import Foundation
import SwiftData

enum PackingCategory: String, Codable, CaseIterable {
    case clothing      = "Clothing"
    case toiletries    = "Toiletries"
    case electronics   = "Electronics"
    case documents     = "Documents"
    case health        = "Health"
    case entertainment = "Entertainment"
    case other         = "Other"

    var emoji: String {
        switch self {
        case .clothing:      return "👕"
        case .toiletries:    return "🧴"
        case .electronics:   return "🔌"
        case .documents:     return "📄"
        case .health:        return "💊"
        case .entertainment: return "🎮"
        case .other:         return "📦"
        }
    }
}

@Model
final class PackingItem {
    var id: String
    var tripId: String
    var name: String
    var category: String            // PackingCategory.rawValue
    var quantity: Int
    var isPacked: Bool
    var isEssential: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        tripId: String,
        name: String,
        category: String,
        quantity: Int = 1,
        isPacked: Bool = false,
        isEssential: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.tripId = tripId
        self.name = name
        self.category = category
        self.quantity = quantity
        self.isPacked = isPacked
        self.isEssential = isEssential
        self.createdAt = createdAt
    }
}

// MARK: - Default packing templates

extension PackingItem {
    static func defaults(for tripId: String, type: String = "city") -> [PackingItem] {
        let items: [(String, String, Bool)] = [
            ("Passport", PackingCategory.documents.rawValue, true),
            ("Flight tickets", PackingCategory.documents.rawValue, true),
            ("Travel insurance", PackingCategory.documents.rawValue, true),
            ("Phone charger", PackingCategory.electronics.rawValue, true),
            ("Headphones", PackingCategory.electronics.rawValue, false),
            ("Toothbrush", PackingCategory.toiletries.rawValue, true),
            ("Shampoo", PackingCategory.toiletries.rawValue, false),
            ("Sunscreen", PackingCategory.health.rawValue, false),
            ("Medications", PackingCategory.health.rawValue, true),
            ("T-shirts", PackingCategory.clothing.rawValue, false),
            ("Underwear", PackingCategory.clothing.rawValue, false),
            ("Comfortable shoes", PackingCategory.clothing.rawValue, false),
        ]
        return items.map {
            PackingItem(tripId: tripId, name: $0.0, category: $0.1, isEssential: $0.2)
        }
    }
}
