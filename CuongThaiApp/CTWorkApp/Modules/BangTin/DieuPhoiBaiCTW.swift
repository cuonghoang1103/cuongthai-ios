import SwiftUI

// MARK: - Điều phối thao tác trên thẻ bài (dùng chung bảng tin + màn chi tiết)
//
// Một chỗ dựng `HanhDongBaiCTW` từ VM + giữ MỘT tấm phủ (bẫy C5: một view một `.sheet`) + trình xem ảnh toàn màn +
// Xem nhanh tệp. Link trong bài: @nhắc ⇒ hồ sơ Thành viên · #tag ⇒ bảng tin lọc theo tag · `/work/…/issue/n` ⇒ đẩy thẻ
// trong ngăn xếp đang đứng · `/work/<ws>/feed?post=` ⇒ màn bài · `/work/…` khác ⇒ `DinhTuyenCTW` · web ngoài ⇒ trình
// duyệt trong app (`SafariCTW` — trang cuongthai.com đi qua chốt 3.1.1).

enum TamPhuBangTinCTW: Identifiable {
    case binhLuan(CTWFeedPost)
    case camXuc(CTWFeedPost)
    case baoCao(CTWFeedPost)
    case soan(NoiDangBangTin?)
    case sua(CTWFeedPost)
    case hoSo(Int)
    case web(URL)

    var id: String {
        switch self {
        case .binhLuan(let p): return "bl\(p.id)"
        case .camXuc(let p): return "cx\(p.id)"
        case .baoCao(let p): return "bc\(p.id)"
        case .soan(let n): return "soan-\(n?.id ?? "")"
        case .sua(let p): return "sua\(p.id)"
        case .hoSo(let i): return "hs\(i)"
        case .web(let u): return u.absoluteString
        }
    }
}

struct XemPhuongTienMo: Identifiable {
    let id = UUID()
    let ds: [CTWFeedAttachment]
    let batDau: Int
}

@MainActor
final class DieuPhoiBaiCTW: ObservableObject {
    @Published var tamPhu: TamPhuBangTinCTW?
    @Published var xem: XemPhuongTienMo?
    @Published var xemTep: URL?
    @Published var dangMoTep: Int?
    @Published var loi: String?

    /// Đẩy một route vào ngăn xếp của màn chứa (NavigationPath cần KIỂU cụ thể — không đẩy `AnyHashable`).
    var day: (RouteBangTinCTW) -> Void = { _ in }
    var dayThe: (CTWRoute) -> Void = { _ in }

    /// Gắn ngăn xếp của khung (iPhone: cột tab · iPad: cột chi tiết).
    func gan(_ nx: NganXepCTW) {
        day = { [weak nx] r in nx?.duong.append(r) }
        dayThe = { [weak nx] r in nx?.duong.append(r) }
    }

    func hanhDong(_ vm: BangTinVM) -> HanhDongBaiCTW {
        var h = HanhDongBaiCTW()
        h.camXuc = { [weak vm] p, k in vm?.thaCamXuc(p, k) }
        h.binhLuan = { [weak self] p in self?.tamPhu = .binhLuan(p) }
        h.xemCamXuc = { [weak self] p in self?.tamPhu = .camXuc(p) }
        h.luu = { [weak vm] p in vm?.luu(p) }
        h.an = { [weak vm] p in vm?.an(p) }
        h.baoCao = { [weak self] p in self?.tamPhu = .baoCao(p) }
        h.chan = { [weak self] u in
            Task {
                do { try await ModerationStore.shared.block(userId: u.id, reason: nil); CTWRung.thanhCong() }
                catch { self?.loi = BangTinLoi.chu(error) }
            }
        }
        h.xoa = { [weak vm] p in Task { await vm?.xoa(p) } }
        h.ghim = { [weak vm] p in Task { await vm?.doiGhim(p) } }
        h.go = { [weak vm] p in Task { await vm?.doiGo(p) } }
        h.sua = { [weak self] p in self?.tamPhu = .sua(p) }
        h.bauChon = { [weak vm] p, ids in Task { await vm?.bauChon(p, ids) } }
        h.moURL = { [weak self] u in self?.moURL(u) }
        h.xemPhuongTien = { [weak self] ds, i in self?.xem = XemPhuongTienMo(ds: ds, batDau: i) }
        h.moTep = { [weak self] a in Task { await self?.moTep(a) } }
        h.thuLai = { KhoBangTinCTW.shared.thuLai($0) }
        h.boTam = { KhoBangTinCTW.shared.boBaiTam($0) }
        h.suaTam = { p in
            guard let k = p.khoaTam, let w = p.workspace else { return }
            KhoBangTinCTW.shared.suaBaiBiChan(k, noi: NoiDangBangTin(ws: w, duAn: p.project))
        }
        h.boAn = { [weak vm] p in Task { await vm?.boAn(p) } }
        h.moBai = { [weak self] p in self?.day(RouteBangTinCTW.bai(id: p.id, binhLuan: nil)) }
        return h
    }

