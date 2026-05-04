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
    static func image(
        style: IconStyle,
        percent: Int,
        status: UsageStatus,
        secondaryPercent: Int? = nil
    ) -> NSImage? {
        let p = max(0, min(100, percent))
        let secondary = secondaryPercent.map { max(0, min(100, $0)) }
        let img: NSImage?
        switch style {
        case .gauge:    img = gaugeImage(percent: p)
        case .minimal:  img = minimalImage(percent: p)
        case .circular: img = circularImage(percent: p)
        case .battery:  img = batteryImage(percent: p)
        case .segments: img = segmentsImage(percent: p)
        case .dualBar:  img = dualBarImage(primary: p, secondary: secondary ?? p)
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

    // MARK: - Segments (5 vertical bars filling left-to-right)

    private static func segmentsImage(percent: Int) -> NSImage {
        let size = NSSize(width: 24, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        let segmentCount = 5
        let segmentWidth: CGFloat = 3
        let segmentSpacing: CGFloat = 1.5
        let baseY: CGFloat = 3
        let maxHeight: CGFloat = 12

        // Number of segments to fill (rounded up so even 1% lights one segment)
        let filled = percent == 0 ? 0 : max(1, Int(ceil(Double(percent) / 100.0 * Double(segmentCount))))
        let tint = color(for: percent)

        let totalWidth = CGFloat(segmentCount) * segmentWidth + CGFloat(segmentCount - 1) * segmentSpacing
        let startX = (size.width - totalWidth) / 2

        for i in 0..<segmentCount {
            // Bars grow taller left-to-right (cellular signal style)
            let height = maxHeight * CGFloat(i + 1) / CGFloat(segmentCount)
            let rect = NSRect(
                x: startX + CGFloat(i) * (segmentWidth + segmentSpacing),
                y: baseY,
                width: segmentWidth,
                height: height
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: 0.8, yRadius: 0.8)
            if i < filled {
                tint.setFill()
            } else {
                NSColor.tertiaryLabelColor.withAlphaComponent(0.3).setFill()
            }
            path.fill()
        }

        return img
    }

    // MARK: - Dual Bar (two stacked horizontal bars)

    private static func dualBarImage(primary: Int, secondary: Int) -> NSImage {
        let size = NSSize(width: 32, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        let barWidth: CGFloat = 26
        let barHeight: CGFloat = 4
        let spacing: CGFloat = 2
        let totalHeight = barHeight * 2 + spacing
        let startX: CGFloat = 3
        let startY = (size.height - totalHeight) / 2

        // Top bar = primary (usually session)
        drawHorizontalBar(
            x: startX,
            y: startY + barHeight + spacing,
            width: barWidth,
            height: barHeight,
            percent: primary,
            tint: color(for: primary)
        )

        // Bottom bar = secondary (usually weekly)
        drawHorizontalBar(
            x: startX,
            y: startY,
            width: barWidth,
            height: barHeight,
            percent: secondary,
            tint: color(for: secondary)
        )

        return img
    }

    private static func drawHorizontalBar(
        x: CGFloat, y: CGFloat,
        width: CGFloat, height: CGFloat,
        percent: Int,
        tint: NSColor
    ) {
        // Track
        let trackRect = NSRect(x: x, y: y, width: width, height: height)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: height / 2, yRadius: height / 2)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.3).setFill()
        track.fill()

        // Fill
        let fillWidth = width * CGFloat(percent) / 100.0
        guard fillWidth > 0 else { return }
        let fillRect = NSRect(x: x, y: y, width: fillWidth, height: height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: height / 2, yRadius: height / 2)
        tint.setFill()
        fill.fill()
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
