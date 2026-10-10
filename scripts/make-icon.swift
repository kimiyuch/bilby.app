// Renders the Bilby app icon: a bilby peeking over a poker chip marked BB, on a desert-ochre squircle.
// Writes an asset catalog icon set with the macOS sizes and the single 1024 px iOS icon.
// Usage: swift make-icon.swift <AppIcon.appiconset> [preview.png]
import AppKit

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
let preview = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let fur = color(0x9AA6B3), furDark = color(0x7C8896), furLight = color(0xD9DEE4)
let earInside = color(0xE9B7B3), nose = color(0x2B2F35), pink = color(0xD98C93)
let chipColor = color(0x2F6F86), chipDark = color(0x24576A), chipLight = color(0xF4EFE6)

func oval(_ c: NSPoint, _ rx: CGFloat, _ ry: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
}

func fill(_ path: NSBezierPath, _ c: NSColor) {
    c.setFill()
    path.fill()
}

func withShadow(_ alpha: CGFloat, offset: CGFloat, blur: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha)
    shadow.shadowOffset = NSSize(width: 0, height: offset)
    shadow.shadowBlurRadius = blur
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// Draws `draw` rotated by `degrees` around `center`.
func rotated(_ degrees: CGFloat, around center: NSPoint, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: center.x, yBy: center.y)
    t.rotate(byDegrees: degrees)
    t.translateX(by: -center.x, yBy: -center.y)
    t.concat()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// A long ear: outer fur with a pink inside, tilted around its base.
func ear(base: NSPoint, length: CGFloat, width: CGFloat, tilt: CGFloat) {
    rotated(tilt, around: base) {
        let center = NSPoint(x: base.x, y: base.y + length / 2)
        fill(oval(center, width / 2, length / 2), fur)
        fill(oval(NSPoint(x: center.x + width * 0.04, y: center.y + length * 0.04), width * 0.3, length * 0.38), earInside)
    }
}

/// The bilby's head in profile, looking right, with its long pointed snout.
func bilby() {
    ear(base: NSPoint(x: 405, y: 640), length: 250, width: 112, tilt: 22)
    ear(base: NSPoint(x: 480, y: 655), length: 265, width: 122, tilt: -6)

    // Head and snout as one shape, so the outline flows into the nose.
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 330, y: 560))
    head.curve(to: NSPoint(x: 470, y: 720), controlPoint1: NSPoint(x: 320, y: 660), controlPoint2: NSPoint(x: 390, y: 720))
    head.curve(to: NSPoint(x: 640, y: 650), controlPoint1: NSPoint(x: 550, y: 720), controlPoint2: NSPoint(x: 600, y: 690))
    head.curve(to: NSPoint(x: 790, y: 560), controlPoint1: NSPoint(x: 690, y: 610), controlPoint2: NSPoint(x: 760, y: 585))
    head.curve(to: NSPoint(x: 770, y: 530), controlPoint1: NSPoint(x: 805, y: 548), controlPoint2: NSPoint(x: 795, y: 528))
    head.curve(to: NSPoint(x: 600, y: 500), controlPoint1: NSPoint(x: 720, y: 532), controlPoint2: NSPoint(x: 660, y: 505))
    head.curve(to: NSPoint(x: 330, y: 560), controlPoint1: NSPoint(x: 500, y: 480), controlPoint2: NSPoint(x: 340, y: 470))
    head.close()
    fill(head, fur)

    // Lighter cheek and muzzle.
    NSGraphicsContext.saveGraphicsState()
    head.addClip()
    let cheek = NSBezierPath()
    cheek.move(to: NSPoint(x: 420, y: 470))
    cheek.curve(to: NSPoint(x: 800, y: 545), controlPoint1: NSPoint(x: 560, y: 560), controlPoint2: NSPoint(x: 700, y: 560))
    cheek.line(to: NSPoint(x: 800, y: 470))
    cheek.close()
    fill(cheek, furLight)
    fill(oval(NSPoint(x: 400, y: 640), 90, 70), color(0xA9B4C0))
    NSGraphicsContext.restoreGraphicsState()

    // Nose, eye with a highlight, and whiskers.
    fill(oval(NSPoint(x: 788, y: 549), 20, 16), pink)
    let eye = NSPoint(x: 590, y: 622)
    fill(oval(eye, 22, 24), nose)
    fill(oval(NSPoint(x: eye.x + 7, y: eye.y + 9), 7, 7), .white)
    color(0xFFFFFF, 0.6).setStroke()
    for (dy, end) in [(CGFloat(8), NSPoint(x: 860, y: 590)), (-4, NSPoint(x: 870, y: 545)), (-14, NSPoint(x: 850, y: 505))] {
        let whisker = NSBezierPath()
        whisker.lineWidth = 5
        whisker.lineCapStyle = .round
        whisker.move(to: NSPoint(x: 745, y: 548 + dy))
        whisker.line(to: end)
        whisker.stroke()
    }
}

