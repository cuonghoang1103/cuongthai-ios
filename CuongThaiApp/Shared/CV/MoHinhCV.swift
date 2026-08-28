import SwiftUI

// ════════════════════════════════════════════════════════════════
// CV BUILDER (web: /cv) — mô hình dữ liệu
//
// Kiểu lấy TỪ `prisma/schema.prisma`, không suy từ tên trường. Hôm nay đã
// dính bốn lần vì đoán: `String?` trong `Codable` KHÔNG có nghĩa "sai kiểu
// thì bỏ qua" — `decodeIfPresent` vẫn NÉM, và một trường lệch là hỏng CẢ
// đối tượng, giao diện chỉ nói "không đọc được".
//
// ⚠️ `GET /cv/profile` TỰ TẠO hồ sơ nếu chưa có (upsert), nên nó không bao
// giờ 404 — đừng dùng mã 404 để suy "người này chưa có CV".
//
// ⚠️ `links` là `Json` kiểu `Record<String, String>` (github/linkedin/…),
// KHÔNG phải mảng.
// ════════════════════════════════════════════════════════════════

struct HoSoCV: Codable {
    let id: Int
    let fullName: String?
    let headline: String?
    let email: String?
    let phone: String?
    let location: String?
    let links: [String: String]?
    let summary: String?
    let targetRoles: [String]?
    let seniority: String?
    let photoR2Key: String?
    let items: [MucCV]?
    let skills: [KyNangCV]?
    let certifications: [ChungChiCV]?
    let languageSkills: [NgonNguCV]?

    var cacMuc: [MucCV] { items ?? [] }
    var cacKyNang: [KyNangCV] { skills ?? [] }
    var cacChungChi: [ChungChiCV] { certifications ?? [] }
    var cacNgonNgu: [NgonNguCV] { languageSkills ?? [] }
    var cacLink: [(String, String)] { (links ?? [:]).sorted { $0.key < $1.key }.map { ($0.key, $0.value) } }
    func muc(_ loai: String) -> [MucCV] { cacMuc.filter { $0.kind == loai } }
}

/// `enum CvItemKind` — 7 loại.
struct MucCV: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let title: String
    let organization: String?
    let location: String?
    let employmentType: String?
    let startDate: String?
    let endDate: String?
    let isCurrent: Bool?
    let url: String?
    let techStack: [String]?
    let context: String?
    let gpa: String?
    let bullets: [GachCV]?

    var cacGach: [GachCV] { bullets ?? [] }
    var congNghe: [String] { techStack ?? [] }
    var khoangThoiGian: String {
        let a = nam(startDate), b = (isCurrent == true) ? T("nay") : nam(endDate)
        if a.isEmpty && b.isEmpty { return "" }
        return b.isEmpty ? a : "\(a) – \(b)"
    }
    private func nam(_ s: String?) -> String {
        guard let s, s.count >= 7 else { return "" }
        // ISO `2024-03-01T…` → `03/2024`, đủ dùng cho CV.
        let p = s.prefix(7).split(separator: "-")
        return p.count == 2 ? "\(p[1])/\(p[0])" : String(s.prefix(4))
    }
}

/// `enum CvBulletStrength` — WEAK · OK · STRONG.
struct GachCV: Codable, Identifiable, Hashable {
    let id: Int
    let text: String
    let verified: Bool?
    let aiGenerated: Bool?
    let strength: String?
    let skillsEvidenced: [String]?

    var mauLuc: Color {
        switch (strength ?? "").uppercased() {
        case "STRONG": return Color(hex: 0x22C55E)
        case "OK": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0xEF4444)
        }
    }
    var nhanLuc: String {
        switch (strength ?? "").uppercased() {
        case "STRONG": return T("Mạnh")
        case "OK": return T("Tạm")
        default: return T("Yếu")
        }
    }
}

/// `enum CvSkillCategory` — 7 nhóm.
struct KyNangCV: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let category: String?
    let proficiency: String?
    let yearsUsed: Double?
    var nhanNhom: String {
        switch (category ?? "").uppercased() {
        case "LANGUAGE": return T("Ngôn ngữ")
        case "FRAMEWORK": return "Framework"
        case "DATABASE": return T("CSDL")
        case "INFRA": return T("Hạ tầng")
        case "TOOL": return T("Công cụ")
        case "PRACTICE": return T("Phương pháp")
        case "SOFT": return T("Kỹ năng mềm")
        default: return T("Khác")
        }
    }
}

