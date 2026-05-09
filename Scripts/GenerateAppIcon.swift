#!/usr/bin/env swift
//
// GenerateAppIcon.swift
//
// Renders Mana's manga-glitch app icon at 1024×1024 in three variants
// (light / dark / tinted) and writes them into App/Resources/Assets.xcassets/AppIcon.appiconset.
//
// Run from the repo root (or anywhere — it locates itself):
//     swift Scripts/GenerateAppIcon.swift
//
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette

enum Palette {
    static let paper   = NSColor(srgbRed: 0.949, green: 0.922, blue: 0.863, alpha: 1)
    static let ink     = NSColor(srgbRed: 0.039, green: 0.031, blue: 0.071, alpha: 1)
    static let accent  = NSColor(srgbRed: 1.000, green: 0.106, blue: 0.420, alpha: 1)
    static let cyan    = NSColor(srgbRed: 0.000, green: 1.000, blue: 0.878, alpha: 1)
    static let red     = NSColor(srgbRed: 1.000, green: 0.000, blue: 0.235, alpha: 1)
    static let yellow  = NSColor(srgbRed: 1.000, green: 0.894, blue: 0.000, alpha: 1)
}

// MARK: - Variant

enum Variant {
    case light
    case dark
    case tinted
}

func backgroundColor(for v: Variant) -> NSColor {
    switch v {
    case .light: return Palette.paper
    case .dark: return Palette.ink
    case .tinted: return .black
    }
}

func mainFillColor(for v: Variant) -> NSColor {
    switch v {
    case .light: return Palette.accent
    case .dark: return Palette.paper
    case .tinted: return .white
    }
}

func mainStrokeColor(for v: Variant) -> NSColor {
    switch v {
    case .light: return Palette.ink
    case .dark: return Palette.accent
    case .tinted: return NSColor(white: 0.85, alpha: 1)
    }
}

func dotColor(for v: Variant) -> NSColor {
    switch v {
    case .light: return Palette.ink.withAlphaComponent(0.10)
    case .dark: return Palette.accent.withAlphaComponent(0.12)
    case .tinted: return NSColor(white: 1, alpha: 0.06)
    }
}

func cyanGhostColor(for v: Variant) -> NSColor {
    switch v {
    case .light, .dark: return Palette.cyan.withAlphaComponent(0.95)
    case .tinted:       return NSColor(white: 0.80, alpha: 0.85)
    }
}

func redGhostColor(for v: Variant) -> NSColor {
    switch v {
    case .light, .dark: return Palette.red.withAlphaComponent(0.95)
    case .tinted:       return NSColor(white: 0.65, alpha: 0.85)
    }
}

func secondaryStarColor(for v: Variant) -> NSColor {
    switch v {
    case .light:  return Palette.cyan
    case .dark:   return Palette.cyan
    case .tinted: return NSColor(white: 0.92, alpha: 1)
    }
}

func tertiaryStarColor(for v: Variant) -> NSColor {
    switch v {
    case .light:  return Palette.yellow
    case .dark:   return Palette.yellow
    case .tinted: return NSColor(white: 0.78, alpha: 1)
    }
}

// MARK: - Drawing

let canvas: CGFloat = 1024

