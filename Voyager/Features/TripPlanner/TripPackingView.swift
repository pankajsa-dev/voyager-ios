import SwiftUI

// MARK: - Trip Packing View

struct TripPackingView: View {
    let trip: TripDTO
    @State private var service = PackingService()
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                progressCard
                if service.isLoading {
                    loadingSkeleton
                } else if service.items.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
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
        .task {
            await service.fetchAll(tripId: trip.id)
            // Seed defaults if brand new list
            try? await service.seedDefaults(tripId: trip.id)
        }
        .sheet(isPresented: $showAdd) {
            AddPackingItemSheet { name, category, quantity, isEssential in
                Task { try? await service.add(tripId: trip.id, name: name, category: category,
                                              quantity: quantity, isEssential: isEssential) }
            }
        }
    }

    // MARK: Progress card

    private var progressCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Packing Progress")
                        .font(AppFont.label).foregroundStyle(.secondary)
                    Text("\(service.packedCount) of \(service.totalCount) packed")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#1A6B6A"))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(UIColor.tertiarySystemGroupedBackground), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: service.progress)
                        .stroke(
                            service.progress == 1
                                ? Color(hex: "#3AAA7A")
                                : Color(hex: "#2A9D8F"),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5), value: service.progress)
                    Text("\(Int(service.progress * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A6B6A"))
                }
                .frame(width: 52, height: 52)
            }

            if service.progress == 1 && service.totalCount > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(hex: "#3AAA7A"))
                    Text("All packed! Have a great trip 🎉")
                        .font(AppFont.bodySmall).fontWeight(.medium)
                        .foregroundStyle(Color(hex: "#3AAA7A"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(Color(hex: "#3AAA7A").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: Category list

    private var categoryList: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(service.usedCategories, id: \.rawValue) { category in
                let catItems = service.items(for: category)
                let packedInCat = catItems.filter(\.isPacked).count

                VStack(alignment: .leading, spacing: 0) {
                    // Category header
                    HStack {
                        Text(category.emoji)
                            .font(.title3)
                        Text(category.rawValue)
                            .font(AppFont.h4)
                        Spacer()
                        Text("\(packedInCat)/\(catItems.count)")
                            .font(AppFont.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 12)

                    Divider()

                    ForEach(catItems) { item in
                        PackingItemRow(item: item,
                            onToggle: { Task { await service.togglePacked(itemId: item.id) } },
                            onDelete: { Task { try? await service.delete(itemId: item.id) } }
                        )
                        if item.id != catItems.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: Empty / loading

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "bag")
                .font(.system(size: 44))
                .foregroundStyle(Color(hex: "#2A9D8F").opacity(0.3))
            Text("Nothing to pack yet")
                .font(AppFont.h4).foregroundStyle(.secondary)
            Text("Tap + to add items or load smart defaults")
                .font(AppFont.bodySmall).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .padding(.horizontal, AppSpacing.md)
    }

    private var loadingSkeleton: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(height: 52).shimmer()
                    .padding(.horizontal, AppSpacing.md)
            }
        }
    }
}

// MARK: - Packing item row

private struct PackingItemRow: View {
    let item: PackingItemDTO
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item.isPacked
                              ? Color(hex: "#2A9D8F")
                              : Color(UIColor.tertiarySystemGroupedBackground))
                        .frame(width: 28, height: 28)
                    if item.isPacked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Text(item.name)
                        .font(AppFont.body)
                        .strikethrough(item.isPacked, color: .secondary)
                        .foregroundStyle(item.isPacked ? .secondary : .primary)
                    if item.isEssential {
                        Text("essential")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(hex: "#E9A84C").opacity(0.15))
                            .foregroundStyle(Color(hex: "#E9A84C"))
                            .clipShape(Capsule())
                    }
                }
                if item.quantity > 1 {
                    Text("Qty: \(item.quantity)")
                        .font(AppFont.caption).foregroundStyle(.secondary)
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
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Add Packing Item sheet

struct AddPackingItemSheet: View {
    let onAdd: (String, PackingCategory, Int, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var category    = PackingCategory.clothing
    @State private var quantity    = 1
    @State private var isEssential = false

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
                            columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4),
                            spacing: AppSpacing.sm
                        ) {
                            ForEach(PackingCategory.allCases, id: \.rawValue) { cat in
                                Button { withAnimation(.spring(response: 0.2)) { category = cat } } label: {
                                    VStack(spacing: 5) {
                                        Text(cat.emoji).font(.title2)
                                        Text(cat.rawValue)
                                            .font(.system(size: 10, weight: .medium))
                                            .lineLimit(2).multilineTextAlignment(.center)
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

                    // Item details
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label("Item Details", systemImage: "pencil")
                            .font(AppFont.label).fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "#1A6B6A"))
                            .padding(.horizontal, AppSpacing.md)
                        VStack(spacing: 0) {
                            HStack(spacing: AppSpacing.md) {
                                Text(category.emoji).font(.title3).frame(width: 28)
                                TextField("Item name *", text: $name).font(AppFont.body)
                            }
                            .padding(AppSpacing.md)
                            Divider().padding(.leading, 56)
                            HStack {
                                Text("Quantity").font(AppFont.body)
                                Spacer()
                                Stepper("\(quantity)", value: $quantity, in: 1...99)
                                    .fixedSize()
                            }
                            .padding(AppSpacing.md)
                            Divider()
                            Toggle("Mark as Essential", isOn: $isEssential)
                                .font(AppFont.body)
                                .padding(AppSpacing.md)
                                .tint(Color(hex: "#E9A84C"))
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .padding(.horizontal, AppSpacing.md)
                    }

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name.trimmingCharacters(in: .whitespaces), category, quantity, isEssential)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
