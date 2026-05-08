import SwiftUI

// MARK: - Collaborators Sheet

struct CollaboratorsSheet: View {
    let trip: TripDTO
    @State private var service = TripMemberService()
    @State private var isGeneratingLink = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var errorMsg: String?
    @Environment(\.dismiss) private var dismiss

    // Owners are never listed in trip_members — only invitees are.
    // So if the current user has no accepted/pending row, they're the owner.
    // Falls back to false until currentUserId is populated after fetchMembers.
    private var isOwner: Bool {
        guard !service.currentUserId.isEmpty else { return false }
        return !service.members.contains { $0.userId == service.currentUserId }
    }

    private var acceptedMembers: [TripMemberDTO] {
        service.members.filter { $0.memberStatus == .accepted }
    }
    private var pendingMembers: [TripMemberDTO] {
        service.members.filter { $0.memberStatus == .pending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // ── Invite via link ────────────────────────────────────
                    if isOwner {
                        inviteLinkSection
                    }

                    // ── Active members ─────────────────────────────────────
                    if !acceptedMembers.isEmpty {
                        memberSection(title: "Members", icon: "person.2.fill",
                                      members: acceptedMembers)
                    }

                    // ── Pending invites ────────────────────────────────────
                    if !pendingMembers.isEmpty {
                        memberSection(title: "Pending Invites", icon: "clock.fill",
                                      members: pendingMembers)
                    }

                    // ── Empty state ────────────────────────────────────────
                    if service.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xl)
                    } else if service.members.isEmpty {
                        emptyState
                    }

                    // ── Error (fetch or invite generation) ────────────────
                    let displayError = errorMsg ?? service.errorMessage
                    if let err = displayError {
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

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await service.fetchMembers(tripId: trip.id) }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    TripShareSheet(items: [url.absoluteString, "Join my trip on Voyager!"])
                }
            }
        }
    }

    // MARK: Invite link section

    private var inviteLinkSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Invite People", systemImage: "link.badge.plus")
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: AppSpacing.sm) {
                Text("Generate a link anyone can use to join this trip as an editor. The link expires in 7 days and works once.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, AppSpacing.md)

                Button {
                    Task { await generateLink() }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if isGeneratingLink {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isGeneratingLink ? "Generating…" : "Share Invite Link")
                            .fontWeight(.semibold)
                    }
                    .font(AppFont.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                }
                .disabled(isGeneratingLink)
                .padding(.horizontal, AppSpacing.md)
            }
            .padding(.vertical, AppSpacing.md)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Member section

    @ViewBuilder
    private func memberSection(title: String, icon: String, members: [TripMemberDTO]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(AppFont.label).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#1A6B6A"))
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: 0) {
                ForEach(members) { member in
                    MemberRow(member: member, isOwner: isOwner,
                              onRemove: {
                                  Task {
                                      try? await service.removeMember(memberId: member.id)
                                  }
                              },
                              onRoleChange: { role in
                                  Task {
                                      try? await service.updateRole(memberId: member.id, role: role)
                                  }
                              })
                    if member.id != members.last?.id {
                        Divider().padding(.leading, 56 + AppSpacing.md)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "#2A9D8F").opacity(0.3))
            Text("No collaborators yet")
                .font(AppFont.h4).foregroundStyle(.secondary)
            Text("Share an invite link to bring friends along")
                .font(AppFont.bodySmall).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: Actions

    private func generateLink() async {
        isGeneratingLink = true
        errorMsg = nil
        do {
            shareURL = try await service.generateInviteLink(tripId: trip.id)
            isGeneratingLink = false
            showShareSheet = true
        } catch {
            isGeneratingLink = false
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Member row

private struct MemberRow: View {
    let member: TripMemberDTO
    let isOwner: Bool
    let onRemove: () -> Void
    let onRoleChange: (MemberRole) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            MemberAvatar(member: member, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.displayName)
                    .font(AppFont.body).fontWeight(.medium)
                    .lineLimit(1)
                if member.memberStatus == .pending {
                    Text("Invite pending")
                        .font(AppFont.caption).foregroundStyle(.secondary)
                } else if let joined = member.joinedAt {
                    Text("Joined \(shortDate(joined))")
                        .font(AppFont.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Role badge / picker
            if isOwner && member.memberStatus == .accepted {
                Menu {
                    ForEach(MemberRole.allCases, id: \.rawValue) { role in
                        Button {
                            onRoleChange(role)
                        } label: {
                            Label(role.label, systemImage: role.icon)
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove", systemImage: "person.fill.xmark")
                    }
                } label: {
                    rolePill(for: member.memberRole)
                }
            } else {
                rolePill(for: member.memberRole)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func rolePill(for role: MemberRole) -> some View {
        HStack(spacing: 4) {
            Image(systemName: role.icon).font(.system(size: 10))
            Text(role.label).font(.system(size: 11, weight: .semibold))
            if isOwner && member.memberStatus == .accepted {
                Image(systemName: "chevron.down").font(.system(size: 9))
            }
        }
        .foregroundStyle(Color(hex: "#1A6B6A"))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(hex: "#1A6B6A").opacity(0.1))
        .clipShape(Capsule())
    }

    private func shortDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        let out = DateFormatter(); out.dateFormat = "MMM d"
        return fmt.date(from: iso).map { out.string(from: $0) } ?? iso
    }
}

// MARK: - Reusable member avatar

struct MemberAvatar: View {
    let member: TripMemberDTO
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            if let urlStr = member.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        ZStack {
            Circle().fill(avatarColor)
            Text(member.initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [
            Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F"),
            Color(hex: "#E9A84C"), Color(hex: "#3AAA7A"),
            Color(hex: "#6C5CE7"), Color(hex: "#E05D5D"),
        ]
        let idx = abs(member.id.hashValue) % colors.count
        return colors[idx]
    }
}

// MARK: - Compact avatar stack (used in TripDetailView)

struct MemberAvatarStack: View {
    let members: [TripMemberDTO]
    var maxVisible: Int = 3

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(members.prefix(maxVisible))) { member in
                MemberAvatar(member: member, size: 28)
                    .overlay(Circle().stroke(Color(UIColor.secondarySystemGroupedBackground), lineWidth: 2))
            }
            if members.count > maxVisible {
                ZStack {
                    Circle().fill(Color(hex: "#1A6B6A").opacity(0.12))
                    Text("+\(members.count - maxVisible)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A6B6A"))
                }
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color(UIColor.secondarySystemGroupedBackground), lineWidth: 2))
            }
        }
    }
}
