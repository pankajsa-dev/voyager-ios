import Foundation
import SwiftData

enum BookingType: String, Codable, CaseIterable {
    case flight        = "Flight"
    case hotel         = "Hotel"
    case experience    = "Experience"
    case carRental     = "Car Rental"
    case transfer      = "Transfer"
    case tour          = "Tour"

    var emoji: String {
        switch self {
        case .flight:      return "✈️"
        case .hotel:       return "🏨"
        case .experience:  return "🎟️"
        case .carRental:   return "🚗"
        case .transfer:    return "🚕"
        case .tour:        return "🗺️"
        }
    }
}

enum BookingStatus: String, Codable, CaseIterable {
    case confirmed = "Confirmed"
    case pending   = "Pending"
    case cancelled = "Cancelled"
    case completed = "Completed"
}

@Model
final class Booking {
    var id: String
    var tripId: String?
    var type: String                // BookingType.rawValue
    var status: String              // BookingStatus.rawValue
    var title: String               // e.g. "London Heathrow → JFK"
    var providerName: String        // e.g. "British Airways"
    var bookingReference: String
    var confirmationNumber: String
    var startDate: Date
    var endDate: Date?
    var totalPrice: Double
    var currency: String
    var passengerNames: [String]
    var documentURLs: [String]      // PDFs / boarding passes stored locally or in cloud
    var notes: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        tripId: String? = nil,
        type: String,
        status: String = BookingStatus.confirmed.rawValue,
        title: String,
        providerName: String = "",
        bookingReference: String = "",
        confirmationNumber: String = "",
        startDate: Date,
        endDate: Date? = nil,
        totalPrice: Double = 0,
        currency: String = "USD",
        passengerNames: [String] = [],
        documentURLs: [String] = [],
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.tripId = tripId
        self.type = type
        self.status = status
        self.title = title
        self.providerName = providerName
        self.bookingReference = bookingReference
        self.confirmationNumber = confirmationNumber
        self.startDate = startDate
        self.endDate = endDate
        self.totalPrice = totalPrice
        self.currency = currency
        self.passengerNames = passengerNames
        self.documentURLs = documentURLs
        self.notes = notes
        self.createdAt = createdAt
    }
}
