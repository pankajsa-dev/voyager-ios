import Foundation
import Supabase

// MARK: - Service

@Observable
final class TripMemberService {
    var members: [TripMemberDTO]  = []
    var isLoading                 = false
    var errorMessage: String?
    private(set) var currentUserId: String = ""

    private let db   = SupabaseManager.shared.database
    private let auth = SupabaseManager.shared.auth

    // ── Fetch all members for a trip ─────────────────────────────────────
    func fetchMembers(tripId: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        // Resolve current user first — set it even if the member fetch fails
        // so the invite button can still appear for the trip owner.
        let uid = (try? await auth.session.user.id.uuidString) ?? ""
        await MainActor.run { currentUserId = uid }

        do {
            // Plain select — no PostgREST join because trip_members.user_id
            // references auth.users, not profiles, so there is no usable FK.
            var results: [TripMemberDTO] = try await db
                .from(Table.tripMembers)
                .select("id, trip_id, user_id, invited_by, invited_email, role, status, invite_expires_at, joined_at, created_at")
                .eq("trip_id", value: tripId)
                .execute()
                .value

            // Enrich with profile names / avatars in a second pass
            let userIds = results.compactMap { $0.userId }
            if !userIds.isEmpty {
                struct ProfileRow: Codable {
                    let id: String; let name: String?; let avatarUrl: String?
                    enum CodingKeys: String, CodingKey { case id, name; case avatarUrl = "avatar_url" }
                }
                let profiles: [ProfileRow] = (try? await db
                    .from(Table.profiles)
                    .select("id, name, avatar_url")
                    .in("id", values: userIds)
                    .execute()
                    .value) ?? []
                let pMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
                for i in results.indices {
                    if let uid = results[i].userId, let p = pMap[uid] {
                        results[i].profiles = ProfileSummaryDTO(name: p.name, avatarUrl: p.avatarUrl)
                    }
                }
            }

            await MainActor.run { members = results; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }

    // ── Generate a shareable invite link ─────────────────────────────────
    // Creates a single-use, 7-day token row. Returns a voyager:// deep link URL.
    func generateInviteLink(tripId: String, role: MemberRole = .editor) async throws -> URL {
        let userId = try await auth.session.user.id.uuidString
        let token  = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let expires = ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600))

        let payload: [String: AnyJSON] = [
            "trip_id":           .string(tripId),
            "invited_by":        .string(userId),
            "role":              .string(role.rawValue),
            "status":            .string(MemberStatus.pending.rawValue),
            "invite_token":      .string(token),
            "invite_expires_at": .string(expires),
        ]
        try await db.from(Table.tripMembers).insert(payload).execute()

        guard let url = URL(string: "voyager://join?token=\(token)") else {
            throw URLError(.badURL)
        }
        return url
    }

    // ── Accept an invite by token ─────────────────────────────────────────
    // Returns the trip_id on success.
    func acceptInvite(token: String) async throws -> String {
        let userId = try await auth.session.user.id.uuidString

        // Look up the pending, unexpired invite row
        struct TokenRow: Codable { let id: String; let tripId: String; enum CodingKeys: String, CodingKey { case id; case tripId = "trip_id" } }
        let rows: [TokenRow] = try await db
            .from(Table.tripMembers)
            .select("id, trip_id")
            .eq("invite_token", value: token)
            .eq("status", value: MemberStatus.pending.rawValue)
            .execute()
            .value

        guard let row = rows.first else { throw InviteError.invalidOrExpired }

        // Accept: claim the row, clear the token so it can't be reused
        let now = ISO8601DateFormatter().string(from: .now)
        let update: [String: AnyJSON] = [
            "user_id":      .string(userId),
            "status":       .string(MemberStatus.accepted.rawValue),
            "joined_at":    .string(now),
            "invite_token": .null,
        ]
        try await db
            .from(Table.tripMembers)
            .update(update)
            .eq("id", value: row.id)
            .execute()

        return row.tripId
    }

    // ── Remove a member ───────────────────────────────────────────────────
    func removeMember(memberId: String) async throws {
        try await db
            .from(Table.tripMembers)
            .delete()
            .eq("id", value: memberId)
            .execute()
        await MainActor.run { members.removeAll { $0.id == memberId } }
    }

    // ── Update a member's role ────────────────────────────────────────────
    func updateRole(memberId: String, role: MemberRole) async throws {
        let payload: [String: AnyJSON] = ["role": .string(role.rawValue)]
        try await db
            .from(Table.tripMembers)
            .update(payload)
            .eq("id", value: memberId)
            .execute()
        if let idx = members.firstIndex(where: { $0.id == memberId }) {
            await MainActor.run { members[idx].role = role.rawValue }
        }
    }

    // ── Is the current user the owner of a trip (not just a member)? ──────
    func isOwner(tripId: String, ownerUserId: String) -> Bool {
        currentUserId == ownerUserId
    }
}

// MARK: - Error

enum InviteError: LocalizedError {
    case invalidOrExpired

    var errorDescription: String? {
        "This invite link is invalid or has already been used."
    }
}
