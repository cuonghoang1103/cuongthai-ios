import SwiftUI

// MARK: - Auth View
struct AuthView: View {
    @State private var isLoginMode = true
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var legalSheet: LegalSheet?

    enum LegalSheet: String, Identifiable {
        case terms, privacy
        var id: String { rawValue }
    }

    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        logoSection
                        tabSelector
                        formFields
                        if let error = errorMessage {
                            errorLabel(error)
                        }
                        submitButton
                        dividerRow
                        // Guideline 4.8 — a privacy-preserving login option.
                        AppleSignInButton(
                            onSignedIn: { res in
                                appState.login(token: res.token, refreshToken: res.refreshToken)
                            },
                            onError: { message in errorMessage = message }
                        )
                        .padding(.horizontal, Spacing.lg)
                        legalNotice
                    }
                }
            }
            .sheet(item: $legalSheet) { sheet in
                NavigationStack {
                    switch sheet {
                    case .terms: TermsView(dismissible: true)
                    case .privacy: PrivacyPolicyView(dismissible: true)
                    }
                }
            }
        }
    }

    private var logoSection: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.35, blue: 0.96),
                        Color(red: 0.02, green: 0.71, blue: 0.83)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            Text("CuongThai")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text("Kết nối và chia sẻ")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.top, Spacing.xxl)
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button { withAnimation { isLoginMode = true } } label: {
                Text("Đăng nhập")
                    .font(.buttonText)
                    .foregroundColor(isLoginMode ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(isLoginMode ? Color(red: 0.55, green: 0.35, blue: 0.96).opacity(0.2) : Color.clear)
                    .cornerRadius(CornerRadius.medium)
            }
            Button { withAnimation { isLoginMode = false } } label: {
                Text("Đăng ký")
                    .font(.buttonText)
                    .foregroundColor(!isLoginMode ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(!isLoginMode ? Color(red: 0.55, green: 0.35, blue: 0.96).opacity(0.2) : Color.clear)
                    .cornerRadius(CornerRadius.medium)
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.14))
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.lg)
    }

    private var formFields: some View {
        VStack(spacing: Spacing.md) {
            if !isLoginMode {
                AuthTextField(icon: "person", placeholder: "Họ và tên", text: $fullName)
            }
            AuthTextField(icon: "at", placeholder: "Tên đăng nhập", text: $username)
            if !isLoginMode {
                AuthTextField(icon: "envelope", placeholder: "Email", text: $email)
            }
            AuthTextField(icon: "lock", placeholder: "Mật khẩu", text: $password, isSecure: true)
            if !isLoginMode {
                AuthTextField(icon: "lock", placeholder: "Xác nhận mật khẩu", text: $confirmPassword, isSecure: true)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func errorLabel(_ error: String) -> some View {
        Text(error)
            .font(.caption)
            .foregroundColor(Color(red: 0.94, green: 0.27, blue: 0.27))
            .padding(.horizontal, Spacing.lg)
    }

    private var submitButton: some View {
        Button { Task { await submit() } } label: {
            HStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(isLoginMode ? "Đăng nhập" : "Tạo tài khoản")
                        .font(.buttonText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.35, blue: 0.96),
                    Color(red: 0.02, green: 0.71, blue: 0.83)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .foregroundColor(.white)
            .cornerRadius(CornerRadius.medium)
        }
        .disabled(isLoading || !isFormValid)
        .opacity(isFormValid ? 1 : 0.6)
        .padding(.horizontal, Spacing.lg)
    }

    private var dividerRow: some View {
        HStack(spacing: Spacing.md) {
            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
            Text("hoặc")
                .font(.caption)
                .foregroundColor(.gray)
            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var legalNotice: some View {
        VStack(spacing: Spacing.xs) {
            Text("Khi tiếp tục, bạn đồng ý với Điều khoản sử dụng và Chính sách bảo mật.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.md) {
                Button("Điều khoản") { legalSheet = .terms }
                Button("Bảo mật") { legalSheet = .privacy }
            }
            .font(.caption)
            .foregroundColor(AppColors.primary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    private var isFormValid: Bool {
        if isLoginMode {
            return !username.isEmpty && !password.isEmpty
        }
        return !username.isEmpty && !email.isEmpty && !password.isEmpty && password == confirmPassword
    }

    private func submit() async {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            if isLoginMode {
                let res: AuthResponse = try await APIClient.shared.request(
                    .login(username: username, password: password, captchaToken: nil)
                )
                appState.login(token: res.token, refreshToken: res.refreshToken)
            } else {
                let _: EmptyResponse = try await APIClient.shared.request(
                    .register(username: username, email: email, password: password, fullName: fullName.isEmpty ? nil : fullName, captchaToken: nil)
                )
                let res: AuthResponse = try await APIClient.shared.request(
                    .login(username: username, password: password, captchaToken: nil)
                )
                appState.login(token: res.token, refreshToken: res.refreshToken)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Auth TextField
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(Color(red: 0.1, green: 0.1, blue: 0.14))
        .cornerRadius(CornerRadius.medium)
    }
}
