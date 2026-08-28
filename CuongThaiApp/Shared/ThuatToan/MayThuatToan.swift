import Foundation
import JavaScriptCore

// ════════════════════════════════════════════════════════════════
// MÁY CHẠY THUẬT TOÁN
//
// Chạy mã JS của thuật toán trong `JSContext` (có sẵn trên iOS, không thêm
// phụ thuộc), rồi lấy TỪNG KHUNG một để vẽ.
//
// ⚠️ KHÔNG kéo cả mảng khung sang Swift một lượt. Mỗi khung là ảnh chụp đầy
// đủ của mọi tracer; một thuật toán vài nghìn bước là hàng chục MB JSON, mà
// mỗi lúc chỉ vẽ đúng một khung. Giữ khung trong `JSContext`, hỏi cái nào lấy
// cái đó.
//
// ⚠️ Mã người dùng có thể lặp vô tận. `JSContext` KHÔNG có `terminate()` như
// Web Worker, nên chặn bằng hai lớp: `exceptionHandler` bắt lỗi cú pháp, và
// chính động cơ JS có trần 300.000 lệnh (`CAP` trong `engine.ts`) — chạm trần
// là nó NÉM lỗi, tức vòng lặp vô tận sẽ dừng ở đó thay vì treo máy.
// ════════════════════════════════════════════════════════════════

@MainActor
final class MayThuatToan: ObservableObject {
    @Published private(set) var soKhung = 0
    @Published private(set) var tracer: [MetaTracer] = []
    @Published private(set) var dongMa: [Int] = []
    @Published private(set) var loi: String?
    @Published private(set) var dangChay = false

    private var ctx: JSContext?
    private var demKhung: [Int: [String: TrangThaiTracer]] = [:]

    /// Chạy một đoạn mã. Trả về `false` nếu hỏng (lý do ở `loi`).
    @discardableResult
    func chay(_ ma: String) async -> Bool {
        dangChay = true
        defer { dangChay = false }
        soKhung = 0; tracer = []; dongMa = []; loi = nil; demKhung = [:]

        // Chạy ở luồng nền: một thuật toán nặng mất vài trăm ms, làm ở luồng
        // chính là khựng hẳn giao diện.
        let kq: (Int, [MetaTracer], [Int], String?) = await Task.detached(priority: .userInitiated) {
            let c = JSContext()!
            var loiJS: String?
            c.exceptionHandler = { _, e in loiJS = e?.toString() ?? "Lỗi JS" }
            c.evaluateScript(DongCoJS.nguon)
            if let l = loiJS { return (0, [], [], "Động cơ hỏng: \(l)") }

            let ham = c.objectForKeyedSubscript("ctsNap")
            guard let r = ham?.call(withArguments: [ma]), !r.isUndefined,
                  let chu = r.toString(), let d = chu.data(using: .utf8) else {
                return (0, [], [], loiJS ?? "Không chạy được mã.")
            }
            struct DapAn: Decodable {
                let ok: Bool; let error: String?; let soKhung: Int?
                let metas: [MetaTracer]?; let lines: [Int]?
            }
            guard let a = try? JSONDecoder().decode(DapAn.self, from: d) else {
                return (0, [], [], "Kết quả không đọc được.")
            }
            guard a.ok else { return (0, [], [], a.error ?? "Mã lỗi.") }
            // Giữ ngữ cảnh sống bằng cách trả nó ra ngoài qua hộp.
            HopNguCanh.dat(c)
            return (a.soKhung ?? 0, a.metas ?? [], a.lines ?? [], nil)
        }.value

        ctx = HopNguCanh.lay()
        soKhung = kq.0; tracer = kq.1; dongMa = kq.2; loi = kq.3
        return loi == nil
    }

