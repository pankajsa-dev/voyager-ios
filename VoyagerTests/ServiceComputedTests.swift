import Testing
import Foundation
@testable import Voyager

// MARK: - Service computed-property tests
//
// These test the pure, sync business logic in ExpenseService and
// PackingService without touching Supabase. We inject pre-built
// DTO arrays directly into the @Observable services.

@Suite("ExpenseService computed properties")
struct ExpenseServiceComputedTests {

    // MARK: - Helpers

    private func makeExpense(
        id: String = UUID().uuidString,
        amount: Double,
        category: ExpenseCategory,
        userId: String = "user-1"
    ) -> ExpenseDTO {
        ExpenseDTO(
            id: id,
            userId: userId,
            tripId: "trip-1",
            title: category.rawValue,
            amount: amount,
            currency: "EUR",
            category: category.rawValue,
            date: "2027-06-15",
            notes: "",
            receiptUrl: nil,
            createdAt: "2027-06-01T00:00:00Z"
        )
    }

    private func serviceWith(_ expenses: [ExpenseDTO]) -> ExpenseService {
        let svc = ExpenseService()
        svc.expenses = expenses
        return svc
    }

    // MARK: - totalSpent

    @Test("totalSpent is 0 when there are no expenses")
    func totalSpent_empty() {
        let svc = serviceWith([])
        #expect(svc.totalSpent == 0)
    }

    @Test("totalSpent sums all amounts correctly")
    func totalSpent_sum() {
        let svc = serviceWith([
            makeExpense(amount: 45.50, category: .food),
            makeExpense(amount: 120.00, category: .accommodation),
            makeExpense(amount: 34.50, category: .transport),
        ])
        #expect(svc.totalSpent == 200.00)
    }

    @Test("totalSpent handles a single expense")
    func totalSpent_single() {
        let svc = serviceWith([makeExpense(amount: 99.99, category: .shopping)])
        #expect(svc.totalSpent == 99.99)
    }

    // MARK: - totalFor(category:)

    @Test("totalFor returns 0 for a category with no expenses")
    func totalFor_noneInCategory() {
        let svc = serviceWith([makeExpense(amount: 50, category: .food)])
        #expect(svc.totalFor(category: .shopping) == 0)
    }

    @Test("totalFor sums only the matching category")
    func totalFor_categorySum() {
        let svc = serviceWith([
            makeExpense(amount: 30.00, category: .food),
            makeExpense(amount: 20.00, category: .food),
            makeExpense(amount: 100.00, category: .accommodation),
        ])
        #expect(svc.totalFor(category: .food) == 50.00)
        #expect(svc.totalFor(category: .accommodation) == 100.00)
    }

    // MARK: - byCategory

    @Test("byCategory is empty when there are no expenses")
    func byCategory_empty() {
        let svc = serviceWith([])
        #expect(svc.byCategory.isEmpty)
    }

    @Test("byCategory excludes categories with 0 total")
    func byCategory_excludesZero() {
        let svc = serviceWith([makeExpense(amount: 50, category: .food)])
        let categories = svc.byCategory.map(\.category)
        #expect(!categories.contains(.shopping))
        #expect(!categories.contains(.transport))
    }

    @Test("byCategory is sorted descending by total")
    func byCategory_sortedDescending() {
        let svc = serviceWith([
            makeExpense(amount: 10,  category: .food),
            makeExpense(amount: 200, category: .accommodation),
            makeExpense(amount: 50,  category: .transport),
        ])
        let totals = svc.byCategory.map(\.total)
        #expect(totals == totals.sorted(by: >))
    }

    @Test("byCategory contains exactly the categories that have expenses")
    func byCategory_correctCategories() {
        let svc = serviceWith([
            makeExpense(amount: 30, category: .food),
            makeExpense(amount: 80, category: .activities),
        ])
        let cats = Set(svc.byCategory.map(\.category))
        #expect(cats == [.food, .activities])
    }
}

// MARK: -

@Suite("PackingService computed properties")
struct PackingServiceComputedTests {

    // MARK: - Helpers

    private func makeItem(
        id: String = UUID().uuidString,
        name: String,
        category: PackingCategory,
        isPacked: Bool = false,
        isEssential: Bool = false
    ) -> PackingItemDTO {
        PackingItemDTO(
            id: id,
            tripId: "trip-1",
            name: name,
            category: category.rawValue,
            quantity: 1,
            isPacked: isPacked,
            isEssential: isEssential,
            createdAt: "2027-06-01T00:00:00Z"
        )
    }

    private func serviceWith(_ items: [PackingItemDTO]) -> PackingService {
        let svc = PackingService()
        svc.items = items
        return svc
    }

