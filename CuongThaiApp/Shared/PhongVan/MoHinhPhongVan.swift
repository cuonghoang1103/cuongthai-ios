import SwiftUI

// ════════════════════════════════════════════════════════════════
// PHỎNG VẤN (web: /interview)
//
// ⚠️ TOÀN BỘ nhóm route CẦN đăng nhập — `interview.routes.ts` gọi
// `router.use(authenticate)` ngay đầu tệp, nên cả `/tracks` (nhìn như dữ liệu
// chung) cũng trả 401 khi chưa đăng nhập. Đo thật 28/08/2026: `/tracks`,
// `/history`, `/mastery`, `/drill` đều 401.
//
// Luồng một phiên:
//   tracks → POST /sessions → (lặp) POST …/turns/<n>/answer → POST …/finish
//   → GET …/report
//
// ⚠️ `referenceAnswer` và `rubric` CHỈ về sau khi đã trả lời (`publicTurn`
// trong `session.service.ts` trả `nil` khi chưa). Đừng dựng giao diện dựa
// vào chúng lúc đang hỏi — sẽ luôn trống.
// ════════════════════════════════════════════════════════════════

// MARK: - Cây chủ đề

struct TaxonomyPV: Codable {
    let domains: [LinhVucPV]?
    let companyProfiles: [KieuCongTy]?
    let aiAvailable: Bool?
    let aiAllowed: Bool?
    let sttProvider: String?

    var cacLinhVuc: [LinhVucPV] { domains ?? [] }
    var cacKieu: [KieuCongTy] { companyProfiles ?? [] }
    /// `aiAvailable` = nền tảng bật AI · `aiAllowed` = NGƯỜI NÀY được dùng
    /// (Pro/admin). Phải đủ cả hai mới hiện tính năng AI, thiếu một cái là
    /// bày ra nút bấm vào chỉ để nhận lỗi.
    var duocDungAI: Bool { (aiAvailable ?? false) && (aiAllowed ?? false) }
}

struct LinhVucPV: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String?
    let name: String
    let nameVi: String?
    let icon: String?
    let tracks: [ViTriPV]?
    var cacViTri: [ViTriPV] { tracks ?? [] }
    func ten(_ anh: Bool) -> String { anh ? name : (nameVi ?? name) }
}

struct ViTriPV: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String?
    let name: String
    let nameVi: String?
    let description: String?
    let icon: String?
    let questionCount: Int?
    let topics: [ChuDePV]?
    var soCau: Int { questionCount ?? 0 }
    var cacChuDe: [ChuDePV] { topics ?? [] }
    func ten(_ anh: Bool) -> String { anh ? name : (nameVi ?? name) }
}

struct ChuDePV: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String?
    let name: String
    let nameVi: String?
    let weight: Double?
    let questionCount: Int?
    var soCau: Int { questionCount ?? 0 }
    func ten(_ anh: Bool) -> String { anh ? name : (nameVi ?? name) }
}

struct KieuCongTy: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String?
    let name: String
    let styleDescriptor: String?
    /// ⚠️ `Int` 1–5, KHÔNG phải chuỗi. Khai nhầm `String?` làm CẢ bản giải mã
    /// hỏng — không phải riêng trường này — và màn hình chỉ hiện "Dữ liệu trả
    /// về không đúng định dạng", không nói trường nào. Lấy kiểu từ
    /// `prisma/schema.prisma`, đừng đoán theo tên.
    let rigor: Int?
    /// 1–5 → chữ, để người dùng khỏi phải đoán "rigor 4" nghĩa là gì.
    var doKho: String {
        switch rigor ?? 3 {
        case ...1: return T("Nhẹ nhàng")
        case 2: return T("Vừa phải")
        case 3: return T("Tiêu chuẩn")
        case 4: return T("Khắt khe")
        default: return T("Rất khắt khe")
        }
    }
}

/// `enum InterviewLevel` trong `schema.prisma` — 7 bậc.
enum BacPV: String, CaseIterable, Identifiable {
    case intern = "INTERN", fresher = "FRESHER", junior = "JUNIOR"
    case mid = "MID", senior = "SENIOR", lead = "LEAD", principal = "PRINCIPAL"
    var id: String { rawValue }
    var nhan: String {
        switch self {
        case .intern: return "Intern"
        case .fresher: return "Fresher"
        case .junior: return "Junior"
        case .mid: return "Middle"
        case .senior: return "Senior"
        case .lead: return "Lead"
        case .principal: return "Principal"
        }
    }
}

// MARK: - Phiên

