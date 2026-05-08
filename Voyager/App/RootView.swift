import SwiftUI

// MARK: - App tabs

enum AppTab: Int, CaseIterable {
    case home      = 0
    case explore   = 1
    case trips     = 2
    case bookings  = 3
    case profile   = 4

    var title: String {
        switch self {
        case .home:     return "Home"
        case .explore:  return "Explore"
        case .trips:    return "Trips"
        case .bookings: return "Bookings"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .explore:  return "safari.fill"
        case .trips:    return "map.fill"
        case .bookings: return "ticket.fill"
        case .profile:  return "person.fill"
        }
    }
}

// MARK: - Root view (auth gate)

struct RootView: View {
    @State private var authVM          = AuthViewModel()
    @State private var appSettings     = AppSettings.shared
    @State private var selectedTab: AppTab = .home

    // Deep-link state for trip invites (voyager://join?token=...)
    // NOTE: Add "voyager" to URL Types in Xcode → Target → Info → URL Types
    @State private var pendingInviteToken: String?
    @State private var tripServiceForInvite = TripService()

    var body: some View {
        Group {
            if authVM.isRestoringSession {
                launchScreen
            } else if !authVM.isOnboardingComplete {
                OnboardingView()
                    .environment(authVM)
            } else if !authVM.isAuthenticated {
                AuthView()
                    .environment(authVM)
            } else {
                mainTabs
                    .environment(authVM)
                    .environment(appSettings)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authVM.isRestoringSession)
        .animation(.easeInOut(duration: 0.35), value: authVM.isOnboardingComplete)
        .animation(.easeInOut(duration: 0.35), value: authVM.isAuthenticated)
        // ── Deep link handler ──────────────────────────────────────────────
        .onOpenURL { url in
            guard authVM.isAuthenticated,
                  url.scheme == "voyager",
                  url.host   == "join",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let token = components.queryItems?.first(where: { $0.name == "token" })?.value
            else { return }
            pendingInviteToken = token
        }
        .sheet(isPresented: Binding(
            get: { pendingInviteToken != nil && authVM.isAuthenticated },
            set: { if !$0 { pendingInviteToken = nil } }
        )) {
            if let token = pendingInviteToken {
                JoinTripView(token: token, tripService: tripServiceForInvite) { _ in
                    pendingInviteToken = nil
                    selectedTab = .trips
                }
            }
        }
    }

    private var launchScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Voyager")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Main tab bar

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
        .tint(Color(hex: "#1A6B6A"))
        // Keep the shared TripService in sync whenever we switch to the Trips tab
        .onChange(of: selectedTab) { _, tab in
            if tab == .trips {
                Task { await tripServiceForInvite.fetchAll() }
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:     HomeView(selectedTab: $selectedTab)
        case .explore:  ExploreView()
        case .trips:    TripsView()
        case .bookings: BookingsView()
        case .profile:  ProfileView()
        }
    }
}

#Preview {
    RootView()
}
