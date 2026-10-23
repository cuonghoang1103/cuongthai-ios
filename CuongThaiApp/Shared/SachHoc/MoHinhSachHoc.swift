import Foundation

// ════════════════════════════════════════════════════════════════
// SÁCH HỌC — mô hình dữ liệu (23/10/2026)
//
// Bộ máy NATIVE cho các khoá "kiểu sách" của web (`frontend/src/components/
// sach-hoc/`): できる日本語 (Dekiru) là khoá đầu tiên, IELTS nền tảng 15 ngày,
// JP, CH dùng lại nguyên bộ này. Nội dung KHÔNG gõ lại trong Swift: web sinh
// JSON lúc `next build` (`frontend/scripts/sach-hoc-xuat.mts`, gọi thẳng code
// web) ⇒ `https://cuongthai.com/sach-hoc/<khoa>/index.json` + `bai-<n>.json`.
//
// Khối (`Block` của web, `types.ts`) có 27 loại, nhận diện bằng khoá `t`.
// ⚠️ Giải mã TỪNG KHỐI riêng, lỗi khối nào thì khối đó thành `.loi` — một
// trường lệch kiểu KHÔNG được làm hỏng cả bài (bài học 28/08: `String?` vẫn
// ném khi sai kiểu, một trường lệch là mất cả đối tượng). Loại khối app chưa
// biết (web thêm sau) ⇒ `.chuaBiet`, hiện "chưa hỗ trợ" chứ không vỡ.
// ════════════════════════════════════════════════════════════════

/// Phiên bản định dạng app hiểu được. `index.json` có `schema` lớn hơn ⇒ báo cập nhật app.
let SACH_HOC_SCHEMA = 1

// MARK: - Mục lục khoá (index.json)

struct KhoaSH: Decodable, Equatable {
    let schema: Int
    let khoa: String
    let tieuDe: String
    let donVi: String
    var chuHuyHieu: String?
    let ngonNgu: String          // ja | zh | en
    let giong: String            // ja-nu, uk-nu…
    let stage: String            // khoá tiến độ trên máy chủ (dekiru1…)
    var duongWeb: String?
    var nhanLoai: [String: String] = [:]
    var nhanLoaiPhu: [String: String] = [:]
    var mauLoai: [String: String] = [:]
    let gioiThieu: BaiSH
    let buoi: [BuoiSH]
    var phu: [MucPhuSH] = []
    var chuHan: TepSH?
    var chia: TepSH?
    let phienBan: String
    var sinhLuc: String?

    func nhan(_ kind: String) -> String { nhanLoai[kind] ?? kind }
}

struct TepSH: Codable, Equatable {
    let tep: String
    let hash: String
    var kb: Double?
}

struct BuoiSH: Codable, Equatable, Identifiable {
    let n: Int
    let so: Int
    let ten: String
    var phut: Int = 0
    var nguPhap: [String] = []
    var soTu: Int = 0
    var baiTap: [BaiTapMetaSH] = []
    let bai: [BaiMetaSH]
    var tep: String?
    var hash: String?
    var kb: Double?
    var id: Int { n }
}

struct BaiTapMetaSH: Codable, Equatable {
    let id: String
    let title: String
    let lessonId: String
    let count: Int
}

struct BaiMetaSH: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let kind: String
    let title: String
    var goal: String = ""
    var minutes: Int = 0
    var ready: Bool = true
    /// Nhóm hiển thị (Dekiru: Bài học · Theo slide lớp · Luyện thêm · Theo sách).
    var nhom: String?
}

/// Mục tra cứu đứng ngoài các buổi (extras của web): Chia động từ, Ôn thẻ, đề luyện…
struct MucPhuSH: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let kind: String
    let title: String
    var goal: String = ""
    var minutes: Int = 0
    let tep: String
    let hash: String
    var kb: Double?
}

// MARK: - Nội dung (bai-<n>.json / phu-<id>.json)

struct TepBuoiSH: Decodable { let bai: [BaiSH] }
struct TepPhuSH: Decodable { let bai: BaiSH }

