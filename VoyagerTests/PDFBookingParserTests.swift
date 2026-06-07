import Testing
import Foundation
@testable import Voyager

// MARK: - PDFBookingParser unit tests
//
// All dates in samples use 2027 so they are always "future" relative to
// today, which matters for the date-extraction fallback logic.

@Suite("PDFBookingParser")
struct PDFBookingParserTests {

    // MARK: - Type detection

    @Test("Detects flight from strong flight keywords")
    func typeDetection_flight() {
        let text = "Boarding Pass  LH 401  PNR: ABCD12  Departure: Frankfurt  Seat 14A"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .flight)
    }

    @Test("Detects hotel from check-in / room-type keywords")
    func typeDetection_hotel() {
        let text = "Hotel Booking Confirmation\nCheck-in: 20 Jun 2027\nRoom Type: Deluxe King\nAccommodation"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .hotel)
    }

    @Test("Detects car rental from 'car hire' keywords")
    func typeDetection_carRental() {
        let text = "Car Hire Confirmation\nPickup Location: CDG Airport\nVehicle Rental Economy"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .carRental)
    }

    @Test("Detects tour from tour keywords")
    func typeDetection_tour() {
        let text = "Guided Tour Booking\nExcursion to Colosseum\nDay Trip Included"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .tour)
    }

    @Test("Detects experience from admission / ticket keywords")
    func typeDetection_experience() {
        let text = "Entry Ticket  Museum of Natural History  Admission valid 15 Jun 2027"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .experience)
    }

    // MARK: - Title extraction

    @Test("Extracts IATA route with arrow separator")
    func titleExtraction_iataArrow() {
        let text = "Flight LHR → JFK  Departure 10 Jul 2027"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.title == "LHR → JFK")
    }

    @Test("Extracts IATA route with dash separator and normalises to arrow")
    func titleExtraction_iataDash() {
        let text = "Flight FRA-JFK  Boarding Pass"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.title == "FRA → JFK")
    }

    @Test("Extracts flight number as fallback title")
    func titleExtraction_flightNumber() {
        let text = "Airline: Lufthansa  Flight LH401  No route info"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.title == "LH401")
    }

    @Test("Extracts hotel name from line containing 'hotel' keyword")
    func titleExtraction_hotelLine() {
        let text = """
            Marriott Hotels & Resorts
            The Paris Marriott Champs-Elysées Hotel
            Check-in: 20 Jun 2027
            Grand Total: EUR 1,250.00
            """
        let result = PDFBookingParser.extract(from: text)
        #expect(result.title.lowercased().contains("hotel"))
    }

    // MARK: - Provider extraction

    @Test("Extracts known airline name")
    func providerExtraction_airline() {
        let text = "Lufthansa Airlines  Flight LH401  Frankfurt to JFK"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.providerName == "Lufthansa")
    }

    @Test("Extracts known hotel chain name")
    func providerExtraction_hotel() {
        let text = "Welcome to the Marriott Hotel. Check-in Date: 20 Jun 2027"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.providerName == "Marriott")
    }

    @Test("Returns empty string for unknown provider")
    func providerExtraction_unknown() {
        let text = "Some unknown travel company confirmation XYZ-123"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.providerName == "")
    }

    // MARK: - Booking reference extraction

    @Test("Extracts 'Booking Reference:' labeled PNR")
    func bookingRef_labeledRef() {
        let text = "Booking Reference: ABCD12  Flight LH401"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.bookingReference == "ABCD12")
    }

    @Test("Extracts PNR label variant")
    func bookingRef_pnrLabel() {
        let text = "PNR: XY7890  Airline: British Airways"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.bookingReference == "XY7890")
    }

    @Test("Extracts confirmation number")
    func confirmationNumber_labeled() {
        let text = "Confirmation Number: CONF123ABC  Check-in: 20 Jun 2027"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.confirmationNumber == "CONF123ABC")
    }

    // MARK: - Date extraction

    @Test("Parses ISO date format yyyy-MM-dd")
    func dateExtraction_iso() {
        let text = "Flight departure: 2027-08-15  airline Lufthansa PNR XYZABC"
        let result = PDFBookingParser.extract(from: text)
        guard let startDate = result.startDate else {
            Issue.record("Expected a startDate but got nil")
            return
        }
        let cal = Calendar.current
        #expect(cal.component(.year,  from: startDate) == 2027)
        #expect(cal.component(.month, from: startDate) == 8)
        #expect(cal.component(.day,   from: startDate) == 15)
    }

    @Test("Parses written date format '15 Jun 2027'")
    func dateExtraction_written() {
        let text = "Departure 15 Jun 2027  Flight LH 401  PNR AAAA11"
        let result = PDFBookingParser.extract(from: text)
        guard let startDate = result.startDate else {
            Issue.record("Expected a startDate but got nil")
            return
        }
        let cal = Calendar.current
        #expect(cal.component(.year,  from: startDate) == 2027)
        #expect(cal.component(.month, from: startDate) == 6)
        #expect(cal.component(.day,   from: startDate) == 15)
    }

    @Test("Parses US written date format 'Jun 15, 2027'")
    func dateExtraction_usWritten() {
        let text = "Travel Date: Jun 15, 2027  PNR BBBB22  Flight AA 200"
        let result = PDFBookingParser.extract(from: text)
        guard let startDate = result.startDate else {
            Issue.record("Expected a startDate but got nil")
            return
        }
        let cal = Calendar.current
        #expect(cal.component(.month, from: startDate) == 6)
        #expect(cal.component(.day,   from: startDate) == 15)
    }

    @Test("Parses slash date format dd/MM/yyyy")
    func dateExtraction_slash() {
        let text = "Check-in: 20/08/2027  Hotel Hilton Room Type: Standard"
        let result = PDFBookingParser.extract(from: text)
        guard let startDate = result.startDate else {
            Issue.record("Expected a startDate but got nil")
            return
        }
        let cal = Calendar.current
        #expect(cal.component(.day,   from: startDate) == 20)
        #expect(cal.component(.month, from: startDate) == 8)
        #expect(cal.component(.year,  from: startDate) == 2027)
    }

    @Test("Extracts both departure and return dates when labeled")
    func dateExtraction_departurePlusReturn() {
        let text = """
            Depart: 15 Jun 2027
            Return: 29 Jun 2027
            PNR: ZZQQ99
            """
        let result = PDFBookingParser.extract(from: text)
        #expect(result.startDate != nil)
        #expect(result.endDate   != nil)
        // End must be after start
        if let s = result.startDate, let e = result.endDate {
            #expect(e > s)
        }
    }

    @Test("Handles text with no dates gracefully")
    func dateExtraction_noDates() {
        let text = "Hotel Confirmation  Reference: XYZ999  No dates provided"
        let result = PDFBookingParser.extract(from: text)
        // Should not crash; dates are nil
        _ = result.startDate   // just ensure no trap
        _ = result.endDate
    }

    // MARK: - Price extraction

    @Test("Extracts 'Grand Total' price with decimal")
    func priceExtraction_grandTotal() {
        let text = """
            Room rate: EUR 200.00 per night
            Taxes & fees: EUR 50.00
            Grand Total: EUR 1,250.00
            """
        let result = PDFBookingParser.extract(from: text)
        #expect(result.totalPrice == 1250.00)
    }

    @Test("Extracts 'Total Amount' label")
    func priceExtraction_totalAmount() {
        let text = "Ticket price: USD 89.00  Total Amount: USD 99.00  Service fee included"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.totalPrice == 99.00)
    }

    @Test("Falls back to symbol-prefixed amount when no total label")
    func priceExtraction_symbolFallback() {
        let text = "Your fare is $542.50  No explicit total label here"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.totalPrice == 542.50)
    }

    @Test("Returns 0 when no price is found")
    func priceExtraction_none() {
        let text = "Tour booking confirmed. No price information available."
        let result = PDFBookingParser.extract(from: text)
        #expect(result.totalPrice == 0)
    }

    // MARK: - Currency detection

    @Test("Detects EUR from € symbol")
    func currencyDetection_euroSymbol() {
        let text = "Total: €542.00"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.currency == "EUR")
    }

    @Test("Detects GBP from £ symbol")
    func currencyDetection_gbpSymbol() {
        let text = "Total: £320.00"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.currency == "GBP")
    }

    @Test("Detects INR from ₹ symbol")
    func currencyDetection_inrSymbol() {
        let text = "Total: ₹8,500.00"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.currency == "INR")
    }

    @Test("Detects currency from ISO code in text")
    func currencyDetection_isoCode() {
        let text = "Amount Payable: AED 1,200.00"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.currency == "AED")
    }

    @Test("Defaults to USD when no currency found")
    func currencyDetection_default() {
        let text = "Total: 250.00  Some booking without currency"
        let result = PDFBookingParser.extract(from: text)
        #expect(result.currency == "USD")
    }

    // MARK: - Integration: full realistic samples

    @Test("Parses realistic flight booking confirmation")
    func integration_flightBooking() {
        let text = """
            LUFTHANSA
            e-Ticket Receipt

            Booking Reference: LH8X4T
            Flight: LH 401
            Route: FRA → JFK

            Passenger: Jane Smith
            Departure: 10 Jul 2027
            Return: 24 Jul 2027
            Seat: 22C Economy

            Total Fare: EUR 742.00
            """
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .flight)
        #expect(result.providerName == "Lufthansa")
        #expect(result.bookingReference == "LH8X4T")
        #expect(result.totalPrice == 742.00)
        #expect(result.currency == "EUR")
        #expect(result.startDate != nil)
        #expect(result.endDate   != nil)
    }

    @Test("Parses realistic hotel booking confirmation")
    func integration_hotelBooking() {
        let text = """
            Marriott Hotels & Resorts
            Reservation Confirmation

            Confirmation Number: MH99231Z
            The Paris Marriott Opéra Ambassador Hotel

            Guest: John Smith
            Check-in:  20 Aug 2027
            Check-out: 25 Aug 2027
            Room Type: Superior Room

            Grand Total: EUR 1,250.00
            """
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .hotel)
        #expect(result.providerName == "Marriott")
        #expect(result.confirmationNumber == "MH99231Z")
        #expect(result.totalPrice == 1250.00)
        #expect(result.currency == "EUR")
        if let s = result.startDate, let e = result.endDate {
            #expect(e > s)
        }
    }

    @Test("Parses realistic car rental confirmation")
    func integration_carRental() {
        let text = """
            Car Hire Confirmation
            Booking Reference: CR-20278833

            Vehicle Rental – Economy Car
            Pickup Location: CDG Terminal 2
            Pickup Date:  20 Aug 2027
            Drop-off Date: 25 Aug 2027

            Total Amount: EUR 320.00
            """
        let result = PDFBookingParser.extract(from: text)
        #expect(result.type == .carRental)
        #expect(result.totalPrice == 320.00)
        #expect(result.startDate != nil)
    }

    @Test("Does not crash on empty string")
    func integration_emptyString() {
        let result = PDFBookingParser.extract(from: "")
        // Should return a default ExtractedBooking without crashing
        #expect(result.totalPrice == 0)
        #expect(result.title == "" || result.title.isEmpty)
    }

    @Test("Does not crash on very short text")
    func integration_shortText() {
        let result = PDFBookingParser.extract(from: "OK")
        _ = result  // just confirm no trap
    }
}
