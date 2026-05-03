import Foundation

enum IconStyle: String, CaseIterable, Identifiable {
    case gauge
    case minimal
    case circular
    case battery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gauge:    return "Gauge"
        case .minimal:  return "Minimal"
        case .circular: return "Circular"
        case .battery:  return "Battery"
        }
    }

    var description: String {
        switch self {
        case .gauge:    return "SF Symbol that fills as usage rises"
        case .minimal:  return "Just the highest % as text"
        case .circular: return "Ring with % inside"
        case .battery:  return "Battery-style horizontal bar with %"
        }
    }
}