struct BaiSH: Decodable, Equatable, Identifiable {
    let id: String
    let kind: String
    let title: String
    var goal: String = ""
    var minutes: Int = 0
    var blocks: [KhoiSH] = []
    var videos: [VideoBaiSH]?
    var videoNeo: [String: [VideoMucSH]]?

    enum CodingKeys: String, CodingKey { case id, kind, title, goal, minutes, blocks, videos, videoNeo }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "intro"
        title = (try? c.decode(String.self, forKey: .title)) ?? id
        goal = (try? c.decode(String.self, forKey: .goal)) ?? ""
        minutes = (try? c.decode(Int.self, forKey: .minutes)) ?? 0
        blocks = ((try? c.decode([KhoiBoc].self, forKey: .blocks)) ?? []).map(\.khoi)
        videos = try? c.decode([VideoBaiSH].self, forKey: .videos)
        videoNeo = try? c.decode([String: [VideoMucSH]].self, forKey: .videoNeo)
    }
}

/// Video gắn theo bài (YouTube 11 ký tự, hoặc mp4 có `src`).
struct VideoBaiSH: Codable, Equatable {
    let id: String
    var src: String?
    var poster: String?
    var credit: String?
    var dur: String?
    var note: String?
}

/// Video mp4 gắn theo MỤC (`'dau-bai'` hoặc `'#<đầu tiêu đề>'`).
struct VideoMucSH: Codable, Equatable {
    let src: String
    let tieuDe: String
    var thoiLuongGiay: Double?
    var poster: String?
    var id: String?
    var ghiChu: String?
}

// MARK: - Khối

/// Câu ví dụ: `en` = câu ngoại ngữ (Anh HOẶC Nhật), `ro` = romaji/pinyin.
struct CauSH: Codable, Equatable { let en: String; var vi: String = ""; var ro: String? }

struct DongMauSH: Codable, Equatable { let formula: String; var vi: String = ""; var examples: [CauSH] = [] }
struct TuSH: Codable, Equatable {
    let w: String; var pos: String = ""; var ipa: String = ""; var vi: String = ""
    var ex: String = ""; var exVi: String = ""; var exRo: String?; var more: String?
}
struct NhomChuSH: Codable, Equatable { let sound: String; let letters: [ChuCaiSH] }
struct ChuCaiSH: Codable, Equatable { let l: String; var ipa: String = ""; var doc: String? }
struct ChepSH: Codable, Equatable { let label: String; let spell: String; let answer: String }
struct CauDienSH: Codable, Equatable { let q: String; var answers: [String] = []; var hint: String? }
struct CauChonSH: Codable, Equatable { let q: String; let options: [String]; let correct: Int; var why: String = "" }
struct DoanSH: Codable, Equatable { var label: String?; let text: String }
struct LoiNgheSH: Codable, Equatable { var who: String?; var voice: String?; let text: String; var ro: String?; var vi: String? }
struct LoiDanSH: Codable, Equatable { let so: String; var boiCanh: String?; var cau: [Int]? }
struct LoiThoaiSH: Codable, Equatable { let who: String; let role: String; let text: String; var vi: String?; var ro: String? }
struct ChuoiSH: Codable, Equatable { let name: String; let values: [Double] }
struct CauPhatAmSH: Codable, Equatable { let text: String; var ipa: String = ""; var vi: String? }
struct CauDocHanSH: Codable, Equatable { let text: String; var ro: String = ""; var vi: String = "" }
struct CauGhepSH: Codable, Equatable {
    let vi: String; let chips: [String]; let answer: [String]; var alt: [[String]]?; var ro: String?
}

