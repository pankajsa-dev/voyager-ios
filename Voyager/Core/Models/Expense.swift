import Foundation
import SwiftData

enum ExpenseCategory: String, Codable, CaseIterable {
    case food          = "Food"
    case transport     = "Transport"
    case accommodation = "Accommodation"
    case activities    = "Activities"
    case shopping      = "Shopping"
    case other         = "Other"

    var emoji: String {
        switch self {
        case .food:          return "🍔"
        case .transport:     return "🚌"
        case .accommodation: return "🏨"
        case .activities:    return "🎯"
        case .shopping:      return "🛍️"
        case .other:         return "💸"
        }
    }
}

@Model
final class Expense {
    var id: String
    var tripId: String
    var title: String
    var amount: Double
    var currency: String
    var category: String            // ExpenseCategory.rawValue
    var date: Date
    var notes: String
    var receiptImageURL: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        tripId: String,
        title: String,
        amount: Double,
        currency: String = "USD",
        category: String,
        date: Date = .now,
        notes: String = "",
        receiptImageURL: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.tripId = tripId
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.date = date
        self.notes = notes
        self.receiptImageURL = receiptImageURL
        self.createdAt = createdAt
    }
}
