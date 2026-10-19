import AltdockCore
import AppKit
import SwiftUI

struct DockIconContent: View {
    let image: NSImage
    let layout: DockIconLayout
    let isActive: Bool
    let isHovered: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                .frame(width: layout.icon.width, height: layout.icon.height)
                .shadow(color: .black.opacity(isHovered ? 0.25 : 0.12), radius: 3, y: 2)
                .position(x: layout.icon.midX, y: layout.icon.midY)
            Capsule().fill(isActive ? Color.primary.opacity(0.85) : Color.primary.opacity(0.35))
                .frame(width: layout.indicator.width, height: layout.indicator.height)
                .position(x: layout.indicator.midX, y: layout.indicator.midY)
                .allowsHitTesting(false)
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}
