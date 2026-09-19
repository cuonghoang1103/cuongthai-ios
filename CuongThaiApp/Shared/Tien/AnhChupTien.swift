import Foundation

// ════════════════════════════════════════════════════════════════
// ẢNH CHỤP TIỀN NONG — thứ DUY NHẤT widget đọc.
//
// ⚠️ Widget KHÔNG gọi API và KHÔNG giữ khoá đăng nhập. Đưa token vào
// extension là nhân đôi chỗ có thể rò, mà đổi lại chỉ được vài phút tươi
// hơn. App ghi ảnh chụp mỗi lần mở Tiền nong và mỗi lần ghi tiền; widget
// đọc tệp đó. Mất mạng vẫn hiện được số cũ kèm mốc thời gian.
//
// ⚠️ Tệp này được biên dịch vào CẢ hai target (app + widget) nên nó phải
// TỰ ĐỦ: chỉ `Foundation`, không `T()`, không `AppColors`, không mô hình
// nào khác. Thêm một lời gọi ra ngoài là kéo theo cả tầng ngôn ngữ vào
// một extension chỉ được cấp vài chục MB bộ nhớ.
// ════════════════════════════════════════════════════════════════

struct AnhChupTien: Codable, Equatable {
    var luc: Date = Date()

    /// Số THÔ — widget cần để vẽ thanh tiến độ và so sánh.
    var chiHomNay: Double = 0
    var hanMucNgay: Double?
    var duNoSo: Double = 0

    /// Chuỗi ĐÃ ĐỊNH DẠNG — app định dạng, widget chỉ vẽ. Giữ bộ định dạng
    /// ở MỘT nơi; chép sang widget là để hai bản trôi khỏi nhau, rồi một
    /// hôm widget hiện "1.5tr" còn app hiện "1,5 tr".
    var duNo: String = "0₫"
    var laiMoiThang: String = "0₫"
    var chiHomNayChu: String = "0₫"
    var hanMucNgayChu: String?
    /// "Chi hôm nay" hay "Chi tháng này" — tuỳ đã đặt mục tiêu ngày chưa.
    var nhanChi: String = "Chi hôm nay"

    var kyToi: [Ky] = []

    struct Ky: Codable, Equatable, Identifiable, Hashable {
        var id: Int            // id của kỳ trong lịch trả
        var debtId: Int
        var ten: String
        var soTien: String
        var ngay: Date
        var quaHan: Bool
    }

    /// Đã bao nhiêu phần trăm hạn mức ngày. `nil` khi chưa đặt hạn mức.
    var tiLeHanMuc: Double? {
        guard let h = hanMucNgay, h > 0 else { return nil }
        return min(chiHomNay / h, 1)
    }
}

enum KhoAnhChupTien {
    /// Phải khớp ĐÚNG chuỗi trong entitlements của cả app lẫn widget. Sai
    /// một ký tự thì `containerURL` trả `nil` và widget im lặng hiện rỗng —
    /// không lỗi, không log, không có gì để lần ra.
    static let nhom = "group.com.cuongthai.app"

    private static var duong: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: nhom)?
            .appendingPathComponent("tien-nong.json")
    }

    static func doc() -> AnhChupTien? {
        guard let u = duong, let d = try? Data(contentsOf: u) else { return nil }
        let bo = JSONDecoder()
        bo.dateDecodingStrategy = .iso8601
        return try? bo.decode(AnhChupTien.self, from: d)
    }

    @discardableResult
    static func ghi(_ a: AnhChupTien) -> Bool {
        guard let u = duong else { return false }
        let ma = JSONEncoder()
        ma.dateEncodingStrategy = .iso8601
        guard let d = try? ma.encode(a) else { return false }
        do { try d.write(to: u, options: .atomic); return true }
        catch { return false }
    }
}
