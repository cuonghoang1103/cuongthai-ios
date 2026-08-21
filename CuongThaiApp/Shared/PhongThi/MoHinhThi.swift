import Foundation

// ════════════════════════════════════════════════════════════════
// PHÒNG THI — lớp dữ liệu
//
// Đo thật production 21/08/2026: 190 đề, 5.191 câu hỏi.
//
// ⚠️ Đường gắn là `/api/v1/exams` (SỐ NHIỀU). `/api/v1/exam` trả 404 —
// đoán theo tên file `exam.routes.ts` là sai.
// ════════════════════════════════════════════════════════════════

struct DeThi: Codable, Identifiable, Hashable {
    let id: Int
    let courseId: Int?
    let kind: String?
    let peType: String?
    let title: String
    let code: String?
    let durationMinutes: Int?
    let totalPoints: Double?
    let passMark: Double?
    let questionCount: Int?
    let course: KhoaHoc?
    let semester: HocKy?

    struct KhoaHoc: Codable, Hashable { let title: String?; let slug: String? }
    struct HocKy: Codable, Hashable { let name: String?; let ordinal: Int?; let code: String? }

    /// Máy chủ ghép hai thứ tiếng vào MỘT trường, ngăn bằng `|||`:
    /// "Đề 1 — SP26 Block 5 Retake Exam|||Đề 1 — Thi lại B".
    /// Hiện thẳng cả chuỗi là người dùng đọc thấy ba gạch đứng giữa câu.
    private static func tach(_ s: String) -> (String, String?) {
        let p = s.components(separatedBy: "|||")
        guard p.count >= 2 else { return (s, nil) }
        let vi = p[1].trimmingCharacters(in: .whitespaces)
        let en = p[0].trimmingCharacters(in: .whitespaces)
        // Ưu tiên tiếng Việt làm dòng chính, tiếng Anh làm dòng phụ.
        return (vi.isEmpty ? en : vi, vi.isEmpty ? nil : en)
    }

    var ten: String { Self.tach(title).0 }
    var tenPhu: String? { Self.tach(title).1 }
    var soCau: Int { questionCount ?? 0 }
    var phut: Int { durationMinutes ?? 0 }
    var tenKhoa: String { course?.title ?? "Khác" }
    var tenKy: String { semester?.name ?? "" }

    /// FE = thi cuối kỳ · PE = thi thực hành · PT = kiểm tra tiến độ.
    var nhanLoai: String {
        switch (kind ?? "").uppercased() {
        case "FE": return "Cuối kỳ"
        case "PE": return "Thực hành"
        case "PT": return "Tiến độ"
        default:   return kind ?? ""
        }
    }
}

struct CauHoiThi: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let sortOrder: Int?
    let points: Double?
    let prompt: String
    let imageUrl: String?
    let options: [LuaChon]?
    /// Bao nhiêu đáp án đúng. Máy chủ CỐ Ý chỉ nói SỐ LƯỢNG, không nói là
    /// những đáp án nào — để giao diện biết vẽ ô tròn hay ô vuông.
    let selectCount: Int?
    let multiSelect: Bool?
    let language: String?
    let starterCode: String?

    struct LuaChon: Codable, Hashable { let text: String }

    var chonNhieu: Bool { multiSelect ?? false }
    var soDapAn: Int { max(1, selectCount ?? 1) }
    var laTracNghiem: Bool { (options?.isEmpty == false) }
    var diem: Double { points ?? 0 }
}

struct DeDangLam: Codable {
    let id: Int
    let title: String
    let durationMinutes: Int?
    let totalPoints: Double?
    let passMark: Double?
    let questions: [CauHoiThi]
}

struct LuotThi: Codable {
    let attemptId: Int
    let startedAt: String?
    let expiresAt: String?
    let resumed: Bool?
}

struct KetQuaThi: Codable {
    let score: Double?
    let totalPoints: Double?
    let passed: Bool?
    let correctCount: Int?
    let totalQuestions: Int?

    var diem: Double { score ?? 0 }
    var tongDiem: Double { totalPoints ?? 10 }
    var dat: Bool { passed ?? false }
}
