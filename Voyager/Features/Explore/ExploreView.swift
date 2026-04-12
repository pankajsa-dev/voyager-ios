import SwiftUI

struct ExploreView: View {
    @State private var searchText = ""
    @State private var selectedCategory: DestinationCategory?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search destinations, countries…", text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)

                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        CategoryChip(title: "All", emoji: "🌍", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(DestinationCategory.allCases, id: \.rawValue) { cat in
                            CategoryChip(
                                title: cat.rawValue,
                                emoji: cat.emoji,
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                }

                Divider()

                // Destination grid placeholder
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                        ForEach(previewDestinations, id: \.self) { name in
                            DestinationGridCard(name: name)
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Explore")
        }
    }

    private let previewDestinations = [
        "Paris", "Tokyo", "Bali", "New York",
        "Santorini", "Kyoto", "Maldives", "Barcelona"
    ]
}

// MARK: - Category chip

private struct CategoryChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji).font(.caption)
                Text(title).font(AppFont.label).fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color(hex: "#1A6B6A") : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Destination grid card

private struct DestinationGridCard: View {
    let name: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2A9D8F").opacity(0.7), Color(hex: "#1A6B6A")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 180)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppFont.h4)
                    .foregroundStyle(.white)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text("4.8")
                        .font(AppFont.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(AppSpacing.sm)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
    }
}

#Preview {
    ExploreView()
}
