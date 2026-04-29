import SwiftUI
import AuthenticationServices

// MARK: - Auth container (toggles Login ↔ Sign Up)

struct AuthView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var mode: AuthMode = .login

    enum AuthMode { case login, signUp }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Brand mark
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                    Text("Voyager")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(mode == .login ? "Welcome back" : "Create your account")
                        .font(AppFont.body)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, AppSpacing.xxl)
                .padding(.bottom, AppSpacing.xl)

                Spacer()

                // Card
                VStack(spacing: 0) {
                    // Mode toggle
                    AuthModeToggle(mode: $mode)
                        .padding(.top, AppSpacing.lg)
                        .padding(.horizontal, AppSpacing.md)

                    if mode == .login {
                        LoginFormView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal:   .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        SignUpFormView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: mode)
    }
}

// MARK: - Mode toggle (Login / Sign Up pill)

private struct AuthModeToggle: View {
    @Binding var mode: AuthView.AuthMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach([AuthView.AuthMode.login, .signUp], id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.3)) { mode = m }
                } label: {
                    Text(m == .login ? "Sign In" : "Sign Up")
                        .font(AppFont.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            mode == m
                            ? Color(hex: "#1A6B6A")
                            : Color.clear
                        )
                        .foregroundStyle(mode == m ? .white : Color(hex: "#6B7B78"))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Login form

private struct LoginFormView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var email    = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Fields
            VStack(spacing: AppSpacing.sm) {
                AuthTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                AuthSecureField(icon: "lock", placeholder: "Password", text: $password, showPassword: $showPassword)
            }
            .padding(.top, AppSpacing.lg)

            // Forgot password
            HStack {
                Spacer()
                Button("Forgot Password?") {}
                    .font(AppFont.bodySmall)
                    .foregroundStyle(Color(hex: "#2A9D8F"))
            }

            // Error
            if let error = authVM.errorMessage {
                ErrorBanner(message: error)
            }

            // Sign in button
            PrimaryButton(title: "Sign In", isLoading: authVM.isLoading) {
                Task { await authVM.login(email: email, password: password) }
            }

            DividerWithLabel(text: "or continue with")

            VStack(spacing: AppSpacing.sm) {
                AppleSignInButton()
                GoogleSignInButton()
            }

            Spacer(minLength: AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - Sign up form

private struct SignUpFormView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: AppSpacing.sm) {
                AuthTextField(icon: "person", placeholder: "Full Name", text: $name)
                AuthTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                AuthSecureField(icon: "lock", placeholder: "Password (min 8 chars)", text: $password, showPassword: $showPassword)
            }
            .padding(.top, AppSpacing.lg)

            // Error
            if let error = authVM.errorMessage {
                ErrorBanner(message: error)
            }

            // Sign up button
            PrimaryButton(title: "Create Account", isLoading: authVM.isLoading) {
                Task { await authVM.signUp(name: name, email: email, password: password) }
            }

            DividerWithLabel(text: "or continue with")

            VStack(spacing: AppSpacing.sm) {
                AppleSignInButton()
                GoogleSignInButton()
            }

            Text("By signing up you agree to our Terms of Service and Privacy Policy.")
                .font(AppFont.caption)
                .foregroundStyle(Color(hex: "#6B7B78"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Spacer(minLength: AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - Reusable auth components

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Color(hex: "#2A9D8F"))
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Color(hex: "#2A9D8F"))
            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(Color(hex: "#6B7B78"))
            }
        }
        .padding(AppSpacing.md)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(AppFont.body)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#1A6B6A"), Color(hex: "#2A9D8F")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .shadow(color: Color(hex: "#1A6B6A").opacity(0.35), radius: 8, y: 4)
        }
        .disabled(isLoading)
    }
}

struct DividerWithLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5)
            Text(text)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color(hex: "#E05D5D"))
            Text(message)
                .font(AppFont.bodySmall)
                .foregroundStyle(Color(hex: "#E05D5D"))
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(Color(hex: "#E05D5D").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
    }
}

struct AppleSignInButton: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256Nonce(nonce)
        } onCompletion: { result in
            authVM.handleAppleSignIn(result, nonce: currentNonce)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

struct GoogleSignInButton: View {
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        Button {
            Task { await authVM.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                // Google "G" logo using coloured quarter-circles
                GoogleLogo()
                    .frame(width: 20, height: 20)
                Text("Continue with Google")
                    .font(AppFont.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        }
        .disabled(authVM.isLoading)
    }
}

private struct GoogleLogo: View {
    var body: some View {
        Canvas { ctx, size in
            let r = size.width / 2
            let cx = size.width / 2
            let cy = size.height / 2
            let segments: [(Color, Double, Double)] = [
                (.red,   -30,  90),
                (.yellow, 90, 210),
                (.green, 210, 270),
                (.blue,  270, 330),
            ]
            for (color, start, end) in segments {
                let path = Path { p in
                    p.move(to: CGPoint(x: cx, y: cy))
                    p.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: r,
                        startAngle: .degrees(start),
                        endAngle: .degrees(end),
                        clockwise: false
                    )
                    p.closeSubpath()
                }
                ctx.fill(path, with: .color(color))
            }
            // White inner circle (donut)
            let hole = Path(ellipseIn: CGRect(
                x: cx - r * 0.55, y: cy - r * 0.55,
                width: r * 1.1, height: r * 1.1
            ))
            ctx.fill(hole, with: .color(.white))
            // White cutout for the "G" bar
            let bar = Path(CGRect(x: cx, y: cy - r * 0.18, width: r, height: r * 0.36))
            ctx.fill(bar, with: .color(.white))
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthViewModel())
}