/// A poker chip seen from the front, with edge inserts and BB in the middle.
func chip(center c: NSPoint, radius r: CGFloat) {
    withShadow(0.28, offset: -12, blur: 24) { fill(oval(c, r, r), chipColor) }
    // Six edge inserts.
    NSGraphicsContext.saveGraphicsState()
    oval(c, r, r).addClip()
    for i in 0..<6 {
        let angle = CGFloat(i) * .pi / 3 + .pi / 6
        let insert = NSBezierPath()
        let half: CGFloat = 0.2
        insert.move(to: c)
        insert.line(to: NSPoint(x: c.x + 2 * r * cos(angle - half), y: c.y + 2 * r * sin(angle - half)))
        insert.line(to: NSPoint(x: c.x + 2 * r * cos(angle + half), y: c.y + 2 * r * sin(angle + half)))
        insert.close()
        fill(insert, chipLight)
    }
    NSGraphicsContext.restoreGraphicsState()
    fill(oval(c, r * 0.78, r * 0.78), chipDark)
    fill(oval(c, r * 0.72, r * 0.72), chipColor)
    // Dashed inner ring.
    let ring = oval(c, r * 0.64, r * 0.64)
    ring.lineWidth = r * 0.035
    ring.setLineDash([r * 0.12, r * 0.08], count: 2, phase: 0)
    chipLight.withAlphaComponent(0.8).setStroke()
    ring.stroke()

    let font = NSFont.systemFont(ofSize: r * 0.62, weight: .heavy)
    let text = NSAttributedString(string: "BB", attributes: [
        .font: font, .foregroundColor: chipLight, .kern: -r * 0.02,
    ])
    let size = text.size()
    text.draw(at: NSPoint(x: c.x - size.width / 2, y: c.y - size.height / 2 + r * 0.02))
}

/// The artwork inside a 1024×1024 canvas. On macOS it sits on the squircle; on iOS the system masks
/// a full-bleed square, so the background fills the canvas and the artwork is scaled up to match.
func drawIcon(squircle: Bool) {
    let background = NSGradient(colors: [color(0xF0C77E), color(0xD08A45)])!
    if squircle {
        let body = NSRect(x: 100, y: 100, width: 824, height: 824)
        let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
        withShadow(0.3, offset: -10, blur: 24) { fill(shape, color(0xD08A45)) }
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        background.draw(in: body, angle: -90)
        NSGradient(colors: [color(0xFFFFFF, 0.2), color(0xFFFFFF, 0)])!
            .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
        artwork()
        NSGraphicsContext.restoreGraphicsState()
    } else {
        background.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: -90)
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: 512, yBy: 512)
        t.scale(by: 1024 / 824)
        t.translateX(by: -512, yBy: -512)
        t.concat()
        artwork()
        NSGraphicsContext.restoreGraphicsState()
    }
}

func artwork() {
    // A low dune behind everything.
    let dune = NSBezierPath()
    dune.move(to: NSPoint(x: 0, y: 300))
    dune.curve(to: NSPoint(x: 1024, y: 360), controlPoint1: NSPoint(x: 350, y: 420), controlPoint2: NSPoint(x: 700, y: 260))
    dune.line(to: NSPoint(x: 1024, y: 0))
    dune.line(to: NSPoint(x: 0, y: 0))
    dune.close()
    fill(dune, color(0xC27A3A, 0.55))

    bilby()
    chip(center: NSPoint(x: 512, y: 335), radius: 205)
    // Paws over the top edge of the chip.
    for x: CGFloat in [430, 600] {
        fill(oval(NSPoint(x: x, y: 548), 46, 32), fur)
        fill(oval(NSPoint(x: x, y: 541), 34, 20), furDark)
    }
}

func render(pixels: Int, squircle: Bool) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(squircle: squircle)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = "mac-\(points)@\(scale)x.png"
    try! render(pixels: points * scale, squircle: true).write(to: iconset.appendingPathComponent(name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
}
try! render(pixels: 1024, squircle: false).write(to: iconset.appendingPathComponent("ios-1024.png"))
images.append(["filename": "ios-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"])

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconset.appendingPathComponent("Contents.json"))
if let preview {
    try! render(pixels: 512, squircle: true).write(to: preview)
}
