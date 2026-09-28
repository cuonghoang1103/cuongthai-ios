import SwiftUI
import Charts

// MARK: - Nên trả khoản nào trước

/// So sánh bốn cách trả nợ + xếp hạng "dồn một khoản tiền vào đâu".
///
/// Mọi con số từ `GET /finance/debts/chien-luoc` — app không mô phỏng lại.
struct ChienLuocNoView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.horizontalSizeClass) private var beRong

    @State private var traThemChu = ""
    @State private var motLanChu = ""
    @State private var kq: ChienLuocNo?
    @State private var dangTinh = false
    @State private var loi: String?
    /// Số đã gửi cho lần tính đang hiện — để biết ô nhập đã đổi mà chưa tính lại.
    @State private var daTinhVoi: (Double, Double)?

    private var traThem: Double { DinhDangTien.doc(traThemChu) ?? 0 }
    private var motLan: Double { DinhDangTien.doc(motLanChu) ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                theNhap
                if let l = loi {
                    Text(l).font(.caption).foregroundStyle(AppColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let k = kq {
                    if let ds = k.khoanChuaKhaiPhi, !ds.isEmpty { canhBaoChuaKhaiPhi(ds) }
                    if let s = k.soSanh { theSoSanh(s) }
                    if let m = k.traMotLan { theMotLan(m) }
                    if let g = k.soSanh?.giaDinh, !g.isEmpty { theGiaDinh(g) }
                } else if dangTinh {
                    ProgressView().padding(.top, 30)
                }
            }
            .padding(Spacing.md)
            .padding(.bottom, 40)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Nên trả khoản nào trước"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { if kq == nil { await tinh() } }
    }

    // MARK: Ô nhập

    private var theNhap: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "arrow.triangle.branch", tieuDe: T("Bạn có thể trả thêm bao nhiêu?"))
            if beRong == .regular {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ONhapTien(nhan: T("Trả thêm mỗi tháng"), chu: $traThemChu)
                    ONhapTien(nhan: T("Có sẵn một khoản (trả một lần)"), chu: $motLanChu)
                }
            } else {
                ONhapTien(nhan: T("Trả thêm mỗi tháng"), chu: $traThemChu)
                ONhapTien(nhan: T("Có sẵn một khoản (trả một lần)"), chu: $motLanChu)
            }
            Button { Task { await tinh() } } label: {
                HStack {
                    if dangTinh { ProgressView().tint(.white) }
                    Text(daDoiSo ? T("Tính lại") : T("Tính"))
                }
                .font(.buttonSmall)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.primary)
                .foregroundStyle(Color.white)
                .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(.plain)
            .disabled(dangTinh)
            Text(T("Để trống = chỉ trả đúng lịch. Máy chủ mô phỏng từng tháng cho tới khi hết nợ, tính cả phí trả trước hạn đã khai."))
                .font(.caption2).foregroundStyle(AppColors.textTertiary)
        }
        .theTien()
    }

    private var daDoiSo: Bool {
        guard let d = daTinhVoi else { return false }
        return d.0 != traThem || d.1 != motLan
    }

    private func tinh() async {
        dangTinh = true
        defer { dangTinh = false }
        let a = traThem, b = motLan
        do {
            kq = try await TienAPI.chienLuocNo(traThem: a, motLan: b)
            daTinhVoi = (a, b)
            loi = nil
        } catch {
            if case APIError.unauthorized = error { return }
            loi = error.localizedDescription
        }
    }

    // MARK: So sánh bốn phương án

    private func theSoSanh(_ s: SoSanhChienLuoc) -> some View {
        let lich = s.theoLich
        let cot = beRong == .regular ? 2 : 1
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "list.number", tieuDe: T("So sánh cách trả"),
                           phu: (s.traThemMoiThang ?? 0) > 0
                           ? "\(T("trả thêm")) \(DinhDangTien.ngan(s.traThemMoiThang ?? 0))/\(T("tháng"))" : nil)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm, alignment: .top), count: cot),
                      spacing: Spacing.sm) {
                if let l = lich {
                    thePhuongAn(T("Theo lịch"), T("Chỉ trả đúng các kỳ, không trả thêm"), l, laLich: true, deXuat: false)
                }
                if let t = s.toiUu {
                    thePhuongAn(T("Rẻ nhất"), T("Thứ tự máy chủ tìm ra tốn ít tiền nhất (tính cả phí)"), t,
                                laLich: false, deXuat: s.deXuat == "TOI_UU")
                }
                if let a = s.avalanche {
                    thePhuongAn(T("Lãi cao trước"), T("Dồn tiền vào khoản lãi suất thực cao nhất"), a, laLich: false, deXuat: false)
                }
                if let b = s.snowball {
                    thePhuongAn(T("Dư nợ nhỏ trước"), T("Đóng khoản nhỏ nhất trước cho nhẹ đầu"), b, laLich: false, deXuat: false)
                }
            }
        }
        .theTien()
    }

    private func thePhuongAn(_ ten: String, _ moTa: String, _ p: PhuongAnTraNo, laLich: Bool, deXuat: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(ten).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                if deXuat {
                    Label(T("Đề xuất"), systemImage: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(AppColors.success.opacity(0.15))
                        .foregroundStyle(AppColors.success)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
            }
            Text(moTa).font(.caption2).foregroundStyle(AppColors.textTertiary)

            HStack(spacing: Spacing.sm) {
                oSo(T("Tổng lãi"), DinhDangTien.ngan(p.tongLai ?? 0), AppColors.error)
                oSo(T("Hết nợ"), HienThiPhanTich.thangGon(p.thangHetNo), AppColors.textPrimary,
                    phu: p.soThang.map { "\($0) \(T("tháng"))" })
                if laLich {
                    oSo(T("Tổng trả"), DinhDangTien.ngan(p.tongTra ?? 0), AppColors.textSecondary)
                } else {
                    oSo(T("Tiết kiệm"), DinhDangTien.ngan(p.tietKiemSoVoiLich ?? 0),
                        (p.tietKiemSoVoiLich ?? 0) > 0 ? AppColors.success : AppColors.textSecondary,
                        phu: (p.somHonThang ?? 0) > 0 ? "\(T("sớm")) \(p.somHonThang ?? 0) \(T("tháng"))" : nil)
                }
            }
            if let f = p.tongPhi, f > 0 {
                Text("\(T("Gồm phí trả trước hạn")) \(DinhDangTien.day(f))")
                    .font(.caption2).foregroundStyle(AppColors.accent)
            }
            if let tt = p.thuTu, !tt.isEmpty {
                ThuTuKhoanView(ds: tt)
            }
        }
        .padding(Spacing.sm + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(deXuat ? AppColors.success.opacity(0.06) : AppColors.backgroundTertiary.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .stroke(deXuat ? AppColors.success.opacity(0.5) : Color.clear, lineWidth: 1.2))
        .cornerRadius(CornerRadius.medium)
    }

    private func oSo(_ nhan: String, _ gt: String, _ mau: Color, phu: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nhan).font(.caption2).foregroundStyle(AppColors.textTertiary)
            Text(gt).font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(mau).lineLimit(1).minimumScaleFactor(0.6)
            if let phu { Text(phu).font(.caption2).foregroundStyle(AppColors.textTertiary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Trả một lần

    private func theMotLan(_ m: TraMotLanPT) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "banknote.fill",
                           tieuDe: "\(T("Dồn")) \(DinhDangTien.ngan(m.soTien ?? 0)) \(T("vào đâu?"))",
                           mau: AppColors.success)
            Text(T("Xếp theo số tiền lãi + phí tránh được nếu trả khoản đó ngay hôm nay."))
                .font(.caption2).foregroundStyle(AppColors.textTertiary)
            ForEach(Array((m.xepHang ?? []).enumerated()), id: \.offset) { i, x in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("\(i + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(width: 24, height: 24)
                        .background(i == 0 ? AppColors.success : AppColors.backgroundTertiary)
                        .foregroundStyle(i == 0 ? Color.white : AppColors.textSecondary)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(x.ten ?? "").font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                            if x.dongKhoanLuon == true {
                                Text(T("đóng luôn"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(AppColors.success.opacity(0.14))
                                    .foregroundStyle(AppColors.success)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(T("Dùng")) \(DinhDangTien.ngan(x.tienDungDuoc ?? 0)) · \(T("tất toán")) \(HienThiPhanTich.thangGon(x.thangTatToanCu)) → \(HienThiPhanTich.thangGon(x.thangTatToanMoi))")
                            .font(.caption2).foregroundStyle(AppColors.textTertiary)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(DinhDangTien.ngan(x.tietKiem ?? 0))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle((x.tietKiem ?? 0) > 0 ? AppColors.success : AppColors.textTertiary)
                        Text(T("tiết kiệm")).font(.caption2).foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .theTien()
    }

    private func canhBaoChuaKhaiPhi(_ ds: [String]) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(AppColors.accent)
            Text("\(T("Chưa khai phí trả trước hạn")): \(ds.joined(separator: ", ")). \(T("Đang tính phí = 0, nên số tiết kiệm thật có thể thấp hơn. Mở từng khoản để khai."))")
                .font(.caption).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.10))
        .cornerRadius(CornerRadius.medium)
    }

    private func theGiaDinh(_ g: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(T("Giả định"), systemImage: "info.circle").font(.captionBold).foregroundStyle(AppColors.textSecondary)
            ForEach(g, id: \.self) { Text("• \($0)").font(.caption2).foregroundStyle(AppColors.textTertiary) }
        }
        .theTien()
    }
}

/// Thứ tự ưu tiên dạng "1 A → 2 B → …", tự xuống dòng.
struct ThuTuKhoanView: View {
    let ds: [TenKhoanPT]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(T("Thứ tự dồn tiền")).font(.caption2).foregroundStyle(AppColors.textTertiary)
            ForEach(Array(ds.enumerated()), id: \.offset) { i, k in
                HStack(spacing: 6) {
                    Text("\(i + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .frame(width: 16, height: 16)
                        .background(AppColors.primary.opacity(0.15))
                        .foregroundStyle(AppColors.primary)
                        .clipShape(Circle())
                    Text(k.ten ?? "").font(.caption).foregroundStyle(AppColors.textPrimary).lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Lịch trả theo tháng

struct LichTraTheoThangView: View {
    let ds: [LichThangPT]
    @State private var xemHet = false

    var body: some View {
        let hien = xemHet ? ds : Array(ds.prefix(12))
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    TieuDeKhoiTien(bieuTuong: "chart.bar.fill", tieuDe: T("Gốc và lãi mỗi tháng"))
                    Chart {
                        ForEach(hien) { t in
                            BarMark(x: .value("Tháng", HienThiPhanTich.thangGon(t.thang)), y: .value("Tiền", t.goc ?? 0))
                                .foregroundStyle(by: .value("Loại", T("Gốc")))
                            BarMark(x: .value("Tháng", HienThiPhanTich.thangGon(t.thang)), y: .value("Tiền", t.lai ?? 0))
                                .foregroundStyle(by: .value("Loại", T("Lãi")))
                        }
                    }
                    .chartForegroundStyleScale([T("Gốc"): AppColors.primary.opacity(0.75), T("Lãi"): AppColors.error])
                    .chartYAxis {
                        AxisMarks(position: .leading) { v in
                            AxisGridLine()
                            AxisValueLabel { if let d = v.as(Double.self) { Text(DinhDangTien.ngan(d)).font(.caption2) } }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in AxisValueLabel().font(.system(size: 9)) }
                    }
                    .frame(height: 200)
                }
                .theTien()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 7) {
                        GridRow {
                            Text(T("Tháng")).gridColumnAlignment(.leading)
                            Text(T("Gốc")); Text(T("Lãi")); Text(T("Tổng"))
                        }
                        .font(.captionBold).foregroundStyle(AppColors.textTertiary)
                        Divider()
                        ForEach(hien) { t in
                            GridRow {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(HienThiPhanTich.thangGon(t.thang)).foregroundStyle(AppColors.textPrimary)
                                    Text("\(t.soKy ?? 0) \(T("kỳ"))").font(.caption2).foregroundStyle(AppColors.textTertiary)
                                }
                                Text(DinhDangTien.ngan(t.goc ?? 0)).foregroundStyle(AppColors.textSecondary)
                                Text(DinhDangTien.ngan(t.lai ?? 0)).foregroundStyle(AppColors.error)
                                Text(DinhDangTien.ngan(t.tong ?? 0)).fontWeight(.semibold).foregroundStyle(AppColors.textPrimary)
                            }
                            .font(.system(size: 13, design: .rounded))
                        }
                    }
                    if ds.count > 12 {
                        Button(xemHet ? T("Chỉ xem 12 tháng") : "\(T("Xem hết")) \(ds.count) \(T("tháng"))") {
                            xemHet.toggle()
                        }
                        .font(.caption)
                    }
                    Text(T("Chỉ gồm các kỳ CHƯA trả, quy ra VND. Tháng này đã trả rồi thì không tính lại ở đây."))
                        .font(.caption2).foregroundStyle(AppColors.textTertiary)
                }
                .theTien()
            }
            .padding(Spacing.md)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Lịch trả theo tháng"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Tất toán sớm

struct TatToanSomView: View {
    @ObservedObject var vm: TienVM
    let noId: Int
    let tenNo: String
    /// Gọi sau khi GHI tất toán thành công — màn chi tiết nạp lại.
    let daGhi: () -> Void
    @Environment(\.dismiss) private var dong

    @State private var ngay = NgayTien.homNay()
    @State private var kq: MoPhongTatToan?
    @State private var dangTai = false
    @State private var loi: String?
    @State private var viId: Int?
    @State private var hoiXacNhan = false
    @State private var dangGhi = false
    @State private var loiGhi: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ChonNgayTien(nhan: T("Ngày tất toán"), ngay: $ngay)
                } footer: {
                    Text(T("Đổi ngày để xem chi phí nếu tất toán vào ngày khác. Chỉ là mô phỏng — chưa ghi gì."))
                }

                if dangTai && kq == nil {
                    Section { HStack { Spacer(); ProgressView(); Spacer() } }
                } else if let l = loi {
                    Section { Text(l).font(.caption).foregroundStyle(AppColors.error) }
                } else if let k = kq {
                    ketQua(k)
                    ghiNhan(k)
                }
            }
            .navigationTitle(T("Tất toán sớm"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
            }
            .task(id: ngay) { await tai() }
            .alert(T("Ghi nhận đã tất toán?"), isPresented: $hoiXacNhan) {
                Button(T("Huỷ"), role: .cancel) {}
                Button(T("Ghi nhận")) { Task { await ghi() } }
            } message: {
                Text(xacNhanChu)
            }
        }
    }

    private var tienTe: String { kq?.tienTe ?? "VND" }

    private var xacNhanChu: String {
        // Máy chủ ghi đúng `chiPhiTatToan` (kỳ quá hạn phải tích riêng trước).
        let tien = DinhDangTien.day(kq?.chiPhiTatToan ?? 0, tienTe)
        let vi = vm.dsVi.first { $0.id == viId }?.name ?? T("không trừ ví nào")
        return "\(tenNo) · \(NgayTien.ngayDay(ngay))\n\(T("Ghi một lần trả")) \(tien) · \(T("ví")): \(vi).\n\(T("Mọi kỳ còn lại sẽ được đánh dấu đã trả và khoản nợ đóng lại."))"
    }

    @ViewBuilder
    private func ketQua(_ k: MoPhongTatToan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(T("Tổng cần chi")).font(.caption).foregroundStyle(AppColors.textSecondary)
                Text(DinhDangTien.day(k.tongCanChi ?? 0, tienTe))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                if let t = k.tietKiem {
                    Text("\(T("Tiết kiệm")) \(DinhDangTien.day(t, tienTe)) \(T("so với trả hết theo lịch"))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(t > 0 ? AppColors.success : AppColors.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }

        Section(T("Chi tiết")) {
            if let kd = k.kyDenHanPhaiTra, (kd.soKy ?? 0) > 0 {
                dongSo(T("Kỳ đã đến hạn phải trả"), "\(kd.soKy ?? 0) \(T("kỳ")) · \(DinhDangTien.day(kd.soTien ?? 0, tienTe))",
                     AppColors.error)
            }
            dongSo(T("Gốc tất toán"), DinhDangTien.day(k.gocTatToan ?? 0, tienTe))
            dongSo(T("Lãi kỳ đang chạy"),
                 DinhDangTien.day(k.laiDonKyDangChay ?? 0, tienTe)
                 + ((k.soNgayCuaKy ?? 0) > 0 ? " (\(k.soNgayDaQuaTrongKy ?? 0)/\(k.soNgayCuaKy ?? 0) \(T("ngày")))" : ""))
            if k.chuaKhaiPhi == true {
                dongSo(T("Phí trả trước hạn"), T("chưa khai — đang tính 0"), AppColors.accent)
            } else {
                dongSo(T("Phí trả trước hạn"), DinhDangTien.day(k.phiTraTruoc ?? 0, tienTe))
            }
            dongSo(T("Chi phí tất toán"), DinhDangTien.day(k.chiPhiTatToan ?? 0, tienTe), AppColors.textPrimary, dam: true)
        }

        // Tách Section thay vì Divider: Divider trong List thành một hàng trống.
        Section(T("So với trả theo lịch")) {
            dongSo(T("Nếu trả theo lịch"), DinhDangTien.day(k.neuTraTheoLich ?? 0, tienTe), AppColors.textSecondary)
            dongSo(T("Lãi tránh được"), DinhDangTien.day(k.laiTranhDuoc ?? 0, tienTe), AppColors.success)
            if let n = k.soKyBoQua, n > 0 {
                dongSo(T("Số kỳ không phải trả nữa"), "\(n) \(T("kỳ"))")
            }
        }

        if let g = k.giaDinh, !g.isEmpty {
            Section(T("Giả định")) {
                ForEach(g, id: \.self) { Text($0).font(.caption).foregroundStyle(AppColors.textSecondary) }
            }
        }
    }

    @ViewBuilder
    private func ghiNhan(_ k: MoPhongTatToan) -> some View {
        Section {
            Picker(T("Trừ tiền từ ví"), selection: $viId) {
                Text(T("Không trừ ví nào")).tag(Int?.none)
                ForEach(vm.dsVi) { v in
                    Text("\(v.bieuTuong) \(v.name) · \(DinhDangTien.ngan(v.balance, v.currency))").tag(Int?.some(v.id))
                }
            }
            Button {
                loiGhi = nil
                hoiXacNhan = true
            } label: {
                HStack {
                    Spacer()
                    if dangGhi { ProgressView() }
                    Text(T("Ghi nhận đã tất toán")).fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(dangGhi)
            if let l = loiGhi {
                Text(l).font(.caption).foregroundStyle(AppColors.error)
            }
        } header: {
            Text(T("Đã tất toán thật?"))
        } footer: {
            Text((k.kyDenHanPhaiTra?.soKy ?? 0) > 0
                 ? T("Còn kỳ quá hạn chưa tích — máy chủ sẽ từ chối. Tích các kỳ đó trước (ở lịch trả), rồi quay lại.")
                 : T("Chỉ bấm khi bạn ĐÃ trả xong cho bên cho vay. App ghi một lần trả bằng số tiền trên và đóng khoản nợ."))
        }
    }

    private func dongSo(_ nhan: String, _ gt: String, _ mau: Color = AppColors.textPrimary, dam: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(nhan).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
            Spacer(minLength: 8)
            Text(gt)
                .font(.system(size: 14, weight: dam ? .bold : .medium, design: .rounded))
                .foregroundStyle(mau)
                .multilineTextAlignment(.trailing)
        }
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        if viId == nil { viId = vm.viMacDinh?.id }
        do {
            kq = try await TienAPI.xemTatToan(noId: noId, ngay: ngay)
            loi = nil
        } catch {
            if case APIError.unauthorized = error { return }
            loi = error.localizedDescription
        }
    }

    private func ghi() async {
        dangGhi = true
        defer { dangGhi = false }
        do {
            _ = try await TienAPI.ghiTatToan(noId: noId, ngay: ngay, viId: viId, soTienThucTe: nil, ghiChu: nil)
            await vm.napNo()
            await vm.sauKhiGhiTien()
            daGhi()
            dong()
        } catch {
            loiGhi = error.localizedDescription
        }
    }
}

// MARK: - Sửa phí trả trước hạn

struct SuaPhiTraTruocView: View {
    let noId: Int
    let hienTai: Double?
    let xong: () -> Void
    @Environment(\.dismiss) private var dong
    @State private var chu = ""
    @State private var dangLuu = false
    @State private var loi: String?

    private var giaTri: Double? { Double(chu.replacingOccurrences(of: ",", with: ".")) }
    private var hopLe: Bool { chu.isEmpty || (giaTri.map { $0 >= 0 && $0 <= 100 } ?? false) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(T("Phí trả trước hạn"))
                        Spacer()
                        TextField(T("chưa khai"), text: $chu)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("%").foregroundStyle(AppColors.textTertiary)
                    }
                    if !hopLe {
                        Text(T("Nhập số từ 0 đến 100.")).font(.caption).foregroundStyle(AppColors.error)
                    }
                } footer: {
                    Text(T("% tính trên số gốc trả trước. Xem trong hợp đồng (ngân hàng thường 1–3%). Để trống = chưa biết — khác với 0% là chắc chắn không mất phí."))
                }
                if let l = loi { Section { Text(l).font(.caption).foregroundStyle(AppColors.error) } }
            }
            .navigationTitle(T("Phí trả trước hạn"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Lưu")) { Task { await luu() } }.disabled(!hopLe || dangLuu)
                }
            }
            .onAppear {
                if let h = hienTai {
                    chu = h == h.rounded() ? String(Int(h)) : String(h).replacingOccurrences(of: ".", with: ",")
                }
            }
        }
    }

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        do {
            _ = try await TienAPI.suaPhiTraTruoc(noId: noId, phanTram: chu.isEmpty ? nil : giaTri)
            xong()
            dong()
        } catch {
            loi = error.localizedDescription
        }
    }
}
