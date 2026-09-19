import Foundation
import SwiftUI

/// Trạng thái của cả mảng Tiền nong.
///
/// MỘT view model cho mọi màn con (tổng quan, chi, thu, nợ, ví, tiết kiệm,
/// đầu tư, mục tiêu). Lý do: mọi màn đều cần `dsVi` và `dsNhom` để đổ vào
/// bộ chọn, và mọi thao tác ghi đều làm lệch bảng tổng quan. Tách ra mỗi màn
/// một VM thì sau khi thêm một khoản chi, thẻ "Tổng số dư" ở màn trước vẫn
/// hiện số cũ cho tới khi người dùng tự kéo làm mới — và họ sẽ tưởng là mất
/// tiền.
@MainActor
final class TienVM: ObservableObject {
    // Tổng quan
    @Published var bang: BangTien?
    @Published var thang: String = NgayTien.thangHienTai()
    @Published var mucTieu: [MucTieuChi] = []
    /// Lỗi của RIÊNG khối mục tiêu, hiện ngay trong thẻ đó.
    ///
    /// Không dùng bảng lỗi chung: mục tiêu là một khối phụ, mà bảng lỗi chung
    /// che kín màn hình và chặn mọi thao tác khác. Cũng không nuốt im — nuốt
    /// đi thì thẻ hiện "Chưa đặt mục tiêu nào", và đó là một câu SAI khi thật
    /// ra là chưa hỏi được máy chủ.
    @Published var loiMucTieu: String?

    // Danh mục dùng chung
    @Published var dsVi: [Vi] = []
    @Published var dsNhom: [NhomChi] = []

    // Từng mảng
    @Published var dsChi: [KhoanChi] = []
    @Published var conTrangChi = false
    @Published var trangChi = 1
    @Published var locNhomId: Int?
    @Published var dsThu: [KhoanThu] = []
    @Published var dsNo: [No] = []
    @Published var dsTietKiem: [SoTietKiem] = []
    @Published var dsMucTieuTietKiem: [MucTieuTietKiem] = []
    @Published var dsDauTu: [KhoanDauTu] = []

    // Cố vấn AI
    @Published var nhanXetAI: String?
    @Published var dangHoiAI = false
    @Published var thieuKhoaAI = false

    @Published var dangTai = false
    @Published var loi: String?

    /// Đã nạp xong lần đầu chưa — để phân biệt "chưa tải" với "tải rồi mà
    /// trống". Hai cái đó phải hiện ra khác nhau: một cái là vòng quay, một
    /// cái là lời mời thêm khoản đầu tiên.
    @Published var daNapLanDau = false

    // MARK: - Nạp

    /// Nạp mọi thứ màn tổng quan cần. Gọi song song: sáu lời gọi tuần tự
    /// trên mạng 4G là ~3 giây nhìn vào màn trống.
    func napTatCa() async {
        dangTai = true
        defer { dangTai = false; daNapLanDau = true }
        await withTaskGroup(of: Void.self) { nhom in
            nhom.addTask { await self.napBang() }
            nhom.addTask { await self.napDanhMuc() }
            nhom.addTask { await self.napMucTieu() }
            nhom.addTask { await self.napNo() }
        }
        ghiAnhChupChoWidget()
    }

    func napBang() async {
        do { bang = try await TienAPI.bang(thang: thang) }
        catch { ghiLoi(error) }
    }

    func napDanhMuc() async {
        // Hai lời gọi độc lập nhau: một cái hỏng không được kéo cái kia chết
        // theo, vì thiếu NHÓM thì vẫn ghi chi được nếu còn VÍ, và ngược lại.
        async let vi = try? TienAPI.dsVi()
        async let nhom = try? TienAPI.dsNhomChi()
        let (v, n) = await (vi, nhom)
        if let v { dsVi = v.filter { !$0.isArchived } }
        if let n { dsNhom = n }
    }

    func napMucTieu() async {
        do {
            mucTieu = try await TienAPI.mucTieu().mucTieu
            loiMucTieu = nil
        } catch {
            if case APIError.unauthorized = error { return }
            loiMucTieu = error.localizedDescription
        }
    }

    func napChi(lamMoi: Bool = true) async {
        if lamMoi { trangChi = 1 }
        do {
            let t = try await TienAPI.dsChi(thang: thang, nhomId: locNhomId, trang: trangChi)
            if lamMoi { dsChi = t.items } else { dsChi += t.items }
            conTrangChi = (t.pagination?.totalPages ?? 1) > trangChi
        } catch { ghiLoi(error) }
    }

    func taiThemChi() async {
        guard conTrangChi, !dangTai else { return }
        trangChi += 1
        await napChi(lamMoi: false)
    }

