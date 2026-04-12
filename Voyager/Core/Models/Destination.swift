import Foundation
import SwiftData

enum DestinationCategory: String, Codable, CaseIterable {
    case beach      = "Beach"
    case mountains  = "Mountains"
    case city       = "City"
    case adventure  = "Adventure"
    case culture    = "Culture"
    case wellness   = "Wellness"
    case nature     = "Nature"
    case desert     = "Desert"

    var emoji: String {
        switch self {
        case .beach:     return "🏖️"
        case .mountains: return "⛰️"
        case .city:      return "🏙️"
        case .adventure: return "🧗"
        case .culture:   return "🏛️"
        case .wellness:  return "🧘"
        case .nature:    return "🌿"
        case .desert:    return "🏜️"
        }
    }
}

@Model
final class Destination {
    var id: String
    var name: String
    var country: String
    var countryCode: String         // ISO 3166-1 alpha-2
    var continent: String
    var tagline: String
    var overview: String
    var category: String            // DestinationCategory.rawValue
    var tags: [String]              // e.g. ["Nightlife", "Food", "History"]
    var imageURLs: [String]         // hero + gallery
    var rating: Double              // 0–5
    var reviewCount: Int
    var latitude: Double
    var longitude: Double
    var bestMonths: [Int]           // 1–12
    var averageBudgetPerDay: Double // USD
    var currency: String            // ISO currency code
    var language: String
    var timezone: String
    var isSaved: Bool
    var createdAt: Date

    var heroImageURL: String? { imageURLs.first }

    init(
        id: String = UUID().uuidString,
        name: String,
        country: String,
        countryCode: String,
        continent: String,
        tagline: String = "",
        overview: String = "",
        category: String,
        tags: [String] = [],
        imageURLs: [String] = [],
        rating: Double = 0,
        reviewCount: Int = 0,
        latitude: Double,
        longitude: Double,
        bestMonths: [Int] = [],
        averageBudgetPerDay: Double = 0,
        currency: String = "USD",
        language: String = "",
        timezone: String = "",
        isSaved: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.countryCode = countryCode
        self.continent = continent
        self.tagline = tagline
        self.overview = overview
        self.category = category
        self.tags = tags
        self.imageURLs = imageURLs
        self.rating = rating
        self.reviewCount = reviewCount
        self.latitude = latitude
        self.longitude = longitude
        self.bestMonths = bestMonths
        self.averageBudgetPerDay = averageBudgetPerDay
        self.currency = currency
        self.language = language
        self.timezone = timezone
        self.isSaved = isSaved
        self.createdAt = createdAt
    }
}
