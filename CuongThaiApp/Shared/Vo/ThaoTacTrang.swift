#if os(iOS)
import Foundation
import PencilKit
import SwiftData
import UIKit

// MARK: - Thao tác trên TRANG (sắp xếp · đổi tên · nhân bản · chèn · chuyển · xoá)
//
// MỘT chỗ duy nhất cho mọi thao tác đổi cây trang. Dải trang, màn "Các trang"
// và menu ⋯ của màn viết đều gọi vào đây — trước 28/09/2026 mỗi chỗ tự dồn
// `thuTu` theo cách riêng, và nhân bản ở menu thì mất nền PDF còn nhân bản ở
// chỗ khác thì không có. Viết hai bản là sớm muộn một bản thiếu một bước.
//
// ⚠️ Ba luật mọi hàm ở đây giữ:
//   1. `thuTu` luôn là 0…n-1 liền mạch sau mỗi thao tác (`danhSoLai`). Có lỗ
//      hay trùng thì thứ tự hiện ra tuỳ lúc và máy khác kéo về sai chỗ.
//   2. Đổi gì ở cây thì `danhDauCay(cuon)` — cờ này chặn lượt KÉO VỀ đè thứ
//      tự/tên vừa sửa bằng bản cũ trên máy chủ trước khi kịp đẩy lên.
//   3. Không bao giờ để cuốn vở rỗng (màn viết không có lối ra khi rỗng).

extension TrangVo {
    /// Tên hiển thị: tên người dùng đặt, không có thì "Trang N" (N đếm từ 1
    /// theo vị trí HIỆN TẠI — nên sắp xếp lại là số tự đổi theo, đúng như vở
    /// giấy đánh số ở góc trang).
    func tenHienThi(so: Int) -> String {
        if let t = tieuDe?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { return t }
        return T("Trang") + " \(so)"
    }

    var coTenRieng: Bool {
        !(tieuDe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    }
}

/// Bản chụp một trang vừa xoá, đủ để dựng lại khi người dùng bấm Hoàn tác.
///
/// ⚠️ Dựng lại bằng id MỚI, không dùng lại id cũ. Lệnh xoá đã vào hàng đợi
/// và rất có thể đã tới máy chủ (xoá mềm, vào thùng rác). Dùng lại `clientId`
/// cũ thì lượt đồng bộ upsert trúng đúng hàng đã xoá — hàng đó vẫn mang
/// `deletedAt`, xin đường đẩy nét trả `NOTE_NOT_FOUND`, và trang "hoàn tác"
/// sống trên máy mà không bao giờ lên được mây. Id mới = một trang mới hoàn
/// toàn sạch; bản cũ nằm yên trong thùng rác 30 ngày.
struct TrangDaXoa {
    let idCu: UUID
    let viTri: Int
    let tieuDe: String?
    let tenChuong: String?
    let loaiGiay: String
    let huongGiay: String
    let danhDau: Bool
    let chuNhanDang: String?
    let nhanDangLuc: Date?
    let nenPdfTen: String?
    let nenPdfTrang: Int
    let nenAnhTen: String?
    let nenKhoaR2: String?
    let nenLoaiR2: String?
    let ghiAmTen: String?
    let ghiAmDai: Double
    let mocNet: [Double]
    let coNet: Bool
}

@MainActor
enum ThaoTacTrang {

    // MARK: Nền tảng

    /// Đánh lại `thuTu` 0…n-1 theo đúng thứ tự mảng truyền vào.
    static func danhSoLai(_ ds: [TrangVo]) {
        for (i, t) in ds.enumerated() where t.thuTu != i { t.thuTu = i }
    }

    /// Cây của cuốn này vừa đổi (thứ tự, tên, giấy, trang ra/vào).
    static func danhDauCay(_ cuon: CuonVo?) {
        guard let cuon else { return }
        cuon.canDayCay = true
        cuon.suaLuc = Date()
    }

    private static func luu(_ kho: ModelContext) {
        do { try kho.save() } catch {
            NhatKy.vo.error("thao tác trang: lưu kho hỏng — \(error.localizedDescription)")
        }
    }

