import AltdockCore
import AppKit
import Combine

@MainActor
final class DockPanelController: ObservableObject {
    @Published var isEnabled = true { didSet { updateVisibility() } }
    @Published private(set) var presentationDescription = "Preparing dock panels"

    private let model: DockModel
    private let preferences: DockPreferences
    private let usePerSpacePanels: Bool
    private let displayProvider: () -> DockDisplay?
    private let makeSurface: (UInt64?) -> any DockSurface
    private let report: (DockPanelReport) -> Void
    private var surfaces: [UInt64: any DockSurface] = [:]
    private var failedSpaces: Set<UInt64> = []
    private var sharedSurface: (any DockSurface)?
    private var display: DockDisplay?
    private var subscriptions: Set<AnyCancellable> = []
    private var visibilityTimer: Timer?
    private var lastInteraction: [UInt64: Date] = [:]
    private var stopped = false

    init(
        model: DockModel, preferences: DockPreferences, usePerSpacePanels: Bool = true,
        displayProvider: (() -> DockDisplay?)? = nil,
        makeSurface: ((UInt64?) -> any DockSurface)? = nil,
        report: @escaping (DockPanelReport) -> Void = { DockPanelDiagnostics.shared.publish($0) }
    ) {
        self.model = model
        self.preferences = preferences
        self.usePerSpacePanels = usePerSpacePanels
        self.report = report
        self.displayProvider = displayProvider ?? {
            preferences.screen.map { DockDisplay(id: $0.displayID, frame: $0.frame, visibleFrame: $0.visibleFrame) }
        }
        if let makeSurface {
            self.makeSurface = makeSurface
        } else {
            let placement = SpacePanelPlacement()
            self.makeSurface = { [weak model] spaceID in
                NativeDockSurface(spaceID: spaceID, placement: placement, moveWindows: spaceID.map { source in
                    { [weak model] application, destination in model?.moveWindows(of: application, from: source, to: destination) }
                }, reorderApplication: spaceID.map { source in
                    { [weak model] processID, index in model?.reorderApplication(processID, to: index, on: source) }
                }, restoreMinimizedWindow: { [weak model] item in
                    model?.restoreMinimizedWindow(item, expectedSpaceID: spaceID)
                }) { [weak model] application in
                    model?.activate(application, expectedSpaceID: spaceID)
                }
            }
        }
        model.$spaceApplications.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.synchronizePanels() }.store(in: &subscriptions)
        model.$spaceMinimizedWindows.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.synchronizePanels() }.store(in: &subscriptions)
        model.$minimizedWindows.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateCurrentSpace() }.store(in: &subscriptions)
        model.$fullScreenSpaceIDs.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.synchronizePanels() }.store(in: &subscriptions)
        model.$desktopDestinations.combineLatest(model.$isMovingWindows).receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMoveDestinations() }.store(in: &subscriptions)
        model.$applications.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateCurrentSpace() }.store(in: &subscriptions)
        model.$activeProcessID.combineLatest(model.$activeSpaceID, model.$isSwitchingSpace)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateCurrentSpace() }.store(in: &subscriptions)
        preferences.objectWillChange.receive(on: RunLoop.main)
            .sink { [weak self] in self?.synchronizePanels() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                self?.model.refresh()
                self?.synchronizePanels()
            }.store(in: &subscriptions)
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollDisplayAndVisibility() }
        }
        visibilityTimer?.tolerance = 0.05
        synchronizePanels()
    }

    func stop() {
        stopped = true
        visibilityTimer?.invalidate()
        subscriptions.removeAll()
        closeSurfaces()
        publishReport()
    }

    func reveal() {
        lastInteraction[currentKey] = Date()
        isEnabled = true
        synchronizePanels()
    }

    func synchronizePanels() {
        guard !stopped else { return }
        let nextDisplay = displayProvider()
        if display?.id != nextDisplay?.id { closeSurfaces() }
        display = nextDisplay
        guard let display else {
            closeSurfaces()
            presentationDescription = "No display available"
            publishReport()
            return
        }
        guard usePerSpacePanels, let snapshots = model.spaceApplications else {
            for surface in surfaces.values { surface.close() }
            surfaces.removeAll()
            failedSpaces.removeAll()
            updateCurrentSpace()
            return
        }
        for (id, surface) in surfaces where snapshots[id] == nil || model.fullScreenSpaceIDs.contains(id) {
            surface.close()
            surfaces.removeValue(forKey: id)
            lastInteraction.removeValue(forKey: id)
        }
        failedSpaces.formIntersection(snapshots.keys)
        for id in snapshots.keys.sorted() {
            guard let applications = snapshots[id], !failedSpaces.contains(id), !model.fullScreenSpaceIDs.contains(id) else { continue }
            let surface = surfaces[id] ?? makeSurface(id)
            let minimized = model.spaceMinimizedWindows?[id] ?? []
            surface.update(applications: applications, minimizedWindows: minimized, isUpdating: false,
                           layout: display.layout(applicationCount: applications.count + minimized.count, style: preferences.style))
            if surfaces[id] == nil {
                guard surface.attach(to: id) else {
                    surface.close()
                    failedSpaces.insert(id)
                    continue
                }
                surfaces[id] = surface
            }
        }
        updateMoveDestinations()
        updateCurrentSpace()
    }

    private func updateMoveDestinations() {
        guard !stopped else { return }
        for (source, surface) in surfaces {
            surface.updateDestinations(model.isMovingWindows ? [] : model.desktopDestinations.filter { $0.id != source })
        }
    }

    func updateCurrentSpace() {
        guard !stopped, let display else { return }
        if let id = model.activeSpaceID, let surface = surfaces[id] {
            surface.updateFocus(model.activeProcessID)
        } else if !model.applications.isEmpty && !model.isFullScreenSpaceActive {
            let surface = sharedSurface ?? makeSurface(nil)
            sharedSurface = surface
            surface.update(
                applications: model.applications, minimizedWindows: model.minimizedWindows, isUpdating: model.isSwitchingSpace,
                layout: display.layout(applicationCount: model.applications.count + model.minimizedWindows.count, style: preferences.style)
            )
            surface.updateFocus(model.activeProcessID)
        }
        let description = model.isFullScreenSpaceActive ? "Dock hidden in full-screen Space" : currentKey == 0
            ? (usePerSpacePanels ? "Shared panel · placement/data fallback" : "Shared panel · compatibility mode")
            : "One panel per Space (\(surfaces.count))" + (failedSpaces.isEmpty ? "" : " · \(failedSpaces.count) fallback")
        if presentationDescription != description { presentationDescription = description }
        updateVisibility()
    }

    func pollDisplayAndVisibility() {
        guard !stopped else { return }
        if displayProvider() != display { synchronizePanels() }
        else { updateVisibility() }
    }

    private var currentKey: UInt64 {
        guard let id = model.activeSpaceID, surfaces[id] != nil else { return 0 }
        return id
    }

    private var currentSurface: (any DockSurface)? {
        currentKey == 0 ? sharedSurface : surfaces[currentKey]
    }

    private func updateVisibility() {
        guard !stopped else { return }
        defer { publishReport() }
        guard isEnabled, let display else {
            surfaces.values.forEach { $0.hide() }
            sharedSurface?.hide()
            return
        }
        if !preferences.autoHide {
            for (id, surface) in surfaces {
                if !model.fullScreenSpaceIDs.contains(id) && model.spaceApplications?[id]?.isEmpty == false { surface.show() }
                else { surface.hide() }
            }
            if currentKey == 0 && !model.applications.isEmpty && !model.isFullScreenSpaceActive { sharedSurface?.show() }
            else { sharedSurface?.hide() }
            return
        }
        for (id, surface) in surfaces where id != currentKey { surface.hide() }
        if currentKey != 0 { sharedSurface?.hide() }
        guard let surface = currentSurface else { return }
        let hasApplications = currentKey == 0 ? !model.applications.isEmpty : model.spaceApplications?[currentKey]?.isEmpty == false
        guard hasApplications, !model.isFullScreenSpaceActive else { surface.hide(); return }
        let mouse = NSEvent.mouseLocation
        let reveal = DockGeometry.revealZone(panel: surface.frame, screen: display.frame, edge: preferences.style.edge)
        let travel = DockGeometry.travelZone(panel: surface.frame, screen: display.frame, edge: preferences.style.edge)
        if reveal.contains(mouse) || (surface.isOrdered && travel.contains(mouse)) || surface.isKeyWindow {
            lastInteraction[currentKey] = Date()
        }
        if Date().timeIntervalSince(lastInteraction[currentKey, default: .distantPast]) < 0.65 { surface.show() }
        else { surface.hide() }
    }

    private func closeSurfaces() {
        surfaces.values.forEach { $0.close() }
        surfaces.removeAll()
        sharedSurface?.close()
        sharedSurface = nil
        failedSpaces.removeAll()
        lastInteraction.removeAll()
    }

    private func publishReport() {
        var panels = surfaces.keys.sorted().compactMap { id -> DockPanelReport.Panel? in
            guard let surface = surfaces[id] else { return nil }
            return .init(spaceID: id, windowNumber: surface.windowNumber, applicationProcessIDs: model.spaceApplications?[id]?.map(\.id) ?? [], frame: NSStringFromRect(surface.frame), ordered: surface.isOrdered, minimizedWindowIDs: model.spaceMinimizedWindows?[id]?.map { $0.id.windowID } ?? [])
        }
        if let sharedSurface {
            panels.append(.init(spaceID: nil, windowNumber: sharedSurface.windowNumber, applicationProcessIDs: model.applications.map(\.id), frame: NSStringFromRect(sharedSurface.frame), ordered: sharedSurface.isOrdered, minimizedWindowIDs: model.minimizedWindows.map { $0.id.windowID }))
        }
        report(DockPanelReport(displayID: display?.id, activeSpaceID: model.activeSpaceID, fullScreenSpaceIDs: model.fullScreenSpaceIDs.sorted(), mode: stopped ? "Stopped" : presentationDescription, style: preferences.style, panels: panels))
    }
}
