import Foundation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let currency     = "voyager_preferred_currency"
        static let languageCode = "voyager_preferred_language"
    }

    var currency: String {
        didSet { UserDefaults.standard.set(currency, forKey: Keys.currency) }
    }

    var languageCode: String {
        didSet { UserDefaults.standard.set(languageCode, forKey: Keys.languageCode) }
    }

    var languageDisplayName: String {
        Self.supportedLanguages.first { $0.code == languageCode }?.name
            ?? Locale.current.localizedString(forLanguageCode: languageCode)
            ?? languageCode.uppercased()
    }

    static let supportedCurrencies = [
        "USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY",
        "SGD", "AED", "CHF", "SEK", "NOK", "DKK", "HRK",
        "MXN", "BRL", "ZAR", "THB", "KRW", "NZD",
    ]

    static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("es", "Español"),
        ("it", "Italiano"),
        ("pt", "Português"),
        ("hr", "Hrvatski"),
        ("nl", "Nederlands"),
        ("pl", "Polski"),
        ("ar", "العربية"),
        ("hi", "हिन्दी"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("zh", "中文"),
    ]

    private init() {
        let localeCurrency = Locale.current.currency?.identifier ?? "USD"
        let localeLanguage = Locale.current.language.languageCode?.identifier ?? "en"

        currency     = UserDefaults.standard.string(forKey: Keys.currency)     ?? localeCurrency
        languageCode = UserDefaults.standard.string(forKey: Keys.languageCode) ?? localeLanguage
    }
}
