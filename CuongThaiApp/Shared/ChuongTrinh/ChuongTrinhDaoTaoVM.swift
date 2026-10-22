import Foundation

/// Nơi lấy dữ liệu — tách khỏi VM để kiểm thử (và màn thử DEBUG) cắm nguồn giả.
struct NguonChuongTrinh {
    /// Thân THÔ của `GET /courses/chuong-trinh`.
    var chuongTrinh: () async throws -> Data
    /// Thân THÔ của một trang `GET /courses?gon=1&size=100&page=N` (đường lùi).
    var trangDanhSach: (Int) async throws -> Data

    /// Đi qua `APIClient` ⇒ có sẵn token (tiến độ riêng), làm mới phiên khi 401, và bản lưu
    /// ngoại tuyến khi MẤT MẠNG (tầng `perform`). Luôn gọi mạng trước — không đệm riêng ở đây.
    static let mang = NguonChuongTrinh(
        chuongTrinh: {
            try await APIClient.shared.requestRaw(
                .tuyChinh(duong: "/api/v1/courses/chuong-trinh", phuongThuc: "GET", than: nil))
        },
        trangDanhSach: { trang in
            try await APIClient.shared.requestRaw(
                .tuyChinh(duong: "/api/v1/courses?gon=1&size=100&page=\(trang)", phuongThuc: "GET", than: nil))
        },
    )

    /// Bản DEBUG có thể cắm nguồn giả qua biến môi trường (`ThuChuongTrinhDebug.swift`) — để chụp màn
    /// khi endpoint chưa lên prod và máy mô phỏng không có phiên đăng nhập. Bản Release: luôn `.mang`.
    static var macDinh: NguonChuongTrinh {
        #if DEBUG
        if let thu = ThuChuongTrinh.nguonTuMoiTruong() { return thu }
        #endif
        return .mang
    }
}

@MainActor
final class ChuongTrinhDaoTaoVM: ObservableObject {
    @Published private(set) var duLieu: ChuongTrinhDaoTao?
    @Published private(set) var dangTai = false
    /// Chỉ đặt khi KHÔNG có gì để hiện (đã có dữ liệu cũ thì giữ dữ liệu cũ, không che bằng lỗi).
    @Published private(set) var loi: String?

    private let nguon: NguonChuongTrinh
    private var lanTaiXong: Date?

    init(nguon: NguonChuongTrinh = .macDinh) {
        self.nguon = nguon
    }

    /// Thẻ ở tab Học gọi mỗi lần hiện: chỉ tải lại khi dữ liệu đã cũ hơn 60 giây.
    func taiNeuCu() async {
        if let lanTaiXong, Date().timeIntervalSince(lanTaiXong) < 60, duLieu != nil { return }
        await tai()
    }

    /// Tải chương trình; HỎNG ⇒ lùi về danh sách khoá phẳng (endpoint chưa lên prod trả 404 rơi vào
    /// `/:slug` "Course not found"). Đường lùi chạy cho MỌI lỗi trừ huỷ — 404 (chưa deploy), 5xx, hay
    /// hình dạng lạ đều không được biến màn này thành màn lỗi khi danh sách khoá vẫn lấy được.
    func tai() async {
        guard !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            let d = try await nguon.chuongTrinh()
            ganDuLieu(try ChuongTrinhDaoTao.giai(d).locHienDuoc())
        } catch {
            if Self.laHuy(error) { return }
            do {
                ganDuLieu(try await taiDanhSach().locHienDuoc())
            } catch {
                if Self.laHuy(error) { return }
                if duLieu == nil { loi = error.localizedDescription }
            }
        }
    }

    private func ganDuLieu(_ d: ChuongTrinhDaoTao) {
        duLieu = d
        loi = nil
        lanTaiXong = Date()
    }

    /// Đọc đủ mọi trang (75 khoá ⇒ một trang). Trần 10 trang: máy chủ trả `totalPages` lạ cũng không lặp mãi.
    private func taiDanhSach() async throws -> ChuongTrinhDaoTao {
        let dau = try ChuongTrinhDaoTao.giaiTrangDanhSach(try await nguon.trangDanhSach(1))
        var mon = dau.mon
        if dau.soTrang > 1 {
            for trang in 2...min(dau.soTrang, 10) {
                guard let t = try? ChuongTrinhDaoTao.giaiTrangDanhSach(try await nguon.trangDanhSach(trang)) else { break }
                mon += t.mon
            }
        }
        guard !mon.isEmpty else { throw LoiChuongTrinh.khongCoDuLieu }
        return ChuongTrinhDaoTao.tuDanhSach(mon)
    }

    nonisolated static func laHuy(_ e: Error) -> Bool {
        if e is CancellationError { return true }
        if let u = e as? URLError, u.code == .cancelled { return true }
        if case APIError.networkError(let goc) = e { return laHuy(goc) }
        return false
    }

    #if DEBUG
    /// Màn thử: dựng sẵn dữ liệu, không gọi mạng.
    func ganThu(_ d: ChuongTrinhDaoTao) { ganDuLieu(d) }
    #endif
}
