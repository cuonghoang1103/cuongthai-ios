import Foundation

// ════════════════════════════════════════════════════════════════
// CUONGMINI — AI ĐỒNG HÀNH KHI THI
//
// Bản iOS của `CuongMiniPanel.tsx` + `ExamQuestionComments.tsx` trên web.
// Năm đường máy chủ, đã đo thật 05/09/2026 (đều trả 401 khi chưa đăng nhập,
// tức ĐÃ gắn và đang sống trên production):
//
//   POST /exams/attempts/:a/ai/reveal          — hiện đáp án, KHÔNG gọi AI
//   POST /exams/attempts/:a/ai/related-lesson  — bài học liên quan, KHÔNG gọi AI
//   POST /exams/attempts/:a/ai/ask             — hỏi AI (một cục, đường lùi)
//   POST /exams/attempts/:a/ai/ask-stream      — hỏi AI (SSE, đường chính)
//   GET/POST/PUT/DELETE /exams/questions/:q/comments — bình luận theo câu
//
// ⚠️ CHỈ hai đường `ask` cần Pro (`requireProForAi` ở `exam.routes.ts`).
// "Bắt đầu thi với CuongMini", "Hiện đáp án", "bài học liên quan" và bình
// luận mở cho MỌI tài khoản — đừng khoá cả phòng sau một cái cổng Pro.
// ════════════════════════════════════════════════════════════════

// MARK: - Câu hỏi gợi ý sẵn

/// Bảy gợi ý dựng sẵn + một chế độ hỏi tự do, đúng danh sách `QUICK` của web.
///
/// ⚠️ `rawValue` là MÃ GỬI LÊN MÁY CHỦ (`MODE_INSTRUCTION` trong
/// `examTutor.service.ts` tra theo đúng chuỗi này), còn `nhan` là chữ hiện
/// cho người đọc. Gộp hai thứ vào một là sớm muộn cũng gửi nhãn tiếng Việt
/// lên máy chủ rồi nó rơi về nhánh mặc định mà không báo gì —
/// xem [[feedback_enum_hien_thi_dung_lam_ma_gui_len]].
enum CheDoHoi: String, CaseIterable, Identifiable {
    case cachLam        = "how_to_solve"
    case cachNho        = "how_to_remember"
    case kienThuc       = "knowledge"
    case viSaoSai       = "why_others_wrong"
    case viDuTuongTu    = "similar_example"
    case loiHayGap      = "common_mistakes"
    case tomTatQuyTac   = "summary_rule"
    case hoiTuDo        = "free_qa"

    var id: String { rawValue }

    var nhan: String {
        switch self {
        case .cachLam:      return "Câu này làm như nào?"
        case .cachNho:      return "Câu này nhớ như nào?"
        case .kienThuc:     return "Câu này kiến thức là gì?"
        case .viSaoSai:     return "Vì sao các đáp án khác sai?"
        case .viDuTuongTu:  return "Cho ví dụ tương tự để luyện thêm"
        case .loiHayGap:    return "Lỗi hay gặp khi làm câu này?"
        case .tomTatQuyTac: return "Tóm tắt công thức/quy tắc liên quan"
        case .hoiTuDo:      return ""
        }
    }

    var bieuTuong: String {
        switch self {
        case .cachLam:      return "function"
        case .cachNho:      return "brain.head.profile"
        case .kienThuc:     return "book"
        case .viSaoSai:     return "xmark.circle"
        case .viDuTuongTu:  return "square.on.square"
        case .loiHayGap:    return "exclamationmark.triangle"
        case .tomTatQuyTac: return "list.bullet.rectangle"
        case .hoiTuDo:      return "text.bubble"
        }
    }

    /// Bảy nút gợi ý — bỏ `hoiTuDo` vì nó là ô gõ chữ, không phải nút.
    static var goiY: [CheDoHoi] { allCases.filter { $0 != .hoiTuDo } }
}

// MARK: - Chọn model

/// `nil` = tự động (máy chủ thử Opus qua cổng rambo trước, lùi sang Sol nếu
/// hỏng). Người dùng ép tay được, đúng ba nút như web.
enum NhaCungCapAI: String, CaseIterable, Identifiable {
    case tuDong, opus, sol
    var id: String { rawValue }

    var nhan: String {
        switch self {
        case .tuDong: return "Tự động"
        case .opus:   return "Opus 4.8"
        case .sol:    return "GPT-5.6-Sol"
        }
    }

    /// Giá trị gửi lên. `tuDong` KHÔNG gửi trường `provider` — máy chủ chỉ
    /// nhận đúng hai chuỗi `'opus'`/`'sol'`, gửi `"tuDong"` là nó bỏ qua
    /// nhưng vẫn tốn một trường vô nghĩa trong thân yêu cầu.
    var ma: String? { self == .tuDong ? nil : rawValue }
}

// MARK: - Hiện đáp án

/// Trả về của `/ai/reveal`. Không gọi AI — đọc thẳng `ExamQuestion`.
///
/// ⚠️ `correctIndexes` là `Int[] @default([])` trong Prisma nên LUÔN có mặt,
/// nhưng câu PE (CODE/WRITE/SPEAK) thì nó rỗng và giá trị thật nằm ở
/// `sampleSolution` / `rubric`. Vẽ theo `kind`, đừng vẽ theo "mảng có rỗng
/// không".
struct DapAnHien: Codable {
    let kind: String
    let correctIndexes: [Int]
    let explanation: String?
    let sampleSolution: String?
    let expectedOutput: String?
    let rubric: [TieuChiCham]?

    var laTracNghiem: Bool { kind.uppercased() == "MCQ" }

