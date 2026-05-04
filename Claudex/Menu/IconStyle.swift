import Foundation

enum IconStyle: String, CaseIterable, Identifiable {
    case gauge
    case minimal
    case circular
    case battery
    case segments
    case dualBar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gauge:    return "Gauge"
        case .minimal:  return "Minimal"
        case .circular: return "Circular"
        case .battery:  return "Battery"
        case .segments: return "Segments"
        case .dualBar:  return "Dual Bar"
        }
    }

    var description: String {
        switch self {
        case .gauge:    return "Half-circle gauge with moving needle"
        case .minimal:  return "Just the highest % as text"
        case .circular: return "Ring with % inside"
        case .battery:  return "Battery-style horizontal bar with %"
        case .segments: return "5 vertical bars filling left-to-right"
        case .dualBar:  return "Two stacked bars: session on top, weekly below"
        }
    }
}
