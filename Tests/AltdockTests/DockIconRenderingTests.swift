import AltdockCore
import AppKit
import SwiftUI
import Testing
@testable import Altdock

@Suite("SwiftUI renders the icon centered, not the combined icon and indicator")
@MainActor
struct DockIconRenderingTests {
    @Test("Rendered artwork is centered across the dock's thickness", arguments: DockEdge.allCases, [false, true])
    func renderedCenter(_ edge: DockEdge, _ active: Bool) throws {
        for scale: CGFloat in [1, 2] {
            try verifyRenderedCenter(edge: edge, active: active, scale: scale)
        }
    }

    private func verifyRenderedCenter(edge: DockEdge, active: Bool, scale: CGFloat) throws {
        let style = DockStyle(edge: edge)
        let layout = DockIconLayout(style: style, isActive: active)
        let icon = try redImage()
        let renderer = ImageRenderer(content: DockIconContent(image: icon, layout: layout, isActive: active, isHovered: false))
        renderer.scale = scale
        let image = try #require(renderer.cgImage)
        if let directory = ProcessInfo.processInfo.environment["ALTDOCK_RENDER_TEST_OUTPUT"] {
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(edge.rawValue)-\(active)-\(Int(scale))x.png"))
        }
        #expect(image.width == Int(layout.size.width * scale))
        #expect(image.height == Int(layout.size.height * scale))
        let artwork = try redBounds(in: image)
        if edge.isVertical { #expect(artwork.midX == CGFloat(image.width) / 2) }
        else { #expect(artwork.midY == CGFloat(image.height) / 2) }
        #expect(artwork.width == 64 * scale && artwork.height == 64 * scale)
    }

    private func redImage() throws -> NSImage {
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 64, height: 64))
    }

    private func redBounds(in image: CGImage) throws -> CGRect {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var bounds = CGRect.null
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = (y * image.width + x) * 4
                if pixels[offset] > 220 && pixels[offset + 1] < 30 && pixels[offset + 2] < 30 && pixels[offset + 3] > 220 {
                    bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        try #require(!bounds.isNull, "The rendered fixture must contain visible red artwork")
        return bounds
    }
}
