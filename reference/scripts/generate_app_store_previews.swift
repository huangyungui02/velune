#!/usr/bin/env swift

import AppKit
import Foundation

struct Slide {
    let key: String
    let screenshotFile: String
    let label: String
    let headline: String
    let gradientTop: NSColor
    let gradientBottom: NSColor
    let accent: NSColor
}

struct ExportSize {
    let name: String
    let width: Int
    let height: Int
}

func hexColor(_ hex: Int, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func rectFromTop(x: CGFloat, yTop: CGFloat, width: CGFloat, height: CGFloat, canvasHeight: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasHeight - yTop - height, width: width, height: height)
}

func drawAspectFill(image: NSImage, in rect: NSRect) {
    let sourceSize = image.size
    guard sourceSize.width > 0, sourceSize.height > 0 else { return }
    let scale = max(rect.width / sourceSize.width, rect.height / sourceSize.height)
    let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let drawRect = NSRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

func drawCenteredText(_ text: String, rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
    let attributed = NSAttributedString(string: text, attributes: attributes)
    attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func makeSlideImage(
    slide: Slide,
    screenshot: NSImage,
    canvasWidth: CGFloat,
    canvasHeight: CGFloat
) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasWidth),
        pixelsHigh: Int(canvasHeight),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let canvasRect = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
    let gradient = NSGradient(colors: [slide.gradientTop, slide.gradientBottom])
    gradient?.draw(in: canvasRect, angle: -90)

    // Quiet accent glows to keep the look deep and restrained.
    slide.accent.withAlphaComponent(0.14).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: canvasWidth * 0.05,
        y: canvasHeight * 0.60,
        width: canvasWidth * 0.70,
        height: canvasWidth * 0.70
    )).fill()

    slide.accent.withAlphaComponent(0.10).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: canvasWidth * 0.45,
        y: canvasHeight * 0.10,
        width: canvasWidth * 0.55,
        height: canvasWidth * 0.55
    )).fill()

    hexColor(0x05070F, alpha: 0.20).setFill()
    canvasRect.fill()

    let sx = canvasWidth / 1320.0
    let sy = canvasHeight / 2868.0

    let labelStyle = NSMutableParagraphStyle()
    labelStyle.alignment = .center

    let labelRect = rectFromTop(
        x: 0,
        yTop: 220 * sy,
        width: canvasWidth,
        height: 70 * sy,
        canvasHeight: canvasHeight
    )
    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 50 * sx, weight: .semibold),
        .foregroundColor: hexColor(0xA3ACC0),
        .kern: 6.0 * sx,
        .paragraphStyle: labelStyle
    ]
    drawCenteredText(slide.label, rect: labelRect, attributes: labelAttributes)

    let headlineStyle = NSMutableParagraphStyle()
    headlineStyle.alignment = .center
    headlineStyle.lineSpacing = 26 * sy

    let headlineRect = rectFromTop(
        x: canvasWidth * 0.08,
        yTop: 330 * sy,
        width: canvasWidth * 0.84,
        height: 420 * sy,
        canvasHeight: canvasHeight
    )
    let headlineAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 110 * sx, weight: .bold),
        .foregroundColor: hexColor(0xF5F7FE),
        .paragraphStyle: headlineStyle
    ]
    drawCenteredText(slide.headline, rect: headlineRect, attributes: headlineAttributes)

    let phoneWidth = canvasWidth * 0.652
    let phoneHeight = phoneWidth * (2532.0 / 1170.0)
    let phoneRect = rectFromTop(
        x: (canvasWidth - phoneWidth) / 2.0,
        yTop: canvasHeight * 0.292,
        width: phoneWidth,
        height: phoneHeight,
        canvasHeight: canvasHeight
    )
    let radius = phoneWidth * 0.078

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -18 * sy)
    shadow.shadowBlurRadius = 48 * sx
    shadow.shadowColor = hexColor(0x000000, alpha: 0.45)
    shadow.set()
    hexColor(0x0F1322, alpha: 0.35).setFill()
    NSBezierPath(roundedRect: phoneRect, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let clipPath = NSBezierPath(roundedRect: phoneRect, xRadius: radius, yRadius: radius)
    clipPath.addClip()
    drawAspectFill(image: screenshot, in: phoneRect)
    NSGraphicsContext.restoreGraphicsState()

    hexColor(0xFFFFFF, alpha: 0.14).setStroke()
    let stroke = NSBezierPath(roundedRect: phoneRect, xRadius: radius, yRadius: radius)
    stroke.lineWidth = max(2.0, 2.5 * sx)
    stroke.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let slides: [Slide] = [
    Slide(
        key: "hero",
        screenshotFile: "souler.PNG",
        label: "SOUL MATCH",
        headline: "Find someone who\nfeels like home",
        gradientTop: hexColor(0x161B2E),
        gradientBottom: hexColor(0x080B14),
        accent: hexColor(0x6B8BFF)
    ),
    Slide(
        key: "starsea",
        screenshotFile: "starsea.PNG",
        label: "STAR SEA",
        headline: "Your inner world,\nbeautifully seen",
        gradientTop: hexColor(0x0F1A37),
        gradientBottom: hexColor(0x080915),
        accent: hexColor(0x58A6FF)
    ),
    Slide(
        key: "chat",
        screenshotFile: "chat.PNG",
        label: "CHAT",
        headline: "Conversations that\nflow with warmth",
        gradientTop: hexColor(0x231A2E),
        gradientBottom: hexColor(0x0D0A16),
        accent: hexColor(0xC38BFF)
    ),
    Slide(
        key: "echo",
        screenshotFile: "echo.PNG",
        label: "ECHO",
        headline: "Let every echo\nbring you closer",
        gradientTop: hexColor(0x1E1A35),
        gradientBottom: hexColor(0x0A0D1A),
        accent: hexColor(0x8396FF)
    ),
    Slide(
        key: "resonance",
        screenshotFile: "resonances.PNG",
        label: "RESONANCE",
        headline: "Feel the resonance\nbetween two hearts",
        gradientTop: hexColor(0x162432),
        gradientBottom: hexColor(0x091018),
        accent: hexColor(0x58C3FF)
    ),
    Slide(
        key: "glimmer",
        screenshotFile: "glimmer.PNG",
        label: "GLIMMER",
        headline: "A quiet glimmer\nfor your night",
        gradientTop: hexColor(0x202338),
        gradientBottom: hexColor(0x0A0D18),
        accent: hexColor(0xBBA1FF)
    )
]

let sizes: [ExportSize] = [
    ExportSize(name: "6.9", width: 1320, height: 2868),
    ExportSize(name: "6.5", width: 1284, height: 2778)
]

let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let screenshotsDir = currentDirectory.appendingPathComponent("reference/Screenshots", isDirectory: true)
let outputRoot = currentDirectory.appendingPathComponent("reference/AppStoreUS", isDirectory: true)

try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)

