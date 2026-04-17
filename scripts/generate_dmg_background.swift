#!/usr/bin/env swift
// Generates the DMG installer window background (540 x 380 @1x, 1080 x 760 @2x).
// Usage: swift scripts/generate_dmg_background.swift
//
// Produces:
//   scripts/dmg-background.png       (540 x 380, 1x)
//   scripts/dmg-background@2x.png    (1080 x 760, 2x — Retina)
// Both are copied into the DMG at build time as ".background/background.png" (tiff
// with both images) so Finder picks up the Retina version on HiDPI displays.
import AppKit
import CoreGraphics

let width:  CGFloat = 540
let height: CGFloat = 380

func drawBackground(scale: CGFloat, outputPath: String) {
    let pixelsWide = Int(width * scale)
    let pixelsHigh = Int(height * scale)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelsWide,
        pixelsHigh: pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Scale so drawing code uses logical coordinates.
    cg.scaleBy(x: scale, y: scale)

    // Background — subtle vertical gradient, dark-app-friendly.
    let bgColors = [
        CGColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1),
        CGColor(red: 0.14, green: 0.14, blue: 0.17, alpha: 1)
    ] as CFArray
    let bgGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: bgColors,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Layout (must match AppleScript icon positions in release.sh)
    //   App icon center:          (140, 180) from top-left
    //   Applications alias center: (400, 180) from top-left
    // macOS Finder coordinates count from top-left with y growing down.
    // CoreGraphics default coordinates count from bottom-left with y growing up.
    // Flip y so we can think top-left throughout.
    cg.translateBy(x: 0, y: height)
    cg.scaleBy(x: 1, y: -1)

    let iconY: CGFloat = 180
    let leftX: CGFloat = 140
    let rightX: CGFloat = 400

    // Arrow — curved from just right of the app icon to just left of Applications.
    // Icon size is 128 in Finder; leave a gap around each icon.
    let arrowStart = CGPoint(x: leftX + 68, y: iconY)
    let arrowEnd   = CGPoint(x: rightX - 68, y: iconY)
    let arrowControl1 = CGPoint(x: leftX + 130,  y: iconY - 55)
    let arrowControl2 = CGPoint(x: rightX - 130, y: iconY - 55)

    cg.setStrokeColor(CGColor(red: 0.46, green: 0.55, blue: 0.95, alpha: 0.9))
    cg.setLineWidth(3)
    cg.setLineCap(.round)
    cg.beginPath()
    cg.move(to: arrowStart)
    cg.addCurve(to: arrowEnd, control1: arrowControl1, control2: arrowControl2)
    cg.strokePath()

    // Arrowhead at end — two short strokes forming a V pointing toward Applications.
    let headSize: CGFloat = 16
    // Tangent at the Bezier end: from arrowControl2 to arrowEnd.
    let dx = arrowEnd.x - arrowControl2.x
    let dy = arrowEnd.y - arrowControl2.y
    let len = sqrt(dx*dx + dy*dy)
    let ux = dx / len
    let uy = dy / len
    // Two lines 35° off the tangent.
    let angle: CGFloat = 0.6108 // ~35°
    let cosA = cos(angle), sinA = sin(angle)
    let back1 = CGPoint(
        x: arrowEnd.x - headSize * (ux * cosA + uy * sinA),
        y: arrowEnd.y - headSize * (uy * cosA - ux * sinA)
    )
    let back2 = CGPoint(
        x: arrowEnd.x - headSize * (ux * cosA - uy * sinA),
        y: arrowEnd.y - headSize * (uy * cosA + ux * sinA)
    )
    cg.beginPath()
    cg.move(to: back1)
    cg.addLine(to: arrowEnd)
    cg.addLine(to: back2)
    cg.strokePath()

    // Instruction text — centered below the icons.
    // CoreGraphics text rendering uses flipped coords; switch back for NSString drawing.
    cg.saveGState()
    cg.translateBy(x: 0, y: height)
    cg.scaleBy(x: 1, y: -1)

    let text = "Drag to Applications folder"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor(calibratedRed: 0.75, green: 0.77, blue: 0.82, alpha: 1),
        .paragraphStyle: paragraph
    ]
    let textSize = (text as NSString).size(withAttributes: attrs)
    let textRect = CGRect(
        x: (width - textSize.width) / 2,
        y: height - 295,  // near the bottom of the window
        width: textSize.width,
        height: textSize.height
    )
    (text as NSString).draw(in: textRect, withAttributes: attrs)

    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Generated \(outputPath) (\(pixelsWide) x \(pixelsHigh))")
}

let outDir = "scripts"
drawBackground(scale: 1, outputPath: "\(outDir)/dmg-background.png")
drawBackground(scale: 2, outputPath: "\(outDir)/dmg-background@2x.png")
print("Done.")
