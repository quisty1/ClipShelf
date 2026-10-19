import AppKit

let output = CommandLine.arguments[1]
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("ClipShelf-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
for (points, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let side = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: Double(side) / 1024)
    (transform as NSAffineTransform).concat()
    let base = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 195, yRadius: 195)
    NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.29, blue: 0.28, alpha: 1), ending: NSColor(srgbRed: 0.24, green: 0.66, blue: 0.54, alpha: 1))!.draw(in: base, angle: 65)
    NSColor.white.withAlphaComponent(0.28).setFill()
    NSBezierPath(roundedRect: NSRect(x: 278, y: 340, width: 440, height: 440), xRadius: 65, yRadius: 65).fill()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.16); shadow.shadowBlurRadius = 30; shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(srgbRed: 0.97, green: 1, blue: 0.97, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 202, y: 235, width: 440, height: 440), xRadius: 65, yRadius: 65).fill()
    NSShadow().set()
    NSColor(srgbRed: 0.18, green: 0.48, blue: 0.41, alpha: 1).setStroke()
    for (y, width) in [(535.0, 230.0), (455.0, 230.0), (375.0, 142.0)] {
        let line = NSBezierPath(); line.lineWidth = 29; line.lineCapStyle = .round
        line.move(to: NSPoint(x: 298, y: y)); line.line(to: NSPoint(x: 298 + width, y: y)); line.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let url = temporary.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", temporary.path, "-o", output]; try process.run(); process.waitUntilExit()
if process.terminationStatus != 0 { exit(process.terminationStatus) }
