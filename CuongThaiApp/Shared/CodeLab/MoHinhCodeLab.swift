import Foundation

// MARK: - Code Lab
//
// Kho lớn nhất của cả nền tảng mà app chưa hề đụng tới. Đo thật 22/08/2026 qua
// `/code-lab/stats`: 12 nhóm · 146 lộ trình · 2.122 mô-đun · **12.549 bài tập**
// (2.381 EASY · 7.563 MEDIUM · 2.605 HARD).
//
// ⚠️ **Danh sách trả về TOÀN BỘ đối tượng**, kể cả HTML đề bài và mã lời giải:
// 20 bài ≈ 296KB, 50 bài ≈ 687KB. Vì thế giữ trang ở 20 và KHÔNG tăng.
// Bù lại: mở chi tiết KHÔNG cần gọi mạng lần hai, mọi thứ đã nằm sẵn trong
// đối tượng của danh sách.
//
// ⚠️ **Đề bài tập CHƯA hề có bản tiếng Việt.** Đo lại 23/08/2026 trên 2.849
// bài — 1.500 trang mới nhất + 1.349 trang cũ nhất, rải khắp 40+ lộ trình:
// `problemHtmlVi` và `solutionExplanationHtmlVi` null **100%**. Nên nút EN/VI
// của màn bài tập gần như không bao giờ hiện, đúng như web (`LangSwitch` chỉ
// vẽ khi `ex.problemHtmlVi` có giá trị). Bản dịch nằm ở BÀI HỌC, không ở đề.

struct TrangBaiTapCode: Codable {
    let exercises: [BaiTapCode]
    let total: Int
    let page: Int
    let totalPages: Int
}

struct BaiTapCode: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String
    let title: String
    let difficulty: String?
    let language: String?
    let estimatedMinutes: Int?
    /// Để `Double?` chứ không `Int?`: máy chủ hiện gửi số nguyên, nhưng cột
    /// điểm kiểu thập phân mà đổi sang 10.5 thì `Int?` **ném lỗi decode**,
    /// khác hẳn trả `nil` — cả màn hình trắng vì một chữ số.
    let points: Double?
    let tags: [String]?
    let concepts: [String]?

    let problemHtml: String?
    /// Luôn null khi đo 22/08 — xem ghi chú đầu file.
    let problemHtmlVi: String?
    let constraints: String?
    let inputSpec: String?
    let outputSpec: String?

    let examplesJson: [ViDu]?
    let hintsJson: [String]?
    let starterCodeJson: [KhoiMa]?
    let solutionCodeJson: [KhoiMa]?
    let solutionExplanationHtml: String?
    let solutionExplanationHtmlVi: String?

    let diagramMermaid: String?
    let youtubeUrl: String?
    let solveCount: Int?
    let viewCount: Int?
    let track: Nhan?
    let module: Nhan?

    struct ViDu: Codable, Hashable, Identifiable {
        let input: String?
        let output: String?
        let explanation: String?
        var id: String { (input ?? "") + (output ?? "") }
    }
    struct KhoiMa: Codable, Hashable, Identifiable {
        let code: String?
        let name: String?
        let language: String?
        var id: String { (name ?? "") + (language ?? "") }
    }
    /// ⚠️ Trường là **`name`**, KHÔNG phải `title` — giống `LoTrinhCode`.
    /// Đo thật: `module` = `{id, name, slug}`, `track` = `{id, name, slug,
    /// language, color, groupId}`. Khai `title` thì decode vẫn xanh mà tên
    /// luôn rỗng. Giữ `title` lại để lỡ chỗ nào backend dùng tên đó.
    struct Nhan: Codable, Hashable {
        let id: Int?
        let name: String?
        let title: String?
        let slug: String?
        let color: String?

        var ten: String? {
            let t = name ?? title
            return (t?.isEmpty == false) ? t : nil
        }
    }

    var doKho: DoKho { DoKho(difficulty) }

    /// Theo ngôn ngữ đang đọc, rơi về tiếng Anh theo TỪNG TRƯỜNG.
    func deBai(_ n: NgonNguDe) -> String { problemHtml.theo(n, viet: problemHtmlVi) }
    func giaiThich(_ n: NgonNguDe) -> String? {
        let v = solutionExplanationHtml.theo(n, viet: solutionExplanationHtmlVi)
        return v.isEmpty ? nil : v
    }
    /// Quyết định CÓ HIỆN nút EN/VI. Ngày backend điền bản dịch là nút tự mọc,
    /// không phải sửa app.
    var coTiengViet: Bool {
        (problemHtmlVi?.isEmpty == false) || (solutionExplanationHtmlVi?.isEmpty == false)
    }
    var phut: Int { estimatedMinutes ?? 0 }
    var diem: Int { Int(points ?? 0) }
}

enum DoKho: String, CaseIterable {
    case de = "EASY", vua = "MEDIUM", kho = "HARD"

    init(_ raw: String?) { self = DoKho(rawValue: (raw ?? "").uppercased()) ?? .vua }

    var ten: String {
        switch self {
        case .de: return "Dễ"
        case .vua: return "Vừa"
        case .kho: return "Khó"
        }
    }
    var mau: UInt32 {
        switch self {
        case .de: return 0x2BA84A
        case .vua: return 0xD97706
        case .kho: return 0xE5484D
        }
    }
}

