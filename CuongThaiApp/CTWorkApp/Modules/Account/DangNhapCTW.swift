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
                    // 1.2 (build 7, audit R7): nói THẲNG "zero tolerance" + phủ bài đăng, bình luận, tin nhắn, hồ sơ.
                    dong("exclamationmark.shield.fill", "There is zero tolerance for objectionable content and abusive users — in posts, comments, messages and profiles.")
                    dong("hand.raised.fill", "No harassment, threats, hate speech, sexual or violent content, or spam — in posts, comments, chat and direct messages, files or profiles.")
                    dong("flag.fill", "Every post, comment, message and profile can be reported. Reported content is hidden for you right away and reviewed by moderators within 24 hours.")
                    dong("person.crop.circle.badge.xmark", "You can block any user — you won't see their posts, comments or messages anymore, and they can't message you.")
                    dong("sparkles", "Some workspace members can be AI agents. Their content is always labelled “AI agent” and can be reported like any other.")
                    dong("xmark.octagon.fill", "Content that breaks these rules is removed, and the users who post it are suspended or banned.")
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

    private func dong(_ icon: String, _ chu: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 24)
            Text(chu).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Đăng nhập / tạo tài khoản
//
// 21/10/2026 — giao diện mới kiểu "hero + tấm trượt lên" (vỏ dùng chung: Shared/ChuyenDong/GiaoDienDangNhap.swift):
// hero là linh vật CT Work vẽ bằng Path + vài thẻ việc lơ lửng; tấm trắng có ô nhập viền chạy quanh khi chạm,
// nút viên thuốc, "Ghi nhớ tên đăng nhập", "Quên mật khẩu?", Sign in with Apple; bấm gửi ⇒ nền mờ + linh vật
// tích việc + "Đang đăng nhập…"; lỗi ⇒ tấm lắc + băng lỗi. LOGIC GIỮ NGUYÊN: cùng `gui()` (login/register),
// cùng `apple(_:)`, cùng `cauLoi`, cùng bước xác thực email — chỉ đổi phần vẽ. Chế độ đăng ký chuyển bằng liên kết
// "Chưa có tài khoản? Đăng ký" ở cuối tấm (thay bộ chọn phân đoạn cũ).

