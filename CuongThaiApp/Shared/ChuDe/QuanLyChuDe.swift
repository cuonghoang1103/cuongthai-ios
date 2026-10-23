import SwiftUI
import Observation
#if os(iOS)
import UIKit
#endif

/// Mật độ hạt rơi.
enum MatDoHat: Int, CaseIterable, Identifiable {
    case it = 0, vua = 1, nhieu = 2
    var id: Int { rawValue }
    var ten: String {
        switch self {
        case .it: return T("Ít")
        case .vua: return T("Vừa")
        case .nhieu: return T("Nhiều")
        }
    }
    /// Số hạt trên một màn cỡ iPhone (390×844). Màn to hơn nhân theo diện tích (trần ×2,2 — iPad 13").
    var soHatCoSo: Int {
        switch self {
        case .it: return 10
        case .vua: return 18
        case .nhieu: return 30
        }
    }
}

/// Giữ lựa chọn chủ đề + quyết bảng màu đang hiệu lực + quyết hiệu ứng động có được chạy không.
///
/// Lưu bằng `UserDefaults` (cùng kho với `@AppStorage`, khoá ở `Khoa`). Đổi bất kỳ thứ gì là có hiệu lực NGAY:
/// `chuDe` ghi bảng mới vào `KhoBangMau` ⇒ mọi `AppColors.x` đọc lại (xem `Theme.swift`).
@MainActor
@Observable
final class QuanLyChuDe {
    static let shared = QuanLyChuDe()

    enum Khoa {
        static let chuDe = "chuDe.ten"
        static let dong = "chuDe.hieuUngDong"
        static let matDo = "chuDe.matDo"
        static let goc = "chuDe.trangTriGoc"
        static let moiTrang = "chuDe.hatMoiTrang"
        static let cham = "chuDe.hieuUngCham"
    }

    var chuDe: ChuDe { didSet { luu(chuDe.rawValue, Khoa.chuDe); apDung() } }
    /// Công tắc tổng của chuyển động (hạt rơi, đèn nháy, sóng…). Tắt ⇒ vẫn vẽ trang trí, nhưng đứng yên.
    var hieuUngDong: Bool { didSet { luu(hieuUngDong, Khoa.dong) } }
    var matDo: MatDoHat { didSet { luu(matDo.rawValue, Khoa.matDo) } }
    /// Hình trang trí ở bốn góc màn chính (đèn lồng, mặt trời, chim cánh cụt…).
    var trangTriGoc: Bool { didSet { luu(trangTriGoc, Khoa.goc) } }
    /// Vài hạt rơi thưa ở MÉP các màn con (ngoài 6 màn chính đã có nền mùa đầy đủ).
    var hatMoiTrang: Bool { didSet { luu(hatMoiTrang, Khoa.moiTrang) } }
    /// Chạm đâu bung vài cánh hoa / bông tuyết ở đó. Mặc định TẮT.
    var hieuUngCham: Bool { didSet { luu(hieuUngCham, Khoa.cham) } }

    /// Mùa ĐANG vẽ (đã giải "Tự động"). `nil` = Mặc định.
    private(set) var mua: Mua?
    /// Chế độ nguồn điện thấp đang bật ⇒ mọi chuyển động dừng.
    private(set) var nguonThap = false

    /// Số màn "đọc dài" đang hiện (`.nenMuaYen()`): bài học, đọc sách, Vở, làm bài thi, trình phát video…
    /// > 0 ⇒ lớp hạt phủ mọi trang tắt và nền mùa đứng yên.
    private(set) var soManYen = 0
    /// Số màn chính đang hiện có nền mùa riêng (`.nenChuDe()`) — khi đó lớp hạt phủ không chạy chồng lên.
    private(set) var soManNen = 0

    /// Chuyển động được phép chạy (chưa tính "Giảm chuyển động" — cái đó đọc từ môi trường của view).
    var dongDuoc: Bool { hieuUngDong && !nguonThap && soManYen == 0 }

