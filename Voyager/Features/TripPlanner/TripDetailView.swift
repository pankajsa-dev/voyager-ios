import SwiftUI
import PhotosUI
import UIKit
import Supabase
import MapKit

struct TripDetailView: View {
    let tripService: TripService
    @Environment(\.dismiss) private var dismiss

    // Local mutable copy of the trip + its days
    @State private var trip: TripDTO
    @State private var days: [ItineraryDay]

    @State private var currentStatus: String
    @State private var showDeleteConfirm   = false
    @State private var isSaving            = false
    @State private var saveError: String?
    @State private var addActivityForDay: ItineraryDay?
    @State private var editingEntry: EditEntry?
    @State private var showEditTrip        = false
    @State private var showShareSheet      = false
    @State private var sharePDFData: Data?
    @State private var showTripMap         = false

    // Tabs
    @State private var selectedTab: DetailTab = .itinerary

    // Weather
    @State private var weatherService = WeatherService()

    // Cover image
    @State private var coverImageItem: PhotosPickerItem?
    @State private var localCoverImage: UIImage?
    @State private var isUploadingCover = false

    enum DetailTab: String, CaseIterable {
        case itinerary = "Itinerary"
        case expenses  = "Expenses"
        case packing   = "Packing"

        var icon: String {
            switch self {
            case .itinerary: return "list.bullet"
            case .expenses:  return "creditcard"
            case .packing:   return "bag"
            }
        }
    }

    init(trip: TripDTO, tripService: TripService) {
        self.tripService  = tripService
        _trip             = State(initialValue: trip)
        _days             = State(initialValue: trip.itineraryDays.sorted { $0.dayNumber < $1.dayNumber })
        _currentStatus    = State(initialValue: trip.status)
    }

    // MARK: - Computed

