import Foundation
import SwiftUI

/// Một mục đọc được của khoá: Mở đầu, một bài trong buổi, hoặc một mục tra cứu.
enum MucDocSH: Hashable, Identifiable {
    case gioiThieu
    case bai(buoi: Int, id: String)
    case phu(id: String)

    var id: String {
        switch self {
        case .gioiThieu: return "bat-dau"
        case .bai(_, let id): return id
        case .phu(let id): return id
        }
    }
}

/// Trạng thái MỘT khoá kiểu sách: mục lục, nội dung đã nạp, tiến độ.
///
/// Tiến độ dùng CHUNG với web: cùng `stage` (`dekiru1`…) trên `/api/v1/ielts/tien-do`
/// (bài đã học = `kind: bai`, điểm bài tập = `kind: baitap`) ⇒ học trên web hay app
/// đều thấy một tiến độ. Chưa đăng nhập ⇒ chỉ lưu trên máy.
@MainActor
final class SachHocVM: ObservableObject {
    let khoaId: String
    @Published private(set) var khoa: KhoaSH?
    @Published private(set) var dangTai = false
    @Published private(set) var loi: String?
    /// Mục lục đang là bản lưu trên máy (không tới được máy chủ).
    @Published private(set) var banLuu = false
    @Published private(set) var noiDung: [Int: [BaiSH]] = [:]
    @Published private(set) var noiDungPhu: [String: BaiSH] = [:]
    /// Buổi đã có trên máy đúng phiên bản (học ngoại tuyến được).
    @Published private(set) var daLuu: Set<Int> = []
    @Published private(set) var daXong: Set<String> = []
    @Published private(set) var diem: [String: Int] = [:]
    @Published private(set) var dangTaiHet: (xong: Int, tong: Int)?
    @Published private(set) var chia: BangChiaSH?
    @Published private(set) var chuHan: ChuHanSH?

    private let kho = KhoSachHoc.chung

    init(khoa: String) {
        khoaId = khoa
        docTienDoMay()
    }

    // MARK: Mục lục

    func nap() async {
        if khoa == nil, let cu = await kho.mucLucDaLuu(khoaId) { datKhoa(cu, banLuu: true) }
        dangTai = true
        defer { dangTai = false }
        do {
            let kq = try await kho.mucLuc(khoaId)
            datKhoa(kq.khoa, banLuu: kq.banLuu)
            loi = nil
        } catch {
            if khoa == nil { loi = error.localizedDescription }
        }
        await kiemDaLuu()
        await dongBoTienDo()
    }

    private func datKhoa(_ k: KhoaSH, banLuu: Bool) {
        // Phiên bản đổi ⇒ nội dung đã nạp trong bộ nhớ có thể cũ.
        if khoa?.phienBan != k.phienBan { noiDung = [:]; noiDungPhu = [:] }
        khoa = k
        self.banLuu = banLuu
        GiongSachHoc.chung.giongMacDinh = k.giong
    }

    private func kiemDaLuu() async {
        guard let khoa else { return }
        var s = Set<Int>()
        for b in khoa.buoi {
            if let t = b.tep, let h = b.hash, await kho.daCo(khoaId, t, hash: h) { s.insert(b.n) }
        }
        daLuu = s
    }

    // MARK: Nội dung

    func buoi(_ n: Int) -> BuoiSH? { khoa?.buoi.first { $0.n == n } }

    /// Nội dung đủ của buổi n (nạp một lần, giữ trong bộ nhớ).
    func noiDungBuoi(_ n: Int) async throws -> [BaiSH] {
        if let c = noiDung[n] { return c }
        guard let b = buoi(n) else { return [] }
        let kq = try await kho.buoi(khoaId, b)
        noiDung[n] = kq.bai
        if b.tep != nil { daLuu.insert(n) }
        return kq.bai
    }

    func noiDungMuc(_ m: MucDocSH) async throws -> BaiSH? {
        switch m {
        case .gioiThieu: return khoa?.gioiThieu
        case .bai(let n, let id): return try await noiDungBuoi(n).first { $0.id == id }
        case .phu(let id):
            if let c = noiDungPhu[id] { return c }
            guard let p = khoa?.phu.first(where: { $0.id == id }) else { return nil }
            let kq = try await kho.phu(khoaId, p)
            noiDungPhu[id] = kq.bai
            return kq.bai
        }
    }

    func napChia() async {
        guard chia == nil, let t = khoa?.chia else { return }
        chia = try? await kho.giai(khoaId, t, BangChiaSH.self)
    }

    func napChuHan() async {
        guard chuHan == nil, let t = khoa?.chuHan else { return }
        chuHan = try? await kho.giai(khoaId, t, ChuHanSH.self)
    }

    // MARK: Thứ tự đọc (nút "Bài tiếp")

    /// Như web: Mở đầu → mọi bài đã soạn theo thứ tự buổi → mục tra cứu ở CUỐI.
    var thuTuDoc: [MucDocSH] {
        guard let khoa else { return [] }
        return [.gioiThieu]
            + khoa.buoi.flatMap { b in b.bai.filter(\.ready).map { MucDocSH.bai(buoi: b.n, id: $0.id) } }
            + khoa.phu.map { .phu(id: $0.id) }
    }

