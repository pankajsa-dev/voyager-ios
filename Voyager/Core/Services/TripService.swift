import Foundation
import Supabase

// MARK: - DTO

struct TripDTO: Codable, Identifiable, Hashable {
    let id: String
    var userId: String?             // owner's user_id
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
    var latitude: Double?
    var longitude: Double?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, status, notes, currency, latitude, longitude
        case userId           = "user_id"
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
    var trips: [TripDTO]              = []
    var isLoading                     = false
    var errorMessage: String?
    private(set) var currentUserId:   String     = ""
    private(set) var sharedTripIds:   Set<String> = []  // trips invited into (not owned)

    private let db   = SupabaseManager.shared.database
    private let auth = SupabaseManager.shared.auth

    // Shared ISO8601 encoder — ensures Date fields in ItineraryDay/Activity
    // are stored as strings that Supabase can round-trip cleanly.
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // ── Fetch all trips the current user owns OR is a member of ──────────
    func fetchAll() async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        await MainActor.run { isLoading = true; errorMessage = nil; currentUserId = userId }
        do {
            // Own trips
            async let ownFetch: [TripDTO] = db
                .from(Table.trips)
                .select()
                .eq("user_id", value: userId)
                .order("start_date", ascending: true)
                .execute()
                .value

            // Trips I've been invited into and accepted
            struct MemberRow: Codable { let tripId: String; enum CodingKeys: String, CodingKey { case tripId = "trip_id" } }
            async let memberFetch: [MemberRow] = db
                .from(Table.tripMembers)
                .select("trip_id")
                .eq("user_id", value: userId)
                .eq("status", value: "accepted")
                .execute()
                .value

            let (ownTrips, memberRows) = try await (ownFetch, memberFetch)
            let invitedIds = memberRows.map { $0.tripId }

            var sharedTrips: [TripDTO] = []
            if !invitedIds.isEmpty {
                sharedTrips = try await db
                    .from(Table.trips)
                    .select()
                    .in("id", values: invitedIds)
                    .execute()
                    .value
            }

            var seen = Set<String>()
            let all = (ownTrips + sharedTrips)
                .filter  { seen.insert($0.id).inserted }
                .sorted  { $0.startDate < $1.startDate }

            await MainActor.run {
                trips        = all
                sharedTripIds = Set(invitedIds)
                isLoading    = false
            }
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
        currency: String = "USD",
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> TripDTO {
        let userId = try await auth.session.user.id.uuidString
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        var payload: [String: AnyJSON] = [
            "user_id":          .string(userId),
            "title":            .string(title),
            "destination_name": .string(destinationName),
            "destination_id":   destinationId.map { .string($0) } ?? .null,
            "start_date":       .string(fmt.string(from: startDate)),
            "end_date":         .string(fmt.string(from: endDate)),
            "total_budget":     .double(totalBudget),
            "currency":         .string(currency),
        ]
        if let lat = latitude  { payload["latitude"]  = .double(lat) }
        if let lng = longitude { payload["longitude"] = .double(lng) }
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
        currency: String,
        notes: String
    ) async throws {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let payload: [String: AnyJSON] = [
            "title":            .string(title),
            "destination_name": .string(destinationName),
            "start_date":       .string(fmt.string(from: startDate)),
            "end_date":         .string(fmt.string(from: endDate)),
            "total_budget":     .double(totalBudget),
            "currency":         .string(currency),
            "notes":            .string(notes),
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
                trips[idx].notes           = notes
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

    // ── Fetch a single trip by ID ─────────────────────────────────────────
    // No user_id filter: RLS handles access for both owners and accepted members.
    func fetchSingle(tripId: String) async throws -> TripDTO? {
        let results: [TripDTO] = try await db
            .from(Table.trips)
            .select()
            .eq("id", value: tripId)
            .limit(1)
            .execute()
            .value
        if let trip = results.first, let idx = trips.firstIndex(where: { $0.id == tripId }) {
            await MainActor.run { trips[idx] = trip }
        }
        return results.first
    }

    // ── Delete trip ───────────────────────────────────────────────────────
    func delete(tripId: String) async throws {
        try await db.from(Table.trips).delete().eq("id", value: tripId).execute()
        await MainActor.run { trips.removeAll { $0.id == tripId } }
    }
}
