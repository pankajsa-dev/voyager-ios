import SwiftUI

// MARK: - Trip Expense View

struct TripExpenseView: View {
    let trip: TripDTO
    @State private var service   = ExpenseService()
    @State private var showAdd   = false
    @State private var showMine  = false        // false = All, true = Mine

    private var visibleExpenses: [ExpenseDTO] {
        showMine
            ? service.expenses.filter { $0.userId == service.currentUserId }
            : service.expenses
    }

    private var activityEstimatesTotal: Double {
        trip.itineraryDays
            .flatMap(\.activities)
            .filter { $0.estimatedCost > 0 }
            .reduce(0) { $0 + $1.estimatedCost }
    }

    private var visibleSpent: Double { visibleExpenses.reduce(0) { $0 + $1.amount } }
    private var combinedTotal: Double { visibleSpent + activityEstimatesTotal }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                budgetSummaryCard
                if activityEstimatesTotal > 0 { activityEstimatesSection }
                if !service.byCategory.isEmpty { categoryBreakdown }
                expenseList
                Spacer(minLength: AppSpacing.xxl)
            }
            .padding(.top, AppSpacing.md)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(hex: "#1A6B6A"))
                    .clipShape(Circle())
                    .shadow(color: Color(hex: "#1A6B6A").opacity(0.4), radius: 10, y: 4)
            }
            .padding(AppSpacing.lg)
        }
        .task { await service.fetchAll(tripId: trip.id) }
        .sheet(isPresented: $showAdd) {
            AddExpenseSheet(tripId: trip.id, defaultCurrency: trip.currency) { title, amount, currency, category, date, notes in
                Task { try? await service.add(tripId: trip.id, title: title, amount: amount,
                                               currency: currency, category: category,
                                               date: date, notes: notes) }
            }
        }
    }

    // MARK: Budget summary

    private var budgetSummaryCard: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Combined total vs budget
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Committed")
                            .font(AppFont.label).foregroundStyle(.secondary)
                        Text("\(trip.currency) \(formatAmount(combinedTotal))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                    }
                    Spacer()
                    if trip.totalBudget > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Budget")
                                .font(AppFont.label).foregroundStyle(.secondary)
                            Text("\(trip.currency) \(formatAmount(trip.totalBudget))")
                                .font(AppFont.h4)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                // Sub-totals row
                if activityEstimatesTotal > 0 {
                    HStack(spacing: AppSpacing.sm) {
                        Label("\(trip.currency) \(formatAmount(visibleSpent)) logged",
                              systemImage: "checkmark.circle")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                        Text("·").font(AppFont.caption).foregroundStyle(.tertiary)
                        Label("\(trip.currency) \(formatAmount(activityEstimatesTotal)) estimated",
                              systemImage: "calendar.badge.clock")
                            .font(AppFont.caption)
                            .foregroundStyle(Color(hex: "#2A9D8F"))
                    }
                }

                if trip.totalBudget > 0 {
                    let progress = min(combinedTotal / trip.totalBudget, 1.0)
                    let overBudget = combinedTotal > trip.totalBudget
                    let loggedFraction = trip.totalBudget > 0
                        ? min(visibleSpent / trip.totalBudget, 1.0)
                        : 0.0
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(overBudget ? Color(hex: "#E05D5D") : Color(hex: "#2A9D8F"))
                                .frame(width: geo.size.width * progress, height: 8)
                                .animation(.spring(response: 0.5), value: progress)
                            // Estimated portion shown as lighter overlay on top
                            if activityEstimatesTotal > 0 && !overBudget {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#2A9D8F").opacity(0.35))
                                    .frame(width: geo.size.width * (progress - loggedFraction), height: 8)
                                    .offset(x: geo.size.width * loggedFraction)
                                    .animation(.spring(response: 0.5), value: progress)
                            }
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        if overBudget {
                            Label("\(trip.currency) \(formatAmount(combinedTotal - trip.totalBudget)) over budget",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(AppFont.caption).foregroundStyle(Color(hex: "#E05D5D"))
                        } else {
                            Text("\(trip.currency) \(formatAmount(trip.totalBudget - combinedTotal)) remaining")
                                .font(AppFont.caption).foregroundStyle(Color(hex: "#3AAA7A"))
                        }
                        Spacer()
                        Text("\(Int(progress * 100))% committed")
                            .font(AppFont.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: Activity estimates

    private var activityEstimatesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Label("Activity Estimates", systemImage: "calendar.badge.clock")
                    .font(AppFont.h4)
                Spacer()
                Text("\(trip.currency) \(formatAmount(activityEstimatesTotal))")
                    .font(AppFont.bodySmall).fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "#2A9D8F"))
            }
            .padding(.horizontal, AppSpacing.md)

            VStack(spacing: 0) {
                let activitiesWithCost = trip.itineraryDays
                    .flatMap { day in day.activities.filter { $0.estimatedCost > 0 }.map { (day: day, activity: $0) } }

                ForEach(Array(activitiesWithCost.enumerated()), id: \.element.activity.id) { idx, pair in
                    HStack(spacing: AppSpacing.md) {
                        Text(pair.activity.category.emoji)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(pair.activity.title)
                                .font(AppFont.body).fontWeight(.medium)
                                .lineLimit(1)
                            Text("Day \(pair.day.dayNumber) · \(pair.activity.category.rawValue)")
                                .font(AppFont.caption).foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(pair.activity.currency) \(formatAmount(pair.activity.estimatedCost))")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "#2A9D8F"))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 12)

                    if idx < activitiesWithCost.count - 1 {
                        Divider().padding(.leading, 56 + AppSpacing.md)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Category breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("By Category")
                .font(AppFont.h4)
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: AppSpacing.xs) {
                ForEach(service.byCategory, id: \.category.rawValue) { item in
                    let pct = service.totalSpent > 0 ? item.total / service.totalSpent : 0
                    HStack(spacing: AppSpacing.md) {
                        Text(item.category.emoji)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.category.rawValue)
                                    .font(AppFont.bodySmall).fontWeight(.medium)
                                Spacer()
                                Text("\(trip.currency) \(formatAmount(item.total))")
                                    .font(AppFont.bodySmall).fontWeight(.semibold)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                        .frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: "#2A9D8F").opacity(0.7))
                                        .frame(width: geo.size.width * pct, height: 5)
                                        .animation(.spring(response: 0.6), value: pct)
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .padding(.horizontal, AppSpacing.md)
                }
            }
        }
    }

    // MARK: Expense list

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header + All/Mine toggle
            HStack {
                Text("Actual Expenses")
                    .font(AppFont.h4)
                Spacer()
                // All/Mine toggle — only shown when there are multiple expense owners
                let hasMultipleOwners = Set(service.expenses.map { $0.userId }).count > 1
                if hasMultipleOwners || !service.expenses.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(["All", "Mine"], id: \.self) { label in
                            let active = label == "Mine" ? showMine : !showMine
                            Button { withAnimation(.easeInOut(duration: 0.15)) { showMine = label == "Mine" } } label: {
                                Text(label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(active ? Color(hex: "#1A6B6A") : Color.clear)
                                    .foregroundStyle(active ? .white : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.md)

            // Actual vs estimate comparison pill
            if activityEstimatesTotal > 0 && !visibleExpenses.isEmpty {
                let delta = visibleSpent - activityEstimatesTotal
                let underBudget = delta <= 0
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: underBudget ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 11))
                    Text(underBudget
                         ? "\(trip.currency) \(formatAmount(abs(delta))) under estimate"
                         : "\(trip.currency) \(formatAmount(delta)) over estimate")
                }
                .font(AppFont.caption).fontWeight(.medium)
                .foregroundStyle(underBudget ? Color(hex: "#3AAA7A") : Color(hex: "#E05D5D"))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background((underBudget ? Color(hex: "#3AAA7A") : Color(hex: "#E05D5D")).opacity(0.1))
                .clipShape(Capsule())
                .padding(.horizontal, AppSpacing.md)
            }

            if service.isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .frame(height: 64).shimmer()
                        .padding(.horizontal, AppSpacing.md)
                }
            } else if visibleExpenses.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(hex: "#2A9D8F").opacity(0.3))
                    Text(showMine ? "No expenses from you yet" : "No expenses yet")
                        .font(AppFont.h4).foregroundStyle(.secondary)
                    if !showMine {
                        Text("Tap + to log your first expense")
                            .font(AppFont.bodySmall).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(visibleExpenses) { expense in
                        ExpenseRow(expense: expense,
                                   showLoggedBy: !showMine && Set(service.expenses.map { $0.userId }).count > 1) {
                            Task { try? await service.delete(expenseId: expense.id) }
                        }
                        if expense.id != visibleExpenses.last?.id {
                            Divider().padding(.leading, 56 + AppSpacing.md)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    private func formatAmount(_ value: Double) -> String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.maximumFractionDigits = 2
        n.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return n.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// MARK: - Expense row

private struct ExpenseRow: View {
    let expense: ExpenseDTO
    var showLoggedBy: Bool = false
    let onDelete: () -> Void

    private var category: ExpenseCategory {
        ExpenseCategory(rawValue: expense.category) ?? .other
    }

    private var formattedDate: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "MMM d"
        return fmt.date(from: expense.date).map { out.string(from: $0) } ?? expense.date
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(category.emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(AppFont.body).fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: AppSpacing.xs) {
                    Text(category.rawValue)
                        .font(AppFont.caption).foregroundStyle(.secondary)
                    Text("·").font(AppFont.caption).foregroundStyle(.tertiary)
                    Text(formattedDate)
                        .font(AppFont.caption).foregroundStyle(.secondary)
                    // Logged-by badge (shown in "All" mode for collaborative trips)
                    if showLoggedBy, let name = expense.loggedByName {
                        Text("·").font(AppFont.caption).foregroundStyle(.tertiary)
                        LoggedByBadge(name: name, avatarUrl: expense.loggedByAvatarUrl)
                    }
                }
            }

            Spacer()

            Text("\(expense.currency) \(formatAmt(expense.amount))")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "#1A6B6A"))

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    private func formatAmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.2f", v)
    }
}

