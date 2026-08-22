import Foundation

// MARK: - Chương trình học của một lộ trình
//
// `GET /code-lab/tracks/:slug` trả TRỌN chương trình: đo thật 23/08/2026 với
// `postgresql` — **21 chương, cả 21 đều có bài học**, và bài tập nằm LỒNG
// trong từng chương với `sortOrder` 1,2,3… tức ĐÚNG thứ tự học.
//
// ⚠️ Đây mới là đường đúng để hiện một lộ trình. Dùng `/exercises?trackId=`
// thì chỉ có danh sách phẳng, không có chương, không có bài học, và thứ tự
// mặc định là `createdAt desc` — bài tổng kết cuối khoá nhảy lên đầu.
//
// ⚠️ Bài tập lồng trong chương là bản GỌN (không có đề bài, ví dụ, lời giải).
// Mở một bài phải gọi thêm `/exercises/:slug`.

struct LoTrinhChiTiet: Codable {
    let id: Int
    let name: String?
    let slug: String?
    let description: String?
    let language: String?
    let level: String?
    let color: String?
    let exerciseCount: Int?
    let modules: [ChuongCode]?

    var ten: String { name ?? slug ?? "Lộ trình" }
    var dsChuong: [ChuongCode] {
        (modules ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }
    var cap: CapDoLoTrinh { CapDoLoTrinh(level) }
    var mau: UInt32 {
        let h = (color ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        return h.count == 6 ? (UInt32(h, radix: 16) ?? 0x64748B) : 0x64748B
    }
}

struct ChuongCode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let slug: String?
    let description: String?
    let sortOrder: Int?
    let hasLesson: Bool?
    let exercises: [BaiTapGon]?

    var ten: String { name ?? "Chương" }
    var coBaiHoc: Bool { hasLesson ?? false }
    var dsBai: [BaiTapGon] {
        (exercises ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }
}

/// Bản gọn của bài tập, dùng trong danh sách chương.
struct BaiTapGon: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String?
    let title: String
    let difficulty: String?
    let language: String?
    let estimatedMinutes: Int?
    let points: Double?
    let sortOrder: Int?
    let solveCount: Int?

    var doKho: DoKho { DoKho(difficulty) }
    var phut: Int { estimatedMinutes ?? 0 }
    var diem: Int { Int(points ?? 0) }
}

// MARK: - Bài học của một chương

/// `GET /code-lab/modules/:id/lesson` → `{id, name, lessonGeneratedAt, blocks}`.
///
/// ⚠️ Bài học **CÓ bản tiếng Việt** (`textVi`, `htmlVi`) — khác hẳn bài tập
/// vốn `problemHtmlVi` null 40/40. Nên bài học phải ưu tiên tiếng Việt.
struct BaiHocChuong: Codable {
    let id: Int
    let name: String?
    let lessonGeneratedAt: String?
    let blocks: [KhoiBaiHoc]?

    var dsKhoi: [KhoiBaiHoc] { blocks ?? [] }
}

/// Năm loại khối, đo thật trên 6 chương đầu của PostgreSQL:
/// prose 63 · heading 55 · code 47 · mermaid 16 · links 6.
struct KhoiBaiHoc: Codable, Identifiable, Hashable {
    let type: String?
    let text: String?
    let textVi: String?
    let html: String?
    let htmlVi: String?
    let code: String?
    let title: String?
    let titleVi: String?
    let language: String?
    let items: [LienKet]?

    struct LienKet: Codable, Hashable, Identifiable {
        let url: String?
        let note: String?
        var id: String { (url ?? "") + (note ?? "") }
    }

    /// `Identifiable` bằng nội dung: máy chủ không đánh số khối, mà dùng chỉ
    /// số mảng làm id thì khối bị vẽ lại sai chỗ khi danh sách đổi.
    var id: String {
        [type, text, title, code?.prefix(40).description, html?.prefix(40).description]
            .compactMap { $0 }.joined(separator: "|")
    }

    var loai: LoaiKhoi { LoaiKhoi(rawValue: type ?? "") ?? .chu }

