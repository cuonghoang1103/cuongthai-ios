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
    /// Tên theo NGÔN NGỮ ĐANG XEM. Dùng chung một quy tắc với đề bài và đáp
    /// án (`String.tachSongNgu`) để cả Phòng thi nói cùng một thứ tiếng.
    ///
    /// ⚠️ CỐ Ý không có bản không-đối-số. Mặc định là tiếng Anh (khớp
    /// `ExamPortalClient` của web: `useState<'en'|'vi'>('en')` — "exams
    /// default to English"), nhưng mặc định đó nằm ở `@State` của từng màn,
    /// không nằm ở đây. Có sẵn một `var ten` là sớm muộn cũng có chỗ gọi nó
    /// rồi nút EN/VI bấm không ăn ở đúng chỗ ấy.
    func ten(_ ngonNgu: NgonNguDe) -> String { title.tachSongNgu(ngonNgu) }

    /// Nửa còn lại, để hiện làm dòng phụ khi có chỗ.
    func tenPhu(_ ngonNgu: NgonNguDe) -> String? {
        let chinh = ten(ngonNgu)
        let kia = title.tachSongNgu(ngonNgu.doiSang)
        return (kia.isEmpty || kia == chinh) ? nil : kia
    }

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

// ════════════════════════════════════════════════════════════════
// XEM LẠI BÀI THI
//
// ⚠️⚠️ **`POST /attempts/:id/submit-fe` KHÔNG trả về một bảng điểm gọn** —
// nó trả về TRỌN BỘ bản xem lại: `{attempt, exam, examBookmarked, questions}`,
// tức `score`/`passed` nằm trong `attempt`, không phải ở tầng ngoài.
//
// Bản đầu của màn Phòng thi khai một `KetQuaThi` phẳng `{score, passed,
// correctCount…}` và đọc ở tầng ngoài. Mọi trường đều optional nên **decode
// vẫn THÀNH CÔNG, chỉ toàn `nil`** — không lỗi, không cảnh báo, build xanh.
// Kết quả: **mọi bài thi đều hiện "Chưa đạt" và "0 / 10"** dù làm đúng hết.
// Phát hiện 22/08/2026 khi đọc `submitFinalExam`, nó kết thúc bằng
// `return buildReview(updated.id, userId)`.
//
// Cái lợi kèm theo: đã có sẵn đáp án đúng + lời giải của TỪNG câu ngay trong
// phản hồi nộp bài, nên xem lại bài KHÔNG tốn thêm một lời gọi mạng nào.

struct XemLaiBaiThi: Codable {
    let attempt: LuotDaLam
    let examBookmarked: Bool?
    let questions: [CauHoiXemLai]

    var diem: Double { attempt.score ?? 0 }
    var tongDiem: Double { attempt.maxScore ?? 10 }
    var dat: Bool { attempt.passed ?? false }
    var soDung: Int? { attempt.feedback?.correctCount }
    var soCau: Int? { attempt.feedback?.total }
}

struct LuotDaLam: Codable, Identifiable, Hashable {
    let id: Int
    let examId: Int
    let status: String?
    let submittedAt: String?
    let timeSpentSeconds: Int?
    let score: Double?
    let maxScore: Double?
    let passed: Bool?
    let bookmarked: Bool?
    let feedback: PhanHoi?
    let exam: DeThi?

    struct PhanHoi: Codable, Hashable {
        let correctCount: Int?
        let total: Int?
    }

    var phut: Int { (timeSpentSeconds ?? 0) / 60 }
    var giay: Int { (timeSpentSeconds ?? 0) % 60 }
}

/// Đáp án người dùng đã chọn.
///
/// ⚠️ Máy chủ lưu `answers` dạng JSON tự do: câu trắc nghiệm là **mảng số**,
/// còn câu code/tự luận là **chuỗi**. Khai thẳng `[Int]?` thì gặp câu code là
/// decode NÉM LỖI (không phải trả `nil`) và hỏng cả màn xem lại chỉ vì một
/// câu. Nhận cả hai dạng ở đây.
struct DapAnCuaToi: Codable, Hashable {
    let chiSo: [Int]
    let chu: String?

    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let a = try? c.decode([Int].self) { chiSo = a; chu = nil }
        else if let s = try? c.decode(String.self) { chiSo = []; chu = s }
        else { chiSo = []; chu = nil }
    }
    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        if let chu { try c.encode(chu) } else { try c.encode(chiSo) }
    }
    var trong: Bool { chiSo.isEmpty && (chu ?? "").isEmpty }
}

struct CauHoiXemLai: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String?
    let sortOrder: Int?
    let points: Double?
    let prompt: String
    let imageUrl: String?
    let options: [CauHoiThi.LuaChon]?
    /// Chỉ số các đáp án ĐÚNG. Bản `/take` cố ý không có trường này.
    let correctIndexes: [Int]?
    let explanation: String?
    let myAnswer: DapAnCuaToi?
    let bookmarked: Bool?
    let bookmarkNote: String?

    var dapAnDung: [Int] { correctIndexes ?? [] }
    var daChon: [Int] { myAnswer?.chiSo ?? [] }
    var laTracNghiem: Bool { (options?.isEmpty == false) && !dapAnDung.isEmpty }
    var boTrong: Bool { myAnswer?.trong ?? true }
    /// Chỉ kết luận đúng/sai với câu trắc nghiệm — câu code/tự luận do người
    /// chấm, client không tự phán được.
    var lamDung: Bool { laTracNghiem && Set(daChon) == Set(dapAnDung) }
}

// ════════════════════════════════════════════════════════════════
// ĐỀ VÀ CÂU HỎI ĐÃ LƯU
//
// Dùng lại `DeThi` và `CauHoiXemLai`: payload của mục đã lưu là TẬP CON của
// hai cái đó (thiếu `myAnswer`, `sortOrder`… nhưng chúng đều optional), nên
// không cần model thứ ba. Đã đối chiếu với `select:` thật của
// `listMyExamBookmarks` / `listMyQuestionBookmarks`.

struct DeDaLuu: Codable, Identifiable {
    let id: Int
    let examId: Int
    let createdAt: String?
    let exam: DeThi
    let course: DeThi.KhoaHoc?
    let semester: DeThi.HocKy?
}

struct CauHoiDaLuu: Codable, Identifiable {
    let id: Int
    let questionId: Int
    let examId: Int
    /// Ghi chú riêng của người học — thứ đáng giá nhất ở đây, vì nó ghi lại
    /// LÝ DO câu này khó với chính họ.
    let note: String?
    let createdAt: String?
    let question: CauHoiXemLai
    let exam: DeThi
    let course: DeThi.KhoaHoc?
    let semester: DeThi.HocKy?

    /// Chuỗi GỐC còn `|||`: dùng làm KHOÁ nhóm nên phải ổn định, không
    /// được đổi theo nút EN/VI (đổi khoá là các nhóm nhảy chỗ). Chỗ hiện
    /// ra màn hình mới gọi `tachSongNgu`.
    var khoaMon: String { course?.title ?? exam.title }
}
