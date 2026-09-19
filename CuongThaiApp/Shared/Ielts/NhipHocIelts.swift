import Foundation

// ════════════════════════════════════════════════════════════════
// CHUỖI NGÀY · XP · KẾ HOẠCH HÔM NAY
//
// Tính HOÀN TOÀN từ dữ liệu tiến độ đã có (`updatedAt` của từng mục đã
// xong). Không thêm bảng nào ở backend, không cần deploy.
//
// ⚠️ Mọi phép tính ngày ở đây dùng múi giờ VIỆT NAM, không dùng giờ máy.
// Máy đang ở múi khác mà tính "hôm nay" theo giờ địa phương thì chuỗi ngày
// đứt oan lúc nửa đêm — và người dùng mất chuỗi 30 ngày vì một lỗi họ
// không thể nào đoán ra.
// ════════════════════════════════════════════════════════════════

struct NhipHocIelts {
    var chuoiNgay = 0
    var xpHomNay = 0
    var mucTieuNgay = 30
    var tongXp = 0

    var daDatMucTieu: Bool { xpHomNay >= mucTieuNgay }
    var tiLeNgay: Double { mucTieuNgay > 0 ? min(Double(xpHomNay) / Double(mucTieuNgay), 1) : 0 }

    /// Mỗi mục xong = 10 XP. Con số tròn để người dùng nhẩm được: 3 mục là
    /// xong mục tiêu ngày. Thang điểm phức tạp hơn chỉ làm mất cảm giác
    /// "còn một bước nữa thôi".
    static let xpMoiMuc = 10

    static func tinh(mocXong: [Date], mucTieuNgay: Int = 30) -> NhipHocIelts {
        var n = NhipHocIelts()
        n.mucTieuNgay = mucTieuNgay
        n.tongXp = mocXong.count * xpMoiMuc

        var lich = Calendar(identifier: .gregorian)
        lich.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current

        let homNay = lich.startOfDay(for: Date())
        n.xpHomNay = mocXong.filter { lich.startOfDay(for: $0) == homNay }.count * xpMoiMuc

        // Chuỗi ngày: đếm lùi từ hôm nay. Nếu hôm nay chưa học thì vẫn tính
        // từ hôm qua — chuỗi chỉ ĐỨT khi bỏ trọn một ngày, không phải ngay
        // lúc 0h sáng trước khi kịp học.
        let ngayCoHoc = Set(mocXong.map { lich.startOfDay(for: $0) })
        guard !ngayCoHoc.isEmpty else { return n }
        var moc = ngayCoHoc.contains(homNay)
            ? homNay
            : lich.date(byAdding: .day, value: -1, to: homNay)!
        guard ngayCoHoc.contains(moc) else { return n }
        var dem = 0
        while ngayCoHoc.contains(moc) {
            dem += 1
            guard let truoc = lich.date(byAdding: .day, value: -1, to: moc) else { break }
            moc = truoc
        }
        n.chuoiNgay = dem
        return n
    }
}

// MARK: - Con đường học

/// Một chặng nhỏ trên con đường — tương đương MỘT buổi 3–5 phút.
struct NutDuongIelts: Identifiable, Hashable {
    let id: String
    let kind: String
    let ten: String
    let bieuTuong: String
    var xong: Bool
    var moKhoa: Bool
    /// Nút cuối của một vòng — hiện to hơn, như "rương" của Duolingo.
    var laMoc: Bool
}

enum DungConDuong {
    /// Nhịp lặp: học → từ vựng → bài tập → một kỹ năng. Đây là thứ biến một
    /// đống 8 ô đếm số thành "bây giờ làm cái này".
    ///
    /// ⚠️ Xen kẽ chứ KHÔNG gom theo loại. Bắt học hết 8 bài lý thuyết rồi
    /// mới được chạm vào bài đọc đầu tiên là cách chắc chắn nhất để người
    /// lười bỏ cuộc ở bài thứ ba.
    private static let nhip = ["units", "vocab", "exercises",
                               "readings", "units", "vocab", "exercises",
                               "listenings", "writings", "speakings"]

    private static let ten: [String: (String, String)] = [
        "units":      ("Bài học", "book.fill"),
        "vocab":      ("Từ vựng", "textformat.abc"),
        "exercises":  ("Luyện tập", "pencil.and.list.clipboard"),
        "readings":   ("Đọc", "doc.text.fill"),
        "listenings": ("Nghe", "headphones"),
        "writings":   ("Viết", "square.and.pencil"),
        "speakings":  ("Nói", "mic.fill"),
    ]

    /// Dựng con đường từ SỐ MỤC CÓ THẬT của chặng. Không bịa ra nút cho loại
    /// chưa có nội dung — một nút mở ra màn trống là thứ phá vỡ lòng tin
    /// nhanh hơn cả việc không có nút.
    static func dung(soMuc: [String: Int], daXongSo: [String: Int]) -> [NutDuongIelts] {
        var conLai = soMuc
        var dung: [NutDuongIelts] = []
        var i = 0
        var demTheoLoai: [String: Int] = [:]

        while conLai.values.contains(where: { $0 > 0 }) && dung.count < 60 {
            let k = nhip[i % nhip.count]
            i += 1
            guard (conLai[k] ?? 0) > 0 else { continue }

            // Bài tập đi theo CỤM 5 câu: một nút = một buổi ngắn, không phải
            // 200 nút lặt vặt trải dài vô tận.
            let buoc = (k == "exercises") ? min(5, conLai[k] ?? 0) : 1
            conLai[k] = (conLai[k] ?? 0) - buoc
            let n = (demTheoLoai[k] ?? 0) + 1
            demTheoLoai[k] = n

            let (t, bt) = ten[k] ?? (k, "circle")
            let xong = n <= (daXongSo[k] ?? 0)
            dung.append(NutDuongIelts(
                id: "\(k)-\(n)", kind: k,
                ten: buoc > 1 ? "\(t) \(n)" : "\(t) \(n)",
                bieuTuong: bt, xong: xong, moKhoa: false,
                laMoc: dung.count % 5 == 4))
        }

        // Mở khoá: mọi nút đã xong, cộng thêm ĐÚNG MỘT nút kế tiếp.
        var daMo = false
        for idx in dung.indices {
            if dung[idx].xong { dung[idx].moKhoa = true }
            else if !daMo { dung[idx].moKhoa = true; daMo = true }
        }
        return dung
    }

    /// Ba việc cho hôm nay — lấy từ chính con đường, không phải lời khuyên chung.
    static func viecHomNay(_ duong: [NutDuongIelts]) -> [NutDuongIelts] {
        Array(duong.filter { !$0.xong }.prefix(3))
    }
}
