import Foundation
import SwiftData

enum TripStatus: String, Codable, CaseIterable {
    case upcoming  = "Upcoming"
    case active    = "Active"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var color: String {
        switch self {
        case .upcoming:  return "voyagerPrimary"
        case .active:    return "voyagerSuccess"
        case .completed: return "voyagerTextSecondary"
        case .cancelled: return "voyagerError"
        }
    }
}

@Model
final class Trip {
    var id: String
    var title: String
    var destinationId: String
    var destinationName: String
    var coverImageURL: String?
    var startDate: Date
    var endDate: Date
    var status: String                  // TripStatus.rawValue
    var notes: String
    var itineraryDays: [ItineraryDay]
    var totalBudget: Double
    var currency: String
    var isShared: Bool
    var createdAt: Date

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var daysUntilTrip: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: startDate).day ?? 0)
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        destinationId: String,
        destinationName: String,
        coverImageURL: String? = nil,
        startDate: Date,
        endDate: Date,
        status: String = TripStatus.upcoming.rawValue,
        notes: String = "",
        itineraryDays: [ItineraryDay] = [],
        totalBudget: Double = 0,
        currency: String = "USD",
        isShared: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.destinationId = destinationId
        self.destinationName = destinationName
        self.coverImageURL = coverImageURL
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.notes = notes
        self.itineraryDays = itineraryDays
        self.totalBudget = totalBudget
        self.currency = currency
        self.isShared = isShared
        self.createdAt = createdAt
    }
}

// MARK: - Itinerary

struct ItineraryDay: Identifiable, Hashable {
    var id: String
    var dayNumber: Int
    var date: Date
    var activities: [ItineraryActivity]

    init(id: String = UUID().uuidString, dayNumber: Int, date: Date, activities: [ItineraryActivity] = []) {
        self.id = id
        self.dayNumber = dayNumber
        self.date = date
        self.activities = activities
    }
}

// Custom Codable: dates stored as ISO8601 strings so Supabase JSONB round-trips cleanly
extension ItineraryDay: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, dayNumber, date, activities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        dayNumber  = try c.decode(Int.self,    forKey: .dayNumber)
        activities = try c.decode([ItineraryActivity].self, forKey: .activities)
        date       = Self.decodeDate(from: c, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,         forKey: .id)
        try c.encode(dayNumber,  forKey: .dayNumber)
        try c.encode(isoString(from: date), forKey: .date)
        try c.encode(activities, forKey: .activities)
    }

    // Accepts both ISO8601 strings (preferred) and legacy TimeInterval doubles
    private static func decodeDate(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date {
        if let str = try? c.decode(String.self, forKey: key) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: str) { return d }
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: str) { return d }
        }
        if let interval = try? c.decode(Double.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: interval)
        }
        return Date()
    }
}

struct ItineraryActivity: Identifiable, Hashable {
    var id: String
    var title: String
    var description: String
    var category: ActivityCategory
    var startTime: Date?
    var durationMinutes: Int?
    var location: String
    var latitude: Double?
    var longitude: Double?
    var estimatedCost: Double
    var currency: String
    var bookingReference: String?
    var notes: String
    var isCompleted: Bool
    var photoURLs: [String]?

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        category: ActivityCategory,
        startTime: Date? = nil,
        durationMinutes: Int? = nil,
        location: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        estimatedCost: Double = 0,
        currency: String = "USD",
        bookingReference: String? = nil,
        notes: String = "",
        isCompleted: Bool = false,
        photoURLs: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.estimatedCost = estimatedCost
        self.currency = currency
        self.bookingReference = bookingReference
        self.notes = notes
        self.isCompleted = isCompleted
        self.photoURLs = photoURLs
    }
}

// Custom Codable: startTime encoded as ISO8601 string
extension ItineraryActivity: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, startTime, durationMinutes
        case location, latitude, longitude, estimatedCost, currency
        case bookingReference, notes, isCompleted, photoURLs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self,           forKey: .id)
        title           = try c.decode(String.self,           forKey: .title)
        description     = (try? c.decode(String.self,         forKey: .description))  ?? ""
        category        = try c.decode(ActivityCategory.self, forKey: .category)
        durationMinutes = try? c.decode(Int.self,             forKey: .durationMinutes)
        location        = (try? c.decode(String.self,         forKey: .location))      ?? ""
        latitude        = try? c.decode(Double.self,          forKey: .latitude)
        longitude       = try? c.decode(Double.self,          forKey: .longitude)
        estimatedCost   = (try? c.decode(Double.self,         forKey: .estimatedCost)) ?? 0
        currency        = (try? c.decode(String.self,         forKey: .currency))      ?? "USD"
        bookingReference = try? c.decode(String.self,         forKey: .bookingReference)
        notes           = (try? c.decode(String.self,         forKey: .notes))         ?? ""
        isCompleted     = (try? c.decode(Bool.self,           forKey: .isCompleted))   ?? false
        photoURLs       = try? c.decode([String].self,        forKey: .photoURLs)
        startTime       = Self.decodeOptionalDate(from: c, forKey: .startTime)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,              forKey: .id)
        try c.encode(title,           forKey: .title)
        try c.encode(description,     forKey: .description)
        try c.encode(category,        forKey: .category)
        try c.encodeIfPresent(durationMinutes,  forKey: .durationMinutes)
        try c.encode(location,        forKey: .location)
        try c.encodeIfPresent(latitude,         forKey: .latitude)
        try c.encodeIfPresent(longitude,        forKey: .longitude)
        try c.encode(estimatedCost,   forKey: .estimatedCost)
        try c.encode(currency,        forKey: .currency)
        try c.encodeIfPresent(bookingReference, forKey: .bookingReference)
        try c.encode(notes,           forKey: .notes)
        try c.encode(isCompleted,     forKey: .isCompleted)
        try c.encodeIfPresent(photoURLs,        forKey: .photoURLs)
        if let t = startTime {
            try c.encode(isoString(from: t), forKey: .startTime)
        } else {
            try c.encodeNil(forKey: .startTime)
        }
    }

    private static func decodeOptionalDate(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let str = try? c.decode(String.self, forKey: key) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: str) { return d }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: str)
        }
        if let interval = try? c.decode(Double.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: interval)
        }
        return nil
    }
}

// MARK: - Helpers

private func isoString(from date: Date) -> String {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.string(from: date)
}

enum ActivityCategory: String, Codable, CaseIterable {
    case sightseeing    = "Sightseeing"
    case food           = "Food & Drink"
    case transport      = "Transport"
    case accommodation  = "Accommodation"
    case activity       = "Activity"
    case shopping       = "Shopping"
    case other          = "Other"

    var emoji: String {
        switch self {
        case .sightseeing:   return "🏛️"
        case .food:          return "🍽️"
        case .transport:     return "🚌"
        case .accommodation: return "🏨"
        case .activity:      return "🎯"
        case .shopping:      return "🛍️"
        case .other:         return "📌"
        }
    }
}
