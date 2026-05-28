import AppKit
import Foundation

struct Palette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let glow: NSColor
    let plate: NSColor
    let rim: NSColor
    let lens: NSColor
    let lensAccent: NSColor
    let lensInner: NSColor
    let centerFill: NSColor
    let leaf: NSColor
    let vein: NSColor
    let sparkle: NSColor
    let shadow: NSColor
}

let size: CGFloat = 1024

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("FoodLens/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let palettes: [(String, Palette)] = [
    (
        "AppIcon-1024.png",
        Palette(
            backgroundTop: NSColor(calibratedRed: 0.10, green: 0.39, blue: 0.29, alpha: 1),
            backgroundBottom: NSColor(calibratedRed: 0.47, green: 0.84, blue: 0.34, alpha: 1),
            glow: NSColor(calibratedRed: 0.96, green: 0.81, blue: 0.29, alpha: 0.78),
            plate: NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.965, alpha: 1),
            rim: NSColor(calibratedRed: 0.88, green: 0.94, blue: 0.89, alpha: 1),
            lens: NSColor(calibratedRed: 0.18, green: 0.60, blue: 0.43, alpha: 1),
            lensAccent: NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.22, alpha: 1),
            lensInner: NSColor(calibratedRed: 0.16, green: 0.33, blue: 0.26, alpha: 1),
            centerFill: NSColor(calibratedRed: 0.95, green: 0.98, blue: 0.95, alpha: 1),
            leaf: NSColor(calibratedRed: 0.19, green: 0.58, blue: 0.39, alpha: 1),
            vein: NSColor(calibratedRed: 0.83, green: 0.94, blue: 0.85, alpha: 1),
            sparkle: NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.81, alpha: 1),
            shadow: NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.09, alpha: 0.20)
        )
    ),
    (
        "AppIcon-1024-dark.png",
        Palette(
            backgroundTop: NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.05, alpha: 1),
            backgroundBottom: NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.14, alpha: 1),
            glow: NSColor(calibratedRed: 0.21, green: 0.40, blue: 0.32, alpha: 0.55),
            plate: NSColor(calibratedRed: 0.10, green: 0.15, blue: 0.14, alpha: 1),
            rim: NSColor(calibratedRed: 0.18, green: 0.27, blue: 0.23, alpha: 1),
            lens: NSColor(calibratedRed: 0.58, green: 0.92, blue: 0.73, alpha: 1),
            lensAccent: NSColor(calibratedRed: 0.98, green: 0.89, blue: 0.53, alpha: 1),
            lensInner: NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.08, alpha: 1),
            centerFill: NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.10, alpha: 1),
            leaf: NSColor(calibratedRed: 0.69, green: 0.97, blue: 0.80, alpha: 1),
            vein: NSColor(calibratedRed: 0.91, green: 0.98, blue: 0.92, alpha: 1),
            sparkle: NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.71, alpha: 1),
            shadow: NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.34)
        )
    ),
    (
        "AppIcon-1024-tinted.png",
        Palette(
            backgroundTop: NSColor(calibratedWhite: 0.08, alpha: 1),
            backgroundBottom: NSColor(calibratedWhite: 0.14, alpha: 1),
            glow: NSColor(calibratedWhite: 0.28, alpha: 0.22),
            plate: NSColor(calibratedWhite: 0.14, alpha: 1),
            rim: NSColor(calibratedWhite: 0.22, alpha: 1),
            lens: NSColor(calibratedWhite: 0.94, alpha: 1),
            lensAccent: NSColor(calibratedWhite: 0.82, alpha: 1),
            lensInner: NSColor(calibratedWhite: 0.17, alpha: 1),
            centerFill: NSColor(calibratedWhite: 0.15, alpha: 1),
            leaf: NSColor(calibratedWhite: 0.97, alpha: 1),
            vein: NSColor(calibratedWhite: 0.72, alpha: 1),
            sparkle: NSColor(calibratedWhite: 0.94, alpha: 1),
            shadow: NSColor(calibratedWhite: 0.0, alpha: 0.28)
        )
    )
]

func radialGradient(radius: CGFloat, color: NSColor) -> NSGradient {
    NSGradient(colors: [
        color,
        color.withAlphaComponent(color.alphaComponent * 0.38),
        color.withAlphaComponent(0)
    ])!
}

func leafPath() -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: 520, y: 622))
    path.curve(
        to: CGPoint(x: 590, y: 520),
        controlPoint1: CGPoint(x: 570, y: 612),
        controlPoint2: CGPoint(x: 608, y: 565)
    )
    path.curve(
        to: CGPoint(x: 520, y: 414),
        controlPoint1: CGPoint(x: 575, y: 450),
        controlPoint2: CGPoint(x: 548, y: 415)
    )
    path.curve(
        to: CGPoint(x: 444, y: 492),
        controlPoint1: CGPoint(x: 486, y: 412),
        controlPoint2: CGPoint(x: 446, y: 445)
    )
    path.curve(
        to: CGPoint(x: 520, y: 622),
        controlPoint1: CGPoint(x: 446, y: 560),
        controlPoint2: CGPoint(x: 476, y: 612)
    )
    path.close()

    var transform = AffineTransform()
    transform.translate(x: 512, y: 512)
    transform.rotate(byDegrees: -24)
    transform.translate(x: -512, y: -512)
    path.transform(using: transform)
    return path
}