enum KhoiSH: Equatable {
    case h(String)
    case p(String)
    case patterns([DongMauSH])
    case table(head: [String], rows: [[String]], caption: String?)
    case note(title: String, items: [String])
    case examples([CauSH])
    case vocab([TuSH])
    case recap(title: String?, items: [String])
    case rule(formula: String, vi: String?)
    case vocabAll
    case alphabet([NhomChuSH])
    case dictation(id: String, title: String?, items: [ChepSH])
    case quiz(id: String, title: String, kieu: String, grammar: String?, items: [CauDienSH])
    case mcq(id: String, title: String, items: [CauChonSH])
    case passage(title: String, intro: String?, paras: [DoanSH])
    case listen(id: String, title: String, note: String?, lines: [LoiNgheSH], dan: LoiDanSH?)
    case dialogue(title: String?, lines: [LoiThoaiSH])
    case essay(id: String, task: String, prompt: String, minWords: Int, tips: [String])
    case chart(kieu: String, title: String, unit: String?, labels: [String], series: [ChuoiSH])
    case speak(id: String, part: String, questions: [String])
    case phatam(id: String, title: String?, note: String?, items: [CauPhatAmSH])
    case readkanji(id: String, title: String, note: String?, items: [CauDocHanSH])
    case build(id: String, title: String, items: [CauGhepSH])
    case write(id: String, title: String, chars: [String], note: String?)
    case hanlop(bai: Int)
    case chia
    case onthe
    /// Loại khối app này chưa biết (web thêm sau bản app).
    case chuaBiet(String)
    /// Khối biết loại nhưng dữ liệu lệch — giữ lại để báo, không làm hỏng cả bài.
    case loi(String, String)

    var loai: String {
        switch self {
        case .h: "h"; case .p: "p"; case .patterns: "patterns"; case .table: "table"; case .note: "note"
        case .examples: "examples"; case .vocab: "vocab"; case .recap: "recap"; case .rule: "rule"
        case .vocabAll: "vocabAll"; case .alphabet: "alphabet"; case .dictation: "dictation"; case .quiz: "quiz"
        case .mcq: "mcq"; case .passage: "passage"; case .listen: "listen"; case .dialogue: "dialogue"
        case .essay: "essay"; case .chart: "chart"; case .speak: "speak"; case .phatam: "phatam"
        case .readkanji: "readkanji"; case .build: "build"; case .write: "write"; case .hanlop: "hanlop"
        case .chia: "chia"; case .onthe: "onthe"; case .chuaBiet(let t): t; case .loi(let t, _): t
        }
    }

    /// Khối bài tập — đứng NGOÀI khung ngữ pháp (như `IS_EXERCISE` của Blocks.tsx).
    var laBaiTap: Bool {
        ["vocabAll", "quiz", "mcq", "dictation", "listen", "essay", "speak", "phatam", "passage", "build", "readkanji", "write"].contains(loai)
    }
}

/// Bọc giải mã một khối — KHÔNG BAO GIỜ ném (xem đầu tệp).
private struct KhoiBoc: Decodable {
    let khoi: KhoiSH

    private struct K: CodingKey {
        var stringValue: String; var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from d: Decoder) {
        guard let c = try? d.container(keyedBy: K.self),
              let t = try? c.decode(String.self, forKey: K("t")) else {
            khoi = .loi("?", "khối không có khoá t")
            return
        }
        do { khoi = try KhoiBoc.giai(t, c) } catch { khoi = .loi(t, String(describing: error).prefix(200).description) }
    }

