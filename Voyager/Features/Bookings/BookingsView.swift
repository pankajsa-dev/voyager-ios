import SwiftUI
import SwiftData

struct BookingsView: View {
    @Query private var bookings: [Booking]
    @State private var selectedType: BookingType? = nil
    @State private var showAddBooking = false

    var filteredBookings: [Booking] {
        guard let type = selectedType else { return bookings }
        return bookings.filter { $0.type == type.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        BookingTypeChip(emoji: "📋", title: "All", isSelected: selectedType == nil) {
                            selectedType = nil
                        }
                        ForEach(BookingType.allCases, id: \.rawValue) { type in
                            BookingTypeChip(emoji: type.emoji, title: type.rawValue, isSelected: selectedType == type) {
                                selectedType = selectedType == type ? nil : type
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                Divider()

                if filteredBookings.isEmpty {
                    BookingsEmptyState()
                } else {
                    List(filteredBookings) { booking in
                        BookingRowView(booking: booking)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Bookings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddBooking = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddBooking) {
                Text("Add Booking — coming soon")
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Type chip

private struct BookingTypeChip: View {
    let emoji: String
    let title: String
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

// MARK: - Booking row

private struct BookingRowView: View {
    let booking: Booking

    var statusColor: Color {
        switch BookingStatus(rawValue: booking.status) {
        case .confirmed: return Color(hex: "#3AAA7A")
        case .pending:   return Color(hex: "#E9A84C")
        case .cancelled: return Color(hex: "#E05D5D")
        default:         return .secondary
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Type icon
            Text(BookingType(rawValue: booking.type)?.emoji ?? "📋")
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(Color(hex: "#1A6B6A").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

            VStack(alignment: .leading, spacing: 4) {
                Text(booking.title)
                    .font(AppFont.h4)
                    .lineLimit(1)
                if !booking.providerName.isEmpty {
                    Text(booking.providerName)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(.secondary)
                }
                Text(booking.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(booking.status)
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusColor)
                if booking.totalPrice > 0 {
                    Text(booking.totalPrice, format: .currency(code: booking.currency))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
    }
}

// MARK: - Empty state

private struct BookingsEmptyState: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "ticket")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "#2A9D8F").opacity(0.4))
            Text("No bookings yet")
                .font(AppFont.h2)
                .fontWeight(.bold)
            Text("Add flights, hotels and experiences\nto keep everything in one place")
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }
}

#Preview {
    BookingsView()
        .modelContainer(for: Booking.self, inMemory: true)
}
