import SwiftUI
import PhotosUI

// MARK: - Main view

struct TripPhotoJournalView: View {
    let trip: TripDTO
    @State private var service       = JournalService()
    @State private var pickerItems:  [PhotosPickerItem] = []
    @State private var showPicker    = false
    @State private var selectedPhoto: JournalPhoto?
    @State private var isUploading   = false
    @State private var uploadError:  String?

    // Photos grouped by day; nil-day photos go last under "Untagged"
    private var grouped: [(label: String, photos: [JournalPhoto])] {
        var byDay: [Int: [JournalPhoto]] = [:]
        var untagged: [JournalPhoto]     = []
        for p in service.photos {
            if let d = p.dayNumber { byDay[d, default: []].append(p) }
            else                   { untagged.append(p) }
        }
        var result = byDay.keys.sorted().map { day in
            (label: "Day \(day)", photos: byDay[day]!)
        }
        if !untagged.isEmpty { result.append((label: "Untagged", photos: untagged)) }
        return result
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ZStack {
            if service.isLoading {
                loadingSkeleton
            } else if service.photos.isEmpty {
                emptyState
            } else {
                photoGrid
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) { fab }
        .task { await service.fetchPhotos(tripId: trip.id) }
        .photosPicker(isPresented: $showPicker, selection: $pickerItems,
                      maxSelectionCount: 20, matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await uploadPicked(items) }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            JournalFullscreenViewer(
                photos: service.photos,
                initial: photo,
                onCaptionSave: { id, caption in
                    Task { try? await service.updateCaption(photoId: id, caption: caption) }
                },
                onDelete: { p in
                    Task { try? await service.deletePhoto(p) }
                }
            )
        }
        .overlay(alignment: .top) {
            if let err = uploadError {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(err).font(AppFont.bodySmall)
                    Spacer()
                    Button { uploadError = nil } label: {
                        Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(AppSpacing.sm)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .padding(AppSpacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: uploadError)
    }

    // MARK: - Grid

    private var photoGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(grouped, id: \.label) { group in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(group.label)
                            .font(AppFont.label).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppSpacing.md)

                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(group.photos) { photo in
                                JournalCell(photo: photo)
                                    .onTapGesture { selectedPhoto = photo }
                            }
                        }
                    }
                }
                Spacer(minLength: 80)
            }
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: - FAB

    private var fab: some View {
        ZStack {
            if isUploading {
                ProgressView()
                    .tint(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(hex: "#1A6B6A"))
                    .clipShape(Circle())
                    .shadow(color: Color(hex: "#1A6B6A").opacity(0.4), radius: 10, y: 4)
            } else {
                Button { showPicker = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(hex: "#1A6B6A"))
                        .clipShape(Circle())
                        .shadow(color: Color(hex: "#1A6B6A").opacity(0.4), radius: 10, y: 4)
                }
            }
        }
        .padding(AppSpacing.lg)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "#1A6B6A").opacity(0.5))
            Text("No photos yet")
                .font(AppFont.h4).fontWeight(.semibold)
            Text("Tap + to add your first memories from this trip")
                .font(AppFont.bodySmall).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showPicker = true } label: {
                Label("Add Photos", systemImage: "plus.circle.fill")
                    .font(AppFont.body).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#1A6B6A"))
                    .clipShape(Capsule())
            }
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.xl)
    }

    // MARK: - Loading skeleton

    private var loadingSkeleton: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<12, id: \.self) { _ in
                    Color(UIColor.secondarySystemGroupedBackground)
                        .aspectRatio(1, contentMode: .fill)
                        .shimmer()
                }
            }
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: - Upload

    private func uploadPicked(_ items: [PhotosPickerItem]) async {
        await MainActor.run { isUploading = true; pickerItems = [] }
        var failed = 0
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { failed += 1; continue }
            let compressed = compress(data) ?? data
            do {
                try await service.addPhoto(
                    tripId: trip.id,
                    dayNumber: nil,
                    activityId: nil,
                    imageData: compressed,
                    caption: ""
                )
            } catch {
                failed += 1
            }
        }
        await MainActor.run {
            isUploading = false
            if failed > 0 { uploadError = "\(failed) photo(s) failed to upload." }
        }
    }

    private func compress(_ data: Data) -> Data? {
        guard let ui = UIImage(data: data) else { return nil }
        let maxDim: CGFloat = 1800
        let size = ui.size
        if max(size.width, size.height) <= maxDim { return ui.jpegData(compressionQuality: 0.85) }
        let scale  = maxDim / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized  = renderer.image { _ in ui.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

// MARK: - Grid cell

private struct JournalCell: View {
    let photo: JournalPhoto

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Color(UIColor.secondarySystemGroupedBackground)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    default:
                        Color(UIColor.secondarySystemGroupedBackground).shimmer()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()

                if !photo.caption.isEmpty {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center, endPoint: .bottom
                    )
                    Text(photo.caption)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fill)
    }
}