    private var dateRange: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d, yyyy"
        let s = fmt.date(from: trip.startDate).map { out.string(from: $0) } ?? trip.startDate
        let e = fmt.date(from: trip.endDate).map   { out.string(from: $0) } ?? trip.endDate
        return "\(s) – \(e)"
    }

    private var duration: Int {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let s = fmt.date(from: trip.startDate),
              let e = fmt.date(from: trip.endDate) else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: s, to: e).day ?? 1)
    }

    private var statusColor: Color {
        switch currentStatus {
        case TripStatus.upcoming.rawValue:  return Color(hex: "#1A6B6A")
        case TripStatus.active.rawValue:    return Color(hex: "#E9A84C")
        case TripStatus.completed.rawValue: return .gray
        default:                            return .red
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // ── Hero (always visible) ─────────────────────────────────────
            heroHeader

            // ── Tab picker ────────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12))
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Rectangle()
                                .fill(selectedTab == tab ? Color(hex: "#1A6B6A") : Color.clear)
                                .frame(height: 2)
                        }
                        .foregroundStyle(selectedTab == tab ? Color(hex: "#1A6B6A") : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) {
                Divider()
            }

            // ── Tab content ───────────────────────────────────────────────
            switch selectedTab {
            case .itinerary:
                itineraryTabContent
            case .expenses:
                TripExpenseView(trip: trip)
            case .packing:
                TripPackingView(trip: trip)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(trip.title)
        .task { await weatherService.fetch(for: trip.destinationName) }
        .toolbar { toolbarContent }
        .confirmationDialog("Delete this trip?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await tripService.delete(tripId: trip.id)
                    await MainActor.run { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .sheet(item: $addActivityForDay) { day in
            AddActivitySheet { activity in
                appendActivity(activity, toDayId: day.id)
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditActivitySheet(activity: entry.activity) { updated in
                updateActivity(updated, inDayId: entry.dayId)
            }
        }
        .sheet(isPresented: $showEditTrip) {
            EditTripSheet(trip: trip, tripService: tripService) { title, dest, start, end, budget, currency in
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                trip.title           = title
                trip.destinationName = dest
                trip.startDate       = fmt.string(from: start)
                trip.endDate         = fmt.string(from: end)
                trip.totalBudget     = budget
                trip.currency        = currency
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = sharePDFData {
                TripShareSheet(items: [data])
            }
        }
        .sheet(isPresented: $showTripMap) {
            TripMapView(trip: trip, days: days)
        }
    }

    // MARK: - Itinerary tab content

    private var itineraryTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let err = saveError {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(err).font(AppFont.bodySmall).foregroundStyle(.primary)
                        Spacer()
                        Button { saveError = nil } label: {
                            Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                }
                overviewSection
                weatherSection
                itinerarySection
                if !trip.notes.isEmpty { notesSection }
                Spacer(minLength: AppSpacing.xxl)
            }
            .padding(.top, AppSpacing.lg)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: AppSpacing.sm) {
                if isSaving {
                    ProgressView().scaleEffect(0.75)
                }
                Button {
                    showTripMap = true
                } label: {
                    Image(systemName: "map")
                }
                Menu {
                    Button { showEditTrip = true } label: {
                        Label("Edit Trip", systemImage: "pencil")
                    }
                    Button {
                        sharePDFData = makeTripPDF(trip: trip, days: days)
                        showShareSheet = true
                    } label: {
                        Label("Share Trip", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Menu("Change Status") {
                        ForEach(TripStatus.allCases, id: \.rawValue) { s in
                            Button(s.rawValue) {
                                currentStatus = s.rawValue
                                Task { try? await tripService.updateStatus(tripId: trip.id, status: s) }
                            }
                        }
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image — local pick takes priority, then remote URL, then gradient
            Group {
                if let local = localCoverImage {
                    Image(uiImage: local)
                        .resizable().scaledToFill()
                } else if let urlStr = trip.coverImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                        else { gradientBg }
                    }
                } else { gradientBg }
            }
            .frame(maxWidth: .infinity).frame(height: 220).clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)

            // Trip title + dates
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destinationName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(dateRange)
                    .font(AppFont.body).foregroundStyle(.white.opacity(0.85))
            }
            .padding(AppSpacing.md)

            // Camera badge — top trailing
            PhotosPicker(selection: $coverImageItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                    if isUploadingCover {
                        ProgressView().scaleEffect(0.65).tint(.white)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(AppSpacing.sm)
        }
        .frame(height: 220)
        .onChange(of: coverImageItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let ui   = UIImage(data: data) else { return }
                // Show locally at once
                await MainActor.run { localCoverImage = ui }
                // Compress and upload
                guard let jpeg = ui.jpegData(compressionQuality: 0.85) else { return }
                await MainActor.run { isUploadingCover = true }
                do {
                    let url = try await tripService.updateCoverImage(tripId: trip.id, imageData: jpeg)
                    await MainActor.run { trip.coverImageUrl = url; isUploadingCover = false }
                } catch {
                    await MainActor.run { isUploadingCover = false; saveError = "Cover upload failed: \(error.localizedDescription)" }
                }
            }
        }
    }

    private var gradientBg: some View {
        LinearGradient(
            colors: [Color(hex: "#0D4A49"), Color(hex: "#2A9D8F")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Overview", actionTitle: nil) {}

            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(statusColor).font(.system(size: 10))
                Text("Status").font(AppFont.body).foregroundStyle(.secondary)
                Spacer()
                Text(currentStatus)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            .padding(AppSpacing.md)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)

            HStack(spacing: AppSpacing.sm) {
                TripStatCard(icon: "sun.max",
                             value: "\(duration)",
                             label: duration == 1 ? "Day" : "Days")
                if trip.totalBudget > 0 {
                    TripStatCard(icon: "creditcard",
                                 value: "\(trip.currency) \(Int(trip.totalBudget))",
                                 label: "Budget")
                }
                TripStatCard(icon: "list.bullet",
                             value: "\(days.count)",
                             label: "Days Planned")
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Weather

    @ViewBuilder
    private var weatherSection: some View {
        if weatherService.isLoading {
            HStack(spacing: AppSpacing.sm) {
                ProgressView().scaleEffect(0.75)
                Text("Loading weather…")
                    .font(AppFont.bodySmall).foregroundStyle(.secondary)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        } else if let forecast = weatherService.forecast {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Label("Weather — \(forecast.city)", systemImage: "cloud.sun")
                        .font(AppFont.h4)
                    Spacer()
                    Text("7 days")
                        .font(AppFont.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppSpacing.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(forecast.days) { day in
                            WeatherDayCard(day: day)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Itinerary

    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Itinerary")
                    .font(AppFont.h3)
                Spacer()
                Button {
                    addDay()
                } label: {
                    Label("Add Day", systemImage: "plus.circle.fill")
                        .font(AppFont.bodySmall).fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#2A9D8F"))
                }
            }
            .padding(.horizontal, AppSpacing.md)

            if days.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "#2A9D8F").opacity(0.35))
                    Text("No days planned yet")
                        .font(AppFont.h4).foregroundStyle(.secondary)
                    Text("Tap \"Add Day\" to start building your itinerary")
                        .font(AppFont.bodySmall).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button { addDay() } label: {
                        Label("Add Day 1", systemImage: "plus")
                            .font(AppFont.bodySmall).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#1A6B6A"))
                            .clipShape(Capsule())
                    }
                    .padding(.top, AppSpacing.xs)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
            } else {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(days) { day in
                        ItineraryDayCard(
                            day: day,
                            onAddActivity:    { addActivityForDay = day },
                            onEditActivity:   { act in editingEntry = EditEntry(activity: act, dayId: day.id) },
                            onDeleteActivity: { actId in deleteActivity(actId, fromDayId: day.id) },
                            onDeleteDay:      { deleteDay(id: day.id) },
                            onToggleComplete: { actId in toggleComplete(actId, inDayId: day.id) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Notes", actionTitle: nil) {}
            Text(trip.notes)
                .font(AppFont.body).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Itinerary mutations

    private func addDay() {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let start    = fmt.date(from: trip.startDate) ?? Date()
        let nextNum  = (days.map(\.dayNumber).max() ?? 0) + 1
        let date     = Calendar.current.date(byAdding: .day, value: nextNum - 1, to: start) ?? start
        let newDay   = ItineraryDay(id: UUID().uuidString, dayNumber: nextNum,
                                    date: date, activities: [])
        withAnimation(.spring(response: 0.3)) { days.append(newDay) }
        saveItinerary()
    }

    private func deleteDay(id: String) {
        withAnimation { days.removeAll { $0.id == id } }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let start = fmt.date(from: trip.startDate) ?? Date()
        for i in days.indices {
            days[i].dayNumber = i + 1
            days[i].date = Calendar.current.date(byAdding: .day, value: i, to: start) ?? start
        }
        saveItinerary()
    }

    private func appendActivity(_ activity: ItineraryActivity, toDayId: String) {
        guard let idx = days.firstIndex(where: { $0.id == toDayId }) else { return }
        withAnimation { days[idx].activities.append(activity) }
        saveItinerary()
    }

    private func deleteActivity(_ activityId: String, fromDayId: String) {
        guard let idx = days.firstIndex(where: { $0.id == fromDayId }) else { return }
        withAnimation { days[idx].activities.removeAll { $0.id == activityId } }
        saveItinerary()
    }

    private func toggleComplete(_ activityId: String, inDayId: String) {
        guard let dIdx = days.firstIndex(where: { $0.id == inDayId }),
              let aIdx = days[dIdx].activities.firstIndex(where: { $0.id == activityId })
        else { return }
        days[dIdx].activities[aIdx].isCompleted.toggle()
        saveItinerary()
    }

    private func updateActivity(_ updated: ItineraryActivity, inDayId: String) {
        guard let dIdx = days.firstIndex(where: { $0.id == inDayId }),
              let aIdx = days[dIdx].activities.firstIndex(where: { $0.id == updated.id })
        else { return }
        withAnimation { days[dIdx].activities[aIdx] = updated }
        saveItinerary()
    }

    private func saveItinerary() {
        isSaving = true
        Task {
            do {
                try await tripService.updateItinerary(tripId: trip.id, days: days)
                await MainActor.run { isSaving = false; saveError = nil }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - PDF generation

    private func makeTripPDF(trip: TripDTO, days: [ItineraryDay]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let margin: CGFloat = 50
        let primaryColor = UIColor(red: 0.10, green: 0.42, blue: 0.42, alpha: 1)

        return renderer.pdfData { ctx in
            var y: CGFloat = margin

            func newPageIfNeeded() {
                if y > pageRect.height - 120 {
                    ctx.beginPage()
                    y = margin
                }
            }

            func drawText(_ text: String, at point: CGPoint, attrs: [NSAttributedString.Key: Any]) {
                text.draw(at: point, withAttributes: attrs)
            }

            ctx.beginPage()

            // ── Brand header ──────────────────────────────────────────
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: primaryColor,
                .kern: 3.0
            ]
            drawText("VOYAGER", at: CGPoint(x: margin, y: y), attrs: brandAttrs)
            y += 20

            // ── Separator ─────────────────────────────────────────────
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: y))
            linePath.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            primaryColor.withAlphaComponent(0.25).setStroke()
            linePath.lineWidth = 1; linePath.stroke()
            y += 16

            // ── Trip title ────────────────────────────────────────────
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.11, green: 0.16, blue: 0.15, alpha: 1)
            ]
            drawText(trip.title, at: CGPoint(x: margin, y: y), attrs: titleAttrs)
            y += 40

            // ── Destination & dates ───────────────────────────────────
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            let outFmt = DateFormatter(); outFmt.dateStyle = .long
            let startStr = fmt.date(from: trip.startDate).map { outFmt.string(from: $0) } ?? trip.startDate
            let endStr   = fmt.date(from: trip.endDate).map   { outFmt.string(from: $0) } ?? trip.endDate
            drawText("📍  \(trip.destinationName)", at: CGPoint(x: margin, y: y), attrs: metaAttrs)
            y += 20
            drawText("📅  \(startStr)  –  \(endStr)", at: CGPoint(x: margin, y: y), attrs: metaAttrs)
            y += 20
            if trip.totalBudget > 0 {
                drawText("💰  Budget: \(trip.currency) \(Int(trip.totalBudget))", at: CGPoint(x: margin, y: y), attrs: metaAttrs)
                y += 20
            }
            y += 12

            // ── Separator ─────────────────────────────────────────────
            let sep2 = UIBezierPath()
            sep2.move(to: CGPoint(x: margin, y: y))
            sep2.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            primaryColor.withAlphaComponent(0.15).setStroke()
            sep2.lineWidth = 1; sep2.stroke()
            y += 20

            // ── Days ──────────────────────────────────────────────────
            let dayHeadAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: primaryColor
            ]
            let actTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.label
            ]
            let actDetailAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dayDateFmt = DateFormatter(); dayDateFmt.dateFormat = "EEEE, MMM d"

            for day in days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
                newPageIfNeeded()

                // Day heading
                drawText("Day \(day.dayNumber)  ·  \(dayDateFmt.string(from: day.date))",
                         at: CGPoint(x: margin, y: y), attrs: dayHeadAttrs)
                y += 22

                if day.activities.isEmpty {
                    let emptyAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.italicSystemFont(ofSize: 12),
                        .foregroundColor: UIColor.tertiaryLabel
                    ]
                    drawText("No activities planned", at: CGPoint(x: margin + 16, y: y), attrs: emptyAttrs)
                    y += 18
                } else {
                    for activity in day.activities {
                        newPageIfNeeded()

                        drawText("\(activity.category.emoji)  \(activity.title)",
                                 at: CGPoint(x: margin + 16, y: y), attrs: actTitleAttrs)
                        y += 17

                        var details: [String] = []
                        if !activity.location.isEmpty    { details.append("📍 \(activity.location)") }
                        if let t = activity.startTime {
                            let tf = DateFormatter(); tf.timeStyle = .short
                            details.append("⏰ \(tf.string(from: t))")
                        }
                        if let mins = activity.durationMinutes, mins > 0 {
                            details.append("⏱ \(mins) min")
                        }
                        if activity.estimatedCost > 0 {
                            details.append("💰 \(activity.currency) \(Int(activity.estimatedCost))")
                        }

                        if !details.isEmpty {
                            drawText(details.joined(separator: "   "),
                                     at: CGPoint(x: margin + 32, y: y), attrs: actDetailAttrs)
                            y += 15
                        }

                        if !activity.notes.isEmpty {
                            drawText(activity.notes,
                                     at: CGPoint(x: margin + 32, y: y), attrs: actDetailAttrs)
                            y += 15
                        }

                        y += 5
                    }
                }
                y += 14
            }

            // ── Footer ────────────────────────────────────────────────
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let footerY = pageRect.height - margin + 10
            drawText("Generated by Voyager  ·  \(Date().formatted(date: .abbreviated, time: .omitted))",
                     at: CGPoint(x: margin, y: footerY), attrs: footerAttrs)
        }
    }
}

// MARK: - Itinerary day card

private struct ItineraryDayCard: View {
    let day: ItineraryDay
    let onAddActivity:    () -> Void
    let onEditActivity:   (ItineraryActivity) -> Void
    let onDeleteActivity: (String) -> Void
    let onDeleteDay:      () -> Void
    let onToggleComplete: (String) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Day header ───────────────────────────────────────────
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#1A6B6A"))
                        .frame(width: 36, height: 36)
                    Text("\(day.dayNumber)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Day \(day.dayNumber)")
                        .font(AppFont.h4)
                    Text(day.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(AppFont.caption).foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: AppSpacing.sm) {
                    Text("\(day.activities.count)")
                        .font(AppFont.caption).foregroundStyle(.secondary)

                    Button(action: onAddActivity) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color(hex: "#2A9D8F"))
                    }

                    Button {
                        withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .contentShape(Rectangle())

            // ── Activities ───────────────────────────────────────────
            if isExpanded {
                Divider().padding(.horizontal, AppSpacing.md)

                if day.activities.isEmpty {
                    Button(action: onAddActivity) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color(hex: "#2A9D8F"))
                            Text("Add first activity")
                                .font(AppFont.bodySmall)
                                .foregroundStyle(Color(hex: "#2A9D8F"))
                            Spacer()
                        }
                        .padding(AppSpacing.md)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(day.activities) { activity in
                        ActivityRow(
                            activity:   activity,
                            onToggle:   { onToggleComplete(activity.id) },
                            onEdit:     { onEditActivity(activity) },
                            onDelete:   { onDeleteActivity(activity.id) }
                        )
                        if activity.id != day.activities.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }

                    Button(action: onAddActivity) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(hex: "#2A9D8F"))
                            Text("Add activity")
                                .font(AppFont.bodySmall)
                                .foregroundStyle(Color(hex: "#2A9D8F"))
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .contextMenu {
            Button(role: .destructive, action: onDeleteDay) {
                Label("Delete Day", systemImage: "trash")
            }
        }
    }
}

// MARK: - Activity row

private struct ActivityRow: View {
    let activity:  ItineraryActivity
    let onToggle:  () -> Void
    let onEdit:    () -> Void
    let onDelete:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Button(action: onToggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .fill(activity.isCompleted
                                  ? Color(hex: "#1A6B6A").opacity(0.15)
                                  : Color(UIColor.tertiarySystemGroupedBackground))
                            .frame(width: 38, height: 38)
                        if activity.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "#1A6B6A"))
                        } else {
                            Text(activity.category.emoji).font(.title3)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(AppFont.body).fontWeight(.medium)
                        .strikethrough(activity.isCompleted, color: .secondary)
                        .foregroundStyle(activity.isCompleted ? .secondary : .primary)

                    if !activity.location.isEmpty {
                        Label(activity.location, systemImage: "mappin")
                            .font(AppFont.caption).foregroundStyle(.secondary)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        if let time = activity.startTime {
                            Text(time, format: .dateTime.hour().minute())
                                .font(AppFont.caption).foregroundStyle(.secondary)
                        }
                        if activity.estimatedCost > 0 {
                            Text("\(activity.currency) \(Int(activity.estimatedCost))")
                                .font(AppFont.caption)
                                .foregroundStyle(Color(hex: "#E9A84C"))
                        }
                    }
                }

                Spacer()

                HStack(spacing: AppSpacing.sm) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#2A9D8F"))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.md)

            // Photo thumbnails
            if let urls = activity.photoURLs, !urls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(urls, id: \.self) { urlStr in
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Color(hex: "#2A9D8F").opacity(0.2)
                                    }
                                }
                                .frame(width: 72, height: 72)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                }
                .frame(height: 88)
            }
        }
    }
}

