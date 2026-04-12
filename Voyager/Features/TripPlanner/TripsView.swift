import SwiftUI
import SwiftData

struct TripsView: View {
    @Query private var trips: [Trip]
    @State private var selectedFilter: TripStatus? = nil
    @State private var showAddTrip = false

    var filteredTrips: [Trip] {
        guard let filter = selectedFilter else { return trips }
        return trips.filter { $0.status == filter.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        FilterTab(title: "All", isSelected: selectedFilter == nil) {
                            selectedFilter = nil
                        }
                        ForEach(TripStatus.allCases, id: \.rawValue) { status in
                            FilterTab(title: status.rawValue, isSelected: selectedFilter == status) {
                                selectedFilter = selectedFilter == status ? nil : status
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                Divider()

                if filteredTrips.isEmpty {
                    TripsEmptyState(onCreate: { showAddTrip = true })
                } else {
                    List {
                        ForEach(filteredTrips) { trip in
                            TripRowView(trip: trip)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("My Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTrip) {
                Text("Add Trip — coming soon")
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Filter tab

private struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.label)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color(hex: "#1A6B6A") : Color(UIColor.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Trip row

private struct TripRowView: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Cover image / placeholder
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color(hex: "#2A9D8F").opacity(0.2))
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundStyle(Color(hex: "#1A6B6A"))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(AppFont.h4)
                    .lineLimit(1)
                Text(trip.destinationName)
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(trip.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(.secondary)
                    Text("→")
                        .foregroundStyle(.secondary)
                    Text(trip.endDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(trip.status)
                .font(AppFont.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#1A6B6A").opacity(0.1))
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .clipShape(Capsule())
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
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
                .foregroundStyle(Color(hex: "#2A9D8F").opacity(0.4))
            Text("No trips yet")
                .font(AppFont.h2)
                .fontWeight(.bold)
            Text("Start planning your next adventure")
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onCreate) {
                Label("Plan a Trip", systemImage: "plus")
                    .font(AppFont.body)
                    .fontWeight(.semibold)
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
        .modelContainer(for: Trip.self, inMemory: true)
}
