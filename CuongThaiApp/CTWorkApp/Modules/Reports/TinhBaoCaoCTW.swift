import Foundation

// MARK: - Tính toán THUẦN cho báo cáo (kiểm ở `KeHoachB1Tests`)

/// Một thanh của biểu đồ phân bố.
struct ThanhPhanBoCTW: Identifiable, Equatable {
    var id: String
    var nhan: String
    var giaTri: Double
    /// 0…1 trên tổng
    var tiLe: Double
    /// Màu gợi ý từ máy chủ (trạng thái) — nil ⇒ dùng màu theo vị trí cố định.
    var mauHex: String?
    var category: String?
    /// Vị trí màu cố định (0…7), 8 = "Other".
    var viTriMau: Int
}

struct DiemCfdCTW: Identifiable, Equatable {
    var id: String { "\(ymd)-\(dai)" }
    var ymd: String
    var ngay: Date
    var dai: String
    var tenDai: String
    var giaTri: Double
    /// Thứ tự xếp chồng (0 = dưới cùng).
    var thuTu: Int
}

enum TinhBaoCaoCTW {
    /// Phân bố: sắp theo giá trị giảm dần (ưu tiên: giữ thứ tự máy chủ), gộp phần quá `toiDa` thành "Other".
    /// `theoDiem` = dùng `points` thay vì `count`.
    static func phanBo(_ ds: [CTWNhomThongKe], theoDiem: Bool = false, toiDa: Int = 8, giuThuTu: Bool = false) -> [ThanhPhanBoCTW] {
        let gt: (CTWNhomThongKe) -> Double = { theoDiem ? ($0.points ?? 0) : Double($0.count ?? 0) }
        var nhom = ds.filter { gt($0) > 0 }
        if !giuThuTu { nhom.sort { gt($0) > gt($1) } }
        let tong = nhom.map(gt).reduce(0, +)
        guard tong > 0 else { return [] }
        var kq: [ThanhPhanBoCTW] = []
        for (i, g) in nhom.prefix(toiDa).enumerated() {
            kq.append(ThanhPhanBoCTW(id: g.key, nhan: g.label ?? g.key, giaTri: gt(g), tiLe: gt(g) / tong,
                                     mauHex: g.color, category: g.category, viTriMau: i))
        }
        if nhom.count > toiDa {
            let con = nhom.dropFirst(toiDa).map(gt).reduce(0, +)
            kq.append(ThanhPhanBoCTW(id: "__other", nhan: "Other (\(nhom.count - toiDa))", giaTri: con, tiLe: con / tong,
                                     mauHex: nil, category: nil, viTriMau: 8))
        }
        return kq
    }

    /// CFD: trải điểm ra từng (ngày, dải). Dải DONE nằm DƯỚI cùng (như web) ⇒ thứ tự ngược mảng `bands`.
    static func cfd(_ c: CTWCfd) -> [DiemCfdCTW] {
        let dai = c.bands ?? []
        var kq: [DiemCfdCTW] = []
        for p in c.points ?? [] {
            guard let d = NgayCTW.ngay(p.day) else { continue }
            for (i, b) in dai.reversed().enumerated() {
                kq.append(DiemCfdCTW(ymd: p.day, ngay: d, dai: b.key, tenDai: b.name ?? b.key, giaTri: p.giaTri[b.key] ?? 0, thuTu: i))
            }
        }
        return kq
    }

    /// Tổng created/resolved và chênh lệch (dương = tồn đọng tăng).
    static func taoXong(_ ds: [CTWTaoXongNgay]) -> (tao: Int, xong: Int, chenh: Int) {
        let t = ds.compactMap(\.created).reduce(0, +)
        let x = ds.compactMap(\.resolved).reduce(0, +)
        return (t, x, t - x)
    }

    /// Phút theo ngày (cộng mọi người) trên dải ngày [tu, den].
    static func phutTheoNgay(_ r: CTWBaoCaoThoiGian) -> [(ymd: String, ngay: Date, phut: Int)] {
        guard let a = NgayCTW.ngay(r.from), let b = NgayCTW.ngay(r.to) else { return [] }
        var kq: [(String, Date, Int)] = []
        var d = a
        while d <= b {
            let k = NgayCTW.ymd(d)
            let p = (r.people ?? []).map { $0.byDay?[k] ?? 0 }.reduce(0, +)
            kq.append((k, d, p))
            d = NgayCTW.cong(d, ngay: 1)
        }
        return kq.map { (ymd: $0.0, ngay: $0.1, phut: $0.2) }
    }

    /// Khoảng `n` ngày tính tới hôm nay (giờ VN) — "YYYY-MM-DD".
    static func khoang(_ n: Int, homNay: Date = Date()) -> (tu: String, den: String) {
        (NgayCTW.ymd(NgayCTW.cong(homNay, ngay: -(n - 1))), NgayCTW.ymd(homNay))
    }

    /// Tuần này (Thứ Hai → hôm nay).
    static func tuanNay(homNay: Date = Date()) -> (tu: String, den: String) {
        (NgayCTW.ymd(NgayCTW.dauTuan(homNay)), NgayCTW.ymd(homNay))
    }

    /// Phần trăm chênh so với kỳ trước (KPI) — nil khi không có số kỳ trước hoặc kỳ trước = 0.
    static func xuHuong(_ k: CTWKpiSo?) -> Double? {
        guard let v = k?.value, let p = k?.previous, p != 0 else { return nil }
        return (v - p) / p
    }
}
