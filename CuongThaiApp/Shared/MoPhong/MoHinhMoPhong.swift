import SwiftUI

// ════════════════════════════════════════════════════════════════
// MÔ PHỎNG (web: /simulation) — mô hình dữ liệu
//
// Đo thật 28/08/2026 trên 62 kịch bản:
//   · 20 kịch bản vẽ SƠ ĐỒ MẠNG (nút + cạnh + gói tin chạy trên dây)
//   · 42 kịch bản vẽ PANEL — và đây mới là phần chính, ngược hẳn với cái tên
//     "network animation" gợi ra
//   · 0 kịch bản dùng cả hai ⇒ mỗi màn chỉ cần một bộ vẽ
//   · 382 bước, 243 bước có `ops`
//   · Panel theo loại: log 42 · code 39 · lanes 26 · chart 19 · meter 17 ·
//     table 15 · tree 6 · stack 2 · race 1 · membrane 1
//   · Khung toạ độ: **1000 × 560**, panel đặt tuyệt đối trong đó
// ════════════════════════════════════════════════════════════════

let SAN_KHAU_W: Double = 1000
let SAN_KHAU_H: Double = 560

/// Chuỗi song ngữ của web. Thiếu bản Anh thì lùi về tiếng Việt.
struct ChuSongNgu: Codable, Hashable {
    let vi: String?
    let en: String?
    func chu(_ anh: Bool) -> String {
        if anh, let e = en, !e.isEmpty { return e }
        return vi ?? en ?? ""
    }
}

struct NhomMoPhong: Codable, Identifiable, Hashable {
    let id: String
    let name: ChuSongNgu?
    let blurb: ChuSongNgu?
    let accent: String?
    var mau: Color { mauHex(accent, mac: 0x38BDF8) }
}

struct KichBan: Codable, Identifiable, Hashable {
    let id: String
    let name: ChuSongNgu?
    let tagline: ChuSongNgu?
    let icon: String?
    let accent: String?
    let group: String?
    /// Bài học trên web mà kịch bản này minh hoạ — cho người đọc đường đi tiếp.
    let lesson: BaiHocMP?
    let nodes: [NutMP]?
    let edges: [CanhMP]?
    let options: [TuyChonMP]?

    var cacNut: [NutMP] { nodes ?? [] }
    var cacCanh: [CanhMP] { edges ?? [] }
    var cacTuyChon: [TuyChonMP] { options ?? [] }
    var laSoDo: Bool { !cacNut.isEmpty }
    var mau: Color { mauHex(accent, mac: 0x38BDF8) }
    /// `icon` là tên bộ **lucide** của web — bắc sang SF Symbols.
    var bieuTuong: String { BieuTuongLucide.sf(icon) }
}

struct BaiHocMP: Codable, Hashable {
    let course: String?
    let code: String?
    let slug: String?
    let title: ChuSongNgu?
}

struct NutMP: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let sublabel: ChuSongNgu?
    let kind: String?
    let x: Double
    let y: Double
    let badge: String?
    /// 13 loại nút của web, mỗi loại một biểu tượng.
    var bieuTuong: String {
        switch (kind ?? "").lowercased() {
        case "client": return "iphone"
        case "edge": return "shield.lefthalf.filled"
        case "gateway": return "arrow.triangle.branch"
        case "server": return "server.rack"
        case "cache": return "bolt.horizontal"
        case "db": return "cylinder.split.1x2"
        case "queue": return "tray.2"
        case "worker": return "gearshape.2"
        case "auth": return "key"
        case "socket": return "antenna.radiowaves.left.and.right"
        case "storage": return "externaldrive"
        case "ci": return "hammer"
        case "index": return "list.bullet.indent"
        default: return "circle"
        }
    }
}

struct CanhMP: Codable, Identifiable, Hashable {
    let id: String
    let from: String
    let to: String
    let label: ChuSongNgu?
    let curve: Double?
}

struct TuyChonMP: Codable, Identifiable, Hashable {
    let id: String
    let label: ChuSongNgu?
    let defaultValue: String?
    let choices: [LuaChonMP]?
    var cacLuaChon: [LuaChonMP] { choices ?? [] }
}

