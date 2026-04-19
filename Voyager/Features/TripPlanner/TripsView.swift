import SwiftUI

struct TripsView: View {
    @State private var tripService    = TripService()
    @State private var selectedTrip: TripDTO?
    @State private var showCreate     = false
    @State private var selectedStatus: TripStatus? = nil

    private var filtered: [TripDTO] {
        guard let s = selectedStatus else { return tripService.trips }
        return tripService.trips.filter { $0.status == s.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Filter chips ─────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        FilterChip(label: "All", isOn: selectedStatus == nil) {
                            selectedStatus = nil
                        }
                        ForEach(TripStatus.allCases, id: \.rawValue) { s in
                            FilterChip(label: s.rawValue, isOn: selectedStatus == s) {
                                selectedStatus = selectedStatus == s ? nil : s
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                Divider()

                // ── Content ──────────────────────────────────────────
                if tripService.isLoading {
                    TripsLoadingState()
                } else if filtered.isEmpty {
                    TripsEmptyState { showCreate = true }
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(filtered) { trip in
                                TripCard(trip: trip)
                                    .onTapGesture { selectedTrip = trip }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { try? await tripService.delete(tripId: trip.id) }
                                        } label: {
                                            Label("Delete Trip", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("My Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                    }
                }
            }
            .navigationDestination(item: $selectedTrip) { trip in
                TripDetailView(trip: trip, tripService: tripService)
            }
            .sheet(isPresented: $showCreate, onDismiss: {
                Task { await tripService.fetchAll() }
            }) {
                CreateTripView(tripService: tripService)
            }
            .task { await tripService.fetchAll() }
            .refreshable { await tripService.fetchAll() }
        }
    }
}

// MARK: - Trip card

private struct TripCard: View {
    let trip: TripDTO

    private var dateRange: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d"
        let outY = DateFormatter(); outY.dateFormat = "MMM d, yyyy"
        if let s = fmt.date(from: trip.startDate), let e = fmt.date(from: trip.endDate) {
            return "\(out.string(from: s)) – \(outY.string(from: e))"
        }
        return "\(trip.startDate) – \(trip.endDate)"
    }

    private var daysUntil: Int? {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let start = fmt.date(from: trip.startDate) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: start).day ?? 0
        return days >= 0 ? days : nil
    }

    private var statusColor: Color {
        switch trip.status {
        case TripStatus.upcoming.rawValue:  return Color(hex: "#1A6B6A")
        case TripStatus.active.rawValue:    return Color(hex: "#E9A84C")
        case TripStatus.completed.rawValue: return Color(.systemGray)
        case TripStatus.cancelled.rawValue: return Color(.systemRed)
        default:                            return Color(.systemGray)
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Thumbnail
            ZStack {
                if let urlStr = trip.coverImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            gradientThumb
                        }
                    }
                } else {
                    gradientThumb
                }
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(AppFont.h4)
                    .lineLimit(1)

                Text(trip.destinationName)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(dateRange)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }

                if let days = daysUntil, trip.status == TripStatus.upcoming.rawValue {
                    Text(days == 0 ? "Today! 🎉" : "In \(days) days")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#E9A84C"))
                }
            }

            Spacer()

            // Status + chevron
            VStack(alignment: .trailing, spacing: 6) {
                Text(trip.status)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
    }

    private var gradientThumb: some View {
        LinearGradient(
            colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
        )
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.label)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isOn ? Color(hex: "#1A6B6A") : Color(UIColor.secondarySystemGroupedBackground))
                .foregroundStyle(isOn ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Loading state

private struct TripsLoadingState: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .frame(height: 100)
                        .shimmer()
                }
            }
            .padding(AppSpacing.md)
        }
    }
}

// MARK: - Empty state

private struct TripsEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "#2A9D8F").opacity(0.35))
            Text("No trips yet")
                .font(AppFont.h2).fontWeight(.bold)
            Text("Start planning your next adventure")
                .font(AppFont.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onCreate) {
                Label("Plan a Trip", systemImage: "plus")
                    .font(AppFont.body).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#1A6B6A"))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }
}

#Preview {
    TripsView()
        .environment(AuthViewModel())
}
