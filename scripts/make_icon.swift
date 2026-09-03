import AppKit

@main
enum MakeIcon {
    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            fputs("usage: make_icon <AppIcon.icns>\n", stderr)
            exit(1)
        }
        let dest = URL(fileURLWithPath: CommandLine.arguments[1])
        let tmp = dest.deletingLastPathComponent().appendingPathComponent("Latch.iconset")
        try? FileManager.default.removeItem(at: tmp)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let slots: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]
        for (name, side) in slots {
            try! png(render(pixels: side), to: tmp.appendingPathComponent(name))
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        task.arguments = ["-c", "icns", "-o", dest.path, tmp.path]
        try! task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            fputs("iconutil failed (\(task.terminationStatus)). Left \(tmp.path)\n", stderr)
            exit(task.terminationStatus)
        }
        try? FileManager.default.removeItem(at: tmp)
    }

    private static func render(pixels: Int) -> NSBitmapImageRep {
        let size = CGFloat(pixels)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
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
        NSGraphicsContext.current?.imageInterpolation = .high

        let inset = size * 0.07
        let box = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let radius = box.width * 0.22
        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1).setFill()
        NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius).fill()

        let pad = size * 0.20
        let paneGap = size * 0.035
        let paneW = (box.width - pad * 2 - paneGap) * 0.62
        let sideW = box.width - pad * 2 - paneGap - paneW
        let paneH = box.height - pad * 2
        let originY = box.minY + pad
        let originX = box.minX + pad

        let main = NSRect(x: originX, y: originY, width: paneW, height: paneH)
        let sideTop = NSRect(
            x: originX + paneW + paneGap,
            y: originY + paneH * 0.52,
            width: sideW,
            height: paneH * 0.48
        )
        let sideBot = NSRect(
            x: originX + paneW + paneGap,
            y: originY,
            width: sideW,
            height: paneH * 0.48 - paneGap
        )

        NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.21, alpha: 1).setFill()
        NSBezierPath(roundedRect: main, xRadius: paneW * 0.08, yRadius: paneW * 0.08).fill()
        NSBezierPath(roundedRect: sideTop, xRadius: sideW * 0.12, yRadius: sideW * 0.12).fill()
        NSBezierPath(roundedRect: sideBot, xRadius: sideW * 0.12, yRadius: sideW * 0.12).fill()

        let barH = max(2, size * 0.045)
        let bar = NSRect(
            x: originX + paneW - size * 0.02,
            y: originY + paneH * 0.42,
            width: paneGap + size * 0.04,
            height: barH
        )
        NSColor(calibratedRed: 0.93, green: 0.72, blue: 0.38, alpha: 1).setFill()
        NSBezierPath(roundedRect: bar, xRadius: barH / 2, yRadius: barH / 2).fill()

        let pin = NSRect(
            x: bar.midX - barH * 0.55,
            y: bar.midY - barH * 0.55,
            width: barH * 1.1,
            height: barH * 1.1
        )
        NSColor(calibratedRed: 0.78, green: 0.54, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(ovalIn: pin).fill()

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func png(_ rep: NSBitmapImageRep, to url: URL) throws {
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MakeIcon", code: 1)
        }
        try data.write(to: url)
    }
}
