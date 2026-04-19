import Foundation
import Supabase

// MARK: - DTO (matches Supabase column names)

struct DestinationDTO: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
    let countryCode: String
    let continent: String
    let tagline: String
    let overview: String
    let category: String
    let tags: [String]
    let imageUrls: [String]
    let rating: Double
    let reviewCount: Int
    let latitude: Double
    let longitude: Double
    let bestMonths: [Int]
    let avgBudgetPerDay: Double
    let currency: String
    let language: String
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case id, name, country, continent, tagline, overview, category,
             tags, rating, language, timezone, currency, latitude, longitude
        case countryCode      = "country_code"
        case imageUrls        = "image_urls"
        case reviewCount      = "review_count"
        case bestMonths       = "best_months"
        case avgBudgetPerDay  = "avg_budget_per_day"
    }
}

// MARK: - Service

@Observable
final class DestinationService {
    var destinations: [DestinationDTO]  = []
    var saved: Set<String>              = []   // destination IDs saved by user
    var isLoading                       = false
    var errorMessage: String?

    private let db      = SupabaseManager.shared.database
    private let auth    = SupabaseManager.shared.auth

    // ── Fetch all destinations ────────────────────────────────────────────
    func fetchAll(category: String? = nil) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            // Apply all eq filters first (PostgrestFilterBuilder),
            // then order (PostgrestTransformBuilder) — order must come last.
            var filterQuery = db.from(Table.destinations).select()
            if let cat = category {
                filterQuery = filterQuery.eq("category", value: cat)
            }
            let results: [DestinationDTO] = try await filterQuery
                .order("rating", ascending: false)
                .execute()
                .value
            await MainActor.run {
                destinations = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not load destinations."
                isLoading = false
            }
        }
    }

    // ── Search ────────────────────────────────────────────────────────────
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await fetchAll(); return
        }
        await MainActor.run { isLoading = true }
        do {
            let results: [DestinationDTO] = try await db
                .from(Table.destinations)
                .select()
                .or("name.ilike.%\(query)%,country.ilike.%\(query)%,tags.cs.{\(query)}")
                .execute()
                .value
            await MainActor.run { destinations = results; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    // ── Save / unsave ─────────────────────────────────────────────────────
    func toggleSave(_ destinationId: String) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        if saved.contains(destinationId) {
            saved.remove(destinationId)
            try? await db.from(Table.savedDestinations)
                .delete()
                .eq("user_id", value: userId)
                .eq("destination_id", value: destinationId)
                .execute()
        } else {
            saved.insert(destinationId)
            try? await db.from(Table.savedDestinations)
                .insert(["user_id": userId, "destination_id": destinationId])
                .execute()
        }
    }

    // ── Fetch user's saved destination IDs ────────────────────────────────
    func fetchSaved() async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        struct Row: Decodable { let destination_id: String }
        let rows: [Row] = (try? await db
            .from(Table.savedDestinations)
            .select("destination_id")
            .eq("user_id", value: userId)
            .execute()
            .value) ?? []
        await MainActor.run { saved = Set(rows.map(\.destination_id)) }
    }
}
