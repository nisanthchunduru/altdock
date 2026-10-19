import AppKit
import ObjectiveC

@MainActor
protocol DesktopMoveRequesting {
    var isAvailable: Bool { get }
    func request(windowIDs: [UInt32], destination: UInt64) -> Bool
}

@MainActor
final class DesktopMoveBridge: DesktopMoveRequesting {
    private typealias Initialize = @convention(c) (AnyObject, Selector, NSArray, UInt64) -> AnyObject
    private typealias Perform = @convention(c) (AnyObject, Selector) -> Void
    private let library = DynamicLibrary(path: "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")
    private let initialize = NSSelectorFromString("initWithWindows:spaceID:")
    private let perform = NSSelectorFromString("performWithWMBridgeDelegate")
    private var operationClass: AnyClass? { library == nil ? nil : NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation") }

    var isAvailable: Bool {
        guard let operationClass else { return false }
        return class_getInstanceMethod(operationClass, initialize) != nil && class_getInstanceMethod(operationClass, perform) != nil
    }

    func request(windowIDs: [UInt32], destination: UInt64) -> Bool {
        guard !windowIDs.isEmpty, destination != 0, isAvailable, let operationClass,
              let allocation = (operationClass as AnyObject).perform(NSSelectorFromString("alloc"))?.takeRetainedValue(),
              let initializer = allocation.method(for: initialize) else { return false }
        let windows = windowIDs.map { NSNumber(value: $0) } as NSArray
        let operation = unsafeBitCast(initializer, to: Initialize.self)(allocation, initialize, windows, destination)
        guard let implementation = operation.method(for: perform) else { return false }
        unsafeBitCast(implementation, to: Perform.self)(operation, perform)
        return true
    }
}
