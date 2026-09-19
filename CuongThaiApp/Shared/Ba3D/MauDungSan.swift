import Foundation

/// Khối mẫu dựng sẵn — mỗi mẫu là một CỤM khối đã ghép đúng tỉ lệ.
///
/// Vì sao cần: bắt đầu từ một khung trống với sáu hình cơ bản là chỗ người ta
/// bỏ cuộc. Dựng một người que từ con số 0 mất mười lăm phút mò tỉ lệ; kéo ra
/// một cái rồi sửa thì mất một phút. Thư viện mẫu không phải trang trí — nó
/// là thứ quyết định người dùng có dựng được cái THỨ HAI hay không.
///
/// Mọi mẫu đều dùng chung một NHÓM để cả cụm kéo đi cùng nhau, và tên nhóm
/// mang mã ngẫu nhiên để kéo hai người que ra thì chúng không dính vào nhau.
enum MauDungSan {
    struct Mau: Identifiable {
        let id: String
        let ten: String
        let bieuTuong: String
        let moTa: String
        let nhom: String
        let dung: (String) -> [KhoiBa]
    }

    static let tatCa: [Mau] = [nguoiQue, thung, tuong, bacThang, cay, ban, xeDon]

    /// Tên nhóm mới, tránh hai cụm cùng loại dính vào nhau.
    static func maNhom(_ goc: String) -> String {
        "\(goc)-\(UUID().uuidString.prefix(4))"
    }

    // ─── Người que ────────────────────────────────────────────────

    /// Nhân vật game cơ bản: đầu, thân, hai tay, hai chân.
    ///
    /// Tỉ lệ theo quy ước dựng nhân vật: cao tổng ~7 lần đầu. Không lấy tỉ lệ
    /// người thật (7,5-8 đầu) vì nhân vật game thấp hơn một chút nhìn thân
    /// thiện hơn và đọc được hình ở cỡ nhỏ.
    static let nguoiQue = Mau(
        id: "nguoi", ten: "Người que", bieuTuong: "figure.stand",
        moTa: "Đầu, thân, 2 tay, 2 chân — sửa tỉ lệ rồi tô màu",
        nhom: "nguoi",
        dung: { n in
            let da = "#F2C9A0", ao = "#7A45E8", quan = "#2E6FD9"
            return [
                KhoiBa(loai: .cau, ten: "Đầu", y: 2.6, coX: 0.62, coY: 0.68, coZ: 0.6, mau: da, nham: 0.6, nhom: n),
                KhoiBa(loai: .hop, ten: "Thân", y: 1.85, coX: 0.72, coY: 0.95, coZ: 0.42, mau: ao, nham: 0.7, nhom: n),
                KhoiBa(loai: .tru, ten: "Tay trái", x: -0.52, y: 1.9, xoayZ: 8, coX: 0.2, coY: 0.95, coZ: 0.2, mau: ao, nham: 0.7, nhom: n),
                KhoiBa(loai: .tru, ten: "Tay phải", x: 0.52, y: 1.9, xoayZ: -8, coX: 0.2, coY: 0.95, coZ: 0.2, mau: ao, nham: 0.7, nhom: n),
                KhoiBa(loai: .tru, ten: "Chân trái", x: -0.2, y: 0.85, coX: 0.24, coY: 1.1, coZ: 0.24, mau: quan, nham: 0.7, nhom: n),
                KhoiBa(loai: .tru, ten: "Chân phải", x: 0.2, y: 0.85, coX: 0.24, coY: 1.1, coZ: 0.24, mau: quan, nham: 0.7, nhom: n),
            ]
        })

    // ─── Đồ vật cho map ───────────────────────────────────────────

    static let thung = Mau(
        id: "thung", ten: "Thùng gỗ", bieuTuong: "shippingbox",
        moTa: "Ô vuông 1×1 — xếp làm chướng ngại vật", nhom: "thung",
        dung: { n in [
            KhoiBa(loai: .hop, ten: "Thùng", y: 0.5, mau: "#8B5A2B", nham: 0.85, nhom: n),
            KhoiBa(loai: .hop, ten: "Nẹp", y: 0.5, coX: 1.04, coY: 0.12, coZ: 1.04, mau: "#5A3A1C", nham: 0.8, nhom: n),
        ] })

