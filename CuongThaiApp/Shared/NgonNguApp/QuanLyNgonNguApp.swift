import SwiftUI

// ════════════════════════════════════════════════════════════════
// NGÔN NGỮ GIAO DIỆN — Tiếng Việt ⇄ English
//
// ⚠️ CỐ Ý không dùng `Localizable.xcstrings` của Apple. Hai lý do đo được:
//
// 1. Đổi ngôn ngữ bằng bộ máy của Apple cần **khởi động lại app** (hoặc phải
//    tráo `Bundle` bằng thủ thuật swizzle). Người dùng bấm trong Cài đặt thì
//    phải thấy đổi NGAY.
// 2. App có **1.592 chuỗi tiếng Việt (1.249 chuỗi khác nhau) nằm rải ở
//    112/134 file** — đo 24/08/2026. Chuyển sang khoá kiểu `"post.create"`
//    là phải sửa đúng 1.592 chỗ và mỗi chỗ đều có thể gõ sai khoá mà build
//    vẫn xanh.
//
// Cách ở đây: **chính chuỗi tiếng Việt là khoá**. Gói lại thành `T("Đăng")`.
// Ba cái lợi:
//   · Di chuyển từng chỗ một, không cần đổi hết mới chạy được.
//   · Chỗ nào chưa dịch thì vẫn ra tiếng Việt — không bao giờ ra khoá thô
//     kiểu "post.create" giữa màn hình.
//   · Bảng dịch nằm một chỗ, dễ soát còn thiếu gì.
// ════════════════════════════════════════════════════════════════

enum NgonNguApp: String, CaseIterable, Identifiable {
    case viet = "vi"
    case anh = "en"

    var id: String { rawValue }

    /// Tên hiện trong Cài đặt — LUÔN viết bằng chính thứ tiếng đó, để người
    /// đang lạc trong giao diện tiếng lạ vẫn nhận ra dòng của mình.
    var ten: String {
        switch self {
        case .viet: return "Tiếng Việt"
        case .anh: return "English"
        }
    }

    var co: String {
        switch self {
        case .viet: return "🇻🇳"
        case .anh: return "🇬🇧"
        }
    }
}

/// Khoá lưu trong `UserDefaults`.
private let khoaNgonNguApp = "app.ngonNgu"

/// Ngôn ngữ đang chọn, đọc được từ MỌI luồng.
///
/// ⚠️ CỐ Ý không đi qua `QuanLyNgonNguApp.shared`. Lớp đó là `@MainActor`
/// (nó phải vậy, vì `@Published` lái SwiftUI), nên `T(...)` gọi vào nó cũng
/// hoá `@MainActor` — và thế là hỏng ngay ở những chỗ Swift cần giá trị
/// ĐỒNG BỘ, ví dụ giá trị mặc định của tham số:
///
///     init(_ message: String = T("Đang tải..."))   // ❌ không biên dịch
///
/// `UserDefaults` vốn an toàn nhiều luồng và đọc rất rẻ, nên đọc thẳng.
private func ngonNguDangDung() -> NgonNguApp {
    NgonNguApp(rawValue: UserDefaults.standard.string(forKey: khoaNgonNguApp) ?? "") ?? .viet
}

@MainActor
final class QuanLyNgonNguApp: ObservableObject {
    static let shared = QuanLyNgonNguApp()

    @Published var ngonNgu: NgonNguApp {
        didSet {
            guard ngonNgu != oldValue else { return }
            UserDefaults.standard.set(ngonNgu.rawValue, forKey: khoaNgonNguApp)
        }
    }

    /// Mặc định TIẾNG VIỆT: đây là app cho người Việt, và mọi nội dung do máy
    /// chủ trả về (nghĩa từ vựng, giải thích ngữ pháp, lời phê của AI) đều là
    /// tiếng Việt. Bật tiếng Anh là lựa chọn, không phải mặc định.
    private init() { ngonNgu = ngonNguDangDung() }
}

/// Gói một chuỗi hiển thị. Dùng ở MỌI chỗ chữ hiện ra cho người dùng.
///
/// Không có trong bảng ⇒ trả nguyên bản tiếng Việt, nên dịch dở vẫn dùng được
/// và không bao giờ lòi khoá thô ra màn hình.
///
/// ⚠️ ĐỪNG gói những chuỗi KHÔNG phải chữ hiển thị: tên SF Symbol, khoá
/// `UserDefaults`, mã gửi lên máy chủ. Xem
/// [[feedback_enum_hien_thi_dung_lam_ma_gui_len]] — đúng cái bẫy đó đã làm
/// mọi bài đăng từ app chỉ tác giả nhìn thấy.
func T(_ vi: String) -> String {
    ngonNguDangDung() == .anh ? (BangDich.anh[vi] ?? vi) : vi
}
