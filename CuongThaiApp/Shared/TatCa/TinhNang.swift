import SwiftUI

// ════════════════════════════════════════════════════════════════
// BẢNG ĐĂNG KÝ TÍNH NĂNG — MỘT CHỖ DUY NHẤT (22/10/2026)
//
// Thanh tab chỉ còn 5 điểm đến chính (Hôm nay · Bảng tin · Học · Tin nhắn ·
// Tôi). MỌI thứ khác là một `TinhNang` ở đây: màn "Tất cả tính năng", lưới
// "Đi nhanh" của Hôm nay, thanh bên iPad, tìm kiếm ⌘K, link `cuongthai://`
// và thông báo đẩy đều đọc CHÍNH enum này — thêm tính năng mới là thêm MỘT
// `case` rồi điền đủ các `switch` (trình biên dịch bắt chỗ thiếu), không phải
// đi sửa năm danh sách song song rồi quên một cái.
//
// ⚠️ `rawValue` là KHOÁ LƯU (danh sách ghim trong UserDefaults, giá trị cửa sổ
// phụ). Đổi tên một `case` thì được, đổi `rawValue` là người dùng mất ghim.
// ⚠️ Màn hình KHÔNG dựng ở đây — chỉ mô tả. Màn dựng lười trong `ManTinhNang`
// (một `switch` @ViewBuilder), nên mở danh mục không khởi tạo 25 màn.
// ════════════════════════════════════════════════════════════════

enum TinhNang: String, CaseIterable, Identifiable, Codable, Hashable {
    // Học tập
    case hocKy = "hoc-ky"
    case thoiKhoaBieu = "thoi-khoa-bieu"
    case academy
    /// Chương trình đào tạo 4 năm · 15 kỳ (/courses của web) — 22/10/2026.
    case chuongTrinh = "chuong-trinh"
    case khoaHocCuaToi = "khoa-hoc-cua-toi"
    case ielts
    case ngoaiNgu = "ngoai-ngu"
    /// Khoá できる日本語 Bài 0–15 (giáo trình JPD113/JPD123), bản native — 23/10/2026.
    case dekiru
    /// Sách IELTS nền tảng 15 ngày (khoá kiểu sách, bản native) — 23/10/2026.
    case ieltsNenTang = "ielts-nen-tang"
    case videoHoc = "video-hoc"
    case thuVienSach = "thu-vien-sach"
    // Luyện tập & nghề nghiệp
    case phongThi = "phong-thi"
    case codeLab = "code-lab"
    case thuatToan = "thuat-toan"
    case moPhong = "mo-phong"
    case snippets
    case loTrinh = "lo-trinh"
    case duAn = "du-an"
    case phongVan = "phong-van"
    case cvBuilder = "cv"
    // Công cụ cá nhân
    case vo
    case notes
    case aiChat = "ai-chat"
    case tienNong = "tien-nong"
    case thongBao = "thong-bao"
    // Sáng tạo
    case xuongVe = "xuong-ve"
    case xuongBa = "xuong-3d"
    // Khác
    case ctWork = "ct-work"
    case caiDat = "cai-dat"

    var id: String { rawValue }

    /// Mục ghim sẵn cho người chưa từng chỉnh — sáu việc của một ngày đi học.
    static let ghimMacDinh: [TinhNang] = [.hocKy, .thoiKhoaBieu, .vo, .aiChat, .phongThi, .codeLab]

    // MARK: Nhóm

    enum Nhom: Int, CaseIterable, Identifiable {
        case hocTap, luyenVaNghe, congCu, sangTao, khac
        var id: Int { rawValue }
        var ten: String {
            switch self {
            case .hocTap: return T("Học tập")
            case .luyenVaNghe: return T("Luyện tập & nghề nghiệp")
            case .congCu: return T("Công cụ cá nhân")
            case .sangTao: return T("Sáng tạo")
            case .khac: return T("Khác")
            }
        }
    }

