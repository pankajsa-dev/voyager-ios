import SwiftUI

struct ProfileView: View {
    @State private var showEditProfile = false

    // Placeholder values — will be driven by a ViewModel
    let name = "Pankaj Sachdeva"
    let email = "pankaj@voyager.app"
    let homeCity = "Munich, Germany"
    let tripsCompleted = 0
    let countriesVisited = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Hero header
                    ProfileHeaderView(
                        name: name,
                        homeCity: homeCity,
                        tripsCompleted: tripsCompleted,
                        countriesVisited: countriesVisited
                    )

                    // Stats row
                    StatsRowView(
                        tripsCompleted: tripsCompleted,
                        countriesVisited: countriesVisited
                    )
                    .padding(.horizontal, AppSpacing.md)

                    // Settings sections
                    VStack(spacing: AppSpacing.sm) {
                        SettingsSectionView(title: "Account", items: [
                            SettingsItem(icon: "person.circle", title: "Edit Profile"),
                            SettingsItem(icon: "bell", title: "Notifications"),
                            SettingsItem(icon: "lock.shield", title: "Privacy & Security"),
                        ])
                        SettingsSectionView(title: "Preferences", items: [
                            SettingsItem(icon: "globe", title: "Language"),
                            SettingsItem(icon: "dollarsign.circle", title: "Currency"),
                            SettingsItem(icon: "moon", title: "Appearance"),
                        ])
                        SettingsSectionView(title: "Support", items: [
                            SettingsItem(icon: "questionmark.circle", title: "Help & FAQ"),
                            SettingsItem(icon: "star", title: "Rate Voyager"),
                            SettingsItem(icon: "info.circle", title: "About"),
                        ])
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Sign out
                    Button(role: .destructive) {
                        // Sign out
                    } label: {
                        Text("Sign Out")
                            .font(AppFont.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#E05D5D").opacity(0.1))
                            .foregroundStyle(Color(hex: "#E05D5D"))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    }
                    .padding(.horizontal, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xl)
                }
                .padding(.top, AppSpacing.md)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEditProfile = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                Text("Edit Profile — coming soon")
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Profile header

private struct ProfileHeaderView: View {
    let name: String
    let homeCity: String
    let tripsCompleted: Int
    let countriesVisited: Int

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first?.uppercased() }.joined()
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                Text(initials)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(name)
                    .font(AppFont.h2)
                    .fontWeight(.bold)
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(homeCity)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Stats row

private struct StatsRowView: View {
    let tripsCompleted: Int
    let countriesVisited: Int

    var body: some View {
        HStack {
            StatItem(value: "\(tripsCompleted)", label: "Trips")
            Divider().frame(height: 40)
            StatItem(value: "\(countriesVisited)", label: "Countries")
            Divider().frame(height: 40)
            StatItem(value: "0", label: "Badges")
        }
        .padding(.vertical, AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
    }
}

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.h2)
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings section

private struct SettingsItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
}

private struct SettingsSectionView: View {
    let title: String
    let items: [SettingsItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xs)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: item.icon)
                            .frame(width: 24)
                            .foregroundStyle(Color(hex: "#2A9D8F"))
                        Text(item.title)
                            .font(AppFont.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                    if item.id != items.last?.id {
                        Divider().padding(.leading, AppSpacing.md + 24 + AppSpacing.md)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        }
    }
}

#Preview {
    ProfileView()
}
