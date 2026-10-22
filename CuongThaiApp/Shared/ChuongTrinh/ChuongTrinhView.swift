import SwiftUI

// ════════════════════════════════════════════════════════════════
// CHƯƠNG TRÌNH ĐÀO TẠO — màn tổng (22/10/2026). Bản app của /courses trên web
// (`frontend/src/components/courses/chuong-trinh/ChuongTrinhClient.tsx`).
//
// Ba cách xem dùng CHUNG một lần tải (lọc/tìm chạy trên máy):
//   · Theo lộ trình (mặc định): bản đồ bốn năm → từng năm → từng kỳ → 5 khoá theo thứ tự nên học,
//     rồi "Khoá mới" (chưa xếp kỳ — KHÔNG BAO GIỜ giấu) và "Môn tự chọn · Sắp ra mắt".
//   · Theo chuyên ngành: nhóm theo danh mục khoá.
//   · Tất cả: lưới thẻ + tìm không dấu + lọc cấp độ.
// Bề ngang rộng (iPad, không chia đôi màn): cột trái là mục lục lộ trình (chạm để nhảy),
// cột phải là nội dung. Bề ngang hẹp (iPhone, iPad Split View hẹp) ⇒ một cột.
// Máy chủ chưa có endpoint ⇒ VM lùi về danh sách phẳng; màn chỉ mở Chuyên ngành / Tất cả.
// ════════════════════════════════════════════════════════════════

enum CheDoXemCT: String, CaseIterable, Identifiable {
    case loTrinh, chuyenNganh, tatCa
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .loTrinh: return T("Theo lộ trình")
        case .chuyenNganh: return T("Theo chuyên ngành")
        case .tatCa: return T("Tất cả khoá")
        }
    }
    var tenNgan: String {
        switch self {
        case .loTrinh: return T("Lộ trình học")
        case .chuyenNganh: return T("Chuyên ngành")
        case .tatCa: return T("Tất cả")
        }
    }
}

struct ChuongTrinhView: View {
    @StateObject private var vm: ChuongTrinhDaoTaoVM
    @State private var cheDo: CheDoXemCT
    @State private var oTim: String
    @State private var boLoc: BoLocCT
    @State private var mucMoDau: String?
    @State private var mucNhay: String?
    @State private var kyDangThay: Set<Int> = []
    @State private var hienTieuDeNho = false

    @Environment(\.horizontalSizeClass) private var lopNgang
    @ObservedObject private var nn = QuanLyNgonNguApp.shared
    @ScaledMetric(relativeTo: .largeTitle) private var coTieuDe: CGFloat = 38
    @ScaledMetric(relativeTo: .largeTitle) private var coTieuDeRong: CGFloat = 56

    /// `vm` truyền từ tab Học ⇒ dùng lại bản đã tải (thẻ ở tab Học cập nhật theo). `kyMoDau` ⇒ cuộn tới kỳ đó;
    /// `muc` ⇒ cuộn tới một neo bất kỳ (`khoa-moi`, `tu-chon`, `nam-2`…).
    init(vm: ChuongTrinhDaoTaoVM? = nil,
         cheDo: CheDoXemCT = .loTrinh, tuKhoa: String = "", kyMoDau: Int? = nil, muc: String? = nil) {
        _vm = StateObject(wrappedValue: vm ?? ChuongTrinhDaoTaoVM())
        _cheDo = State(initialValue: cheDo)
        _oTim = State(initialValue: tuKhoa)
        _boLoc = State(initialValue: BoLocCT(tuKhoa: tuKhoa))
        _mucMoDau = State(initialValue: muc ?? kyMoDau.map { "ky-\($0)" })
    }

