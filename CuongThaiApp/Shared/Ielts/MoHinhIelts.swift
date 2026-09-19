import Foundation

// MARK: - Nội dung IELTS
//
// ⚠️ NGUỒN SỰ THẬT KHÔNG NẰM Ở ĐÂY. Nó là các tệp TypeScript của web
// (`frontend/src/app/tech-trends/ielts/data/types.ts`); máy chủ chỉ chuyển
// tiếp nguyên khối JSON. Mô hình dưới đây là bản đọc THỨ HAI của cùng hình
// dạng đó — đổi bên kia mà quên bên này thì trường mới không hiện ra.
//
// Vì thế MỌI trường không sống còn đều để `optional`, và không trường nào
// được phép làm hỏng cả màn hình: backend thêm một khoá lạ là chuyện bình
// thường, còn `JSONDecoder` ném vì một trường thiếu thì người dùng nhìn màn
// trắng không có lời giải thích nào.

// ─── Lộ trình ────────────────────────────────────────────────

struct KeHoachKyNang: Decodable, Hashable {
    let skill: String        // Nghe | Đọc | Viết | Nói
    let icon: String
    let daily: String
    let target: String
    let trap: String
}

struct ChangBand: Decodable, Identifiable, Hashable {
    let id: String
    let from: String
    let to: String
    let title: String
    let icon: String
    let duration: String
    let youAre: String
    let keyFocus: String
    let skills: [KeHoachKyNang]
    let checkpoints: [String]

    var band: String { "Band \(from) → \(to)" }
}

/// Một phần của chặng trong mục lục — `readings`, `vocab`…
struct PhanChang: Decodable, Hashable {
    let kind: String
    let soMuc: Int
    let daXong: Int

    var ten: String { PhanChang.tenPhan[kind] ?? kind }
    var bieuTuong: String { PhanChang.btPhan[kind] ?? "doc.text" }
    var tiLe: Double { soMuc > 0 ? Double(daXong) / Double(soMuc) : 0 }

    static let tenPhan: [String: String] = [
        "units": "Bài học", "vocab": "Từ vựng", "readings": "Đọc",
        "listenings": "Nghe", "writings": "Viết", "speakings": "Nói",
        "exercises": "Bài tập", "questionTypes": "Cẩm nang dạng đề",
    ]
    static let btPhan: [String: String] = [
        "units": "book.fill", "vocab": "character.book.closed.fill", "readings": "doc.text.fill",
        "listenings": "headphones", "writings": "pencil.and.outline", "speakings": "mic.fill",
        "exercises": "checklist", "questionTypes": "lightbulb.fill",
    ]
    /// Thứ tự hiện trên màn hình — theo đường HỌC, không theo bảng chữ cái.
    static let thuTu = ["units", "vocab", "readings", "listenings", "writings", "speakings", "exercises", "questionTypes"]
}

struct ChangIelts: Decodable, Identifiable, Hashable {
    let id: String           // stage1…stage4
    let coNoiDung: Bool
    let phan: [PhanChang]
    let tongMuc: Int
    let tongXong: Int
    let tiLe: Int

    var so: Int { Int(id.dropFirst(5)) ?? 1 }
    var phanTheoThuTu: [PhanChang] {
        phan.sorted { (PhanChang.thuTu.firstIndex(of: $0.kind) ?? 99) < (PhanChang.thuTu.firstIndex(of: $1.kind) ?? 99) }
    }
}

struct GoiLoTrinh: Decodable {
    let roadmap: BoLoTrinh?
    let chang: [ChangIelts]
    let daSeed: Bool
}

struct BoLoTrinh: Decodable {
    let stages: [ChangBand]
}

// ─── Bọc chung cho mọi phần nội dung ─────────────────────────

/// Máy chủ trả `{ stage, kind, soMuc, capNhatLuc, payload }`. `payload` mang
/// hình dạng khác nhau tuỳ `kind`, nên mỗi màn tự khai kiểu nó cần.
struct GoiNoiDung<T: Decodable>: Decodable {
    let kind: String
    let soMuc: Int
    let payload: T
}

// ─── Từ vựng ─────────────────────────────────────────────────