    func ke(_ m: MucDocSH, buoc: Int) -> MucDocSH? {
        let ds = thuTuDoc
        guard let i = ds.firstIndex(of: m) else { return nil }
        let j = i + buoc
        return ds.indices.contains(j) ? ds[j] : nil
    }

    func meta(_ m: MucDocSH) -> (title: String, kind: String, nhan: String)? {
        guard let khoa else { return nil }
        switch m {
        case .gioiThieu: return (khoa.gioiThieu.title, khoa.gioiThieu.kind, "Mở đầu")
        case .bai(let n, let id):
            guard let b = buoi(n), let l = b.bai.first(where: { $0.id == id }) else { return nil }
            return (l.title, l.kind, b.ten)
        case .phu(let id):
            guard let p = khoa.phu.first(where: { $0.id == id }) else { return nil }
            return (p.title, p.kind, "Tra cứu")
        }
    }

    /// Bài nên học tiếp: bài đã soạn đầu tiên chưa đánh dấu xong.
    var baiTiepTheo: MucDocSH? {
        thuTuDoc.first { m in
            if case .phu = m { return false }
            return !daXong.contains(m.id)
        }
    }

    // MARK: Học ngoại tuyến

    /// Tải mọi buổi + mục tra cứu về máy (đọc được khi không có mạng).
    func taiHet() async {
        guard let khoa, dangTaiHet == nil else { return }
        let ds = khoa.buoi.filter { $0.tep != nil }
        dangTaiHet = (0, ds.count + khoa.phu.count)
        var xong = 0
        for b in ds {
            _ = try? await kho.buoi(khoaId, b)
            daLuu.insert(b.n)
            xong += 1; dangTaiHet = (xong, dangTaiHet?.tong ?? 0)
        }
        for p in khoa.phu {
            _ = try? await kho.phu(khoaId, p)
            xong += 1; dangTaiHet = (xong, dangTaiHet?.tong ?? 0)
        }
        if let t = khoa.chia { _ = try? await kho.tep(khoaId, t.tep, hash: t.hash) }
        if let t = khoa.chuHan { _ = try? await kho.tep(khoaId, t.tep, hash: t.hash) }
        dangTaiHet = nil
        await kiemDaLuu()
    }

    func dungLuongDaLuu() async -> Int { await kho.dungLuong(khoaId) }

    // MARK: Tiến độ

    private var khoaMay: String { "sachhoc.\(khoaId).tiendo" }
    private struct TienDoMay: Codable { var done: [String]; var scores: [String: Int] }

    private func docTienDoMay() {
        guard let d = UserDefaults.standard.data(forKey: khoaMay),
              let t = try? JSONDecoder().decode(TienDoMay.self, from: d) else { return }
        daXong = Set(t.done); diem = t.scores
    }

    private func ghiTienDoMay() {
        let t = TienDoMay(done: Array(daXong).sorted(), scores: diem)
        if let d = try? JSONEncoder().encode(t) { UserDefaults.standard.set(d, forKey: khoaMay) }
    }

    private var daDangNhap: Bool { StorageManager.shared.getAuthToken() != nil }

    func dongBoTienDo() async {
        guard daDangNhap, let stage = khoa?.stage else { return }
        struct Dong: Decodable { let kind: String; let muc: String; var xong: Bool?; var diem: Double? }
        struct Kq: Decodable { let items: [Dong] }
        guard let kq: Kq = try? await APIClient.shared.request(.ieltsTienDo(chang: stage)) else { return }
        var xong = daXong
        var d = diem
        for r in kq.items {
            if r.kind == "bai", r.xong == true { xong.insert(r.muc) }
            if r.kind == "baitap", let v = r.diem { d[r.muc] = Int(v.rounded()) }
        }
        daXong = xong; diem = d
        ghiTienDoMay()
    }

    func danhDau(_ id: String, xong: Bool) {
        if xong { daXong.insert(id) } else { daXong.remove(id) }
        ghiTienDoMay()
        guard daDangNhap, let stage = khoa?.stage else { return }
        Task {
            if xong {
                _ = try? await APIClient.shared.send(.ieltsGhiTienDo(items: [["stage": stage, "kind": "bai", "muc": id, "xong": true]]))
            } else {
                _ = try? await APIClient.shared.send(.ieltsXoaTienDo(chang: stage, phan: "bai", muc: id))
            }
        }
    }

    /// Điểm (%) khi làm xong một bài tập — như `tutor.report` của web.
    func baoDiem(_ quizId: String, _ pct: Int) {
        diem[quizId] = pct
        ghiTienDoMay()
        guard daDangNhap, let stage = khoa?.stage else { return }
        Task { _ = try? await APIClient.shared.send(.ieltsGhiTienDo(items: [["stage": stage, "kind": "baitap", "muc": quizId, "diem": pct]])) }
    }

    /// Tỉ lệ bài đã học của một buổi.
    func tienDo(_ b: BuoiSH) -> (xong: Int, tong: Int) {
        let ds = b.bai.filter(\.ready)
        return (ds.filter { daXong.contains($0.id) }.count, ds.count)
    }

    var tienDoKhoa: (xong: Int, tong: Int) {
        guard let khoa else { return (0, 0) }
        let ds = khoa.buoi.flatMap { $0.bai.filter(\.ready) }
        return (ds.filter { daXong.contains($0.id) }.count, ds.count)
    }
}