    // MARK: Sắp xếp

    /// Chuyển các trang ở `tu` tới vị trí `toi` — đúng ngữ nghĩa `onMove`
    /// của SwiftUI (`toi` là chỉ số TRƯỚC khi gỡ các trang ra).
    static func diChuyen(trongCuon cuon: CuonVo, tu: IndexSet, toi: Int, kho: ModelContext) {
        var ds = cuon.trangsTheoThuTu
        ds.move(fromOffsets: tu, toOffset: toi)
        danhSoLai(ds)
        danhDauCay(cuon)
        luu(kho)
    }

    /// Kéo–thả: đặt `trang` vào đúng chỗ `dich` đang đứng.
    ///
    /// Kéo XUỐNG thì trang nằm SAU `dich`, kéo LÊN thì nằm TRƯỚC — đúng cảm
    /// giác "đẩy trang kia sang một bên" của GoodNotes/Files.
    static func datVaoCho(_ trang: TrangVo, choCua dich: TrangVo, trongCuon cuon: CuonVo,
                          kho: ModelContext) {
        guard trang.id != dich.id else { return }
        var ds = cuon.trangsTheoThuTu
        guard let a = ds.firstIndex(where: { $0.id == trang.id }),
              let b = ds.firstIndex(where: { $0.id == dich.id }) else { return }
        ds.move(fromOffsets: IndexSet(integer: a), toOffset: b > a ? b + 1 : b)
        danhSoLai(ds)
        danhDauCay(cuon)
        luu(kho)
    }

    // MARK: Đổi tên

    static func doiTen(_ trang: TrangVo, thanh ten: String, kho: ModelContext) {
        let t = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        let moi: String? = t.isEmpty ? nil : String(t.prefix(300))
        guard moi != trang.tieuDe else { return }
        trang.tieuDe = moi
        trang.suaLuc = Date()
        danhDauCay(trang.cuon)
        luu(kho)
    }

    // MARK: Chèn · nhân bản

    /// Chèn một trang TRẮNG vào vị trí `viTri` (0 = đầu cuốn).
    @discardableResult
    static func chenTrangTrang(vao cuon: CuonVo, viTri: Int, giay: LoaiGiay, huong: HuongGiay,
                               kho: ModelContext) -> TrangVo {
        var ds = cuon.trangsTheoThuTu
        let t = TrangVo(cuon: cuon, thuTu: ds.count, giay: giay, huong: huong)
        kho.insert(t)
        ds.insert(t, at: min(max(0, viTri), ds.count))
        danhSoLai(ds)
        danhDauCay(cuon)
        luu(kho)
        return t
    }

    /// Nhân bản ĐẦY ĐỦ một trang: nét, nền PDF/ảnh, giấy, tên, chữ đã đọc.
    ///
    /// ⚠️ Bản cũ (menu ⋯) chỉ chép nét — nhân bản một trang chú thích trên
    /// giáo trình ra một trang mực trôi trên giấy trắng. Nhãn chương KHÔNG
    /// chép: hai trang cùng nhãn là mục lục có hai mục trùng nhau.
    @discardableResult
    static func nhanBan(_ goc: TrangVo, kho: ModelContext) -> TrangVo? {
        guard let cuon = goc.cuon else { return nil }
        var ds = cuon.trangsTheoThuTu
        guard let i = ds.firstIndex(where: { $0.id == goc.id }) else { return nil }
        let t = TrangVo(cuon: cuon, thuTu: ds.count, giay: goc.giay, huong: goc.huong)
        if let ten = goc.tieuDe, !ten.isEmpty { t.tieuDe = ten + " " + T("(bản sao)") }
        t.nenPdfTen = goc.nenPdfTen
        t.nenPdfTrang = goc.nenPdfTrang
        t.nenAnhTen = goc.nenAnhTen
        t.nenKhoaR2 = goc.nenKhoaR2
        t.nenLoaiR2 = goc.nenLoaiR2
        t.chuNhanDang = goc.chuNhanDang
        t.nhanDangLuc = goc.nhanDangLuc
        t.coNet = goc.coNet
        kho.insert(t)
        KhoVo.nhanBan(tu: goc.id, sang: t.id)
        KhoVo.nhanBanAnhNho(tu: goc.id, sang: t.id)
        ds.insert(t, at: i + 1)
        danhSoLai(ds)
        danhDauCay(cuon)
        luu(kho)
        return t
    }

