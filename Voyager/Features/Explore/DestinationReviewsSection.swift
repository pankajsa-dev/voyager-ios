import SwiftUI

// MARK: - Reviews section (embedded in DestinationDetailView)

struct DestinationReviewsSection: View {
    let destination: DestinationDTO
    @State private var service      = ReviewService()
    @State private var showWrite    = false
    @State private var showAll      = false
    @State private var showDeleteConfirm = false

    private var visibleReviews: [ReviewDTO] {
        showAll ? service.reviews : Array(service.reviews.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            // ── Header ────────────────────────────────────────────────────
            HStack {
                SectionTitle("Reviews")
                Spacer()
                Button {
                    showWrite = true
                } label: {
                    Label(service.myReview == nil ? "Write a Review" : "Edit Review",
                          systemImage: service.myReview == nil ? "square.and.pencil" : "pencil")
                        .font(AppFont.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.voyagerPrimary)
                }
            }

            if service.isLoading {
                reviewsSkeleton
            } else if service.reviews.isEmpty {
                emptyState
            } else {
                // ── Aggregate ──────────────────────────────────────────
                aggregateCard

                // ── Review list ────────────────────────────────────────
                VStack(spacing: AppSpacing.sm) {
                    ForEach(visibleReviews) { review in
                        ReviewRow(review: review, isOwn: review.id == service.myReview?.id) {
                            showDeleteConfirm = true
                        }
                        if review.id != visibleReviews.last?.id { Divider() }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                // ── Show all toggle ────────────────────────────────────
                if service.reviews.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAll ? "Show fewer reviews" : "See all \(service.reviews.count) reviews")
                            Image(systemName: showAll ? "chevron.up" : "chevron.down")
                        }
                        .font(AppFont.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.voyagerPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
        }
        .task { await service.fetchReviews(destinationId: destination.id) }
        .sheet(isPresented: $showWrite, onDismiss: {
            Task { await service.fetchReviews(destinationId: destination.id) }
        }) {
            WriteReviewSheet(
                destination: destination,
                existing: service.myReview,
                service: service
            )
        }
        .confirmationDialog("Delete your review?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let id = service.myReview?.id else { return }
                Task { try? await service.delete(reviewId: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }

    // MARK: - Aggregate card

    private var aggregateCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.lg) {

            // Big rating number
            VStack(spacing: 4) {
                Text(String(format: "%.1f", service.averageRating))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.voyagerPrimary)
                StarRow(rating: service.averageRating, size: 14)
                Text("\(service.reviews.count) review\(service.reviews.count == 1 ? "" : "s")")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 100)

            // Distribution bars
            VStack(spacing: 6) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                    RatingBar(star: star,
                              count: service.count(for: star),
                              total: service.reviews.count)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "star.bubble")
                .font(.system(size: 32))
                .foregroundStyle(Color.voyagerPrimary.opacity(0.4))
            Text("No reviews yet")
                .font(AppFont.label).fontWeight(.semibold)
            Text("Be the first to share your experience")
                .font(AppFont.caption).foregroundStyle(.secondary)
            Button { showWrite = true } label: {
                Text("Write a Review")
                    .font(AppFont.label).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, 10)
                    .background(Color.voyagerPrimary)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    // MARK: - Loading skeleton

    private var reviewsSkeleton: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Circle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: 36, height: 36)
                        .shimmer()
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 120, height: 12)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(maxWidth: .infinity).frame(height: 10)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(maxWidth: .infinity).frame(height: 10)
                            .shimmer()
                    }
                }
                .padding(AppSpacing.md)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

// MARK: - Single review row

private struct ReviewRow: View {
    let review: ReviewDTO
    let isOwn: Bool
    let onDelete: () -> Void

    private var formattedDate: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: review.createdAt)
            ?? ISO8601DateFormatter().date(from: review.createdAt)
            ?? Date()
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                // Avatar
                AvatarView(url: review.authorAvatarUrl, name: review.authorName, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(review.authorName)
                            .font(AppFont.label).fontWeight(.semibold)
                        if isOwn {
                            Text("You")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.voyagerPrimary)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text(formattedDate)
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    StarRow(rating: Double(review.rating), size: 12)
                }
            }

            if !review.body.isEmpty {
                Text(review.body)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
            }

            if isOwn {
                HStack {
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
        }
        .padding(AppSpacing.md)
    }
}

// MARK: - Write / edit review sheet

struct WriteReviewSheet: View {
    let destination: DestinationDTO
    let existing: ReviewDTO?
    let service: ReviewService

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int
    @State private var reviewText: String
    @State private var isSaving   = false
    @State private var saveError: String?

