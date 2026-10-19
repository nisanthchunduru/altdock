import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(pixels) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)

    let background = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 196, yRadius: 196)
    NSGradient(
        starting: NSColor(calibratedRed: 0.18, green: 0.24, blue: 0.34, alpha: 1),
        ending: NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.18, alpha: 1)
    )?.draw(in: background, angle: -90)

    NSColor.white.withAlphaComponent(0.14).setFill()
    NSBezierPath(roundedRect: NSRect(x: 170, y: 246, width: 684, height: 258), xRadius: 64, yRadius: 64).fill()
    for (index, height) in [140.0, 244.0, 140.0].enumerated() {
        let x = 224.0 + Double(index) * 208
        let color = index == 1
            ? NSColor(calibratedRed: 0.48, green: 0.88, blue: 0.80, alpha: 1)
            : NSColor.white.withAlphaComponent(0.8)
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: 312, width: 160, height: height), xRadius: 34, yRadius: 34).fill()
    }
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: 498, y: 270, width: 28, height: 12)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        guard let png = drawIcon(pixels: size * scale) else {
            fatalError("Could not render the Altdock icon")
        }
        try png.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