struct LuaChonMP: Codable, Identifiable, Hashable {
    let value: String
    let label: String?
    let color: String?
    let hint: ChuSongNgu?
    var id: String { value }
    var mau: Color? { color.map { mauHex($0, mac: 0x64748B) } }
}

// MARK: - Bước

struct BuocMP: Codable, Identifiable, Hashable {
    let id: String
    let title: ChuSongNgu?
    let detail: ChuSongNgu?
    let teachingNote: ChuSongNgu?
    let edge: String?
    let at: String?
    let reverse: Bool?
    let kind: String?
    let duration: Double?
    let latencyMs: Double?
    let packetLabel: String?
    let status: Int?
    let headers: [String: String]?
    let query: [String: String]?
    let nodeStates: [String: String]?
    let ops: [ThaoTacPanel]?
    let log: ChuSongNgu?
    /// Tên hiệu ứng âm thanh kịch bản chọn cho bước này — 9 tên, xem `TiengMP`.
    let sfx: String?

    var cacOps: [ThaoTacPanel] { ops ?? [] }
    /// 13 loại luồng — quyết định màu viên gói tin.
    var mauLuong: Color {
        switch (kind ?? "").uppercased() {
        case "GET", "QUERY": return Color(hex: 0x10B981)
        case "POST", "PUT": return Color(hex: 0x3B82F6)
        case "DELETE", "ERROR": return Color(hex: 0xEF4444)
        case "RESPONSE", "ACK": return Color(hex: 0x22C55E)
        case "CACHE_HIT": return Color(hex: 0x06B6D4)
        case "CACHE_MISS": return Color(hex: 0xF59E0B)
        case "TOKEN": return Color(hex: 0xA855F7)
        case "EVENT": return Color(hex: 0xEC4899)
        default: return Color(hex: 0x94A3B8)
        }
    }
}

// MARK: - Panel

struct PanelMP: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let title: ChuSongNgu?
    let hint: ChuSongNgu?
    let x: Double?
    let y: Double?
    let w: Double?
    let h: Double?
    let accent: String?

    // code
    let file: String?
    let lines: [String]?
    let startLine: Int?
    // log
    let maxLines: Int?
    // lanes
    let lanes: [LanMP]?
    let layout: String?
    // meter
    let meters: [DongHoMP]?
    // chart
    let mode: String?
    let series: [ChuoiMP]?
    let max: Double?
    let unit: String?
    let xLabel: ChuSongNgu?
    let xMax: Double?
    // table
    let columns: [CotMP]?
    // stack
    let floor: ChuSongNgu?
    // race
    let tracks: [LanMP]?
    let better: String?
    let showDelta: Bool?
    // membrane
    let layers: [LanMP]?
    // ⚠️ `sink`/`source` của web là OBJECT, không phải chuỗi. Khai `String?`
    // KHÔNG "bỏ qua nếu sai kiểu": `decodeIfPresent` vẫn NÉM khi gặp object,
    // và một trường ném là hỏng CẢ panel. Bỏ hẳn — `membrane` chỉ có ở 1/62
    // kịch bản và hai trường này không cần để vẽ.

    var mau: Color { mauHex(accent, mac: 0x64748B) }
    var khung: CGRect {
        CGRect(x: x ?? 0, y: y ?? 0, width: w ?? SAN_KHAU_W, height: h ?? 200)
    }
}

/// ⚠️ `label` ở đây là CHUỖI THUẦN, không phải khối `{vi,en}` — đo thật trên
/// `lanes`, `layers`, `meters`, `series`, `tracks`, `columns` đều vậy. Chỉ
/// `sub`/`hint` mới song ngữ. Khai nhầm `ChuSongNgu?` là hỏng cả bản giải mã
/// panel, và màn hình chỉ nói "Kết quả dựng không đọc được".
struct LanMP: Codable, Identifiable, Hashable {
    let id: String
    let label: String?
    let sub: ChuSongNgu?
    let accent: String?
    let hint: ChuSongNgu?
    var mau: Color? { accent.map { mauHex($0, mac: 0x64748B) } }
}

