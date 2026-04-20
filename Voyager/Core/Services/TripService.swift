import Foundation
import Supabase

// MARK: - DTO

struct TripDTO: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var destinationId: String?
    var destinationName: String
    var coverImageUrl: String?
    var startDate: String           // "yyyy-MM-dd"
    var endDate: String
    var status: String
    var notes: String
    var itineraryDays: [ItineraryDay]
    var totalBudget: Double
    var currency: String
    var isShared: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, status, notes, currency
        case destinationId    = "destination_id"
        case destinationName  = "destination_name"
        case coverImageUrl    = "cover_image_url"
        case startDate        = "start_date"
        case endDate          = "end_date"
        case itineraryDays    = "itinerary_days"
        case totalBudget      = "total_budget"
        case isShared         = "is_shared"
        case createdAt        = "created_at"
    }
}

// MARK: - Service

@Observable
final class TripService {
    var trips: [TripDTO]   = []
    var isLoading          = false
    var errorMessage: String?

    private let db   = SupabaseManager.shared.database
    private let auth = SupabaseManager.shared.auth

    // Shared ISO8601 encoder — ensures Date fields in ItineraryDay/Activity
    // are stored as strings that Supabase can round-trip cleanly.
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // ── Fetch all user trips ──────────────────────────────────────────────
    func fetchAll() async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let results: [TripDTO] = try await db
                .from(Table.trips)
                .select()
                .eq("user_id", value: userId)
                .order("start_date", ascending: true)
                .execute()
                .value
            await MainActor.run { trips = results; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = "Could not load trips."; isLoading = false }
        }
    }

    // ── Create trip ───────────────────────────────────────────────────────
    func create(
        title: String,
        destinationName: String,
        destinationId: String? = nil,
        startDate: Date,
        endDate: Date,
        totalBudget: Double = 0,
        currency: String = "USD"
    ) async throws -> TripDTO {
        let userId = try await auth.session.user.id.uuidString
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let payload: [String: AnyJSON] = [
            "user_id":          .string(userId),
            "title":            .string(title),
            "destination_name": .string(destinationName),
            "destination_id":   destinationId.map { .string($0) } ?? .null,
            "start_date":       .string(fmt.string(from: startDate)),
            "end_date":         .string(fmt.string(from: endDate)),
            "total_budget":     .double(totalBudget),
            "currency":         .string(currency),
        ]
        let created: [TripDTO] = try await db
            .from(Table.trips)
            .insert(payload)
            .select()
            .execute()
            .value
        guard let trip = created.first else { throw URLError(.badServerResponse) }
        await MainActor.run { trips.insert(trip, at: 0) }
        return trip
    }

    // ── Update itinerary days ─────────────────────────────────────────────
    func updateItinerary(tripId: String, days: [ItineraryDay]) async throws {
        // Encode with ISO8601 dates so Supabase JSONB stores strings, not raw doubles
        let data = try Self.jsonEncoder.encode(days)
        let itineraryJSON = try JSONDecoder().decode(AnyJSON.self, from: data)
        let payload: [String: AnyJSON] = [
            "itinerary_days": itineraryJSON,
            "updated_at":     .string(ISO8601DateFormatter().string(from: .now)),
        ]
        try await db
            .from(Table.trips)
            .update(payload)
            .eq("id", value: tripId)
            .execute()
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            await MainActor.run { trips[idx].itineraryDays = days }
        }
    }

    // ── Update status ─────────────────────────────────────────────────────
    func updateStatus(tripId: String, status: TripStatus) async throws {
        let payload: [String: AnyJSON] = ["status": .string(status.rawValue)]
        try await db
            .from(Table.trips)
            .update(payload)
            .eq("id", value: tripId)
            .execute()
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            await MainActor.run { trips[idx].status = status.rawValue }
        }
    }

    // ── Update trip details (title, destination, dates, budget) ──────────
    func updateTripDetails(
        tripId: String,
        title: String,
        destinationName: String,
        startDate: Date,
        endDate: Date,
        totalBudget: Double,
        currency: String
    ) async throws {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let payload: [String: AnyJSON] = [
            "title":            .string(title),
            "destination_name": .string(destinationName),
            "start_date":       .string(fmt.string(from: startDate)),
            "end_date":         .string(fmt.string(from: endDate)),
            "total_budget":     .double(totalBudget),
            "currency":         .string(currency),
            "updated_at":       .string(ISO8601DateFormatter().string(from: .now)),
        ]
        try await db.from(Table.trips).update(payload).eq("id", value: tripId).execute()
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            await MainActor.run {
                trips[idx].title           = title
                trips[idx].destinationName = destinationName
                trips[idx].startDate       = fmt.string(from: startDate)
                trips[idx].endDate         = fmt.string(from: endDate)
                trips[idx].totalBudget     = totalBudget
                trips[idx].currency        = currency
            }
        }
    }

    // ── Upload and set cover image ────────────────────────────────────────
    func updateCoverImage(tripId: String, imageData: Data) async throws -> String {
        let path = "trips/\(tripId)/cover.jpg"
        var urlString: String

        if CloudflareR2Config.isConfigured {
            urlString = try await CloudflareR2Service.shared.uploadImage(
                imageData, path: path, contentType: "image/jpeg"
            )
        } else {
            try await SupabaseManager.shared.storage.upload(
                path, data: imageData,
                options: .init(contentType: "image/jpeg", upsert: true)
            )
            let url = try SupabaseManager.shared.storage.getPublicURL(path: path)
            urlString = url.absoluteString
        }

        let payload: [String: AnyJSON] = [
            "cover_image_url": .string(urlString),
            "updated_at":      .string(ISO8601DateFormatter().string(from: .now)),
        ]
        try await db.from(Table.trips).update(payload).eq("id", value: tripId).execute()
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            await MainActor.run { trips[idx].coverImageUrl = urlString }
        }
        return urlString
    }

    // ── Delete trip ───────────────────────────────────────────────────────
    func delete(tripId: String) async throws {
        try await db.from(Table.trips).delete().eq("id", value: tripId).execute()
        await MainActor.run { trips.removeAll { $0.id == tripId } }
    }
}
