import SwiftUI

// MARK: - ViewModel

@Observable
final class HomeViewModel {
    var upcomingTrip: TripDTO?
    var featuredDestinations: [DestinationDTO] = []
    var allTrips: [TripDTO] = []
    var isLoading = false

    private let tripService        = TripService()
    private let destinationService = DestinationService()

    var tripCount: Int {
        allTrips.filter { $0.status != "cancelled" }.count
    }

    var countriesCount: Int {
        Set(allTrips.compactMap { $0.destinationName.isEmpty ? nil : $0.destinationName }).count
    }

    func load() async {
        await MainActor.run { isLoading = true }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.tripService.fetchAll() }
            group.addTask { await self.destinationService.fetchAll() }
        }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let now = Date()
        let upcoming = tripService.trips
            .filter {
                guard let d = fmt.date(from: $0.startDate) else { return false }
                return d >= Calendar.current.startOfDay(for: now)
            }
            .sorted { $0.startDate < $1.startDate }
        await MainActor.run {
            allTrips             = tripService.trips
            upcomingTrip         = upcoming.first
            featuredDestinations = Array(destinationService.destinations.prefix(6))
            isLoading            = false
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var vm = HomeViewModel()
    @State private var selectedDestination: DestinationDTO?
    private let destinationService = DestinationService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {

                    // ── Greeting header ──────────────────────────────
                    headerSection

                    // ── Stats row ────────────────────────────────────
                    statsRow
                        .padding(.horizontal, AppSpacing.md)

                    // ── Upcoming trip ────────────────────────────────
                    SectionHeader(title: "Upcoming Trip", actionTitle: nil) {}
                    upcomingTripCard
                        .padding(.horizontal, AppSpacing.md)

                    // ── Featured destinations ────────────────────────
                    SectionHeader(title: "Featured Destinations", actionTitle: "See all") {}
                    featuredDestinationsRow

                    // ── Browse by category ───────────────────────────
                    SectionHeader(title: "Browse by Category", actionTitle: nil) {}
                    CategoriesGrid()
                        .padding(.horizontal, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xxl)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { } label: {
                        Image(systemName: "bell")
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                    }
                }
            }
            .navigationDestination(item: $selectedDestination) { dest in
                DestinationDetailView(destination: dest, service: destinationService)
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.secondary)
                Text(firstName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
            // Avatar initial
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                Text(initial)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            StatPill(value: "\(vm.tripCount)", label: "Trips", icon: "airplane")
            StatPill(value: "\(vm.countriesCount)", label: "Places", icon: "mappin.circle")
            StatPill(value: "0", label: "Bookings", icon: "ticket")
        }
    }

    // MARK: Upcoming trip card

    @ViewBuilder
    private var upcomingTripCard: some View {
        if vm.isLoading {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .frame(height: 160)
                .shimmer()
        } else if let trip = vm.upcomingTrip {
            ActiveTripCard(trip: trip)
        } else {
            EmptyTripCard()
        }
    }

    // MARK: Featured row

    private var featuredDestinationsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.md) {
                if vm.isLoading {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .frame(width: 150, height: 190)
                            .shimmer()
                    }
                } else {
                    ForEach(vm.featuredDestinations) { dest in
                        DestinationCardSmall(destination: dest)
                            .onTapGesture { selectedDestination = dest }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Helpers

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning 🌤" }
        if h < 17 { return "Good afternoon ☀️" }
        return "Good evening 🌙"
    }

    private var firstName: String {
        authVM.currentUser?.name.components(separatedBy: " ").first ?? "Traveller"
    }

    private var initial: String {
        String(authVM.currentUser?.name.prefix(1).uppercased() ?? "V")
    }
}

// MARK: - Active trip card

private struct ActiveTripCard: View {
    let trip: TripDTO

    private var daysUntil: Int {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let start = fmt.date(from: trip.startDate) else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: start).day ?? 0)
    }

    private var formattedDate: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: trip.startDate) else { return trip.startDate }
        let out = DateFormatter(); out.dateFormat = "MMM d"
        let outEnd = DateFormatter(); outEnd.dateFormat = "MMM d, yyyy"
        if let e = fmt.date(from: trip.endDate) {
            return "\(out.string(from: d)) – \(outEnd.string(from: e))"
        }
        return out.string(from: d)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1A6B6A"), Color(hex: "#0D4A49")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(height: 170)

            // Decorative circle
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 160, height: 160)
                .offset(x: 180, y: -20)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Label("UPCOMING TRIP", systemImage: "airplane.departure")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .labelStyle(.titleAndIcon)

                Text(trip.destinationName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer(minLength: 8)

                // Countdown badge
                HStack(spacing: 6) {
                    if daysUntil == 0 {
                        Label("Today!", systemImage: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                    } else {
                        Label("\(daysUntil) days to go", systemImage: "clock")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.18))
                .clipShape(Capsule())
            }
            .padding(AppSpacing.md)
        }
        .cardShadow()
    }
}

// MARK: - Empty trip card

private struct EmptyTripCard: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2A9D8F"), Color(hex: "#1A6B6A")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(height: 160)

            VStack(alignment: .leading, spacing: 4) {
                Text("NO UPCOMING TRIPS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Ready to explore?")
                    .font(AppFont.h3)
                    .foregroundStyle(.white)
                Text("Plan your next adventure →")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(AppSpacing.md)
        }
        .cardShadow()
    }
}

// MARK: - Stat pill

private struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#2A9D8F"))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(label)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

// MARK: - Destination card (small, horizontal)

private struct DestinationCardSmall: View {
    let destination: DestinationDTO

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            Group {
                if let urlStr = destination.imageUrls.first, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            placeholderGradient
                        }
                    }
                } else {
                    placeholderGradient
                }
            }
            .frame(width: 150, height: 195)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

            // Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(destination.country)
                    .font(AppFont.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(AppSpacing.sm)

            // Rating badge
            VStack {
                HStack {
                    Spacer()
                    Label(String(format: "%.1f", destination.rating), systemImage: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(6)
                }
                Spacer()
            }
            .frame(width: 150, height: 195)
        }
        .frame(width: 150, height: 195)
        .cardShadow()
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Categories grid

private struct CategoriesGrid: View {
    let categories = DestinationCategory.allCases
    let columns = Array(repeating: GridItem(.flexible()), count: 4)

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

// MARK: - Shimmer modifier

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase + 0.3, y: 0)
                )
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Section header (shared)

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
        .environment(AuthViewModel())
}