    /// "A, C" — chỉ số 0-based đổi sang chữ cái, đúng như web.
    var chuCaiDapAn: String {
        correctIndexes.sorted()
            .compactMap { i -> String? in
                guard i >= 0, i < 26, let v = Unicode.Scalar(65 + i) else { return nil }
                return String(Character(v))
            }
            .joined(separator: ", ")
    }

    var trongTron: Bool {
        (sampleSolution ?? "").isEmpty && (explanation ?? "").isEmpty && (rubric ?? []).isEmpty
    }
}

/// Một dòng tiêu chí chấm.
///
/// ⚠️ `rubric` là cột `Json?` tự do — schema ghi `[{ id, criterion, weight,
/// maxScore }]` nhưng đó là quy ước của người soạn đề, KHÔNG có gì ép kiểu ở
/// tầng cơ sở dữ liệu. Một `maxScore` lỡ lưu thành chuỗi `"2"` là
/// `Double?` NÉM LỖI (không phải trả `nil`) và hỏng cả màn hiện đáp án chỉ vì
/// một dòng — xem [[feedback_optional_trong_codable_khong_tha_kieu_sai]].
/// Nên tự giải mã, nhận cả số lẫn chuỗi.
struct TieuChiCham: Codable, Hashable {
    let criterion: String?
    let maxScore: Double?

    private enum K: String, CodingKey { case criterion, maxScore }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        if let s = try? c.decode(String.self, forKey: .criterion) { criterion = s }
        else if let n = try? c.decode(Double.self, forKey: .criterion) { criterion = String(n) }
        else { criterion = nil }

        if let n = try? c.decode(Double.self, forKey: .maxScore) { maxScore = n }
        else if let s = try? c.decode(String.self, forKey: .maxScore) { maxScore = Double(s) }
        else { maxScore = nil }
    }

    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: K.self)
        try c.encodeIfPresent(criterion, forKey: .criterion)
        try c.encodeIfPresent(maxScore, forKey: .maxScore)
    }

    var diem: String? {
        guard let m = maxScore else { return nil }
        return m == m.rounded() ? "\(Int(m))đ" : String(format: "%.1fđ", m)
    }
}

// MARK: - Bài học liên quan

/// Trả về của `/ai/related-lesson`. Không gọi AI — tra `ExamQuestion.sectionId`
/// rồi chọn bài khớp nhất trong chương bằng cách đếm từ trùng.
///
/// ⚠️ Máy chủ trả `data: null` khi câu chưa được gán chương. `request()` coi
/// `data == nil` là lỗi, nên nơi gọi phải `try?` rồi coi `nil` là "không có",
/// KHÔNG hiện chữ đỏ.
struct BaiHocLienQuan: Codable {
    let sectionTitle: String
    let courseTitle: String
    let lessonId: Int
    let lessonTitle: String
    let url: String

    /// `/courses/<slug>/learn?lessonId=<id>` → địa chỉ đầy đủ mở bằng Safari.
    /// Web thêm `&fromExam=<id>` để trang học biết đường quay lại phòng thi.
    func diaChi(examId: Int) -> URL? {
        URL(string: APIClient.diaChiGoc + url + "&fromExam=\(examId)")
    }
}

// MARK: - Trả lời của CuongMini

/// Trả về của `/ai/ask` (đường lùi không stream).
struct TraLoiCuongMini: Codable {
    let answer: String
    let cached: Bool?
}

/// Một lượt trong khung chat. Chỉ sống trong bộ nhớ — máy chủ KHÔNG nhớ hộ,
/// lịch sử phải gửi kèm mỗi lượt (giống AI Chat, xem
/// [[reference_chat_backend_khong_nho_ho]]).
struct LuotHoiMini: Identifiable, Equatable {
    let id = UUID()
    var cuaToi: Bool
    var noiDung: String
    var dangChay = false
    /// Máy chủ đã từng trả lời đúng câu này rồi → lấy lại, không tính tiền.
    var coSan = false

    static func nguoi(_ s: String) -> LuotHoiMini { .init(cuaToi: true, noiDung: s) }
    static func may() -> LuotHoiMini { .init(cuaToi: false, noiDung: "", dangChay: true) }

    /// Khuôn máy chủ đợi ở trường `history`.
    var goiTin: [String: String] { ["role": cuaToi ? "user" : "assistant", "content": noiDung] }
}

// MARK: - Bình luận theo câu hỏi

/// Một bình luận, kèm các trả lời (đúng MỘT cấp — web cũng vậy).
///
/// `isAi = true` là bình luận do bot `cuongmini` tự đăng lại sau khi trả lời
/// trong khung chat, nên nó BỀN qua mọi lần deploy: người sau vào đúng câu ấy
/// đọc được lời giải mà không tốn thêm một lượt gọi AI nào.
struct BinhLuanCauHoi: Codable, Identifiable, Hashable {
    let id: Int
    let content: String
    let isAi: Bool?
    let isEdited: Bool?
    let likesCount: Int?
    let createdAt: String?
    let author: TacGia?
    let replies: [BinhLuanCauHoi]?

    struct TacGia: Codable, Hashable {
        let id: Int?
        let username: String?
        let displayName: String?
        let fullName: String?
        let avatarUrl: String?

        var ten: String {
            for x in [displayName, fullName, username] {
                if let x, !x.isEmpty { return x }
            }
            return "Người dùng"
        }
    }

    var laAI: Bool { isAi ?? false }
    var daSua: Bool { isEdited ?? false }
    var traLoi: [BinhLuanCauHoi] { replies ?? [] }
    var luc: String { createdAt.map { TimeFormatter.formatTimeAgo($0) } ?? "" }

    /// Tổng cả gốc lẫn trả lời — con số hiện trên nút mở.
    static func dem(_ ds: [BinhLuanCauHoi]) -> Int {
        ds.reduce(0) { $0 + 1 + $1.traLoi.count }
    }
}