// MARK: - Add Activity sheet (redesigned)

struct AddActivitySheet: View {
    let onAdd: (ItineraryActivity) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title        = ""
    @State private var category     = ActivityCategory.sightseeing
    @State private var location     = ""
    @State private var latitude: Double?  = nil
    @State private var longitude: Double? = nil
    @State private var showLocationPicker = false
    @State private var hasTime      = false
    @State private var startTime    = Date()
    @State private var duration     = ""
    @State private var cost         = ""
    @State private var currency     = "USD"
    @State private var notes        = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var isUploading  = false

    private let currencies = ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    categorySection
                    detailsSection
                    timeSection
                    costSection
                    photosSection
                    notesSection
                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Button("Add") { Task { await addActivity() } }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                    }
                }
            }
        }
    }

    // MARK: Category chips

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Category", systemImage: "tag")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4),
                spacing: AppSpacing.sm
            ) {
                ForEach(ActivityCategory.allCases, id: \.rawValue) { cat in
                    Button {
                        withAnimation(.spring(response: 0.2)) { category = cat }
                    } label: {
                        VStack(spacing: 5) {
                            Text(cat.emoji).font(.title2)
                            Text(cat.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(category == cat ? Color(hex: "#1A6B6A") : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            category == cat
                                ? Color(hex: "#1A6B6A").opacity(0.1)
                                : Color(UIColor.secondarySystemGroupedBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(
                                    category == cat ? Color(hex: "#1A6B6A") : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Details", systemImage: "pencil")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.md) {
                    Text(category.emoji)
                        .font(.title3)
                        .frame(width: 28)
                        .animation(.spring(response: 0.2), value: category)
                    TextField("Activity title *", text: $title)
                        .font(AppFont.body)
                }
                .padding(AppSpacing.md)

                Divider().padding(.leading, 56)

                Button { showLocationPicker = true } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: latitude != nil ? "mappin.circle.fill" : "mappin")
                            .font(.system(size: 15))
                            .foregroundStyle(latitude != nil ? Color(hex: "#1A6B6A") : Color(hex: "#E9A84C"))
                            .frame(width: 28)
                        if location.isEmpty {
                            Text("Set location (optional)")
                                .font(AppFont.body)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location)
                                    .font(AppFont.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if latitude != nil {
                                    Text("Coordinates saved")
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color(hex: "#3AAA7A"))
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppSpacing.md)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showLocationPicker) {
                    LocationPickerSheet { name, lat, lng in
                        location = name
                        latitude = lat
                        longitude = lng
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Time

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Time", systemImage: "clock")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: 0) {
                Toggle("Set start time", isOn: $hasTime.animation())
                    .font(AppFont.body)
                    .padding(AppSpacing.md)
                    .tint(Color(hex: "#2A9D8F"))

                if hasTime {
                    Divider()
                    DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .font(AppFont.body)
                        .padding(AppSpacing.md)
                        .tint(Color(hex: "#2A9D8F"))

                    Divider()

                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "timer")
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        TextField("Duration (minutes)", text: $duration)
                            .keyboardType(.numberPad)
                            .font(AppFont.body)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Cost

    private var costSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Cost (optional)", systemImage: "creditcard")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            HStack(spacing: AppSpacing.sm) {
                Picker("", selection: $currency) {
                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $cost)
                        .keyboardType(.decimalPad)
                        .font(AppFont.body)
                }
                .padding(AppSpacing.md)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Photos (optional)", systemImage: "photo.on.rectangle.angled")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // Existing selected photos
                    ForEach(photoImages.indices, id: \.self) { idx in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photoImages[idx])
                                .resizable().scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                            Button {
                                photoImages.remove(at: idx)
                                if idx < selectedPhotos.count {
                                    selectedPhotos.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .background(Color.black.opacity(0.5).clipShape(Circle()))
                            }
                            .padding(4)
                        }
                    }

                    // Add photo button
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color(hex: "#2A9D8F"))
                            Text("Add Photo")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(hex: "#2A9D8F"))
                        }
                        .frame(width: 88, height: 88)
                        .background(Color(hex: "#2A9D8F").opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(
                                    Color(hex: "#2A9D8F").opacity(0.4),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .onChange(of: selectedPhotos) { _, items in
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            images.append(img)
                        }
                    }
                    await MainActor.run { photoImages = images }
                }
            }
        }
    }

    // MARK: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Notes (optional)", systemImage: "note.text")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            TextEditor(text: $notes)
                .frame(minHeight: 88)
                .font(AppFont.body)
                .padding(AppSpacing.sm)
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Submit

    private func addActivity() async {
        isUploading = true
        var uploadedURLs: [String] = []

        for image in photoImages {
            if let data = image.jpegData(compressionQuality: 0.82) {
                let path = "activities/\(UUID().uuidString).jpg"
                do {
                    if CloudflareR2Config.isConfigured {
                        let url = try await CloudflareR2Service.shared.uploadImage(data, path: path)
                        uploadedURLs.append(url)
                    } else {
                        // Fallback: Supabase Storage
                        try await SupabaseManager.shared.storage.upload(
                            path, data: data, options: .init(contentType: "image/jpeg")
                        )
                        let url = try SupabaseManager.shared.storage.getPublicURL(path: path)
                        uploadedURLs.append(url.absoluteString)
                    }
                } catch {
                    // Skip failed uploads silently
                }
            }
        }

        let activity = ItineraryActivity(
            id:               UUID().uuidString,
            title:            title.trimmingCharacters(in: .whitespaces),
            description:      "",
            category:         category,
            startTime:        hasTime ? startTime : nil,
            durationMinutes:  Int(duration),
            location:         location.trimmingCharacters(in: .whitespaces),
            latitude:         latitude,
            longitude:        longitude,
            estimatedCost:    Double(cost) ?? 0,
            currency:         currency,
            bookingReference: nil,
            notes:            notes.trimmingCharacters(in: .whitespaces),
            isCompleted:      false,
            photoURLs:        uploadedURLs.isEmpty ? nil : uploadedURLs
        )

        await MainActor.run {
            isUploading = false
            onAdd(activity)
            dismiss()
        }
    }
}

