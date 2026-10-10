import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale; let s = CGFloat(pixels)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let bounds = NSRect(x: s * 0.085, y: s * 0.085, width: s * 0.83, height: s * 0.83)
        let shape = NSBezierPath(roundedRect: bounds, xRadius: s * 0.205, yRadius: s * 0.205)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.shadowBlurRadius = s * 0.035; shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012); shadow.set()
        NSColor.black.setFill(); shape.fill(); NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor(white: 0.15, alpha: 1), NSColor(white: 0.065, alpha: 1)])!.draw(in: shape, angle: -90)
        NSColor.white.withAlphaComponent(0.15).setStroke(); shape.lineWidth = max(0.5, s * 0.006); shape.stroke()
        let search = NSBezierPath(roundedRect: NSRect(x: s * 0.24, y: s * 0.61, width: s * 0.53, height: s * 0.145), xRadius: s * 0.073, yRadius: s * 0.073)
        NSGradient(colors: [NSColor(white: 0.31, alpha: 1), NSColor(white: 0.20, alpha: 1)])!.draw(in: search, angle: -90)
        NSColor.white.withAlphaComponent(0.23).setStroke(); search.lineWidth = s * 0.006; search.stroke()
        NSColor(white: 0.83, alpha: 1).setStroke()
        let magnifier = NSBezierPath(ovalIn: NSRect(x: s * 0.282, y: s * 0.662, width: s * 0.056, height: s * 0.056)); magnifier.lineWidth = max(1, s * 0.011); magnifier.stroke()
        let handle = NSBezierPath(); handle.move(to: NSPoint(x: s * 0.327, y: s * 0.668)); handle.line(to: NSPoint(x: s * 0.35, y: s * 0.645)); handle.lineWidth = max(1, s * 0.011); handle.lineCapStyle = .round; handle.stroke()
        let palette: [[NSColor]] = [
            [NSColor(red: 0.02, green: 0.69, blue: 0.96, alpha: 1), NSColor(red: 0.12, green: 0.79, blue: 0.29, alpha: 1), NSColor(red: 0.97, green: 0.18, blue: 0.35, alpha: 1)],
            [NSColor(red: 1, green: 0.62, blue: 0.02, alpha: 1), NSColor(red: 0.69, green: 0.28, blue: 0.82, alpha: 1), NSColor(white: 0.52, alpha: 1)]
        ]
        for row in 0..<2 { for col in 0..<3 {
            let rect = NSRect(x: s * (0.24 + CGFloat(col) * 0.20), y: s * (0.425 - CGFloat(row) * 0.18), width: s * 0.13, height: s * 0.13)
            let tile = NSBezierPath(roundedRect: rect, xRadius: s * 0.028, yRadius: s * 0.028)
            let color = palette[row][col]
            NSGradient(colors: [color, color.blended(withFraction: 0.14, of: .black)!])!.draw(in: tile, angle: -90)
        } }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        let png = bitmap.representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
        if size == 512 && scale == 2 { try png.write(to: root.appendingPathComponent("AppIconPreview.png")) }
    }
}
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("AppIcon.icns").path]; try process.run(); process.waitUntilExit()
if process.terminationStatus != 0 { exit(process.terminationStatus) }
try FileManager.default.removeItem(at: iconset)
