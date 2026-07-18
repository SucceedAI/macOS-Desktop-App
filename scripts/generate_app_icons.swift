#!/usr/bin/env swift

import AppKit
import Foundation

private struct IconSpec {
    let filename: String
    let pixels: Int
}

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let sourceURL = root.appendingPathComponent("AppStore/Brand/SucceedAI-AppIcon-Master-v2.png")
private let iosURL = root.appendingPathComponent("iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
private let macDirectory = root.appendingPathComponent("Succeed AI/Assets.xcassets/AppIcon.appiconset")

private let macSpecs = [
    IconSpec(filename: "icon_16x16.png", pixels: 16),
    IconSpec(filename: "icon_32x32 1.png", pixels: 32),
    IconSpec(filename: "icon_32x32.png", pixels: 32),
    IconSpec(filename: "icon_32x32@2x.png", pixels: 64),
    IconSpec(filename: "icon_128x128.png", pixels: 128),
    IconSpec(filename: "icon_128x128@2x 1.png", pixels: 256),
    IconSpec(filename: "icon_256x256.png", pixels: 256),
    IconSpec(filename: "icon_512x512.png", pixels: 512),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024),
]

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

private func loadSource() -> NSImage {
    guard let image = NSImage(contentsOf: sourceURL) else {
        fail("Could not load \(sourceURL.path)")
    }
    return image
}

private func bitmap(size: Int, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fail("Could not allocate a \(size)x\(size) icon")
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fail("Could not create an icon drawing context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    draw(NSRect(x: 0, y: 0, width: size, height: size))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

private func write(_ bitmap: NSBitmapImageRep, to destination: URL) {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fail("Could not encode \(destination.lastPathComponent)")
    }
    do {
        try data.write(to: destination, options: .atomic)
    } catch {
        fail("Could not write \(destination.path): \(error.localizedDescription)")
    }
}

private func renderIOS(source: NSImage) {
    let result = bitmap(size: 1024) { canvas in
        source.draw(in: canvas, from: .zero, operation: .copy, fraction: 1)
    }
    write(result, to: iosURL)
}

private func renderMac(source: NSImage, spec: IconSpec) {
    let size = CGFloat(spec.pixels)
    let inset = max(1, size * 0.065)
    let tile = NSRect(x: inset, y: inset * 1.18, width: size - inset * 2, height: size - inset * 2)
    let radius = tile.width * 0.225

    let result = bitmap(size: spec.pixels) { _ in
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = max(1, size * 0.045)
        shadow.shadowOffset = NSSize(width: 0, height: -max(1, size * 0.022))

        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius).addClip()
        source.draw(in: tile, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.18).setStroke()
        let highlight = NSBezierPath(roundedRect: tile.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
        highlight.lineWidth = max(0.5, size / 512)
        highlight.stroke()
    }

    write(result, to: macDirectory.appendingPathComponent(spec.filename))
}

let source = loadSource()
renderIOS(source: source)
for spec in macSpecs {
    renderMac(source: source, spec: spec)
}

print("Generated the iOS 1024px icon and \(macSpecs.count) macOS icon renditions from \(sourceURL.lastPathComponent).")
