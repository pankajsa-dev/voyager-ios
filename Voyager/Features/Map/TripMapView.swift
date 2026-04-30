import SwiftUI
import MapKit

// MARK: - Day colour palette (cycles for trips with many days)

private let dayColors: [Color] = [
    Color(hex: "#1A6B6A"), Color(hex: "#E9A84C"), Color(hex: "#E05D5D"),
    Color(hex: "#6B5EA8"), Color(hex: "#2A9D8F"), Color(hex: "#F4A261"),
    Color(hex: "#3AAA7A"), Color(hex: "#E76F51"),
]

private func dayColor(_ dayIndex: Int) -> Color {
    dayColors[dayIndex % dayColors.count]
}

// MARK: - Annotated activity (for map pins)

private struct ActivityAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let category: ActivityCategory
    let dayNumber: Int
    let dayIndex: Int
    let isCompleted: Bool
}

// MARK: - TripMapView

struct TripMapView: View {
    let trip: TripDTO
    let days: [ItineraryDay]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAnnotation: ActivityAnnotation? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleDays: Set<Int> = []

    // Activities that have coordinates, filtered to visible days
    private var annotations: [ActivityAnnotation] {
        days.enumerated().flatMap { (dayIdx, day) in
            guard visibleDays.contains(dayIdx) else { return [ActivityAnnotation]() }
            return day.activities.compactMap { activity in
                guard let lat = activity.latitude, let lng = activity.longitude else { return nil }
                return ActivityAnnotation(
                    id: activity.id,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    title: activity.title,
                    category: activity.category,
                    dayNumber: day.dayNumber,
                    dayIndex: dayIdx,
                    isCompleted: activity.isCompleted
                )
            }
        }
    }

    // Coordinates grouped by day (for polylines), filtered to visible days
    private var dayRoutes: [(dayIndex: Int, coords: [CLLocationCoordinate2D])] {
        days.enumerated().compactMap { (dayIdx, day) in
            guard visibleDays.contains(dayIdx) else { return nil }
            let coords = day.activities.compactMap { a -> CLLocationCoordinate2D? in
                guard let lat = a.latitude, let lng = a.longitude else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            guard coords.count >= 2 else { return nil }
            return (dayIndex: dayIdx, coords: coords)
        }
    }

    private var hasAnyCoordinates: Bool { !annotations.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if hasAnyCoordinates {
                    mapContent
                } else {
                    emptyState
                }

                if hasAnyCoordinates {
                    legendCard
                }
            }
            .navigationTitle(trip.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Day-by-day route polylines
            ForEach(dayRoutes, id: \.dayIndex) { route in
                MapPolyline(coordinates: route.coords)
                    .stroke(dayColor(route.dayIndex), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            }

            // Activity pins
            ForEach(annotations) { ann in
                Annotation(ann.title, coordinate: ann.coordinate, anchor: .bottom) {
                    PinView(annotation: ann, isSelected: selectedAnnotation?.id == ann.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25)) {
                                selectedAnnotation = selectedAnnotation?.id == ann.id ? nil : ann
                            }
                        }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            visibleDays = Set(days.indices)
            fitCamera()
        }
        .overlay(alignment: .topTrailing) {
            if let ann = selectedAnnotation {
                calloutCard(ann)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .padding(.trailing, AppSpacing.md)
            }
        }
    }

    // MARK: - Callout card

    private func calloutCard(_ ann: ActivityAnnotation) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(ann.category.emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(dayColor(ann.dayIndex).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(ann.dayNumber)")
                    .font(AppFont.caption)
                    .foregroundStyle(dayColor(ann.dayIndex))
                    .fontWeight(.semibold)
                Text(ann.title)
                    .font(AppFont.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                withAnimation { selectedAnnotation = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
        .frame(maxWidth: 280)
    }

    // MARK: - Legend

    private var legendCard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(days.indices, id: \.self) { idx in
                    let day = days[idx]
                    let hasCoords = day.activities.contains { $0.latitude != nil }
                    let isVisible = visibleDays.contains(idx)
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            visibleDays.formSymmetricDifference([idx])
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(dayColor(idx))
                                .frame(width: 10, height: 10)
                            Text("Day \(day.dayNumber)")
                                .font(AppFont.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(hasCoords ? .primary : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            hasCoords
                                ? dayColor(idx).opacity(isVisible ? 0.15 : 0.05)
                                : Color(UIColor.tertiarySystemGroupedBackground)
                        )
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(dayColor(idx).opacity(isVisible ? 0.5 : 0), lineWidth: 1))
                        .opacity(isVisible ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasCoords)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(.thinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: "#1A6B6A").opacity(0.4))
            Text("No locations yet")
                .font(AppFont.h3).fontWeight(.bold)
            Text("Add locations when creating activities\nand they'll appear on the map.")
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Camera fit

    private func fitCamera() {
        guard !annotations.isEmpty else { return }
        if annotations.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: annotations[0].coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
            return
        }
        let lats = annotations.map(\.coordinate.latitude)
        let lngs = annotations.map(\.coordinate.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.02)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Pin view

private struct PinView: View {
    let annotation: ActivityAnnotation
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(dayColor(annotation.dayIndex))
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: dayColor(annotation.dayIndex).opacity(0.4), radius: 4, y: 2)

                Text(annotation.category.emoji)
                    .font(.system(size: isSelected ? 22 : 16))
            }
            .opacity(annotation.isCompleted ? 0.5 : 1.0)

            if annotation.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white, Color(hex: "#3AAA7A"))
                    .offset(x: 4, y: 4)
            }
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}
