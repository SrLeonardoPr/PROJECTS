import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("Expected PNG output path")
}

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let outer = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 210, yRadius: 210)
NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.33, blue: 0.79, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.63, blue: 0.82, alpha: 1)
])!.draw(in: outer, angle: 35)

let center = NSPoint(x: size / 2, y: size / 2)
NSColor.white.setStroke()
for index in 0..<8 {
    let angle = CGFloat(index) * .pi / 4
    let start = NSPoint(x: center.x + cos(angle) * 268, y: center.y + sin(angle) * 268)
    let end = NSPoint(x: center.x + cos(angle) * 354, y: center.y + sin(angle) * 354)
    let ray = NSBezierPath()
    ray.lineWidth = 48
    ray.lineCapStyle = .round
    ray.move(to: start)
    ray.line(to: end)
    ray.stroke()
}

let sun = NSBezierPath(ovalIn: NSRect(x: center.x - 172, y: center.y - 172, width: 344, height: 344))
NSColor.white.setFill()
sun.fill()
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
