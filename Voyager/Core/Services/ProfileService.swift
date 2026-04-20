import Foundation
import Supabase

// MARK: - DTO

struct ProfileDTO: Codable {
    var name: String
    var email: String
    var avatarUrl: String?
    var homeCity: String?
    var bio: String?
    var travelPrefs: [String]
    var visitedCountries: [String]
    var tripsCompleted: Int

    enum CodingKeys: String, CodingKey {
        case name, email, bio
        case avatarUrl         = "avatar_url"
        case homeCity          = "home_city"
        case travelPrefs       = "travel_prefs"
        case visitedCountries  = "visited_countries"
        case tripsCompleted    = "trips_completed"
    }
}

// MARK: - Service

@Observable
final class ProfileService {
    var profile: ProfileDTO?
    var isLoading   = false
    var isSaving    = false
    var errorMessage: String?

    private let db      = SupabaseManager.shared.database
    private let auth    = SupabaseManager.shared.auth
    private let storage = SupabaseManager.shared.storage

    // ── Fetch ─────────────────────────────────────────────────────────────
    func fetch() async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        await MainActor.run { isLoading = true }
        let result: ProfileDTO? = try? await db
            .from(Table.profiles)
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        await MainActor.run { profile = result; isLoading = false }
    }

    // ── Update profile ────────────────────────────────────────────────────
    func update(name: String, homeCity: String, bio: String, travelPrefs: [String]) async {
        guard let userId = try? await auth.session.user.id.uuidString else { return }
        await MainActor.run { isSaving = true }
        let payload: [String: AnyJSON] = [
            "name":         .string(name),
            "home_city":    .string(homeCity),
            "bio":          .string(bio),
            "travel_prefs": .array(travelPrefs.map { .string($0) }),
        ]
        try? await db.from(Table.profiles).update(payload).eq("id", value: userId).execute()
        await MainActor.run {
            profile?.name = name
            profile?.homeCity = homeCity
            profile?.bio = bio
            profile?.travelPrefs = travelPrefs
            isSaving = false
        }
    }

    // ── Upload avatar ─────────────────────────────────────────────────────
    /// Uploads to Cloudflare R2 when configured, otherwise falls back to Supabase Storage.
    func uploadAvatar(_ imageData: Data) async throws -> String {
        let userId = try await auth.session.user.id.uuidString
        let path   = "avatars/\(userId)/avatar.jpg"
        var urlString: String

        if CloudflareR2Config.isConfigured {
            // ── Cloudflare R2 (preferred — 10 GB free, no egress fees) ──
            urlString = try await CloudflareR2Service.shared.uploadImage(
                imageData,
                path: path,
                contentType: "image/jpeg"
            )
        } else {
            // ── Supabase Storage fallback ─────────────────────────────────
            try await storage.upload(
                path,
                data: imageData,
                options: .init(contentType: "image/jpeg", upsert: true)
            )
            let url = try storage.getPublicURL(path: path)
            urlString = url.absoluteString
        }

        // Persist the URL in the profiles table
        try? await db
            .from(Table.profiles)
            .update(["avatar_url": urlString])
            .eq("id", value: userId)
            .execute()

        await MainActor.run { profile?.avatarUrl = urlString }
        return urlString
    }
}