struct PhienPV: Codable {
    let id: Int
    let trackName: String?
    let level: String?
    let language: String?
    let engineMode: String?
    let total: Int?
    let status: String?
    let companyStyle: String?
    let hasReport: Bool?
    let aiAvailable: Bool?
    let generating: Bool?
    let turns: [LuotPV]?

    var cacLuot: [LuotPV] { turns ?? [] }
    var soCau: Int { total ?? cacLuot.count }
    var xongHet: Bool { cacLuot.allSatisfy { $0.answered == true } }
    var soDaTraLoi: Int { cacLuot.filter { $0.answered == true }.count }
}

struct LuotPV: Codable, Identifiable, Hashable {
    let order: Int
    let questionText: String
    let type: String?
    let mcqOptions: [LuaChonMCQ]?
    let answered: Bool?
    let userAnswer: String?
    let referenceAnswer: String?
    let rubric: [TieuChiPV]?
    let round: Int?

    var id: Int { order }
    var laMCQ: Bool { (type ?? "") == "MCQ" && !(mcqOptions ?? []).isEmpty }
    var cacLuaChon: [LuaChonMCQ] { mcqOptions ?? [] }
    var cacTieuChi: [TieuChiPV] { rubric ?? [] }
    var nhanLoai: String {
        switch (type ?? "").uppercased() {
        case "MCQ": return T("Trắc nghiệm")
        case "CODING": return T("Lập trình")
        case "SYSTEM_DESIGN": return T("Thiết kế hệ thống")
        case "BEHAVIORAL": return T("Hành vi")
        case "SCENARIO": return T("Tình huống")
        default: return T("Lý thuyết")
        }
    }
}

struct LuaChonMCQ: Codable, Identifiable, Hashable {
    let id: String
    let text: String
}

/// Tiêu chí chấm. Máy chủ trả JSON tự do nên nhận mềm: có bản chỉ là chuỗi.
struct TieuChiPV: Codable, Hashable, Identifiable {
    let label: String
    let weight: Double?
    var id: String { label }

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            label = s; weight = nil; return
        }
        let c = try decoder.container(keyedBy: Khoa.self)
        label = (try? c.decode(String.self, forKey: .label))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .criterion)) ?? "—"
        weight = try? c.decode(Double.self, forKey: .weight)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Khoa.self)
        try c.encode(label, forKey: .label)
        try c.encodeIfPresent(weight, forKey: .weight)
    }
    private enum Khoa: String, CodingKey { case label, name, criterion, weight }
}

// MARK: - Kết quả một lượt

struct KetQuaLuot: Codable {
    let order: Int
    let type: String?
    let referenceAnswer: String?
    let rubric: [TieuChiPV]?
    let deterministic: ChamMay?
    let aiEvaluation: ChamAI?
    let downgraded: Bool?
    let injectionAttempted: Bool?
    var cacTieuChi: [TieuChiPV] { rubric ?? [] }
}

/// Chấm bằng TỪ KHOÁ — nhanh, miễn phí, nhưng KHÔNG đáng tin khi bộ khoá
/// không cùng ngôn ngữ với câu trả lời. Máy chủ nói thẳng qua cờ `reliable`;
/// `false` thì ẩn điểm đi chứ đừng hiện một con số sai.
///
/// ⚠️ Tên trường lấy TỪ `scoring.ts`, không phải đoán: `mustHit`/`mustMiss`
/// (ý bắt buộc nêu được / bỏ sót), `shouldHit`/`shouldMiss` (ý nên có),
/// `redFlagsHit` (điều KHÔNG nên nói mà vẫn nói).
struct ChamMay: Codable {
    let score: Double?
    let grade: String?
    let mustHit: [String]?
    let mustMiss: [String]?
    let shouldHit: [String]?
    let shouldMiss: [String]?
    let redFlagsHit: [String]?
    let mustCoverage: Double?
    let shouldCoverage: Double?
    let reliable: Bool?

    var dangTin: Bool { reliable ?? true }
    var yBatBuocDaNeu: [String] { mustHit ?? [] }
    var yBatBuocBoSot: [String] { mustMiss ?? [] }
    var yNenCoDaNeu: [String] { shouldHit ?? [] }
    var yNenCoBoSot: [String] { shouldMiss ?? [] }
    var canhBao: [String] { redFlagsHit ?? [] }
}

/// ⚠️ Điểm của AI nằm ở `aiScore`/`finalScore`, KHÔNG phải `score`. Và
/// `criteria[].id` là MÃ tiêu chí (khớp với `rubric[].id` của câu hỏi), không
/// phải nhãn hiển thị — muốn có nhãn thì tra sang rubric.
struct ChamAI: Codable {
    let aiScore: Double?
    let finalScore: Double?
    let letterGrade: String?
    let summary: String?
    let criteria: [TieuChiAI]?
    let needsReview: Bool?
    let disagreement: Double?
    let grounded: Bool?
    let injectionAttempted: Bool?
    var cacTieuChi: [TieuChiAI] { criteria ?? [] }
    var diem: Double? { finalScore ?? aiScore }
}

