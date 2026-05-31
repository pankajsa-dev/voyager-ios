import SwiftUI
import PhotosUI
import MapKit

struct CreateTripView: View {
    let tripService: TripService
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var tripTitle       = ""
    @State private var destinationName = ""
    @State private var selectedDestId: String?
    @State private var startDate       = Date()
    @State private var endDate         = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var budget          = ""
    @State private var currency        = AppSettings.shared.currency
    @State private var isCreating      = false
    @State private var errorMsg: String?

    // Banner image
    @State private var bannerItem:        PhotosPickerItem?
    @State private var bannerImage:       UIImage?
    @State private var isLoadingBanner =  false
    private let initialBannerURL:         String?

    // Destination search
    @State private var destService        = DestinationService()
    @State private var searchQuery        = ""
    @State private var showDestPicker     = false
    @State private var selectedLatitude:  Double?
    @State private var selectedLongitude: Double?

    init(tripService: TripService, initialDestination: DestinationDTO? = nil) {
        self.tripService    = tripService
        self.initialBannerURL = initialDestination?.imageUrls.first
        if let dest = initialDestination {
            _destinationName = State(initialValue: "\(dest.name), \(dest.country)")
            _selectedDestId  = State(initialValue: dest.id)
        }
    }

    private let currencies = ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"]