    func napThu() async {
        do { dsThu = try await TienAPI.dsThu(thang: thang) }
        catch { ghiLoi(error) }
    }

    func napNo() async {
        do { dsNo = try await TienAPI.dsNo() }
        catch { ghiLoi(error) }
    }

    func napTietKiem() async {
        async let so = try? TienAPI.dsTietKiem()
        async let mt = try? TienAPI.dsMucTieuTietKiem()
        let (s, m) = await (so, mt)
        if let s { dsTietKiem = s }
        if let m { dsMucTieuTietKiem = m }
    }

    func napDauTu() async {
        do { dsDauTu = try await TienAPI.dsDauTu() }
        catch { ghiLoi(error) }
    }

    /// Đổi tháng đang xem. Nạp lại MỌI thứ phụ thuộc tháng.
    func doiThang(_ buoc: Int) async {
        thang = NgayTien.doiThang(thang, buoc)
        // Không nạp `dsChi`/`dsThu` ở đây: hai màn đó tự nạp khi mở. Nạp sẵn
        // là tải hai danh sách mà phần lớn lượt đổi tháng không ai nhìn tới.
        await napBang()
    }

    // MARK: - Ghi

    func themChi(nhomId: Int, viId: Int, soTien: Double, ngay: String, moTa: String?) async -> Bool {
        do {
            _ = try await TienAPI.themChi(nhomId: nhomId, viId: viId, soTien: soTien, ngay: ngay, moTa: moTa)
            await sauKhiGhiTien()
            await napChi()
            return true
        } catch { ghiLoi(error); return false }
    }

    func suaChi(id: Int, nhomId: Int, viId: Int, soTien: Double, ngay: String, moTa: String?) async -> Bool {
        do {
            _ = try await TienAPI.suaChi(id: id, nhomId: nhomId, viId: viId, soTien: soTien, ngay: ngay, moTa: moTa)
            await sauKhiGhiTien()
            await napChi()
            return true
        } catch { ghiLoi(error); return false }
    }

    func xoaChi(id: Int) async {
        do {
            _ = try await TienAPI.xoaChi(id: id)
            dsChi.removeAll { $0.id == id }
            await sauKhiGhiTien()
        } catch { ghiLoi(error) }
    }

    func themThu(viId: Int, soTien: Double, ngay: String, loai: String, nguonId: Int?, ghiChu: String?) async -> Bool {
        do {
            _ = try await TienAPI.themThu(viId: viId, soTien: soTien, ngay: ngay, loai: loai, nguonId: nguonId, ghiChu: ghiChu)
            await sauKhiGhiTien()
            await napThu()
            return true
        } catch { ghiLoi(error); return false }
    }

    func xoaThu(id: Int) async {
        do {
            _ = try await TienAPI.xoaThu(id: id)
            dsThu.removeAll { $0.id == id }
            await sauKhiGhiTien()
        } catch { ghiLoi(error) }
    }

    /// Tích/bỏ tích một kỳ nợ.
    ///
    /// Nạp lại CẢ danh sách nợ chứ không sửa tại chỗ: tích một kỳ làm đổi
    /// `computed.remaining`, `progressPct`, `nextDueDate` và cả `status` của
    /// khoản nợ — bốn thứ do máy chủ tính. Sửa tay ở app là chép lại công
    /// thức lần thứ hai rồi để hai bản trôi khỏi nhau.
    func doiTichKy(noId: Int, kyId: Int, dangTich: Bool, viId: Int?) async {
        do {
            if dangTich {
                _ = try await TienAPI.huyTraKy(noId: noId, kyId: kyId)
            } else {
                _ = try await TienAPI.traKy(noId: noId, kyId: kyId, viId: viId)
            }
            await napNo()
            await sauKhiGhiTien()
        } catch { ghiLoi(error) }
    }

    func datMucTieu(ky: String, soTien: Double) async -> Bool {
        do {
            _ = try await TienAPI.datMucTieu(ky: ky, soTien: soTien)
            await napMucTieu()
            return true
        } catch { ghiLoi(error); return false }
    }

    // MARK: Ảnh chụp cho widget

