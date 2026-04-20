import Foundation

// MARK: - Unsplash photo response (only fields we need)

private struct UnsplashSearchResponse: Decodable {
    let results: [UnsplashPhoto]
}

private struct UnsplashPhoto: Decodable {
    struct Urls: Decodable {
        let regular: String   // ~1080px wide, good for hero images
        let small: String     // ~400px wide, good for cards
    }
    let urls: Urls
}

// MARK: - DestinationImageService
//
// Fetches a landscape photo from Unsplash for a destination name + country
// when the destination has no image_urls stored in the database.
//
// - Results are cached in memory for the session (no duplicate API calls).
// - Silently no-ops when UnsplashConfig is not set up yet.

@Observable
final class DestinationImageService {

    // Shared singleton — every view reads from the same cache
    static let shared = DestinationImageService()

    // cache key: "\(destinationName)|\(country)" → regular photo URL
    private var cache: [String: String] = [:]
    private var inFlight: Set<String>   = []

    private init() {}

    // Returns a cached URL if we already have one, otherwise nil (triggers fetch).
    func cachedURL(for destination: String, country: String) -> String? {
        cache[cacheKey(destination, country)]
    }

    // Fetches a photo from Unsplash and stores it in the cache.
    // Safe to call multiple times — duplicate in-flight calls are deduplicated.
    func fetch(destination: String, country: String) async {
        guard UnsplashConfig.isConfigured else { return }

        let key = cacheKey(destination, country)
        guard cache[key] == nil, !inFlight.contains(key) else { return }

        inFlight.insert(key)
        defer { inFlight.remove(key) }

        // Build query: "Tokyo Japan landscape" gets better travel photos
        let query = "\(destination) \(country) travel"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination

        let urlString = "https://api.unsplash.com/search/photos"
            + "?query=\(query)"
            + "&per_page=1"
            + "&orientation=landscape"
            + "&content_filter=high"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(UnsplashConfig.accessKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response  = try JSONDecoder().decode(UnsplashSearchResponse.self, from: data)
            if let photo = response.results.first {
                await MainActor.run {
                    self.cache[key] = photo.urls.regular
                }
            }
        } catch {
            // Silently ignore — gradient placeholder will show instead
        }
    }

    private func cacheKey(_ destination: String, _ country: String) -> String {
        "\(destination)|\(country)"
    }
}
