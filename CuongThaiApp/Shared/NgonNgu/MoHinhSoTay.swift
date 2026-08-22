import SwiftUI

// MARK: - Sổ tay ngôn ngữ
//
// Thư mục lồng nhau (`parentId` tự trỏ) + các mục, riêng theo TỪNG NGƯỜI và
// TỪNG NGÔN NGỮ. Máy chủ lấy `userId` từ phiên và kiểm quyền sở hữu ở mọi thao
// tác — client không bao giờ chọn được sổ tay của người khác.
//
// ⚠️ Mọi trường ngày để kiểu `String`: `APIClient` dùng `JSONDecoder()` trần
// nên `Date` sẽ hỏng decode. Dùng `Date.tuChuoiISO(_:)` khi cần so sánh.

struct CaySoTay: Codable {
    let language: NgonNgu
    let folders: [ThuMucSoTay]
    let entries: [MucSoTayGon]
}

struct ThuMucSoTay: Codable, Identifiable, Hashable {
    let id: Int
    let parentId: Int?
    let name: String
    let icon: String?
    let sortOrder: Int
}

/// Mục ở dạng danh sách — máy chủ CỐ Ý không trả `body`/`meaning` ở cây, để
/// một sổ tay vài trăm mục không kéo theo vài trăm đoạn markdown.
struct MucSoTayGon: Codable, Identifiable, Hashable {
    let id: Int
    let folderId: Int?
    let kind: String
    let title: String
    let reading: String?
    let updatedAt: String
    let nextReviewAt: String?

    var loai: LoaiMuc { LoaiMuc(kind) }

    /// Tới hạn ôn khi CHƯA ôn lần nào (`nextReviewAt == nil`) hoặc đã quá hạn.
    /// Cùng quy ước với `listLanguages` ở backend.
    var toiHan: Bool {
        guard let s = nextReviewAt, let d = Date.tuChuoiISO(s) else { return true }
        return d <= Date()
    }
}

/// Mục đầy đủ, lấy ở `GET /notebook/entry/:id`.
struct MucSoTay: Codable, Identifiable {
    let id: Int
    let languageId: Int
    let folderId: Int?
    let kind: String
    let title: String
    let body: String
    let reading: String?
    let meaning: String?
    let nextReviewAt: String?
    let lastReviewedAt: String?
    let repetitions: Int?
    let intervalDays: Int?
    let createdAt: String?
    let updatedAt: String?

    var loai: LoaiMuc { LoaiMuc(kind) }
}

struct NgonNguSoTay: Codable, Identifiable, Hashable {
    let id: Int
    let code: String
    let name: String
    let flagEmoji: String?
    let entryCount: Int
    let dueCount: Int
}

// MARK: - Loại mục

/// Danh sách trắng của backend (`ENTRY_KINDS`). Gửi giá trị ngoài danh sách
/// này thì máy chủ **âm thầm bỏ qua** trường `kind` chứ không báo lỗi — nên
/// đừng bịa thêm loại ở client.
enum LoaiMuc: String, CaseIterable {
    case ghiChu = "note"
    case giaiThich = "explanation"
    case tuVung = "vocab"
    case nguPhap = "grammar"
    case phatAm = "pronunciation"
    case tapViet = "writing"
    case dich = "translate"
    case kiemNguPhap = "grammar-check"

    init(_ raw: String) { self = LoaiMuc(rawValue: raw) ?? .ghiChu }

    var ten: String {
        switch self {
        case .ghiChu: return "Ghi chú"
        case .giaiThich: return "Giải thích"
        case .tuVung: return "Từ vựng"
        case .nguPhap: return "Ngữ pháp"
        case .phatAm: return "Phát âm"
        case .tapViet: return "Tập viết"
        case .dich: return "Bản dịch"
        case .kiemNguPhap: return "Sửa ngữ pháp"
        }
    }

    var bieuTuong: String {
        switch self {
        case .ghiChu: return "note.text"
        case .giaiThich: return "lightbulb.fill"
        case .tuVung: return "character.book.closed.fill"
        case .nguPhap: return "text.book.closed.fill"
        case .phatAm: return "waveform"
        case .tapViet: return "pencil.line"
        case .dich: return "arrow.left.arrow.right"
        case .kiemNguPhap: return "checkmark.seal.fill"
        }
    }

    var mau: UInt32 {
        switch self {
        case .ghiChu: return 0x64748B
        case .giaiThich: return 0xD97706
        case .tuVung: return 0x2563EB
        case .nguPhap: return 0x7A45E8
        case .phatAm: return 0x0891B2
        case .tapViet: return 0xDB2777
        case .dich: return 0x8C5AF0
        case .kiemNguPhap: return 0x2BA84A
        }
    }

    /// Loại người dùng tự tạo được. `dich`/`kiemNguPhap` chỉ sinh ra từ nút
    /// "Lưu vào sổ tay" ở màn AI, cho tay chọn thì chỉ gây nhầm.
    static var tuTaoDuoc: [LoaiMuc] {
        [.ghiChu, .tuVung, .nguPhap, .phatAm, .giaiThich, .tapViet]
    }
}

// MARK: - Mức nhớ khi ôn

/// Bốn nút, không sáu — cùng lý lẽ với phần Ôn tập từ vựng: sáu mức làm người
/// ta cân nhắc lâu hơn cả thời gian nhớ ra, mà lúc đó đã nhìn đáp án mấy giây.
/// Giá trị gửi lên là thang SM-2 0-5 của backend.
enum MucNhoSoTay: Int, CaseIterable {
    case quen = 1, kho = 3, duoc = 4, de = 5

    var nhan: String {
        switch self {
        case .quen: return "Quên"
        case .kho: return "Khó"
        case .duoc: return "Được"
        case .de: return "Dễ"
        }
    }

    var mau: UInt32 {
        switch self {
        case .quen: return 0xE5484D
        case .kho: return 0xF59E0B
        case .duoc: return 0x2BA84A
        case .de: return 0x0E93A6
        }
    }
}
