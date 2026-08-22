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
// ⚠️ **`problemHtmlVi`, `solutionExplanationHtmlVi`, `youtubeUrl` đang NULL
// 40/40** khi đo — bản dịch tiếng Việt chưa được điền, nội dung là tiếng Anh.
// Đừng dựng giao diện dựa vào việc có bản tiếng Việt.

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
    struct Nhan: Codable, Hashable {
        let id: Int?
        let title: String?
        let slug: String?
    }

    var doKho: DoKho { DoKho(difficulty) }
    /// Ưu tiên bản tiếng Việt nếu có ngày nào backend điền vào.
    var deBai: String { (problemHtmlVi?.isEmpty == false ? problemHtmlVi : problemHtml) ?? "" }
    var giaiThich: String? {
        let v = solutionExplanationHtmlVi?.isEmpty == false ? solutionExplanationHtmlVi : solutionExplanationHtml
        return (v?.isEmpty == false) ? v : nil
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

struct NhomCodeLab: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String?
    let description: String?
    let icon: String?
    let color: String?
    let tracks: [LoTrinhCode]?

    var soLoTrinh: Int { tracks?.count ?? 0 }
}

struct LoTrinhCode: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let slug: String?
    let description: String?
}