    static let tuong = Mau(
        id: "tuong", ten: "Tường", bieuTuong: "rectangle.split.3x1",
        moTa: "Dài 4, cao 2 — ghép thành phòng", nhom: "tuong",
        dung: { n in [
            KhoiBa(loai: .hop, ten: "Tường", y: 1, coX: 4, coY: 2, coZ: 0.22, mau: "#9999A6", nham: 0.9, nhom: n),
            KhoiBa(loai: .hop, ten: "Chân tường", y: 0.12, coX: 4.1, coY: 0.24, coZ: 0.3, mau: "#56565F", nham: 0.9, nhom: n),
        ] })

    /// Bậc thang: năm bậc, mỗi bậc lùi đúng một bề dày.
    ///
    /// Dựng bằng vòng lặp chứ không gõ tay năm khối — gõ tay thì sửa độ cao
    /// bậc phải sửa năm chỗ, và chỉ cần quên một chỗ là thang gãy.
    static let bacThang = Mau(
        id: "thang", ten: "Bậc thang", bieuTuong: "stairs",
        moTa: "5 bậc đều nhau", nhom: "thang",
        dung: { n in
            let soBac = 5, caoBac = 0.3, sauBac = 0.45
            return (0..<soBac).map { i in
                KhoiBa(loai: .hop, ten: "Bậc \(i + 1)",
                       y: caoBac / 2 + Double(i) * caoBac,
                       z: -Double(i) * sauBac,
                       coX: 2, coY: caoBac, coZ: sauBac,
                       mau: "#81818C", nham: 0.9, nhom: n)
            }
        })

    static let cay = Mau(
        id: "cay", ten: "Cây", bieuTuong: "tree",
        moTa: "Thân trụ + ba tán cầu", nhom: "cay",
        dung: { n in [
            KhoiBa(loai: .tru, ten: "Thân", y: 0.9, coX: 0.24, coY: 1.8, coZ: 0.24, mau: "#6B4423", nham: 0.95, nhom: n),
            KhoiBa(loai: .cau, ten: "Tán dưới", y: 1.95, coX: 1.5, coY: 1.1, coZ: 1.5, mau: "#1A8F35", nham: 0.85, nhom: n),
            KhoiBa(loai: .cau, ten: "Tán giữa", y: 2.45, coX: 1.15, coY: 0.95, coZ: 1.15, mau: "#33C759", nham: 0.85, nhom: n),
            KhoiBa(loai: .cau, ten: "Tán trên", y: 2.9, coX: 0.8, coY: 0.75, coZ: 0.8, mau: "#1A8F35", nham: 0.85, nhom: n),
        ] })

    static let ban = Mau(
        id: "ban", ten: "Bàn", bieuTuong: "table.furniture",
        moTa: "Mặt bàn + 4 chân", nhom: "ban",
        dung: { n in
            var ds = [KhoiBa(loai: .hop, ten: "Mặt bàn", y: 0.75, coX: 2, coY: 0.1, coZ: 1.1,
                             mau: "#8B5A2B", nham: 0.6, nhom: n)]
            for (i, p) in [(-0.85, -0.45), (0.85, -0.45), (-0.85, 0.45), (0.85, 0.45)].enumerated() {
                ds.append(KhoiBa(loai: .hop, ten: "Chân \(i + 1)", x: p.0, y: 0.35, z: p.1,
                                 coX: 0.1, coY: 0.7, coZ: 0.1, mau: "#6B4423", nham: 0.7, nhom: n))
            }
            return ds
        })

    static let xeDon = Mau(
        id: "xe", ten: "Xe đơn giản", bieuTuong: "car",
        moTa: "Thân + mui + 4 bánh", nhom: "xe",
        dung: { n in
            var ds = [
                KhoiBa(loai: .hop, ten: "Thân xe", y: 0.55, coX: 2.4, coY: 0.5, coZ: 1.1,
                       mau: "#D32F2F", kimLoai: 0.5, nham: 0.3, nhom: n),
                KhoiBa(loai: .hop, ten: "Mui", y: 0.98, z: -0.05, coX: 1.25, coY: 0.42, coZ: 0.95,
                       mau: "#B02525", kimLoai: 0.5, nham: 0.3, nhom: n),
            ]
            for (i, p) in [(-0.8, -0.58), (0.8, -0.58), (-0.8, 0.58), (0.8, 0.58)].enumerated() {
                ds.append(KhoiBa(loai: .tru, ten: "Bánh \(i + 1)", x: p.0, y: 0.3, z: p.1,
                                 xoayX: 90, coX: 0.56, coY: 0.22, coZ: 0.56,
                                 mau: "#14141C", nham: 0.95, nhom: n))
            }
            return ds
        })
}
