import Foundation

// ════════════════════════════════════════════════════════════════
// PHÒNG THI — lớp dữ liệu
//
// Đo thật production 05/09/2026: 844 đề · 32.025 câu · 25 môn · 5 kỳ học.
//
// ⚠️ Con số này lớn nhanh và ĐỪNG chép nó ra giao diện: 21/08 mới 190 đề,
// sáng 05/09 là 800, chiều cùng ngày 844 (một trần cứng `take: 800` ở
// `GET /exams` vừa được gỡ — tức con số 800 tôi đo buổi sáng là CÁI TRẦN,
// không phải tổng thật). Chỗ nào cần số thì đếm từ dữ liệu vừa tải.
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
    /// Bốn trường dưới đây CHỈ có ở `GET /exams/course/:slug` (và `/take`) —
    /// `GET /exams` (danh sách toàn bộ) KHÔNG trả chúng. Optional hết: cùng
    /// một struct giải mã cả hai đường.
    /// `REAL` | `SAMPLE` | `FUOverflow` (đo 22/10/2026) — chuỗi tự do.
    let source: String?
    let description: String?
    let attachmentUrl: String?
    let attachmentName: String?
    /// Thống kê của chính người xem — chỉ `/exams/course/:slug` khi đã đăng nhập.
    let my: ThongKeDeCuaToi?

    /// ⚠️ `courseCode` CÓ trong phản hồi (`/exams` trả `course.courseCode`,
    /// ví dụ "PRF192") nhưng bản model đầu bỏ sót, nên màn danh sách phải
    /// gom nhóm theo `title` dài dòng thay vì mã môn ngắn gọn.
    struct KhoaHoc: Codable, Hashable {
        let title: String?
        let slug: String?
        let courseCode: String?
    }
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
    var laPE: Bool { (kind ?? "").uppercased() == "PE" }
    /// `CODE` | `WRITE` | `SPEAK` khi là đề PE.
    var loaiPE: String? { laPE ? peType?.uppercased() : nil }
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
    /// Ví dụ / kết quả mong đợi của câu CODE — `/take` CÓ trả trường này.
    let expectedOutput: String?
    /// Các câu hỏi phụ của đề NÓI. Cột `Json?` tự do ⇒ giải mã khoan dung.
    let speakingPrompts: [CauNoiPhu]?

    /// Một phương án.
    ///
    /// ⚠️ `/take` chuẩn hoá thành `{text}`, nhưng bản XEM LẠI và mục ĐÃ LƯU
    /// trả cột `options` THÔ (`Array.isArray(q.options) ? q.options : null`)
    /// — mà người soạn đề có lúc lưu chuỗi trần `["A", "B"]`. Khai cứng
    /// `{text: String}` là MỘT câu như thế làm hỏng cả màn xem lại lẫn sổ tay.
    /// Nhận cả chuỗi lẫn `{text}`; dạng lạ thì thành chuỗi rỗng.
    struct LuaChon: Codable, Hashable {
        let text: String
        init(text: String) { self.text = text }
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let s = try? c.decode(String.self) { text = s; return }
            if let n = try? c.decode(Double.self) {
                text = n == n.rounded() ? String(Int(n)) : String(n); return
            }
            struct Vo: Decodable { let text: String? }
            text = ((try? c.decode(Vo.self))?.text) ?? ""
        }
        func encode(to e: Encoder) throws {
            var c = e.container(keyedBy: K.self)
            try c.encode(text, forKey: .text)
        }
        private enum K: String, CodingKey { case text }
    }

    var chonNhieu: Bool { multiSelect ?? false }
    var laCode: Bool { kind.uppercased() == "CODE" }
    var laViet: Bool { kind.uppercased() == "WRITE" }
    var laNoi: Bool { kind.uppercased() == "SPEAK" }
    var soDapAn: Int { max(1, selectCount ?? 1) }
    var laTracNghiem: Bool { (options?.isEmpty == false) }
    var diem: Double { points ?? 0 }
}

