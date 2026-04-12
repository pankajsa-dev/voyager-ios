import Foundation
import Supabase

// MARK: - Supabase client singleton

final class SupabaseManager {

    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://scpwgtlfaqhlxntadirq.supabase.co")!,
            supabaseKey: "sb_publishable_4u9gL5r4O2bX3UVH8IAftA_w3NFM6s1"
        )
    }

    // Convenience accessors
    var auth:     AuthClient     { client.auth }
    var database: PostgrestClient { client.database }
    var storage:  StorageFileApi  { client.storage.from("voyager") }
}

// MARK: - Table name constants

enum Table {
    static let profiles          = "profiles"
    static let destinations      = "destinations"
    static let savedDestinations = "saved_destinations"
    static let trips             = "trips"
    static let bookings          = "bookings"
    static let expenses          = "expenses"
    static let packingItems      = "packing_items"
}
