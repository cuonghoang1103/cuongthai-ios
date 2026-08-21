import SwiftUI

/// Chế độ giao diện người dùng chọn trong Cài đặt.
///
/// Toàn bộ màu của app đã là màu THÍCH ỨNG (`Color.theoCheDo(sang:toi:)` trong
/// `Theme.swift`), nên chỗ này chỉ quyết định "đang ở chế độ nào" — không phải
/// sửa từng màu. Đã rà 16 chỗ đặt màu cứng: tất cả đều nằm trên nền tự đặt
/// (ảnh, gradient, nút màu, khối mã) nên đúng ở cả hai chế độ.
enum CheDoGiaoDien: String, CaseIterable, Identifiable {
    case heThong, sang, toi, theoGio
    var id: String { rawValue }

    var ten: String {
        switch self {
        case .heThong: return "Theo hệ thống"
        case .sang:    return "Sáng"
        case .toi:     return "Tối"
        case .theoGio: return "Tự động theo giờ"
        }
    }

    var bieuTuong: String {
        switch self {
        case .heThong: return "iphone"
        case .sang:    return "sun.max.fill"
        case .toi:     return "moon.fill"
        case .theoGio: return "clock.fill"
        }
    }

    var moTa: String {
        switch self {
        case .heThong: return "Đổi theo Cài đặt của iPhone"
        case .sang:    return "Luôn nền sáng"
        case .toi:     return "Luôn nền tối"
        case .theoGio:
            return "Sáng \(QuanLyGiaoDien.gioSang)h–\(QuanLyGiaoDien.gioToi)h, tối ngoài khung đó"
        }
    }
}

/// Giữ lựa chọn và tính ra chế độ đang hiệu lực.
///
/// ⚠️ `theoGio` phải TỰ ĐỔI khi tới giờ, không chỉ lúc mở app — đang đọc lúc
/// 17:59 thì 18:00 nền phải tối đi. Vì thế có hẹn giờ đánh thức ĐÚNG mốc
/// chuyển, thay vì hỏi mỗi phút cho tốn pin.
@MainActor
final class QuanLyGiaoDien: ObservableObject {
    static let shared = QuanLyGiaoDien()

    /// Khung giờ SÁNG. Một chỗ duy nhất, dùng cho cả luật tính lẫn câu mô tả
    /// trong Cài đặt — hai nơi lệch nhau là màn Cài đặt nói dối.
    static let gioSang = 6
    static let gioToi = 18

    private static let khoa = "cheDoGiaoDien"

    @Published var cheDo: CheDoGiaoDien {
        didSet {
            UserDefaults.standard.set(cheDo.rawValue, forKey: Self.khoa)
            tinhLai()
            datHenGio()
        }
    }

    /// `nil` = để hệ thống quyết định.
    @Published private(set) var mauSac: ColorScheme?

    private var hen: Timer?

    private init() {
        let luu = UserDefaults.standard.string(forKey: Self.khoa)
        cheDo = luu.flatMap(CheDoGiaoDien.init(rawValue:)) ?? .heThong
        tinhLai()
        datHenGio()
    }

    private func tinhLai() {
        switch cheDo {
        case .heThong: mauSac = nil
        case .sang:    mauSac = .light
        case .toi:     mauSac = .dark
        case .theoGio: mauSac = Self.dangLaBanNgay() ? .light : .dark
        }
    }

    static func dangLaBanNgay(_ luc: Date = Date()) -> Bool {
        let gio = Calendar.current.component(.hour, from: luc)
        return gio >= gioSang && gio < gioToi
    }

    /// Mốc 6h hoặc 18h gần nhất còn ở phía trước.
    static func mocChuyenKeTiep(_ tu: Date = Date()) -> Date? {
        let l = Calendar.current
        for them in 0...1 {
            guard let ngay = l.date(byAdding: .day, value: them, to: tu) else { continue }
            for gio in [gioSang, gioToi] {
                if let m = l.date(bySettingHour: gio, minute: 0, second: 0, of: ngay), m > tu {
                    return m
                }
            }
        }
        return nil
    }

    private func datHenGio() {
        hen?.invalidate(); hen = nil
        guard cheDo == .theoGio, let moc = Self.mocChuyenKeTiep() else { return }
        let sau = max(60, moc.timeIntervalSinceNow)
        hen = Timer.scheduledTimer(withTimeInterval: sau, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.tinhLai()
                self?.datHenGio()   // đặt tiếp cho mốc sau
            }
        }
    }

    /// Gọi khi app quay lại tiền cảnh: máy có thể đã ngủ qua mốc chuyển, và
    /// `Timer` không chạy trong lúc đó.
    func lamMoiKhiTroLai() {
        tinhLai()
        datHenGio()
    }
}