    // MARK: Link

    func moURL(_ u: URL) {
        if u.scheme == ChuBangTin.luocDo {
            switch u.host {
            case "nguoi":
                if let id = Int(u.lastPathComponent) { moHoSo(id) }
            case "tag":
                let t = u.lastPathComponent.removingPercentEncoding ?? u.lastPathComponent
                var l = LocBangTin.gop
                l.q = "#" + t
                day(RouteBangTinCTW.hashtag(t, l))
            default: break
            }
            return
        }
        if let d = DichBangTin.tach(u.absoluteString) { day(RouteBangTinCTW.bai(id: d.post, binhLuan: d.comment)); return }
        if TrinhDuyetCuongThaiCTW.laCuaCuongThai(u), let d = DuongDanCTW.tach(u.absoluteString) {
            if d.doan == "issue", let ma = d.maDuAn, let so = d.phanCon.first.flatMap(Int.init) {
                dayThe(CTWRoute.theTheoMa(slug: d.slug, ma: ma, so: so))
            } else {
                DinhTuyenCTW.mo(duongDan: u.path + (u.query.map { "?" + $0 } ?? ""))
            }
            return
        }
        guard ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { return }
        tamPhu = .web(u)
    }

    func moHoSo(_ id: Int) {
        let kho = KhoTinNhanCTW.shared
        if kho.thanhVien(id) != nil { tamPhu = .hoSo(id); return }
        Task {
            await kho.taiDanhBa()
            if kho.thanhVien(id) != nil { tamPhu = .hoSo(id) }
            else { loi = String(localized: "This person's profile isn't available.") }
        }
    }

    /// Tệp: xin URL tải về (đúng tên tệp) ⇒ tải tạm ⇒ Xem nhanh.
    func moTep(_ a: CTWFeedAttachment) async {
        dangMoTep = a.id
        defer { dangMoTep = nil }
        do {
            var nguon: URL?
            if let r: CTWFeedURL = try? await APIClient.shared.request(CTWAPI.duongTep(a.id, taiVe: true)), let s = r.url { nguon = URL(string: s) }
            if nguon == nil { nguon = await DuongTepBangTin.url(a, kieu: "full") }
            guard let nguon else { throw TaiLenBangTin.Loi.khongDocDuoc }
            xemTep = try await CTWXemTep.taiVe(url: nguon, ten: a.fileName ?? "file", khoa: "feed-\(a.id)")
        } catch {
            loi = BangTinLoi.chu(error)
        }
    }
}

/// Gắn tấm phủ + trình xem của Bảng tin vào một màn.
struct GanTamPhuBangTin: ViewModifier {
    @ObservedObject var dp: DieuPhoiBaiCTW
    let vm: BangTinVM

    func body(content: Content) -> some View {
        content
            .sheet(item: $dp.tamPhu) { t in
                switch t {
                case .binhLuan(let p):
                    BinhLuanBaiCTW(post: p) { u in
                        dp.tamPhu = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dp.moURL(u) }
                    }
                case .camXuc(let p): AiThaCamXucCTW(post: p)
                case .baoCao(let p):
                    BaoCaoBangTinCTW(dich: .bai(p.id), tacGia: p.author) { vm.daBaoCao(p.id) }
                case .soan(let n): SoanBaiCTW(noi: n)
                case .sua(let p): SoanBaiCTW(noi: nil, sua: p)
                case .hoSo(let id): NavigationStack { HoSoThanhVienCTW(userId: id, laTamPhu: true) }
                case .web(let u): SafariCTW(url: u).ignoresSafeArea()
                }
            }
            .fullScreenCover(item: $dp.xem) { x in XemPhuongTienCTW(ds: x.ds, chiSo: x.batDau) }
            .ctwXemTep($dp.xemTep)
            .overlay {
                if dp.dangMoTep != nil {
                    ProgressView().controlSize(.large).padding(24)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                }
            }
            .alert(dp.loi ?? "", isPresented: Binding(get: { dp.loi != nil }, set: { if !$0 { dp.loi = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }
}

extension View {
    func ctwTamPhuBangTin(_ dp: DieuPhoiBaiCTW, _ vm: BangTinVM) -> some View { modifier(GanTamPhuBangTin(dp: dp, vm: vm)) }
}