// MARK: - Edit entry identifier (activity + owning day)

struct EditEntry: Identifiable {
    var activity: ItineraryActivity
    let dayId: String
    var id: String { activity.id }
}

// MARK: - Edit Activity sheet

struct EditActivitySheet: View {
    let activity: ItineraryActivity
    let onSave: (ItineraryActivity) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title:       String
    @State private var category:    ActivityCategory
    @State private var location:    String
    @State private var latitude:    Double?
    @State private var longitude:   Double?
    @State private var showLocationPicker = false
    @State private var hasTime:     Bool
    @State private var startTime:   Date
    @State private var duration:    String
    @State private var cost:        String
    @State private var currency:    String
    @State private var notes:       String
    @State private var photoURLs:   [String]
    @State private var newPhotos:   [PhotosPickerItem] = []
    @State private var newImages:   [UIImage] = []
    @State private var isUploading  = false

    private let currencies = ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"]

    init(activity: ItineraryActivity, onSave: @escaping (ItineraryActivity) -> Void) {
        self.activity = activity
        self.onSave   = onSave
        _title       = State(initialValue: activity.title)
        _category    = State(initialValue: activity.category)
        _location    = State(initialValue: activity.location)
        _latitude    = State(initialValue: activity.latitude)
        _longitude   = State(initialValue: activity.longitude)
        _hasTime     = State(initialValue: activity.startTime != nil)
        _startTime   = State(initialValue: activity.startTime ?? Date())
        _duration    = State(initialValue: activity.durationMinutes.map(String.init) ?? "")
        _cost        = State(initialValue: activity.estimatedCost > 0 ? "\(Int(activity.estimatedCost))" : "")
        _currency    = State(initialValue: activity.currency)
        _notes       = State(initialValue: activity.notes)
        _photoURLs   = State(initialValue: activity.photoURLs ?? [])
    }

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Category chips
                    categorySection
                    // Details
                    detailsSection
                    // Time
                    timeSection
                    // Cost
                    costSection
                    // Existing + new photos
                    photosSection
                    // Notes
                    notesSection
                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold).disabled(!isValid)
                    }
                }
            }
        }
    }

    // ── Reuse same section views as AddActivitySheet ──────────────────────

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Category", systemImage: "tag")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4),
                spacing: AppSpacing.sm
            ) {
                ForEach(ActivityCategory.allCases, id: \.rawValue) { cat in
                    Button { withAnimation(.spring(response: 0.2)) { category = cat } } label: {
                        VStack(spacing: 5) {
                            Text(cat.emoji).font(.title2)
                            Text(cat.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(2).multilineTextAlignment(.center)
                                .foregroundStyle(category == cat ? Color(hex: "#1A6B6A") : .secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(category == cat ? Color(hex: "#1A6B6A").opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(category == cat ? Color(hex: "#1A6B6A") : Color.clear, lineWidth: 1.5))
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
                    Text(category.emoji).font(.title3).frame(width: 28)
                    TextField("Activity title *", text: $title).font(AppFont.body)
                }
                .padding(AppSpacing.md)
                Divider().padding(.leading, 56)

                Button { showLocationPicker = true } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: latitude != nil ? "mappin.circle.fill" : "mappin")
                            .font(.system(size: 15))
                            .foregroundStyle(latitude != nil ? Color(hex: "#1A6B6A") : Color(hex: "#E9A84C"))
                            .frame(width: 28)
                        if location.isEmpty {
                            Text("Set location (optional)")
                                .font(AppFont.body)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location)
                                    .font(AppFont.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if latitude != nil {
                                    Text("Coordinates saved")
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color(hex: "#3AAA7A"))
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppSpacing.md)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showLocationPicker) {
                    LocationPickerSheet { name, lat, lng in
                        location = name
                        latitude = lat
                        longitude = lng
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Time", systemImage: "clock")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            VStack(spacing: 0) {
                Toggle("Set start time", isOn: $hasTime.animation())
                    .font(AppFont.body).padding(AppSpacing.md).tint(Color(hex: "#2A9D8F"))
                if hasTime {
                    Divider()
                    DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .font(AppFont.body).padding(AppSpacing.md).tint(Color(hex: "#2A9D8F"))
                    Divider()
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "timer").foregroundStyle(.secondary).frame(width: 28)
                        TextField("Duration (minutes)", text: $duration).keyboardType(.numberPad).font(AppFont.body)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private var costSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Cost (optional)", systemImage: "creditcard")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            HStack(spacing: AppSpacing.sm) {
                Picker("", selection: $currency) {
                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu).labelsHidden()
                .padding(.horizontal, AppSpacing.md).padding(.vertical, 14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "dollarsign.circle").foregroundStyle(.secondary)
                    TextField("0.00", text: $cost).keyboardType(.decimalPad).font(AppFont.body)
                }
                .padding(AppSpacing.md)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Photos", systemImage: "photo.on.rectangle.angled")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // Existing uploaded photos
                    ForEach(photoURLs, id: \.self) { urlStr in
                        ZStack(alignment: .topTrailing) {
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    if case .success(let img) = phase { img.resizable().scaledToFill() }
                                    else { Color(hex: "#2A9D8F").opacity(0.2) }
                                }
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                            Button { photoURLs.removeAll { $0 == urlStr } } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .background(Color.black.opacity(0.5).clipShape(Circle()))
                            }
                            .padding(4)
                        }
                    }
                    // New picks
                    ForEach(newImages.indices, id: \.self) { idx in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: newImages[idx]).resizable().scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            Button { newImages.remove(at: idx); if idx < newPhotos.count { newPhotos.remove(at: idx) } } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .background(Color.black.opacity(0.5).clipShape(Circle()))
                            }
                            .padding(4)
                        }
                    }
                    // Add button
                    PhotosPicker(selection: $newPhotos, maxSelectionCount: 5, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 22, weight: .medium)).foregroundStyle(Color(hex: "#2A9D8F"))
                            Text("Add Photo").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: "#2A9D8F"))
                        }
                        .frame(width: 88, height: 88)
                        .background(Color(hex: "#2A9D8F").opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color(hex: "#2A9D8F").opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .onChange(of: newPhotos) { _, items in
                Task {
                    var imgs: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) { imgs.append(ui) }
                    }
                    await MainActor.run { newImages = imgs }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Notes (optional)", systemImage: "note.text")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            TextEditor(text: $notes)
                .frame(minHeight: 88).font(AppFont.body).padding(AppSpacing.sm)
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
        }
    }

    private func save() async {
        isUploading = true
        var allURLs = photoURLs   // keep existing

        for image in newImages {
            if let data = image.jpegData(compressionQuality: 0.82) {
                let path = "activities/\(UUID().uuidString).jpg"
                do {
                    if CloudflareR2Config.isConfigured {
                        let url = try await CloudflareR2Service.shared.uploadImage(data, path: path)
                        allURLs.append(url)
                    } else {
                        try await SupabaseManager.shared.storage.upload(path, data: data, options: .init(contentType: "image/jpeg"))
                        let url = try SupabaseManager.shared.storage.getPublicURL(path: path)
                        allURLs.append(url.absoluteString)
                    }
                } catch { /* skip */ }
            }
        }

        var updated = activity
        updated.title           = title.trimmingCharacters(in: .whitespaces)
        updated.category        = category
        updated.location        = location.trimmingCharacters(in: .whitespaces)
        updated.latitude        = latitude
        updated.longitude       = longitude
        updated.startTime       = hasTime ? startTime : nil
        updated.durationMinutes = Int(duration)
        updated.estimatedCost   = Double(cost) ?? 0
        updated.currency        = currency
        updated.notes           = notes.trimmingCharacters(in: .whitespaces)
        updated.photoURLs       = allURLs.isEmpty ? nil : allURLs

        await MainActor.run {
            isUploading = false
            onSave(updated)
            dismiss()
        }
    }
}

