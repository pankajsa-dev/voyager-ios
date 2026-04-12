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
    @State private var authVM = AuthViewModel()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Group {
            if !authVM.isOnboardingComplete {
                OnboardingView()
                    .environment(authVM)
            } else if !authVM.isAuthenticated {
                AuthView()
                    .environment(authVM)
            } else {
                mainTabs
                    .environment(authVM)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authVM.isOnboardingComplete)
        .animation(.easeInOut(duration: 0.35), value: authVM.isAuthenticated)
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
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:     HomeView()
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