struct TieuChiAI: Codable, Hashable, Identifiable {
    let id: String
    let score: Double?
    /// Câu trích trong bài làm chứng minh cho điểm đó.
    let evidence: String?
    /// Phần còn thiếu — thứ hữu ích nhất để học, nên hiện rõ.
    let whatWasMissing: String?
}

// MARK: - Báo cáo

struct BaoCaoPV: Codable {
    let report: NoiDungBaoCao?
    let language: String?
    let turns: [LuotBaoCao]?
    var cacLuot: [LuotBaoCao] { turns ?? [] }
}

/// ⚠️ Đây là bản ghi `InterviewReport` trong `schema.prisma`, chép đúng tên
/// trường. Không có `summary`/`recommendations` như tôi đoán lúc đầu — lời
/// khuyên nằm ở **`actionableAdvice`** (một đoạn chữ), tài nguyên gợi ý ở
/// `suggestedResources`, và kết luận tuyển ở `hireRecommendation`.
struct NoiDungBaoCao: Codable {
    let id: Int?
    let overallScore: Double?
    let letterGrade: String?
    let strengths: [String]?
    let weaknesses: [String]?
    let actionableAdvice: String?
    let hireRecommendation: String?

    var diemManh: [String] { strengths ?? [] }
    var diemYeu: [String] { weaknesses ?? [] }

    /// `enum InterviewHireRecommendation` — 6 mức.
    var nhanTuyen: String? {
        switch (hireRecommendation ?? "").uppercased() {
        case "STRONG_YES": return T("Rất nên tuyển")
        case "YES": return T("Nên tuyển")
        case "LEAN_YES": return T("Nghiêng về tuyển")
        case "LEAN_NO": return T("Nghiêng về từ chối")
        case "NO": return T("Chưa nên tuyển")
        case "STRONG_NO": return T("Không nên tuyển")
        default: return nil
        }
    }
    var mauTuyen: Color {
        switch (hireRecommendation ?? "").uppercased() {
        case "STRONG_YES", "YES": return Color(hex: 0x22C55E)
        case "LEAN_YES": return Color(hex: 0x84CC16)
        case "LEAN_NO": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0xEF4444)
        }
    }
}

struct LuotBaoCao: Codable, Identifiable, Hashable {
    let order: Int
    let topic: String?
    let questionText: String?
    let userAnswer: String?
    let referenceAnswer: String?
    let turnScore: DiemLuot?
    let selfScore: DiemTuCham?
    let needsReview: Bool?
    var id: Int { order }
    /// Điểm chính thức của lượt. Máy chủ tổng hợp báo cáo theo `final`; MCQ
    /// không có `final` nên lùi về `deterministic`.
    var diem: Double? { turnScore?.final ?? turnScore?.deterministic ?? selfScore?.score }
}

/// ⚠️ `turnScore` trong `schema.prisma` là **`Json?`**, KHÔNG phải số. Khai
/// `Double?` làm hỏng CẢ bản giải mã báo cáo, và màn hình chỉ nói "Dữ liệu
/// trả về không đúng định dạng" — không chỉ ra trường nào. Hình dạng lấy từ
/// `session.service.ts` dòng 342 (đường MCQ) và 437 (đường AI), hai đường ghi
/// hai bộ khoá KHÁC NHAU nên mọi trường đều phải để tuỳ chọn.
struct DiemLuot: Codable, Hashable {
    let mode: String?
    let deterministic: Double?
    let ai: Double?
    let final: Double?
    let grade: String?
    let summary: String?
    let disagreement: Double?
}

struct DiemTuCham: Codable, Hashable {
    let score: Double?
    let grade: String?
}

// MARK: - Lịch sử

/// ⚠️ Trường tên vị trí là **`track`**, KHÔNG phải `trackName` (khác với
/// `getSessionState`). Hai endpoint cùng một khái niệm mà đặt tên khác nhau —
/// lấy đúng theo `listHistory` trong `session.service.ts`.
struct MucLichSuPV: Codable, Identifiable, Hashable {
    let id: Int
    let track: String?
    let level: String?
    let status: String?
    let engineMode: String?
    let createdAt: String?
    let overallScore: Double?
    let letterGrade: String?

    var xong: Bool { (status ?? "").uppercased() == "COMPLETED" }
}