func drawIcon(_ variant: Variant) -> Data {
    let imageSize = NSSize(width: canvas, height: canvas)
    let width = Int(canvas)
    let height = Int(canvas)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("could not create bitmap context")
    }

    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    defer { NSGraphicsContext.restoreGraphicsState() }

    // 1. Background
    backgroundColor(for: variant).setFill()
    NSRect(origin: .zero, size: imageSize).fill()

    // 2. Halftone dots
    let dot = dotColor(for: variant)
    dot.setFill()
    let spacing: CGFloat = 26
    let radius: CGFloat = 4.5
    var rowIdx = 0
    var y: CGFloat = -spacing
    while y <= canvas + spacing {
        var x: CGFloat = rowIdx.isMultiple(of: 2) ? 0 : spacing / 2
        while x <= canvas + spacing {
            let r = NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            NSBezierPath(ovalIn: r).fill()
            x += spacing
        }
        y += spacing
        rowIdx += 1
    }

    // 3. Speed-line burst from center (subtle)
    let burstColor = mainStrokeColor(for: variant).withAlphaComponent(0.08)
    burstColor.setStroke()
    let center = NSPoint(x: canvas / 2, y: canvas / 2)
    let lineCount = 64
    for i in 0..<lineCount {
        let angle = Double(i) / Double(lineCount) * .pi * 2
        let inner: CGFloat = 280
        let outer: CGFloat = 720
        let p = NSBezierPath()
        p.move(to: NSPoint(
            x: center.x + cos(angle) * inner,
            y: center.y + sin(angle) * inner
        ))
        p.line(to: NSPoint(
            x: center.x + cos(angle) * outer,
            y: center.y + sin(angle) * outer
        ))
        p.lineWidth = 1.6
        p.stroke()
    }

    // 4. Big sound-effect burst star, rotated for energy
    let mainCenter = NSPoint(x: canvas / 2, y: canvas / 2)
    ctx.saveGState()
    ctx.translateBy(x: mainCenter.x, y: mainCenter.y)
    ctx.rotate(by: -8.0 * .pi / 180.0)
    ctx.translateBy(x: -mainCenter.x, y: -mainCenter.y)

    let inkColor: NSColor = (variant == .tinted)
        ? NSColor(white: 0.18, alpha: 1)
        : Palette.ink

    // 4a. Ink shadow (offset)
    let shadowDX: CGFloat = 22
    let shadowDY: CGFloat = -22
    let shadowStar = starPath(
        center: NSPoint(x: mainCenter.x + shadowDX, y: mainCenter.y + shadowDY),
        points: 12, outerRadius: 380, innerRadius: 230
    )
    inkColor.setFill()
    shadowStar.fill()

    // 4b. Cyan ghost (stronger split + vertical drift)
    let cyanStar = starPath(
        center: NSPoint(x: mainCenter.x - 34, y: mainCenter.y + 8),
        points: 12, outerRadius: 380, innerRadius: 230
    )
    cyanGhostColor(for: variant).setFill()
    cyanStar.fill()

    // 4c. Red ghost
    let redStar = starPath(
        center: NSPoint(x: mainCenter.x + 34, y: mainCenter.y - 8),
        points: 12, outerRadius: 380, innerRadius: 230
    )
    redGhostColor(for: variant).setFill()
    redStar.fill()

    // 4c'. Yellow third channel (tiny)
    let yellowStar = starPath(
        center: NSPoint(x: mainCenter.x + 6, y: mainCenter.y + 22),
        points: 12, outerRadius: 380, innerRadius: 230
    )
    Palette.yellow.withAlphaComponent(0.55).setFill()
    yellowStar.fill()

    // 4d. Main fill + outline, sliced into horizontal bands that are
    // offset by varying dx values to fake a torn-frame glitch.
    let sliceOffsets: [CGFloat] = [0, -22, 8, -10, 26, -6, 14]
    let sliceCount = sliceOffsets.count
    let bandHeight = canvas / CGFloat(sliceCount)
    for i in 0..<sliceCount {
        ctx.saveGState()
        let bandRect = CGRect(
            x: -200,
            y: CGFloat(i) * bandHeight,
            width: canvas + 400,
            height: bandHeight + 0.5
        )
        ctx.clip(to: bandRect)
        ctx.translateBy(x: sliceOffsets[i], y: 0)
        let slicePath = starPath(
            center: mainCenter,
            points: 12,
            outerRadius: 380,
            innerRadius: 230
        )
        mainFillColor(for: variant).setFill()
        slicePath.fill()
        mainStrokeColor(for: variant).setStroke()
        slicePath.lineWidth = 18
        slicePath.stroke()
        ctx.restoreGState()
    }

    // 4d'. Hard horizontal tear bands — narrow strips of pure cyan/magenta
    let tearBands: [(y: CGFloat, h: CGFloat, color: NSColor, dx: CGFloat)] = [
        (canvas * 0.32, 8,  Palette.cyan.withAlphaComponent(0.85), -28),
        (canvas * 0.55, 5,  Palette.red.withAlphaComponent(0.90),   22),
        (canvas * 0.71, 3,  Palette.cyan.withAlphaComponent(0.75), -16)
    ]
    for band in tearBands {
        ctx.saveGState()
        let clipRect = CGRect(x: -200, y: band.y, width: canvas + 400, height: band.h)
        ctx.clip(to: clipRect)
        ctx.translateBy(x: band.dx, y: 0)
        let tearStar = starPath(
            center: mainCenter,
            points: 12,
            outerRadius: 380,
            innerRadius: 230
        )
        band.color.setFill()
        tearStar.fill()
        ctx.restoreGState()
    }

    // 4e. Inner concentric ring — empty center disc with stroke
    let innerDiscRadius: CGFloat = 95
    let innerDisc = NSBezierPath(
        ovalIn: NSRect(
            x: mainCenter.x - innerDiscRadius,
            y: mainCenter.y - innerDiscRadius,
            width: innerDiscRadius * 2,
            height: innerDiscRadius * 2
        )
    )
    inkColor.setFill()
    innerDisc.fill()

    let innerDot = NSBezierPath(
        ovalIn: NSRect(
            x: mainCenter.x - 36,
            y: mainCenter.y - 36,
            width: 72,
            height: 72
        )
    )
    mainFillColor(for: variant).setFill()
    innerDot.fill()

    ctx.restoreGState()

    // 5. Decorative small bursts in two corners
    drawSmallBurst(
        center: NSPoint(x: canvas - 200, y: canvas - 200),
        radius: 88,
        innerRadius: 48,
        points: 8,
        rotation: 14,
        fill: secondaryStarColor(for: variant),
        stroke: inkColor
    )
    drawSmallBurst(
        center: NSPoint(x: 175, y: 215),
        radius: 64,
        innerRadius: 34,
        points: 6,
        rotation: -22,
        fill: tertiaryStarColor(for: variant),
        stroke: inkColor
    )

    // 6. Glitch noise blocks — small CMY rectangles scattered, deterministic
    let blocks: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: NSColor)] = [
        (90,             860,  120, 14, Palette.cyan.withAlphaComponent(0.85)),
        (canvas - 280,   60,   180, 10, Palette.red.withAlphaComponent(0.85)),
        (60,             510,  44,  44, Palette.yellow.withAlphaComponent(0.85)),
        (canvas - 130,   460,  90,  6,  Palette.cyan.withAlphaComponent(0.95)),
        (canvas * 0.5 - 40,  40, 120, 8, Palette.red.withAlphaComponent(0.85)),
        (canvas * 0.42, canvas - 70, 200, 12, Palette.cyan.withAlphaComponent(0.75)),
        (520,            780,  16,  16, Palette.red.withAlphaComponent(0.95))
    ]
    for b in blocks {
        b.color.setFill()
        NSRect(x: b.x, y: b.y, width: b.w, height: b.h).fill()
    }

    // 7. Scanlines overlay — full-canvas
    let scanColor: NSColor = (variant == .tinted)
        ? NSColor(white: 0, alpha: 0.18)
        : Palette.ink.withAlphaComponent(0.10)
    scanColor.setFill()
    var sy: CGFloat = 0
    while sy < canvas {
        NSRect(x: 0, y: sy, width: canvas, height: 1.5).fill()
        sy += 5
    }

    // Encode PNG via ImageIO directly (avoids the broken NSImage TIFF path on macOS 26)
    guard let cgImage = ctx.makeImage() else { fatalError("makeImage failed") }
    let outData = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(
        outData,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fatalError("destination create failed")
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("PNG finalize failed")
    }
    return outData as Data
}

