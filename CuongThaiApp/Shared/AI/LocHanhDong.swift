import Foundation

// ════════════════════════════════════════════════════════════════
// LỌC DẤU LỆNH RA KHỎI CÂU TRẢ LỜI
//
// Khi người dùng bảo "đánh dấu xong bài LAB211", model kết câu bằng một dấu
// lệnh máy đọc được:
//
//     <<VIEC:XONG|nộp bài LAB211>>
//     <<VIEC:THEM|ôn 30 từ tiếng Nhật>>
//
// Bộ lọc này rút dấu đó ra và trả về phần chữ SẠCH. Người dùng không bao giờ
// thấy nó, và máy đọc không bao giờ đọc nó lên.
//
// ⚠️ PHẢI CÓ TRẠNG THÁI. Chữ về theo từng mẩu SSE, và dấu lệnh có thể bị cắt
// đôi giữa hai mẩu ("…xong<<VIEC" + ":XONG|abc>>"). Lọc từng mẩu rời rạc thì
// một nửa dấu lệnh lọt ra màn hình rồi bị đọc lên thành tiếng.
//
// ⚠️ VÀ NÓ CHỈ ĐỀ NGHỊ. Không có gì được thực hiện cho tới khi người dùng bấm
// xác nhận — nghe nhầm một câu mà tự xoá việc thì tệ hơn hẳn tự bấm.
// ════════════════════════════════════════════════════════════════

struct HanhDongDeNghi: Identifiable, Equatable {
    enum Loai: String { case xong = "XONG", them = "THEM" }
    let id = UUID()
    let loai: Loai
    let noiDung: String

    var moTa: String {
        switch loai {
        case .xong: return String(format: T("Đánh dấu xong: %@"), noiDung)
        case .them: return String(format: T("Thêm việc: %@"), noiDung)
        }
    }
}

/// Bộ lọc chảy dần. Nạp từng mẩu, nhận về phần chữ đã sạch.
final class LocHanhDong {
    private var dem = ""
    private(set) var hanhDong: [HanhDongDeNghi] = []

    /// Nạp một mẩu, trả về phần chữ CHẮC CHẮN an toàn để hiện.
    func nap(_ mau: String) -> String {
        dem += mau
        var ra = ""
        while let mo = dem.range(of: "<<VIEC:") {
            ra += String(dem[dem.startIndex..<mo.lowerBound])
            guard let dong = dem.range(of: ">>", range: mo.upperBound..<dem.endIndex) else {
                // Mới thấy nửa đầu — GIỮ LẠI chờ mẩu sau. Đây là toàn bộ lý do
                // bộ lọc phải có trạng thái.
                dem = String(dem[mo.lowerBound...])
                return ra
            }
            let than = String(dem[mo.upperBound..<dong.lowerBound])
            ghiNhan(than)
            dem = String(dem[dong.upperBound...])
        }
        // Giữ lại phần đuôi có thể là đầu một dấu lệnh đang tới.
        let giu = duoiCoTheLaDauLenh(dem)
        ra += String(dem.dropLast(giu))
        dem = String(dem.suffix(giu))
        return ra
    }

    /// Gọi khi luồng đã đóng: nhả nốt phần còn giữ.
    func xong() -> String {
        let con = dem
        dem = ""
        // Còn sót nửa dấu lệnh nghĩa là model bị cắt giữa chừng — bỏ nó đi chứ
        // đừng hiện "<<VIEC:XO" ra màn hình.
        if con.hasPrefix("<<VIEC:") || con.hasPrefix("<<") { return "" }
        return con
    }

    private func ghiNhan(_ than: String) {
        let phan = than.split(separator: "|", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard phan.count == 2,
              let loai = HanhDongDeNghi.Loai(rawValue: phan[0].uppercased()),
              !phan[1].isEmpty else { return }
        let hd = HanhDongDeNghi(loai: loai, noiDung: String(phan[1].prefix(200)))
        // Model đôi khi lặp lại đúng một đề nghị hai lần trong một câu trả lời.
        guard !hanhDong.contains(where: { $0.loai == hd.loai && $0.noiDung == hd.noiDung }) else { return }
        hanhDong.append(hd)
    }

    /// Bao nhiêu ký tự cuối có thể là phần đầu của "<<VIEC:" đang tới dở.
    private func duoiCoTheLaDauLenh(_ s: String) -> Int {
        let dau = "<<VIEC:"
        for n in stride(from: min(dau.count - 1, s.count), through: 1, by: -1) {
            if dau.hasPrefix(s.suffix(n)) { return n }
        }
        return 0
    }
}
