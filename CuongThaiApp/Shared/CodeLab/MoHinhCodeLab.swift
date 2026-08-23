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
// ⚠️ **Bản dịch đề bài chỉ có ở LAB211** — và suýt kết luận ngược lại.
//
// Lần đo đầu lấy 2.849 bài theo TRANG (1.500 trang mới nhất + 1.349 trang cũ
// nhất) ra `problemHtmlVi` null 100%, nên tôi ghi là "chưa lộ trình nào được
// dịch". Sai: `/exercises` sắp theo `createdAt desc` trên 12.549 bài, và
// LAB211 chỉ có 54 bài nên KHÔNG rơi vào trang nào của mẫu ấy.
//
// Đo lại bằng `trackId` của từng lộ trình (23/08/2026):
//   lab211      54/54 có `problemHtmlVi` VÀ 54/54 có `solutionExplanationHtmlVi`
//   8 lộ trình khác (postgresql, java-core, javascript, react, nextjs,
//   typescript, python, sql) — 0/100 mỗi cái.
//
// Bài học: xem `MoHinhBaiHoc.swift` (phe khác hẳn — postgresql/react/nextjs…
// đều dịch, còn java/python/sql thì không).
//
// ⚠️ **Lấy mẫu theo trang KHÔNG thay được hỏi theo `trackId`.** Một lộ trình
// nhỏ lọt hẳn khỏi mẫu, và con số ra 0% trông rất thuyết phục.

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

    // ── Đề gốc đính kèm ──────────────────────────────────────────
    //
    // ⚠️ Bốn trường này TỪNG BỊ BỎ QUÊN trong mô hình, nên app không hiện đề
    // gốc dù web hiện. Đo 23/08/2026: **54/54 bài lab211 có `briefPdfUrl`**
    // (`media.cuongthai.com/code-lab/lab211/briefs/*.pdf`, tải về HTTP 206
    // `application/pdf`), 45/54 có thêm file Word gốc ở `briefFileUrl`, và
    // 54/54 có `referenceUrl` trỏ sang kho mã tham khảo trên GitHub.
    //
    // ⚠️ Cùng cái bẫy lấy mẫu nói ở đầu file: 0/2.849 bài có đính kèm, chỉ
    // vì lab211 không nằm trong mẫu. Hỏi bằng `trackId` mới ra 54/54.

    /// Đề gốc dạng PDF. Web nhúng bằng `<iframe>` và tự thừa nhận "trên điện
    /// thoại khung này có thể trắng"; app dùng PDFKit nên đọc được thật.
    let briefPdfUrl: String?
    /// File gốc chưa đổi định dạng (thường là .docx). Chỉ đáng hiện khi KHÁC
    /// `briefPdfUrl` — 9/54 bài hai trường trỏ cùng một file.
    let briefFileUrl: String?
    let diagramImageUrl: String?
    let imagesJson: [AnhKem]?
    let referenceUrl: String?
    let githubUrl: String?
    let sourceUrl: String?

    struct AnhKem: Codable, Hashable, Identifiable {
        let url: String?
        let caption: String?
        var id: String { url ?? UUID().uuidString }
    }
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

    var pdfDeGoc: URL? { URL(string: briefPdfUrl ?? "") }
    /// `nil` khi không có file riêng HOẶC khi nó trùng đúng cái PDF đang xem.
    var fileGoc: URL? {
        guard let f = briefFileUrl, !f.isEmpty, f != briefPdfUrl else { return nil }
        return URL(string: f)
    }
    var dsAnh: [AnhKem] { (imagesJson ?? []).filter { $0.url?.isEmpty == false } }
    /// Các đường dẫn ngoài, gộp sẵn để vẽ một khối duy nhất.
    var dsThamKhao: [(String, URL)] {
        [("Kho mã tham khảo", referenceUrl), ("GitHub", githubUrl), ("Mã nguồn", sourceUrl)]
            .compactMap { ten, u in
                guard let u, !u.isEmpty, let url = URL(string: u) else { return nil }
                return (ten, url)
            }
    }
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
