import SwiftUI

// MARK: - Join Trip View (deep-link landing)

struct JoinTripView: View {
    let token: String
    let tripService: TripService
    let onJoined: (String) -> Void   // called with tripId on success
    @Environment(\.dismiss) private var dismiss

    @State private var service  = TripMemberService()
    @State private var state: JoinState = .ready
    @State private var errorMsg: String?

    enum JoinState { case ready, joining, success }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: AppSpacing.lg) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 88, height: 88)
                        Image(systemName: state == .success ? "checkmark" : "person.badge.plus")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .animation(.spring(response: 0.4), value: state)

                    VStack(spacing: AppSpacing.sm) {
                        Text(state == .success ? "You're in!" : "Trip Invitation")
                            .font(AppFont.h2).fontWeight(.bold)
                        Text(state == .success
                             ? "You've joined the trip. Open it to start collaborating."
                             : "You've been invited to collaborate on a Voyager trip.")
                            .font(AppFont.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    if let err = errorMsg {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(err).font(AppFont.bodySmall)
                        }
                        .foregroundStyle(.red)
                        .padding(AppSpacing.sm)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Action button
                    if state != .success {
                        Button(action: acceptInvite) {
                            ZStack {
                                if state == .joining {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Accept Invitation")
                                        .font(AppFont.body).fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                            .shadow(color: Color(hex: "#1A6B6A").opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(state == .joining)
                        .padding(.horizontal, AppSpacing.md)

                        Button("Decline") { dismiss() }
                            .font(AppFont.body)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Open Trip") {
                            // onJoined triggers navigation in RootView
                            // We dismiss first so the sheet closes cleanly
                            dismiss()
                        }
                        .font(AppFont.body).fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#1A6B6A"))
                    }
                }
                .padding(AppSpacing.xl)

                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func acceptInvite() {
        state    = .joining
        errorMsg = nil
        Task {
            do {
                let tripId = try await service.acceptInvite(token: token)
                // Refresh trips list so the newly joined trip appears
                await tripService.fetchAll()
                await MainActor.run {
                    state = .success
                    onJoined(tripId)
                }
            } catch {
                await MainActor.run {
                    state    = .ready
                    errorMsg = error.localizedDescription
                }
            }
        }
    }
}