struct TuVungIelts: Decodable, Hashable, Identifiable {
    let en: String
    let ipa: String
    let vi: String
    let pos: String?
    let ex: String
    let exVi: String
    var id: String { en }
}

struct ChuDeTuIelts: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let why: String
    let words: [TuVungIelts]
}

struct GoiTuVung: Decodable {
    let topics: [ChuDeTuIelts]
    let allWords: [TuVungIelts]
}

// ─── Đọc ─────────────────────────────────────────────────────

struct CauHoiDoc: Decodable, Hashable, Identifiable {
    let kind: String         // TFNG | YNNG | MCQ | GAP | MATCH | HEADING
    let q: String
    let options: [String]?
    let answer: String
    let alt: [String]?
    let why: String
    let whyNot: String?

    /// Không có `id` trong dữ liệu gốc — dựng từ nội dung để `ForEach` ổn định.
    var id: String { "\(kind)|\(q)" }

    /// Dạng phải tự GÕ đáp án, không có nút để chọn.
    var phaiGo: Bool { kind == "GAP" }

    /// TFNG/YNNG không kèm `options` trong dữ liệu — ba lựa chọn là cố định
    /// của chính dạng đề, không phải thứ người soạn phải gõ lại mỗi câu.
    var luaChon: [String] {
        if let o = options, !o.isEmpty { return o }
        switch kind {
        case "TFNG": return ["TRUE", "FALSE", "NOT GIVEN"]
        case "YNNG": return ["YES", "NO", "NOT GIVEN"]
        default: return []
        }
    }

    /// So đáp án: bỏ hoa thường, bỏ khoảng trắng thừa, chấp cả `alt`.
    func dung(_ traLoi: String) -> Bool {
        let chuan = { (s: String) in
            s.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "  ", with: " ")
        }
        let t = chuan(traLoi)
        if t.isEmpty { return false }
        if chuan(answer) == t { return true }
        return (alt ?? []).contains { chuan($0) == t }
    }
}

struct DoanVan: Decodable, Hashable {
    let label: String
    let text: String
}

struct TuKho: Decodable, Hashable, Identifiable {
    let en: String
    let ipa: String
    let vi: String
    var id: String { en }
}

struct BaiDocIelts: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let titleVi: String
    let level: String
    let words: Int
    let minutes: Int
    let paragraphs: [DoanVan]
    let glossary: [TuKho]
    let questions: [CauHoiDoc]
    let strategy: [String]
    let translation: String

    /// Toàn văn để đưa cho AI khi hỏi — có nhãn đoạn để AI trích đúng chỗ.
    var toanVan: String {
        paragraphs.map { "\($0.label). \($0.text)" }.joined(separator: "\n\n")
    }
}

// ─── Nghe ────────────────────────────────────────────────────

struct CauHoiNgheIelts: Decodable, Hashable, Identifiable {
    let q: String
    let answer: String
    let alt: [String]?
    let why: String
    var id: String { q }

    func dung(_ traLoi: String) -> Bool {
        let chuan = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let t = chuan(traLoi)
        if t.isEmpty { return false }
        return chuan(answer) == t || (alt ?? []).contains { chuan($0) == t }
    }
}

struct DongThoai: Decodable, Hashable {
    let who: String
    let text: String
}

struct BaiNgheIelts: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let titleVi: String
    let kind: String
    let level: String
    let context: String
    let lines: [DongThoai]
    let questions: [CauHoiNgheIelts]
    let listenFor: [String]
    let tips: [String]
}

struct GoiNghe: Decodable {
    let items: [BaiNgheIelts]
}

// ─── Viết ────────────────────────────────────────────────────

struct DanY: Decodable, Hashable {
    let part: String
    let what: String
}

struct CumTu: Decodable, Hashable, Identifiable {
    let en: String
    let vi: String
    var id: String { en }
}

struct BaiMau: Decodable, Hashable {
    let band: String
    let text: String
    let note: String?
}

struct LoiHayMac: Decodable, Hashable, Identifiable {
    let wrong: String
    let right: String
    let why: String
    var id: String { wrong }
}

