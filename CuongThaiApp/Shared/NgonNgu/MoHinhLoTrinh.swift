import SwiftUI

// MARK: - Lộ trình học
//
// Backend trả về ở `GET /api/v1/my-language/:code/roadmap` (optionalAuth).
// Đo thật 22/08/2026: en 6 chặng/38 nút · ja 6/37 · zh 7/36 — tổng 111 nút.
//
// ⚠️ `language` ở đây KHÔNG mang `counts` như `/my-language/` trả về, nên đừng
// dùng nó để quyết định ẩn/hiện mục nào. Mọi trường thừa của `NgonNgu` đều
// optional nên dùng lại được, nhưng `coNoiDung` sẽ luôn false ở đối tượng này.

struct LoTrinh: Codable {
    let language: NgonNgu
    let stages: [ChangLoTrinh]
    let doneNodeIds: [Int]
    let total: Int
}

struct ChangLoTrinh: Codable, Identifiable, Hashable {
    let stage: Int
    let stageLabel: String
    let nodes: [NutLoTrinh]

    var id: Int { stage }
}

struct NutLoTrinh: Codable, Identifiable, Hashable {
    let id: Int
    let stage: Int
    let stageLabel: String
    let order: Int
    let side: String
    let kind: String
    let title: String
    let subtitle: String?
    let level: String?
    let icon: String?
    let description: String?
    let linkType: String?
    let linkRef: String?
}

// MARK: - Vị trí ngang

/// Ba cột của đường đi, tính theo TỈ LỆ bề ngang chứ không phải số điểm cố
/// định — iPhone SE rộng 320pt còn iPad rộng hơn 1000pt, đặt cứng là nút văng
/// ra ngoài hoặc dồn cục vào giữa.
enum CotLoTrinh: String {
    case trai = "left", giua = "center", phai = "right"

    init(_ raw: String) { self = CotLoTrinh(rawValue: raw) ?? .giua }

    var tiLe: CGFloat {
        switch self {
        case .trai: return 0.24
        case .giua: return 0.50
        case .phai: return 0.76
        }
    }
}

// MARK: - Loại nút

/// `kind` từ backend. Đo thật: primary 79 · alternative 28 · info 4.
enum LoaiNut: String {
    /// Chặng bắt buộc — vòng tròn lớn.
    case chinh = "primary"
    /// Học thêm, không bắt buộc — vòng tròn nhỏ hơn, viền đứt.
    case phu = "alternative"
    /// Không phải bài học, chỉ là lời dặn — vẽ thành thẻ chữ, KHÔNG vẽ vòng
    /// tròn. Vẽ tròn thì người ta bấm vào rồi chờ một bài học không tồn tại.
    case ghiChu = "info"

    init(_ raw: String) { self = LoaiNut(rawValue: raw) ?? .chinh }

    var duongKinh: CGFloat {
        switch self {
        case .chinh: return 66
        case .phu: return 52
        case .ghiChu: return 0
        }
    }
}

// MARK: - Loại nội dung nút trỏ tới

/// `linkType` từ backend. Đo thật trên 111 nút: vocab 32 · grammar 17 ·
/// reading 15 · listening 14 · alphabet 10 · conversation 9 · roleplay 6 ·
/// writing 5 · qna 3.
///
/// ⚠️ **Chỉ `vocab` có `linkRef`** (mã chủ đề dạng chuỗi). Tám loại còn lại
/// `linkRef` đều null, nên chúng chỉ mở được màn danh sách chung của loại đó.
enum LoaiNoiDung: String {
    case bangChu = "alphabet"
    case tuVung = "vocab"
    case nguPhap = "grammar"
    case nghe = "listening"
    case hoiThoai = "conversation"
    case baiDoc = "reading"
    case hoiDap = "qna"
    case dongVai = "roleplay"
    case tapViet = "writing"
    case ngoai = "external"

    init?(_ raw: String?) {
        guard let raw, let v = LoaiNoiDung(rawValue: raw) else { return nil }
        self = v
    }

