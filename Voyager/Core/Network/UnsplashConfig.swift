// MARK: - Unsplash Configuration
//
// One-time setup (free — 50 requests/hour for demo, 5000/hour after approval):
//  1. Go to https://unsplash.com/developers → "Your Apps" → "New Application"
//  2. Accept the guidelines, give your app a name (e.g. "Voyager")
//  3. Copy the "Access Key" from the app detail page
//  4. Paste it below and save.
//
// That's it — the app will automatically fetch real photos for any
// destination that has no image in the database.

enum UnsplashConfig {
    /// Paste your Unsplash Access Key here
    static let accessKey = "00RI3Uf6E6ibpuYo6LP_Jnh1ELOpJKoSXjUXUMIery4"

    static var isConfigured: Bool {
        !accessKey.hasPrefix("YOUR_")
    }
}