/// `GET /exams/:id/take` — phần đầu đề (`examHeader`) + câu hỏi đã gỡ đáp án.
///
/// ⚠️ Bản cũ chỉ giữ 6 trường nên app KHÔNG BIẾT đề là PE hay FE, không có
/// hướng dẫn, không có tệp cho sẵn — và câu PE hiện "hãy làm trên web". Mọi
/// trường thêm vào đều optional: đề cũ thiếu trường nào cũng không vỡ.
struct DeDangLam: Codable {
    let id: Int
    let title: String
    let durationMinutes: Int?
    let totalPoints: Double?
    let passMark: Double?
    let questions: [CauHoiThi]
    let courseId: Int?
    let kind: String?
    let peType: String?
    let code: String?
    let description: String?
    let source: String?
    /// HTML, có thể chứa khối `.ml-en` / `.ml-vi` (đề PE) — xem `HuongDanDe`.
    let instructions: String?
    /// Đường dẫn TƯƠNG ĐỐI (`/exam-assets/PRF192-given.zip`) hoặc URL đầy đủ.
    let attachmentUrl: String?
    let attachmentName: String?
    let my: ThongKeDeCuaToi?

    var laPE: Bool { (kind ?? "").uppercased() == "PE" }
    var loaiPE: String? { laPE ? peType?.uppercased() : nil }
    var laNguon: String { (source ?? "").uppercased() }
    var laDeThat: Bool { laNguon == "REAL" }
    /// Đề FE có câu lập trình (Progress Test = trắc nghiệm + 1–2 câu code).
    var coCauCode: Bool { questions.contains { $0.laCode } }
    var toanCode: Bool { !questions.isEmpty && questions.allSatisfy { $0.laCode } }
}

/// Thống kê lượt thi của CHÍNH người xem trên một đề (`my` của máy chủ).
///
/// Lượt CuongMini (ôn tập, không tính giờ) KHÔNG tính vào `attempts`/điểm —
/// máy chủ lọc sẵn; `aiInProgressId` là lượt ôn tập đang dở, tách riêng.
struct ThongKeDeCuaToi: Codable, Hashable {
    let attempts: Int?
    let bestScore: Double?
    let lastScore: Double?
    let passed: Bool?
    let lastAttemptId: Int?
    let inProgressId: Int?
    let aiInProgressId: Int?

    var soLan: Int { attempts ?? 0 }
    var daDat: Bool { passed ?? false }
}

/// Một câu hỏi phụ của đề NÓI (`speakingPrompts`). Cột JSON tự do: nhận cả
/// `{text, imageUrl}` lẫn chuỗi trần.
struct CauNoiPhu: Codable, Hashable {
    let text: String
    let imageUrl: String?

    init(text: String, imageUrl: String? = nil) { self.text = text; self.imageUrl = imageUrl }
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let s = try? c.decode(String.self) { text = s; imageUrl = nil; return }
        struct Vo: Decodable { let text: String?; let imageUrl: String? }
        let v = try? c.decode(Vo.self)
        text = v?.text ?? ""
        imageUrl = v?.imageUrl
    }
    private enum K: String, CodingKey { case text, imageUrl }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: K.self)
        try c.encode(text, forKey: .text)
        try c.encodeIfPresent(imageUrl, forKey: .imageUrl)
    }
}

struct LuotThi: Codable {
    let attemptId: Int
    let startedAt: String?
    let expiresAt: String?
    let resumed: Bool?
    /// Lượt này là phòng ôn tập CuongMini hay lượt thi thật.
    ///
    /// ⚠️ `expiresAt = nil` KHÔNG suy ra được "đây là phòng CuongMini": đề
    /// `durationMinutes = 0` cũng cho `expiresAt` rỗng. Máy chủ nói thẳng ra
    /// bằng trường này — đọc nó, đừng suy.
    let aiAssisted: Bool?
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
    /// Phần đầu đề (`examHeader`) — biết đây là FE hay PE mà không phải đoán.
    let exam: DeThi?