// MARK: - Logged-by badge

private struct LoggedByBadge: View {
    let name: String
    let avatarUrl: String?

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 3) {
            ZStack {
                if let urlStr = avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                        else { initialsCircle }
                    }
                } else { initialsCircle }
            }
            .frame(width: 14, height: 14)
            .clipShape(Circle())

            Text(name.components(separatedBy: " ").first ?? name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color(hex: "#2A9D8F").opacity(0.3))
            Text(initials).font(.system(size: 6, weight: .bold)).foregroundStyle(Color(hex: "#1A6B6A"))
        }
    }
}

// MARK: - Add Expense sheet

struct AddExpenseSheet: View {
    let tripId: String
    let defaultCurrency: String
    let onAdd: (String, Double, String, ExpenseCategory, Date, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title    = ""
    @State private var amount   = ""
    @State private var currency: String
    @State private var category = ExpenseCategory.food
    @State private var date     = Date()
    @State private var notes    = ""

    private let currencies = ["USD", "EUR", "GBP", "INR", "AUD", "CAD", "JPY", "SGD", "AED"]

    init(tripId: String, defaultCurrency: String,
         onAdd: @escaping (String, Double, String, ExpenseCategory, Date, String) -> Void) {
        self.tripId = tripId
        self.defaultCurrency = defaultCurrency
        self.onAdd = onAdd
        _currency = State(initialValue: defaultCurrency)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // Category chips
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label("Category", systemImage: "tag")
                            .font(AppFont.label).fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                            .padding(.horizontal, AppSpacing.md)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 3),
                            spacing: AppSpacing.sm
                        ) {
                            ForEach(ExpenseCategory.allCases, id: \.rawValue) { cat in
                                Button { withAnimation(.spring(response: 0.2)) { category = cat } } label: {
                                    VStack(spacing: 5) {
                                        Text(cat.emoji).font(.title2)
                                        Text(cat.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(category == cat ? Color(hex: "#1A6B6A") : .secondary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(category == cat
                                        ? Color(hex: "#1A6B6A").opacity(0.1)
                                        : Color(UIColor.secondarySystemGroupedBackground))
                                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(category == cat ? Color(hex: "#1A6B6A") : Color.clear, lineWidth: 1.5))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Details
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label("Details", systemImage: "pencil")
                            .font(AppFont.label).fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                            .padding(.horizontal, AppSpacing.md)
                        VStack(spacing: 0) {
                            HStack(spacing: AppSpacing.md) {
                                Text(category.emoji).font(.title3).frame(width: 28)
                                TextField("What did you spend on? *", text: $title).font(AppFont.body)
                            }
                            .padding(AppSpacing.md)
                            Divider().padding(.leading, 56)
                            HStack(spacing: AppSpacing.sm) {
                                Picker("", selection: $currency) {
                                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu).labelsHidden()
                                .frame(width: 70)
                                TextField("0.00 *", text: $amount)
                                    .keyboardType(.decimalPad).font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#1A6B6A"))
                            }
                            .padding(AppSpacing.md)
                            Divider()
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .font(AppFont.body).padding(AppSpacing.md).tint(Color(hex: "#2A9D8F"))
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label("Notes (optional)", systemImage: "note.text")
                            .font(AppFont.label).fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                            .padding(.horizontal, AppSpacing.md)
                        TextEditor(text: $notes)
                            .frame(minHeight: 72).font(AppFont.body).padding(AppSpacing.sm)
                            .scrollContentBackground(.hidden)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                            .padding(.horizontal, AppSpacing.md)
                    }

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Log Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(title.trimmingCharacters(in: .whitespaces),
                              Double(amount) ?? 0, currency, category, date,
                              notes.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .fontWeight(.semibold).disabled(!isValid)
                }
            }
        }
    }
}
