import AppKit
import SwiftUI

@MainActor
enum DockMembershipAnimation {
    static let duration: TimeInterval = 0.24
    static var animation: Animation { .easeInOut(duration: duration) }

    static func shouldAnimate(
        previousIDs: [Int32], nextIDs: [Int32],
        previousLayout: DockPanelLayout?, nextLayout: DockPanelLayout,
        isSpaceBound: Bool, isOrdered: Bool, isOnActiveSpace: Bool,
        wasUpdating: Bool, isUpdating: Bool, reduceMotion: Bool, additionalMembershipChanged: Bool = false
    ) -> Bool {
        guard !previousIDs.isEmpty, !nextIDs.isEmpty, previousIDs != nextIDs || additionalMembershipChanged, let previousLayout,
              previousLayout.style == nextLayout.style,
              isSpaceBound, isOrdered, isOnActiveSpace,
              !wasUpdating, !isUpdating, !reduceMotion else { return false }
        let previous = previousLayout.frame
        let next = nextLayout.frame
        if nextLayout.style.edge.isVertical {
            return previous.minX == next.minX && previous.width == next.width && previous.midY == next.midY
        }
        return previous.minY == next.minY && previous.height == next.height && previous.midX == next.midX
    }
}
