import SwiftUI
import PhotosUI

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AppSettings.self)   private var appSettings
    @State private var tripService        = TripService()
    @State private var profileService     = ProfileService()
    @State private var showEditProfile    = false
    @State private var showSignOutConfirm = false
    @State private var showCurrencyPicker = false
    @State private var showLanguagePicker = false

    // Avatar photo
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?

    private var displayName: String { authVM.currentUser?.name ?? "Traveller" }
    private var email: String       { authVM.currentUser?.email ?? "" }

    private var initials: String {
        displayName.split(separator: " ").prefix(2)
            .compactMap { $0.first?.uppercased() }.joined()
    }

    private var tripsCount: Int {
        tripService.trips.filter { $0.status != TripStatus.cancelled.rawValue }.count
    }

    private var countriesCount: Int {
        Set(tripService.trips.compactMap {
            $0.destinationName.isEmpty ? nil : $0.destinationName
        }).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // ── Hero header ──────────────────────────────────
                    heroHeader

                    // ── Stats ────────────────────────────────────────
                    statsRow
                        .padding(.horizontal, AppSpacing.md)

                    // ── Settings sections ────────────────────────────
                    VStack(spacing: AppSpacing.md) {
                        SettingsSection(title: "Account", items: [
                            SettingsRow(icon: "person.circle",    label: "Edit Profile",       tint: Color(hex: "#2A9D8F")) { showEditProfile = true },
                            SettingsRow(icon: "envelope",          label: email,                tint: Color(hex: "#2A9D8F"), isDetail: true) {},
                            SettingsRow(icon: "bell",             label: "Notifications",      tint: Color(hex: "#2A9D8F")) {},
                            SettingsRow(icon: "lock.shield",      label: "Privacy & Security", tint: Color(hex: "#2A9D8F")) {},
                        ])

                        SettingsSection(title: "Preferences", items: [
                            SettingsRow(icon: "globe",            label: "Language",    tint: Color(hex: "#1A6B6A"), detail: appSettings.languageDisplayName) { showLanguagePicker = true },
                            SettingsRow(icon: "dollarsign.circle",label: "Currency",    tint: Color(hex: "#1A6B6A"), detail: appSettings.currency) { showCurrencyPicker = true },
                            SettingsRow(icon: "moon",             label: "Appearance",  tint: Color(hex: "#1A6B6A")) {},
                        ])

                        SettingsSection(title: "Support", items: [
                            SettingsRow(icon: "questionmark.circle", label: "Help & FAQ",    tint: .gray) {},
                            SettingsRow(icon: "star",               label: "Rate Voyager",   tint: Color(hex: "#E9A84C")) {},
                            SettingsRow(icon: "info.circle",        label: "About",          tint: .gray) {},
                        ])
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // ── Sign out ─────────────────────────────────────
                    Button { showSignOutConfirm = true } label: {
                        Text("Sign Out")
                            .font(AppFont.body).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.08))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    }
                    .padding(.horizontal, AppSpacing.md)

                    Text("Voyager v1.0")
                        .font(AppFont.caption)
                        .foregroundStyle(.tertiary)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.top, AppSpacing.md)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task { await tripService.fetchAll() }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(name: displayName, email: email)
                    .environment(authVM)
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerSheet(selected: appSettings.currency) { appSettings.currency = $0 }
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerSheet(selected: appSettings.languageCode) { appSettings.languageCode = $0 }
            }
            .confirmationDialog("Sign out of Voyager?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authVM.signOut() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        VStack(spacing: AppSpacing.md) {
            // Avatar — tappable for photo picker
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let avatarImage {
                            avatarImage
                                .resizable().scaledToFill()
                        } else {
                            LinearGradient(
                                colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .overlay(
                                Text(initials)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                    // Camera badge / uploading spinner
                    Circle()
                        .fill(isUploadingAvatar ? Color(.systemGray3) : Color(hex: "#E9A84C"))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Group {
                                if isUploadingAvatar {
                                    ProgressView().scaleEffect(0.6).tint(.white)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                }
                            }
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .onChange(of: avatarItem) { _, item in
                Task {
                    guard let item,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let ui   = UIImage(data: data) else { return }

                    // Show locally immediately
                    await MainActor.run { avatarImage = Image(uiImage: ui) }

                    // Compress and upload
                    guard let jpeg = ui.jpegData(compressionQuality: 0.82) else { return }
                    await MainActor.run { isUploadingAvatar = true; avatarError = nil }
                    do {
                        _ = try await profileService.uploadAvatar(jpeg)
                    } catch {
                        await MainActor.run { avatarError = error.localizedDescription }
                    }
                    await MainActor.run { isUploadingAvatar = false }
                }
            }

            // Name + email
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(email)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(.secondary)
            }

            if let err = avatarError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(err).font(AppFont.caption).lineLimit(2)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, AppSpacing.sm)
                .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, AppSpacing.md)
        .task {
            await profileService.fetch()
            // Restore saved avatar if no local pick yet
            if avatarImage == nil, let urlStr = profileService.profile?.avatarUrl,
               let url = URL(string: urlStr) {
                let (data, _) = (try? await URLSession.shared.data(from: url)) ?? (nil, URLResponse())
                if let data, let ui = UIImage(data: data) {
                    avatarImage = Image(uiImage: ui)
                }
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            ProfileStat(value: "\(tripsCount)",    label: "Trips",     icon: "airplane")
            dividerLine
            ProfileStat(value: "\(countriesCount)", label: "Places",    icon: "mappin.circle")
            dividerLine
            ProfileStat(value: "0",                label: "Badges",    icon: "star.circle")
        }
        .padding(.vertical, AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(UIColor.separator))
            .frame(width: 0.5, height: 40)
    }
}

