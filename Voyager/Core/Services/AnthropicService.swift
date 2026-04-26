import Foundation

// MARK: - Extracted booking data

struct ExtractedBooking {
    var type: BookingType
    var title: String
    var providerName: String
    var bookingReference: String
    var confirmationNumber: String
    var startDate: Date?
    var endDate: Date?
    var totalPrice: Double
    var currency: String
    var notes: String
}

// MARK: - Local regex-based PDF parser (no API, no cost)

enum PDFBookingParser {

    static func extract(from text: String) -> ExtractedBooking {
        let lower = text.lowercased()
        let type  = detectType(in: lower)
        let (startDate, endDate) = extractDates(from: text, lower: lower, type: type)
        let (price, currency)    = extractPrice(from: text)

        return ExtractedBooking(
            type:               type,
            title:              extractTitle(from: text, lower: lower, type: type),
            providerName:       extractProvider(lower: lower),
            bookingReference:   extractBookingReference(from: text),
            confirmationNumber: extractConfirmationNumber(from: text),
            startDate:          startDate,
            endDate:            endDate,
            totalPrice:         price,
            currency:           currency,
            notes:              ""
        )
    }

    // MARK: - Type detection

    private static func detectType(in lower: String) -> BookingType {
        let scores: [(BookingType, [String])] = [
            (.flight,     ["flight", "airline", "airways", "departure", "arrival", "boarding pass", "pnr", "cabin", "seat"]),
            (.hotel,      ["hotel", "resort", "inn", "lodge", "check-in", "check in", "room type", "bed", "accommodation"]),
            (.carRental,  ["car rental", "vehicle rental", "car hire", "hire car", "pickup location", "rental car"]),
            (.tour,       ["tour", "excursion", "guided tour", "day trip"]),
            (.transfer,   ["transfer", "shuttle", "airport pickup", "chauffeur"]),
            (.experience, ["experience", "admission", "entry ticket", "attraction", "museum", "activity"]),
        ]
        let best = scores.max { a, b in
            a.1.filter { lower.contains($0) }.count < b.1.filter { lower.contains($0) }.count
        }
        return best?.0 ?? .flight
    }

    // MARK: - Title

    private static func extractTitle(from text: String, lower: String, type: BookingType) -> String {
        if type == .flight {
            // IATA route with various separators: "LHR → JFK", "LHR-JFK", "LHR to JFK"
            if let route = firstMatch(#"[A-Z]{3}\s*[→\-–>]\s*[A-Z]{3}"#, in: text) {
                return route.replacingOccurrences(of: "-", with: " → ")
            }
            // City/airport names: "London Heathrow to New York" or "From London To New York"
            if let route = captureGroup(
                #"(?i)(?:from\s+)?([A-Za-z ]{3,25})\s+(?:to|→|-)\s+([A-Za-z ]{3,25})"#,
                in: text, group: 0
            ) {
                let cleaned = route
                    .replacingOccurrences(of: "(?i)from\\s+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if cleaned.count < 60 { return cleaned }
            }
            // Flight number as fallback: "BA 456" or "BA456"
            if let flight = firstMatch(#"\b[A-Z]{2}\d{3,4}\b"#, in: text) {
                return flight
            }
        }

        // Hotel / venue: first short line containing a hotel keyword
        for line in text.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard (4...80).contains(t.count) else { continue }
            let l = t.lowercased()
            if l.contains("hotel") || l.contains("resort") || l.contains("inn") || l.contains("lodge") {
                return t
            }
        }
        return ""
    }

    // MARK: - Provider

    private static let knownAirlines = [
        "British Airways", "American Airlines", "Delta Air Lines", "Delta", "United Airlines",
        "Emirates", "Lufthansa", "Air France", "KLM", "Singapore Airlines",
        "Qantas", "Air India", "IndiGo", "Ryanair", "easyJet", "Southwest",
        "Alaska Airlines", "JetBlue", "Air Canada", "Turkish Airlines",
        "Etihad Airways", "Etihad", "Qatar Airways", "Cathay Pacific",
        "Japan Airlines", "ANA", "AirAsia", "Wizz Air", "Norwegian",
        "Iberia", "Finnair", "Vueling", "TAP Air Portugal", "Swiss", "Austrian",
    ]

    private static let knownHotels = [
        "Marriott", "Hilton", "Hyatt", "IHG", "Accor", "Wyndham",
        "Best Western", "Radisson", "Sheraton", "Westin", "Renaissance",
        "Four Seasons", "Ritz-Carlton", "Mandarin Oriental", "InterContinental",
        "Holiday Inn", "Crowne Plaza", "Novotel", "Ibis", "Mercure",
    ]