    /// App đã có màn hình cho loại này chưa.
    ///
    /// `nghe` ĐÃ CÓ từ 24/08/2026 (`NgheView`) — trước đó 3 trong 38 nút của
    /// lộ trình tiếng Anh mở ra màn trống. Kho vẫn mỏng và chỉ tiếng Anh mới
    /// có (11 bài; Nhật và Trung đều 0), nhưng 7 bài có lời thoại + bản dịch
    /// và 10 bài có 4 câu hỏi, đủ để học thật.
    ///
    /// `tapViet` thì vẫn CHƯA: 4 nút nữa của lộ trình tiếng Anh. Nó cần
    /// `POST /ai/writing` (AI chấm bài viết), không phải màn viết tay bằng
    /// ngón đã có — hai thứ khác hẳn nhau dù trùng tên.
    var coManHinh: Bool {
        switch self {
        case .tapViet, .ngoai: return false
        default: return true
        }
    }

    var ten: String {
        switch self {
        case .bangChu: return "Bảng chữ"
        case .tuVung: return "Từ vựng"
        case .nguPhap: return "Ngữ pháp"
        case .nghe: return "Luyện nghe"
        case .hoiThoai: return "Hội thoại"
        case .baiDoc: return "Bài đọc"
        case .hoiDap: return "Hỏi đáp"
        case .dongVai: return "Luyện nói với AI"
        case .tapViet: return "Luyện viết"
        case .ngoai: return "Liên kết ngoài"
        }
    }

    /// Giữ đúng màu mà lưới mục ở `NgonNguHomeView` đang dùng, để cùng một
    /// thứ không mang hai màu ở hai chỗ.
    var mau: UInt32 {
        switch self {
        case .bangChu: return 0x8C5AF0
        case .tuVung: return 0x2563EB
        case .nguPhap: return 0x7A45E8
        case .nghe: return 0x0891B2
        case .hoiThoai: return 0x0E93A6
        case .baiDoc: return 0xD97706
        case .hoiDap: return 0x2BA84A
        case .dongVai: return 0xE5484D
        case .tapViet: return 0xDB2777
        case .ngoai: return 0x64748B
        }
    }
}

// MARK: - Biểu tượng

extension NutLoTrinh {
    var loai: LoaiNut { LoaiNut(kind) }
    var cot: CotLoTrinh { CotLoTrinh(side) }
    var noiDung: LoaiNoiDung? { LoaiNoiDung(linkType) }

    var mau: UInt32 { noiDung?.mau ?? 0x64748B }

    /// Mã chủ đề từ vựng, chỉ có ở nút `vocab`.
    var maChuDe: Int? {
        guard noiDung == .tuVung, let s = linkRef else { return nil }
        return Int(s)
    }

    /// Tên biểu tượng SF Symbol.
    ///
    /// ⚠️ Backend trả tên icon của **Lucide** (bộ icon của web) — `BookOpen`,
    /// `GraduationCap`, `Headphones`… Những tên đó KHÔNG tồn tại trong SF
    /// Symbols; đưa thẳng vào `Image(systemName:)` là ra ô trống, không lỗi,
    /// không cảnh báo. Đo thật 22/08 có đúng 10 giá trị, ánh xạ hết ở đây.
    ///
    /// Không khớp thì rơi về biểu tượng theo `linkType` — nó đáng tin hơn vì
    /// backend ràng buộc `linkType` bằng danh sách trắng, còn `icon` là chuỗi
    /// tự do người soạn gõ tay.
    var bieuTuong: String {
        switch icon {
        case "BookOpen": return "book.fill"
        case "GraduationCap": return "graduationcap.fill"
        case "Newspaper": return "newspaper.fill"
        case "Headphones": return "headphones"
        case "Type": return "textformat"
        case "MessagesSquare": return "bubble.left.and.bubble.right.fill"
        case "Bot": return "sparkles"
        case "PenLine": return "pencil.line"
        case "Dumbbell": return "dumbbell.fill"
        case "HelpCircle": return "questionmark.circle.fill"
        default: break
        }
        switch noiDung {
        case .bangChu: return "textformat"
        case .tuVung: return "book.fill"
        case .nguPhap: return "text.book.closed.fill"
        case .nghe: return "headphones"
        case .hoiThoai: return "bubble.left.and.bubble.right.fill"
        case .baiDoc: return "doc.text.fill"
        case .hoiDap: return "questionmark.circle.fill"
        case .dongVai: return "sparkles"
        case .tapViet: return "pencil.line"
        case .ngoai, .none: return "circle.fill"
        }
    }
}
