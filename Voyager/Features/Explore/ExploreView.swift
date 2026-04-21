import SwiftUI

struct ExploreView: View {
    @State private var service           = DestinationService()
    @State private var searchText        = ""
    @State private var selectedCategory: DestinationCategory?
    @State private var selectedDest: DestinationDTO?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Search bar ────────────────────────────────────────────
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search destinations, countries…", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, new in
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                guard !Task.isCancelled else { return }
                                if new.isEmpty {
                                    await service.fetchAll(category: selectedCategory?.rawValue)
                                } else {
                                    await service.search(query: new)
                                }
                            }
                        }
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)

                // ── Category chips ────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        CategoryChip(title: "All", emoji: "🌍", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                            Task { await service.fetchAll() }
                        }
                        ForEach(DestinationCategory.allCases, id: \.rawValue) { cat in
                            CategoryChip(
                                title: cat.rawValue,
                                emoji: cat.emoji,
                                isSelected: selectedCategory == cat
                            ) {
                                if selectedCategory == cat {
                                    selectedCategory = nil
                                    Task { await service.fetchAll() }
                                } else {
                                    selectedCategory = cat
                                    Task { await service.fetchAll(category: cat.rawValue) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }

                Divider()

                // ── Content ───────────────────────────────────────────────
                if service.isLoading && service.destinations.isEmpty {
                    ExploreSkeletonGrid()
                } else if service.destinations.isEmpty {
                    ExploreEmptyState(searchText: searchText)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: AppSpacing.md
                        ) {
                            ForEach(service.destinations) { dest in
                                DestinationCard(
                                    destination: dest,
                                    isSaved: service.saved.contains(dest.id)
                                ) {
                                    Task { await service.toggleSave(dest.id) }
                                }
                                .onTapGesture { selectedDest = dest }
                            }
                        }
                        .padding(AppSpacing.md)
                        .padding(.bottom, AppSpacing.xl)
                    }
                    .refreshable { await service.fetchAll(category: selectedCategory?.rawValue) }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Explore")
            .task {
                await service.fetchAll()
                await service.fetchSaved()
            }
            .navigationDestination(item: $selectedDest) { dest in
                DestinationDetailView(destination: dest, service: service)
            }
        }
    }
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
            .background(isSelected
                        ? Color.voyagerPrimary
                        : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Destination card

struct DestinationCard: View {
    let destination: DestinationDTO
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image / gradient placeholder
                ZStack(alignment: .bottomLeading) {
                    DestinationHero(
                        imageURLs: destination.imageUrls,
                        height: 140,
                        destinationName: destination.name,
                        country: destination.country
                    )
                    .frame(height: 140)  // pin height so grid cells never bleed

                    // Rating pill
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", destination.rating))
                            .font(AppFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(8)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.name)
                        .font(AppFont.h4)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(flag(for: destination.countryCode))
                        Text(destination.country)
                            .font(AppFont.bodySmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 2) {
                        Text("~$\(Int(destination.avgBudgetPerDay))")
                            .font(AppFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.voyagerPrimary)
                        Text("/day")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
                .padding(AppSpacing.sm)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .cardShadow()

            // Save button
            Button(action: onSave) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSaved ? Color.voyagerAccent : .white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(8)
            .animation(.spring(response: 0.3), value: isSaved)
        }
    }
}

// MARK: - Destination hero image (Unsplash fallback)

struct DestinationHero: View {
    let imageURLs: [String]
    let height: CGFloat
    var destinationName: String = ""
    var country: String = ""

    @State private var fallbackURL: String?

    private var imageService: DestinationImageService { .shared }

    private var effectiveURL: URL? {
        let stored = imageURLs.first.flatMap { $0.isEmpty ? nil : $0 }
        return (stored ?? fallbackURL).flatMap { URL(string: $0) }
    }

    var body: some View {
        // GeometryReader gives the exact column/card width so we can pin
        // the AsyncImage to a pixel-perfect size — prevents scaledToFill()
        // from reporting a larger layout size to the parent grid/stack.
        GeometryReader { proxy in
            ZStack {
                // Gradient — always-visible background/placeholder
                LinearGradient(
                    colors: [Color.voyagerPrimary, Color.voyagerPrimaryLight],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                if let url = effectiveURL {
                    AsyncImage(url: url) { img in
                        img.resizable()
                            .scaledToFill()
                            // Pin to exact size HERE, not just on the container
                            .frame(width: proxy.size.width, height: height)
                            .clipped()
                    } placeholder: {
                        EmptyView()
                    }
                }
            }
            // Container is also pinned — belt-and-suspenders
            .frame(width: proxy.size.width, height: height)
            .clipped()
        }
        .frame(height: height)          // GeometryReader needs explicit height
        .task(id: destinationName) {
            let hasStored = imageURLs.first.map { !$0.isEmpty } ?? false
            guard !hasStored, !destinationName.isEmpty else { return }
            if let cached = imageService.cachedURL(for: destinationName, country: country) {
                fallbackURL = cached; return
            }
            await imageService.fetch(destination: destinationName, country: country)
            fallbackURL = imageService.cachedURL(for: destinationName, country: country)
        }
    }
}

// MARK: - Skeleton grid

private struct ExploreSkeletonGrid: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in DestinationCardSkeleton() }
            }
            .padding(AppSpacing.md)
        }
    }
}

private struct DestinationCardSkeleton: View {
    @State private var animating = false

    var shimmer: Color { Color.gray.opacity(animating ? 0.18 : 0.07) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(shimmer)
                .frame(height: 140)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(width: 100, height: 13)
                RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(width: 70,  height: 10)
                RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(width: 50,  height: 10)
            }
            .padding(AppSpacing.sm)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}

// MARK: - Empty state

private struct ExploreEmptyState: View {
    let searchText: String
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "globe" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(Color.voyagerPrimaryLight.opacity(0.4))
            Text(searchText.isEmpty ? "No destinations yet" : "No results for \"\(searchText)\"")
                .font(AppFont.h3)
                .fontWeight(.bold)
            Text(searchText.isEmpty
                 ? "Check back soon — new places are being added."
                 : "Try a different search or browse by category.")
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
        }
    }
}

// MARK: - Flag emoji helper

func flag(for countryCode: String) -> String {
    countryCode.uppercased().unicodeScalars.compactMap {
        Unicode.Scalar(127397 + $0.value)
    }.map(String.init).joined()
}

#Preview {
    ExploreView()
}
