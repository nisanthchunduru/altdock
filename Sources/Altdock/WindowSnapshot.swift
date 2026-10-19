import AltdockCore
import AppKit

enum WindowSnapshot {
    static func current() -> [SpaceWindow] {
        guard let descriptions = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return descriptions.compactMap { description in
            guard let id = description[kCGWindowNumber as String] as? UInt32,
                  let processID = description[kCGWindowOwnerPID as String] as? Int32,
                  let layer = description[kCGWindowLayer as String] as? Int,
                  let boundsDictionary = description[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else { return nil }

            return SpaceWindow(
                id: id, processID: processID, bounds: bounds, layer: layer,
                alpha: description[kCGWindowAlpha as String] as? Double ?? 1,
                isOnScreen: description[kCGWindowIsOnscreen as String] as? Bool ?? false
            )
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
