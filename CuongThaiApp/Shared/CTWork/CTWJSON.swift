import Foundation

// MARK: - CT Work — JSON tự do GIỮ NGUYÊN (lossless)
//
// Vì sao không dùng `CTWNode`: `CTWNode` chỉ để HIỂN THỊ — nó bỏ `attrs`/`marks`
// khi mã hoá lại. Sửa mô tả thẻ (tick ô việc, soạn lại) mà đi qua `CTWNode` là
// làm rơi màu chữ, nhắc tên, ảnh, thuộc tính bảng… của người khác. Mọi chỗ GHI
// lại TipTap phải đi qua `CTWJSON` (đọc thô ⇒ sửa đúng chỗ ⇒ gửi lại thô).
//
// Mảng C dùng lại cho kế hoạch "Create with CuongMini" (`SetupPlan`): cây rất to, máy chủ kiểm CHẶT khi PATCH. App chỉ sửa
// vài trường; khai struct Codable cho cả cây thì mỗi trường app không khai sẽ RƠI MẤT khi gửi lại (CLAUDE.md C4 — mất im
// lặng). Giữ cây gốc, sửa đúng chỗ (`subscript` set, `suaTrongMang`), gửi lại nguyên vẹn; phần hiển thị giải mã riêng
// bằng model có kiểu (`giai`).

enum CTWJSON: Codable, Hashable {
    case null
    case bool(Bool)
    case so(Double)
    case chuoi(String)
    case mang([CTWJSON])
    case doiTuong([String: CTWJSON])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .so(n); return }
        if let s = try? c.decode(String.self) { self = .chuoi(s); return }
        if let a = try? c.decode([CTWJSON].self) { self = .mang(a); return }
        if let o = try? c.decode([String: CTWJSON].self) { self = .doiTuong(o); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        // Số nguyên gửi dạng nguyên ("5", không "5.0") — zod `.int()` của máy chủ, TipTap `level: 3`.
        case .so(let n): if n.rounded() == n, abs(n) < 1e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .chuoi(let s): try c.encode(s)
        case .mang(let a): try c.encode(a)
        case .doiTuong(let o): try c.encode(o)
        }
    }

    /// Dựng từ `Any` của JSONSerialization (dữ liệu mẫu, thân yêu cầu).
    init(_ x: Any?) {
        switch x {
        case nil, is NSNull: self = .null
        case let n as NSNumber:
            // NSNumber của JSONSerialization: bool là CFBoolean.
            if CFGetTypeID(n) == CFBooleanGetTypeID() { self = .bool(n.boolValue) } else { self = .so(n.doubleValue) }
        case let s as String: self = .chuoi(s)
        case let a as [Any]: self = .mang(a.map { CTWJSON($0) })
        case let o as [String: Any]: self = .doiTuong(o.mapValues { CTWJSON($0) })
        default: self = .null
        }
    }

    /// Ra `Any` để nhét vào thân yêu cầu (`CTWAPI.goi`). Số nguyên giữ dạng Int (TipTap `level: 3`, không `3.0`).
    var any: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .so(let n): return n == n.rounded() && abs(n) < 1e15 ? Int(n) : n
        case .chuoi(let s): return s
        case .mang(let a): return a.map(\.any)
        case .doiTuong(let o): return o.mapValues(\.any)
        }
    }

    subscript(_ k: String) -> CTWJSON? {
        get { if case .doiTuong(let o) = self { return o[k] }; return nil }
        set {
            guard case .doiTuong(var o) = self else { return }
            o[k] = newValue
            self = .doiTuong(o)
        }
    }

    /// Tên mảng C dùng — cùng nghĩa với `any`.
    var foundation: Any { any }

    var chuoi: String? { if case .chuoi(let s) = self { return s }; return nil }
    var so: Double? { if case .so(let n) = self { return n }; return nil }
    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var mang: [CTWJSON]? { if case .mang(let a) = self { return a }; return nil }
    var doiTuong: [String: CTWJSON]? { if case .doiTuong(let o) = self { return o }; return nil }
    var laNull: Bool { if case .null = self { return true }; return false }

    /// Đổi sang `CTWNode` (bộ dựng hiển thị sẵn có).
    var nut: CTWNode? {
        guard let d = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(CTWNode.self, from: d)
    }

    /// Giải mã cây này thành một model có kiểu (hiển thị).
    func giai<T: Decodable>(_ t: T.Type) -> T? {
        guard let d = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    /// Mã hoá một model có kiểu thành cây (đầu vào trình hướng dẫn đã khai đủ trường).
    static func tu<T: Encodable>(_ v: T) -> CTWJSON? {
        guard let d = try? JSONEncoder().encode(v) else { return nil }
        return try? JSONDecoder().decode(CTWJSON.self, from: d)
    }

    // MARK: Sửa tại chỗ trong mảng đối tượng (theo `ref`)

    /// Sửa phần tử có `ref == ref` trong mảng `self[khoa]` bằng `sua`. Trả false nếu không thấy.
    @discardableResult
    mutating func suaTrongMang(_ khoa: String, ref: String, khoaRef: String = "ref", _ sua: (inout CTWJSON) -> Void) -> Bool {
        guard var a = self[khoa]?.mang, let i = a.firstIndex(where: { $0[khoaRef]?.chuoi == ref }) else { return false }
        sua(&a[i])
        self[khoa] = .mang(a)
        return true
    }
}
