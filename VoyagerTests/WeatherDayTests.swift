import Testing
import Foundation
@testable import Voyager

// MARK: - WeatherDay static mapping tests
//
// These cover the WMO weather code → SF Symbol, description, and hex colour
// mappings. Any change to WeatherDay's switch statements will surface here.

@Suite("WeatherDay")
struct WeatherDayTests {

    // MARK: - icon(for:)

    @Test("Clear sky → sun.max.fill")
    func icon_clearSky() {
        #expect(WeatherDay.icon(for: 0) == "sun.max.fill")
    }

    @Test("Mainly clear (1) and partly cloudy (2) → cloud.sun.fill")
    func icon_partlyCloudy() {
        #expect(WeatherDay.icon(for: 1) == "cloud.sun.fill")
        #expect(WeatherDay.icon(for: 2) == "cloud.sun.fill")
    }

    @Test("Overcast (3) → cloud.fill")
    func icon_overcast() {
        #expect(WeatherDay.icon(for: 3) == "cloud.fill")
    }

    @Test("Fog (45, 48) → cloud.fog.fill")
    func icon_fog() {
        #expect(WeatherDay.icon(for: 45) == "cloud.fog.fill")
        #expect(WeatherDay.icon(for: 48) == "cloud.fog.fill")
    }

    @Test("Drizzle (51–55) → cloud.drizzle.fill")
    func icon_drizzle() {
        for code in [51, 53, 55] {
            #expect(WeatherDay.icon(for: code) == "cloud.drizzle.fill")
        }
    }

    @Test("Rain (61–65) → cloud.rain.fill")
    func icon_rain() {
        for code in [61, 63, 65] {
            #expect(WeatherDay.icon(for: code) == "cloud.rain.fill")
        }
    }

    @Test("Snow (71–75) → cloud.snow.fill")
    func icon_snow() {
        for code in [71, 73, 75] {
            #expect(WeatherDay.icon(for: code) == "cloud.snow.fill")
        }
    }

    @Test("Showers (80–82) → cloud.heavyrain.fill")
    func icon_showers() {
        for code in [80, 81, 82] {
            #expect(WeatherDay.icon(for: code) == "cloud.heavyrain.fill")
        }
    }

    @Test("Thunderstorm (95) → cloud.bolt.fill")
    func icon_thunderstorm() {
        #expect(WeatherDay.icon(for: 95) == "cloud.bolt.fill")
    }

    @Test("Hail storm (96, 99) → cloud.bolt.rain.fill")
    func icon_hailStorm() {
        #expect(WeatherDay.icon(for: 96) == "cloud.bolt.rain.fill")
        #expect(WeatherDay.icon(for: 99) == "cloud.bolt.rain.fill")
    }

    @Test("Unknown code falls back to cloud.fill")
    func icon_unknownCode() {
        #expect(WeatherDay.icon(for: 999) == "cloud.fill")
        #expect(WeatherDay.icon(for: -1)  == "cloud.fill")
    }

    // MARK: - description(for:)

    @Test("Clear sky description")
    func description_clearSky() {
        #expect(WeatherDay.description(for: 0) == "Clear sky")
    }

    @Test("Mainly clear description")
    func description_mainlyClear() {
        #expect(WeatherDay.description(for: 1) == "Mainly clear")
    }

    @Test("Partly cloudy description")
    func description_partlyCloudy() {
        #expect(WeatherDay.description(for: 2) == "Partly cloudy")
    }

    @Test("Overcast description")
    func description_overcast() {
        #expect(WeatherDay.description(for: 3) == "Overcast")
    }

    @Test("Fog descriptions")
    func description_fog() {
        #expect(WeatherDay.description(for: 45) == "Foggy")
        #expect(WeatherDay.description(for: 48) == "Foggy")
    }

    @Test("Rain description")
    func description_rain() {
        #expect(WeatherDay.description(for: 61) == "Rain")
    }

    @Test("Snow description")
    func description_snow() {
        #expect(WeatherDay.description(for: 71) == "Snow")
    }

    @Test("Thunderstorm description")
    func description_thunderstorm() {
        #expect(WeatherDay.description(for: 95) == "Thunderstorm")
    }

    @Test("Hail storm description")
    func description_hailStorm() {
        #expect(WeatherDay.description(for: 96) == "Hail storm")
        #expect(WeatherDay.description(for: 99) == "Hail storm")
    }

    @Test("Unknown code returns a non-empty description")
    func description_unknownCode() {
        let desc = WeatherDay.description(for: 500)
        #expect(!desc.isEmpty)
    }

    // MARK: - color(for:)

    @Test("Sunny codes return amber colour")
    func color_sunny() {
        #expect(WeatherDay.color(for: 0) == "#E9A84C")
        #expect(WeatherDay.color(for: 1) == "#E9A84C")
    }

    @Test("Cloudy codes return grey colour")
    func color_cloudy() {
        #expect(WeatherDay.color(for: 2) == "#6B7B78")
        #expect(WeatherDay.color(for: 3) == "#6B7B78")
    }

    @Test("Rain codes return teal colour")
    func color_rain() {
        for code in [51, 53, 55, 61, 63, 65] {
            #expect(WeatherDay.color(for: code) == "#2A9D8F")
        }
    }

    @Test("Snow codes return icy blue colour")
    func color_snow() {
        for code in [71, 73, 75] {
            #expect(WeatherDay.color(for: code) == "#90B4C5")
        }
    }

    @Test("Storm codes return dark purple colour")
    func color_storm() {
        #expect(WeatherDay.color(for: 95) == "#4A4A72")
        #expect(WeatherDay.color(for: 96) == "#4A4A72")
    }

    @Test("Unknown code returns a non-empty colour string")
    func color_unknownCode() {
        let colour = WeatherDay.color(for: 999)
        #expect(!colour.isEmpty)
        #expect(colour.hasPrefix("#"))
    }

    // MARK: - WeatherDay initialisation

    @Test("WeatherDay exposes correct icon and description properties")
    func weatherDay_properties() {
        let day = WeatherDay(date: Date(), maxTemp: 25.0, minTemp: 18.0, code: 0)
        #expect(day.icon        == "sun.max.fill")
        #expect(day.description == "Clear sky")
    }

    @Test("WeatherDay id is unique across instances")
    func weatherDay_uniqueIds() {
        let a = WeatherDay(date: Date(), maxTemp: 25.0, minTemp: 18.0, code: 0)
        let b = WeatherDay(date: Date(), maxTemp: 25.0, minTemp: 18.0, code: 0)
        #expect(a.id != b.id)
    }
}