    init(destination: DestinationDTO, existing: ReviewDTO?, service: ReviewService) {
        self.destination = destination
        self.existing    = existing
        self.service     = service
        _rating     = State(initialValue: existing?.rating ?? 0)
        _reviewText = State(initialValue: existing?.body   ?? "")
    }

    private var isValid: Bool { rating > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // Destination badge
                    HStack(spacing: AppSpacing.sm) {
                        Text(flag(for: destination.countryCode))
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(destination.name)
                                .font(AppFont.label).fontWeight(.semibold)
                            Text(destination.country)
                                .font(AppFont.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .padding(.horizontal, AppSpacing.md)

                    // Star picker
                    VStack(spacing: AppSpacing.sm) {
                        Text("Your Rating")
                            .font(AppFont.label).fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.md)

                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        rating = star
                                    }
                                } label: {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 36))
                                        .foregroundStyle(star <= rating ? Color.voyagerAccent : Color(UIColor.systemGray4))
                                        .scaleEffect(star <= rating ? 1.1 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if rating > 0 {
                            Text(ratingLabel)
                                .font(AppFont.label)
                                .foregroundStyle(Color.voyagerPrimary)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: rating)

                    // Review body
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Your Review (optional)")
                            .font(AppFont.label).fontWeight(.semibold)
                            .padding(.horizontal, AppSpacing.md)

                        TextEditor(text: $reviewText)
                            .font(AppFont.body)
                            .frame(minHeight: 120)
                            .padding(AppSpacing.sm)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .padding(.horizontal, AppSpacing.md)
                    }

                    // Error banner
                    if let err = saveError {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                            Text(err).font(AppFont.bodySmall)
                            Spacer()
                            Button { saveError = nil } label: {
                                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(AppSpacing.sm)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Submit
                    Button {
                        // Snapshot @State values synchronously on MainActor before the Task
                        // starts — reading @State inside an async Task can return stale or
                        // zeroed values if SwiftUI has rebuilt the view struct by then.
                        let capturedRating = rating
                        let capturedBody   = String(reviewText.trimmingCharacters(in: .whitespacesAndNewlines))
                        isSaving = true
                        saveError = nil
                        Task {
                            do {
                                try await service.submit(destinationId: destination.id, rating: capturedRating, body: capturedBody)
                                await MainActor.run { dismiss() }
                            } catch {
                                await MainActor.run { isSaving = false; saveError = error.localizedDescription }
                            }
                        }
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(existing == nil ? "Submit Review" : "Update Review")
                                    .font(AppFont.body).fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isValid
                                ? LinearGradient(colors: [Color.voyagerPrimary, Color.voyagerPrimaryLight],
                                                 startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray4)],
                                                 startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .shadow(color: isValid ? Color.voyagerPrimary.opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .disabled(!isValid || isSaving)
                    .padding(.horizontal, AppSpacing.md)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(existing == nil ? "Write a Review" : "Edit Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return ""
        }
    }
}

// MARK: - Star row (read-only, supports half stars)

struct StarRow: View {
    let rating: Double
    let size: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                let fill = min(max(rating - Double(i - 1), 0), 1)
                starIcon(fill: fill)
                    .font(.system(size: size))
                    .foregroundStyle(fill > 0 ? Color.voyagerAccent : Color(UIColor.systemGray4))
            }
        }
    }

    @ViewBuilder
    private func starIcon(fill: Double) -> some View {
        if fill >= 0.75 {
            Image(systemName: "star.fill")
        } else if fill >= 0.25 {
            Image(systemName: "star.leadinghalf.filled")
        } else {
            Image(systemName: "star")
        }
    }
}

// MARK: - Rating distribution bar

private struct RatingBar: View {
    let star: Int
    let count: Int
    let total: Int

    private var fraction: CGFloat {
        total == 0 ? 0 : CGFloat(count) / CGFloat(total)
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("\(star)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 10, alignment: .trailing)
            Image(systemName: "star.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.voyagerAccent)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.systemGray5))
                    Capsule()
                        .fill(Color.voyagerPrimary.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
    }
}

// MARK: - Avatar view

private struct AvatarView: View {
    let url: String?
    let name: String
    let size: CGFloat

    private var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap { $0.first?.uppercased() }.joined()
    }

    var body: some View {
        if let urlStr = url, let u = URL(string: urlStr) {
            AsyncImage(url: u) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    initialsView
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            initialsView
                .frame(width: size, height: size)
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(Color.voyagerPrimary.opacity(0.15))
            .overlay(
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundStyle(Color.voyagerPrimary)
            )
    }
}

// MARK: - Section title (local re-use — mirrors DestinationDetailView's private version)

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(AppFont.h3).fontWeight(.bold)
    }
}

