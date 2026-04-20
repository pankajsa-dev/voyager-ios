import Foundation
import Supabase

// MARK: - DTO

struct PackingItemDTO: Codable, Identifiable {
    let id: String
    let tripId: String
    var name: String
    var category: String          // PackingCategory.rawValue
    var quantity: Int
    var isPacked: Bool
    var isEssential: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, category, quantity
        case tripId     = "trip_id"
        case isPacked   = "is_packed"
        case isEssential = "is_essential"
        case createdAt  = "created_at"
    }
}

// MARK: - Service

@Observable
final class PackingService {
    var items: [PackingItemDTO] = []
    var isLoading  = false
    var errorMessage: String?

    private let db   = SupabaseManager.shared.database
    private let auth = SupabaseManager.shared.auth

    // ── Fetch all items for a trip ────────────────────────────────────────
    func fetchAll(tripId: String) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let results: [PackingItemDTO] = try await db
                .from(Table.packingItems)
                .select()
                .eq("user_id", value: userId)
                .eq("trip_id", value: tripId)
                .order("category", ascending: true)
                .execute()
                .value
            await MainActor.run { items = results; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = "Could not load packing list."; isLoading = false }
        }
    }

    // ── Add item ──────────────────────────────────────────────────────────
    func add(
        tripId: String,
        name: String,
        category: PackingCategory,
        quantity: Int = 1,
        isEssential: Bool = false
    ) async throws {
        let userId = try await auth.session.user.id.uuidString
        let payload: [String: AnyJSON] = [
            "user_id":      .string(userId),
            "trip_id":      .string(tripId),
            "name":         .string(name),
            "category":     .string(category.rawValue),
            "quantity":     .integer(quantity),
            "is_essential": .bool(isEssential),
        ]
        let created: [PackingItemDTO] = try await db
            .from(Table.packingItems).insert(payload).select().execute().value
        if let item = created.first {
            await MainActor.run { items.append(item) }
        }
    }

    // ── Seed defaults for a new trip ──────────────────────────────────────
    func seedDefaults(tripId: String) async throws {
        guard items.isEmpty else { return }
        let userId = try await auth.session.user.id.uuidString
        let defaults: [(String, PackingCategory, Bool)] = [
            ("Passport",         .documents,  true),
            ("Flight tickets",   .documents,  true),
            ("Travel insurance", .documents,  true),
            ("Hotel booking",    .documents,  false),
            ("Phone charger",    .electronics, true),
            ("Power adapter",    .electronics, false),
            ("Headphones",       .electronics, false),
            ("Camera",           .electronics, false),
            ("Toothbrush",       .toiletries, true),
            ("Toothpaste",       .toiletries, true),
            ("Shampoo",          .toiletries, false),
            ("Deodorant",        .toiletries, false),
            ("Sunscreen",        .health,     false),
            ("Medications",      .health,     true),
            ("First aid kit",    .health,     false),
            ("T-shirts",         .clothing,   false),
            ("Underwear",        .clothing,   false),
            ("Comfortable shoes",.clothing,   false),
            ("Jacket",           .clothing,   false),
        ]
        let payloads: [AnyJSON] = defaults.map { name, cat, essential in
            .object([
                "user_id":       .string(userId),
                "trip_id":       .string(tripId),
                "name":          .string(name),
                "category":      .string(cat.rawValue),
                "quantity":      .integer(1),
                "is_essential":  .bool(essential),
            ])
        }
        let created: [PackingItemDTO] = try await db
            .from(Table.packingItems).insert(payloads).select().execute().value
        await MainActor.run { items = created.sorted { $0.category < $1.category } }
    }

    // ── Toggle packed ─────────────────────────────────────────────────────
    func togglePacked(itemId: String) async {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        let newValue = !items[idx].isPacked
        await MainActor.run { items[idx].isPacked = newValue }
        let payload: [String: AnyJSON] = ["is_packed": .bool(newValue)]
        try? await db.from(Table.packingItems).update(payload).eq("id", value: itemId).execute()
    }

    // ── Delete item ───────────────────────────────────────────────────────
    func delete(itemId: String) async throws {
        try await db.from(Table.packingItems).delete().eq("id", value: itemId).execute()
        await MainActor.run { items.removeAll { $0.id == itemId } }
    }

    // ── Computed helpers ──────────────────────────────────────────────────

    var packedCount: Int  { items.filter(\.isPacked).count }
    var totalCount:  Int  { items.count }
    var progress:    Double { totalCount == 0 ? 0 : Double(packedCount) / Double(totalCount) }

    func items(for category: PackingCategory) -> [PackingItemDTO] {
        items.filter { $0.category == category.rawValue }
    }

    var usedCategories: [PackingCategory] {
        PackingCategory.allCases.filter { !items(for: $0).isEmpty }
    }
}