func sparklePath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: center.x, y: center.y + radius))
    path.line(to: CGPoint(x: center.x + radius * 0.30, y: center.y + radius * 0.30))
    path.line(to: CGPoint(x: center.x + radius, y: center.y))
    path.line(to: CGPoint(x: center.x + radius * 0.30, y: center.y - radius * 0.30))
    path.line(to: CGPoint(x: center.x, y: center.y - radius))
    path.line(to: CGPoint(x: center.x - radius * 0.30, y: center.y - radius * 0.30))
    path.line(to: CGPoint(x: center.x - radius, y: center.y))
    path.line(to: CGPoint(x: center.x - radius * 0.30, y: center.y + radius * 0.30))
    path.close()
    return path
}

func drawIcon(filename: String, palette: Palette) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let background = NSGradient(colors: [palette.backgroundTop, palette.backgroundBottom])!
    background.draw(in: rect, angle: -52)

    radialGradient(radius: 380, color: palette.glow)
        .draw(fromCenter: CGPoint(x: 790, y: 860), radius: 0, toCenter: CGPoint(x: 790, y: 860), radius: 380, options: [])

    radialGradient(radius: 240, color: palette.backgroundBottom.withAlphaComponent(0.28))
        .draw(fromCenter: CGPoint(x: 178, y: 190), radius: 0, toCenter: CGPoint(x: 178, y: 190), radius: 240, options: [])

    let plateShadow = NSShadow()
    plateShadow.shadowBlurRadius = 40
    plateShadow.shadowOffset = NSSize(width: 0, height: -18)
    plateShadow.shadowColor = palette.shadow
    plateShadow.set()

    let plateRect = NSRect(x: 232, y: 232, width: 560, height: 560)
    let platePath = NSBezierPath(ovalIn: plateRect)
    palette.plate.setFill()
    platePath.fill()

    let noShadow = NSShadow()
    noShadow.shadowColor = .clear
    noShadow.shadowBlurRadius = 0
    noShadow.shadowOffset = .zero
    noShadow.set()

    let rimPath = NSBezierPath(ovalIn: NSRect(x: 263, y: 263, width: 498, height: 498))
    rimPath.lineWidth = 42
    palette.rim.setStroke()
    rimPath.stroke()

    let centerPlate = NSBezierPath(ovalIn: NSRect(x: 326, y: 326, width: 372, height: 372))
    palette.centerFill.withAlphaComponent(0.92).setFill()
    centerPlate.fill()

    let outerLens = NSBezierPath(ovalIn: NSRect(x: 378, y: 378, width: 268, height: 268))
    outerLens.lineWidth = 40
    palette.lens.setStroke()
    outerLens.stroke()

    let accentArc = NSBezierPath()
    accentArc.lineWidth = 40
    accentArc.lineCapStyle = .round
    accentArc.appendArc(withCenter: CGPoint(x: 512, y: 512), radius: 134, startAngle: 18, endAngle: 126)
    palette.lensAccent.setStroke()
    accentArc.stroke()

    let innerLens = NSBezierPath(ovalIn: NSRect(x: 424, y: 424, width: 176, height: 176))
    innerLens.lineWidth = 18
    palette.lensInner.withAlphaComponent(0.88).setStroke()
    innerLens.stroke()

    let centerCircle = NSBezierPath(ovalIn: NSRect(x: 454, y: 454, width: 116, height: 116))
    palette.centerFill.setFill()
    centerCircle.fill()

    let leaf = leafPath()
    let leafShadow = NSShadow()
    leafShadow.shadowBlurRadius = 12
    leafShadow.shadowOffset = NSSize(width: 0, height: -6)
    leafShadow.shadowColor = palette.shadow.withAlphaComponent(0.55)
    leafShadow.set()
    palette.leaf.setFill()
    leaf.fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let vein = NSBezierPath()
    vein.lineWidth = 10
    vein.lineCapStyle = .round
    vein.move(to: CGPoint(x: 468, y: 438))
    vein.curve(to: CGPoint(x: 568, y: 586), controlPoint1: CGPoint(x: 484, y: 474), controlPoint2: CGPoint(x: 540, y: 560))
    palette.vein.setStroke()
    vein.stroke()

    let stem = NSBezierPath()
    stem.lineWidth = 7
    stem.lineCapStyle = .round
    stem.move(to: CGPoint(x: 468, y: 438))
    stem.line(to: CGPoint(x: 490, y: 472))
    palette.vein.withAlphaComponent(0.70).setStroke()
    stem.stroke()

    let sparkle = sparklePath(center: CGPoint(x: 690, y: 698), radius: 22)
    palette.sparkle.setFill()
    sparkle.fill()

    let sparkleMini = sparklePath(center: CGPoint(x: 726, y: 658), radius: 10)
    palette.sparkle.withAlphaComponent(0.82).setFill()
    sparkleMini.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }

    try data.write(to: outputDirectory.appendingPathComponent(filename))
    print("Generated \(filename)")
}

for (filename, palette) in palettes {
    try drawIcon(filename: filename, palette: palette)
}

exit(EXIT_SUCCESS)