    /// Khung thứ `i`. Đã lấy rồi thì trả bản nhớ — tua đi tua lại là chuyện
    /// thường, giải mã JSON mỗi lần là phí.
    func khung(_ i: Int) -> [String: TrangThaiTracer] {
        if let c = demKhung[i] { return c }
        guard let ctx, i >= 0, i < soKhung else { return [:] }
        guard let r = ctx.objectForKeyedSubscript("ctsKhung")?.call(withArguments: [i]),
              let chu = r.toString(), let d = chu.data(using: .utf8),
              let m = try? JSONDecoder().decode([String: TrangThaiTracer].self, from: d)
        else { return [:] }
        // Giữ tối đa 400 khung: tua qua một thuật toán 5.000 bước mà nhớ hết
        // là ăn hết bộ nhớ đúng theo cách vừa tránh được ở trên.
        if demKhung.count > 400 { demKhung.removeAll(keepingCapacity: true) }
        demKhung[i] = m
        return m
    }
}

/// `JSContext` phải sống sau khi `Task.detached` kết thúc, mà `JSContext`
/// không `Sendable`. Hộp này là chỗ gửi tạm, dùng ngay trong cùng một lượt.
private enum HopNguCanh {
    nonisolated(unsafe) private static var giu: JSContext?
    static func dat(_ c: JSContext) { giu = c }
    static func lay() -> JSContext? { let c = giu; giu = nil; return c }
}

// MARK: - Mô hình khung

struct MetaTracer: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let title: String
}

/// Một tracer tại một bước. Sáu loại dùng chung một vỏ vì `buildFrames` của
/// web trả về map `id → state` với `kind` phân biệt.
struct TrangThaiTracer: Codable, Hashable {
    let kind: String
    let title: String?

    // array1d · chart
    let data: [Double]?
    let selected: [Int]?
    let patched: [Int]?

    // log
    let lines: [String]?

    // graph
    let directed: Bool?
    let nodes: [NutDoThi]?
    let edges: [CanhDoThi]?

    // array2d — `selected`/`patched` ở đây là khoá "r,c" nên phải tên khác
    let data2: [[Double]]?
    let selectedKeys: [String]?
    let patchedKeys: [String]?

    // grid
    let rows: Int?
    let cols: Int?
    let walls: [Bool]?
    let weights: [Double]?
    let states: [String]?
    let start: String?
    let goal: String?

    enum CodingKeys: String, CodingKey {
        case kind, title, data, selected, patched, lines, directed, nodes, edges
        case rows, cols, walls, weights, states, start, goal
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "log"
        title = try? c.decode(String.self, forKey: .title)
        lines = try? c.decode([String].self, forKey: .lines)
        directed = try? c.decode(Bool.self, forKey: .directed)
        nodes = try? c.decode([NutDoThi].self, forKey: .nodes)
        edges = try? c.decode([CanhDoThi].self, forKey: .edges)
        rows = try? c.decode(Int.self, forKey: .rows)
        cols = try? c.decode(Int.self, forKey: .cols)
        walls = try? c.decode([Bool].self, forKey: .walls)
        weights = try? c.decode([Double].self, forKey: .weights)
        states = try? c.decode([String].self, forKey: .states)
        start = try? c.decode(String.self, forKey: .start)
        goal = try? c.decode(String.self, forKey: .goal)

        // ⚠️ `data` là [Double] ở array1d/chart nhưng [[Double]] ở array2d;
        // `selected` là [Int] ở array1d nhưng ["r,c"] ở array2d. Cùng TÊN
        // KHOÁ, khác KIỂU — thử cả hai chứ đừng chọn theo `kind`, vì bản ghi
        // rỗng lúc mới tạo có thể không lộ ra kiểu nào.
        data = try? c.decode([Double].self, forKey: .data)
        data2 = try? c.decode([[Double]].self, forKey: .data)
        selected = try? c.decode([Int].self, forKey: .selected)
        selectedKeys = try? c.decode([String].self, forKey: .selected)
        patched = try? c.decode([Int].self, forKey: .patched)
        patchedKeys = try? c.decode([String].self, forKey: .patched)
    }

    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(title, forKey: .title)
    }
}

struct NutDoThi: Codable, Hashable, Identifiable {
    let id: String
    let weight: Double?
    let x: Double?
    let y: Double?
    let visited: Bool
    let selected: Bool
}

struct CanhDoThi: Codable, Hashable {
    let source: String
    let target: String
    let weight: Double?
    let visited: Bool
    let selected: Bool
}
