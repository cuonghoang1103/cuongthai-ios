import SwiftUI

// MARK: - Đăng nhập / Đăng ký
//
// 21/10/2026 — giao diện mới kiểu "hero + tấm trượt lên" (vỏ dùng chung với app CT Work:
// Shared/ChuyenDong/GiaoDienDangNhap.swift): gấu trúc Bip vẫy tay giữa vài chip học tập lơ lửng, tấm trắng có ô nhập
// viền chạy quanh khi chạm, nút viên thuốc co + rung khi nhấn, "Ghi nhớ tên đăng nhập", "Quên mật khẩu?", Apple + Google;
// bấm gửi ⇒ nền mờ + Bip nhảy + "Đang đăng nhập…"; lỗi ⇒ tấm lắc + băng lỗi.
// LOGIC GIỮ NGUYÊN: đăng ký ⇒ đăng nhập bằng cùng tên/mật khẩu (`gui()`), Apple/Google qua đúng hai nút cũ,
// `appState.login(...)` như trước. Chỉ thêm: lớp chờ hiện ít nhất 0,9 s (thời gian hiển thị, không đổi luồng).

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var cheDo

    @State private var laDangNhap = true
    @State private var tenDangNhap = ""
    @State private var email = ""
    @State private var matKhau = ""
    @State private var xacNhanMatKhau = ""
    @State private var hoTen = ""
    @State private var dangGui = false
    @State private var loi: String?
    @State private var manPhapLy: ManPhapLy?
    @State private var lanLac = 0
    @FocusState private var oDangGo: O?
    /// Ghi nhớ TÊN ĐĂNG NHẬP cho lần sau (phiên vẫn giữ trong Keychain như cũ — công tắc này không đổi điều đó).
    @AppStorage("dangNhap.nhoTen") private var nhoTen = true
    @AppStorage("dangNhap.tenDaNho") private var tenDaNho = ""

    private enum O: Hashable { case hoTen, tenDangNhap, email, matKhau, xacNhan }

    enum ManPhapLy: String, Identifiable {
        case dieuKhoan, baoMat
        var id: String { rawValue }
    }

    #if DEBUG
    /// Màn thử (`CT_XEM_MAN=dangnhap`): thay lời gọi máy chủ bằng bản giả và chuyển kết quả sang màn chính giả —
    /// để quay/chụp cả luồng mà không cần tài khoản thật. Bản Release không có hai biến này.
    static var thuDangNhap: ((String, String) async throws -> AuthResponse)?
    static var thuSauDangNhap: ((AuthResponse) -> Void)?
    #endif

    static let choToiThieu: TimeInterval = 0.9

    var body: some View {
        BoCucDangNhap(
            nenHero: AnyShapeStyle(LinearGradient(
                colors: cheDo == .dark
                    ? [Color(red: 0.20, green: 0.12, blue: 0.36), Color(red: 0.07, green: 0.16, blue: 0.24)]
                    : [Color(red: 0.93, green: 0.89, blue: 1.0), Color(red: 0.99, green: 0.90, blue: 0.95)],
                startPoint: .topLeading, endPoint: .bottomTrailing)),
            dangGo: oDangGo != nil,
            cuonToi: oDangGo.map { AnyHashable("o-\($0)") },
            dangDangNhap: dangGui,
            lanLac: lanLac,
            hero: { gon in HeroDangNhapBip(gon: gon) },
            tam: { tam },
            lopCho: {
                LopDangDangNhap(chu: laDangNhap ? T("Đang đăng nhập…") : T("Đang tạo tài khoản…"),
                                mau: AppColors.brandGradient) {
                    BipNhay(co: 96)
                }
            })
        .sheet(item: $manPhapLy) { man in
            NavigationStack {
                switch man {
                case .dieuKhoan: TermsView(dismissible: true)
                case .baoMat: PrivacyPolicyView(dismissible: true)
                }
            }
        }
        .onAppear { if nhoTen, tenDangNhap.isEmpty { tenDangNhap = tenDaNho } }
    }

    // MARK: Tấm form

    private var tam: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(laDangNhap ? T("Chào mừng trở lại") : T("Tạo tài khoản mới"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(laDangNhap ? T("Đăng nhập để tiếp tục học và kết nối.") : T("Một tài khoản cho app và cuongthai.com."))
                    .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
            }
            .id(laDangNhap)
            .transition(.opacity)

            if let loi { khoiLoi(loi) }

            cacO

            if laDangNhap {
                HStack(spacing: 8) {
                    OTich(nhan: T("Ghi nhớ tên đăng nhập"), bat: $nhoTen)
                    Spacer(minLength: 4)
                    // Việc lấy lại mật khẩu đi qua email OTP và app chưa có màn nhập OTP, nên mở web.
                    Link(destination: URL(string: "https://cuongthai.com/forgot-password")!) {
                        Text(T("Quên mật khẩu?")).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                    }
                }
            }

            NutVienThuoc(nhan: laDangNhap ? T("Đăng nhập") : T("Tạo tài khoản"), nen: AppColors.brandGradient,
                         dangChay: dangGui, bat: hopLe, maDinhDanh: "dangNhap.gui") {
                Task { await gui() }
            }
            .shadow(color: AppColors.primary.opacity(hopLe ? 0.32 : 0), radius: 14, y: 7)

            HStack(spacing: 10) {
                Rectangle().fill(AppColors.divider).frame(height: 0.5)
                Text(T("hoặc tiếp tục với")).font(.caption).foregroundColor(AppColors.textTertiary).fixedSize()
                Rectangle().fill(AppColors.divider).frame(height: 0.5)
            }

            VStack(spacing: Spacing.sm) {
                AppleSignInButton(
                    onSignedIn: { res in Task { await vaoBangMangXaHoi(res) } },
                    onError: { thongBao in baoLoi(thongBao) },
                    kieu: cheDo == .dark ? .white : .black,
                    vienThuoc: true)
                // Tự ẩn khi chưa dán client ID iOS vào Info.plist.
                GoogleSignInButtonView(
                    onSignedIn: { res in Task { await vaoBangMangXaHoi(res) } },
                    onError: { thongBao in baoLoi(thongBao) })
            }

            HStack(spacing: 4) {
                Text(laDangNhap ? T("Chưa có tài khoản?") : T("Đã có tài khoản?"))
                    .foregroundColor(AppColors.textSecondary)
                Button(laDangNhap ? T("Đăng ký") : T("Đăng nhập")) { doiTab() }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
                    .accessibilityIdentifier("dangNhap.doiCheDo")
            }
            .font(.system(size: 14))
            .frame(maxWidth: .infinity)

            ghiChuPhapLy
        }
        .animation(.snappy(duration: 0.28), value: laDangNhap)
        .animation(.easeOut(duration: 0.2), value: loi)
    }

    private func doiTab() {
        RungNhe.cham()
        withAnimation(.snappy(duration: 0.28)) {
            laDangNhap.toggle()
            loi = nil
        }
    }

    // MARK: Các ô nhập

    private var cacO: some View {
        VStack(spacing: 12) {
            if !laDangNhap {
                ODangNhap(bieuTuong: "person", goiY: T("Họ và tên"), chu: $hoTen, tapTrung: $oDangGo, gia: .hoTen,
                          mau: AppColors.primary, maDinhDanh: "dangNhap.hoTen")
                    .submitLabel(.next)
                    .onSubmit { oDangGo = .tenDangNhap }
                    .id(AnyHashable("o-\(O.hoTen)"))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            ODangNhap(bieuTuong: "at", goiY: T("Tên đăng nhập"), chu: $tenDangNhap, tapTrung: $oDangGo, gia: .tenDangNhap,
                      mau: AppColors.primary, maDinhDanh: "dangNhap.ten")
                .oKhongTuSua()
                .submitLabel(.next)
                .onSubmit { oDangGo = laDangNhap ? .matKhau : .email }
                .id(AnyHashable("o-\(O.tenDangNhap)"))
            if !laDangNhap {
                ODangNhap(bieuTuong: "envelope", goiY: "Email", chu: $email, tapTrung: $oDangGo, gia: .email,
                          mau: AppColors.primary, maDinhDanh: "dangNhap.email")
                    .oKhongTuSua()
                    .banPhimEmail()
                    .submitLabel(.next)
                    .onSubmit { oDangGo = .matKhau }
                    .id(AnyHashable("o-\(O.email)"))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            ODangNhap(bieuTuong: "lock", goiY: T("Mật khẩu"), chu: $matKhau, an: true, tapTrung: $oDangGo, gia: .matKhau,
                      mau: AppColors.primary, nhanHien: T("Hiện mật khẩu"), nhanAn: T("Ẩn mật khẩu"),
                      maDinhDanh: "dangNhap.matKhau")
                .oKhongTuSua()
                .submitLabel(laDangNhap ? .go : .next)
                .onSubmit { if laDangNhap { Task { await gui() } } else { oDangGo = .xacNhan } }
                .id(AnyHashable("o-\(O.matKhau)"))
            if !laDangNhap {
                ODangNhap(bieuTuong: "lock.rotation", goiY: T("Nhập lại mật khẩu"), chu: $xacNhanMatKhau, an: true,
                          tapTrung: $oDangGo, gia: .xacNhan, mau: AppColors.primary,
                          nhanHien: T("Hiện mật khẩu"), nhanAn: T("Ẩn mật khẩu"), maDinhDanh: "dangNhap.xacNhan")
                    .oKhongTuSua()
                    .submitLabel(.go)
                    .onSubmit { Task { await gui() } }
                    .id(AnyHashable("o-\(O.xacNhan)"))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                if !xacNhanMatKhau.isEmpty && matKhau != xacNhanMatKhau {
                    dongCanhBao(T("Hai mật khẩu chưa khớp"))
                }
                if !matKhau.isEmpty && matKhau.count < 12 {
                    dongCanhBao(T("Mật khẩu cần ít nhất 12 ký tự"))
                }
            }
        }
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
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var ghiChuPhapLy: some View {
        VStack(spacing: Spacing.xs) {
            Text(T("Khi tiếp tục, bạn đồng ý với"))
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            HStack(spacing: Spacing.md) {
                Button(T("Điều khoản sử dụng")) { manPhapLy = .dieuKhoan }
                Button(T("Chính sách bảo mật")) { manPhapLy = .baoMat }
            }
            .font(.caption)
            .foregroundColor(AppColors.primary)
        }
        .frame(maxWidth: .infinity)
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

    private func baoLoi(_ chu: String) {
        Haptics.hong()
        withAnimation { loi = chu }
        lanLac += 1
    }

    private func doiToiThieu(tu batDau: Date) async {
        let con = Self.choToiThieu - Date().timeIntervalSince(batDau)
        if con > 0 { try? await Task.sleep(nanoseconds: UInt64(con * 1_000_000_000)) }
    }

    /// Apple/Google đã xác thực xong (hai nút cũ tự gọi máy chủ) ⇒ hiện lớp chờ cho liền mạch rồi `login` như trước.
    private func vaoBangMangXaHoi(_ res: AuthResponse) async {
        dangGui = true
        await doiToiThieu(tu: Date())
        Haptics.xong()
        vao(res)
        dangGui = false
    }

    private func vao(_ res: AuthResponse) {
        #if DEBUG
        if let sau = Self.thuSauDangNhap { sau(res); return }
        #endif
        appState.login(token: res.token, refreshToken: res.refreshToken)
    }

    private func dangNhapMayChu() async throws -> AuthResponse {
        #if DEBUG
        if let thu = Self.thuDangNhap { return try await thu(tenDangNhap, matKhau) }
        #endif
        return try await APIClient.shared.request(
            .login(username: tenDangNhap, password: matKhau, captchaToken: nil),
        )
    }

    private func gui() async {
        guard hopLe, !dangGui else { return }
        oDangGo = nil
        dangGui = true
        withAnimation { loi = nil }
        let batDau = Date()

        do {
            if !laDangNhap {
                let _: EmptyResponse = try await APIClient.shared.request(
                    .register(username: tenDangNhap, email: email, password: matKhau,
                              fullName: hoTen.isEmpty ? nil : hoTen, captchaToken: nil),
                )
            }
            let res = try await dangNhapMayChu()
            tenDaNho = nhoTen ? tenDangNhap : ""
            await doiToiThieu(tu: batDau)
            Haptics.xong()
            vao(res)
        } catch {
            await doiToiThieu(tu: batDau)
            baoLoi(error.localizedDescription)
        }

        dangGui = false
    }
}

#Preview {
    AuthView().environmentObject(AppState.shared)
}
