import SwiftUI
import AuthenticationServices

// Lightweight in-memory user (separate from SwiftData User model)
struct AppUser {
    let id: String
    var name: String
    var email: String
    var avatarURL: String?
}

@Observable
final class AuthViewModel {

    // ── State ──────────────────────────────────────────────────────────────
    var isAuthenticated: Bool = false
    var isOnboardingComplete: Bool = false
    var currentUser: AppUser?
    var isLoading: Bool = false
    var errorMessage: String?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let onboardingDone  = "voyager_onboarding_complete"
        static let isAuthenticated = "voyager_is_authenticated"
        static let userId          = "voyager_user_id"
        static let userName        = "voyager_user_name"
        static let userEmail       = "voyager_user_email"
    }

    init() {
        isOnboardingComplete = defaults.bool(forKey: Keys.onboardingDone)
        isAuthenticated      = defaults.bool(forKey: Keys.isAuthenticated)
        if isAuthenticated {
            currentUser = AppUser(
                id:    defaults.string(forKey: Keys.userId)    ?? UUID().uuidString,
                name:  defaults.string(forKey: Keys.userName)  ?? "",
                email: defaults.string(forKey: Keys.userEmail) ?? ""
            )
        }
    }

    // ── Onboarding ────────────────────────────────────────────────────────
    func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isOnboardingComplete = true
        }
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    // ── Email login ───────────────────────────────────────────────────────
    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }

        // Simulate network call — replace with real API
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        await MainActor.run {
            isLoading = false
            persistUser(id: UUID().uuidString, name: nameFromEmail(email), email: email)
        }
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

        // Simulate network call — replace with real API
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        await MainActor.run {
            isLoading = false
            persistUser(id: UUID().uuidString, name: name, email: email)
        }
    }

    // ── Sign in with Apple ────────────────────────────────────────────────
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let name  = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let email = credential.email ?? defaults.string(forKey: Keys.userEmail) ?? ""
            persistUser(id: credential.user, name: name.isEmpty ? "Voyager User" : name, email: email)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // ── Sign out ──────────────────────────────────────────────────────────
    func signOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAuthenticated = false
            currentUser = nil
        }
        defaults.set(false, forKey: Keys.isAuthenticated)
    }

    // ── Reset onboarding (debug) ──────────────────────────────────────────
    func resetAll() {
        defaults.removeObject(forKey: Keys.onboardingDone)
        defaults.removeObject(forKey: Keys.isAuthenticated)
        isOnboardingComplete = false
        isAuthenticated = false
        currentUser = nil
    }

    // ── Private ───────────────────────────────────────────────────────────
    private func persistUser(id: String, name: String, email: String) {
        let user = AppUser(id: id, name: name, email: email)
        currentUser = user
        isAuthenticated = true
        defaults.set(true,  forKey: Keys.isAuthenticated)
        defaults.set(id,    forKey: Keys.userId)
        defaults.set(name,  forKey: Keys.userName)
        defaults.set(email, forKey: Keys.userEmail)
    }

    private func nameFromEmail(_ email: String) -> String {
        email.components(separatedBy: "@").first?.capitalized ?? "Traveller"
    }
}
