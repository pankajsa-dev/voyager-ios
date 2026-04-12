import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good morning 👋")
                            .font(AppFont.bodySmall)
                            .foregroundStyle(.secondary)
                        Text("Where to next?")
                            .font(AppFont.h1)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)

                    // Upcoming trip card placeholder
                    UpcomingTripCard()
                        .padding(.horizontal, AppSpacing.md)

                    // Featured destinations placeholder
                    SectionHeader(title: "Featured Destinations", actionTitle: "See all") {}
                    FeaturedDestinationsRow()

                    // Categories
                    SectionHeader(title: "Browse by Category", actionTitle: nil) {}
                    CategoriesGrid()
                        .padding(.horizontal, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xl)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Notifications
                    } label: {
                        Image(systemName: "bell")
                    }
                }
            }
        }
    }
}

// MARK: - Upcoming trip card

private struct UpcomingTripCard: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 160)

            VStack(alignment: .leading, spacing: 4) {
                Text("UPCOMING TRIP")
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                Text("No trips planned yet")
                    .font(AppFont.h3)
                    .foregroundStyle(.white)
                Text("Tap + to start planning your adventure")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(AppSpacing.md)

            HStack {
                Spacer()
                Button {
                    // Add trip
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .padding(AppSpacing.md)
            }
        }
        .cardShadow()
    }
}

// MARK: - Featured destinations row

private struct FeaturedDestinationsRow: View {
    let placeholders = ["Paris", "Tokyo", "Bali", "New York"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.md) {
                ForEach(placeholders, id: \.self) { name in
                    DestinationCardSmall(name: name)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
}

private struct DestinationCardSmall: View {
    let name: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .frame(width: 150, height: 190)
                .cardShadow()

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppFont.h4)
                    .foregroundStyle(.primary)
                Text("Explore →")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.sm)
        }
    }
}

// MARK: - Categories grid

private struct CategoriesGrid: View {
    let categories = DestinationCategory.allCases

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
            ForEach(categories, id: \.rawValue) { cat in
                VStack(spacing: 4) {
                    Text(cat.emoji)
                        .font(.title2)
                        .padding(10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    Text(cat.rawValue)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

// MARK: - Shared section header

struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(AppFont.h3)
            Spacer()
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(Color(hex: "#2A9D8F"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
}

#Preview {
    HomeView()
}