// MARK: - Profile stat

private struct ProfileStat: View {
    let value: String
    let label: String
    let icon:  String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#1A6B6A"))
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings section / row

private struct SettingsRow: Identifiable {
    let id     = UUID()
    let icon:   String
    let label:  String
    let tint:   Color
    var detail: String? = nil
    var isDetail: Bool  = false
    let action: () -> Void
}

private struct SettingsSection: View {
    let title: String
    let items: [SettingsRow]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppSpacing.sm)

            VStack(spacing: 0) {
                ForEach(items) { row in
                    Button(action: row.action) {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: row.icon)
                                .foregroundStyle(row.tint)
                                .frame(width: 24)
                            Text(row.label)
                                .font(AppFont.body)
                                .foregroundStyle(row.isDetail ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                            if let detail = row.detail {
                                Text(detail)
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !row.isDetail {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if row.id != items.last?.id {
                        Divider()
                            .padding(.leading, AppSpacing.md + 24 + AppSpacing.md)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        }
    }
}

// MARK: - Edit Profile sheet

private struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var name:  String
    @State private var email: String
    @State private var isSaving = false

    init(name: String, email: String) {
        _name  = State(initialValue: name)
        _email = State(initialValue: email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Full name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
                Section("Email") {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(.secondary)
                        .disabled(true)   // email change requires re-auth; disable for now
                }
                Section {
                    Text("Email change requires re-authentication and is not supported in this version.")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        // Update in-memory user immediately; full Supabase profile update
        // goes through ProfileService (to be added when backend profile table is ready)
        if var user = authVM.currentUser {
            user.name = trimmed
            authVM.currentUser = user
        }
        dismiss()
    }
}

// MARK: - Currency picker sheet

private struct CurrencyPickerSheet: View {
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppSettings.supportedCurrencies, id: \.self) { code in
                    Button {
                        onSelect(code)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(code)
                                    .font(AppFont.body).fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                if let name = Locale(identifier: "en_US").localizedString(forCurrencyCode: code) {
                                    Text(name)
                                        .font(AppFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if code == selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: "#1A6B6A"))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Language picker sheet

private struct LanguagePickerSheet: View {
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppSettings.supportedLanguages, id: \.code) { lang in
                    Button {
                        onSelect(lang.code)
                        dismiss()
                    } label: {
                        HStack {
                            Text(lang.name)
                                .font(AppFont.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if lang.code == selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: "#1A6B6A"))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthViewModel())
        .environment(AppSettings.shared)
}
