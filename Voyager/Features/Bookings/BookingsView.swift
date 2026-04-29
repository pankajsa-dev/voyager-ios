import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct BookingsView: View {
    @State private var service        = BookingService()
    @State private var selectedType: BookingType? = nil
    @State private var showAddBooking = false
    @State private var selectedBooking: BookingDTO? = nil

    var filteredBookings: [BookingDTO] {
        guard let type = selectedType else { return service.bookings }
        return service.bookings.filter { $0.type == type.rawValue }
    }

    private var totalSpend: Double {
        filteredBookings.reduce(0) { $0 + $1.totalPrice }
    }

    private var dominantCurrency: String {
        filteredBookings.first?.currency ?? "USD"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChipsRow
                Divider()

                if service.isLoading {
                    loadingRows
                    Spacer()
                } else if filteredBookings.isEmpty {
                    BookingsEmptyState()
                } else {
                    summaryHeader
                    List {
                        ForEach(filteredBookings) { booking in
                            BookingRowView(booking: booking)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .onTapGesture { selectedBooking = booking }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { try? await service.delete(bookingId: booking.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
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
            .task { await service.fetchAll() }
            .sheet(isPresented: $showAddBooking) {
                AddBookingSheet { type, title, providerName, bookingRef, startDate, endDate, totalPrice, currency, notes, documentPath in
                    Task {
                        if let booking = try? await service.create(
                            type: type,
                            title: title,
                            providerName: providerName,
                            bookingReference: bookingRef,
                            startDate: startDate,
                            endDate: endDate,
                            totalPrice: totalPrice,
                            currency: currency,
                            notes: notes
                        ) {
                            if let path = documentPath {
                                BookingDocumentStore.save(paths: [path], forBookingId: booking.id)
                            }
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedBooking) { booking in
                BookingDetailView(booking: booking, service: service)
            }
        }
    }

    private var filterChipsRow: some View {
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
    }

    private var summaryHeader: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(filteredBookings.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#1A6B6A"))
                Text(selectedType == nil ? "Total Bookings" : "\(selectedType!.rawValue)s")
                    .font(AppFont.label)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if totalSpend > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(totalSpend, format: .currency(code: dominantCurrency))
                        .font(AppFont.h4).fontWeight(.bold)
                    Text("Total Spend")
                        .font(AppFont.label).foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    private var loadingRows: some View {
        LazyVStack(spacing: AppSpacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(height: 80)
                    .shimmer()
                    .padding(.horizontal, AppSpacing.md)
            }
        }
        .padding(.top, AppSpacing.sm)
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
    let booking: BookingDTO

    private var parsedStartDate: Date {
        ISO8601DateFormatter().date(from: booking.startDate) ?? Date()
    }

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
                Text(parsedStartDate.formatted(date: .abbreviated, time: .omitted))
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

// MARK: - Add Booking Sheet

private struct AddBookingSheet: View {
    typealias Callback = (BookingType, String, String, String, Date, Date?, Double, String, String, String?) -> Void
    let onAdd: Callback

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: BookingType = .flight
    @State private var step = 1

    @State private var title        = ""
    @State private var providerName = ""
    @State private var bookingRef   = ""
    @State private var confirmationNumber = ""
    @State private var startDate    = Date()
    @State private var endDate      = Date()
    @State private var hasEndDate   = false
    @State private var priceText    = ""
    @State private var currency     = AppSettings.shared.currency
    @State private var notes        = ""

    @State private var isImportingPDF   = false
    @State private var importedPDFPath: String? = nil
    @State private var extractionError: String? = nil

    private let currencies = ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"]

    private var showEndDate: Bool {
        [BookingType.flight, .hotel, .carRental, .tour].contains(selectedType)
    }

    private var endDateSectionTitle: String {
        selectedType == .flight ? "Return Flight (optional)" : "End Date (optional)"
    }

    private var endDateToggleLabel: String {
        selectedType == .flight ? "Add return flight" : "Set end date"
    }

    private var endDatePickerLabel: String {
        selectedType == .flight ? "Return date" : "End date"
    }

    private var titlePlaceholder: String {
        switch selectedType {
        case .flight:     return "e.g. LHR → JFK"
        case .hotel:      return "e.g. Marriott Times Square"
        case .experience: return "e.g. Eiffel Tower Skip-the-Line"
        case .carRental:  return "e.g. Budget Compact Car"
        case .transfer:   return "e.g. Airport Pickup"
        case .tour:       return "e.g. Rome Food & Wine Tour"
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if step == 1 {
                        typePickerSection
                    } else {
                        scanPDFCard
                        detailsSection
                        if showEndDate { endDateSection }
                        priceSection
                        notesSection
                    }
                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(step == 1 ? "Booking Type" : selectedType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == 1 {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button("Back") { withAnimation { step = 1 } }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == 1 {
                        Button("Next") { withAnimation { step = 2 } }
                            .fontWeight(.semibold)
                    } else {
                        Button("Save") {
                            onAdd(
                                selectedType,
                                title.trimmingCharacters(in: .whitespaces),
                                providerName.trimmingCharacters(in: .whitespaces),
                                bookingRef.trimmingCharacters(in: .whitespaces),
                                startDate,
                                showEndDate && hasEndDate ? endDate : nil,
                                Double(priceText) ?? 0,
                                currency,
                                notes.trimmingCharacters(in: .whitespaces),
                                importedPDFPath
                            )
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                    }
                }
            }
            .fileImporter(
                isPresented: $isImportingPDF,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                guard let url = (try? result.get())?.first else { return }
                importPDF(from: url)
            }
        }
    }

    private var scanPDFCard: some View {
        let attached = importedPDFPath != nil
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button { isImportingPDF = true } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: attached ? "doc.fill" : "doc.viewfinder")
                        .font(.title3)
                        .foregroundStyle(attached ? Color(hex: "#3AAA7A") : Color(hex: "#1A6B6A"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attached ? "PDF Attached" : "Import from PDF")
                            .font(AppFont.body).fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text(attached ? "Tap to replace" : "Auto-fill from your booking confirmation")
                            .font(AppFont.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if attached {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: "#3AAA7A"))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(AppSpacing.md)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(
                            attached ? Color(hex: "#3AAA7A").opacity(0.4) : Color(hex: "#1A6B6A").opacity(0.3),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.md)

            if let err = extractionError {
                Text(err)
                    .font(AppFont.caption).foregroundStyle(Color(hex: "#E05D5D"))
                    .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    private func importPDF(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let pdf = PDFDocument(url: url) else {
            extractionError = "Could not read the PDF file."
            return
        }

        // Save the original PDF to local storage so it can be viewed later
        importedPDFPath = saveLocalPDF(from: url)

        var text = ""
        for i in 0..<pdf.pageCount {
            text += pdf.page(at: i)?.string ?? ""
            text += "\n"
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            extractionError = "PDF saved — no readable text found. Fill in manually."
            return
        }

        extractionError = nil
        applyExtraction(PDFBookingParser.extract(from: text))
    }

    private func saveLocalPDF(from url: URL) -> String? {
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docsDir.appendingPathComponent("voyager_docs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(UUID().uuidString).pdf")
        try? FileManager.default.copyItem(at: url, to: dest)
        return FileManager.default.fileExists(atPath: dest.path) ? dest.path : nil
    }

    private func applyExtraction(_ e: ExtractedBooking) {
        withAnimation(.spring(response: 0.3)) {
            selectedType   = e.type
            title          = e.title
            providerName   = e.providerName
            bookingRef     = e.bookingReference
            confirmationNumber = e.confirmationNumber
            if let d = e.startDate { startDate = d }
            if let d = e.endDate   { endDate = d; hasEndDate = true }
            if e.totalPrice > 0    { priceText = String(format: "%.2f", e.totalPrice) }
            if !e.currency.isEmpty { currency = e.currency }
            notes = e.notes
        }
    }

    private var typePickerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Select Type", systemImage: "tag")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 3),
                spacing: AppSpacing.sm
            ) {
                ForEach(BookingType.allCases, id: \.rawValue) { type in
                    Button {
                        withAnimation(.spring(response: 0.2)) { selectedType = type }
                    } label: {
                        VStack(spacing: 5) {
                            Text(type.emoji).font(.title2)
                            Text(type.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(selectedType == type ? Color(hex: "#1A6B6A") : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedType == type
                            ? Color(hex: "#1A6B6A").opacity(0.1)
                            : Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(selectedType == type ? Color(hex: "#1A6B6A") : Color.clear, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Details", systemImage: "pencil")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.md) {
                    Text(selectedType.emoji).font(.title3).frame(width: 28)
                    TextField(titlePlaceholder, text: $title).font(AppFont.body)
                }
                .padding(AppSpacing.md)
                Divider().padding(.leading, 56)
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "building.2").foregroundStyle(.secondary).frame(width: 28)
                    TextField("Provider (e.g. British Airways)", text: $providerName).font(AppFont.body)
                }
                .padding(AppSpacing.md)
                Divider().padding(.leading, 56)
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "number").foregroundStyle(.secondary).frame(width: 28)
                    TextField("Booking reference", text: $bookingRef)
                        .font(AppFont.body)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
                .padding(AppSpacing.md)
                Divider()
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    .font(AppFont.body).padding(AppSpacing.md).tint(Color(hex: "#2A9D8F"))
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private var endDateSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(endDateSectionTitle, systemImage: selectedType == .flight ? "airplane.arrival" : "calendar.badge.clock")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            VStack(spacing: 0) {
                Toggle(endDateToggleLabel, isOn: $hasEndDate.animation())
                    .font(AppFont.body).padding(AppSpacing.md).tint(Color(hex: "#2A9D8F"))
                if hasEndDate {
                    Divider()
                    DatePicker(endDatePickerLabel, selection: $endDate,
                               in: startDate..., displayedComponents: .date)
                        .font(AppFont.body).padding(AppSpacing.md).tint(Color(hex: "#2A9D8F"))
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Price (optional)", systemImage: "creditcard")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            HStack(spacing: AppSpacing.sm) {
                Picker("", selection: $currency) {
                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu).labelsHidden().frame(width: 70)
                TextField("0.00", text: $priceText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "#1A6B6A"))
            }
            .padding(AppSpacing.md)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Notes (optional)", systemImage: "note.text")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            TextEditor(text: $notes)
                .frame(minHeight: 72)
                .font(AppFont.body)
                .padding(AppSpacing.sm)
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
        }
    }
}

#Preview {
    BookingsView()
}