struct DangNhapCTW: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var cheDo

    enum CheDo: String, CaseIterable, Identifiable {
        case dangNhap = "Sign in", dangKy = "Create account"
        var id: String { rawValue }
        var ten: String { self == .dangNhap ? String(localized: "Sign in") : String(localized: "Create account") }
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
    /// Tăng mỗi lần lỗi ⇒ tấm form lắc.
    @State private var lanLac = 0
    /// Ghi nhớ TÊN ĐĂNG NHẬP cho lần sau (phiên đăng nhập vốn đã giữ trong Keychain — công tắc này không đổi điều đó).
    @AppStorage("ctw.dangNhap.nhoTen") private var nhoTen = true
    @AppStorage("ctw.dangNhap.tenDaNho") private var tenDaNho = ""
    @Environment(\.openURL) private var moURL
    @FocusState private var o: O?
    enum O { case ten, email, hoTen, matKhau }

    /// Lớp "Đang đăng nhập…" hiện ít nhất chừng này — máy chủ trả nhanh thì lớp không loé rồi tắt.
    static let choToiThieu: TimeInterval = 0.9

    private var mauNut: LinearGradient {
        LinearGradient(colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        BoCucDangNhap(
            nenHero: AnyShapeStyle(LinearGradient(
                colors: cheDo == .dark
                    ? [Color(red: 0.13, green: 0.14, blue: 0.30), Color(red: 0.06, green: 0.20, blue: 0.22)]
                    : [Color(red: 0.89, green: 0.90, blue: 1.0), Color(red: 0.86, green: 0.96, blue: 0.95)],
                startPoint: .topLeading, endPoint: .bottomTrailing)),
            dangGo: o != nil,
            cuonToi: o.map { AnyHashable("o-\($0)") },
            dangDangNhap: dangGui,
            lanLac: lanLac,
            hero: { gon in HeroDangNhapCTW(gon: gon) },
            tam: { tam },
            lopCho: {
                LopDangDangNhap(chu: cheDoForm == .dangKy ? String(localized: "Creating your account…") : String(localized: "Signing you in…"),
                                mau: mauNut) {
                    LinhVatTichViecCTW().frame(width: 104, height: 104)
                }
            })
        // Gắn trên khối TRONG (không cùng chỗ với `.sheet` — bẫy C5).
        .fullScreenCover(item: $xacThuc) { x in
            XacThucEmailCTW(email: x.email, tokenCho: x.token) { tk in
                xacThuc = nil
                if let tk { app.login(token: tk.token, refreshToken: tk.refreshToken) }
                else { cheDoForm = .dangNhap; loi = String(localized: "Email verified. Please sign in.") }
            } huy: { xacThuc = nil }
        }
        .background(Color.clear.sheet(item: $tamPhu) { t in NavigationStack { TrangPhapLyView(trang: t) } })
        .onAppear { if nhoTen, ten.isEmpty { ten = tenDaNho } }
        #if DEBUG
        .task { await tuChayThu() }
        #endif
    }

    #if DEBUG
    /// Màn thử `CT_XEM_TU_CHAY=1` (chỉ DEBUG, cùng máy chủ giả `CT_XEM_MAN=dangnhap`): tự gõ tên + mật khẩu SAI ⇒ lỗi + lắc,
    /// rồi mật khẩu đúng ⇒ vào My Work — để quay video cả luồng bằng `simctl` (không có ngón tay nào gõ được).
    private func tuChayThu() async {
        guard ProcessInfo.processInfo.environment["CT_XEM_TU_CHAY"] == "1" else { return }
        func ngu(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        while KhoiDongChung.shared.dangChieu { await ngu(0.1) }
        await ngu(1.0)
        func go(_ chu: String, vao o: O, _ gan: (String) -> Void) async {
            self.o = o
            await ngu(0.45)
            var da = ""
            for c in chu { da.append(c); gan(da); await ngu(0.07) }
        }
        await go("alex", vao: .ten) { ten = $0 }
        await go("wrong", vao: .matKhau) { matKhau = $0 }
        await ngu(0.5)
        await gui()
        await ngu(1.6)
        await go("secret-pass", vao: .matKhau) { matKhau = $0 }
        await ngu(0.5)
        await gui()
    }
    #endif

    // MARK: Tấm form

    private var tam: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(cheDoForm == .dangKy ? String(localized: "Create your account") : String(localized: "Welcome back"))
                    .font(.ctw(size: 28, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(cheDoForm == .dangKy ? String(localized: "One account for CT Work and cuongthai.com.") : String(localized: "Sign in with your cuongthai.com account"))
                    .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            }
            .id(cheDoForm)
            .transition(.opacity)

            if let loi { CTWErrorBanner(text: loi) { self.loi = nil }.transition(.opacity.combined(with: .move(edge: .top))) }

            VStack(spacing: 12) {
                ODangNhap(bieuTuong: "person", goiY: String(localized: "Username"), chu: $ten, tapTrung: $o, gia: .ten,
                          maDinhDanh: "dangNhap.ten")
                    .textContentType(.username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { o = cheDoForm == .dangKy ? .email : .matKhau }
                    .id(AnyHashable("o-\(O.ten)"))
                if cheDoForm == .dangKy {
                    ODangNhap(bieuTuong: "envelope", goiY: String(localized: "Email"), chu: $email, tapTrung: $o, gia: .email,
                              maDinhDanh: "dangNhap.email")
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { o = .hoTen }
                        .id(AnyHashable("o-\(O.email)"))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    ODangNhap(bieuTuong: "person.text.rectangle", goiY: String(localized: "Full name (optional)"), chu: $hoTen,
                              tapTrung: $o, gia: .hoTen, maDinhDanh: "dangNhap.hoTen")
                        .textContentType(.name).textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit { o = .matKhau }
                        .id(AnyHashable("o-\(O.hoTen)"))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ODangNhap(bieuTuong: "lock", goiY: String(localized: "Password"), chu: $matKhau, an: true, tapTrung: $o, gia: .matKhau,
                          nhanHien: String(localized: "Show password"), nhanAn: String(localized: "Hide password"),
                          maDinhDanh: "dangNhap.matKhau")
                    .textContentType(cheDoForm == .dangKy ? .newPassword : .password)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { Task { await gui() } }
                    .id(AnyHashable("o-\(O.matKhau)"))
            }

            if cheDoForm == .dangKy {
                Text("Password: at least 12 characters with an uppercase letter, a lowercase letter, a number and a symbol.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    OTich(nhan: String(localized: "Remember username"), bat: $nhoTen)
                    Spacer(minLength: 4)
                    Button("Forgot password?") {
                        if let u = URL(string: APIClient.diaChiGoc + "/forgot-password") { moURL(u) }
                    }
                    .font(.ctw(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                }
            }

            NutVienThuoc(nhan: cheDoForm.ten, nen: mauNut, dangChay: dangGui, bat: hopLe, maDinhDanh: "dangNhap.gui") {
                Task { await gui() }
            }
            .shadow(color: AppColors.primary.opacity(hopLe ? 0.32 : 0), radius: 14, y: 7)
            .padding(.top, 2)

            HStack(spacing: 10) {
                Rectangle().fill(AppColors.divider).frame(height: 0.5)
                Text("or continue with").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).fixedSize()
                Rectangle().fill(AppColors.divider).frame(height: 0.5)
            }

            // 4.8: lựa chọn đăng nhập riêng tư của Apple.
            SignInWithAppleButton(.continue) { r in
                r.requestedScopes = [.fullName, .email]
            } onCompletion: { kq in
                Task { await apple(kq) }
            }
            .signInWithAppleButtonStyle(cheDo == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(Capsule())

            HStack(spacing: 4) {
                Text(cheDoForm == .dangKy ? String(localized: "Already have an account?") : String(localized: "Don't have an account?"))
                    .foregroundColor(AppColors.textSecondary)
                Button(cheDoForm == .dangKy ? String(localized: "Sign in") : String(localized: "Sign up")) { doiCheDo() }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
                    .accessibilityIdentifier("dangNhap.doiCheDo")
            }
            .font(.ctw(size: 14))
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                if cheDoForm == .dangKy {
                    Text("By creating an account you agree to the Terms of Use and Privacy Policy.")
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: Spacing.md) {
                    Button("Terms of Use") { tamPhu = .dieuKhoan }
                    Text("·").foregroundColor(AppColors.textTertiary)
                    Button("Privacy Policy") { tamPhu = .baoMat }
                    Text("·").foregroundColor(AppColors.textTertiary)
                    Button("Help") { tamPhu = .troGiup }
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.snappy(duration: 0.28), value: cheDoForm)
        .animation(.easeOut(duration: 0.2), value: loi)
    }

    private func doiCheDo() {
        RungNhe.cham()
        withAnimation(.snappy(duration: 0.28)) {
            cheDoForm = cheDoForm == .dangKy ? .dangNhap : .dangKy
            loi = nil
        }
    }

    private var hopLe: Bool {
        let t = ten.trimmingCharacters(in: .whitespaces)
        if cheDoForm == .dangNhap { return !t.isEmpty && !matKhau.isEmpty }
        return t.count >= 3 && email.contains("@") && matKhau.count >= 12
    }

    /// Lỗi ⇒ tấm lắc + rung + băng lỗi.
    private func baoLoi(_ chu: String) {
        loi = chu
        lanLac += 1
        RungNhe.loi()
    }

    /// Giữ lớp "Đang đăng nhập…" đủ lâu để đọc được (chỉ là thời gian hiển thị — không đổi luồng xác thực).
    private func doiToiThieu(tu batDau: Date) async {
        let con = Self.choToiThieu - Date().timeIntervalSince(batDau)
        if con > 0 { try? await Task.sleep(nanoseconds: UInt64(con * 1_000_000_000)) }
    }

    private func gui() async {
        guard hopLe, !dangGui else { return }
        o = nil
        dangGui = true
        loi = nil
        defer { dangGui = false }
        let batDau = Date()
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
            tenDaNho = nhoTen ? t : ""
            await doiToiThieu(tu: batDau)
            if cheDoForm == .dangKy {
                xacThuc = XacThucEmail(email: email.trimmingCharacters(in: .whitespaces), token: res)
            } else {
                RungNhe.xong()
                app.login(token: res.token, refreshToken: res.refreshToken)
            }
        } catch APIError.coMa(let ma, _) where ma == "EMAIL_NOT_VERIFIED" {
            xacThuc = XacThucEmail(email: t.contains("@") ? t : "", token: nil)
        } catch {
            await doiToiThieu(tu: batDau)
            baoLoi(Self.cauLoi(error))
        }
    }

    private func apple(_ kq: Result<ASAuthorization, Error>) async {
        switch kq {
        case .success(let a):
            guard let c = a.credential as? ASAuthorizationAppleIDCredential else { return }
            dangGui = true
            defer { dangGui = false }
            let batDau = Date()
            do {
                let res = try await AppleSignInService.authenticate(with: c)
                await doiToiThieu(tu: batDau)
                RungNhe.xong()
                app.login(token: res.token, refreshToken: res.refreshToken)
            } catch AppleSignInError.noEmail {
                baoLoi(String(localized: "Apple didn't share an email address. Go to Settings › Apple ID › Sign in with Apple › CT Work › Stop Using, then try again."))
            } catch {
                baoLoi(Self.cauLoi(error))
            }
        case .failure(let e):
            if (e as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            baoLoi(String(localized: "Sign in with Apple didn't complete. Please try again."))
        }
    }

    /// Lỗi đăng nhập của máy chủ có thể là tiếng Việt (app chính) — app này
    /// chỉ tiếng Anh, nên dịch những câu hay gặp.
    static func cauLoi(_ e: Error) -> String {
        let goc = CTW.loi(e)
        let thap = goc.lowercased()
        if thap.contains("sai tên đăng nhập") || thap.contains("mật khẩu") || thap.contains("invalid credentials") {
            return String(localized: "Incorrect username or password.")
        }
        if thap.contains("đã tồn tại") || thap.contains("already") { return String(localized: "That username or email is already in use.") }
        if thap.contains("khoá") || thap.contains("locked") || thap.contains("banned") { return String(localized: "This account is locked. Contact support.") }
        if goc.unicodeScalars.contains(where: { $0.value > 0x2FF }) { return String(localized: "Couldn't sign in. Please check your details and try again.") }
        return goc
    }
}

// MARK: Hero — linh vật + thẻ việc lơ lửng

struct HeroDangNhapCTW: View {
    let gon: Bool
    @Environment(\.colorScheme) private var cheDo
    @Environment(\.accessibilityReduceMotion) private var giam

    var body: some View {
        GeometryReader { g in
            let co = gon ? min(84, g.size.height * 0.62) : min(150, g.size.height * 0.6)
            let cx = g.size.width * 0.56
            // Chip không bao giờ tràn mép màn (iPhone hẹp): kẹp tâm trong [74, rộng − 74].
            let kep = { (x: CGFloat) in min(max(x, 74), g.size.width - 74) }
            ZStack {
                // Quầng mềm sau linh vật.
                Circle().fill(Color.white.opacity(cheDo == .dark ? 0.06 : 0.55))
                    .frame(width: co * 1.7, height: co * 1.7).blur(radius: 30)
                    .position(x: cx, y: g.size.height * 0.56)
                LinhVatCTWView()
                    .frame(width: co, height: co)
                    .shadow(color: AppColors.primary.opacity(0.28), radius: 18, y: 10)
                    .noiLoLung(bienDo: 5, chuKy: 3.6)
                    .position(x: cx, y: g.size.height * 0.56)
                if !gon {
                    ChipNoi(bieuTuong: "checkmark.circle.fill", chu: "NW-12 · Done", mau: Color(red: 0.13, green: 0.6, blue: 0.3))
                        .noiLoLung(bienDo: 7, chuKy: 3.0, lech: 0.25)
                        .position(x: kep(cx - co * 0.98), y: g.size.height * 0.40)
                    ChipNoi(bieuTuong: "flag.fill", chu: "Sprint 6", mau: AppColors.primary)
                        .noiLoLung(bienDo: 6, chuKy: 3.4, lech: 0.6)
                        .position(x: kep(cx + co * 0.85), y: g.size.height * 0.26)
                    ChipNoi(bieuTuong: "arrow.triangle.branch", chu: "In review", mau: Color(red: 0.9, green: 0.5, blue: 0.1))
                        .noiLoLung(bienDo: 6, chuKy: 2.8, lech: 0.1)
                        .position(x: kep(cx + co * 0.7), y: g.size.height * 0.86)
                    Image(systemName: "sparkle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(MauLinhVatCTW.vang)
                        .noiLoLung(bienDo: 4, chuKy: 2.2, lech: 0.4)
                        .position(x: cx - co * 0.62, y: g.size.height * 0.82)
                        .accessibilityHidden(true)
                }
                // Dấu thương hiệu góc trên trái.
                HStack(spacing: 8) {
                    LinhVatCTWView().frame(width: 30, height: 30)
                    Text(verbatim: "CT Work").font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(cheDo == .dark ? .white : Color(red: 0.12, green: 0.13, blue: 0.27))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "CT Work"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 24)
                .padding(.top, 8)
            }
        }
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
            loi = String(localized: "That code didn't work. Check it, or send a new one.")
        }
    }

    private func guiLai() async {
        dangGui = true
        defer { dangGui = false }
        _ = try? await APIClient.shared.send(.tuyChinh(duong: "/api/v1/auth/resend-otp", phuongThuc: "POST",
                                                       than: ["email": emailNhap.trimmingCharacters(in: .whitespaces)]))
        thongBao = String(localized: "If that address needs verifying, a new code is on its way.")
    }
}