    private static func giai(_ t: String, _ c: KeyedDecodingContainer<K>) throws -> KhoiSH {
        func s(_ k: String) throws -> String { try c.decode(String.self, forKey: K(k)) }
        func so(_ k: String) -> String? { try? c.decode(String.self, forKey: K(k)) }
        func m<T: Decodable>(_ k: String, _: T.Type = T.self) throws -> T { try c.decode(T.self, forKey: K(k)) }
        switch t {
        case "h": return .h(try s("text"))
        case "p": return .p(try s("text"))
        case "patterns": return .patterns(try m("rows"))
        case "table": return .table(head: (try? m("head")) ?? [], rows: try m("rows"), caption: so("caption"))
        case "note": return .note(title: so("title") ?? "", items: try m("items"))
        case "examples": return .examples(try m("items"))
        case "vocab": return .vocab(try m("items"))
        case "recap": return .recap(title: so("title"), items: try m("items"))
        case "rule": return .rule(formula: try s("formula"), vi: so("vi"))
        case "vocabAll": return .vocabAll
        case "alphabet": return .alphabet(try m("groups"))
        case "dictation": return .dictation(id: try s("id"), title: so("title"), items: try m("items"))
        case "quiz": return .quiz(id: try s("id"), title: so("title") ?? "", kieu: so("kind") ?? "fill", grammar: so("grammar"), items: try m("items"))
        case "mcq": return .mcq(id: try s("id"), title: so("title") ?? "", items: try m("items"))
        case "passage": return .passage(title: so("title") ?? "", intro: so("intro"), paras: try m("paras"))
        case "listen": return .listen(id: try s("id"), title: so("title") ?? "", note: so("note"), lines: try m("lines"), dan: try? m("dan"))
        case "dialogue": return .dialogue(title: so("title"), lines: try m("lines"))
        case "essay": return .essay(id: try s("id"), task: so("task") ?? "", prompt: try s("prompt"), minWords: (try? m("minWords")) ?? 0, tips: (try? m("tips")) ?? [])
        case "chart": return .chart(kieu: so("kind") ?? "bar", title: so("title") ?? "", unit: so("unit"), labels: try m("labels"), series: try m("series"))
        case "speak": return .speak(id: try s("id"), part: so("part") ?? "", questions: try m("questions"))
        case "phatam": return .phatam(id: try s("id"), title: so("title"), note: so("note"), items: try m("items"))
        case "readkanji": return .readkanji(id: try s("id"), title: so("title") ?? "", note: so("note"), items: try m("items"))
        case "build": return .build(id: try s("id"), title: so("title") ?? "", items: try m("items"))
        case "write": return .write(id: try s("id"), title: so("title") ?? "", chars: try m("chars"), note: so("note"))
        case "hanlop": return .hanlop(bai: try m("bai"))
        case "chia": return .chia
        case "onthe": return .onthe
        default: return .chuaBiet(t)
        }
    }
}

// MARK: - Bảng chia (chia.json — khoá tiếng Nhật)

struct BangChiaSH: Decodable {
    struct DongTu: Decodable, Identifiable { let d: String; let vi: String; let nhom: Int; let bai: Int; let the: [String: String]; var id: String { d } }
    struct TinhTu: Decodable, Identifiable { let d: String; let vi: String; let loai: String; let bai: Int; let the: [String: String]; var id: String { d } }
    struct NhomHang: Decodable { let ten: String; let hang: [[String]] }
    let dongTu: [DongTu]
    let tinhTu: [TinhTu]
    let nhomDongTu: [NhomHang]
    let hangTinhTu: [[String]]
    var tenNhom: [String: String] = [:]
}

// MARK: - Chữ Hán (chu-han.json) — phần thẻ "Chữ Hán của lớp"

struct ChuHanSH: Decodable {
    struct Han: Decodable {
        var hv: String = ""; var nghia: String = ""; var on: [String] = []; var kun: [String] = []
        var nho: String?; var tu: [TuDiChung]?
        enum CodingKeys: String, CodingKey { case hv, nghia, on, kun, nho, tu }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            hv = (try? c.decode(String.self, forKey: .hv)) ?? ""
            nghia = (try? c.decode(String.self, forKey: .nghia)) ?? ""
            on = (try? c.decode([String].self, forKey: .on)) ?? []
            kun = (try? c.decode([String].self, forKey: .kun)) ?? []
            nho = try? c.decode(String.self, forKey: .nho)
            tu = try? c.decode([TuDiChung].self, forKey: .tu)
        }
    }
    struct TuDiChung: Decodable, Hashable { let w: String; var ro: String?; var vi: String? }
    struct Lop: Decodable { let chars: String; var nguon: String? }
    var han: [String: Han] = [:]
    var lop: [String: Lop] = [:]

    enum CodingKeys: String, CodingKey { case han, lop }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        han = (try? c.decode([String: Han].self, forKey: .han)) ?? [:]
        lop = (try? c.decode([String: Lop].self, forKey: .lop)) ?? [:]
    }
}
