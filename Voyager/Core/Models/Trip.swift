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

struct ItineraryDay: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var dayNumber: Int
    var date: Date
    var activities: [ItineraryActivity]
}

struct ItineraryActivity: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
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
}

enum ActivityCategory: String, Codable, CaseIterable {
    case sightseeing = "Sightseeing"
    case food        = "Food & Drink"
    case transport   = "Transport"
    case accommodation = "Accommodation"
    case activity    = "Activity"
    case shopping    = "Shopping"
    case other       = "Other"

    var emoji: String {
        switch self {
        case .sightseeing:    return "🏛️"
        case .food:           return "🍽️"
        case .transport:      return "🚌"
        case .accommodation:  return "🏨"
        case .activity:       return "🎯"
        case .shopping:       return "🛍️"
        case .other:          return "📌"
        }
    }
}