    private var isValid: Bool {
        !tripTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destinationName.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // ── Banner image ───────────────────────────────────
                    PhotosPicker(selection: $bannerItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let img = bannerImage {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                } else if isLoadingBanner {
                                    RoundedRectangle(cornerRadius: AppRadius.lg)
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .shimmer()
                                } else {
                                    LinearGradient(
                                        colors: [Color(hex: "#0D4A49"), Color(hex: "#2A9D8F")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.system(size: 32))
                                                .foregroundStyle(.white.opacity(0.7))
                                            Text("Add Banner Photo")
                                                .font(AppFont.bodySmall).fontWeight(.semibold)
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                            // Camera badge — always visible so user knows they can change the image
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#E9A84C"))
                                    .frame(width: 34, height: 34)
                                Image(systemName: bannerImage == nil && !isLoadingBanner ? "plus" : "camera.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(AppSpacing.sm)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .task {
                        guard bannerImage == nil, let urlString = initialBannerURL,
                              let url = URL(string: urlString) else { return }
                        await MainActor.run { isLoadingBanner = true }
                        if let data = try? await URLSession.shared.data(from: url).0,
                           let ui = UIImage(data: data) {
                            await MainActor.run { bannerImage = ui; isLoadingBanner = false }
                        } else {
                            await MainActor.run { isLoadingBanner = false }
                        }
                    }
                    .onChange(of: bannerItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let ui = UIImage(data: data) {
                                await MainActor.run { bannerImage = ui }
                            }
                        }
                    }

                    // ── Trip name ──────────────────────────────────────
                    formSection(title: "Trip Name", icon: "pencil") {
                        TextField(destinationName.isEmpty ? "e.g. Summer in Bali" : "e.g. Trip to \(destinationName.components(separatedBy: ",").first ?? destinationName)", text: $tripTitle)
                            .font(AppFont.body)
                            .padding(AppSpacing.md)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }

                    // ── Destination ────────────────────────────────────
                    formSection(title: "Destination", icon: "mappin.circle") {
                        Button {
                            showDestPicker = true
                        } label: {
                            HStack {
                                Text(destinationName.isEmpty ? "Search or enter a destination" : destinationName)
                                    .font(AppFont.body)
                                    .foregroundStyle(destinationName.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(AppSpacing.md)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }
                    }

                    // ── Dates ──────────────────────────────────────────
                    formSection(title: "Dates", icon: "calendar") {
                        VStack(spacing: AppSpacing.sm) {
                            DatePickerRow(label: "Departure", date: $startDate, minimumDate: Date())
                            Divider().padding(.horizontal, AppSpacing.md)
                            DatePickerRow(label: "Return", date: $endDate, minimumDate: startDate)
                        }
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }

                    // ── Budget ─────────────────────────────────────────
                    formSection(title: "Budget (optional)", icon: "creditcard") {
                        HStack(spacing: AppSpacing.sm) {
                            Picker("Currency", selection: $currency) {
                                ForEach(currencies, id: \.self) { c in
                                    Text(c).tag(c)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                            TextField("0", text: $budget)
                                .keyboardType(.decimalPad)
                                .font(AppFont.body)
                                .padding(AppSpacing.md)
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // ── Error ──────────────────────────────────────────
                    if let err = errorMsg {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(err).font(AppFont.bodySmall)
                        }
                        .foregroundStyle(.red)
                        .padding(AppSpacing.sm)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // ── Create button ──────────────────────────────────
                    Button(action: createTrip) {
                        ZStack {
                            if isCreating {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Trip")
                                    .font(AppFont.body).fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isValid
                            ? LinearGradient(colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .shadow(color: isValid ? Color(hex: "#1A6B6A").opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .disabled(!isValid || isCreating)
                    .padding(.horizontal, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Plan a Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showDestPicker) {
                DestinationPickerSheet(
                    service: destService,
                    onSelect: { dto in
                        destinationName   = "\(dto.name), \(dto.country)"
                        selectedDestId    = dto.id
                        selectedLatitude  = dto.latitude
                        selectedLongitude = dto.longitude
                        showDestPicker    = false
                    },
                    onCustomPlace: { name, lat, lng in
                        destinationName   = name
                        selectedDestId    = nil
                        selectedLatitude  = lat
                        selectedLongitude = lng
                        showDestPicker    = false
                    }
                )
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func formSection<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            content()
                .padding(.horizontal, AppSpacing.md)
        }
    }

    private func createTrip() {
        guard isValid else { return }
        isCreating = true
        errorMsg   = nil
        Task {
            do {
                let trip = try await tripService.create(
                    title:           tripTitle.trimmingCharacters(in: .whitespaces),
                    destinationName: destinationName.trimmingCharacters(in: .whitespaces),
                    destinationId:   selectedDestId,
                    startDate:       startDate,
                    endDate:         endDate,
                    totalBudget:     Double(budget) ?? 0,
                    currency:        currency,
                    latitude:        selectedLatitude,
                    longitude:       selectedLongitude
                )
                // Upload banner if one was picked
                if let jpeg = bannerImage?.jpegData(compressionQuality: 0.85) {
                    try? await tripService.updateCoverImage(tripId: trip.id, imageData: jpeg)
                }
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMsg   = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Date picker row

struct DatePickerRow: View {
    let label: String
    @Binding var date: Date
    var minimumDate: Date? = nil

    var body: some View {
        Group {
            if let min = minimumDate {
                DatePicker(label, selection: $date, in: min..., displayedComponents: .date)
            } else {
                DatePicker(label, selection: $date, displayedComponents: .date)
            }
        }
        .font(AppFont.body)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
    }
}

// MARK: - Destination picker sheet

private struct DestinationPickerSheet: View {
    let service: DestinationService
    let onSelect:      (DestinationDTO) -> Void
    let onCustomPlace: (_ name: String, _ latitude: Double?, _ longitude: Double?) -> Void

    @State private var query       = ""
    @State private var mapResults: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Search bar ─────────────────────────────────────────
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search any city or place…", text: $query)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, new in
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(for: .milliseconds(350))
                                guard !Task.isCancelled else { return }
                                // Search Voyager DB
                                await service.search(query: new)
                                // Search MapKit for real-world places
                                await searchMapKit(query: new)
                            }
                        }
                }
                .padding(AppSpacing.md)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .padding(AppSpacing.md)

                // ── Results ────────────────────────────────────────────
                List {
                    // Voyager curated destinations
                    if !service.destinations.isEmpty {
                        Section {
                            ForEach(service.destinations) { dest in
                                Button { onSelect(dest) } label: {
                                    HStack(spacing: AppSpacing.md) {
                                        if let url = dest.imageUrls.first.flatMap(URL.init) {
                                            AsyncImage(url: url) { p in
                                                if case .success(let img) = p { img.resizable().scaledToFill() }
                                                else { Color(hex: "#2A9D8F") }
                                            }
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                        } else {
                                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                                .fill(Color(hex: "#2A9D8F"))
                                                .frame(width: 44, height: 44)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(dest.name).font(AppFont.h4)
                                            Text(dest.country).font(AppFont.bodySmall).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Label("In Voyager", systemImage: "star.fill")
                                .font(AppFont.caption).foregroundStyle(Color(hex: "#1A6B6A"))
                                .textCase(nil)
                        }
                    }

                    // MapKit real-world places
                    if !mapResults.isEmpty {
                        Section {
                            ForEach(mapResults, id: \.self) { item in
                                Button {
                                    let coord = item.placemark.coordinate
                                    let name  = mapKitPlaceName(for: item)
                                    onCustomPlace(name, coord.latitude, coord.longitude)
                                } label: {
                                    HStack(spacing: AppSpacing.md) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                                .fill(Color(hex: "#1A6B6A").opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(Color(hex: "#1A6B6A"))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name ?? item.placemark.locality ?? "Unknown")
                                                .font(AppFont.h4)
                                            Text(mapKitSubtitle(for: item))
                                                .font(AppFont.bodySmall).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Label("All Places", systemImage: "globe")
                                .font(AppFont.caption).foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }

                    // Fallback: no results at all
                    if service.destinations.isEmpty && mapResults.isEmpty && !query.isEmpty {
                        ContentUnavailableView(
                            "No places found",
                            systemImage: "magnifyingglass",
                            description: Text("Try a different city or country name")
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                .task { await service.fetchAll() }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Choose Destination")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - MapKit search

    private func searchMapKit(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { mapResults = [] }
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        guard let response = try? await MKLocalSearch(request: request).start() else {
            await MainActor.run { mapResults = [] }
            return
        }
        // Deduplicate by coordinate (MapKit can return near-duplicates)
        let unique = response.mapItems.reduce(into: [MKMapItem]()) { acc, item in
            let coord = item.placemark.coordinate
            let isDup = acc.contains {
                abs($0.placemark.coordinate.latitude  - coord.latitude)  < 0.01 &&
                abs($0.placemark.coordinate.longitude - coord.longitude) < 0.01
            }
            if !isDup { acc.append(item) }
        }
        await MainActor.run { mapResults = Array(unique.prefix(6)) }
    }

    // MARK: - Display helpers

    private func mapKitPlaceName(for item: MKMapItem) -> String {
        let parts = [
            item.name,
            item.placemark.locality,
            item.placemark.country
        ].compactMap { $0 }.filter { !$0.isEmpty }
        // Avoid repeating the same word (e.g. "Paris, Paris, France")
        var seen = Set<String>()
        let deduped = parts.filter { seen.insert($0).inserted }
        return deduped.joined(separator: ", ")
    }

    private func mapKitSubtitle(for item: MKMapItem) -> String {
        let parts = [
            item.placemark.locality,
            item.placemark.administrativeArea,
            item.placemark.country
        ].compactMap { $0 }.filter { !$0.isEmpty }
        var seen = Set<String>()
        return parts.filter { seen.insert($0).inserted }.joined(separator: ", ")
    }
}
