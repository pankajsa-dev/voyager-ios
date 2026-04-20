import SwiftUI
import MapKit

struct DestinationDetailView: View {
    let destination: DestinationDTO
    @State var service: DestinationService
    @Environment(\.dismiss) private var dismiss
    @State private var showFullOverview = false
    @State private var region: MKCoordinateRegion

    init(destination: DestinationDTO, service: DestinationService) {
        self.destination = destination
        self._service    = State(initialValue: service)
        self._region     = State(initialValue: MKCoordinateRegion(
            center:      CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude),
            latitudinalMeters: 50_000,
            longitudinalMeters: 50_000
        ))
    }

    private var isSaved: Bool { service.saved.contains(destination.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Hero ──────────────────────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    DestinationHero(
                        imageURLs: destination.imageUrls,
                        height: 300,
                        destinationName: destination.name,
                        country: destination.country
                    )

                    // Gradient scrim
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 300)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(flag(for: destination.countryCode))
                                .font(.title3)
                            Text(destination.country)
                                .font(AppFont.body)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        Text(destination.name)
                            .font(AppFont.h1)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text(destination.tagline)
                            .font(AppFont.body)
                            .foregroundStyle(.white.opacity(0.85))
                            .italic()
                    }
                    .padding(AppSpacing.md)
                }

                // ── Quick stats row ───────────────────────────────────────
                HStack(spacing: 0) {
                    StatPill(icon: "star.fill",  value: String(format: "%.1f", destination.rating),
                             label: "\(destination.reviewCount) reviews", iconColor: .yellow)
                    Divider().frame(height: 36)
                    StatPill(icon: "dollarsign.circle.fill",
                             value: "~$\(Int(destination.avgBudgetPerDay))",
                             label: "per day", iconColor: Color.voyagerAccent)
                    Divider().frame(height: 36)
                    StatPill(icon: "globe", value: destination.language,
                             label: "language", iconColor: Color.voyagerPrimaryLight)
                }
                .padding(.vertical, AppSpacing.sm)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cardShadow()

                // ── Overview ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionTitle("Overview")
                    Text(destination.overview)
                        .font(AppFont.body)
                        .foregroundStyle(.primary)
                        .lineLimit(showFullOverview ? nil : 3)
                        .lineSpacing(4)
                    if destination.overview.count > 120 {
                        Button(showFullOverview ? "Show less" : "Read more") {
                            withAnimation(.easeInOut(duration: 0.2)) { showFullOverview.toggle() }
                        }
                        .font(AppFont.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.voyagerPrimaryLight)
                    }
                }
                .padding(AppSpacing.md)

                Divider().padding(.horizontal, AppSpacing.md)

                // ── Tags ──────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionTitle("Highlights")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(destination.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(AppFont.label)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.voyagerPrimary.opacity(0.1))
                                    .foregroundStyle(Color.voyagerPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.horizontal, -AppSpacing.md)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)

                Divider().padding(.horizontal, AppSpacing.md)

                // ── Best time to visit ────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionTitle("Best Time to Visit")
                    BestMonthsView(months: destination.bestMonths)
                }
                .padding(AppSpacing.md)

                Divider().padding(.horizontal, AppSpacing.md)

                // ── Map ───────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionTitle("Location")
                    Map(coordinateRegion: $region, annotationItems: [destination]) { dest in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: dest.latitude, longitude: dest.longitude)) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(Color.voyagerPrimary)
                                        .frame(width: 36, height: 36)
                                    Text(flag(for: dest.countryCode))
                                        .font(.system(size: 18))
                                }
                                .shadow(radius: 4)
                                Text(dest.name)
                                    .font(AppFont.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .disabled(false)
                }
                .padding(AppSpacing.md)

                // ── CTA ───────────────────────────────────────────────────
                Button {
                    // Navigate to trip planner with this destination pre-filled
                } label: {
                    Label("Plan a Trip Here", systemImage: "map.fill")
                        .font(AppFont.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.voyagerPrimary, Color.voyagerPrimaryLight],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .shadow(color: Color.voyagerPrimary.opacity(0.3), radius: 8, y: 4)
                }
                .padding(AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await service.toggleSave(destination.id) }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSaved ? Color.voyagerAccent : .white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .animation(.spring(response: 0.3), value: isSaved)
            }
        }
    }
}

// MARK: - Stat pill

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(iconColor)
                Text(value)
                    .font(AppFont.bodySmall)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Best months bar

private struct BestMonthsView: View {
    let months: [Int]
    private let names = ["J","F","M","A","M","J","J","A","S","O","N","D"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...12, id: \.self) { m in
                let best = months.contains(m)
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(best ? Color.voyagerPrimary : Color(UIColor.systemGray5))
                        .frame(height: best ? 28 : 16)
                    Text(names[m-1])
                        .font(.system(size: 9, weight: best ? .bold : .regular))
                        .foregroundStyle(best ? Color.voyagerPrimary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.4).delay(Double(m) * 0.03), value: months)
            }
        }
    }
}

// MARK: - Section title helper

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(AppFont.h3)
            .fontWeight(.bold)
    }
}

// Make DestinationDTO work with MapKit annotation
extension DestinationDTO: Equatable {
    static func == (lhs: DestinationDTO, rhs: DestinationDTO) -> Bool { lhs.id == rhs.id }
}
