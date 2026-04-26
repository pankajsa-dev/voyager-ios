import SwiftUI
import PDFKit

struct BookingDetailView: View {
    let booking: BookingDTO
    let service: BookingService

    @Environment(\.dismiss) private var dismiss
    @State private var currentStatus: BookingStatus
    @State private var showDeleteConfirm = false
    @State private var documentPaths: [String] = []
    @State private var showFullPDF = false

    init(booking: BookingDTO, service: BookingService) {
        self.booking = booking
        self.service = service
        _currentStatus = State(initialValue: BookingStatus(rawValue: booking.status) ?? .confirmed)
    }

    private func statusColor(for status: BookingStatus) -> Color {
        switch status {
        case .confirmed: return Color(hex: "#3AAA7A")
        case .pending:   return Color(hex: "#E9A84C")
        case .cancelled: return Color(hex: "#E05D5D")
        case .completed: return .secondary
        }
    }

    private func parseISO(_ str: String) -> Date? {
        ISO8601DateFormatter().date(from: str)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    headerCard
                    detailsCard
                    if !booking.notes.isEmpty { notesCard }
                    if !documentPaths.isEmpty { documentCard }
                    statusPickerCard
                    deleteButton
                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(booking.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                documentPaths = BookingDocumentStore.paths(forBookingId: booking.id)
            }
            .sheet(isPresented: $showFullPDF) {
                fullPDFSheet
            }
            .confirmationDialog("Delete this booking?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await service.delete(bookingId: booking.id)
                        await MainActor.run { dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: AppSpacing.md) {
            Text(BookingType(rawValue: booking.type)?.emoji ?? "📋")
                .font(.system(size: 48))
                .frame(width: 88, height: 88)
                .background(Color(hex: "#1A6B6A").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            Text(booking.title)
                .font(AppFont.h3).fontWeight(.bold)
                .multilineTextAlignment(.center)
            if !booking.providerName.isEmpty {
                Text(booking.providerName)
                    .font(AppFont.body).foregroundStyle(.secondary)
            }
            Text(currentStatus.rawValue)
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(statusColor(for: currentStatus))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(statusColor(for: currentStatus).opacity(0.12))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Details", systemImage: "info.circle")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            VStack(spacing: 0) {
                if !booking.bookingReference.isEmpty {
                    detailRow(icon: "number", label: "Reference", value: booking.bookingReference)
                    Divider().padding(.leading, AppSpacing.md)
                }
                if !booking.confirmationNumber.isEmpty {
                    detailRow(icon: "checkmark.seal", label: "Confirmation", value: booking.confirmationNumber)
                    Divider().padding(.leading, AppSpacing.md)
                }
                if let date = parseISO(booking.startDate) {
                    detailRow(icon: "calendar", label: "Start date",
                              value: date.formatted(date: .long, time: .omitted))
                    Divider().padding(.leading, AppSpacing.md)
                }
                if let endStr = booking.endDate, let date = parseISO(endStr) {
                    detailRow(icon: "calendar.badge.clock", label: "End date",
                              value: date.formatted(date: .long, time: .omitted))
                    Divider().padding(.leading, AppSpacing.md)
                }
                if booking.totalPrice > 0 {
                    detailRow(icon: "creditcard", label: "Total price",
                              value: booking.totalPrice.formatted(.currency(code: booking.currency)))
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(AppFont.body).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(AppFont.body).fontWeight(.medium)
        }
        .padding(AppSpacing.md)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Notes", systemImage: "note.text")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            Text(booking.notes)
                .font(AppFont.body)
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Document / PDF viewer

    private var documentCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Document", systemImage: "doc.fill")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            if let path = documentPaths.first,
               let pdf = PDFDocument(url: URL(fileURLWithPath: path)) {
                Button { showFullPDF = true } label: {
                    VStack(spacing: 0) {
                        PDFKitView(document: pdf, singlePage: true)
                            .frame(height: 220)
                            .clipped()
                            .allowsHitTesting(false)
                        Divider()
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "qrcode.viewfinder")
                                .foregroundStyle(Color(hex: "#1A6B6A"))
                            Text("Tap to view • QR codes visible")
                                .font(AppFont.caption).foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    private var fullPDFSheet: some View {
        Group {
            if let path = documentPaths.first,
               let pdf = PDFDocument(url: URL(fileURLWithPath: path)) {
                NavigationStack {
                    PDFKitView(document: pdf, singlePage: false)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("Booking Document")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showFullPDF = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Status picker

    private var statusPickerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Change Status", systemImage: "pencil.circle")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)
            VStack(spacing: 0) {
                ForEach(BookingStatus.allCases, id: \.rawValue) { status in
                    Button {
                        currentStatus = status
                        Task { try? await service.updateStatus(bookingId: booking.id, status: status) }
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            Circle()
                                .fill(statusColor(for: status))
                                .frame(width: 10, height: 10)
                            Text(status.rawValue)
                                .font(AppFont.body).foregroundStyle(.primary)
                            Spacer()
                            if currentStatus == status {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: "#1A6B6A"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                    .buttonStyle(.plain)
                    if status != BookingStatus.allCases.last {
                        Divider().padding(.leading, AppSpacing.md)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete Booking", systemImage: "trash")
                .font(AppFont.body).fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "#E05D5D"))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        }
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - PDF viewer (UIViewRepresentable)

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let singlePage: Bool

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = singlePage ? .singlePage : .singlePageContinuous
        view.displayDirection = .vertical
        view.isUserInteractionEnabled = !singlePage
        view.backgroundColor = UIColor.secondarySystemGroupedBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = document
    }
}

// MARK: - Local document store (UserDefaults-backed, no schema changes needed)

enum BookingDocumentStore {
    private static let key = "voyager_booking_docs"

    static func save(paths: [String], forBookingId id: String) {
        var all = loadAll()
        all[id] = paths
        UserDefaults.standard.set(all, forKey: key)
    }

    static func paths(forBookingId id: String) -> [String] {
        loadAll()[id] ?? []
    }

    private static func loadAll() -> [String: [String]] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
    }
}
