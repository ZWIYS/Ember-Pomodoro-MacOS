// Renders the Ember app icon (1024x1024 PNG). Usage: swift scripts/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824pt rounded square centered in 1024pt.
let inset: CGFloat = 100
let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 190, yRadius: 190)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 28
shadow.set()
color(0x262624).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

// Warm gradient on the tile.
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
NSGradient(starting: color(0x34332F), ending: color(0x21201E))!.draw(in: tile, angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Ring.
let center = NSPoint(x: size / 2, y: size / 2)
let radius: CGFloat = 235
let lineWidth: CGFloat = 78

let track = NSBezierPath()
track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
track.lineWidth = lineWidth
color(0xFAF9F5, 0.10).setStroke()
track.stroke()

// Progress arc: starts at the top, sweeps clockwise ~270 degrees.
let arc = NSBezierPath()
arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 270, clockwise: true)
arc.lineWidth = lineWidth
arc.lineCapStyle = .round
color(0xD97757).setStroke()
arc.stroke()

// Ember dot in the middle.
let dotRadius: CGFloat = 62
let dot = NSBezierPath(ovalIn: NSRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                      width: dotRadius * 2, height: dotRadius * 2))
color(0xD97757).setFill()
dot.fill()

NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
