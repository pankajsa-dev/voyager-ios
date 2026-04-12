import SwiftUI
import Supabase
import AuthenticationServices

// MARK: - App user (lightweight, in-memory)

struct AppUser {
    let id: String
    var name: String
    var email: String
    var avatarURL: String?
}

// MARK: - AuthViewModel

@Observable
final class AuthViewModel {

    // ── Published state ───────────────────────────────────────────────────
    var isAuthenticated: Bool      = false
    var isOnboardingComplete: Bool = false
    var currentUser: AppUser?
    var isLoading: Bool            = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let onboardingDone = "voyager_onboarding_complete"
    }

    // ── Init ──────────────────────────────────────────────────────────────
    init() {
        isOnboardingComplete = defaults.bool(forKey: Keys.onboardingDone)
        // Check for an active Supabase session
        Task { await restoreSession() }
    }

    // ── Onboarding ────────────────────────────────────────────────────────
    func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isOnboardingComplete = true
        }
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    // ── Email sign-up ─────────────────────────────────────────────────────
    func signUp(name: String, email: String, password: String) async {
        guard !name.isEmpty, !email.isEmpty, password.count >= 8 else {
            errorMessage = password.count < 8
                ? "Password must be at least 8 characters."
                : "Please fill in all fields."
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": AnyJSON.string(name)]
            )
            if let user = response.user {
                await MainActor.run {
                    isLoading = false
                    setUser(id: user.id.uuidString, name: name, email: email)
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = friendlyError(error)
            }
        }
    }

    // ── Email login ───────────────────────────────────────────────────────
    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            let name = session.user.userMetadata["full_name"]?.stringValue
                ?? nameFromEmail(email)
            await MainActor.run {
                isLoading = false
                setUser(id: session.user.id.uuidString, name: name, email: email)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = friendlyError(error)
            }
        }
    }

    // ── Sign in with Apple ────────────────────────────────────────────────
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8)
            else { errorMessage = "Apple Sign-In failed."; return }

            Task {
                await MainActor.run { isLoading = true; errorMessage = nil }
                do {
                    let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                        .compactMap { $0 }.joined(separator: " ")
                    let session = try await supabase.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: tokenString)
                    )
                    await MainActor.run {
                        isLoading = false
                        setUser(
                            id: session.user.id.uuidString,
                            name: name.isEmpty ? "Voyager User" : name,
                            email: session.user.email ?? ""
                        )
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = friendlyError(error)
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // ── Sign out ──────────────────────────────────────────────────────────
    func signOut() {
        Task {
            try? await supabase.auth.signOut()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAuthenticated = false
                    currentUser = nil
                }
            }
        }
    }

    // ── Restore session on launch ─────────────────────────────────────────
    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            let name = session.user.userMetadata["full_name"]?.stringValue
                ?? nameFromEmail(session.user.email ?? "")
            await MainActor.run {
                setUser(
                    id: session.user.id.uuidString,
                    name: name,
                    email: session.user.email ?? ""
                )
            }
        } catch {
            // No active session — user needs to log in
            await MainActor.run { isAuthenticated = false }
        }
    }

    // ── Reset (debug / dev) ───────────────────────────────────────────────
    func resetAll() {
        Task { try? await supabase.auth.signOut() }
        defaults.removeObject(forKey: Keys.onboardingDone)
        withAnimation {
            isOnboardingComplete = false
            isAuthenticated = false
            currentUser = nil
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────
    private func setUser(id: String, name: String, email: String) {
        currentUser = AppUser(id: id, name: name, email: email)
        isAuthenticated = true
    }

    private func nameFromEmail(_ email: String) -> String {
        email.components(separatedBy: "@").first?.capitalized ?? "Traveller"
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login")   { return "Incorrect email or password." }
        if msg.contains("already registered") { return "An account with this email already exists." }
        if msg.contains("network")         { return "No internet connection. Please try again." }
        return "Something went wrong. Please try again."
    }
}
