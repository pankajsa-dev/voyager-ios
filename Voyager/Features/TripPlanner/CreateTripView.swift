import SwiftUI

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
    @State private var currency        = "USD"
    @State private var isCreating      = false
    @State private var errorMsg: String?

    // Destination search
    @State private var destService     = DestinationService()
    @State private var searchQuery     = ""
    @State private var showDestPicker  = false

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

                    // ── Trip name ──────────────────────────────────────
                    formSection(title: "Trip Name", icon: "pencil") {
                        TextField("e.g. Summer in Bali", text: $tripTitle)
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
                        destinationName = "\(dto.name), \(dto.country)"
                        selectedDestId  = dto.id
                        showDestPicker  = false
                    },
                    onManual: { name in
                        destinationName = name
                        selectedDestId  = nil
                        showDestPicker  = false
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
                _ = try await tripService.create(
                    title:           tripTitle.trimmingCharacters(in: .whitespaces),
                    destinationName: destinationName.trimmingCharacters(in: .whitespaces),
                    destinationId:   selectedDestId,
                    startDate:       startDate,
                    endDate:         endDate,
                    totalBudget:     Double(budget) ?? 0,
                    currency:        currency
                )
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

private struct DatePickerRow: View {
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
    let onSelect: (DestinationDTO) -> Void
    let onManual: (String) -> Void

    @State private var query       = ""
    @State private var manualEntry = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search destinations…", text: $query)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, new in
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(for: .milliseconds(350))
                                guard !Task.isCancelled else { return }
                                await service.search(query: new)
                            }
                        }
                }
                .padding(AppSpacing.md)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .padding(AppSpacing.md)

                // Manual entry
                if !query.isEmpty && service.destinations.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Text("Not found in our list? Enter manually:")
                            .font(AppFont.bodySmall).foregroundStyle(.secondary)
                        HStack(spacing: AppSpacing.sm) {
                            TextField("e.g. Maldives", text: $manualEntry)
                                .font(AppFont.body)
                                .padding(AppSpacing.md)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            Button("Use") {
                                if !manualEntry.isEmpty { onManual(manualEntry) }
                            }
                            .font(AppFont.body).fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                // Results list
                List(service.destinations) { dest in
                    Button {
                        onSelect(dest)
                    } label: {
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
                .listStyle(.plain)
                .task { await service.fetchAll() }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Choose Destination")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