    var nhom: Nhom {
        switch self {
        case .hocKy, .thoiKhoaBieu, .academy, .chuongTrinh, .khoaHocCuaToi, .ielts, .ngoaiNgu, .dekiru, .ieltsNenTang, .videoHoc, .thuVienSach:
            return .hocTap
        case .phongThi, .codeLab, .thuatToan, .moPhong, .snippets, .loTrinh, .duAn, .phongVan, .cvBuilder:
            return .luyenVaNghe
        case .vo, .notes, .aiChat, .tienNong, .thongBao:
            return .congCu
        case .xuongVe, .xuongBa:
            return .sangTao
        case .ctWork, .caiDat:
            return .khac
        }
    }

    // MARK: Cách mở

    enum CachMo: Equatable {
        /// Đẩy vào stack đang có (iPhone) / cột chi tiết (iPad). Màn KHÔNG
        /// được mang `NavigationStack` riêng — xem `ManTinhNang`.
        case day
        /// Màn tự mang thanh "Đóng"/stack riêng ⇒ trình bày từ GỐC (`MainView`).
        case trinhBay
        /// Mở ra NGOÀI app (app CT Work riêng / App Store).
        case ngoai
    }

    var cachMo: CachMo {
        switch self {
        case .aiChat, .notes, .thongBao, .caiDat: return .trinhBay
        case .ctWork: return .ngoai
        default: return .day
        }
    }

    // MARK: Hiển thị

    var ten: String {
        switch self {
        case .hocKy: return T("Học kỳ")
        case .thoiKhoaBieu: return T("Thời khoá biểu")
        case .academy: return "Academy"
        case .chuongTrinh: return T("Chương trình đào tạo")
        case .khoaHocCuaToi: return T("Khoá học của tôi")
        case .ielts: return "IELTS"
        case .ngoaiNgu: return T("Ngoại ngữ")
        case .dekiru: return T("Tiếng Nhật できる")
        case .ieltsNenTang: return T("IELTS nền tảng 15 ngày")
        case .videoHoc: return T("Học bằng video")
        case .thuVienSach: return T("Thư viện sách")
        case .phongThi: return T("Phòng thi")
        case .codeLab: return "Code Lab"
        case .thuatToan: return T("Thuật toán")
        case .moPhong: return T("Mô phỏng")
        case .snippets: return "Snippets"
        case .loTrinh: return T("Lộ trình")
        case .duAn: return T("Dự án")
        case .phongVan: return T("Phỏng vấn")
        case .cvBuilder: return "CV Builder"
        case .vo: return T("Vở")
        case .notes: return T("Ghi chú")
        case .aiChat: return "AI Chat"
        case .tienNong: return T("Tiền nong")
        case .thongBao: return T("Thông báo")
        case .xuongVe: return T("Xưởng vẽ")
        case .xuongBa: return T("Xưởng 3D")
        case .ctWork: return "CT Work"   // tên sản phẩm, không dịch
        case .caiDat: return T("Cài đặt")
        }
    }

    var moTa: String {
        switch self {
        case .hocKy: return T("Việc AI giao, điểm, tỷ lệ trượt")
        case .thoiKhoaBieu: return T("Lịch học, lịch thi trong tuần")
        case .academy: return T("Chương trình đại học theo kỳ")
        case .chuongTrinh: return T("4 năm · 15 kỳ, nền tảng tới chuyên gia")
        case .khoaHocCuaToi: return T("Khoá đang học, tiến độ")
        case .ielts: return T("Nghe, nói, đọc, viết")
        case .ngoaiNgu: return T("Từ vựng, thẻ ghi nhớ, ôn tập")
        case .dekiru: return T("Bài 0–15 theo sách trên lớp: kana, ngữ pháp, nghe, nói")
        case .ieltsNenTang: return T("Sách 4 kỹ năng: nghe như đề thật, phát âm + nói + viết có máy chấm")
        case .videoHoc: return T("Học tiếng Anh qua video")
        case .thuVienSach: return T("Sách song ngữ Anh–Việt")
        case .phongThi: return T("Đề thi thật, bấm giờ")
        case .codeLab: return T("Bài tập lập trình, 9 ngôn ngữ")
        case .thuatToan: return T("Chạy thuật toán từng bước")
        case .moPhong: return T("Kịch bản mô phỏng tương tác")
        case .snippets: return T("Lệnh cài môi trường, chép một chạm")
        case .loTrinh: return T("Lộ trình nghề, đánh dấu từng bước")
        case .duAn: return T("Dự án mẫu: mốc, tính năng, schema")
        case .phongVan: return T("Mô phỏng phỏng vấn, chấm điểm")
        case .cvBuilder: return T("Soạn CV, soi lỗi, chấm AI")
        case .vo: return T("Vở viết tay theo môn")
        case .notes: return T("Ghi chú theo môn học")
        case .aiChat: return T("Hỏi đáp, giải bài, đọc ảnh")
        case .tienNong: return T("Chi tiêu, nợ, mục tiêu")
        case .thongBao: return T("Bình luận, cảm xúc, lời mời")
        case .xuongVe: return T("Vẽ, phác bố cục, tô màu")
        case .xuongBa: return T("Ghép khối thành mô hình 3D")
        case .ctWork: return T("Mở app CT Work riêng")
        case .caiDat: return T("Tài khoản, giao diện, ngôn ngữ")
        }
    }