struct CotMP: Codable, Identifiable, Hashable {
    let id: String?
    let label: String?
    var idOn: String { id ?? label ?? "" }
}

struct DongHoMP: Codable, Identifiable, Hashable {
    let id: String
    let label: String?
    let max: Double?
    let unit: String?
    let accent: String?
}

struct ChuoiMP: Codable, Identifiable, Hashable {
    let id: String
    let label: String?
    let accent: String?
}

// MARK: - Thao tác

/// Chín thao tác: push · pop · shift · clear · tone · active · lines · value ·
/// point. Trường `p` là id panel (web đặt tên một chữ cái vì mỗi kịch bản viết
/// hàng trăm dòng ops).
struct ThaoTacPanel: Codable, Hashable {
    let p: String
    let op: String
    let lane: String?
    let n: Int?
    let key: String?
    let badge: String?
    let sub: String?
    let tone: String?
    let label: String?
    let x: Double?
    let y: Double?
    /// `value` khi op = `active` là chuỗi (hoặc null), khi op = `value` là số,
    /// khi op = `lines` là mảng số. Ba kiểu, cùng một tên khoá.
    let valueChu: String?
    let valueSo: Double?
    let valueMang: [Int]?
    let item: [MucPanel]?

    enum CodingKeys: String, CodingKey {
        case p, op, lane, n, key, badge, sub, tone, label, x, y, value, item
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        p = (try? c.decode(String.self, forKey: .p)) ?? ""
        op = (try? c.decode(String.self, forKey: .op)) ?? ""
        lane = try? c.decode(String.self, forKey: .lane)
        n = try? c.decode(Int.self, forKey: .n)
        key = try? c.decode(String.self, forKey: .key)
        badge = try? c.decode(String.self, forKey: .badge)
        sub = try? c.decode(String.self, forKey: .sub)
        tone = try? c.decode(String.self, forKey: .tone)
        label = try? c.decode(String.self, forKey: .label)
        x = try? c.decode(Double.self, forKey: .x)
        y = try? c.decode(Double.self, forKey: .y)
        valueChu = try? c.decode(String.self, forKey: .value)
        valueSo = try? c.decode(Double.self, forKey: .value)
        valueMang = try? c.decode([Int].self, forKey: .value)
        // `item` là MỘT mục hoặc MẢNG mục — web cho phép cả hai để viết kịch
        // bản gọn hơn. Nhận cả hai, đừng bắt kịch bản phải sửa.
        if let m = try? c.decode([MucPanel].self, forKey: .item) { item = m }
        else if let m = try? c.decode(MucPanel.self, forKey: .item) { item = [m] }
        else { item = nil }
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(p, forKey: .p); try c.encode(op, forKey: .op)
    }
}

struct MucPanel: Codable, Hashable, Identifiable {
    let id: String?
    let label: String?
    let sub: String?
    let badge: String?
    let tone: String?
    let cells: [String]?
    let depth: Int?
    /// SwiftUI cần id ổn định; mục không khai `id` thì lấy nhãn.
    var idOn: String { id ?? label ?? UUID().uuidString }
}

/// Sắc thái của một mục — bảng màu giữ đúng nghĩa của web.
func mauSacThai(_ t: String?) -> Color {
    switch (t ?? "").lowercased() {
    case "good", "success", "hit": return Color(hex: 0x22C55E)
    case "bad", "error", "miss": return Color(hex: 0xEF4444)
    case "warn", "warning": return Color(hex: 0xF59E0B)
    case "info", "active": return Color(hex: 0x3B82F6)
    case "muted", "dim": return Color(hex: 0x64748B)
    default: return Color(hex: 0x94A3B8)
    }
}

func mauHex(_ s: String?, mac: UInt32) -> Color {
    guard let s, s.hasPrefix("#"), let v = UInt32(s.dropFirst(), radix: 16) else {
        return Color(hex: mac)
    }
    return Color(hex: v)
}
