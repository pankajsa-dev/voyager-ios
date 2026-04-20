import Foundation
import Supabase

// MARK: - DTO

struct ExpenseDTO: Codable, Identifiable {
    let id: String
    let tripId: String
    var title: String
    var amount: Double
    var currency: String
    var category: String          // ExpenseCategory.rawValue
    var date: String              // "yyyy-MM-dd"
    var notes: String
    var receiptUrl: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, amount, currency, category, date, notes
        case tripId     = "trip_id"
        case receiptUrl = "receipt_url"
        case createdAt  = "created_at"
    }
}

// MARK: - Service

@Observable
final class ExpenseService {
    var expenses: [ExpenseDTO] = []
    var isLoading  = false
    var errorMessage: String?

    private let db   = SupabaseManager.shared.database
    private let auth = SupabaseManager.shared.auth

    // ── Fetch all expenses for a trip ─────────────────────────────────────
    func fetchAll(tripId: String) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let results: [ExpenseDTO] = try await db
                .from(Table.expenses)
                .select()
                .eq("user_id", value: userId)
                .eq("trip_id", value: tripId)
                .order("date", ascending: false)
                .execute()
                .value
            await MainActor.run { expenses = results; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = "Could not load expenses."; isLoading = false }
        }
    }

    // ── Add expense ───────────────────────────────────────────────────────
    func add(
        tripId: String,
        title: String,
        amount: Double,
        currency: String,
        category: ExpenseCategory,
        date: Date,
        notes: String
    ) async throws {
        let userId = try await auth.session.user.id.uuidString
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let payload: [String: AnyJSON] = [
            "user_id":  .string(userId),
            "trip_id":  .string(tripId),
            "title":    .string(title),
            "amount":   .double(amount),
            "currency": .string(currency),
            "category": .string(category.rawValue),
            "date":     .string(fmt.string(from: date)),
            "notes":    .string(notes),
        ]
        let created: [ExpenseDTO] = try await db
            .from(Table.expenses).insert(payload).select().execute().value
        if let expense = created.first {
            await MainActor.run { expenses.insert(expense, at: 0) }
        }
    }

    // ── Delete expense ────────────────────────────────────────────────────
    func delete(expenseId: String) async throws {
        try await db.from(Table.expenses).delete().eq("id", value: expenseId).execute()
        await MainActor.run { expenses.removeAll { $0.id == expenseId } }
    }

    // ── Computed helpers ──────────────────────────────────────────────────

    var totalSpent: Double { expenses.reduce(0) { $0 + $1.amount } }

    func totalFor(category: ExpenseCategory) -> Double {
        expenses.filter { $0.category == category.rawValue }.reduce(0) { $0 + $1.amount }
    }

    var byCategory: [(category: ExpenseCategory, total: Double)] {
        ExpenseCategory.allCases.compactMap { cat in
            let t = totalFor(category: cat)
            return t > 0 ? (cat, t) : nil
        }.sorted { $0.total > $1.total }
    }
}