    /// Ưu tiên tiếng Việt, rơi về bản gốc nếu chưa dịch.
    var tieuDeHien: String { (textVi?.isEmpty == false ? textVi : text) ?? "" }
    var htmlHien: String { (htmlVi?.isEmpty == false ? htmlVi : html) ?? "" }
    var tenMaHien: String? {
        let t = (titleVi?.isEmpty == false ? titleVi : title)
        return (t?.isEmpty == false) ? t : nil
    }

    enum LoaiKhoi: String {
        case tieuDe = "heading"
        case chu = "prose"
        case soDo = "mermaid"
        case ma = "code"
        case lienKet = "links"
    }
}

// MARK: - Tiến độ

/// Một dòng tiến độ: `GET /code-lab/progress/mine?trackId=`.
struct TienDoBai: Codable, Hashable {
    let exerciseId: Int
    let status: String?
    let solvedAt: String?
    /// Mã người học đã lưu. Máy chủ chuẩn hoá thành mảng `{name, language,
    /// code}`, tối đa 20 khối — xem `normalizeCodeBlocks`.
    let savedCode: [BaiTapCode.KhoiMa]?

    var daGiai: Bool { (status ?? "").uppercased() == "SOLVED" }
    var maDaLuu: String? {
        let c = savedCode?.first?.code
        return (c?.isEmpty == false) ? c : nil
    }
}

// MARK: - AI chấm mã theo đề bài

/// `POST /code-lab/exercises/:id/coach/check` — gửi mã, AI đối chiếu với TỪNG
/// yêu cầu của đề bài.
///
/// ⚠️ Đây KHÔNG phải chạy mã. Nền tảng không có bộ thực thi; cái này là chấm
/// theo đặc tả. Với người học thì nó nói được nhiều hơn một dòng "sai" — nó
/// chỉ ra yêu cầu nào thiếu và sửa thế nào.
///
/// ⚠️ **Chỉ Pro** (`assertPro`) và tốn AI, nên phải để người dùng tự bấm, đừng
/// gọi tự động. Trần 24.000 ký tự.
struct KetQuaChamMa: Codable {
    let summary: String?
    let summaryVi: String?
    let met: Int?
    let total: Int?
    let items: [MucYeuCau]?
    let risks: [String]?
    let risksVi: [String]?

    var tomTat: String { (summaryVi?.isEmpty == false ? summaryVi : summary) ?? "" }
    var dsRuiRo: [String] { (risksVi?.isEmpty == false ? risksVi : risks) ?? [] }
    var dat: Int { met ?? 0 }
    var tong: Int { total ?? (items?.count ?? 0) }

    struct MucYeuCau: Codable, Identifiable, Hashable {
        let requirement: String?
        let requirementVi: String?
        /// `met` · `partial` · `missing`
        let status: String?
        let evidence: String?
        let evidenceVi: String?
        let fix: String?
        let fixVi: String?

        var id: String { (requirement ?? "") + (status ?? "") }
        var yeuCau: String { (requirementVi?.isEmpty == false ? requirementVi : requirement) ?? "" }
        var bangChung: String { (evidenceVi?.isEmpty == false ? evidenceVi : evidence) ?? "" }
        var cachSua: String { (fixVi?.isEmpty == false ? fixVi : fix) ?? "" }

        var mucDat: MucDat { MucDat(rawValue: (status ?? "").lowercased()) ?? .thieu }
    }

    enum MucDat: String {
        case dat = "met", motPhan = "partial", thieu = "missing"
        var ten: String {
            switch self {
            case .dat: return "Đạt"
            case .motPhan: return "Một phần"
            case .thieu: return "Thiếu"
            }
        }
        var mau: UInt32 {
            switch self {
            case .dat: return 0x2BA84A
            case .motPhan: return 0xD97706
            case .thieu: return 0xE5484D
            }
        }
        var bieuTuong: String {
            switch self {
            case .dat: return "checkmark.circle.fill"
            case .motPhan: return "exclamationmark.circle.fill"
            case .thieu: return "xmark.circle.fill"
            }
        }
    }
}
