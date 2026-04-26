import Foundation
import Supabase

// MARK: - DTO

struct BookingDTO: Codable, Identifiable {
    let id: String
    var tripId: String?
    var type: String
    var status: String
    var title: String
    var providerName: String
    var bookingReference: String
    var confirmationNumber: String
    var startDate: String
    var endDate: String?
    var totalPrice: Double
    var currency: String
    var passengerNames: [String]
    var notes: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, status, title, currency, notes
        case tripId               = "trip_id"
        case providerName         = "provider_name"
        case bookingReference     = "booking_reference"
        case confirmationNumber   = "confirmation_number"
        case startDate            = "start_date"
        case endDate              = "end_date"
        case totalPrice           = "total_price"
        case passengerNames       = "passenger_names"
        case createdAt            = "created_at"
    }
}

// MARK: - Service

@Observable
final class BookingService {
    var bookings: [BookingDTO] = []
    var isLoading              = false
    var errorMessage: String?

    private let db   = SupabaseManager.shared.database
    private let auth = SupabaseManager.shared.auth

    func fetchAll(tripId: String? = nil) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            // Build filter phase first (eq), then add order so we stay on
            // PostgrestFilterBuilder until all filters are applied.
            var filterQuery = db.from(Table.bookings)
                .select()
                .eq("user_id", value: userId)
            if let tid = tripId { filterQuery = filterQuery.eq("trip_id", value: tid) }
            let results: [BookingDTO] = try await filterQuery
                .order("start_date", ascending: true)
                .execute()
                .value
            await MainActor.run { bookings = results; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = "Could not load bookings."; isLoading = false }
        }
    }

    func create(
        type: BookingType,
        title: String,
        providerName: String = "",
        bookingReference: String = "",
        startDate: Date,
        endDate: Date? = nil,
        totalPrice: Double = 0,
        currency: String = "USD",
        tripId: String? = nil,
        notes: String = ""
    ) async throws -> BookingDTO {
        let userId = try await auth.session.user.id.uuidString
        let fmt = ISO8601DateFormatter()
        var payload: [String: AnyJSON] = [
            "user_id":           .string(userId),
            "type":              .string(type.rawValue),
            "title":             .string(title),
            "provider_name":     .string(providerName),
            "booking_reference": .string(bookingReference),
            "start_date":        .string(fmt.string(from: startDate)),
            "total_price":       .double(totalPrice),
            "currency":          .string(currency),
            "notes":             .string(notes),
        ]
        if let tid = tripId  { payload["trip_id"]  = .string(tid) }
        if let ed  = endDate { payload["end_date"] = .string(fmt.string(from: ed)) }

        let created: [BookingDTO] = try await db
            .from(Table.bookings).insert(payload).select().execute().value
        guard let booking = created.first else { throw URLError(.badServerResponse) }
        await MainActor.run { bookings.insert(booking, at: 0) }
        return booking
    }

    func updateStatus(bookingId: String, status: BookingStatus) async throws {
        let payload: [String: AnyJSON] = ["status": .string(status.rawValue)]
        try await db.from(Table.bookings).update(payload).eq("id", value: bookingId).execute()
        await MainActor.run {
            if let idx = bookings.firstIndex(where: { $0.id == bookingId }) {
                bookings[idx].status = status.rawValue
            }
        }
    }

    func delete(bookingId: String) async throws {
        try await db.from(Table.bookings).delete().eq("id", value: bookingId).execute()
        await MainActor.run { bookings.removeAll { $0.id == bookingId } }
    }
}