    // MARK: Giấy

    static func doiGiay(_ ds: [TrangVo], thanh g: LoaiGiay, kho: ModelContext) {
        for t in ds where t.loaiGiay != g.rawValue {
            t.loaiGiay = g.rawValue
            t.suaLuc = Date()
            danhDauCay(t.cuon)
        }
        luu(kho)
    }

    // MARK: Chuyển sang cuốn khác

    /// Chuyển các trang sang cuối cuốn `dich`, giữ nguyên thứ tự giữa chúng.
    ///
    /// Nét vẽ nằm ở tệp theo id trang nên không phải chép gì; trên máy chủ
    /// lượt đồng bộ cây kế tiếp mang `chapterId` mới theo (`dongBoCay` có
    /// `chapterId` trong nhánh `update`).
    ///
    /// Trả về `false` (không làm gì) nếu việc chuyển để lại một cuốn RỖNG.
    @discardableResult
    static func chuyen(_ trangs: [TrangVo], sang dich: CuonVo, kho: ModelContext) -> Bool {
        let ids = Set(trangs.map(\.id))
        var cuonNguon: [UUID: CuonVo] = [:]
        for t in trangs { if let c = t.cuon, c.id != dich.id { cuonNguon[c.id] = c } }
        let deLaiCuonRong = cuonNguon.values.contains { c in
            c.trangsTheoThuTu.allSatisfy { ids.contains($0.id) }
        }
        if deLaiCuonRong { return false }
        let sapXep = trangs.filter { $0.cuon?.id != dich.id }
            .sorted { ($0.cuon?.thuTu ?? 0, $0.thuTu) < ($1.cuon?.thuTu ?? 0, $1.thuTu) }
        guard !sapXep.isEmpty else { return true }
        var dsDich = dich.trangsTheoThuTu
        for t in sapXep {
            t.cuon = dich
            t.suaLuc = Date()
            dsDich.append(t)
        }
        danhSoLai(dsDich)
        for c in cuonNguon.values {
            let conLai = c.trangsTheoThuTu.filter { !ids.contains($0.id) }
            danhSoLai(conLai)
            c.trangDangDoc = min(c.trangDangDoc, max(0, conLai.count - 1))
            danhDauCay(c)
        }
        danhDauCay(dich)
        luu(kho)
        return true
    }

    // MARK: Xoá + hoàn tác

    /// Thư mục giữ tạm nét của những trang vừa xoá, chờ Hoàn tác.
    private static var thuMucHoanTac: URL {
        let u = KhoVo.thuMucGoc.appendingPathComponent("hoantac", isDirectory: true)
        if !FileManager.default.fileExists(atPath: u.path) {
            try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        }
        return u
    }

