import SwiftUI

// MARK: - Trạng thái hoạt động kiểu Messenger (21/10/2026)
//
// Hai nguồn bù cho nhau (bài học app chính, Shared/Realtime/TrangThaiHoatDong.swift):
//   · máy chủ (`/work/me/people` › presence, `peer.lastActiveAt` của hội thoại) — đúng NGAY lúc mở màn;
//   · socket `presence:update` — realtime, nhưng chỉ phát cho bạn bè ∪ người đã có hội thoại.
// Riêng tư: ai tắt "Hiển thị trạng thái hoạt động" thì máy chủ không trả mốc và không phát socket; người XEM tự tắt
// thì máy chủ ẩn của mọi người (luật đối ứng) — app áp lại luật đó ở client cho dữ liệu đến từ socket/hội thoại.

enum TrangThaiHoatDongCTW {
    /// PHẢI khớp `NGUONG_TRUC_TUYEN_GIAY` (people.service.ts) / `ONLINE_THRESHOLD_SECONDS` (follow.service.ts).
    static let nguong: TimeInterval = 60

    enum Moc: Equatable {
        /// Không vẽ gì (ẩn vì riêng tư, agent, đã chặn, hoặc quá lâu).
        case an
        case dangHoatDong
        case phut(Int)
        case gio(Int)
        case homQua
        case ngay(Int)
        case tuan(Int)
    }

    /// Luật hiện trạng thái giữa người xem và một người: cả HAI phải bật, không phải agent, không chặn nhau.
    static func duocHien(toiBat: Bool, hoBat: Bool, laAgent: Bool = false, daChan: Bool = false) -> Bool {
        toiBat && hoBat && !laAgent && !daChan
    }

    /// Phân loại mốc. `online` = máy chủ/socket nói đang hoạt động.
    static func phanLoai(hien: Bool, online: Bool, moc: Date?, bayGio: Date = Date(), lich: Calendar = .current) -> Moc {
        guard hien else { return .an }
        if online { return .dangHoatDong }
        guard let moc else { return .an }
        let giay = bayGio.timeIntervalSince(moc)
        // Mốc ở tương lai (đồng hồ lệch) hoặc trong ngưỡng ⇒ coi như đang hoạt động.
        if giay < nguong { return .dangHoatDong }
        let phut = Int(giay / 60)
        if phut < 60 { return .phut(max(1, phut)) }
        let gio = phut / 60
        if gio < 24 { return .gio(gio) }
        let ngayLich = lich.dateComponents([.day], from: lich.startOfDay(for: moc), to: lich.startOfDay(for: bayGio)).day ?? 0
        if ngayLich <= 1 { return .homQua }
        if ngayLich < 7 { return .ngay(ngayLich) }
        if ngayLich < 28 { return .tuan(ngayLich / 7) }
        return .an
    }

    /// Chữ hiện dưới tên ("Active now" / "Đang hoạt động", "Hoạt động 5 phút trước"…). Rỗng = không vẽ dòng nào.
    static func chu(_ m: Moc) -> String {
        switch m {
        case .an: return ""
        case .dangHoatDong: return String(localized: "Active now")
        case .phut(let n): return String(localized: "Active \(n)m ago")
        case .gio(let n): return String(localized: "Active \(n)h ago")
        case .homQua: return String(localized: "Active yesterday")
        case .ngay(let n): return String(localized: "Active \(n)d ago")
        case .tuan(let n): return String(localized: "Active \(n)w ago")
        }
    }

    /// Chữ ngắn cho góc avatar trong danh sách (Messenger: "5 phút", "2 giờ") — chỉ khi vừa rời < 1 giờ.
    static func nhanGoc(_ m: Moc) -> String? {
        if case .phut(let n) = m { return String(localized: "\(n)m") }
        return nil
    }
}

// MARK: - Avatar có chấm hoạt động

/// Avatar + chấm xanh viền trắng ở góc dưới phải khi đang hoạt động (như Messenger); vừa rời < 1 giờ ⇒ nhãn "5m".
struct AvatarHoatDongCTW: View {
    let user: CTWUser?
    var size: CGFloat = 44
    var moc: TrangThaiHoatDongCTW.Moc = .an

