import Testing
import Foundation
@testable import Voyager

// MARK: - Codable round-trip tests for core models
//
// These catch decoding regressions that would cause crashes when reading
// itinerary data back from Supabase JSONB.

@Suite("Model Codable round-trips")
struct ModelCodableTests {

    // MARK: - ItineraryActivity

    @Test("ItineraryActivity round-trips all fields through JSON")
    func activity_fullRoundTrip() throws {
        let original = ItineraryActivity(
            id:               "act-001",
            title:            "Visit Eiffel Tower",
            description:      "Iconic iron lattice tower",
            category:         .sightseeing,
            startTime:        ISO8601DateFormatter().date(from: "2027-06-15T10:00:00Z"),
            durationMinutes:  120,
            location:         "Champ de Mars, Paris",
            latitude:         48.8584,
            longitude:        2.2945,
            estimatedCost:    28.0,
            currency:         "EUR",
            bookingReference: "ET-XYZ",
            notes:            "Pre-book tickets",
            isCompleted:      false,
            photoURLs:        ["https://example.com/photo.jpg"]
        )

        let encoder = TripService.jsonEncoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data   = try encoder.encode(original)
        let decoded = try decoder.decode(ItineraryActivity.self, from: data)

        #expect(decoded.id               == original.id)
        #expect(decoded.title            == original.title)
        #expect(decoded.description      == original.description)
        #expect(decoded.category         == original.category)
        #expect(decoded.durationMinutes  == original.durationMinutes)
        #expect(decoded.location         == original.location)
        #expect(decoded.latitude         == original.latitude)
        #expect(decoded.longitude        == original.longitude)
        #expect(decoded.estimatedCost    == original.estimatedCost)
        #expect(decoded.currency         == original.currency)
        #expect(decoded.bookingReference == original.bookingReference)
        #expect(decoded.notes            == original.notes)
        #expect(decoded.isCompleted      == original.isCompleted)
        #expect(decoded.photoURLs        == original.photoURLs)
    }

    @Test("ItineraryActivity with nil optional fields round-trips cleanly")
    func activity_nilOptionals() throws {
        let original = ItineraryActivity(
            id:       "act-min",
            title:    "Lunch",
            category: .food
        )
        let data    = try TripService.jsonEncoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ItineraryActivity.self, from: data)

