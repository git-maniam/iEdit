import Cocoa

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.225

    // Background rounded square (macOS-style app tile) with a warm paper gradient.
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let colors = [
        NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.30, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.95, green: 0.63, blue: 0.13, alpha: 1.0).cgColor,
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // Notepad "page" — cream rounded rect inset within the tile.
    let pageInsetX = size * 0.165
    let pageTop = size * 0.09
    let pageBottom = size * 0.09
    let pageRect = CGRect(x: pageInsetX, y: pageBottom, width: size - 2 * pageInsetX, height: size - pageTop - pageBottom)
    let pageRadius = size * 0.05
    let pagePath = CGPath(roundedRect: pageRect, cornerWidth: pageRadius, cornerHeight: pageRadius, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.02, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.addPath(pagePath)
    ctx.setFillColor(NSColor(calibratedWhite: 0.99, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Spiral binding along the top of the page.
    let spiralY = pageRect.maxY
    let spiralCount = 7
    let spiralInset = pageRect.width * 0.12
    let spacing = (pageRect.width - 2 * spiralInset) / CGFloat(spiralCount - 1)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.15, alpha: 1.0).cgColor)
    ctx.setLineWidth(size * 0.014)
    for i in 0..<spiralCount {
        let x = pageRect.minX + spiralInset + CGFloat(i) * spacing
        let holeRect = CGRect(x: x - size * 0.018, y: spiralY - size * 0.028, width: size * 0.036, height: size * 0.056)
        ctx.strokeEllipse(in: holeRect)
    }

    // Red margin rule line near the left edge of the page.
    let marginX = pageRect.minX + pageRect.width * 0.16
    ctx.setStrokeColor(NSColor(calibratedRed: 0.85, green: 0.25, blue: 0.25, alpha: 0.85).cgColor)
    ctx.setLineWidth(size * 0.012)
    ctx.move(to: CGPoint(x: marginX, y: pageRect.minY + pageRect.height * 0.08))
    ctx.addLine(to: CGPoint(x: marginX, y: pageRect.maxY - pageRect.height * 0.18))
    ctx.strokePath()

    // Ruled text lines.
    ctx.setStrokeColor(NSColor(calibratedWhite: 0.55, alpha: 0.9).cgColor)
    ctx.setLineWidth(size * 0.014)
    let lineStartX = marginX + pageRect.width * 0.08
    let lineEndXFull = pageRect.maxX - pageRect.width * 0.10
    let lineTop = pageRect.maxY - pageRect.height * 0.30
    let lineSpacing = pageRect.height * 0.115
    let widths: [CGFloat] = [1.0, 1.0, 0.7, 1.0, 0.5]
    for (i, w) in widths.enumerated() {
        let y = lineTop - CGFloat(i) * lineSpacing
        if y < pageRect.minY + pageRect.height * 0.08 { break }
        ctx.move(to: CGPoint(x: lineStartX, y: y))
        ctx.addLine(to: CGPoint(x: lineStartX + (lineEndXFull - lineStartX) * w, y: y))
        ctx.strokePath()
    }

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage, size: CGFloat) -> Data? {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, px) in specs {
    let image = drawIcon(size: px)
    if let data = pngData(from: image, size: px) {
        let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
        try? data.write(to: url)
        print("Wrote \(name)")
    }
}
