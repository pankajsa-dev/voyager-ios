import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TripCountdownEntry: TimelineEntry {
    let date: Date
    let trip: WidgetTripEntry?
    let daysUntil: Int
}

// MARK: - Timeline Provider

struct TripCountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> TripCountdownEntry {
        TripCountdownEntry(
            date: Date(),
            trip: WidgetTripEntry(
                tripId: "placeholder",
                title: "Tokyo Adventure",
                destinationName: "Tokyo",
                startDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 12)),
                endDate:   ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 22)),
                coverImageUrl: nil
            ),
            daysUntil: 12
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TripCountdownEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripCountdownEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh at midnight so the day count stays current
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func makeEntry() -> TripCountdownEntry {
        let trip = WidgetSharedData.loadNextTrip()
        let days = trip.map { WidgetSharedData.daysUntil(startDate: $0.startDate) } ?? 0
        return TripCountdownEntry(date: Date(), trip: trip, daysUntil: max(0, days))
    }
}

// MARK: - Widget Views

struct TripCountdownWidgetView: View {
    let entry: TripCountdownEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let trip = entry.trip, entry.daysUntil >= 0 {
            switch family {
            case .systemSmall:  SmallWidgetView(trip: trip, days: entry.daysUntil)
            case .systemMedium: MediumWidgetView(trip: trip, days: entry.daysUntil)
            default:            SmallWidgetView(trip: trip, days: entry.daysUntil)
            }
        } else {
            NoTripView()
        }
    }
}

// MARK: Small widget

private struct SmallWidgetView: View {
    let trip: WidgetTripEntry
    let days: Int

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#0A3D62"), Color(hex: "#1A6EA8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Decorative circle
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 120)
                .offset(x: 55, y: -45)

            VStack(alignment: .leading, spacing: 4) {
                // Icon + label
                Label("NEXT TRIP", systemImage: "airplane.departure")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .labelStyle(.titleAndIcon)

                Spacer()

                // Countdown
                if days == 0 {
                    Text("Today! 🎉")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(days)")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("days")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, 6)
                    }
                }

                // Destination
                Text(trip.destinationName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Date range
                Text(formattedRange)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var formattedRange: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d"
        guard let s = fmt.date(from: trip.startDate),
              let e = fmt.date(from: trip.endDate) else { return trip.startDate }
        return "\(out.string(from: s)) – \(out.string(from: e))"
    }
}

// MARK: Medium widget

private struct MediumWidgetView: View {
    let trip: WidgetTripEntry
    let days: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A3D62"), Color(hex: "#1A6EA8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 200)
                .offset(x: 120, y: -70)

            Circle()
                .fill(Color(hex: "#E8734A").opacity(0.15))
                .frame(width: 80)
                .offset(x: 150, y: 40)

            HStack(spacing: 0) {
                // Left: countdown block
                VStack(alignment: .leading, spacing: 6) {
                    Label("NEXT TRIP", systemImage: "airplane.departure")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .labelStyle(.titleAndIcon)

                    Spacer()

                    if days == 0 {
                        Text("Today! 🎉")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(days)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("days")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("to go")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .leading)

                Divider()
                    .background(.white.opacity(0.2))
                    .padding(.vertical, 14)

                // Right: trip details
                VStack(alignment: .leading, spacing: 5) {
                    Text(trip.destinationName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !trip.title.isEmpty && trip.title != trip.destinationName {
                        Text(trip.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    Text(formattedRange)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    // Coral accent pill
                    HStack(spacing: 4) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 10))
                        Text(days == 0 ? "Bon voyage!" : "Get ready!")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#E8734A").opacity(0.85))
                    .clipShape(Capsule())
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private var formattedRange: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d"
        let outYear = DateFormatter(); outYear.dateFormat = "MMM d, yyyy"
        guard let s = fmt.date(from: trip.startDate),
              let e = fmt.date(from: trip.endDate) else { return trip.startDate }
        return "\(out.string(from: s)) – \(outYear.string(from: e))"
    }
}

// MARK: No trip view

private struct NoTripView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A1A2E"), Color(hex: "#16213E")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                Image(systemName: "map")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.5))
                Text("No upcoming trips")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Open Voyager to plan one")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Color hex helper (widget-local, mirrors AppTheme)

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64(0)
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255)
    }
}

// MARK: - Widget declaration

struct VoyagerTripCountdownWidget: Widget {
    let kind = "VoyagerTripCountdown"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripCountdownProvider()) { entry in
            TripCountdownWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "#0A3D62"), Color(hex: "#1A6EA8")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Trip Countdown")
        .description("See how many days until your next Voyager trip.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct VoyagerWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoyagerTripCountdownWidget()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    VoyagerTripCountdownWidget()
} timeline: {
    TripCountdownEntry(
        date: Date(),
        trip: WidgetTripEntry(
            tripId: "1",
            title: "Golden Week in Japan",
            destinationName: "Tokyo",
            startDate: {
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                return fmt.string(from: Date().addingTimeInterval(86400 * 7))
            }(),
            endDate: {
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                return fmt.string(from: Date().addingTimeInterval(86400 * 17))
            }(),
            coverImageUrl: nil
        ),
        daysUntil: 7
    )
}

#Preview(as: .systemMedium) {
    VoyagerTripCountdownWidget()
} timeline: {
    TripCountdownEntry(
        date: Date(),
        trip: WidgetTripEntry(
            tripId: "1",
            title: "Golden Week in Japan",
            destinationName: "Tokyo",
            startDate: {
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                return fmt.string(from: Date().addingTimeInterval(86400 * 7))
            }(),
            endDate: {
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                return fmt.string(from: Date().addingTimeInterval(86400 * 17))
            }(),
            coverImageUrl: nil
        ),
        daysUntil: 7
    )
}
