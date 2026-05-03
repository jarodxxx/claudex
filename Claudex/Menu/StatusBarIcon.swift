import AppKit

/// Renders the menu bar icon for the current `IconStyle`.
///
/// Color coding (consistent across every style):
///   * Green   ≤ 50 %
///   * Orange  50–90 %
///   * Red     ≥ 90 %
///
/// The image is NOT a template image because we need real colors. macOS will
/// invert nothing — the green/orange/red system colors remain readable on both
/// light and dark menu bars.
enum StatusBarIcon {
    static func image(style: IconStyle, percent: Int, status: UsageStatus) -> NSImage? {
        let p = max(0, min(100, percent))
        let img: NSImage?
        switch style {
        case .gauge:    img = gaugeImage(percent: p)
        case .minimal:  img = minimalImage(percent: p)
        case .circular: img = circularImage(percent: p)
        case .battery:  img = batteryImage(percent: p)
        }
        // Template = false: we want our colors preserved.
        img?.isTemplate = false
        return img
    }

    // MARK: - Color helpers

    private static func color(for percent: Int) -> NSColor {
        switch percent {
        case ..<50:   return .systemGreen
        case 50..<90: return .systemOrange
        default:      return .systemRed
        }
    }

    /// Tint used for "neutral" elements (needle, battery outline, …). Static
    /// because we draw outside any view context — NSColor.labelColor would
    /// resolve against the wrong appearance.
    private static var neutralTint: NSColor {
        let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return bestMatch == .darkAqua ? .white : .black
    }

    // MARK: - Gauge (half-circle, 3 colored zones, animated needle)

    private static func gaugeImage(percent: Int) -> NSImage {
        let size = NSSize(width: 32, height: 20)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        let center = NSPoint(x: size.width / 2, y: 4)
        let radius: CGFloat = 13
        let lineWidth: CGFloat = 3

        // Background track (very light gray)
        drawArc(
            center: center,
            radius: radius,
            startAngle: 180, endAngle: 0,
            clockwise: true,
            color: NSColor.tertiaryLabelColor.withAlphaComponent(0.3),
            lineWidth: lineWidth
        )

        // 3 colored zones (vertical: green 0-50, orange 50-90, red 90-100)
        // Mapping percent → angle: 0% → 180°, 100% → 0° (clockwise across top)
        drawArc(center: center, radius: radius,
                startAngle: 180, endAngle: 90, clockwise: true,
                color: .systemGreen, lineWidth: lineWidth)
        drawArc(center: center, radius: radius,
                startAngle: 90, endAngle: 18, clockwise: true,
                color: .systemOrange, lineWidth: lineWidth)
        drawArc(center: center, radius: radius,
                startAngle: 18, endAngle: 0, clockwise: true,
                color: .systemRed, lineWidth: lineWidth)

        // Needle
        let needleAngle = (180.0 - Double(percent) * 180.0 / 100.0) * .pi / 180.0
        let needleLength: CGFloat = radius - 2
        let tip = NSPoint(
            x: center.x + cos(needleAngle) * needleLength,
            y: center.y + sin(needleAngle) * needleLength
        )
        let needle = NSBezierPath()
        needle.move(to: center)
        needle.line(to: tip)
        needle.lineWidth = 1.6
        needle.lineCapStyle = .round
        neutralTint.setStroke()
        needle.stroke()

        // Pivot dot
        let dotSize: CGFloat = 3.5
        let dot = NSBezierPath(ovalIn: NSRect(
            x: center.x - dotSize / 2,
            y: center.y - dotSize / 2,
            width: dotSize, height: dotSize
        ))
        neutralTint.setFill()
        dot.fill()

        return img
    }

    // MARK: - Minimal (colored text "XX%")

    private static func minimalImage(percent: Int) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: color(for: percent),
        ]
        let attr = NSAttributedString(string: "\(percent)%", attributes: attrs)
        let textSize = attr.size()
        let img = NSImage(size: NSSize(width: ceil(textSize.width) + 4, height: 18))
        img.lockFocus()
        attr.draw(at: NSPoint(x: 2, y: (18 - textSize.height) / 2))
        img.unlockFocus()
        return img
    }

    // MARK: - Circular (colored ring + center text)

    private static func circularImage(percent: Int) -> NSImage {
        let size = NSSize(width: 22, height: 20)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = 8
        let lineWidth: CGFloat = 2.2
        let tint = color(for: percent)

        // Track
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor.tertiaryLabelColor.withAlphaComponent(0.35).setStroke()
        track.stroke()

        // Filled portion (start at 12 o'clock, clockwise)
        let endAngle = 90 - (Double(percent) / 100.0) * 360
        let filled = NSBezierPath()
        filled.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: endAngle,
            clockwise: true
        )
        filled.lineWidth = lineWidth
        filled.lineCapStyle = .round
        tint.setStroke()
        filled.stroke()

        // Center text (small)
        let label = "\(percent)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: tint,
        ]
        let attr = NSAttributedString(string: label, attributes: attrs)
        let textSize = attr.size()
        attr.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2))

        return img
    }

    // MARK: - Battery (colored fill + colored % text)

    private static func batteryImage(percent: Int) -> NSImage {
        let size = NSSize(width: 40, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        let bodyRect = NSRect(x: 0, y: 4, width: 22, height: 10)
        let capRect = NSRect(x: 22, y: 7, width: 2, height: 4)
        let tint = color(for: percent)

        // Outline
        let outline = NSBezierPath(roundedRect: bodyRect, xRadius: 2, yRadius: 2)
        outline.lineWidth = 1
        neutralTint.setStroke()
        outline.stroke()
        neutralTint.setFill()
        NSBezierPath(rect: capRect).fill()

        // Fill (colored)
        let fillWidth = max(0, (bodyRect.width - 2) * CGFloat(percent) / 100.0)
        let fillRect = NSRect(
            x: bodyRect.minX + 1,
            y: bodyRect.minY + 1,
            width: fillWidth,
            height: bodyRect.height - 2
        )
        tint.setFill()
        fillRect.fill()

        // Percent text right of battery (in tint color)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: tint,
        ]
        let attr = NSAttributedString(string: "\(percent)%", attributes: attrs)
        attr.draw(at: NSPoint(x: 26, y: 4))

        return img
    }

    // MARK: - Drawing helpers

    private static func drawArc(
        center: NSPoint,
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        clockwise: Bool,
        color: NSColor,
        lineWidth: CGFloat
    ) {
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .butt
        color.setStroke()
        arc.stroke()
    }
}
