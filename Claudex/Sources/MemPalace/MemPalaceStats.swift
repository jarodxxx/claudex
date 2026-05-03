import Foundation

struct MemPalaceStats: Codable, Equatable {
    let totalDrawers: Int
    let wings: [MemPalaceWing]

    enum CodingKeys: String, CodingKey {
        case totalDrawers = "total_drawers"
        case wings
    }
}

struct MemPalaceWing: Codable, Equatable {
    let name: String
    let rooms: [MemPalaceRoom]

    var totalDrawers: Int { rooms.reduce(0) { $0 + $1.drawers } }
}

struct MemPalaceRoom: Codable, Equatable {
    let name: String
    let drawers: Int
}
