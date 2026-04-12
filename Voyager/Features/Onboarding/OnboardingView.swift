import SwiftUI

// MARK: - Model

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let primaryColor: Color
    let secondaryColor: Color
    let title: String
    let subtitle: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon:         "globe.americas.fill",
        primaryColor:  Color(hex: "#1A6B6A"),
        secondaryColor: Color(hex: "#2A9D8F"),
        title:    "Discover the World",
        subtitle: "Browse thousands of curated destinations across every continent, handpicked for every type of traveller."
    ),
    OnboardingPage(
        icon:         "map.fill",
        primaryColor:  Color(hex: "#C77B2E"),
        secondaryColor: Color(hex: "#E9A84C"),
        title:    "Plan Every Detail",
        subtitle: "Build day-by-day itineraries, add activities, and keep your entire trip perfectly organised."
    ),
    OnboardingPage(
        icon:         "checkmark.seal.fill",
        primaryColor:  Color(hex: "#1A6B6A"),
        secondaryColor: Color(hex: "#52C0B4"),
        title:    "Travel with Confidence",
        subtitle: "Manage bookings, track your budget, and keep your packing list — all in one beautiful app."
    ),
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Animated background gradient
            LinearGradient(
                colors: [
                    pages[currentPage].primaryColor,
                    pages[currentPage].secondaryColor,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(.spring(response: 0.4)) { currentPage = pages.count - 1 }
                        }
                        .font(AppFont.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
                .padding(.top, AppSpacing.sm)

                // Icon area
                Spacer()
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 200, height: 200)
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 240, height: 240)
                    Image(systemName: pages[currentPage].icon)
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: currentPage)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)
                Spacer()

                // Bottom card
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)

                    // Page content
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            VStack(spacing: AppSpacing.md) {
                                Text(page.title)
                                    .font(AppFont.h1)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color(hex: "#1C2827"))

                                Text(page.subtitle)
                                    .font(AppFont.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color(hex: "#6B7B78"))
                                    .lineSpacing(4)
                                    .padding(.horizontal, AppSpacing.lg)
                            }
                            .padding(.top, AppSpacing.lg)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 180)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage
                                      ? pages[currentPage].primaryColor
                                      : Color(hex: "#1C2827").opacity(0.15))
                                .frame(width: i == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.top, AppSpacing.md)

                    // CTA button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4)) { currentPage += 1 }
                        } else {
                            authVM.completeOnboarding()
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(AppFont.body)
                                .fontWeight(.semibold)
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "arrow.right.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [pages[currentPage].primaryColor, pages[currentPage].secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .shadow(color: pages[currentPage].primaryColor.opacity(0.4), radius: 10, y: 4)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                    .animation(.spring(response: 0.3), value: currentPage)
                }
                .padding(.bottom, AppSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color(UIColor.systemBackground))
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50, currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4)) { currentPage += 1 }
                    } else if value.translation.width > 50, currentPage > 0 {
                        withAnimation(.spring(response: 0.4)) { currentPage -= 1 }
                    }
                }
        )
    }
}

#Preview {
    OnboardingView()
        .environment(AuthViewModel())
}