        #expect(decoded.startTime        == nil)
        #expect(decoded.durationMinutes  == nil)
        #expect(decoded.latitude         == nil)
        #expect(decoded.longitude        == nil)
        #expect(decoded.bookingReference == nil)
        #expect(decoded.photoURLs        == nil)
    }

    @Test("ItineraryActivity startTime is encoded and decoded as ISO8601 string")
    func activity_startTimeIsISO() throws {
        let date = ISO8601DateFormatter().date(from: "2027-08-20T14:30:00Z")!
        let activity = ItineraryActivity(id: "a1", title: "Dinner", category: .food,
                                         startTime: date)
        let data = try TripService.jsonEncoder.encode(activity)

        // The encoded JSON should store startTime as an ISO8601 string, not a Double
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let startTimeValue = json["startTime"]
        #expect(startTimeValue is String, "startTime should be encoded as a String, not a number")
    }

    // MARK: - ItineraryDay

    @Test("ItineraryDay round-trips with multiple activities")
    func day_roundTrip() throws {
        let a1 = ItineraryActivity(id: "a1", title: "Breakfast", category: .food)
        let a2 = ItineraryActivity(id: "a2", title: "Museum",    category: .sightseeing)
        let date = ISO8601DateFormatter().date(from: "2027-06-15T00:00:00Z")!
        let day  = ItineraryDay(id: "d1", dayNumber: 1, date: date, activities: [a1, a2])

        let data    = try TripService.jsonEncoder.encode(day)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ItineraryDay.self, from: data)

        #expect(decoded.id         == "d1")
        #expect(decoded.dayNumber  == 1)
        #expect(decoded.activities.count == 2)
        #expect(decoded.activities[0].title == "Breakfast")
        #expect(decoded.activities[1].title == "Museum")
    }

    @Test("ItineraryDay date encodes as ISO8601 string (not TimeInterval)")
    func day_dateEncodedAsString() throws {
        let date = ISO8601DateFormatter().date(from: "2027-07-04T00:00:00Z")!
        let day  = ItineraryDay(id: "d2", dayNumber: 2, date: date)
        let data = try TripService.jsonEncoder.encode(day)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let dateValue = json["date"]
        #expect(dateValue is String, "date should be encoded as an ISO8601 string")
    }

    @Test("ItineraryDay decodes legacy TimeInterval date without crashing")
    func day_decodeLegacyTimeInterval() throws {
        // Simulate a record written before the ISO migration: date as TimeInterval
        let timeInterval: TimeInterval = 1_000_000_000   // some past timestamp
        let json = """
        {
          "id": "legacy-day",
          "dayNumber": 3,
          "date": \(timeInterval),
          "activities": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        let decoded = try decoder.decode(ItineraryDay.self, from: data)
        #expect(decoded.id == "legacy-day")
        #expect(decoded.dayNumber == 3)
        // Date should be valid (non-nil / non-zero reference)
        #expect(decoded.date.timeIntervalSince1970 > 0)
    }

    @Test("Empty itinerary (no days) encodes to an empty JSON array")
    func emptyItinerary_encodesAsEmptyArray() throws {
        let days: [ItineraryDay] = []
        let data = try TripService.jsonEncoder.encode(days)
        let json = try JSONSerialization.jsonObject(with: data) as! [Any]
        #expect(json.isEmpty)
    }

    // MARK: - ActivityCategory

    @Test("ActivityCategory raw values are stable")
    func activityCategory_rawValues() {
        #expect(ActivityCategory.sightseeing.rawValue  == "Sightseeing")
        #expect(ActivityCategory.food.rawValue         == "Food & Drink")
        #expect(ActivityCategory.transport.rawValue    == "Transport")
        #expect(ActivityCategory.accommodation.rawValue == "Accommodation")
        #expect(ActivityCategory.activity.rawValue     == "Activity")
        #expect(ActivityCategory.shopping.rawValue     == "Shopping")
        #expect(ActivityCategory.other.rawValue        == "Other")
    }

    @Test("ActivityCategory emoji is non-empty for all cases")
    func activityCategory_emojiNonEmpty() {
        for category in ActivityCategory.allCases {
            #expect(!category.emoji.isEmpty)
        }
    }

    // MARK: - TripStatus

    @Test("TripStatus raw values are stable")
    func tripStatus_rawValues() {
        #expect(TripStatus.upcoming.rawValue   == "Upcoming")
        #expect(TripStatus.active.rawValue     == "Active")
        #expect(TripStatus.completed.rawValue  == "Completed")
        #expect(TripStatus.cancelled.rawValue  == "Cancelled")
    }

    @Test("TripStatus covers all 4 cases")
    func tripStatus_allCasesCount() {
        #expect(TripStatus.allCases.count == 4)
    }

    // MARK: - DestinationCategory

    @Test("DestinationCategory emoji is non-empty for all cases")
    func destinationCategory_emojiNonEmpty() {
        for category in DestinationCategory.allCases {
            #expect(!category.emoji.isEmpty)
        }
    }

    @Test("DestinationCategory raw values are stable")
    func destinationCategory_rawValues() {
        #expect(DestinationCategory.beach.rawValue     == "Beach")
        #expect(DestinationCategory.mountains.rawValue == "Mountains")
        #expect(DestinationCategory.city.rawValue      == "City")
        #expect(DestinationCategory.adventure.rawValue == "Adventure")
        #expect(DestinationCategory.culture.rawValue   == "Culture")
        #expect(DestinationCategory.wellness.rawValue  == "Wellness")
        #expect(DestinationCategory.nature.rawValue    == "Nature")
        #expect(DestinationCategory.desert.rawValue    == "Desert")
    }
}