    private static func extractProvider(lower: String) -> String {
        for name in knownAirlines + knownHotels {
            if lower.contains(name.lowercased()) { return name }
        }
        return ""
    }

    // MARK: - Booking reference / PNR

    private static func extractBookingReference(from text: String) -> String {
        let labeled = [
            #"(?i)(?:booking\s+ref(?:erence)?|PNR|reservation\s+(?:code|number)|booking\s+(?:code|number))\s*[:\s#]+([A-Z0-9]{4,10})"#,
            #"(?i)reference\s*[:\s]+([A-Z0-9]{5,8})"#,
            #"(?i)order\s+(?:number|no\.?)\s*[:\s#]+([A-Z0-9\-]{4,15})"#,
        ]
        for p in labeled {
            if let m = captureGroup(p, in: text, group: 1) { return m }
        }
        // Standalone 6-char PNR (letters + digits, starts with letter)
        return captureGroup(#"\b([A-Z][A-Z0-9]{5})\b"#, in: text, group: 1) ?? ""
    }

    private static func extractConfirmationNumber(from text: String) -> String {
        let patterns = [
            #"(?i)confirmation\s+(?:number|code|no\.?)\s*[:\s#]+([A-Z0-9\-]{4,20})"#,
            #"(?i)e-?ticket(?:\s+number)?\s*[:\s]+([0-9]{10,14})"#,
            #"(?i)ticket\s+number\s*[:\s]+([A-Z0-9\-]{4,20})"#,
        ]
        for p in patterns {
            if let m = captureGroup(p, in: text, group: 1) { return m }
        }
        return ""
    }

    // MARK: - Dates
    // Strategy:
    // 1. Look for departure-labeled dates → startDate
    // 2. Look for return/arrival-labeled dates → endDate
    // 3. Fallback: collect all dates in text, exclude past/today (booking creation date),
    //    use earliest future date as startDate, next as endDate

    private static func extractDates(from text: String, lower: String, type: BookingType) -> (Date?, Date?) {
        let today = Calendar.current.startOfDay(for: Date())

        // Labeled departure
        let departureLabels = ["depart", "departure", "outbound", "travel date", "flight date",
                               "check-in", "check in", "checkin", "from date", "pickup"]
        let arrivalLabels   = ["return", "inbound", "arrival", "check-out", "check out",
                               "checkout", "to date", "dropoff", "drop-off", "land"]

        let startLabeled = extractLabeledDate(labels: departureLabels, from: text, lower: lower)
        let endLabeled   = extractLabeledDate(labels: arrivalLabels,   from: text, lower: lower)

        if let s = startLabeled {
            return (s, endLabeled)
        }

        // Fallback: all parseable dates in the text
        let allDates = parseAllDates(from: text)

        // Split into past (≤ today) and future (> today)
        let futureDates = allDates.filter { $0 > today }.sorted()
        let pastDates   = allDates.filter { $0 <= today }.sorted()

        // Future dates: first is departure, second is return (if round trip)
        if !futureDates.isEmpty {
            let start = futureDates.first!
            let end   = futureDates.count > 1 ? futureDates[1] : nil
            return (start, end)
        }

        // If only past dates found (PDF is for a completed trip), use them
        if pastDates.count >= 2 {
            return (pastDates[pastDates.count - 2], pastDates.last)
        }
        return (pastDates.first, nil)
    }

    private static func extractLabeledDate(labels: [String], from text: String, lower: String) -> Date? {
        let lines    = text.components(separatedBy: .newlines)
        let lLines   = lower.components(separatedBy: .newlines)

        for (i, lLine) in lLines.enumerated() {
            for label in labels {
                if lLine.contains(label) {
                    // Try the same line and the next line
                    let candidates = [lines[i], i + 1 < lines.count ? lines[i + 1] : ""]
                    for candidate in candidates {
                        if let d = extractFirstDate(from: candidate) { return d }
                    }
                }
            }
        }
        return nil
    }

    private static func extractFirstDate(from line: String) -> Date? {
        let dates = parseAllDates(from: line)
        return dates.first
    }

    private static func parseAllDates(from text: String) -> [Date] {
        var dates: [Date] = []
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")

        // ISO: 2026-05-15
        for m in allCaptures(#"\b(\d{4}-\d{2}-\d{2})\b"#, in: text) {
            fmt.dateFormat = "yyyy-MM-dd"
            if let d = fmt.date(from: m) { dates.append(Calendar.current.startOfDay(for: d)) }
        }

        // Slash/dot: 15/05/2026 or 15.05.2026
        for m in allCaptures(#"\b(\d{1,2}[/\.]\d{1,2}[/\.]\d{4})\b"#, in: text) {
            for f in ["dd/MM/yyyy", "d/M/yyyy", "dd.MM.yyyy", "d.M.yyyy", "MM/dd/yyyy", "M/d/yyyy"] {
                fmt.dateFormat = f
                if let d = fmt.date(from: m) { dates.append(Calendar.current.startOfDay(for: d)); break }
            }
        }

        // Written: "15 May 2026" or "15 May, 2026"
        let writtenPattern = #"\b(\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec),?\s+\d{4})\b"#
        for m in allCaptures(writtenPattern, in: text) {
            for f in ["d MMMM yyyy", "d MMM yyyy", "d MMMM, yyyy", "d MMM, yyyy"] {
                fmt.dateFormat = f
                if let d = fmt.date(from: m) { dates.append(Calendar.current.startOfDay(for: d)); break }
            }
        }

        // US written: "May 15, 2026" or "May 15 2026"
        let usPattern = #"\b((?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4})\b"#
        for m in allCaptures(usPattern, in: text) {
            for f in ["MMMM d, yyyy", "MMM d, yyyy", "MMMM d yyyy", "MMM d yyyy"] {
                fmt.dateFormat = f
                if let d = fmt.date(from: m) { dates.append(Calendar.current.startOfDay(for: d)); break }
            }
        }

        // Deduplicate and sort
        let unique = Array(Set(dates)).sorted()
        return unique
    }

    // MARK: - Price
    // Strategy:
    // 1. Scan lines bottom-to-top for a strong "grand total" label with a decimal amount
    // 2. Fall back to last line containing any "total" label
    // 3. Last resort: pick largest symbol-prefixed amount with decimals

    private static func extractPrice(from text: String) -> (Double, String) {
        let currency = detectCurrencySymbol(in: text)
        let lines = text.components(separatedBy: .newlines).reversed()

        // Strong total labels — scan bottom-up, first match wins
        let strongLabels = ["grand total", "total amount", "total fare", "total price",
                            "amount due", "amount payable", "total charged", "net total",
                            "amount to pay", "total cost"]
        for line in lines {
            let lower = line.lowercased()
            guard strongLabels.contains(where: { lower.contains($0) }) else { continue }
            if let val = extractDecimalAmount(from: line), val > 0 {
                return (val, currency)
            }
        }

        // Weaker "total" label — bottom-up, require decimal
        for line in lines {
            let lower = line.lowercased()
            guard lower.contains("total") && !lower.contains("subtotal") && !lower.contains("sub-total") else { continue }
            if let val = extractDecimalAmount(from: line), val > 0 {
                return (val, currency)
            }
        }

        // Symbol-prefixed fallback: pick the largest value with exactly 2 decimal places
        let symbolMap: [(String, String)] = [
            (#"[\$]\s*([\d,]+\.\d{2})"#, "USD"),
            (#"[€]\s*([\d,]+\.\d{2})"#, "EUR"),
            (#"[£]\s*([\d,]+\.\d{2})"#, "GBP"),
            (#"[₹]\s*([\d,]+\.\d{2})"#, "INR"),
        ]
        var symbolCandidates: [Double] = []
        for (pattern, _) in symbolMap {
            for raw in allCaptures(pattern, in: text) {
                let clean = raw.replacingOccurrences(of: ",", with: "")
                if let d = Double(clean), d > 0 { symbolCandidates.append(d) }
            }
        }
        if let best = symbolCandidates.max() { return (best, currency) }

        return (0, "USD")
    }

    // Extracts the last decimal number (e.g. 1,234.56) from a line
    private static func extractDecimalAmount(from line: String) -> Double? {
        // Must have 2 decimal places to avoid matching years or reference numbers
        let pattern = #"([\d,]+\.\d{2})"#
        var found: [Double] = []
        for raw in allCaptures(pattern, in: line) {
            let clean = raw.replacingOccurrences(of: ",", with: "")
            if let d = Double(clean) { found.append(d) }
        }
        return found.last  // rightmost/last amount on the line is usually the total
    }

    private static func detectCurrencySymbol(in text: String) -> String {
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("₹") { return "INR" }
        for code in ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"] {
            if text.contains(code) { return code }
        }
        return "USD"
    }

    // MARK: - Regex helpers

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range)
    }

    private static func captureGroup(_ pattern: String, in text: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > group else { return nil }
        let r = m.range(at: group)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }

    private static func allCaptures(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m -> String? in
            let idx = m.numberOfRanges > 1 ? 1 : 0
            let r = m.range(at: idx)
            guard r.location != NSNotFound else { return nil }
            return ns.substring(with: r)
        }
    }
}