    var laPE: Bool { exam?.laPE ?? questions.contains { ($0.kind ?? "MCQ").uppercased() != "MCQ" } }
    /// Bài chấm của một câu (PE, hoặc câu CODE trong đề FE).
    func cham(_ questionId: Int) -> ChamCau? {
        attempt.feedback?.perQuestion?.first { $0.questionId == questionId }
    }

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
    let startedAt: String?
    /// `AUTO` (FE) | `AI` (PE).
    let gradingMode: String?

    struct PhanHoi: Codable, Hashable {
        let correctCount: Int?
        let total: Int?
        /// Bài chấm TỪNG CÂU. FE: `{questionId, points, correct, selected}`;
        /// PE / câu CODE: `{questionId, grade}` hoặc `{ungraded: true}`.
        ///
        /// ⚠️ Giải mã KHOAN DUNG từng phần tử: một dòng chấm của AI lỡ sai
        /// hình dạng thì chỉ dòng đó mất, không kéo đổ cả màn xem lại.
        let perQuestion: [ChamCau]?

        private enum K: String, CodingKey { case correctCount, total, perQuestion }
        init(correctCount: Int?, total: Int?, perQuestion: [ChamCau]?) {
            self.correctCount = correctCount; self.total = total; self.perQuestion = perQuestion
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            correctCount = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .correctCount))?.flatMap { $0.int }
            total = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .total))?.flatMap { $0.int }
            perQuestion = (try? c.decodeIfPresent(MangKhoan<ChamCau>.self, forKey: .perQuestion))?.flatMap { $0.phanTu }
        }
        func encode(to e: Encoder) throws {
            var c = e.container(keyedBy: K.self)
            try c.encodeIfPresent(correctCount, forKey: .correctCount)
            try c.encodeIfPresent(total, forKey: .total)
            try c.encodeIfPresent(perQuestion, forKey: .perQuestion)
        }
    }

    var hetGio: Bool { (status ?? "").uppercased() == "EXPIRED" }

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
    let language: String?
    let starterCode: String?
    /// Đáp án mẫu của câu CODE/WRITE — chỉ lộ SAU khi nộp.
    let sampleSolution: String?
    let expectedOutput: String?
    let speakingPrompts: [CauNoiPhu]?

    var laMCQ: Bool { (kind ?? "MCQ").uppercased() == "MCQ" }
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

    /// Cùng cảnh báo như `CauHoiDaLuu.maMon`: đọc môn/kỳ từ TẦNG NGOÀI, không
    /// đọc từ `exam`.
    var maMon: String { course?.courseCode ?? "—" }
    var tenMon: String { course?.title ?? exam.title }
    var soKyHoc: Int { semester?.ordinal ?? 99 }
    var tenKyHoc: String { semester?.name ?? "" }
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

    /// ⚠️ `exam` trong mục đã lưu KHÔNG mang `course`/`semester` — máy chủ
    /// trả chúng thành trường ANH EM ở tầng ngoài (`listMyQuestionBookmarks`
    /// map `course: b.exam.course`, `semester: b.exam.course?.semester`).
    /// Gọi `exam.maMon` ở đây là ra "—" cho mọi mục, và cả màn gom vào một
    /// nhóm vô danh mà không có lỗi nào để thấy.
    var maMon: String { course?.courseCode ?? "—" }
    var soKyHoc: Int { semester?.ordinal ?? 99 }
    var tenKyHoc: String { semester?.name ?? "" }
}