    private var rong: Bool { lopNgang == .regular }
    private var anh: Bool { nn.ngonNgu == .anh }

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if rong, let d = vm.duLieu {
                    HStack(alignment: .top, spacing: 0) {
                        ThanhBenCT(duLieu: d, cheDo: cheDoHieuLuc, kyDangXem: kyDangThay.min(),
                                   nganhDangChon: boLoc.nganh, nhay: { mucNhay = $0 },
                                   chonNganh: { boLoc.nganh = $0 })
                            .frame(width: 270)
                        Rectangle().fill(MauCT.ke).frame(width: 0.5).ignoresSafeArea(edges: .bottom)
                        cuon
                    }
                } else {
                    cuon
                }
            }
            .onChange(of: mucNhay) { _, id in
                guard let id else { return }
                mucNhay = nil
                Haptics.cham()
                // LazyVStack chỉ ƯỚC LƯỢNG vị trí hàng chưa dựng ⇒ nhảy xa có thể hụt: nhảy một lần cho
                // các hàng quanh đích được dựng + đo, rồi chỉnh lại đúng chỗ.
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(id, anchor: .top) }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(420))
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
        .background(MauCT.giay.ignoresSafeArea())
        .navigationTitle(hienTieuDeNho ? T("Chương trình đào tạo") : "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.tai()
            if let muc = mucMoDau, vm.duLieu != nil {
                mucMoDau = nil
                try? await Task.sleep(for: .milliseconds(150))
                mucNhay = muc
            }
        }
        // Gõ xong 250 ms mới lọc — đủ nhanh để thấy kết quả, không giật theo từng phím.
        .task(id: oTim) {
            if oTim != boLoc.tuKhoa { try? await Task.sleep(for: .milliseconds(250)) }
            guard !Task.isCancelled else { return }
            boLoc.tuKhoa = oTim
        }
    }

    // MARK: Cuộn chính

    private var cuon: some View {
        ScrollView {
            // ⚠️ KHÔNG ghim thanh "Cách xem" (`pinnedViews`): đã thử — mọi cú nhảy tới học kỳ đều rơi dưới
            // thanh ghim và mất nhãn "Học kỳ N". Điện thoại đổi chế độ ở đầu trang; iPad có cột mục lục.
            LazyVStack(alignment: .leading, spacing: 0) {
                dauTrang.id("dau")
                thanhCheDo
                noiDung
            }
            .padding(.horizontal, rong ? 40 : Spacing.md)
            .frame(maxWidth: rong ? 940 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 64)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await vm.tai() }
    }

    @ViewBuilder
    private var noiDung: some View {
        hangTim.padding(.bottom, 4)
        if let d = vm.duLieu {
            switch cheDoHieuLuc {
            case .loTrinh: XemLoTrinhCT(duLieu: d, boLoc: boLoc, rong: rong, kyHienTai: d.kyHienTai,
                                        nhay: { mucNhay = $0 }, xoaLoc: xoaLoc,
                                        thay: { k, co in if co { kyDangThay.insert(k) } else { kyDangThay.remove(k) } })
            case .chuyenNganh: XemChuyenNganhCT(duLieu: d, boLoc: $boLoc, rong: rong, xoaLoc: xoaLoc)
            case .tatCa: XemTatCaCT(duLieu: d, boLoc: $boLoc, rong: rong, xoaLoc: xoaLoc)
            }
        } else if let loi = vm.loi {
            ErrorStateView(message: loi) { Task { await vm.tai() } }
                .padding(.top, Spacing.xl)
        } else {
            KhungChoCT(rong: rong)
        }
    }

    private var cacCheDo: [CheDoXemCT] {
        vm.duLieu?.coLoTrinh == false ? [.chuyenNganh, .tatCa] : CheDoXemCT.allCases
    }

    private var cheDoHieuLuc: CheDoXemCT { cacCheDo.contains(cheDo) ? cheDo : .chuyenNganh }

    private func xoaLoc() {
        oTim = ""
        boLoc = BoLocCT()
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CuongThai  /  \(T("Khoá học"))")
                .font(.caption)
                .foregroundColor(MauCT.muc3)
            Text(T("Chương trình đào tạo"))
                .font(.system(size: rong ? coTieuDeRong : coTieuDe, weight: .regular, design: .serif))
                .tracking(-0.4)
                .foregroundColor(MauCT.muc)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
                .onGeometryChange(for: Bool.self) { g in g.frame(in: .global).maxY < 90 } action: { an in
                    if an != hienTieuDeNho { hienTieuDeNho = an }
                }
            Text(loiDan)
                .font(rong ? .title3 : .body)
                .foregroundColor(MauCT.muc2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.top, 14)

            if let d = vm.duLieu {
                LuoiSoCT(duLieu: d, rong: rong).padding(.top, 22)
            } else if vm.loi == nil {
                SkeletonBox(height: 64).padding(.top, 22)
            }

            lienKetAcademy.padding(.top, 14)

            if let ds = vm.duLieu?.dangHoc, !ds.isEmpty {
                DaiDangHocCT(ds: Array(ds.prefix(3))).padding(.top, 18)
            }
        }
        .padding(.top, rong ? 36 : 8)
        .padding(.bottom, 18)
    }

    private var loiDan: String {
        vm.duLieu?.coLoTrinh == false
            ? T("Toàn bộ khoá học tự biên soạn, nhóm theo chuyên ngành — từ nền tảng tới chuyên sâu.")
            : T("Mười lăm học kỳ, đi từ dòng lệnh đầu tiên tới hệ thống chạy thật. Mỗi kỳ năm khoá, xếp theo thứ tự nên học — học trọn một kỳ là làm được một việc cụ thể.")
    }

    private var lienKetAcademy: some View {
        NavigationLink { AcademyView() } label: {
            (Text(T("Đang học tại FPT University?")).foregroundColor(MauCT.muc2)
             + Text("  ")
             + Text(T("Các môn theo giáo trình trường ở FPTU Academy")).foregroundColor(MauCT.nhan).underline()
             + Text(" ") + Text(Image(systemName: "arrow.up.right")).foregroundColor(MauCT.nhan))
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: Chế độ xem + tìm

    private var thanhCheDo: some View {
        HStack(spacing: 0) {
            ForEach(Array(cacCheDo.enumerated()), id: \.element) { i, k in
                Button {
                    guard k != cheDoHieuLuc else { return }
                    Haptics.cham()
                    withAnimation(.easeOut(duration: 0.18)) { cheDo = k }
                } label: {
                    Text(rong ? k.ten : k.tenNgan)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(k == cheDoHieuLuc ? MauCT.giay : MauCT.muc2)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(k == cheDoHieuLuc ? MauCT.muc : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(k == cheDoHieuLuc ? [.isSelected] : [])
                if i < cacCheDo.count - 1 { Rectangle().fill(MauCT.keDam).frame(width: 1) }
            }
        }
        .frame(maxWidth: rong ? 520 : .infinity)
        .overlay(Rectangle().stroke(MauCT.keDam, lineWidth: 1))
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MauCT.giay)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(T("Cách xem"))
    }

    private var hangTim: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(MauCT.muc3)
                    .accessibilityHidden(true)
                TextField(T("Tìm khoá học…"), text: $oTim)
                    .font(.subheadline)
                    .foregroundColor(MauCT.muc)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                if !oTim.isEmpty {
                    Button { oTim = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(MauCT.muc3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(T("Xoá từ khoá"))
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 40)
            .background(MauCT.the)
            .overlay(Rectangle().stroke(MauCT.ke, lineWidth: 1))

            Menu {
                Picker(T("Cấp độ"), selection: $boLoc.capDo) {
                    Text(T("Mọi cấp độ")).tag(CapDoCT?.none)
                    ForEach(CapDoCT.allCases) { Text($0.ten).tag(CapDoCT?.some($0)) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(boLoc.capDo?.ten ?? T("Mọi cấp độ")).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
                .font(.subheadline)
                .foregroundColor(boLoc.capDo == nil ? MauCT.muc2 : MauCT.nhan)
                .padding(.horizontal, 10)
                .frame(minHeight: 40)
                .background(MauCT.the)
                .overlay(Rectangle().stroke(boLoc.capDo == nil ? MauCT.ke : MauCT.nhan, lineWidth: 1))
            }
            .accessibilityLabel(T("Cấp độ"))
            .accessibilityValue(boLoc.capDo?.ten ?? T("Mọi cấp độ"))
        }
        .frame(maxWidth: rong ? 520 : .infinity, alignment: .leading)
    }
}

// MARK: - Số liệu đầu trang

private struct LuoiSoCT: View {
    let duLieu: ChuongTrinhDaoTao
    let rong: Bool
    @ObservedObject private var nn = QuanLyNgonNguApp.shared
    @ScaledMetric(relativeTo: .title) private var coSo: CGFloat = 30

    var body: some View {
        let anh = nn.ngonNgu == .anh
        let t = duLieu.tong
        var o: [(String, String)] = [(ChuCT.so(t.khoa, anh), T("khoá học"))]
        if duLieu.coLoTrinh { o.append((ChuCT.so(t.ky, anh), T("học kỳ"))) }
        o.append((ChuCT.so(t.bai, anh), T("bài học")))
        if t.gio > 0 { o.append((ChuCT.so(t.gio, anh), T("giờ video"))) }
        let cot = rong || o.count == 3 ? o.count : 2
        return Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<Int(ceil(Double(o.count) / Double(cot))), id: \.self) { h in
                GridRow {
                    ForEach(0..<cot, id: \.self) { c in
                        let i = h * cot + c
                        if i < o.count {
                            o_(o[i].0, o[i].1, coKeTrai: c > 0)
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                }
                .overlay(alignment: .bottom) { KeMong() }
            }
        }
        .overlay(alignment: .top) { KeMong() }
        .frame(maxWidth: rong ? 640 : .infinity, alignment: .leading)
    }

    private func o_(_ so: String, _ nhan: String, coKeTrai: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(so)
                .font(.system(size: coSo, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundColor(MauCT.muc)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(nhan).font(.caption).foregroundColor(MauCT.muc3)
        }
        .padding(.vertical, 12)
        .padding(.leading, coKeTrai ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { if coKeTrai { Rectangle().fill(MauCT.ke).frame(width: 0.5) } }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bạn đang học

private struct DaiDangHocCT: View {
    let ds: [MonChuongTrinh]
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Bạn đang học"))
                .font(.caption.weight(.semibold))
                .foregroundColor(MauCT.muc2)
            ForEach(ds) { m in
                NavigationLink { CourseDetailView(slug: m.slug) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(m.ten(nn.ngonNgu == .anh))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(MauCT.muc)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(m.progress ?? 0)%")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(MauCT.nhan)
                        Image(systemName: "chevron.right").font(.caption2).foregroundColor(MauCT.muc3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(m.ten(nn.ngonNgu == .anh)), \(ChuCT.tienDo(m.progress ?? 0, nn.ngonNgu == .anh))")
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { KeMong() }
        .overlay(alignment: .bottom) { KeMong() }
    }
}

// MARK: - Lối mở một khoá

/// Khoá thường ⇒ màn chi tiết môn của Academy (bài, video, CuongMini y như Academy).
/// Khoá Sắp ra mắt ⇒ màn giới thiệu CHỈ ĐỌC (không ghi danh, không mở bài).
struct LienKetKhoaCT<Nhan: View>: View {
    let m: MonChuongTrinh
    @ViewBuilder let nhan: () -> Nhan

    var body: some View {
        NavigationLink {
            if m.laSapRaMat { KhoaSapRaMatView(mon: m) } else { CourseDetailView(slug: m.slug) }
        } label: {
            nhan()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theo lộ trình

private struct XemLoTrinhCT: View {
    let duLieu: ChuongTrinhDaoTao
    let boLoc: BoLocCT
    let rong: Bool
    let kyHienTai: (ky: KyHocCT, dangHoc: Bool)?
    let nhay: (String) -> Void
    let xoaLoc: () -> Void
    let thay: (Int, Bool) -> Void

    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let anh = nn.ngonNgu == .anh
        let khop = { (m: MonChuongTrinh) in boLoc.khop(m, boQuaNganh: true) }
        let nam = duLieu.nam.map { n -> NamHocCT in
            var n = n
            n.ky = n.ky.map { k in var k = k; k.mon = k.mon.filter(khop); return k }
                .filter { !$0.mon.isEmpty || !boLoc.coLoc }
            return n
        }.filter { !$0.ky.isEmpty }
        let moi = duLieu.chuaXep.filter(khop)
        let tuChon = duLieu.sapRaMat.map { g -> NhomTuChonCT in var g = g; g.mon = g.mon.filter(khop); return g }
            .filter { !$0.mon.isEmpty }
        let soKhop = nam.reduce(0) { $0 + $1.ky.reduce(0) { $0 + $1.mon.count } } + moi.count
            + tuChon.reduce(0) { $0 + $1.mon.count }

        if boLoc.coLoc && soKhop == 0 {
            KhongCoCT(xoaLoc: xoaLoc)
        } else {
            if boLoc.coLoc {
                DongKetQuaCT(so: soKhop, xoaLoc: xoaLoc)
            } else if !rong {
                BanDoNgangCT(duLieu: duLieu, kyHienTai: kyHienTai, nhay: nhay).padding(.top, 12)
            }

            ForEach(nam) { n in
                TieuDePhanCT(keo: "\(ChuCT.nam(n.so, anh))  ·  \(phamVi(n, anh))",
                             tieuDe: n.tenHien(anh), moTa: n.moTaHien(anh), rong: rong)
                    .padding(.top, rong ? 72 : 52)
                    .id("nam-\(n.so)")
                ForEach(n.ky) { k in
                    KhoiKyCT(ky: k, rong: rong, laKyHienTai: kyHienTai?.ky.so == k.so && kyHienTai?.dangHoc == true)
                        .id("ky-\(k.so)")
                        .onAppear { thay(k.so, true) }
                        .onDisappear { thay(k.so, false) }
                }
            }

            if !moi.isEmpty {
                TieuDePhanCT(tieuDe: T("Khoá mới"),
                             moTa: T("Khoá vừa ra mắt, chưa xếp vào học kỳ nào. Học độc lập được ngay."), rong: rong)
                    .padding(.top, rong ? 72 : 52)
                    .id("khoa-moi")
                DanhSachHangCT(ds: moi, rong: rong).padding(.top, 10)
            }

            if !tuChon.isEmpty {
                TieuDePhanCT(tieuDe: T("Môn tự chọn · Sắp ra mắt"),
                             moTa: T("Khung chương trình đã sẵn — mục lục từng phần, từng bài. Nội dung mở dần khi soạn xong; chưa đăng ký được."),
                             rong: rong)
                    .padding(.top, rong ? 72 : 52)
                    .id("tu-chon")
                ForEach(tuChon) { g in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(g.tenHien(anh))
                                .font(ChuCTFont.serif(.title2))
                                .foregroundColor(MauCT.muc)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            Text(ChuCT.khoa(g.mon.count, anh))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(MauCT.muc3)
                        }
                        .padding(.bottom, 10)
                        KeMong()
                        DanhSachHangCT(ds: g.mon, rong: rong)
                    }
                    .padding(.top, 34)
                }
            }
        }
    }

    private func phamVi(_ n: NamHocCT, _ anh: Bool) -> String {
        guard let a = n.ky.first?.so, let b = n.ky.last?.so else { return "" }
        return a == b ? ChuCT.ky(a, anh) : (anh ? "Terms \(a)–\(b)" : "Kỳ \(a)–\(b)")
    }
}

/// Một học kỳ: nhãn "Học kỳ N" · tên · mô tả · tóm tắt, rồi các khoá theo thứ tự.
private struct KhoiKyCT: View {
    let ky: KyHocCT
    let rong: Bool
    var laKyHienTai = false
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let anh = nn.ngonNgu == .anh
        let tomTat = [ChuCT.khoa(ky.mon.count, anh),
                      ky.mon.reduce(0) { $0 + $1.soBai } > 0 ? ChuCT.bai(ky.mon.reduce(0) { $0 + $1.soBai }, anh) : nil,
                      ChuCT.gio(ky.mon.reduce(0) { $0 + $1.soGiay }, anh).nilNeuRong]
            .compactMap { $0 }.joined(separator: " · ")
        VStack(alignment: .leading, spacing: 0) {
            dauKy(anh, tomTat)
                .padding(.bottom, 14)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(ChuCT.ky(ky.so, anh)), \(ky.tenHien(anh)), \(ChuCT.khoa(ky.mon.count, anh))")
                .accessibilityAddTraits(.isHeader)
            KeMong()
            if ky.mon.isEmpty {
                Text(T("Chưa có khoá nào trong kỳ này."))
                    .font(.footnote)
                    .foregroundColor(MauCT.muc3)
                    .padding(.vertical, 16)
            } else {
                DanhSachHangCT(ds: ky.mon, rong: rong, coSoThuTu: true)
            }
        }
        .padding(.top, rong ? 48 : 40)
    }

    @ViewBuilder
    private func dauKy(_ anh: Bool, _ tomTat: String) -> some View {
        let chu = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(ChuCT.hocKy(ky.so, anh))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(MauCT.nhan)
                if laKyHienTai {
                    Text(T("Bạn đang ở đây"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(MauCT.giay)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(MauCT.nhan)
                }
            }
            Text(ky.tenHien(anh))
                .font(ChuCTFont.serif(rong ? .title : .title2))
                .foregroundColor(MauCT.muc)
                .fixedSize(horizontal: false, vertical: true)
            if let mt = ky.moTaHien(anh) {
                Text(mt)
                    .font(rong ? .body : .subheadline)
                    .foregroundColor(MauCT.muc2)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 640, alignment: .leading)
            }
        }
        if rong {
            HStack(alignment: .bottom, spacing: 32) {
                chu.frame(maxWidth: .infinity, alignment: .leading)
                Text(tomTat).font(.caption.monospacedDigit()).foregroundColor(MauCT.muc3)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                chu
                Text(tomTat).font(.caption.monospacedDigit()).foregroundColor(MauCT.muc3)
            }
        }
    }
}

/// Các hàng khoá, kẻ mảnh giữa hai hàng.
private struct DanhSachHangCT: View {
    let ds: [MonChuongTrinh]
    let rong: Bool
    var coSoThuTu = false
    var hienKy = false

    var body: some View {
        ForEach(Array(ds.enumerated()), id: \.element.id) { i, m in
            VStack(spacing: 0) {
                LienKetKhoaCT(m: m) {
                    HangKhoaCT(m: m, soThuTu: coSoThuTu ? (m.loTrinhThuTu ?? i + 1) : nil, hienKy: hienKy, rong: rong)
                }
                if i < ds.count - 1 { KeMong() }
            }
        }
    }
}

/// Bản đồ bốn năm (điện thoại) — mỗi năm một cột, cuộn ngang; chạm kỳ để nhảy tới.
private struct BanDoNgangCT: View {
    let duLieu: ChuongTrinhDaoTao
    let kyHienTai: (ky: KyHocCT, dangHoc: Bool)?
    let nhay: (String) -> Void
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let anh = nn.ngonNgu == .anh
        VStack(alignment: .leading, spacing: 0) {
            Text(T("Lộ trình bốn năm"))
                .font(ChuCTFont.serif(.title3))
                .foregroundColor(MauCT.muc)
                .accessibilityAddTraits(.isHeader)
            Text(T("Chạm một học kỳ để tới thẳng phần đó."))
                .font(.caption)
                .foregroundColor(MauCT.muc3)
                .padding(.top, 3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(duLieu.nam) { n in
                        VStack(alignment: .leading, spacing: 0) {
                            Rectangle().fill(MauCT.keDam).frame(height: 1.5)
                            Text(ChuCT.nam(n.so, anh)).font(.caption2).foregroundColor(MauCT.muc3).padding(.top, 8)
                            Text(n.tenHien(anh)).font(ChuCTFont.serif(.headline)).foregroundColor(MauCT.muc)
                                .padding(.bottom, 6)
                            ForEach(Array(n.ky.enumerated()), id: \.element.id) { i, k in
                                Button { nhay("ky-\(k.so)") } label: {
                                    HangBanDoCT(ky: k, laHienTai: kyHienTai?.ky.so == k.so)
                                }
                                .buttonStyle(.plain)
                                if i < n.ky.count - 1 { KeMong() }
                            }
                        }
                        .frame(width: 196, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .padding(.horizontal, -16)
            LoiTatPhuCT(duLieu: duLieu, nhay: nhay).padding(.top, 14)
        }
        .padding(16)
        .background(MauCT.giay2)
    }
}

/// Một dòng kỳ trong bản đồ: "03  Frontend căn bản".
struct HangBanDoCT: View {
    let ky: KyHocCT
    var laHienTai = false
    var dangChon = false
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(format: "%02d", ky.so))
                .font(ChuCTFont.serif(.callout))
                .monospacedDigit()
                .foregroundColor(MauCT.nhan)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(ky.tenHien(nn.ngonNgu == .anh))
                    .font(.footnote.weight(dangChon ? .semibold : .regular))
                    .foregroundColor(MauCT.muc)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if laHienTai {
                    Text(T("Bạn đang ở đây")).font(.caption2.weight(.semibold)).foregroundColor(MauCT.nhan)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(T("Tới học kỳ này"))
    }
}

/// "Khoá mới — 3 khoá" · "Môn tự chọn · Sắp ra mắt — 12 khoá" ở chân bản đồ.
private struct LoiTatPhuCT: View {
    let duLieu: ChuongTrinhDaoTao
    let nhay: (String) -> Void
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let anh = nn.ngonNgu == .anh
        VStack(alignment: .leading, spacing: 8) {
            KeMong()
            if !duLieu.chuaXep.isEmpty {
                nut(T("Khoá mới"), ChuCT.khoa(duLieu.chuaXep.count, anh), "khoa-moi")
            }
            if !duLieu.monSapRaMat.isEmpty {
                nut(T("Môn tự chọn · Sắp ra mắt"), ChuCT.khoa(duLieu.monSapRaMat.count, anh), "tu-chon")
            }
        }
    }

    private func nut(_ ten: String, _ so: String, _ id: String) -> some View {
        Button { nhay(id) } label: {
            (Text(ten).foregroundColor(MauCT.nhan).underline() + Text("  —  \(so)").foregroundColor(MauCT.muc3))
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theo chuyên ngành

private struct XemChuyenNganhCT: View {
    let duLieu: ChuongTrinhDaoTao
    @Binding var boLoc: BoLocCT
    let rong: Bool
    let xoaLoc: () -> Void
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let anh = nn.ngonNgu == .anh
        let nhom = duLieu.nhomTheoNganh(duLieu.tatCaMon.filter { boLoc.khop($0) })
        if !rong { ChipNganhCT(duLieu: duLieu, boLoc: $boLoc).padding(.top, 10) }
        if nhom.isEmpty {
            KhongCoCT(xoaLoc: xoaLoc)
        } else {
            if boLoc.coLoc { DongKetQuaCT(so: nhom.reduce(0) { $0 + $1.mon.count }, xoaLoc: xoaLoc) }
            ForEach(nhom, id: \.nganh.id) { g in
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(MauCT.keDam).frame(height: 2)
                    HStack(alignment: .firstTextBaseline) {
                        Text(g.nganh.tenHien)
                            .font(ChuCTFont.serif(rong ? .largeTitle : .title))
                            .foregroundColor(MauCT.muc)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text(ChuCT.khoa(g.mon.count, anh)).font(.caption.monospacedDigit()).foregroundColor(MauCT.muc3)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    DanhSachHangCT(ds: g.mon, rong: rong, hienKy: true)
                }
                .padding(.top, 36)
                .id("nganh-\(g.nganh.id)")
            }
        }
    }
}

private struct ChipNganhCT: View {
    let duLieu: ChuongTrinhDaoTao
    @Binding var boLoc: BoLocCT

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, T("Mọi chuyên ngành"), nil)
                ForEach(duLieu.cacNganh()) { n in chip(n.slug, n.tenHien, n.so) }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    private func chip(_ slug: String?, _ ten: String, _ so: Int?) -> some View {
        let chon = boLoc.nganh == slug
        return Button {
            Haptics.cham()
            boLoc.nganh = slug
        } label: {
            HStack(spacing: 6) {
                Text(ten)
                if let so { Text("\(so)").monospacedDigit().opacity(0.6) }
            }
            .font(.footnote)
            .foregroundColor(chon ? MauCT.giay : MauCT.muc2)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(chon ? MauCT.muc : Color.clear)
            .overlay(Rectangle().stroke(chon ? MauCT.muc : MauCT.ke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chon ? [.isSelected] : [])
    }
}

// MARK: - Tất cả

private struct XemTatCaCT: View {
    let duLieu: ChuongTrinhDaoTao
    @Binding var boLoc: BoLocCT
    let rong: Bool
    let xoaLoc: () -> Void
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let ds = duLieu.tatCaMon.filter { boLoc.khop($0) }
        if !rong { ChipNganhCT(duLieu: duLieu, boLoc: $boLoc).padding(.top, 10) }
        if ds.isEmpty {
            KhongCoCT(xoaLoc: xoaLoc)
        } else {
            Text(ChuCT.ketQua(ds.count, nn.ngonNgu == .anh))
                .font(.footnote.monospacedDigit())
                .foregroundColor(MauCT.muc2)
                .padding(.top, 18)
                .padding(.bottom, 14)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: rong ? 230 : 152), spacing: rong ? 28 : 16, alignment: .top)],
                      alignment: .leading, spacing: rong ? 40 : 28) {
                ForEach(ds) { m in
                    LienKetKhoaCT(m: m) { TheKhoaCT(m: m) }
                }
            }
        }
    }
}

// MARK: - Mảnh nhỏ

private struct DongKetQuaCT: View {
    let so: Int
    let xoaLoc: () -> Void
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        HStack(spacing: 6) {
            Text(ChuCT.ketQua(so, nn.ngonNgu == .anh)).fontWeight(.semibold).foregroundColor(MauCT.muc).monospacedDigit()
            Text("·").foregroundColor(MauCT.muc3)
            Button(T("Xoá bộ lọc"), action: xoaLoc).foregroundColor(MauCT.nhan)
        }
        .font(.footnote)
        .padding(.top, 16)
    }
}

private struct KhongCoCT: View {
    let xoaLoc: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(T("Không có khoá nào khớp bộ lọc."))
                .font(.callout)
                .foregroundColor(MauCT.muc2)
            Button(T("Xoá bộ lọc"), action: xoaLoc)
                .font(.footnote.weight(.semibold))
                .foregroundColor(MauCT.nhan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .overlay(alignment: .top) { KeMong() }
        .padding(.top, 16)
    }
}

/// Khung chờ — đúng bố cục sắp hiện (năm → kỳ → hàng), không phải vòng xoay.
private struct KhungChoCT: View {
    let rong: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle().fill(MauCT.ke).frame(height: 2)
                    SkeletonBox(height: 12, width: 110, radius: 2)
                    SkeletonBox(height: 28, width: 220, radius: 2)
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(alignment: .top, spacing: 14) {
                            SkeletonBox(height: 58, width: rong ? 148 : 104, radius: 0)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBox(height: 14, radius: 2)
                                SkeletonBox(height: 11, width: 140, radius: 2)
                            }
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(.top, 40)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(T("Đang tải chương trình…"))
    }
}

// MARK: - Cột trái (iPad)

/// Mục lục cố định bên trái ở màn rộng. Lộ trình ⇒ 4 năm × kỳ (chạm để nhảy, kỳ đang xem được tô);
/// hai chế độ kia ⇒ danh sách chuyên ngành (chạm để lọc).
private struct ThanhBenCT: View {
    let duLieu: ChuongTrinhDaoTao
    let cheDo: CheDoXemCT
    let kyDangXem: Int?
    let nganhDangChon: String?
    let nhay: (String) -> Void
    let chonNganh: (String?) -> Void
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let anh = nn.ngonNgu == .anh
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if cheDo == .loTrinh {
                    Text(T("Lộ trình bốn năm"))
                        .font(ChuCTFont.serif(.title3))
                        .foregroundColor(MauCT.muc)
                        .accessibilityAddTraits(.isHeader)
                    Text(T("Chạm một học kỳ để tới thẳng phần đó."))
                        .font(.caption).foregroundColor(MauCT.muc3).padding(.top, 3)
                    ForEach(duLieu.nam) { n in
                        VStack(alignment: .leading, spacing: 0) {
                            Rectangle().fill(MauCT.keDam).frame(height: 1.5)
                            Button { nhay("nam-\(n.so)") } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ChuCT.nam(n.so, anh)).font(.caption2).foregroundColor(MauCT.muc3)
                                    Text(n.tenHien(anh)).font(ChuCTFont.serif(.headline)).foregroundColor(MauCT.muc)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            ForEach(n.ky) { k in
                                Button { nhay("ky-\(k.so)") } label: {
                                    HangBanDoCT(ky: k, laHienTai: duLieu.kyHienTai?.ky.so == k.so && duLieu.kyHienTai?.dangHoc == true,
                                                dangChon: kyDangXem == k.so)
                                        .padding(.horizontal, 8)
                                        .background(kyDangXem == k.so ? MauCT.nhanNhat : Color.clear)
                                        .overlay(alignment: .leading) {
                                            if kyDangXem == k.so { Rectangle().fill(MauCT.nhan).frame(width: 2) }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 18)
                    }
                    LoiTatPhuCT(duLieu: duLieu, nhay: nhay).padding(.top, 18)
                } else {
                    Text(T("Chuyên ngành"))
                        .font(ChuCTFont.serif(.title3))
                        .foregroundColor(MauCT.muc)
                        .padding(.bottom, 10)
                        .accessibilityAddTraits(.isHeader)
                    Rectangle().fill(MauCT.keDam).frame(height: 1.5)
                    hangNganh(nil, T("Mọi chuyên ngành"), duLieu.tatCaMon.count)
                    ForEach(duLieu.cacNganh()) { n in
                        KeMong()
                        hangNganh(n.slug, n.tenHien, n.so)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
        }
        .background(MauCT.giay2.ignoresSafeArea(edges: .bottom))
    }

    private func hangNganh(_ slug: String?, _ ten: String, _ so: Int) -> some View {
        let chon = nganhDangChon == slug
        return Button {
            Haptics.cham()
            chonNganh(slug)
        } label: {
            HStack {
                Text(ten).font(.subheadline.weight(chon ? .semibold : .regular)).foregroundColor(MauCT.muc)
                Spacer()
                Text("\(so)").font(.caption.monospacedDigit()).foregroundColor(MauCT.muc3)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(chon ? MauCT.nhanNhat : Color.clear)
            .overlay(alignment: .leading) { if chon { Rectangle().fill(MauCT.nhan).frame(width: 2) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chon ? [.isSelected] : [])
    }
}
