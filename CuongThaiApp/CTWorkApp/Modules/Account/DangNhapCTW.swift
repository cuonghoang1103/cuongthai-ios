import SwiftUI
import AuthenticationServices

// MARK: - Đồng ý quy tắc cộng đồng (App Store 1.2 — điều khoản trước khi xem/đăng nội dung)

struct DongYQuyTacCTW: View {
    let dongY: () -> Void
    @State private var tamPhu: TrangPhapLyCTW?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image("LogoCTWork").resizable().scaledToFit().frame(width: 84, height: 84)
                    .padding(.top, Spacing.xl)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text("Welcome to CT Work").font(.ctw(size: 26, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    Text("Plan, track and discuss your team's work.")
                        .font(.ctw(size: 15)).foregroundColor(AppColors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Community rules").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    dong("hand.raised.fill", "No harassment, threats, hate speech or sexual content in comments, chat or files.")
                    dong("flag.fill", "Every comment and message can be reported. Reported content is hidden for you right away and reviewed by moderators within 24 hours.")
                    dong("person.crop.circle.badge.xmark", "You can block any user — you won't see their comments or messages anymore.")
                    dong("sparkles", "Some workspace members can be AI agents. Their content is always labelled “AI agent” and can be reported like any other.")
                    dong("exclamationmark.shield.fill", "Accounts that break these rules are removed.")
                }
                .padding(Spacing.lg)
                .ctwThe(16)
                HStack(spacing: Spacing.md) {
                    Button("Terms of Use") { tamPhu = .dieuKhoan }
                    Text("·").foregroundColor(AppColors.textTertiary)
                    Button("Privacy Policy") { tamPhu = .baoMat }
                }
                .font(.footnote)
                Button(action: dongY) {
                    Text("I agree").font(.ctw(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .sheet(item: $tamPhu) { t in NavigationStack { TrangPhapLyView(trang: t) } }
    }

    private func dong(_ icon: String, _ chu: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 24)
            Text(chu).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Đăng nhập / tạo tài khoản

struct DangNhapCTW: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var cheDo

    enum CheDo: String, CaseIterable, Identifiable {
        case dangNhap = "Sign in", dangKy = "Create account"
        var id: String { rawValue }
    }

    @State private var cheDoForm: CheDo = .dangNhap
    @State private var ten = ""
    @State private var email = ""
    @State private var hoTen = ""
    @State private var matKhau = ""
    @State private var dangGui = false
    @State private var loi: String?
    @State private var tamPhu: TrangPhapLyCTW?
    /// Bước xác thực email (mã 6 số) — máy chủ CHẶN đăng nhập khi email chưa
    /// xác thực (`EMAIL_NOT_VERIFIED`), nên đăng ký xong phải nhập mã ngay.
    @State private var xacThuc: XacThucEmail?
    @Environment(\.openURL) private var moURL
    @FocusState private var o: O?
    enum O { case ten, email, hoTen, matKhau }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: 10) {
                    Image("LogoCTWork").resizable().scaledToFit().frame(width: 76, height: 76)
                        .accessibilityHidden(true)
                    Text("CT Work").font(.ctw(size: 30, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    Text("Sign in with your cuongthai.com account")
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, Spacing.xl)

                Picker("Mode", selection: $cheDoForm) {
                    ForEach(CheDo.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }

                VStack(spacing: 0) {
                    o("Username", text: $ten, kieu: .ten)
                        .textContentType(.username)
                    if cheDoForm == .dangKy {
                        Divider()
                        o("Email", text: $email, kieu: .email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                        Divider()
                        o("Full name (optional)", text: $hoTen, kieu: .hoTen)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }
                    Divider()
                    SecureField("Password", text: $matKhau)
                        .textContentType(cheDoForm == .dangKy ? .newPassword : .password)
                        .focused($o, equals: .matKhau)
                        .submitLabel(.go)
                        .onSubmit { Task { await gui() } }
                        .padding(.horizontal, 14).frame(minHeight: 50)
                }
                .ctwThe(14)

                Button { Task { await gui() } } label: {
                    Group {
                        if dangGui { ProgressView().tint(.white) } else { Text(cheDoForm.rawValue) }
                    }
                    .font(.ctw(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(dangGui || !hopLe)

                if cheDoForm == .dangKy {
                    Text("Password: at least 12 characters with an uppercase letter, a lowercase letter, a number and a symbol.")
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button("Forgot password?") {
                        if let u = URL(string: APIClient.diaChiGoc + "/forgot-password") { moURL(u) }
                    }
                    .font(.footnote)
                }

                HStack {
                    Rectangle().fill(AppColors.divider).frame(height: 0.5)
                    Text("or").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    Rectangle().fill(AppColors.divider).frame(height: 0.5)
                }

                // 4.8: lựa chọn đăng nhập riêng tư của Apple.
                SignInWithAppleButton(.continue) { r in
                    r.requestedScopes = [.fullName, .email]
                } onCompletion: { kq in
                    Task { await apple(kq) }
                }
                .signInWithAppleButtonStyle(cheDo == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(cheDoForm == .dangKy
                     ? "By creating an account you agree to the Terms of Use and Privacy Policy."
                     : "New here? Create an account, or continue with Apple.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                HStack(spacing: Spacing.md) {
                    Button("Terms of Use") { tamPhu = .dieuKhoan }
                    Text("·").foregroundColor(AppColors.textTertiary)
                    Button("Privacy Policy") { tamPhu = .baoMat }
                    Text("·").foregroundColor(AppColors.textTertiary)
                    Button("Help") { tamPhu = .troGiup }
                }
                .font(.footnote)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            // Gắn trên khối TRONG (không cùng chỗ với `.sheet` ở ngoài — bẫy C5).
            .fullScreenCover(item: $xacThuc) { x in
                XacThucEmailCTW(email: x.email, tokenCho: x.token) { tk in
                    xacThuc = nil
                    if let tk { app.login(token: tk.token, refreshToken: tk.refreshToken) }
                    else { cheDoForm = .dangNhap; loi = "Email verified. Please sign in." }
                } huy: { xacThuc = nil }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .sheet(item: $tamPhu) { t in NavigationStack { TrangPhapLyView(trang: t) } }
    }

    private func o(_ nhan: String, text: Binding<String>, kieu: O) -> some View {
        TextField(nhan, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($o, equals: kieu)
            .padding(.horizontal, 14).frame(minHeight: 50)
    }

    private var hopLe: Bool {
        let t = ten.trimmingCharacters(in: .whitespaces)
        if cheDoForm == .dangNhap { return !t.isEmpty && !matKhau.isEmpty }
        return t.count >= 3 && email.contains("@") && matKhau.count >= 12
    }

    private func gui() async {
        guard hopLe, !dangGui else { return }
        dangGui = true
        loi = nil
        defer { dangGui = false }
        let t = ten.trimmingCharacters(in: .whitespaces)
        do {
            let res: AuthResponse
            if cheDoForm == .dangKy {
                res = try await APIClient.shared.request(.register(
                    username: t, email: email.trimmingCharacters(in: .whitespaces), password: matKhau,
                    fullName: hoTen.trimmingCharacters(in: .whitespaces).isEmpty ? nil : hoTen, captchaToken: nil))
            } else {
                res = try await APIClient.shared.request(.login(username: t, password: matKhau, captchaToken: nil))
            }
            matKhau = ""
            if cheDoForm == .dangKy {
                xacThuc = XacThucEmail(email: email.trimmingCharacters(in: .whitespaces), token: res)
            } else {
                app.login(token: res.token, refreshToken: res.refreshToken)
            }
        } catch APIError.coMa(let ma, _) where ma == "EMAIL_NOT_VERIFIED" {
            xacThuc = XacThucEmail(email: t.contains("@") ? t : "", token: nil)
        } catch {
            loi = Self.cauLoi(error)
        }
    }

    private func apple(_ kq: Result<ASAuthorization, Error>) async {
        switch kq {
        case .success(let a):
            guard let c = a.credential as? ASAuthorizationAppleIDCredential else { return }
            dangGui = true
            defer { dangGui = false }
            do {
                let res = try await AppleSignInService.authenticate(with: c)
                app.login(token: res.token, refreshToken: res.refreshToken)
            } catch AppleSignInError.noEmail {
                loi = "Apple didn't share an email address. Go to Settings › Apple ID › Sign in with Apple › CT Work › Stop Using, then try again."
            } catch {
                loi = Self.cauLoi(error)
            }
        case .failure(let e):
            if (e as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            loi = "Sign in with Apple didn't complete. Please try again."
        }
    }

    /// Lỗi đăng nhập của máy chủ có thể là tiếng Việt (app chính) — app này
    /// chỉ tiếng Anh, nên dịch những câu hay gặp.
    static func cauLoi(_ e: Error) -> String {
        let goc = CTW.loi(e)
        let thap = goc.lowercased()
        if thap.contains("sai tên đăng nhập") || thap.contains("mật khẩu") || thap.contains("invalid credentials") {
            return "Incorrect username or password."
        }
        if thap.contains("đã tồn tại") || thap.contains("already") { return "That username or email is already in use." }
        if thap.contains("khoá") || thap.contains("locked") || thap.contains("banned") { return "This account is locked. Contact support." }
        if goc.unicodeScalars.contains(where: { $0.value > 0x2FF }) { return "Couldn't sign in. Please check your details and try again." }
        return goc
    }
}


// MARK: - Xác thực email bằng mã 6 số (`/auth/verify-email-otp`, `/auth/resend-otp`)

struct XacThucEmail: Identifiable {
    var email: String
    var token: AuthResponse?
    var id: String { email }
}

struct XacThucEmailCTW: View {
    let email: String
    let tokenCho: AuthResponse?
    let xong: (AuthResponse?) -> Void
    let huy: () -> Void

    @State private var emailNhap = ""
    @State private var ma = ""
    @State private var dangGui = false
    @State private var loi: String?
    @State private var thongBao: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("We emailed a 6-digit code to verify your address. Enter it below to finish.")
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                if let loi { Section { CTWErrorBanner(text: loi) } }
                Section {
                    TextField("Email", text: $emailNhap)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textContentType(.emailAddress)
                    TextField("6-digit code", text: $ma)
                        .keyboardType(.numberPad).textContentType(.oneTimeCode)
                        .font(.ctw(size: 20, weight: .semibold, design: .monospaced))
                } footer: {
                    if let thongBao { Text(thongBao) }
                }
                Section {
                    Button { Task { await xacNhan() } } label: {
                        HStack { Spacer(); if dangGui { ProgressView() } else { Text("Verify").bold() }; Spacer() }
                    }
                    .disabled(dangGui || ma.filter(\.isNumber).count != 6 || !emailNhap.contains("@"))
                    Button("Send a new code") { Task { await guiLai() } }
                        .disabled(dangGui || !emailNhap.contains("@"))
                }
            }
            .navigationTitle("Verify your email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: huy) } }
            .onAppear { if emailNhap.isEmpty { emailNhap = email } }
        }
    }

    private func xacNhan() async {
        dangGui = true
        loi = nil
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(.tuyChinh(duong: "/api/v1/auth/verify-email-otp", phuongThuc: "POST",
                                                      than: ["email": emailNhap.trimmingCharacters(in: .whitespaces),
                                                             "code": ma.filter(\.isNumber)]))
            xong(tokenCho)
        } catch {
            loi = "That code didn't work. Check it, or send a new one."
        }
    }

    private func guiLai() async {
        dangGui = true
        defer { dangGui = false }
        _ = try? await APIClient.shared.send(.tuyChinh(duong: "/api/v1/auth/resend-otp", phuongThuc: "POST",
                                                       than: ["email": emailNhap.trimmingCharacters(in: .whitespaces)]))
        thongBao = "If that address needs verifying, a new code is on its way."
    }
}