    var body: some View {
        CTWAvatar(user: user, size: size)
            .overlay(alignment: .bottomTrailing) {
                if moc == .dangHoatDong {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay(Circle().strokeBorder(AppColors.backgroundPrimary, lineWidth: max(2, size * 0.06)))
                        .offset(x: size * 0.02, y: size * 0.02)
                        .accessibilityHidden(true)
                } else if let n = TrangThaiHoatDongCTW.nhanGoc(moc), size >= 36 {
                    Text(n)
                        .font(.ctw(size: max(8, size * 0.2), weight: .bold))
                        .foregroundColor(AppColors.success)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Capsule().fill(AppColors.backgroundCard))
                        .overlay(Capsule().strokeBorder(AppColors.success.opacity(0.5), lineWidth: 1))
                        .offset(x: size * 0.1, y: size * 0.04)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(TrangThaiHoatDongCTW.chu(moc))
    }
}

// MARK: - Báo "tôi đang hoạt động" lên máy chủ

/// `POST /users/status` mỗi 45 s khi app ở tiền cảnh (ngưỡng máy chủ 60 s). Thiếu nhịp này thì người dùng app CT Work
/// luôn "ngoại tuyến" với người không có socket chung (bài học app chính 17/09/2026). Ra nền ⇒ dừng; máy chủ ghi mốc
/// lúc ngắt socket cuối (messaging.socket.ts) nên "Hoạt động N phút trước" vẫn đúng.
@MainActor
final class NhipHoatDongCTW {
    static let shared = NhipHoatDongCTW()
    private static let nhip: TimeInterval = 45
    private var dong: Timer?
    private init() {}

    func batDau() {
        #if DEBUG
        if AppState.shared.cheDoXemThu { return }
        #endif
        guard dong == nil, AppState.shared.isAuthenticated else { return }
        Task { await gui() }
        let t = Timer.scheduledTimer(withTimeInterval: Self.nhip, repeats: true) { _ in
            Task { @MainActor in await NhipHoatDongCTW.shared.gui() }
        }
        RunLoop.main.add(t, forMode: .common)   // không thì đứng im khi đang cuộn
        dong = t
    }

    func dungLai() { dong?.invalidate(); dong = nil }

    private func gui() async {
        guard AppState.shared.isAuthenticated else { return }
        _ = try? await APIClient.shared.requestRaw(.baoHoatDong)
    }
}

// MARK: - Công tắc "Hiển thị trạng thái hoạt động" (Account › Privacy & security)

/// Như Messenger: tắt ⇒ người khác không thấy chấm xanh / "hoạt động … trước" của bạn, VÀ bạn cũng không thấy của họ
/// (máy chủ áp luật đối ứng ở `/work/me/people` + `/messages/online`; socket không phát trạng thái của bạn nữa).
/// Cùng trường `User.showActiveStatus` mà app chính sửa ở "Chỉnh sửa hồ sơ" — đổi ở đâu cũng có hiệu lực ở mọi nơi.
struct CongTacTrangThaiHoatDongCTW: View {
    @EnvironmentObject private var app: AppState
    @State private var bat = true
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        Toggle(isOn: Binding(get: { bat }, set: { moi in Task { await dat(moi) } })) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show active status")
                    Text("When off, teammates won't see when you're active, and you won't see theirs.")
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
            } icon: { Image(systemName: "circlebadge.fill") }
        }
        .disabled(dangLuu)
        .accessibilityIdentifier("account.activeStatus")
        .onAppear { bat = app.currentUser?.showActiveStatus ?? true }
        .onChange(of: app.currentUser?.showActiveStatus) { _, m in if !dangLuu { bat = m ?? true } }
        if let loi { Text(loi).font(.ctw(size: 12)).foregroundColor(AppColors.error) }
    }

    private func dat(_ moi: Bool) async {
        let cu = bat
        bat = moi; dangLuu = true; loi = nil
        defer { dangLuu = false }
        do { try await KhoTinNhanCTW.shared.datHienTrangThai(moi) } catch { bat = cu; loi = CTW.loi(error) }
    }
}