struct ChungChiCV: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let issuer: String?
    let issueDate: String?
    let credentialId: String?
    let url: String?
}

struct NgonNguCV: Codable, Identifiable, Hashable {
    let id: Int
    let language: String
    let proficiency: String?
    let certName: String?
    let certScore: String?
}

// MARK: - Độ đầy

struct DoDayCV: Codable {
    let percent: Int?
    let checks: [MucKiemCV]?
    let counts: DemCV?
    var cacMuc: [MucKiemCV] { checks ?? [] }
}

struct MucKiemCV: Codable, Identifiable, Hashable {
    let key: String
    let label: String
    let done: Bool
    var id: String { key }
}

struct DemCV: Codable {
    let items: Int?
    let bullets: Int?
    let skills: Int?
    let certifications: Int?
    let languageSkills: Int?
    let documents: Int?
}

// MARK: - Tài liệu

struct TaiLieuCV: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let market: String?
    let language: String?
    let experienceLevel: String?
    let cvType: String?
    let templateKey: String?
    let pageTarget: Int?
    let updatedAt: String?
}

struct MauCV: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let name: String
    let description: String?
    let atsSafe: Bool?
}

// MARK: - Soi lỗi (máy, không dùng AI)

/// ⚠️ Trường là **`problem`**, không phải `message`; **`band`**, không phải
/// `verdict`. Lấy từ `CvLintResult` trong `rules/documentLinter.ts` — bản đầu
/// tôi đoán theo tên thường gặp và sai cả hai.
struct KetQuaSoiLoi: Codable {
    let score: Int?
    let band: String?
    let sixSecondTest: String?
    let issues: [LoiCV]?
    let strengths: [String]?
    let skillGaps: [String]?
    let counts: DemSoiLoi?

    var cacLoi: [LoiCV] { issues ?? [] }
    var diemManh: [String] { strengths ?? [] }
    var thieuKyNang: [String] { skillGaps ?? [] }
    /// `INTERVIEW` · `MAYBE` · `REJECT`.
    var nhanBand: String {
        switch (band ?? "").uppercased() {
        case "INTERVIEW": return T("Được gọi phỏng vấn")
        case "MAYBE": return T("Còn cân nhắc")
        default: return T("Bị loại")
        }
    }
    var mauBand: Color {
        switch (band ?? "").uppercased() {
        case "INTERVIEW": return Color(hex: 0x22C55E)
        case "MAYBE": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0xEF4444)
        }
    }
}

struct DemSoiLoi: Codable {
    let bullets: Int?
    let weakBullets: Int?
    let strongBullets: Int?
    let bulletsWithMetric: Int?
    let items: Int?
}

struct LoiCV: Codable, Identifiable, Hashable {
    let code: String?
    let severity: String?
    let problem: String?
    let suggestedFix: String?
    var id: String { (code ?? "") + (problem ?? "") }
    var mau: Color {
        switch (severity ?? "").uppercased() {
        case "ERROR", "CRITICAL", "HIGH": return Color(hex: 0xEF4444)
        case "WARN", "WARNING", "MAJOR", "MEDIUM": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0x3B82F6)
        }
    }
}

// MARK: - Tin tuyển dụng

struct ViecLamCV: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let company: String?
    let sourceUrl: String?
    let createdAt: String?
}

/// ⚠️ Độ phủ KHÔNG trả `covered`/`missing` như tôi đoán. Nó trả `rows` — mỗi
/// kỹ năng một dòng với mức **GREEN** (có dòng thành tích chứng minh) ·
/// **AMBER** (có ghi kỹ năng nhưng chưa chứng minh) · **RED** (không có bằng
/// chứng). Ba mức này là cả bài học của tính năng: "có ghi" khác "chứng minh
/// được", và người phỏng vấn sẽ hỏi đúng chỗ AMBER.
struct DoPhuCV: Codable {
    let job: ViecLamGon?
    let rows: [DongPhu]?
    let summary: TomTatPhu?
    var cacDong: [DongPhu] { rows ?? [] }
}