// MARK: - Fullscreen viewer

struct JournalFullscreenViewer: View {
    let photos: [JournalPhoto]
    let initial: JournalPhoto
    let onCaptionSave: (String, String) -> Void
    let onDelete: (JournalPhoto) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentId: String
    @State private var editingCaption = false
    @State private var captionDraft   = ""
    @State private var showDeleteConfirm = false
    @FocusState private var captionFocused: Bool

    init(photos: [JournalPhoto], initial: JournalPhoto,
         onCaptionSave: @escaping (String, String) -> Void,
         onDelete: @escaping (JournalPhoto) -> Void) {
        self.photos        = photos
        self.initial       = initial
        self.onCaptionSave = onCaptionSave
        self.onDelete      = onDelete
        _currentId         = State(initialValue: initial.id)
    }

    private var current: JournalPhoto {
        photos.first(where: { $0.id == currentId }) ?? initial
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // ── Paged photo viewer ────────────────────────────────────────
            TabView(selection: $currentId) {
                ForEach(photos) { photo in
                    AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                        default:
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(photo.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { if editingCaption { saveCaption() } }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // ── Bottom overlay ────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()
                captionBar
            }
            .ignoresSafeArea(edges: .bottom)

            // ── Top bar ───────────────────────────────────────────────────
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("\(photoIndex + 1) / \(photos.count)")
                        .font(AppFont.label).foregroundStyle(.white)
                    Spacer()
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                Spacer()
            }
        }
        .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let p = current
                dismiss()
                onDelete(p)
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }

    private var photoIndex: Int {
        photos.firstIndex(where: { $0.id == currentId }) ?? 0
    }

    // MARK: - Caption bar

    private var captionBar: some View {
        VStack(spacing: 0) {
            if editingCaption {
                TextField("Add a caption…", text: $captionDraft, axis: .vertical)
                    .font(AppFont.body)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .focused($captionFocused)
                    .submitLabel(.done)
                    .onSubmit { saveCaption() }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)

                HStack {
                    Button("Cancel") {
                        editingCaption = false
                        captionFocused = false
                    }
                    .font(AppFont.label).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button("Save") { saveCaption() }
                        .font(AppFont.label).fontWeight(.semibold).foregroundStyle(.white)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            } else {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let day = current.dayNumber {
                            Text("Day \(day)")
                                .font(AppFont.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        if current.caption.isEmpty {
                            Text("Tap to add a caption")
                                .font(AppFont.bodySmall)
                                .foregroundStyle(.white.opacity(0.5))
                                .italic()
                        } else {
                            Text(current.caption)
                                .font(AppFont.bodySmall)
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                    Button {
                        captionDraft   = current.caption
                        editingCaption = true
                        captionFocused = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
            }
        }
        .background(.ultraThinMaterial.opacity(0.8))
    }

    private func saveCaption() {
        let trimmed = captionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        onCaptionSave(current.id, trimmed)
        editingCaption = false
        captionFocused = false
    }
}