    /// Ghi lại số liệu cho widget đọc. Gọi sau mỗi lần nạp/ghi tiền.
    ///
    /// ⚠️ Gọi ở ĐÂY chứ không ở màn hình: widget phải đúng kể cả khi người
    /// dùng ghi một khoản chi rồi thoát app ngay, không kịp mở màn Tiền nong.
    func ghiAnhChupChoWidget() {
        var a = AnhChupTien()
        // Chưa đặt mục tiêu ngày thì KHÔNG có "đã tiêu hôm nay" — máy chủ chỉ
        // tính con số đó trong phạm vi một mục tiêu. Rơi về chi cả tháng còn
        // hơn hiện 0₫, vì 0₫ trông như "hôm nay chưa tiêu gì".
        a.chiHomNay = mucTieuNgay?.daTieu ?? 0
        a.hanMucNgay = mucTieuNgay?.mucTieu
        a.duNoSo = tongDuNo
        a.duNo = DinhDangTien.ngan(tongDuNo)
        a.laiMoiThang = DinhDangTien.ngan(tongLaiMoiThang)
        a.chiHomNayChu = mucTieuNgay != nil
            ? DinhDangTien.ngan(mucTieuNgay!.daTieu)
            : DinhDangTien.ngan(bang?.expenseThisMonth ?? 0)
        a.nhanChi = mucTieuNgay != nil ? "Chi hôm nay" : "Chi tháng này"
        if let h = mucTieuNgay?.mucTieu { a.hanMucNgayChu = DinhDangTien.ngan(h) }
        a.kyToi = noCanGap.prefix(3).map { k in
            AnhChupTien.Ky(id: k.id, debtId: k.debtId, ten: k.lenderName,
                           soTien: DinhDangTien.ngan(k.amountDue, k.currency),
                           ngay: NgayTien.mayChu.date(from: String(k.dueDate.prefix(10))) ?? Date(),
                           quaHan: k.isOverdue)
        }
        KhoAnhChupTien.ghi(a)
        LamMoiWidget.ngay()
    }

    /// Sau MỌI thao tác làm đổi tiền: bảng tổng quan, ví và mục tiêu đều lệch.
    private func sauKhiGhiTien() async {
        await withTaskGroup(of: Void.self) { n in
            n.addTask { await self.napBang() }
            n.addTask { await self.napMucTieu() }
            n.addTask { await self.napDanhMuc() }
        }
        ghiAnhChupChoWidget()
    }

    // MARK: - Cố vấn AI

    func hoiAITomTat() async {
        dangHoiAI = true
        defer { dangHoiAI = false }
        do {
            let kq = try await TienAPI.aiTomTat()
            thieuKhoaAI = kq.thieuKhoaAI
            nhanXetAI = kq.chu
        } catch { ghiLoi(error) }
    }

    // MARK: - Tiện

    /// Ví mặc định khi ghi khoản mới: ví đầu danh sách (đã sắp theo `order`).
    var viMacDinh: Vi? { dsVi.first }

    var mucTieuNgay: MucTieuChi? { mucTieu.first { $0.ky == "DAY" } }

    // MARK: Tổng về nợ và lãi

    /// ⚠️ Chỉ cộng khoản CHƯA trả xong. Cộng cả khoản đã tất toán vào "lãi
    /// mỗi tháng" thì con số phình lên và mất hết ý nghĩa — nó phải trả lời
    /// đúng một câu: từ tháng này trở đi mỗi tháng mất bao nhiêu tiền lãi.
    private var noDangCon: [No] { dsNo.filter { $0.status != "PAID_OFF" } }

    /// Tổng dư nợ gốc còn lại.
    var tongDuNo: Double { noDangCon.reduce(0) { $0 + ($1.computed?.remaining ?? 0) } }

    /// Mỗi tháng riêng tiền LÃI đi mất bao nhiêu (cộng kỳ tới của mọi khoản).
    var tongLaiMoiThang: Double { noDangCon.reduce(0) { $0 + $1.laiKyToi } }

    /// Tổng lãi của cả các khoản đang vay, gồm phần đã trả.
    var tongLaiCaKhoan: Double { noDangCon.reduce(0) { $0 + $1.laiCaKhoan } }

    /// Lãi CÒN phải trả từ giờ tới lúc hết nợ — con số đáng sợ nhất, và là
    /// con số quyết định có nên trả trước hạn hay không.
    var tongLaiConPhaiTra: Double { noDangCon.reduce(0) { $0 + $1.laiConPhaiTra } }

    /// Kỳ nợ đang QUÁ HẠN hoặc tới hạn trong 7 ngày — thứ cần hiện đỏ lên đầu.
    var noCanGap: [KyNoSapToi] {
        (bang?.upcomingPayments ?? []).filter { k in
            k.isOverdue || (NgayTien.conBaoNhieuNgay(k.dueDate).map { $0 <= 7 } ?? false)
        }
    }

    private func ghiLoi(_ e: Error) {
        // `unauthorized` KHÔNG hiện lên: `APIClient` đã tự làm mới token và
        // thử lại một lần; tới đây nghĩa là phiên hết hạn thật, và `AppState`
        // lo việc đưa về màn đăng nhập. Hiện thêm một bảng lỗi đỏ ở đây chỉ
        // làm người dùng tưởng app hỏng.
        if case APIError.unauthorized = e { return }
        loi = e.localizedDescription
    }
}