// ════════════════════════════════════════════════════════════════
// CHẤM TỪNG CÂU — `attempt.feedback.perQuestion`
//
// Hình dạng đọc từ `exam.routes.ts › finalizePe` và
// `exam.service.ts › submitFinalExam` (22/10/2026):
//   FE/MCQ : { questionId, points, correct, selected }
//   CODE   : { questionId, points, kind: "CODE", grade } | { …, ungraded: true }
//   PE     : { questionId, grade }
// `grade` = `PeGradeResult` của `exam.grading.service.ts`.
// ════════════════════════════════════════════════════════════════

struct ChamCau: Codable, Hashable {
    let questionId: Int
    let points: Double?
    let correct: Bool?
    let kind: String?
    let grade: KetQuaChamPE?
    /// AI hỏng lúc nộp ⇒ câu này KHÔNG tính vào điểm (không bị trừ).
    let ungraded: Bool?

    private enum K: String, CodingKey { case questionId, points, correct, kind, grade, ungraded }
    init(questionId: Int, points: Double? = nil, correct: Bool? = nil, kind: String? = nil,
         grade: KetQuaChamPE? = nil, ungraded: Bool? = nil) {
        self.questionId = questionId; self.points = points; self.correct = correct
        self.kind = kind; self.grade = grade; self.ungraded = ungraded
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        guard let q = try c.decodeIfPresent(SoLinhHoat.self, forKey: .questionId)?.int else {
            throw DecodingError.dataCorruptedError(forKey: .questionId, in: c,
                                                   debugDescription: "thiếu questionId")
        }
        questionId = q
        points = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .points))?.flatMap { $0.so }
        correct = try? c.decodeIfPresent(Bool.self, forKey: .correct)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        grade = try? c.decodeIfPresent(KetQuaChamPE.self, forKey: .grade)
        ungraded = try? c.decodeIfPresent(Bool.self, forKey: .ungraded)
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: K.self)
        try c.encode(questionId, forKey: .questionId)
        try c.encodeIfPresent(points, forKey: .points)
        try c.encodeIfPresent(correct, forKey: .correct)
        try c.encodeIfPresent(kind, forKey: .kind)
        try c.encodeIfPresent(grade, forKey: .grade)
        try c.encodeIfPresent(ungraded, forKey: .ungraded)
    }

    var khongCham: Bool { ungraded ?? false }
}

/// Bài chấm AI của một câu PE (`PeGradeResult`). Mọi chữ là "EN|||VI".
struct KetQuaChamPE: Codable, Hashable {
    let score: Double
    let maxScore: Double
    let percent: Double
    /// `excellent` | `good` | `pass` | `weak` | `fail`
    let verdict: String
    let summary: String
    let criteria: [TieuChi]
    let suggestions: [String]
    /// Bản ghi giọng nói (đề NÓI).
    let transcript: String?

    struct TieuChi: Codable, Hashable {
        let id: String
        let name: String
        let score: Double
        let maxScore: Double
        let comment: String