var generatedCount = 0

for size in sizes {
    let sizeFolder = outputRoot.appendingPathComponent(size.name, isDirectory: true)
    try FileManager.default.createDirectory(at: sizeFolder, withIntermediateDirectories: true)

    for (index, slide) in slides.enumerated() {
        let screenshotURL = screenshotsDir.appendingPathComponent(slide.screenshotFile)
        guard let screenshot = NSImage(contentsOf: screenshotURL) else {
            fputs("Missing screenshot: \(slide.screenshotFile)\n", stderr)
            continue
        }

        guard let rep = makeSlideImage(
            slide: slide,
            screenshot: screenshot,
            canvasWidth: CGFloat(size.width),
            canvasHeight: CGFloat(size.height)
        ), let pngData = rep.representation(using: .png, properties: [:]) else {
            fputs("Failed to render slide: \(slide.key)\n", stderr)
            continue
        }

        let indexPrefix = String(format: "%02d", index + 1)
        let fileName = "\(indexPrefix)-\(slide.key)-en-US-\(size.width)x\(size.height).png"
        let outputURL = sizeFolder.appendingPathComponent(fileName)
        try pngData.write(to: outputURL)
        generatedCount += 1
        print("Generated: \(outputURL.path)")
    }
}

print("Done. Generated \(generatedCount) screenshots.")
