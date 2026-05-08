import Foundation

// MARK: - Enums

enum MemberRole: String, Codable, CaseIterable {
    case editor = "editor"
    case viewer = "viewer"

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .editor: return "pencil"
        case .viewer: return "eye"
        }
    }
}

enum MemberStatus: String, Codable {
    case pending  = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

// MARK: - Profile summary (used in member + expense joins)

struct ProfileSummaryDTO: Codable {
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Trip member DTO

struct TripMemberDTO: Codable, Identifiable {
    let id: String
    let tripId: String
    var userId: String?
    var invitedBy: String
    var invitedEmail: String?
    var role: String
    var status: String
    var inviteExpiresAt: String?
    var joinedAt: String?
    let createdAt: String
    var profiles: ProfileSummaryDTO?   // PostgREST join: profiles!user_id(name,avatar_url)

    enum CodingKeys: String, CodingKey {
        case id, role, status, profiles
        case tripId          = "trip_id"
        case userId          = "user_id"
        case invitedBy       = "invited_by"
        case invitedEmail    = "invited_email"
        case inviteExpiresAt = "invite_expires_at"
        case joinedAt        = "joined_at"
        case createdAt       = "created_at"
    }

    var memberRole: MemberRole     { MemberRole(rawValue: role)       ?? .viewer }
    var memberStatus: MemberStatus { MemberStatus(rawValue: status)   ?? .pending }

    var displayName: String {
        if let name = profiles?.name, !name.isEmpty { return name }
        if let email = invitedEmail { return email.components(separatedBy: "@").first ?? email }
        return "Invited"
    }

    var avatarUrl: String? { profiles?.avatarUrl }

    var initials: String {
        let n = displayName
        let parts = n.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(n.prefix(2)).uppercased()
    }
}