        private enum K: String, CodingKey { case id, name, score, maxScore, comment }
        init(id: String, name: String, score: Double, maxScore: Double, comment: String) {
            self.id = id; self.name = name; self.score = score; self.maxScore = maxScore; self.comment = comment
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            id = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .id))?.chu ?? UUID().uuidString
            name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
            score = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .score))?.so ?? 0
            maxScore = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .maxScore))?.so ?? 0
            comment = (try? c.decodeIfPresent(String.self, forKey: .comment)) ?? ""
        }
        func encode(to e: Encoder) throws {
            var c = e.container(keyedBy: K.self)
            try c.encode(id, forKey: .id); try c.encode(name, forKey: .name)
            try c.encode(score, forKey: .score); try c.encode(maxScore, forKey: .maxScore)
            try c.encode(comment, forKey: .comment)
        }
    }

    private enum K: String, CodingKey { case score, maxScore, percent, verdict, summary, criteria, suggestions, transcript }
    init(score: Double, maxScore: Double, percent: Double, verdict: String, summary: String,
         criteria: [TieuChi], suggestions: [String], transcript: String?) {
        self.score = score; self.maxScore = maxScore; self.percent = percent; self.verdict = verdict
        self.summary = summary; self.criteria = criteria; self.suggestions = suggestions; self.transcript = transcript
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        score = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .score))?.so ?? 0
        maxScore = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .maxScore))?.so ?? 0
        let p = (try? c.decodeIfPresent(SoLinhHoat.self, forKey: .percent))?.so
        percent = p ?? (maxScore > 0 ? score / maxScore * 100 : 0)
        verdict = (try? c.decodeIfPresent(String.self, forKey: .verdict)) ?? ""
        summary = (try? c.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        criteria = (try? c.decodeIfPresent(MangKhoan<TieuChi>.self, forKey: .criteria))?.phanTu ?? []
        suggestions = ((try? c.decodeIfPresent(MangKhoan<String>.self, forKey: .suggestions))?.phanTu) ?? []
        transcript = try? c.decodeIfPresent(String.self, forKey: .transcript)
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: K.self)
        try c.encode(score, forKey: .score); try c.encode(maxScore, forKey: .maxScore)
        try c.encode(percent, forKey: .percent); try c.encode(verdict, forKey: .verdict)
        try c.encode(summary, forKey: .summary); try c.encode(criteria, forKey: .criteria)
        try c.encode(suggestions, forKey: .suggestions)
        try c.encodeIfPresent(transcript, forKey: .transcript)
    }

    /// Nhãn tiếng Việt của `verdict`.
    var nhanKetLuan: String {
        switch verdict.lowercased() {
        case "excellent": return T("Xuất sắc")
        case "good":      return T("Tốt")
        case "pass":      return T("Đạt")
        case "weak":      return T("Yếu")
        case "fail":      return T("Chưa đạt")
        default:          return verdict
        }
    }
}

// MARK: - Bộ giải mã khoan dung

/// Một số mà máy chủ có thể gửi dạng số HOẶC chuỗi (`Decimal` của Prisma đi
/// qua `JSON.stringify` thành chuỗi ở vài đường; cột JSON tự do càng không
/// chắc). Khai thẳng `Double?` thì gặp `"2"` là NÉM LỖI, không phải `nil`.
struct SoLinhHoat: Codable, Hashable {
    let so: Double?
    let chu: String?

    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let n = try? c.decode(Double.self) {
            so = n; chu = n == n.rounded() ? String(Int(n)) : String(n)
        } else if let s = try? c.decode(String.self) {
            so = Double(s.trimmingCharacters(in: .whitespaces)); chu = s
        } else if let b = try? c.decode(Bool.self) {
            so = b ? 1 : 0; chu = b ? "true" : "false"
        } else { so = nil; chu = nil }
    }
    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        if let so { try c.encode(so) } else if let chu { try c.encode(chu) } else { try c.encodeNil() }
    }
    var int: Int? { so.map { Int($0) } }
}

/// Mảng mà phần tử nào giải mã hỏng thì BỎ phần tử đó, giữ phần còn lại.
struct MangKhoan<T: Codable>: Codable {
    let phanTu: [T]

    init(_ phanTu: [T]) { self.phanTu = phanTu }
    init(from d: Decoder) throws {
        var c = try d.unkeyedContainer()
        var ra: [T] = []
        while !c.isAtEnd {
            if let x = try? c.decode(T.self) { ra.append(x) }
            else { _ = try? c.decode(BoQua.self) }
        }
        phanTu = ra
    }
    func encode(to e: Encoder) throws {
        var c = e.unkeyedContainer()
        for x in phanTu { try c.encode(x) }
    }
    /// Nuốt một phần tử bất kỳ để con trỏ của `unkeyedContainer` tiến lên —
    /// `try? decode` hỏng KHÔNG tự tiến, không có dòng này là lặp vô tận.
    private struct BoQua: Decodable { init(from d: Decoder) throws {} }
}