    var bieuTuong: String {
        switch self {
        case .hocKy: return "target"
        case .thoiKhoaBieu: return "calendar"
        case .academy: return "building.columns.fill"
        case .chuongTrinh: return "books.vertical"
        case .khoaHocCuaToi: return "book.closed.fill"
        case .ielts: return "textformat.abc"
        case .ngoaiNgu: return "character.book.closed.fill"
        case .dekiru: return "character.ja"
        case .ieltsNenTang: return "book.pages"
        case .videoHoc: return "play.rectangle.fill"
        case .thuVienSach: return "books.vertical.fill"
        case .phongThi: return "checklist"
        case .codeLab: return "chevron.left.forwardslash.chevron.right"
        case .thuatToan: return "chart.bar.xaxis"
        case .moPhong: return "waveform.path.ecg.rectangle"
        case .snippets: return "curlybraces"
        case .loTrinh: return "map.fill"
        case .duAn: return "hammer.fill"
        case .phongVan: return "person.crop.rectangle.stack.fill"
        case .cvBuilder: return "doc.text.fill"
        case .vo: return "pencil.and.scribble"
        case .notes: return "note.text"
        case .aiChat: return "sparkles"
        case .tienNong: return "creditcard.fill"
        case .thongBao: return "bell.fill"
        case .xuongVe: return "paintbrush.pointed.fill"
        case .xuongBa: return "cube.transparent.fill"
        case .ctWork: return "rectangle.3.group.fill"
        case .caiDat: return "gearshape.fill"
        }
    }

    /// Màu của ô biểu tượng. Lấy từ bảng màu của app (đã chỉnh cho cả sáng lẫn
    /// tối, đủ tương phản) — không tự chế mã màu mới ở đây.
    var mau: Color {
        switch self {
        case .hocKy, .phongThi: return AppColors.error
        case .thoiKhoaBieu, .academy, .codeLab, .ctWork: return AppColors.primary
        case .khoaHocCuaToi, .duAn, .tienNong, .chuongTrinh: return AppColors.accent
        case .ielts, .videoHoc, .xuongBa, .dekiru, .ieltsNenTang: return AppColors.brandPink
        case .ngoaiNgu, .thuVienSach, .moPhong, .xuongVe: return AppColors.secondary
        case .thuatToan, .snippets, .cvBuilder: return AppColors.info
        case .loTrinh, .phongVan, .notes: return AppColors.success
        case .vo, .thongBao: return AppColors.warning
        case .aiChat: return AppColors.primaryLight
        case .caiDat: return AppColors.textSecondary
        }
    }

