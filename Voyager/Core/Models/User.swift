import Foundation
import SwiftData

@Model
final class User {
    var id: String
    var name: String
    var email: String
    var avatarURL: String?
    var homeCity: String?
    var bio: String?
    var travelPreferences: [String]   // e.g. ["Beach", "Adventure"]
    var visitedCountries: [String]    // ISO country codes
    var tripsCompleted: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        avatarURL: String? = nil,
        homeCity: String? = nil,
        bio: String? = nil,
        travelPreferences: [String] = [],
        visitedCountries: [String] = [],
        tripsCompleted: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.homeCity = homeCity
        self.bio = bio
        self.travelPreferences = travelPreferences
        self.visitedCountries = visitedCountries
        self.tripsCompleted = tripsCompleted
        self.createdAt = createdAt
    }
}
