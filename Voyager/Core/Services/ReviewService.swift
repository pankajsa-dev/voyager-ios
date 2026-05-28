import Foundation
import Supabase

// MARK: - DTO

struct ReviewDTO: Codable, Identifiable, Hashable {
    let id: String
    let destinationId: String
    let userId: String
    var rating: Int         // 1–5
    var body: String
    let createdAt: String
    var profile: ProfileSnippet?

    struct ProfileSnippet: Codable, Hashable {
        let name: String?
        let avatarUrl: String?
        enum CodingKeys: String, CodingKey {
            case name
            case avatarUrl = "avatar_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, rating, body, profile
        case destinationId = "destination_id"
        case userId        = "user_id"
        case createdAt     = "created_at"
    }

    var authorName: String { profile?.name ?? "Traveller" }
    var authorAvatarUrl: String? { profile?.avatarUrl }
}

// MARK: - Encodable payloads

private struct ReviewInsertPayload: Encodable {
    let destinationId: String
    let userId: UUID
    let rating: Int
    let body: String
    enum CodingKeys: String, CodingKey {
        case destinationId = "destination_id"
        case userId        = "user_id"
        case rating, body
    }
}

private struct ReviewUpdatePayload: Encodable {
    let rating: Int
    let body: String
}

// MARK: - Service

@Observable
final class ReviewService {
    var reviews: [ReviewDTO]    = []
    var myReview: ReviewDTO?    = nil
    var isLoading               = false
    var errorMessage: String?
    private(set) var currentUserId = ""

    private var db:   PostgrestClient { SupabaseManager.shared.database }
    private var auth: AuthClient      { SupabaseManager.shared.auth }

    // ── Fetch all reviews for a destination ───────────────────────────────

    func fetchReviews(destinationId: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            currentUserId = (try? await auth.session.user.id.uuidString) ?? ""
            let result: [ReviewDTO] = try await db
                .from(Table.reviews)
                .select("*, profiles(name, avatar_url)")
                .eq("destination_id", value: destinationId)
                .order("created_at", ascending: false)
                .execute()
                .value
            await MainActor.run {
                reviews    = result
                myReview   = result.first(where: { $0.userId == currentUserId })
                isLoading  = false
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }

    // ── Submit (insert or update) ─────────────────────────────────────────

    func submit(destinationId: String, rating: Int, body: String) async throws {
        let userId = try await auth.session.user.id          // keep as UUID
        await MainActor.run { currentUserId = userId.uuidString }

        if let existing = myReview {
            guard let existingUUID = UUID(uuidString: existing.id) else { return }
            let payload = ReviewUpdatePayload(rating: rating, body: body)
            let updated: [ReviewDTO] = try await db
                .from(Table.reviews)
                .update(payload)
                .eq("id", value: existingUUID)
                .select()
                .execute()
                .value
            if let saved = updated.first {
                await MainActor.run {
                    if let idx = reviews.firstIndex(where: { $0.id == existing.id }) {
                        reviews[idx] = saved
                    }
                    myReview = saved
                }
            }
        } else {
            let payload = ReviewInsertPayload(
                destinationId: destinationId,
                userId: userId,          // now UUID — matches the DB column type
                rating: rating,
                body: body
            )
            let created: [ReviewDTO] = try await db
                .from(Table.reviews)
                .insert(payload)
                .select()
                .execute()
                .value
            if let saved = created.first {
                await MainActor.run {
                    reviews.insert(saved, at: 0)
                    myReview = saved
                }
            }
        }
        // Re-fetch to populate profile display names after insert/update
        await fetchReviews(destinationId: destinationId)
    }

    // ── Delete ────────────────────────────────────────────────────────────

    func delete(reviewId: String) async throws {
        guard let uuid = UUID(uuidString: reviewId) else { return }
        try await db.from(Table.reviews).delete().eq("id", value: uuid).execute()
        await MainActor.run {
            reviews.removeAll { $0.id == reviewId }
            if myReview?.id == reviewId { myReview = nil }
        }
    }

    // ── Computed helpers ──────────────────────────────────────────────────

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    func count(for star: Int) -> Int {
        reviews.filter { $0.rating == star }.count
    }
}
