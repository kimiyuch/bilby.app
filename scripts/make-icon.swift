// Renders the Bilby app icon: a bilby peeking over its hole cards, a pair of aces, on a deep teal squircle.
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
let spadeInk = color(0x173544), heartInk = color(0xC9473D)

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

func symbol(_ text: String, at p: NSPoint, size: CGFloat, _ c: NSColor) {
    let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: c])
    let s = string.size()
    string.draw(at: NSPoint(x: p.x - s.width / 2, y: p.y - s.height / 2))
}

/// A playing card centred at `c`, tilted by `tilt` degrees, with the rank and suit in the corner and
/// optionally a big suit in the middle.
func card(center c: NSPoint, tilt: CGFloat, rank: String, suit: String, ink: NSColor, pip: Bool) {
    rotated(tilt, around: c) {
        let w: CGFloat = 270, h: CGFloat = 378
        let rect = NSRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        withShadow(0.3, offset: -10, blur: 22) { fill(NSBezierPath(roundedRect: rect, xRadius: 32, yRadius: 32), .white) }
        symbol(rank, at: NSPoint(x: rect.minX + 48, y: rect.maxY - 54), size: 68, ink)
        symbol(suit, at: NSPoint(x: rect.minX + 48, y: rect.maxY - 118), size: 52, ink)
        if pip { symbol(suit, at: NSPoint(x: c.x + 14, y: c.y - 34), size: 170, ink) }
    }
}

/// The artwork inside a 1024×1024 canvas. On macOS it sits on the squircle; on iOS the system masks
/// a full-bleed square, so the background fills the canvas and the artwork is scaled up to match.
func drawIcon(squircle: Bool) {
    let background = NSGradient(colors: [color(0x2F6F86), color(0x173544)])!
    if squircle {
        let body = NSRect(x: 100, y: 100, width: 824, height: 824)
        let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
        withShadow(0.3, offset: -10, blur: 24) { fill(shape, color(0x173544)) }
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
    bilby()
    // The hole cards: the ace of spades behind, the ace of hearts in front.
    card(center: NSPoint(x: 440, y: 352), tilt: 13, rank: "A", suit: "♠", ink: spadeInk, pip: false)
    card(center: NSPoint(x: 592, y: 340), tilt: -8, rank: "A", suit: "♥", ink: heartInk, pip: true)
    // Paws over the top of the front card.
    for x: CGFloat in [590, 700] {
        fill(oval(NSPoint(x: x, y: 532), 44, 30), fur)
        fill(oval(NSPoint(x: x, y: 525), 32, 18), furDark)
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
