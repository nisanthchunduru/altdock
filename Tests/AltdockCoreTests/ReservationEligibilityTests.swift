import AltdockCore
import Testing

@Suite("Optional Accessibility attributes do not exclude normal windows")
struct ReservationEligibilityTests {
    @Test("A standard resizable window qualifies when AXFullScreen is unsupported")
    func unsupportedFullScreenFlag() {
        #expect(rejection(fullScreen: .unsupported) == nil)
    }

    @Test("An explicit full-screen window is still excluded")
    func excludesFullScreen() {
        #expect(rejection(fullScreen: .value(true)) == "Full-screen window")
    }

    @Test("An AX timeout is not mistaken for a supported false fullscreen value")
    func retriesUnavailableFullScreenFlag() {
        #expect(rejection(fullScreen: .unavailable(-25204))?.contains("-25204") == true)
    }

    @Test("A standard size-only resizable window does not need writable position for a height adjustment")
    func sizeOnlyWindow() {
        #expect(rejection(fullScreen: .value(false)) == nil)
    }

    @Test("Dialogs, minimized windows, and fixed-size windows remain protected")
    func rejectsUnsafeWindows() {
        #expect(ReservationEligibility.rejection(subrole: .value("AXDialog"), minimized: .value(false), fullScreen: .unsupported, sizeSettable: .value(true)) != nil)
        #expect(ReservationEligibility.rejection(subrole: .value("AXStandardWindow"), minimized: .value(true), fullScreen: .unsupported, sizeSettable: .value(true)) != nil)
        #expect(ReservationEligibility.rejection(subrole: .value("AXStandardWindow"), minimized: .value(false), fullScreen: .unsupported, sizeSettable: .value(false)) != nil)
    }

    private func rejection(fullScreen: AccessibilityAttribute<Bool>) -> String? {
        ReservationEligibility.rejection(subrole: .value("AXStandardWindow"), minimized: .value(false), fullScreen: fullScreen, sizeSettable: .value(true))
    }
}