// MARK: - Star path helper

func starPath(center: NSPoint, points: Int, outerRadius: CGFloat, innerRadius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let total = points * 2
    let angleStep = .pi * 2 / Double(total)
    let startAngle = -Double.pi / 2

    for i in 0..<total {
        let r = i.isMultiple(of: 2) ? outerRadius : innerRadius
        let a = startAngle + angleStep * Double(i)
        let p = NSPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        if i == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close()
    return path
}

func drawSmallBurst(
    center: NSPoint,
    radius: CGFloat,
    innerRadius: CGFloat,
    points: Int,
    rotation: CGFloat,
    fill: NSColor,
    stroke: NSColor
) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: rotation * .pi / 180.0)
    ctx.translateBy(x: -center.x, y: -center.y)

    let p = starPath(center: center, points: points, outerRadius: radius, innerRadius: innerRadius)
    fill.setFill()
    p.fill()
    stroke.setStroke()
    p.lineWidth = 8
    p.stroke()

    ctx.restoreGState()
}

// MARK: - Output

let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let scriptsDir = scriptPath.deletingLastPathComponent()
let repoRoot = scriptsDir.deletingLastPathComponent()
let outDir = repoRoot
    .appendingPathComponent("App")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

let fm = FileManager.default
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

func write(_ data: Data, to filename: String) throws {
    let url = outDir.appendingPathComponent(filename)
    try data.write(to: url)
    print("wrote \(url.path)")
}

try write(drawIcon(.light),  to: "icon-1024.png")
try write(drawIcon(.dark),   to: "icon-1024-dark.png")
try write(drawIcon(.tinted), to: "icon-1024-tinted.png")

// Update Contents.json with all three variants
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon-1024-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon-1024-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try contentsJSON.write(
    to: outDir.appendingPathComponent("Contents.json"),
    atomically: true,
    encoding: .utf8
)
print("updated Contents.json")