    /// Xoá các trang (cùng một cuốn). Trả về bản chụp để hoàn tác, hoặc `nil`
    /// nếu việc xoá sẽ làm cuốn vở rỗng — người gọi phải chặn TRƯỚC và nói
    /// lý do bằng chữ, đừng để nút bấm-không-ăn.
    static func xoa(_ trangs: [TrangVo], kho: ModelContext) -> [TrangDaXoa]? {
        guard let cuon = trangs.first?.cuon else { return nil }
        let ids = Set(trangs.map(\.id))
        let ds = cuon.trangsTheoThuTu
        guard ds.contains(where: { !ids.contains($0.id) }) else { return nil }

        // Lượt hoàn tác trước hết hạn: dọn tệp tạm của nó.
        if let cu = try? FileManager.default.contentsOfDirectory(at: thuMucHoanTac,
                                                                 includingPropertiesForKeys: nil) {
            for u in cu { try? FileManager.default.removeItem(at: u) }
        }

        var chup: [TrangDaXoa] = []
        for (i, t) in ds.enumerated() where ids.contains(t.id) {
            let tam = thuMucHoanTac.appendingPathComponent("\(t.id.uuidString).drawing")
            try? FileManager.default.copyItem(at: KhoVo.duongDanNet(t.id), to: tam)
            chup.append(TrangDaXoa(
                idCu: t.id, viTri: i, tieuDe: t.tieuDe, tenChuong: t.tenChuong,
                loaiGiay: t.loaiGiay, huongGiay: t.huongGiay, danhDau: t.danhDau,
                chuNhanDang: t.chuNhanDang, nhanDangLuc: t.nhanDangLuc,
                nenPdfTen: t.nenPdfTen, nenPdfTrang: t.nenPdfTrang, nenAnhTen: t.nenAnhTen,
                nenKhoaR2: t.nenKhoaR2, nenLoaiR2: t.nenLoaiR2,
                ghiAmTen: t.ghiAmTen, ghiAmDai: t.ghiAmDai, mocNet: t.mocNet, coNet: t.coNet))
            DongBoVo.ghiNhanXoa(kho: kho, maDoiTuong: t.id.uuidString, loai: "trang")
            kho.delete(t)
        }
        let conLai = ds.filter { !ids.contains($0.id) }
        danhSoLai(conLai)
        cuon.trangDangDoc = min(cuon.trangDangDoc, max(0, conLai.count - 1))
        danhDauCay(cuon)
        luu(kho)
        for id in ids { KhoVo.xoa(id) }
        DongBoVo.shared.batDau()
        return chup
    }

    /// Dựng lại các trang vừa xoá, về đúng vị trí cũ (id MỚI — xem `TrangDaXoa`).
    @discardableResult
    static func hoanTacXoa(_ chup: [TrangDaXoa], vao cuon: CuonVo, kho: ModelContext) -> [TrangVo] {
        var ds = cuon.trangsTheoThuTu
        var moi: [TrangVo] = []
        for c in chup.sorted(by: { $0.viTri < $1.viTri }) {
            let t = TrangVo(cuon: cuon, thuTu: ds.count,
                            giay: LoaiGiay(rawValue: c.loaiGiay) ?? .keNgang,
                            huong: HuongGiay(rawValue: c.huongGiay) ?? .doc)
            t.tieuDe = c.tieuDe
            t.tenChuong = c.tenChuong
            t.danhDau = c.danhDau
            t.chuNhanDang = c.chuNhanDang
            t.nhanDangLuc = c.nhanDangLuc
            t.nenPdfTen = c.nenPdfTen
            t.nenPdfTrang = c.nenPdfTrang
            t.nenAnhTen = c.nenAnhTen
            t.nenKhoaR2 = c.nenKhoaR2
            t.nenLoaiR2 = c.nenLoaiR2
            t.ghiAmTen = c.ghiAmTen
            t.ghiAmDai = c.ghiAmDai
            t.mocNet = c.mocNet
            t.coNet = c.coNet
            kho.insert(t)
            let tam = thuMucHoanTac.appendingPathComponent("\(c.idCu.uuidString).drawing")
            if FileManager.default.fileExists(atPath: tam.path) {
                try? FileManager.default.copyItem(at: tam, to: KhoVo.duongDanNet(t.id))
                try? FileManager.default.removeItem(at: tam)
            }
            let net = KhoVo.nap(t.id)
            KhoVo.dungAnhNho(net, kho: t.khoTrang, cho: t.id, nenPdfTen: t.nenPdfTen,
                             nenPdfTrang: t.nenPdfTrang, nenAnhTen: t.nenAnhTen)
            ds.insert(t, at: min(c.viTri, ds.count))
            moi.append(t)
        }
        danhSoLai(ds)
        danhDauCay(cuon)
        luu(kho)
        DongBoVo.shared.batDau()
        return moi
    }
}
#endif
