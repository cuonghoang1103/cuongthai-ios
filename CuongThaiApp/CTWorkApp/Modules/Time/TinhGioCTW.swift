import Foundation

// MARK: - Phép tính THUẦN của chấm công (không gọi mạng ⇒ kiểm thử đơn vị được)

enum TinhGioCTW {
    /// Một ô của bảng tuần: ngày (VN) + số phút.
    struct Ngay: Hashable, Identifiable {
        var ngay: String       // "YYYY-MM-DD"
        var phut: Int
        var id: String { ngay }
    }

    /// 7 ngày Thứ Hai → Chủ Nhật của tuần bắt đầu `thuHai` ("YYYY-MM-DD").
    static func bayNgay(tuThuHai thuHai: String) -> [String] {
        guard let d = NgayCTW.ngay(thuHai) else { return [] }
        return (0..<7).map { NgayCTW.ymd(NgayCTW.cong(d, ngay: $0)) }
    }

    /// Cộng phút theo ngày của NHIỀU người (báo cáo giờ có thể trả nhiều dòng) — đủ 7 ngày, ngày trống = 0.
    static func theoNgay(_ nguoi: [CTWBaoCaoGio.Nguoi], tuThuHai thuHai: String) -> [Ngay] {
        var cong: [String: Int] = [:]
        for n in nguoi { for (k, v) in n.byDay ?? [:] { cong[k, default: 0] += v } }
        return bayNgay(tuThuHai: thuHai).map { Ngay(ngay: $0, phut: cong[$0] ?? 0) }
    }

    /// Tổng phút của tuần (chỉ tính 7 ngày của tuần, bỏ ngày lạc ngoài khoảng).
    static func tongTuan(_ ngay: [Ngay]) -> Int { ngay.reduce(0) { $0 + $1.phut } }

    /// Gộp thẻ trùng số (nhiều người cùng ghi một thẻ) rồi sắp phút giảm dần.
    static func theoThe(_ nguoi: [CTWBaoCaoGio.Nguoi]) -> [CTWBaoCaoGio.The] {
        var gop: [Int: CTWBaoCaoGio.The] = [:]
        for n in nguoi {
            for t in n.issues ?? [] {
                guard let so = t.number else { continue }
                var c = gop[so] ?? CTWBaoCaoGio.The(number: so, title: t.title, minutes: 0)
                c.minutes = (c.minutes ?? 0) + (t.minutes ?? 0)
                gop[so] = c
            }
        }
        return gop.values.sorted { ($0.minutes ?? 0, $1.number ?? 0) > ($1.minutes ?? 0, $0.number ?? 0) }
    }

    /// Phút → "1h 30m" · "45m" · "2h" · "0m".
    static func chuPhut(_ p: Int) -> String {
        let p = max(p, 0)
        let h = p / 60, m = p % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// "1h 30m" / "1.5h" / "90m" / "90" / "1:30" → phút (nil nếu không hiểu hoặc ngoài 1…1440).
    static func docPhut(_ s: String) -> Int? {
        let t = s.lowercased().replacingOccurrences(of: " ", with: "")
        guard !t.isEmpty else { return nil }
        var tong: Double = 0
        if t.contains(":") {
            let p = t.split(separator: ":").map(String.init)
            guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]), m < 60 else { return nil }
            tong = Double(h * 60 + m)
        } else if t.contains("h") || t.contains("m") {
            var so = ""
            for ch in t {
                if ch.isNumber || ch == "." || ch == "," { so.append(ch == "," ? "." : ch); continue }
                guard let v = Double(so) else { return nil }
                if ch == "h" { tong += v * 60 } else if ch == "m" { tong += v } else { return nil }
                so = ""
            }
            if !so.isEmpty { return nil }
        } else if let v = Double(t.replacingOccurrences(of: ",", with: ".")) {
            tong = v
        } else { return nil }
        let p = Int(tong.rounded())
        return (1...1440).contains(p) ? p : nil
    }

    /// Giây đã trôi của đồng hồ lúc `bayGio`: máy chủ báo `elapsedSec` tính đến `serverNow`;
    /// đang chạy thì cộng thêm thời gian từ lúc TẢI (đồng hồ máy) — không tin đồng hồ máy so với máy chủ.
    static func giayTroi(_ d: CTWDongHoChay, taiLuc: Date, bayGio: Date) -> Int {
        let goc = max(d.elapsedSec ?? 0, 0)
        guard d.dangChay else { return goc }
        return goc + max(Int(bayGio.timeIntervalSince(taiLuc)), 0)
    }

    /// Đồng hồ dừng lúc này sẽ ghi bao nhiêu phút (máy chủ làm tròn `round(sec/60)`, trần 1440).
    static func phutSeGhi(giay: Int) -> Int { min(Int((Double(max(giay, 0)) / 60).rounded()), 1440) }
}
