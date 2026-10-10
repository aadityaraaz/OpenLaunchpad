import AppKit

@MainActor enum LauncherIcon {
    private static let gridImage: NSImage? = {
        if let image = Bundle(path: "/System/Applications/Apps.app")?.image(forResource: "AppIcon") { return image }
        let systemIcon = "/System/Applications/Apps.app/Contents/Resources/AppIcon.icns"
        if let image = NSImage(contentsOfFile: systemIcon) { return image }
        return Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap { NSImage(contentsOf: $0) }
    }()
    static func grid() -> NSImage? { gridImage }
    private static var rocketImage: NSImage?
    static func rocket() -> NSImage {
        if let rocketImage { return rocketImage }
        let image = NSImage(size: NSSize(width: 512, height: 512)); image.lockFocus()
        let shell = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 440, height: 440), xRadius: 108, yRadius: 108)
        NSGradient(colors: [NSColor(red: 0.18, green: 0.24, blue: 0.42, alpha: 1), NSColor(red: 0.05, green: 0.12, blue: 0.22, alpha: 1)])!.draw(in: shell, angle: -60)
        let flame = NSBezierPath(); flame.move(to: NSPoint(x: 215, y: 173)); flame.curve(to: NSPoint(x: 256, y: 89), controlPoint1: NSPoint(x: 215, y: 117), controlPoint2: NSPoint(x: 242, y: 102)); flame.curve(to: NSPoint(x: 297, y: 173), controlPoint1: NSPoint(x: 270, y: 102), controlPoint2: NSPoint(x: 297, y: 117)); flame.close()
        NSGradient(colors: [.systemOrange, .systemYellow])!.draw(in: flame, angle: 90)
        let fin = NSBezierPath(); fin.move(to: NSPoint(x: 211, y: 238)); fin.line(to: NSPoint(x: 155, y: 157)); fin.line(to: NSPoint(x: 211, y: 171)); fin.close()
        fin.move(to: NSPoint(x: 301, y: 238)); fin.line(to: NSPoint(x: 357, y: 157)); fin.line(to: NSPoint(x: 301, y: 171)); fin.close(); NSColor.systemTeal.setFill(); fin.fill()
        let body = NSBezierPath(); body.move(to: NSPoint(x: 209, y: 173)); body.curve(to: NSPoint(x: 256, y: 411), controlPoint1: NSPoint(x: 176, y: 284), controlPoint2: NSPoint(x: 224, y: 376)); body.curve(to: NSPoint(x: 303, y: 173), controlPoint1: NSPoint(x: 288, y: 376), controlPoint2: NSPoint(x: 336, y: 284)); body.close()
        NSGradient(colors: [.white, NSColor(red: 0.62, green: 0.86, blue: 0.92, alpha: 1)])!.draw(in: body, angle: 0)
        NSColor(red: 0.13, green: 0.39, blue: 0.53, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 230, y: 279, width: 52, height: 52)).fill()
        image.unlockFocus(); rocketImage = image; return image
    }
}
