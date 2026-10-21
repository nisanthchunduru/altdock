import AltdockCore
import AppKit
import SwiftUI
import Testing
@testable import Altdock

@Suite("Separator spacing accounts for transparent app-icon padding")
@MainActor
struct DockIconArtworkTests {
    @Test("Measured trailing padding agrees with the artwork actually rendered in the dock", arguments: DockEdge.allCases)
    func matchesRenderedArtwork(_ edge: DockEdge) throws {
        _ = NSApplication.shared
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256,
                                           space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 12, y: 8, width: 44, height: 40))
        let image = NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 64, height: 64))
        let style = DockStyle(edge: edge, iconSize: 64)
        let layout = DockIconLayout(style: style, isActive: false)
        let renderer = ImageRenderer(content: DockIconContent(image: image, layout: layout, isActive: false, isHovered: false))
        let rendered = try #require(renderer.cgImage)
        let artwork = try redBounds(rendered)
        let inset = DockIconArtwork.trailingInset(image: image, style: style)
        let expected = edge.isVertical ? layout.icon.maxY - artwork.maxY : layout.icon.maxX - artwork.maxX
        #expect(abs(inset - expected) <= 0.5)
        let minimized = DockMinimizedWindowLayout(style: style, precedingIconTrailingInset: inset)
        let previousEnd = edge.isVertical
            ? artwork.maxY - layout.size.height - DockIconLayout.spacing
            : artwork.maxX - layout.size.width - DockIconLayout.spacing
        let before = (edge.isVertical ? minimized.separator.minY : minimized.separator.minX) - previousEnd
        let after = edge.isVertical ? minimized.preview.minY - minimized.separator.maxY : minimized.preview.minX - minimized.separator.maxX
        #expect(abs(before - after) <= 0.5)
    }

    @Test("An image without visible artwork safely falls back to its nominal bounds")
    func missingArtwork() {
        let image = NSImage(size: CGSize(width: 64, height: 64))
        #expect(DockIconArtwork.trailingInset(image: image, style: DockStyle()) == 0)
    }

    private func redBounds(_ image: CGImage) throws -> CGRect {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var bounds = CGRect.null
        for y in 0..<image.height {
            for x in 0..<image.width {
                let index = (y * image.width + x) * 4
                if pixels[index] > 220 && pixels[index + 1] < 30 && pixels[index + 2] < 30 && pixels[index + 3] >= 128 {
                    bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        return try #require(bounds.isNull ? nil : bounds)
    }
}
