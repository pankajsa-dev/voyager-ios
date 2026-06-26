import Foundation

// MARK: - Shared model (read by widget, written by app)

/// Lightweight trip snapshot shared via App Group UserDefaults.
/// Must be kept in sync with TripDTO fields used here.
struct WidgetTripEntry: Codable {
    let tripId: String
    let title: String
    let destinationName: String
    let startDate: String           // "yyyy-MM-dd"
    let endDate: String             // "yyyy-MM-dd"
    let coverImageUrl: String?
}

// MARK: - Shared storage

enum WidgetSharedData {
    static let appGroupID      = "group.com.pankajapps.voyager"
    static let nextTripKey     = "widget_next_trip"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Called from the main app after fetching trips. Persists the nearest
    /// upcoming trip so the widget can read it without a network call.
    static func saveNextTrip(_ trip: WidgetTripEntry?) {
        guard let defaults else { return }
        if let trip, let data = try? JSONEncoder().encode(trip) {
            defaults.set(data, forKey: nextTripKey)
        } else {
            defaults.removeObject(forKey: nextTripKey)
        }
    }

    /// Called by the widget extension's TimelineProvider.
    static func loadNextTrip() -> WidgetTripEntry? {
        guard let defaults,
              let data = defaults.data(forKey: nextTripKey),
              let trip = try? JSONDecoder().decode(WidgetTripEntry.self, from: data)
        else { return nil }
        return trip
    }

    /// Days from today until startDate ("yyyy-MM-dd"). Negative = past.
    static func daysUntil(startDate: String) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: startDate) else { return 0 }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: Date()), to: date
        ).day ?? 0
        return days
    }
}
