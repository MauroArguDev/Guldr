#!/usr/bin/env swift
// Composes one App Store screenshot (v1 plan, 34.6): a caption over a raw 6.9-inch capture, on a
// 1320 × 2868 canvas. Layout in docs/app-store/screenshots.md › Composition; colors from the design tokens.
// Usage: scripts/compose-store-screenshot.swift <capture.png> <output.png> <light|dark> "<caption>"

import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 5, ["light", "dark"].contains(arguments[3]) else {
    FileHandle.standardError.write(Data(
        "Usage: compose-store-screenshot.swift <capture.png> <output.png> <light|dark> \"<caption>\"\n".utf8))
    exit(64)
}
let (inputPath, outputPath, mode, caption) = (arguments[1], arguments[2], arguments[3], arguments[4])

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// MARK: - Tokens

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
guard let tokensData = try? Data(contentsOf: root.appending(path: "docs/design/tokens.json")),
      let tokens = try? JSONSerialization.jsonObject(with: tokensData) as? [String: Any],
      let colors = tokens["color"] as? [String: [String: String]],
      let radii = tokens["radius_pt"] as? [String: Double] else {
    fail("couldn't read docs/design/tokens.json")
}

func color(_ name: String) -> CGColor {
    guard let hex = colors[name]?[mode], hex.count == 7, let value = UInt32(hex.dropFirst(), radix: 16) else {
        fail("no \(mode) value for \(name) in tokens.json")
    }
    return CGColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

// MARK: - Layout (pixels; the canvas is the 6.9-inch display at 3×)

let canvas = CGSize(width: 1320, height: 2868)
let captionHeight: CGFloat = 560
let sideMargin: CGFloat = 96
let bottomMargin: CGFloat = 120
let fontSize: CGFloat = 96
let cornerRadius = CGFloat(radii["phoneCard"] ?? 28) * 3
let borderWidth: CGFloat = 3

// MARK: - Drawing

guard let source = NSImage(contentsOfFile: inputPath),
      let capture = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fail("couldn't read \(inputPath)")
}
guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8,
                              bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fail("couldn't create the canvas")
}

// Core Graphics' origin is the bottom-left corner.
context.setFillColor(color("AppBackground"))
context.fill(CGRect(origin: .zero, size: canvas))

// The capture keeps its aspect ratio in the space under the caption.
let shotHeight = canvas.height - captionHeight - bottomMargin
let shotWidth = (shotHeight * CGFloat(capture.width) / CGFloat(capture.height)).rounded()
let shotRect = CGRect(x: ((canvas.width - shotWidth) / 2).rounded(), y: bottomMargin, width: shotWidth,
                      height: shotHeight)
let shotPath = CGPath(roundedRect: shotRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
context.saveGState()
context.addPath(shotPath)
context.clip()
context.interpolationQuality = .high
context.draw(capture, in: shotRect)
context.restoreGState()
context.addPath(shotPath)
context.setStrokeColor(color("Hairline"))
context.setLineWidth(borderWidth)
context.strokePath()

// New York, like the app's brand moments; centered in the caption band.
let base = NSFont.systemFont(ofSize: fontSize, weight: .regular)
let font = base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? base
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.lineBreakMode = .byWordWrapping
let text = NSAttributedString(string: caption, attributes: [
    .font: font,
    .foregroundColor: NSColor(cgColor: color("TextPrimary")) ?? .black,
    .paragraphStyle: paragraph
])
let textWidth = canvas.width - 2 * sideMargin
let bounds = text.boundingRect(with: CGSize(width: textWidth, height: captionHeight),
                               options: [.usesLineFragmentOrigin, .usesFontLeading])
let textHeight = bounds.height.rounded(.up)
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
text.draw(with: CGRect(x: sideMargin, y: canvas.height - (captionHeight + textHeight) / 2, width: textWidth,
                       height: textHeight),
          options: [.usesLineFragmentOrigin, .usesFontLeading])
NSGraphicsContext.current = nil

guard let image = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fail("couldn't encode the PNG")
}
do {
    try FileManager.default.createDirectory(at: URL(fileURLWithPath: outputPath).deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fail("couldn't write \(outputPath): \(error.localizedDescription)")
}
print("Wrote \(outputPath)")