    // MARK: - totalCount / packedCount / progress

    @Test("Empty list has zero counts and zero progress")
    func empty_countsAndProgress() {
        let svc = serviceWith([])
        #expect(svc.totalCount  == 0)
        #expect(svc.packedCount == 0)
        #expect(svc.progress    == 0)
    }

    @Test("totalCount equals the number of items")
    func totalCount_correct() {
        let svc = serviceWith([
            makeItem(name: "Passport",  category: .documents),
            makeItem(name: "T-shirt",   category: .clothing),
            makeItem(name: "Sunscreen", category: .health),
        ])
        #expect(svc.totalCount == 3)
    }

    @Test("packedCount only counts isPacked == true")
    func packedCount_correct() {
        let svc = serviceWith([
            makeItem(name: "Passport",  category: .documents,  isPacked: true),
            makeItem(name: "T-shirt",   category: .clothing,   isPacked: true),
            makeItem(name: "Sunscreen", category: .health,     isPacked: false),
        ])
        #expect(svc.packedCount == 2)
    }

    @Test("progress is 0.5 when half packed")
    func progress_halfPacked() {
        let svc = serviceWith([
            makeItem(name: "A", category: .clothing,   isPacked: true),
            makeItem(name: "B", category: .toiletries, isPacked: false),
        ])
        #expect(svc.progress == 0.5)
    }

    @Test("progress is 1.0 when all items are packed")
    func progress_allPacked() {
        let svc = serviceWith([
            makeItem(name: "A", category: .clothing,   isPacked: true),
            makeItem(name: "B", category: .toiletries, isPacked: true),
            makeItem(name: "C", category: .documents,  isPacked: true),
        ])
        #expect(svc.progress == 1.0)
    }

    @Test("progress is 0.0 when no items are packed")
    func progress_nonePacked() {
        let svc = serviceWith([
            makeItem(name: "A", category: .clothing, isPacked: false),
            makeItem(name: "B", category: .clothing, isPacked: false),
        ])
        #expect(svc.progress == 0.0)
    }

    // MARK: - items(for category:)

    @Test("items(for:) returns only items in that category")
    func itemsForCategory_correct() {
        let svc = serviceWith([
            makeItem(name: "Passport",  category: .documents),
            makeItem(name: "Tickets",   category: .documents),
            makeItem(name: "T-shirt",   category: .clothing),
        ])
        let docs = svc.items(for: .documents)
        #expect(docs.count == 2)
        #expect(docs.allSatisfy { $0.category == PackingCategory.documents.rawValue })
    }

    @Test("items(for:) returns empty for a category with no items")
    func itemsForCategory_empty() {
        let svc = serviceWith([makeItem(name: "Passport", category: .documents)])
        #expect(svc.items(for: .electronics).isEmpty)
    }

    // MARK: - usedCategories

    @Test("usedCategories returns only categories with at least one item")
    func usedCategories_correct() {
        let svc = serviceWith([
            makeItem(name: "Passport", category: .documents),
            makeItem(name: "T-shirt",  category: .clothing),
        ])
        let used = svc.usedCategories
        #expect(used.contains(.documents))
        #expect(used.contains(.clothing))
        #expect(!used.contains(.electronics))
        #expect(!used.contains(.health))
    }

    @Test("usedCategories is empty when there are no items")
    func usedCategories_empty() {
        let svc = serviceWith([])
        #expect(svc.usedCategories.isEmpty)
    }

    @Test("usedCategories contains all categories when items span all of them")
    func usedCategories_allCategories() {
        let allItems = PackingCategory.allCases.map {
            makeItem(name: $0.rawValue, category: $0)
        }
        let svc = serviceWith(allItems)
        #expect(Set(svc.usedCategories) == Set(PackingCategory.allCases))
    }

    // MARK: - PackingCategory

    @Test("PackingCategory emoji is non-empty for all cases")
    func packingCategory_emojiNonEmpty() {
        for category in PackingCategory.allCases {
            #expect(!category.emoji.isEmpty)
        }
    }

    @Test("PackingCategory raw values are stable")
    func packingCategory_rawValues() {
        #expect(PackingCategory.clothing.rawValue      == "Clothing")
        #expect(PackingCategory.toiletries.rawValue    == "Toiletries")
        #expect(PackingCategory.electronics.rawValue   == "Electronics")
        #expect(PackingCategory.documents.rawValue     == "Documents")
        #expect(PackingCategory.health.rawValue        == "Health")
        #expect(PackingCategory.entertainment.rawValue == "Entertainment")
        #expect(PackingCategory.other.rawValue         == "Other")
    }
}