struct ViecLamGon: Codable {
    let id: Int?
    let title: String?
    let company: String?
    let injectionAttempted: Bool?
}

struct DongPhu: Codable, Identifiable, Hashable {
    let skill: String
    let category: String?
    let required: Bool?
    let level: String?
    let evidence: String?
    var id: String { skill }
    var mau: Color {
        switch (level ?? "").uppercased() {
        case "GREEN": return Color(hex: 0x22C55E)
        case "AMBER": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0xEF4444)
        }
    }
    var nhanMuc: String {
        switch (level ?? "").uppercased() {
        case "GREEN": return T("Chứng minh được")
        case "AMBER": return T("Mới chỉ ghi")
        default: return T("Chưa có")
        }
    }
}

struct TomTatPhu: Codable {
    let verdict: String?
    let message: String?
    let mustHaveTotal: Int?
    let mustHaveMatched: Int?
    let mustHaveStrong: Int?
    let gaps: [String]?
    var tiLe: Double {
        let t = Double(mustHaveTotal ?? 0)
        return t > 0 ? Double(mustHaveMatched ?? 0) / t : 0
    }
    /// `STRONG` · `STRETCH` · `POOR`.
    var mau: Color {
        switch (verdict ?? "").uppercased() {
        case "STRONG": return Color(hex: 0x22C55E)
        case "STRETCH": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0xEF4444)
        }
    }
}

struct ThuXinViec: Codable {
    let id: Int?
    let body: String?
    let tone: String?
    let version: Int?
}

// MARK: - Chấm CV (AI)

/// ⚠️ Trường là **`overallVerdict`**, không phải `verdict`; vấn đề có
/// `whyItMatters` + `clarifyingQuestion`; rủi ro phỏng vấn là OBJECT
/// `{claim, likelyQuestion, canYouAnswerIt}` chứ không phải chuỗi.
struct ChamCV: Codable {
    let overallVerdict: String?
    let sixSecondTest: String?
    let issues: [VanDeCham]?
    let strengths: [String]?
    let interviewRisks: [RuiRoPhongVan]?
    let injectionAttempted: Bool?
    let mode: String?

    var cacVanDe: [VanDeCham] { issues ?? [] }
    var diemManh: [String] { strengths ?? [] }
    var ruiRo: [RuiRoPhongVan] { interviewRisks ?? [] }
    var nhanKetLuan: String? {
        switch (overallVerdict ?? "").uppercased() {
        case "STRONG": return T("Mạnh")
        case "MAYBE": return T("Còn cân nhắc")
        case "WEAK", "REJECT": return T("Cần sửa nhiều")
        default: return overallVerdict
        }
    }
    var mauKetLuan: Color {
        switch (overallVerdict ?? "").uppercased() {
        case "STRONG": return Color(hex: 0x22C55E)
        case "MAYBE": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0xEF4444)
        }
    }
}

struct VanDeCham: Codable, Identifiable, Hashable {
    let severity: String?
    let location: String?
    let problem: String?
    let whyItMatters: String?
    let suggestedFix: String?
    let needsUserInput: Bool?
    let clarifyingQuestion: String?
    var id: String { (location ?? "") + (problem ?? "") }
    var mau: Color {
        switch (severity ?? "").uppercased() {
        case "CRITICAL": return Color(hex: 0xEF4444)
        case "MAJOR": return Color(hex: 0xF59E0B)
        default: return Color(hex: 0x3B82F6)
        }
    }
}

struct RuiRoPhongVan: Codable, Identifiable, Hashable {
    let claim: String?
    let likelyQuestion: String?
    let canYouAnswerIt: String?
    var id: String { (claim ?? "") + (likelyQuestion ?? "") }
}

/// Cổng AI: máy chủ trả trạng thái để giao diện biết vì sao nút mờ, thay vì
/// bày ra một nút bấm vào chỉ nhận lỗi.
struct CongAI: Codable {
    let enabled: Bool?
    let available: Bool?
    let needPro: Bool?
    let reason: String?
    var bat: Bool { enabled ?? available ?? false }
}
