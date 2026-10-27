import AppKit

enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }()

    private static func draw(in rect: NSRect) {
        let s = rect.width / 18
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let slider = NSBezierPath()
        slider.move(to: p(3.9, 9.4))
        slider.curve(to: p(9, 16.9), controlPoint1: p(3.6, 14.6), controlPoint2: p(5.6, 16.9))
        slider.curve(to: p(14.1, 9.4), controlPoint1: p(12.4, 16.9), controlPoint2: p(14.4, 14.6))
        slider.lineWidth = 0.9 * s
        slider.lineCapStyle = .round
        slider.stroke()

        let pad = NSBezierPath()
        pad.move(to: p(5.6, 14.4))
        pad.curve(to: p(12.4, 14.4), controlPoint1: p(7.2, 16.1), controlPoint2: p(10.8, 16.1))
        pad.lineWidth = 2.4 * s
        pad.lineCapStyle = .round
        pad.stroke()

        for (x, inner) in [(CGFloat(3.9), CGFloat(1)), (14.1, -1)] {
            let cup = NSBezierPath(
                roundedRect: NSRect(origin: p(x - 2.5, 0.8), size: NSSize(width: 5 * s, height: 9.2 * s)),
                xRadius: 2.5 * s, yRadius: 2.9 * s
            )
            cup.append(NSBezierPath(
                roundedRect: NSRect(origin: p(x + inner * 1.1 - 0.35, 2.4), size: NSSize(width: 0.7 * s, height: 6 * s)),
                xRadius: 0.35 * s, yRadius: 0.35 * s
            ))
            cup.windingRule = .evenOdd
            cup.fill()
        }
    }
}
