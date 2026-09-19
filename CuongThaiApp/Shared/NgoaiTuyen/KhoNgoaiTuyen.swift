import Foundation
import CryptoKit

// ════════════════════════════════════════════════════════════════
// HỌC NGOẠI TUYẾN
//
// Lưu JSON THÔ của các lời gọi GET xuống đĩa, rồi trả lại chúng khi mất
// mạng. Đặt ở tầng `perform` — chỗ DUY NHẤT mọi lời gọi đi qua — nên không
// màn nào phải sửa, và không có màn nào "quên" hỗ trợ ngoại tuyến.
//
// Hai loại mục, khác nhau ở chỗ bị dọn hay không:
//   · ĐỆM (tự động): mọi thứ bạn đã xem. Có trần dung lượng, đầy thì dọn
//     mục cũ nhất trước.
//   · GHIM (bạn bấm "Tải về"): KHÔNG BAO GIỜ bị dọn tự động. Người dùng
//     tải một môn trước chuyến đi mà app tự xoá nó để nhường chỗ cho bảng
//     tin vừa lướt thì thà đừng có tính năng này.
// ════════════════════════════════════════════════════════════════

actor KhoNgoaiTuyen {
    static let chung = KhoNgoaiTuyen()

    /// Trần cho phần ĐỆM. Phần ghim không tính vào đây.
    ///
    /// 200 MB: đo thật 19/09/2026 một khoá 76 bài đầy đủ nội dung chỉ
    /// **2,1 MB** và KHÔNG có media — nội dung là chữ trong Postgres. Nên
    /// trần này đủ cho hàng chục môn, mà vẫn không âm thầm ngốn đĩa.
    private let tranDem = 200 * 1024 * 1024

    private var thuMuc: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ngoai-tuyen", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// ⚠️ Khoá phải gồm CẢ query. `/courses?page=1` và `?page=2` là hai thứ
    /// khác nhau; gộp chúng lại thì trang 2 đè lên trang 1 và người dùng mở
    /// ngoại tuyến thấy danh sách nhảy cóc mà không hiểu vì sao.
    private func ten(_ khoa: String) -> String {
        let h = SHA256.hash(data: Data(khoa.utf8))
        return h.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func duong(_ khoa: String) -> URL { thuMuc.appendingPathComponent(ten(khoa)) }
    private func duongGhim(_ khoa: String) -> URL {
        thuMuc.appendingPathComponent(ten(khoa) + ".ghim")
    }

    // MARK: Đọc / ghi

    func doc(_ khoa: String) -> Data? {
        try? Data(contentsOf: duong(khoa))
    }

    func ghi(_ d: Data, khoa: String, ghim: Bool = false, mon: String? = nil) {
        try? d.write(to: duong(khoa), options: .atomic)
        if ghim {
            // Tệp ghim đi kèm ghi tên môn, để "xoá môn này" biết phải xoá gì.
            try? Data((mon ?? "").utf8).write(to: duongGhim(khoa), options: .atomic)
        }
        donNeuDay()
    }

    func daGhim(_ khoa: String) -> Bool {
        FileManager.default.fileExists(atPath: duongGhim(khoa).path)
    }

    // MARK: Dọn dẹp

    /// Dọn mục ĐỆM cũ nhất cho tới khi xuống dưới trần. Không đụng mục ghim.
    private func donNeuDay() {
        let fm = FileManager.default
        guard let ds = try? fm.contentsOfDirectory(at: thuMuc,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        let dem = ds.filter { $0.pathExtension != "ghim" }
            .filter { !fm.fileExists(atPath: $0.path + ".ghim") }
        var tong = dem.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        guard tong > tranDem else { return }
        let theoTuoi = dem.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a < b
        }
        for u in theoTuoi {
            guard tong > tranDem else { break }
            tong -= (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try? fm.removeItem(at: u)
        }
    }

    /// Dung lượng đang dùng: (đệm, đã ghim) tính bằng byte.
    func dungLuong() -> (dem: Int, ghim: Int) {
        let fm = FileManager.default
        guard let ds = try? fm.contentsOfDirectory(at: thuMuc,
                includingPropertiesForKeys: [.fileSizeKey]) else { return (0, 0) }
        var dem = 0, ghim = 0
        for u in ds where u.pathExtension != "ghim" {
            let co = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if fm.fileExists(atPath: u.path + ".ghim") { ghim += co } else { dem += co }
        }
        return (dem, ghim)
    }

    /// Danh sách môn đã tải về (tên môn → số mục).
    func monDaTai() -> [String: Int] {
        let fm = FileManager.default
        guard let ds = try? fm.contentsOfDirectory(at: thuMuc, includingPropertiesForKeys: nil) else { return [:] }
        var kq: [String: Int] = [:]
        for u in ds where u.pathExtension == "ghim" {
            let ten = (try? Data(contentsOf: u)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            kq[ten.isEmpty ? "Khác" : ten, default: 0] += 1
        }
        return kq
    }

    func xoaMon(_ mon: String) {
        let fm = FileManager.default
        guard let ds = try? fm.contentsOfDirectory(at: thuMuc, includingPropertiesForKeys: nil) else { return }
        for u in ds where u.pathExtension == "ghim" {
            let ten = (try? Data(contentsOf: u)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard ten == mon else { continue }
            try? fm.removeItem(at: u)
            try? fm.removeItem(at: u.deletingPathExtension())
        }
    }

    func xoaHet() {
        try? FileManager.default.removeItem(at: thuMuc)
    }
}

// MARK: - Trạng thái mạng

/// Có đang dùng được mạng không — để màn hình nói thật với người dùng.
///
/// ⚠️ KHÔNG chặn lời gọi khi cờ này báo mất mạng. `NWPathMonitor` sai khá
/// thường xuyên (Wi-Fi có sóng nhưng cổng chặn, captive portal, VPN vừa
/// bật). Cứ gọi thật; hỏng thì rơi về bản đã lưu. Cờ này chỉ để HIỆN CHỮ.
@MainActor
final class TrangThaiMang: ObservableObject {
    static let chung = TrangThaiMang()
    @Published var coMang = true
    @Published var dangDungBanLuu = false

    /// ⚠️ Gọi từ MỌI lời gọi GET, tức là đường NÓNG nhất của app.
    ///
    /// Hai chốt chặn, cả hai đều cần:
    ///  · `Task { @MainActor }` chứ không `await MainActor.run` — bản kia bắt
    ///    lời gọi mạng ĐỢI main thread rảnh mới trả kết quả về.
    ///  · chỉ gán khi GIÁ TRỊ ĐỔI: gán vào `@Published` luôn bắn
    ///    `objectWillChange` kể cả khi gán đúng giá trị cũ, nên mỗi lần lướt
    ///    bảng tin là hàng chục lần vẽ lại cả cây màn hình mà không đổi gì.
    nonisolated static func bao(coMang: Bool, dungBanLuu: Bool) {
        Task { @MainActor in
            let c = TrangThaiMang.chung
            if c.coMang != coMang { c.coMang = coMang }
            if c.dangDungBanLuu != dungBanLuu { c.dangDungBanLuu = dungBanLuu }
        }
    }
}
