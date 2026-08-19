import SwiftUI

// MARK: - Đăng nhập / Đăng ký

struct AuthView: View {
    @EnvironmentObject var appState: AppState

    @State private var laDangNhap = true
    @State private var tenDangNhap = ""
    @State private var email = ""
    @State private var matKhau = ""
    @State private var xacNhanMatKhau = ""
    @State private var hoTen = ""
    @State private var hienMatKhau = false
    @State private var dangGui = false
    @State private var loi: String?
    @State private var manPhapLy: ManPhapLy?
    @FocusState private var oDangGo: O?

    private enum O: Hashable { case hoTen, tenDangNhap, email, matKhau, xacNhan }

    enum ManPhapLy: String, Identifiable {
        case dieuKhoan, baoMat
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            nenGradient

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    khoiLogo
                    boChonTab
                    cacO
                    if let loi { khoiLoi(loi) }
                    nutChinh
                    if laDangNhap { nutQuenMatKhau }
                    gachNgang
                    AppleSignInButton(
                        onSignedIn: { res in
                            Haptics.xong()
                            appState.login(token: res.token, refreshToken: res.refreshToken)
                        },
                        onError: { thongBao in
                            Haptics.hong()
                            loi = thongBao
                        },
                    )
                    .padding(.horizontal, Spacing.lg)
                    ghiChuPhapLy
                }
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(item: $manPhapLy) { man in
            NavigationStack {
                switch man {
                case .dieuKhoan: TermsView(dismissible: true)
                case .baoMat: PrivacyPolicyView(dismissible: true)
                }
            }
        }
    }

    // MARK: Nền

    /// Hai quầng sáng mờ thay cho nền phẳng. Đặt sau `ignoresSafeArea` nên nó
    /// tràn cả sau thanh trạng thái; `blur` lớn để không thành hai vệt rõ rệt.
    private var nenGradient: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            Circle()
                .fill(AppColors.primary.opacity(0.28))
                .frame(width: 340, height: 340)
                .blur(radius: 110)
                .offset(x: -110, y: -260)
            Circle()
                .fill(AppColors.secondary.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: 130, y: 240)
        }
        .ignoresSafeArea()
    }

    // MARK: Logo

    private var khoiLogo: some View {
        VStack(spacing: Spacing.sm) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppColors.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 1),
                        )
                        .shadow(color: AppColors.primary.opacity(0.35), radius: 24, y: 8),
                )

            Text("CuongThai")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.brandGradient)

            Text(laDangNhap ? "Chào mừng trở lại" : "Tạo tài khoản mới")
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, Spacing.xxl)
    }

    // MARK: Tab

    private var boChonTab: some View {
        HStack(spacing: 4) {
            tab("Đăng nhập", chon: laDangNhap) { doiTab(sangDangNhap: true) }
            tab("Đăng ký", chon: !laDangNhap) { doiTab(sangDangNhap: false) }
        }
        .padding(4)
        .background(AppColors.backgroundSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
        .padding(.horizontal, Spacing.lg)
    }

    private func tab(_ nhan: String, chon: Bool, _ bam: @escaping () -> Void) -> some View {
        Button(action: bam) {
            Text(nhan)
                .font(.buttonText)
                .foregroundColor(chon ? AppColors.onPrimary : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if chon {
                        Capsule().fill(AppColors.brandGradient)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func doiTab(sangDangNhap: Bool) {
        guard laDangNhap != sangDangNhap else { return }
        Haptics.cham()
        withAnimation(.snappy(duration: 0.25)) {
            laDangNhap = sangDangNhap
            loi = nil
        }
    }

    // MARK: Các ô nhập

    private var cacO: some View {
        VStack(spacing: Spacing.md) {
            if !laDangNhap {
                ONhap(icon: "person", nhan: "Họ và tên", chu: $hoTen)
                    .focused($oDangGo, equals: .hoTen)
                    .submitLabel(.next)
                    .onSubmit { oDangGo = .tenDangNhap }
            }

            ONhap(icon: "at", nhan: "Tên đăng nhập", chu: $tenDangNhap)
                .focused($oDangGo, equals: .tenDangNhap)
                .oKhongTuSua()
                .submitLabel(.next)
                .onSubmit { oDangGo = laDangNhap ? .matKhau : .email }

            if !laDangNhap {
                ONhap(icon: "envelope", nhan: "Email", chu: $email)
                    .focused($oDangGo, equals: .email)
                    .oKhongTuSua()
                    .banPhimEmail()
                    .submitLabel(.next)
                    .onSubmit { oDangGo = .matKhau }
            }

            ONhap(
                icon: "lock",
                nhan: "Mật khẩu",
                chu: $matKhau,
                an: !hienMatKhau,
                nutPhai: (hienMatKhau ? "eye.slash" : "eye", { hienMatKhau.toggle() }),
            )
            .focused($oDangGo, equals: .matKhau)
            .submitLabel(laDangNhap ? .go : .next)
            .onSubmit {
                if laDangNhap { Task { await gui() } } else { oDangGo = .xacNhan }
            }

            if !laDangNhap {
                ONhap(
                    icon: "lock.rotation",
                    nhan: "Nhập lại mật khẩu",
                    chu: $xacNhanMatKhau,
                    an: !hienMatKhau,
                )
                .focused($oDangGo, equals: .xacNhan)
                .submitLabel(.go)
                .onSubmit { Task { await gui() } }

                if !xacNhanMatKhau.isEmpty && matKhau != xacNhanMatKhau {
                    dongCanhBao("Hai mật khẩu chưa khớp")
                }
                if !matKhau.isEmpty && matKhau.count < 12 {
                    dongCanhBao("Mật khẩu cần ít nhất 12 ký tự")
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func dongCanhBao(_ chu: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(chu)
            Spacer()
        }
        .font(.caption)
        .foregroundColor(AppColors.warning)
    }

    // MARK: Lỗi

    private func khoiLoi(_ chu: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(chu)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.bodySmall)
        .foregroundColor(AppColors.error)
        .padding(Spacing.md)
        .background(AppColors.error.opacity(0.12))
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.error.opacity(0.35), lineWidth: 1),
        )
        .padding(.horizontal, Spacing.lg)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Nút

    private var nutChinh: some View {
        Button {
            Task { await gui() }
        } label: {
            HStack(spacing: Spacing.sm) {
                if dangGui {
                    ProgressView().tint(AppColors.onPrimary)
                }
                Text(laDangNhap ? "Đăng nhập" : "Tạo tài khoản")
                    .font(.buttonText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppColors.brandGradient)
            .foregroundColor(AppColors.onPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .shadow(color: AppColors.primary.opacity(hopLe ? 0.35 : 0), radius: 14, y: 6)
        }
        .disabled(dangGui || !hopLe)
        .opacity(hopLe ? 1 : 0.5)
        .padding(.horizontal, Spacing.lg)
    }

    private var nutQuenMatKhau: some View {
        // Việc lấy lại mật khẩu đi qua email OTP và app chưa có màn nhập OTP,
        // nên mở web thay vì dựng một nút chết.
        Link(destination: URL(string: "https://cuongthai.com/forgot-password")!) {
            Text("Quên mật khẩu?")
                .font(.bodySmall)
                .foregroundColor(AppColors.primary)
        }
    }

    private var gachNgang: some View {
        HStack(spacing: Spacing.md) {
            Rectangle().fill(AppColors.divider).frame(height: 1)
            Text("hoặc")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            Rectangle().fill(AppColors.divider).frame(height: 1)
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var ghiChuPhapLy: some View {
        VStack(spacing: Spacing.xs) {
            Text("Khi tiếp tục, bạn đồng ý với")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            HStack(spacing: Spacing.md) {
                Button("Điều khoản sử dụng") { manPhapLy = .dieuKhoan }
                Button("Chính sách bảo mật") { manPhapLy = .baoMat }
            }
            .font(.caption)
            .foregroundColor(AppColors.primary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: Logic

    private var hopLe: Bool {
        if laDangNhap {
            return !tenDangNhap.isEmpty && !matKhau.isEmpty
        }
        return !tenDangNhap.isEmpty
            && email.contains("@")
            && matKhau.count >= 12
            && matKhau == xacNhanMatKhau
    }

    private func gui() async {
        guard hopLe, !dangGui else { return }
        oDangGo = nil
        dangGui = true
        withAnimation { loi = nil }

        do {
            if !laDangNhap {
                let _: EmptyResponse = try await APIClient.shared.request(
                    .register(username: tenDangNhap, email: email, password: matKhau,
                              fullName: hoTen.isEmpty ? nil : hoTen, captchaToken: nil),
                )
            }
            let res: AuthResponse = try await APIClient.shared.request(
                .login(username: tenDangNhap, password: matKhau, captchaToken: nil),
            )
            Haptics.xong()
            appState.login(token: res.token, refreshToken: res.refreshToken)
        } catch {
            Haptics.hong()
            withAnimation { loi = error.localizedDescription }
        }

        dangGui = false
    }
}

// MARK: - Ô nhập dùng chung

struct ONhap: View {
    let icon: String
    let nhan: String
    @Binding var chu: String
    var an: Bool = false
    /// Nút bên phải trong ô — hiện dùng cho con mắt bật/tắt mật khẩu.
    var nutPhai: (String, () -> Void)? = nil

    @FocusState private var dangGo: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(dangGo ? AppColors.primary : AppColors.textTertiary)
                .frame(width: 22)

            Group {
                if an {
                    SecureField(nhan, text: $chu)
                } else {
                    TextField(nhan, text: $chu)
                }
            }
            .foregroundColor(AppColors.textPrimary)
            .focused($dangGo)

            if let (bieuTuong, bam) = nutPhai {
                Button {
                    Haptics.cham()
                    bam()
                } label: {
                    Image(systemName: bieuTuong)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Nhãn cho VoiceOver: một biểu tượng con mắt trơn không nói
                // lên nó đang bật hay tắt.
                .accessibilityLabel(bieuTuong == "eye" ? "Hiện mật khẩu" : "Ẩn mật khẩu")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .background(AppColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(dangGo ? AppColors.primary : AppColors.border, lineWidth: dangGo ? 1.5 : 1),
        )
        .animation(.easeOut(duration: 0.15), value: dangGo)
    }
}

#Preview {
    AuthView().environmentObject(AppState.shared)
}