    /// Từ khoá phụ cho ô tìm (không dấu, cả tiếng Anh) — người ta gõ "money"
    /// hay "chi tieu" chứ không nhớ đúng chữ "Tiền nong".
    var tuKhoaPhu: [String] {
        switch self {
        case .hocKy: return ["semester", "coach", "huan luyen", "diem", "ty le truot"]
        case .thoiKhoaBieu: return ["lich", "schedule", "timetable", "calendar", "tkb", "lich thi"]
        case .academy: return ["fpt", "dai hoc", "mon hoc", "university", "nganh"]
        case .chuongTrinh: return ["khoa hoc", "courses", "curriculum", "lo trinh hoc", "hoc ky", "chuyen nganh", "sap ra mat"]
        case .khoaHocCuaToi: return ["my courses", "khoa hoc", "tien do"]
        case .ielts: return ["english", "tieng anh", "band"]
        case .ngoaiNgu: return ["language", "tu vung", "flashcard", "tieng nhat", "tieng trung"]
        case .ieltsNenTang: return ["ielts", "nen tang", "15 ngay", "tieng anh", "english", "phat am", "speaking", "writing", "sach"]
        case .dekiru: return ["dekiru", "tieng nhat", "japanese", "jpd113", "jpd123", "kana", "hiragana", "katakana", "nihongo", "nhat"]
        case .videoHoc: return ["video", "youtube", "nghe chep"]
        case .thuVienSach: return ["book", "library", "doc sach", "sach"]
        case .phongThi: return ["exam", "de thi", "thi thu", "quiz"]
        case .codeLab: return ["code", "lap trinh", "bai tap", "programming"]
        case .thuatToan: return ["algorithm", "sap xep", "do thi"]
        case .moPhong: return ["simulation", "kich ban"]
        case .snippets: return ["lenh", "cai dat moi truong", "command"]
        case .loTrinh: return ["roadmap", "nghe nghiep", "career"]
        case .duAn: return ["project", "schema"]
        case .phongVan: return ["interview", "mock"]
        case .cvBuilder: return ["resume", "cv", "xin viec", "thu xin viec"]
        case .vo: return ["notebook", "viet tay", "handwriting", "pencil"]
        case .notes: return ["note", "ghi chep"]
        case .aiChat: return ["ai", "chat", "tro ly", "cuongmini", "hoi dap", "assistant"]
        case .tienNong: return ["money", "finance", "chi tieu", "no", "vi", "tien"]
        case .thongBao: return ["notification", "chuong", "bell"]
        case .xuongVe: return ["draw", "ve", "sketch", "canvas"]
        case .xuongBa: return ["3d", "mo hinh", "model", "ar"]
        case .ctWork: return ["jira", "du an nhom", "task", "issue", "ctwork"]
        case .caiDat: return ["settings", "tai khoan", "giao dien", "ngon ngu", "dang xuat"]
        }
    }

    // MARK: Tìm

    /// Bỏ dấu + chữ thường. "đ" phải tự đổi: `diacriticInsensitive` coi "đ"
    /// là một chữ riêng chứ không phải "d" có dấu.
    static func chuanHoa(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                  locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Mục khớp từ khoá, xếp theo độ khớp: tên bắt đầu bằng từ khoá → tên chứa
    /// → mô tả/từ khoá phụ chứa. Chuỗi rỗng ⇒ `[]` (màn gọi tự quyết hiện gì).
    static func tim(_ q: String, trong ds: [TinhNang] = TinhNang.allCases) -> [TinhNang] {
        let k = chuanHoa(q)
        guard !k.isEmpty else { return [] }
        var diem: [(TinhNang, Int)] = []
        for f in ds {
            let ten = chuanHoa(f.ten)
            // Khớp cả tên tiếng Việt GỐC (người dùng bật tiếng Anh vẫn gõ được "vở").
            let tenGoc = chuanHoa(f.rawValue.replacingOccurrences(of: "-", with: " "))
            let tu = ten.split(separator: " ")
            // Trùng NGUYÊN một từ của tên đứng trước khớp đầu từ: "tien" ⇒ "Tiền nóng" trước "Tiếng Nhật".
            if tu.contains(where: { $0 == k }) {
                diem.append((f, 0))
            } else if ten.hasPrefix(k) || tu.contains(where: { $0.hasPrefix(k) }) {
                diem.append((f, 1))
            } else if ten.contains(k) || tenGoc.contains(k) {
                diem.append((f, 2))
            } else if chuanHoa(f.moTa).contains(k) || f.tuKhoaPhu.contains(where: { $0.contains(k) }) {
                diem.append((f, 3))
            }
        }
        return diem.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.thuTu < $1.0.thuTu }.map(\.0)
    }

    /// Thứ tự khai báo — để kết quả cùng hạng không nhảy lung tung.
    var thuTu: Int { TinhNang.allCases.firstIndex(of: self) ?? 0 }
}