    private init() {
        let d = UserDefaults.standard
        var c = d.string(forKey: Khoa.chuDe).flatMap(ChuDe.init(rawValue:)) ?? .tuDong
        var dong = d.object(forKey: Khoa.dong) as? Bool ?? true
        var md = MatDoHat(rawValue: d.object(forKey: Khoa.matDo) as? Int ?? 1) ?? .vua
        var cham = d.object(forKey: Khoa.cham) as? Bool ?? false
        #if DEBUG
        // Cửa chụp màn: `CT_CHU_DE=tudong|macdinh|xuan|ha|thu|dong`, `CT_HIEU_UNG=0|1`, `CT_MAT_DO=0|1|2`, `CT_CHAM=1`.
        // Chỉ đè trong phiên chạy — gán vào biến cục bộ nên KHÔNG ghi xuống UserDefaults.
        let env = ProcessInfo.processInfo.environment
        if let s = env["CT_CHU_DE"]?.lowercased(),
           let x = ChuDe.allCases.first(where: { $0.rawValue.lowercased() == s }) { c = x }
        if let s = env["CT_HIEU_UNG"] { dong = s != "0" }
        if let s = env["CT_MAT_DO"], let v = Int(s), let m = MatDoHat(rawValue: v) { md = m }
        if env["CT_CHAM"] == "1" { cham = true }
        #endif
        chuDe = c
        hieuUngDong = dong
        matDo = md
        trangTriGoc = d.object(forKey: Khoa.goc) as? Bool ?? true
        hatMoiTrang = d.object(forKey: Khoa.moiTrang) as? Bool ?? true
        hieuUngCham = cham
        nguonThap = ProcessInfo.processInfo.isLowPowerModeEnabled
        mua = chuDe.mua()
        KhoBangMau.shared.bang = BangMauChuDe.cua(mua)
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil,
                                               queue: .main) { _ in
            Task { @MainActor in
                QuanLyChuDe.shared.nguonThap = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    /// Gọi sớm nhất có thể (init của App) để màn đầu tiên đã mang đúng màu — không nháy tím rồi mới đổi.
    static func khoiDong() { _ = shared }

    /// Tính lại mùa + bảng. Gọi khi đổi chủ đề và khi app quay lại tiền cảnh (qua nửa đêm 31/10 → 1/11 là sang Đông).
    func apDung() {
        let moi = chuDe.mua()
        if moi != mua { mua = moi }
        KhoBangMau.shared.bang = BangMauChuDe.cua(moi)
    }

    func lamMoiKhiTroLai() {
        if chuDe.mua() != mua { apDung() }
        nguonThap = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func vaoManYen() { soManYen += 1 }
    func roiManYen() { soManYen = max(0, soManYen - 1) }
    func vaoManNen() { soManNen += 1 }
    func roiManNen() { soManNen = max(0, soManNen - 1) }

    private func luu(_ v: Any, _ k: String) { UserDefaults.standard.set(v, forKey: k) }
}

// MARK: - Modifier cho các màn

extension View {
    /// Nền mùa ĐẦY ĐỦ (nền loang + hạt + trang trí 4 góc) cho MÀN CHÍNH. Thay cho
    /// `.background(AppColors.backgroundPrimary)` ở gốc màn: nội dung (thẻ) nằm TRÊN nền nên luôn rõ.
    /// `tieuDeLon: true` cho màn dùng tiêu đề LỚN (navigationBarTitleDisplayMode .large) — bỏ trang trí dải trên.
    func nenChuDe(tieuDeLon: Bool = false) -> some View { modifier(NenChuDeModifier(tren: !tieuDeLon)) }

    /// Màn đọc dài / tập trung (bài học, đọc sách, Vở, làm bài thi, video): khi màn này đang hiện thì mọi chuyển
    /// động của chủ đề dừng (nền vẫn giữ màu mùa). Gắn ở gốc màn — đếm theo onAppear/onDisappear nên lồng nhau vẫn đúng.
    func nenMuaYen() -> some View { modifier(ManYenModifier()) }
}

private struct ManYenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { QuanLyChuDe.shared.vaoManYen() }
            .onDisappear { QuanLyChuDe.shared.roiManYen() }
    }
}

private struct NenChuDeModifier: ViewModifier {
    var tren = true
    func body(content: Content) -> some View {
        content
            .background { NenMuaTuDong(kieu: .trangChinh, tren: tren) }
            .onAppear { QuanLyChuDe.shared.vaoManNen() }
            .onDisappear { QuanLyChuDe.shared.roiManNen() }
    }
}
