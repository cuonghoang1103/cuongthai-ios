import Foundation

// MARK: - JSON thô GIỮ NGUYÊN cấu trúc (đọc ⇒ sửa vài trường ⇒ gửi lại)
//
// Vì sao: kế hoạch của "Create with CuongMini" (`SetupPlan`) rất to (dự án, thành viên, sprint, mô-đun, epic/story,
// trang Docs, test, rủi ro, họp…) và máy chủ kiểm CHẶT khi PATCH. App chỉ sửa vài trường; khai struct Codable cho cả cây
// thì mỗi trường app không khai sẽ RƠI MẤT khi gửi lại (CLAUDE.md C4 — mất im lặng). Giữ cây JSON gốc, sửa đúng chỗ,
// gửi lại nguyên vẹn; phần hiển thị giải mã riêng bằng model có kiểu (`CTWKeHoachCM`).

enum CTWJSON: Codable, Equatable {
    case chuoi(String)
    case so(Double)
    case bool(Bool)
    case null
    case mang([CTWJSON])
    case doiTuong([String: CTWJSON])

    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .so(n) }
        else if let s = try? c.decode(String.self) { self = .chuoi(s) }
        else if let a = try? c.decode([CTWJSON].self) { self = .mang(a) }
        else { self = .doiTuong(try c.decode([String: CTWJSON].self)) }
    }

    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        switch self {
        case .chuoi(let s): try c.encode(s)
        // Số nguyên gửi dạng nguyên ("5", không "5.0") — zod `.int()` của máy chủ.
        case .so(let n): if n.rounded() == n, abs(n) < 1e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .mang(let a): try c.encode(a)
        case .doiTuong(let o): try c.encode(o)
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

    var mang: [CTWJSON]? { if case .mang(let a) = self { return a }; return nil }
    var chuoi: String? { if case .chuoi(let s) = self { return s }; return nil }
    var so: Double? { if case .so(let n) = self { return n }; return nil }

    /// Sang đối tượng Foundation (thân yêu cầu của `CTWAPI.goi`).
    var foundation: Any {
        switch self {
        case .chuoi(let s): return s
        case .so(let n): return n.rounded() == n && abs(n) < 1e15 ? Int(n) as Any : n as Any
        case .bool(let b): return b
        case .null: return NSNull()
        case .mang(let a): return a.map(\.foundation)
        case .doiTuong(let o): return o.mapValues(\.foundation)
        }
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
