import SwiftUI
import LocalAuthentication

// MARK: - Khoá app bằng Face ID / Touch ID (mảng D) — TUỲ CHỌN, mặc định TẮT
//
// · Bật ở Account → Security. Lúc bật phải xác thực thành công một lần (chứng minh máy làm được).
// · Bật rồi: mỗi lần app VỀ tiền cảnh từ nền (hoặc mở nguội) ⇒ phủ màn khoá, gọi
//   `.deviceOwnerAuthentication` (Face ID, lùi về mật mã máy — không bao giờ khoá chết người dùng).
// · Khi app vào nền ⇒ phủ ngay (ảnh chụp đa nhiệm không lộ nội dung).
// · `NSFaceIDUsageDescription` trong Info.plist — BẮT BUỘC từ khi có tệp này (thiếu ⇒ iOS giết app khi gọi
//   Face ID). CLAUDE.md A14: chỉ khai vì tính năng này DÙNG thật.
// · Máy chủ GIẢ (`CT_XEM_MAN`): không khoá (ảnh chụp/kiểm thử) trừ màn thử `khoa`.

@MainActor
final class KhoaAppVM: ObservableObject {
    static let shared = KhoaAppVM()
    static let khoaBat = "com.cuongthai.ctwork.faceIdLock"

    @Published var bat: Bool = UserDefaults.standard.bool(forKey: KhoaAppVM.khoaBat)
    @Published var dangKhoa: Bool
    @Published var loi: String?
    private var dangHoi = false

    private init() {
        dangKhoa = UserDefaults.standard.bool(forKey: KhoaAppVM.khoaBat)
        #if DEBUG
        if let m = XemThuCTW.man, !m.isEmpty { dangKhoa = m.lowercased() == "khoa" }
        #endif
    }

    func datBat(_ v: Bool) async {
        if v {
            // Bật: xác thực một lần trước — máy không có Face ID/mật mã thì không bật được.
            guard await xacThuc(lyDo: "Turn on Face ID lock for CT Work") else { return }
        }
        bat = v
        UserDefaults.standard.set(v, forKey: Self.khoaBat)
    }

    func khoa() { if bat { dangKhoa = true } }

    func moKhoa() async {
        guard dangKhoa, !dangHoi else { return }
        #if DEBUG
        // Màn thử `khoa`: chỉ hiện màn khoá, không bật hộp mật mã của hệ thống (máy ảo không có Face ID).
        if XemThuCTW.man?.lowercased() == "khoa" { return }
        #endif
        dangHoi = true
        defer { dangHoi = false }
        if await xacThuc(lyDo: "Unlock CT Work") { dangKhoa = false; loi = nil }
    }

    private func xacThuc(lyDo: String) async -> Bool {
        let c = LAContext()
        var e: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthentication, error: &e) else {
            loi = "Set a passcode or Face ID in Settings to use this."
            return false
        }
        do { return try await c.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: lyDo) }
        catch { loi = (error as? LAError)?.code == .userCancel ? nil : "Couldn't verify it's you. Try again."; return false }
    }
}

/// Lớp phủ khoá — gắn MỘT lần ở gốc app.
struct KhoaAppCTW: View {
    @ObservedObject private var vm = KhoaAppVM.shared

    static var tenSinhTracHoc: String {
        let c = LAContext()
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch c.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Face ID"
        }
    }

    /// Gọi từ `onChange(of: scenePhase)` của app.
    static func doiPha(_ p: ScenePhase) {
        switch p {
        case .background: KhoaAppVM.shared.khoa()
        case .active: Task { await KhoaAppVM.shared.moKhoa() }
        default: break
        }
    }

    var body: some View {
        if vm.dangKhoa {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                VStack(spacing: 18) {
                    Image("LogoCTWork").resizable().scaledToFit().frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityHidden(true)
                    Text("CT Work is locked").font(.ctw(size: 20, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    if let l = vm.loi { Text(l).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center) }
                    Button { Task { await vm.moKhoa() } } label: {
                        Label("Unlock with \(Self.tenSinhTracHoc)", systemImage: Self.tenSinhTracHoc == "Touch ID" ? "touchid" : "faceid")
                            .font(.ctw(size: 16, weight: .semibold)).frame(minWidth: 220, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(32)
            }
            .transition(.opacity)
            .task { await vm.moKhoa() }
        }
    }
}

/// Công tắc ở Account → Security.
struct KhoaAppCongTacCTW: View {
    @ObservedObject private var vm = KhoaAppVM.shared

    var body: some View {
        Toggle(isOn: Binding(get: { vm.bat }, set: { v in Task { await vm.datBat(v) } })) {
            Label("Require \(KhoaAppCTW.tenSinhTracHoc)", systemImage: "faceid")
        }
        if let l = vm.loi, !vm.dangKhoa {
            Text(l).font(.ctw(size: 12)).foregroundColor(AppColors.error)
        }
    }
}