// MARK: - Location search completer (wraps MKLocalSearchCompleter + delegate)

@Observable
final class LocationSearcher: NSObject, MKLocalSearchCompleterDelegate {
    var completions: [MKLocalSearchCompletion] = []
    var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func search(_ query: String) {
        isSearching = true
        completer.queryFragment = query
    }

    func clear() {
        completer.queryFragment = ""
        completions = []
        isSearching = false
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
        isSearching = false
    }

    func resolve(_ completion: MKLocalSearchCompletion, callback: @escaping (MKMapItem?) -> Void) {
        let req = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: req).start { response, _ in
            callback(response?.mapItems.first)
        }
    }
}

// MARK: - Location picker sheet

struct LocationPickerSheet: View {
    let onSelect: (String, Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query        = ""
    @State private var searcher     = LocationSearcher()
    @State private var selected: MKMapItem? = nil
    @State private var isResolving  = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color(UIColor.secondarySystemGroupedBackground))

                Divider()

                if let item = selected {
                    mapPreview(item: item)
                } else {
                    resultsList
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if selected != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use") { confirm() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                    }
                }
            }
            .onAppear { focused = true }
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Beaches, parks, landmarks…", text: $query)
                .focused($focused)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: query) { _, new in
                    selected = nil
                    if new.isEmpty { searcher.clear() } else { searcher.search(new) }
                }
            if !query.isEmpty {
                Button { query = ""; selected = nil; searcher.clear() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
            if searcher.isSearching || isResolving {
                ProgressView().scaleEffect(0.75)
            }
        }
        .padding(AppSpacing.sm)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Results list

    private var resultsList: some View {
        Group {
            if query.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "#1A6B6A").opacity(0.35))
                    Text("Search for a place")
                        .font(AppFont.body).foregroundStyle(.secondary)
                    Text("Try: \"Nin Beach Zadar\", \"Krka National Park\"")
                        .font(AppFont.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.xxl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searcher.completions.isEmpty && !searcher.isSearching {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No results for \"\(query)\"")
                        .font(AppFont.body).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searcher.completions.indices, id: \.self) { idx in
                    let completion = searcher.completions[idx]
                    Button { resolveAndSelect(completion) } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color(hex: "#1A6B6A"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(AppFont.body).foregroundStyle(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(AppFont.caption).foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: Map preview

    private func mapPreview(item: MKMapItem) -> some View {
        VStack(spacing: 0) {
            // Selected location row
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "#1A6B6A"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "")
                        .font(AppFont.body).fontWeight(.medium)
                    if let sub = item.placemark.title, sub != item.name {
                        Text(sub).font(AppFont.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    selected = nil; query = ""; searcher.clear(); focused = true
                } label: {
                    Text("Change").font(AppFont.label).foregroundStyle(Color(hex: "#1A6B6A"))
                }
            }
            .padding(AppSpacing.md)
            .background(Color(UIColor.secondarySystemGroupedBackground))

            Divider()

            // Map
            Map(position: $cameraPosition) {
                Annotation(item.name ?? "", coordinate: item.placemark.coordinate, anchor: .bottom) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#1A6B6A"))
                            .frame(width: 36, height: 36)
                            .shadow(color: Color(hex: "#1A6B6A").opacity(0.4), radius: 4, y: 2)
                        Image(systemName: "mappin")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Confirm button
            Button {
                confirm()
            } label: {
                Text("Use This Location")
                    .font(AppFont.body).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#1A6B6A"))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            }
            .padding(AppSpacing.md)
            .background(Color(UIColor.secondarySystemGroupedBackground))
        }
    }

    // MARK: Helpers

    private func resolveAndSelect(_ completion: MKLocalSearchCompletion) {
        isResolving = true
        focused = false
        searcher.resolve(completion) { item in
            DispatchQueue.main.async {
                isResolving = false
                guard let item else { return }
                selected = item
                let coord = item.placemark.coordinate
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }

    private func confirm() {
        guard let item = selected else { return }
        let coord = item.placemark.coordinate
        let name = item.name ?? item.placemark.title ?? query
        onSelect(name, coord.latitude, coord.longitude)
        dismiss()
    }
}

// MARK: - Edit Trip sheet

struct EditTripSheet: View {
    let trip: TripDTO
    let tripService: TripService
    let onSave: (String, String, Date, Date, Double, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var tripTitle: String
    @State private var destinationName: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var budget: String
    @State private var currency: String
    @State private var isSaving  = false
    @State private var errorMsg: String?

    // Banner image
    @State private var bannerItem:  PhotosPickerItem?
    @State private var bannerImage: UIImage?
    @State private var isUploadingBanner = false

    private let currencies = ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"]

    init(trip: TripDTO, tripService: TripService,
         onSave: @escaping (String, String, Date, Date, Double, String) -> Void) {
        self.trip       = trip
        self.tripService = tripService
        self.onSave     = onSave
        let fmt         = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        _tripTitle       = State(initialValue: trip.title)
        _destinationName = State(initialValue: trip.destinationName)
        _startDate       = State(initialValue: fmt.date(from: trip.startDate) ?? Date())
        _endDate         = State(initialValue: fmt.date(from: trip.endDate)   ?? Date())
        _budget          = State(initialValue: trip.totalBudget > 0 ? "\(Int(trip.totalBudget))" : "")
        _currency        = State(initialValue: trip.currency)
    }

    private var isValid: Bool {
        !tripTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destinationName.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // ── Banner image picker ────────────────────────────
                    PhotosPicker(selection: $bannerItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let local = bannerImage {
                                    Image(uiImage: local).resizable().scaledToFill()
                                } else if let urlStr = trip.coverImageUrl, let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                                        else { bannerGradient }
                                    }
                                } else { bannerGradient }
                            }
                            .frame(maxWidth: .infinity).frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                            ZStack {
                                Circle()
                                    .fill(isUploadingBanner ? Color(.systemGray3) : Color(hex: "#E9A84C"))
                                    .frame(width: 34, height: 34)
                                if isUploadingBanner {
                                    ProgressView().scaleEffect(0.6).tint(.white)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(AppSpacing.sm)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .onChange(of: bannerItem) { _, item in
                        Task {
                            guard let item,
                                  let data = try? await item.loadTransferable(type: Data.self),
                                  let ui   = UIImage(data: data) else { return }
                            await MainActor.run { bannerImage = ui; isUploadingBanner = true }
                            if let jpeg = ui.jpegData(compressionQuality: 0.85) {
                                try? await tripService.updateCoverImage(tripId: trip.id, imageData: jpeg)
                            }
                            await MainActor.run { isUploadingBanner = false }
                        }
                    }

                    formSection(title: "Trip Name", icon: "pencil") {
                        TextField("e.g. Summer in Bali", text: $tripTitle)
                            .font(AppFont.body)
                            .padding(AppSpacing.md)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }

                    formSection(title: "Destination", icon: "mappin.circle") {
                        TextField("e.g. Bali, Indonesia", text: $destinationName)
                            .font(AppFont.body)
                            .autocorrectionDisabled()
                            .padding(AppSpacing.md)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }

                    formSection(title: "Dates", icon: "calendar") {
                        VStack(spacing: 0) {
                            DatePickerRow(label: "Departure", date: $startDate)
                            Divider().padding(.horizontal, AppSpacing.md)
                            DatePickerRow(label: "Return", date: $endDate, minimumDate: startDate)
                        }
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }

                    formSection(title: "Budget (optional)", icon: "creditcard") {
                        HStack(spacing: AppSpacing.sm) {
                            Picker("Currency", selection: $currency) {
                                ForEach(currencies, id: \.self) { c in Text(c).tag(c) }
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

                    Button(action: saveTrip) {
                        ZStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(AppFont.body).fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isValid
                                ? LinearGradient(
                                    colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                                    startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(
                                    colors: [Color(.systemGray4), Color(.systemGray4)],
                                    startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .shadow(color: isValid ? Color(hex: "#1A6B6A").opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .disabled(!isValid || isSaving)
                    .padding(.horizontal, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func formSection<C: View>(title: String, icon: String,
                                      @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            content()
                .padding(.horizontal, AppSpacing.md)
        }
    }

    private var bannerGradient: some View {
        LinearGradient(
            colors: [Color(hex: "#0D4A49"), Color(hex: "#2A9D8F")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28)).foregroundStyle(.white.opacity(0.7))
                Text("Change Banner Photo")
                    .font(AppFont.bodySmall).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))
            }
        )
    }

    private func saveTrip() {
        guard isValid else { return }
        isSaving = true; errorMsg = nil
        Task {
            do {
                try await tripService.updateTripDetails(
                    tripId:          trip.id,
                    title:           tripTitle.trimmingCharacters(in: .whitespaces),
                    destinationName: destinationName.trimmingCharacters(in: .whitespaces),
                    startDate:       startDate,
                    endDate:         endDate,
                    totalBudget:     Double(budget) ?? 0,
                    currency:        currency
                )
                await MainActor.run {
                    onSave(
                        tripTitle.trimmingCharacters(in: .whitespaces),
                        destinationName.trimmingCharacters(in: .whitespaces),
                        startDate, endDate,
                        Double(budget) ?? 0,
                        currency
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run { isSaving = false; errorMsg = error.localizedDescription }
            }
        }
    }
}

// MARK: - Weather day card

private struct WeatherDayCard: View {
    let day: WeatherDay

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(day.date) { return "Today" }
        if cal.isDateInTomorrow(day.date) { return "Tomorrow" }
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        return fmt.string(from: day.date)
    }

    private var dateLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        return fmt.string(from: day.date)
    }

    private var iconColor: Color {
        Color(hex: WeatherDay.color(for: day.code))
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(dayLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(dateLabel)
                .font(AppFont.caption).foregroundStyle(.secondary)
            Image(systemName: day.icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)
                .frame(height: 30)
            Text(day.description)
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 68)
            HStack(spacing: 4) {
                Text("\(Int(day.maxTemp))°")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(Int(day.minTemp))°")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.sm)
        .frame(width: 76)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

// MARK: - Share sheet wrapper

struct TripShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Stat card

private struct TripStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#2A9D8F"))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}
