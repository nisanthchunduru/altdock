import AltdockCore
import AppKit

@MainActor
enum DockIconArtwork {
    private static weak var previousImage: NSImage?
    private static var previousBounds = CGRect(x: 0, y: 0, width: 1, height: 1)

    static func trailingInset(image: NSImage, style: DockStyle) -> CGFloat {
        if previousImage !== image {
            previousBounds = normalizedBounds(image) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            previousImage = image
        }
        return style.iconSize * (1 - (style.edge.isVertical ? previousBounds.maxY : previousBounds.maxX))
    }

    private static func normalizedBounds(_ image: NSImage) -> CGRect? {
        guard image.size.width > 0, image.size.height > 0,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let dimension = 128
        var pixels = [UInt8](repeating: 0, count: dimension * dimension * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: dimension, height: dimension,
                                          bitsPerComponent: 8, bytesPerRow: dimension * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            let scale = CGFloat(dimension) / max(image.size.width, image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            context.draw(cgImage, in: CGRect(x: (CGFloat(dimension) - size.width) / 2,
                                            y: (CGFloat(dimension) - size.height) / 2, width: size.width, height: size.height))
            return true
        }
        guard drawn else { return nil }
        var bounds = CGRect.null
        for y in 0..<dimension {
            for x in 0..<dimension where pixels[(y * dimension + x) * 4 + 3] >= 128 {
                bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        guard !bounds.isNull else { return nil }
        return CGRect(x: bounds.minX / CGFloat(dimension), y: bounds.minY / CGFloat(dimension),
                      width: bounds.width / CGFloat(dimension), height: bounds.height / CGFloat(dimension))
    }
}