struct DeVietIelts: Decodable, Identifiable, Hashable {
    let id: String
    let task: String
    let title: String
    let prompt: String
    let promptVi: String
    let minWords: Int
    let minutes: Int
    let outline: [DanY]
    let phrases: [CumTu]
    let sample: BaiMau
    /// Bài mẫu KÉM để đối chiếu. Nhìn cái sai mới nhớ cái đúng — bản đầu
    /// tôi bỏ sót trường này, và mất đúng nửa giá trị của phần Viết.
    let weakSample: BaiMauKem?
    let mistakes: [LoiHayMac]
}

struct BaiMauKem: Decodable, Hashable {
    let band: String
    let text: String
    let problems: [String]
}

// ─── Nói ─────────────────────────────────────────────────────

struct CauHoiNoi: Decodable, Hashable, Identifiable {
    let q: String
    let qVi: String
    let weak: String
    let good: String
    let goodVi: String
    let why: String
    var id: String { q }
}

struct ChuDeNoiIelts: Decodable, Identifiable, Hashable {
    let id: String
    let part: String         // "Part 1" | "Part 2" | "Part 3"
    let title: String
    let titleVi: String
    let questions: [CauHoiNoi]
    let phrases: [CumTu]?
}

struct GoiNoi: Decodable {
    let topics: [ChuDeNoiIelts]
}

// ─── Bài học ─────────────────────────────────────────────────

struct ViDuCau: Decodable, Hashable, Identifiable {
    let en: String
    let vi: String
    var id: String { en }
}

struct KhoiNguPhap: Decodable, Hashable {
    let formula: String?
    let explain: String
    let examples: [ViDuCau]
    let mistake: LoiHayMac?
}

/// ⚠️ TÊN TRƯỜNG PHẢI KHỚP `types.ts` CỦA WEB, KHÔNG ĐƯỢC ĐẶT LẠI CHO XUÔI TAI.
///
/// Bản đầu tiên tôi khai `grammar` và `words` vì nghe hợp lý hơn. Dữ liệu
/// thật tên là `blocks` và `keyWords`, nên hai trường đó KHÔNG BAO GIỜ giải
/// mã được và luôn là `nil` — màn Bài học chỉ hiện đúng một dòng `goal` rồi
/// trống trơn. Không có lỗi, không có cảnh báo: chỉ là một khoá học trông
/// như chẳng có gì để học. Người dùng báo 19/09/2026.
///
/// Và `practice` thì tôi quên hẳn — mất luôn phần việc tự làm sau mỗi bài,
/// vốn là thứ biến một bài đọc hiểu thành một bài học.
struct BaiHocIelts: Decodable, Identifiable, Hashable {
    let id: String
    /// Số thứ tự bài trong cả chặng (1–40).
    let n: Int?
    let title: String
    /// Học xong LÀM ĐƯỢC gì — viết bằng động từ.
    let goal: String?
    /// Phần giảng chính. Tên `blocks` là của web, giữ nguyên.
    let blocks: [KhoiNguPhap]?
    /// Từ cần thuộc ngay trong bài — chỉ có en/ipa/vi, KHÁC `TuVungIelts`
    /// (cái kia còn có từ loại và câu ví dụ).
    let keyWords: [TuKho]?
    /// Việc tự làm sau bài, phải kiểm được.
    let practice: [String]?
}

struct ChuDiemIelts: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String?
    let lessons: [BaiHocIelts]
}

// ─── Tiến độ ─────────────────────────────────────────────────

struct MucTienDo: Decodable, Hashable {
    let stage: String
    let kind: String
    let muc: String
    let xong: Bool
    let diem: Int?
    /// ⚠️ Máy chủ VẪN GỬI trường này (`select` trong `layTienDo` có nó), chỉ
    /// là mô hình cũ không khai nên nó rơi mất. Đây là thứ duy nhất tính được
    /// CHUỖI NGÀY học — không có nó thì phải thêm bảng mới ở backend cho một
    /// dữ liệu vốn đã nằm sẵn trong tay.
    let updatedAt: String?
}

struct GoiTienDo: Decodable {
    let items: [MucTienDo]
}