// MARK: - Nhóm và lộ trình
//
// Đo thật 22/08/2026: **12 nhóm · 72 lộ trình**. Nhóm lớn nhất là "CuongThai"
// (22 lộ trình · 3.155 bài). Cấp: BEGINNER 56 · INTERMEDIATE 15 · ADVANCED 1.

struct NhomCodeLab: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String?
    let description: String?
    let icon: String?
    /// Mã màu hex kiểu `#e11d48` — web dùng chính giá trị này.
    let color: String?
    let tracks: [LoTrinhCode]?

    var dsLoTrinh: [LoTrinhCode] { tracks ?? [] }
    var soBai: Int { dsLoTrinh.reduce(0) { $0 + $1.soBai } }

    /// Tên icon của web (`star`, `backend`, `devops`…) sang SF Symbol.
    var bieuTuong: String {
        switch icon ?? "" {
        case "star": return "star.fill"
        case "languages": return "chevron.left.forwardslash.chevron.right"
        case "backend": return "server.rack"
        case "frontend": return "macwindow"
        case "database": return "cylinder.split.1x2.fill"
        case "mobile": return "iphone"
        case "devops": return "shippingbox.fill"
        case "algorithms": return "function"
        case "game": return "gamecontroller.fill"
        case "web": return "globe"
        case "credit-card": return "creditcard.fill"
        case "fptu": return "building.columns.fill"
        default: return "folder.fill"
        }
    }
}

struct LoTrinhCode: Codable, Identifiable, Hashable {
    let id: Int
    /// ⚠️ Trường là **`name`**, KHÔNG phải `title`. Bản đầu tôi khai `title` —
    /// backend trả `null` cho nó nên mọi lộ trình sẽ hiện tên TRỐNG, mà decode
    /// vẫn xanh vì optional.
    let name: String?
    let slug: String?
    let description: String?
    let language: String?
    let level: String?
    let color: String?
    let exerciseCount: Int?
    let moduleCount: Int?

    var ten: String { name ?? slug ?? "Lộ trình" }
    var soBai: Int { exerciseCount ?? 0 }
    var soChuong: Int { moduleCount ?? 0 }
    var cap: CapDoLoTrinh { CapDoLoTrinh(level) }

    /// ⚠️ Mô tả mở đầu bằng **`⟦ctv⟧`** nghĩa là "CuongThai kiểm chứng" — web
    /// cắt tiền tố đó ra và vẽ thành huy hiệu. Đo thật: 44/72 lộ trình có nó.
    /// Không cắt thì người dùng đọc thấy một chuỗi ký hiệu lạ ngay đầu dòng.
    private static let dauKiemChung = "⟦ctv⟧"
    var kiemChung: Bool { (description ?? "").hasPrefix(Self.dauKiemChung) }
    var moTa: String {
        (description ?? "")
            .replacingOccurrences(of: Self.dauKiemChung, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Chữ cái đầu làm biểu tượng. Backend KHÔNG trả icon hay ảnh bìa cho lộ
    /// trình (đo: `icon` null 72/72, `coverImageUrl` 0/72) — web dùng logo
    /// thương hiệu lấy từ tài nguyên riêng của nó, app không có bộ đó.
    var chuDau: String {
        let s = ten.trimmingCharacters(in: .whitespaces)
        guard let c = s.first else { return "?" }
        // MỘT chữ cái thôi. Lấy hai chữ ra "NO" cho Node.js và "PO" cho
        // PostgreSQL — đọc thành từ có nghĩa khác, trông như lỗi.
        return String(c).uppercased()
    }

    /// `#336791` → 0x336791. Hỏng thì về màu trung tính chứ không nhuộm bừa.
    var mau: UInt32 {
        let h = (color ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        return h.count == 6 ? (UInt32(h, radix: 16) ?? 0x64748B) : 0x64748B
    }
}

enum CapDoLoTrinh: String {
    case coBan = "BEGINNER", trungCap = "INTERMEDIATE", nangCao = "ADVANCED"

    init(_ raw: String?) { self = CapDoLoTrinh(rawValue: (raw ?? "").uppercased()) ?? .coBan }

    var ten: String {
        switch self {
        case .coBan: return "Cơ bản"
        case .trungCap: return "Trung cấp"
        case .nangCao: return "Nâng cao"
        }
    }
    var mau: UInt32 {
        switch self {
        case .coBan: return 0x2BA84A
        case .trungCap: return 0xD97706
        case .nangCao: return 0xE5484D
        }
    }
}


/// `/code-lab/stats` — con số CHÍNH THỨC của kho.
///
/// ⚠️ Cộng dồn `exerciseCount` của các lộ trình trong `/groups` KHÔNG ra con
/// số này (đo 22/08: cộng dồn 10.626 vs stats 12.549) — `/groups` chỉ trả lộ
/// trình đã xuất bản và có nhóm, còn stats đếm toàn bộ. Lấy số từ đây, đừng
/// tự cộng: hai chỗ trên cùng một màn hình nói hai con số là người dùng mất
/// tin ngay.
struct ThongKeCodeLab: Codable {
    let groups: Int?
    let tracks: Int?
    let modules: Int?
    let exercises: Int?
}
