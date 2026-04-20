import Foundation

// MARK: - Weather models

struct WeatherForecast {
    let city: String
    let days: [WeatherDay]
}

struct WeatherDay: Identifiable {
    let id = UUID()
    let date: Date
    let maxTemp: Double
    let minTemp: Double
    let code: Int           // WMO weather code

    var icon: String { Self.icon(for: code) }
    var description: String { Self.description(for: code) }

    // WMO weather interpretation codes → SF Symbol + label
    static func icon(for code: Int) -> String {
        switch code {
        case 0:           return "sun.max.fill"
        case 1, 2:        return "cloud.sun.fill"
        case 3:           return "cloud.fill"
        case 45, 48:      return "cloud.fog.fill"
        case 51, 53, 55:  return "cloud.drizzle.fill"
        case 61, 63, 65:  return "cloud.rain.fill"
        case 71, 73, 75:  return "cloud.snow.fill"
        case 80, 81, 82:  return "cloud.heavyrain.fill"
        case 95:          return "cloud.bolt.fill"
        case 96, 99:      return "cloud.bolt.rain.fill"
        default:          return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0:           return "Clear sky"
        case 1:           return "Mainly clear"
        case 2:           return "Partly cloudy"
        case 3:           return "Overcast"
        case 45, 48:      return "Foggy"
        case 51, 53, 55:  return "Drizzle"
        case 61, 63, 65:  return "Rain"
        case 71, 73, 75:  return "Snow"
        case 80, 81, 82:  return "Showers"
        case 95:          return "Thunderstorm"
        case 96, 99:      return "Hail storm"
        default:          return "Cloudy"
        }
    }

    static func color(for code: Int) -> String {
        switch code {
        case 0, 1:        return "#E9A84C"   // amber — sunny
        case 2, 3:        return "#6B7B78"   // grey — cloudy
        case 45, 48:      return "#8E9EA0"   // fog
        case 51...65:     return "#2A9D8F"   // rain — teal
        case 71...75:     return "#90B4C5"   // snow — icy blue
        case 80...82:     return "#1A6B6A"   // heavy rain — deep teal
        case 95, 96, 99:  return "#4A4A72"   // storm — dark purple
        default:          return "#6B7B78"
        }
    }
}

// MARK: - Service

@Observable
final class WeatherService {
    var forecast: WeatherForecast?
    var isLoading  = false
    var errorMessage: String?

    // ── Fetch 7-day forecast for a destination name ───────────────────────
    func fetch(for destinationName: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        // Step 1: geocode the destination name → lat/lon
        let city = destinationName.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? destinationName

        guard let (lat, lon) = await geocode(city: city) else {
            await MainActor.run { errorMessage = "Location not found."; isLoading = false }
            return
        }

        // Step 2: fetch weather forecast
        let weatherURL = URL(string:
            "https://api.open-meteo.com/v1/forecast" +
            "?latitude=\(lat)&longitude=\(lon)" +
            "&daily=weathercode,temperature_2m_max,temperature_2m_min" +
            "&forecast_days=7&timezone=auto"
        )!

        do {
            let (data, _) = try await URLSession.shared.data(from: weatherURL)
            let raw = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            let dateParser = DateFormatter()
            dateParser.dateFormat = "yyyy-MM-dd"

            var days: [WeatherDay] = []
            for i in 0..<min(raw.daily.time.count, 7) {
                let date = dateParser.date(from: raw.daily.time[i]) ?? Date()
                days.append(WeatherDay(
                    date:    date,
                    maxTemp: raw.daily.temperature2mMax[i],
                    minTemp: raw.daily.temperature2mMin[i],
                    code:    raw.daily.weathercode[i]
                ))
            }

            await MainActor.run {
                forecast = WeatherForecast(city: city, days: days)
                isLoading = false
            }
        } catch {
            await MainActor.run { errorMessage = "Weather unavailable."; isLoading = false }
        }
    }

    // ── Geocode via Open-Meteo (free, no key) ─────────────────────────────
    private func geocode(city: String) async -> (Double, Double)? {
        let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let geo = try? JSONDecoder().decode(GeocodingResponse.self, from: data),
              let result = geo.results?.first else { return nil }
        return (result.latitude, result.longitude)
    }
}

// MARK: - Open-Meteo decodable models (private)

private struct OpenMeteoResponse: Codable {
    let daily: DailyData

    struct DailyData: Codable {
        let time:               [String]
        let weathercode:        [Int]
        let temperature2mMax:   [Double]
        let temperature2mMin:   [Double]

        enum CodingKeys: String, CodingKey {
            case time, weathercode
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
        }
    }
}

private struct GeocodingResponse: Codable {
    let results: [GeoResult]?

    struct GeoResult: Codable {
        let latitude:  Double
        let longitude: Double
    }
}
