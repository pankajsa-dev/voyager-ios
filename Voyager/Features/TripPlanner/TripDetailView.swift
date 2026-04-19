import SwiftUI

struct TripDetailView: View {
    let tripService: TripService
    @Environment(\.dismiss) private var dismiss

    // Local mutable copy of the trip + its days
    @State private var trip: TripDTO
    @State private var days: [ItineraryDay]

    @State private var currentStatus: String
    @State private var showDeleteConfirm   = false
    @State private var isSaving            = false
    @State private var addActivityForDay: ItineraryDay?   // triggers Add Activity sheet

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
        ScrollView {
            VStack(spacing: 0) {
                heroHeader

                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    overviewSection
                    itinerarySection
                    if !trip.notes.isEmpty { notesSection }
                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(trip.title)
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
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: AppSpacing.sm) {
                if isSaving {
                    ProgressView().scaleEffect(0.75)
                }
                Menu {
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
            Group {
                if let urlStr = trip.coverImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                        else { gradientBg }
                    }
                } else { gradientBg }
            }
            .frame(maxWidth: .infinity).frame(height: 220).clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destinationName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(dateRange)
                    .font(AppFont.body).foregroundStyle(.white.opacity(0.85))
            }
            .padding(AppSpacing.md)
        }
        .frame(height: 220)
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

    // MARK: - Itinerary

    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header with Add Day button
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
                // Empty state
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
                            onAddActivity: { addActivityForDay = day },
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
        // Renumber remaining days
        for i in days.indices { days[i].dayNumber = i + 1 }
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

    private func saveItinerary() {
        isSaving = true
        Task {
            try? await tripService.updateItinerary(tripId: trip.id, days: days)
            await MainActor.run { isSaving = false }
        }
    }
}

// MARK: - Itinerary day card

private struct ItineraryDayCard: View {
    let day: ItineraryDay
    let onAddActivity:    () -> Void
    let onDeleteActivity: (String) -> Void
    let onDeleteDay:      () -> Void
    let onToggleComplete: (String) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Day header ───────────────────────────────────────────
            HStack {
                // Day number badge
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

                    // Add activity
                    Button(action: onAddActivity) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color(hex: "#2A9D8F"))
                    }

                    // Collapse / expand
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
                            onDelete:   { onDeleteActivity(activity.id) }
                        )
                        if activity.id != day.activities.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }

                    // Add more activities
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
    let onDelete:  () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Category emoji + complete toggle
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

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.md)
    }
}

// MARK: - Add Activity sheet

struct AddActivitySheet: View {
    let onAdd: (ItineraryActivity) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title       = ""
    @State private var category    = ActivityCategory.sightseeing
    @State private var location    = ""
    @State private var hasTime     = false
    @State private var startTime   = Date()
    @State private var duration    = ""
    @State private var cost        = ""
    @State private var currency    = "USD"
    @State private var notes       = ""

    private let currencies = ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Basic info ─────────────────────────────────────
                Section("Activity") {
                    TextField("Title", text: $title)
                        .autocorrectionDisabled()

                    Picker("Category", selection: $category) {
                        ForEach(ActivityCategory.allCases, id: \.rawValue) { cat in
                            Label {
                                Text(cat.rawValue)
                            } icon: {
                                Text(cat.emoji)
                            }
                            .tag(cat)
                        }
                    }

                    TextField("Location (optional)", text: $location)
                        .autocorrectionDisabled()
                }

                // ── Time ───────────────────────────────────────────
                Section("Time") {
                    Toggle("Set start time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Start time", selection: $startTime,
                                   displayedComponents: .hourAndMinute)
                        TextField("Duration (minutes)", text: $duration)
                            .keyboardType(.numberPad)
                    }
                }

                // ── Cost ───────────────────────────────────────────
                Section("Cost (optional)") {
                    HStack {
                        Picker("", selection: $currency) {
                            ForEach(currencies, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 80)

                        TextField("0", text: $cost)
                            .keyboardType(.decimalPad)
                    }
                }

                // ── Notes ──────────────────────────────────────────
                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .font(AppFont.body)
                }
            }
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addActivity() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func addActivity() {
        let activity = ItineraryActivity(
            id:               UUID().uuidString,
            title:            title.trimmingCharacters(in: .whitespaces),
            description:      "",
            category:         category,
            startTime:        hasTime ? startTime : nil,
            durationMinutes:  Int(duration),
            location:         location.trimmingCharacters(in: .whitespaces),
            latitude:         nil,
            longitude:        nil,
            estimatedCost:    Double(cost) ?? 0,
            currency:         currency,
            bookingReference: nil,
            notes:            notes.trimmingCharacters(in: .whitespaces),
            isCompleted:      false
        )
        onAdd(activity)
        dismiss()
    }
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
