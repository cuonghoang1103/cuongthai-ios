import SwiftUI
import Charts

/// Màn "Phân tích" đầy đủ — đọc thẳng gói `/finance/phan-tich`.
///
/// Không có phép tính tiền nào ở đây: máy chủ chốt mọi con số (kể cả ròng,
/// dự báo, tỷ lệ), màn này chỉ xếp chúng ra cho dễ đọc. Độ dài thanh ngang
/// là phép chia ĐỂ VẼ, không phải số hiện ra cho người dùng.
struct PhanTichView: View {
    @ObservedObject var vm: TienVM
    @Environment(\.horizontalSizeClass) private var beRong

    var body: some View {
        ScrollView {
            if let p = vm.phanTich {
                noiDung(p)
                    .padding(Spacing.md)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
            } else if let l = vm.loiPhanTich {
                KhungTrongTien(bieuTuong: "exclamationmark.icloud", tieuDe: T("Chưa tải được phân tích"),
                               moTa: l, tenNut: T("Thử lại")) { Task { await vm.napPhanTich() } }
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Phân tích"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { if vm.phanTich == nil { await vm.napPhanTich() } }
        .refreshable { await vm.napPhanTich() }
    }

    @ViewBuilder
    private func noiDung(_ p: GoiPhanTich) -> some View {
        VStack(spacing: Spacing.md) {
            theTongQuan(p)
            if beRong == .regular {
                HStack(alignment: .top, spacing: Spacing.md) {
                    VStack(spacing: Spacing.md) {
                        theXuHuong(p)
                        theChiSo(p)
                        theThuTheoNguon(p)
                    }
                    VStack(spacing: Spacing.md) {
                        theChiTheoNhom(p)
                        theDauTu(p)
                        theTietKiem(p)
                    }
                }
            } else {
                theXuHuong(p)
                theChiTheoNhom(p)
                theChiSo(p)
                theDauTu(p)
                theThuTheoNguon(p)
                theTietKiem(p)
            }
            if let cb = p.canhBao, !cb.isEmpty {
                KhoiCanhBaoTien(vm: vm, ds: cb, toiDa: cb.count, tieuDe: "Tất cả cảnh báo", choXemHet: false)
            }
            if let t = p.thieuDuLieu, !t.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label(T("Thiếu dữ liệu"), systemImage: "questionmark.circle")
                        .font(.captionBold).foregroundStyle(AppColors.accent)
                    ForEach(t, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(AppColors.textSecondary) }
                }
                .theTien()
            }
            if let h = p.homNay {
                Text("\(T("Số liệu tính tới")) \(NgayTien.ngayDay(h)) · \(T("giờ Việt Nam"))")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    // MARK: Tổng quan

    private func theTongQuan(_ p: GoiPhanTich) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "heart.text.square.fill", tieuDe: T("Sức khoẻ tài chính"),
                           phu: p.thang.map { NgayTien.tenThang($0) })
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm, alignment: .top),
                                     count: beRong == .regular ? 3 : 2),
                      alignment: .leading, spacing: Spacing.sm) {
                CacChiSoSucKhoe(p: p)
            }
            if let q = p.quyKhanCap, let cs = q.coSo {
                Text("\(T("Quỹ khẩn cấp")) = \(T("tiền trong ví")) \(DinhDangTien.day(q.tienMat ?? 0)) ÷ \(DinhDangTien.day(q.chiMoiThang ?? 0))/\(T("tháng")) (\(cs)).")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .theTien()
    }

    // MARK: Xu hướng 6 tháng

    private func theXuHuong(_ p: GoiPhanTich) -> some View {
        let ds = p.dongTien?.xuHuong ?? []
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "chart.bar.xaxis", tieuDe: T("Dòng tiền 6 tháng"))
            if ds.isEmpty {
                Text(T("Chưa có dữ liệu.")).font(.caption).foregroundStyle(AppColors.textTertiary)
            } else {
                Chart {
                    ForEach(ds) { t in
                        BarMark(x: .value("Tháng", nhanThang(t.thang)), y: .value("Tiền", t.thu ?? 0))
                            .foregroundStyle(by: .value("Loại", T("Thu")))
                            .position(by: .value("Loại", T("Thu")))
                        BarMark(x: .value("Tháng", nhanThang(t.thang)), y: .value("Tiền", t.chi ?? 0))
                            .foregroundStyle(by: .value("Loại", T("Chi")))
                            .position(by: .value("Loại", T("Chi")))
                        BarMark(x: .value("Tháng", nhanThang(t.thang)), y: .value("Tiền", t.traNo ?? 0))
                            .foregroundStyle(by: .value("Loại", T("Trả nợ")))
                            .position(by: .value("Loại", T("Trả nợ")))
                    }
                    ForEach(ds) { t in
                        LineMark(x: .value("Tháng", nhanThang(t.thang)), y: .value("Tiền", t.rong ?? 0))
                            .foregroundStyle(by: .value("Loại", T("Ròng")))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Tháng", nhanThang(t.thang)), y: .value("Tiền", t.rong ?? 0))
                            .foregroundStyle(by: .value("Loại", T("Ròng")))
                            .symbolSize(30)
                    }
                    RuleMark(y: .value("0", 0)).foregroundStyle(AppColors.divider)
                }
                .chartForegroundStyleScale([
                    T("Thu"): AppColors.success,
                    T("Chi"): AppColors.error,
                    T("Trả nợ"): AppColors.accent,
                    T("Ròng"): AppColors.primary,
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { v in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = v.as(Double.self) { Text(DinhDangTien.ngan(d)).font(.caption2) }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 230)

                // Bảng số — biểu đồ cho thấy hình dạng, bảng cho con số chính xác.
                Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        Text(T("Tháng")).gridColumnAlignment(.leading)
                        Text(T("Thu")); Text(T("Chi")); Text(T("Trả nợ")); Text(T("Ròng"))
                    }
                    .font(.captionBold).foregroundStyle(AppColors.textTertiary)
                    Divider()
                    ForEach(ds.reversed()) { t in
                        GridRow {
                            Text(HienThiPhanTich.thangGon(t.thang)).foregroundStyle(AppColors.textSecondary)
                            Text(DinhDangTien.ngan(t.thu ?? 0)).foregroundStyle(AppColors.success)
                            Text(DinhDangTien.ngan(t.chi ?? 0)).foregroundStyle(AppColors.error)
                            Text(DinhDangTien.ngan(t.traNo ?? 0)).foregroundStyle(AppColors.accent)
                            Text(DinhDangTien.ngan(t.rong ?? 0))
                                .fontWeight(.semibold)
                                .foregroundStyle((t.rong ?? 0) >= 0 ? AppColors.textPrimary : AppColors.error)
                        }
                        .font(.system(size: 12, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                Text(T("Ròng = thu − chi − trả nợ (máy chủ tính)."))
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
        }
        .theTien()
    }

    private func nhanThang(_ s: String?) -> String {
        guard let s else { return "?" }
        let p = s.split(separator: "-")
        guard p.count >= 2, let m = Int(p[1]) else { return s }
        return "T\(m)"
    }

    // MARK: Chi theo nhóm

    private func theChiTheoNhom(_ p: GoiPhanTich) -> some View {
        let c = p.chiTieu
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "cart.fill", tieuDe: T("Chi theo nhóm"), mau: AppColors.error)
            HStack(spacing: Spacing.sm) {
                oNho(T("Tháng này"), DinhDangTien.ngan(c?.thangNay ?? 0), AppColors.textPrimary)
                oNho(T("Cùng kỳ tháng trước"), DinhDangTien.ngan(c?.cungKyThangTruoc ?? 0), AppColors.textSecondary)
                oNho(T("So cùng kỳ"), HienThiPhanTich.phanTramCoDau(c?.soVoiCungKyPct),
                     mauChenh(c?.soVoiCungKyPct))
            }
            HStack(spacing: Spacing.sm) {
                oNho(T("Cả tháng trước"), DinhDangTien.ngan(c?.thangTruoc ?? 0), AppColors.textSecondary)
                oNho(T("Dự báo cả tháng"), DinhDangTien.ngan(c?.duBaoCuoiThang ?? 0),
                     MauTien.theoMa(p.canhBao, "du_bao_am") ?? AppColors.textPrimary)
                Spacer().frame(maxWidth: .infinity)
            }
            Divider()
            if let ds = c?.nhom, !ds.isEmpty {
                ForEach(ds) { n in dongNhom(n) }
            } else {
                Text(T("Tháng này chưa có khoản chi nào.")).font(.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
        .theTien()
    }

    private func dongNhom(_ n: NhomChiPT) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(n.icon ?? "🏷️") \(n.ten ?? T("Chưa phân nhóm"))")
                    .font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                Spacer(minLength: 4)
                Text(DinhDangTien.day(n.thangNay ?? 0))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
            HStack(spacing: 6) {
                Text("\(T("Tháng trước")) \(DinhDangTien.ngan(n.thangTruoc ?? 0))")
                if let t = n.tiTrong { Text("· \(HienThiPhanTich.phanTram(t)) \(T("tổng chi"))") }
                Spacer(minLength: 0)
                if let ch = n.chenhCungKyPct {
                    Text("\(HienThiPhanTich.phanTramCoDau(ch)) \(T("cùng kỳ"))")
                        .fontWeight(.semibold)
                        .foregroundStyle(mauChenh(ch))
                } else if (n.cungKyThangTruoc ?? 0) == 0, (n.thangNay ?? 0) > 0 {
                    Text(T("mới tháng này")).foregroundStyle(AppColors.textTertiary)
                }
            }
            .font(.caption2).foregroundStyle(AppColors.textTertiary)
            if let ns = n.nganSach, let tl = n.tiLeNganSach {
                ThanhTienDoTien(tiLe: tl / 100, mau: mauNganSach(tl), cao: 6)
                Text("\(HienThiPhanTich.phanTram(tl)) \(T("ngân sách")) \(DinhDangTien.ngan(ns))")
                    .font(.caption2).foregroundStyle(mauNganSach(tl))
            }
        }
        .padding(.vertical, 3)
    }

    private func mauChenh(_ v: Double?) -> Color {
        guard let v else { return AppColors.textSecondary }
        if v > 0 { return AppColors.accent }
        if v < 0 { return AppColors.success }
        return AppColors.textSecondary
    }

    private func mauNganSach(_ tl: Double) -> Color {
        if tl > 100 { return AppColors.error }
        if tl >= 80 { return AppColors.accent }
        return AppColors.success
    }

    // MARK: Chỉ số

    private func theChiSo(_ p: GoiPhanTich) -> some View {
        let c = p.chiSo
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "gauge.with.dots.needle.50percent", tieuDe: T("Bình quân & tỷ lệ"),
                           phu: c?.soThangLamBinhQuan.map { "\($0) \(T("tháng gần nhất"))" })
            dongSo(T("Thu bình quân / tháng"), DinhDangTien.day(c?.thuBinhQuan3Thang ?? 0), AppColors.success)
            dongSo(T("Chi bình quân / tháng"), DinhDangTien.day(c?.chiBinhQuan3Thang ?? 0), AppColors.error)
            dongSo(T("Trả nợ bình quân / tháng"), DinhDangTien.day(c?.traNoBinhQuan3Thang ?? 0), AppColors.accent)
            Divider()
            dongSo(T("Trả nợ / thu nhập"), HienThiPhanTich.phanTram(c?.tyLeNoTrenThu),
                   MauTien.theoMa(p.canhBao, "dti") ?? AppColors.textPrimary)
            dongSo(T("Chi / thu tháng này"), HienThiPhanTich.phanTram(c?.tyLeChiTrenThuThangNay), AppColors.textPrimary)
            dongSo(T("Tỷ lệ để dành tháng trước"), HienThiPhanTich.phanTram(c?.tyLeTietKiemThangTruoc),
                   (c?.tyLeTietKiemThangTruoc ?? 0) >= 0 ? AppColors.success : AppColors.error)
        }
        .theTien()
    }

    // MARK: Đầu tư

    private func theDauTu(_ p: GoiPhanTich) -> some View {
        let t = p.dauTu?.tong
        let ds = p.dauTu?.cacKhoan ?? []
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "chart.pie.fill", tieuDe: T("Đầu tư"), mau: AppColors.secondary,
                           phu: T("quy ra VND"))
            if ds.isEmpty {
                Text(T("Chưa có khoản đầu tư nào.")).font(.caption).foregroundStyle(AppColors.textTertiary)
            } else {
                HStack(spacing: Spacing.sm) {
                    oNho(T("Vốn đang giữ"), DinhDangTien.ngan(t?.vonDangGiu ?? 0), AppColors.textPrimary)
                    oNho(T("Giá trị hiện tại"), DinhDangTien.ngan(t?.giaTriDangGiu ?? 0), AppColors.textPrimary)
                    oNho(T("Lãi/lỗ tạm tính"),
                         "\(DinhDangTien.ngan(t?.laiLoTamTinh ?? 0)) (\(HienThiPhanTich.phanTramCoDau(t?.tySuatTamTinh)))",
                         mauLaiLo(t?.laiLoTamTinh))
                }
                if let c = t?.laiLoDaChot, c != 0 {
                    Text("\(T("Lãi/lỗ đã chốt")): \(DinhDangTien.day(c))")
                        .font(.caption).foregroundStyle(mauLaiLo(c))
                }
                Divider()
                ForEach(Array(ds.enumerated()), id: \.offset) { _, k in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(k.ten ?? "").font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                                if k.daChot == true { nhan(T("Đã chốt"), AppColors.textTertiary) }
                                if k.loai == "SELF" { nhan(T("Bản thân"), AppColors.secondary) }
                                if k.tienTe == "USD" { nhan("USD", AppColors.textTertiary) }
                            }
                            Text("\(T("Vốn")) \(DinhDangTien.ngan(k.von ?? 0))" + (k.giaTri.map { " → \(DinhDangTien.ngan($0))" } ?? ""))
                                .font(.caption2).foregroundStyle(AppColors.textTertiary)
                            if k.chuaCapNhatGia == true {
                                Text(T("Chưa cập nhật giá gần đây")).font(.caption2).foregroundStyle(AppColors.accent)
                            }
                        }
                        Spacer(minLength: 4)
                        if let l = k.laiLo {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(DinhDangTien.ngan(l))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(mauLaiLo(l))
                                Text(HienThiPhanTich.phanTramCoDau(k.tySuat))
                                    .font(.caption2).foregroundStyle(mauLaiLo(l))
                            }
                        } else {
                            Text("—").font(.caption).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
            }
        }
        .theTien()
    }

    private func mauLaiLo(_ v: Double?) -> Color {
        guard let v else { return AppColors.textSecondary }
        return v > 0 ? AppColors.success : (v < 0 ? AppColors.error : AppColors.textSecondary)
    }

    // MARK: Thu theo nguồn

    private func theThuTheoNguon(_ p: GoiPhanTich) -> some View {
        let ds = p.thuTheoNguon ?? []
        let lonNhat = max(1, ds.compactMap { $0.tong }.max() ?? 1)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "briefcase.fill", tieuDe: T("Thu theo nguồn"), mau: AppColors.success,
                           phu: T("3 tháng gần nhất"))
            if ds.isEmpty {
                Text(T("Chưa có khoản thu nào.")).font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            ForEach(ds) { n in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(n.ten ?? tenLoaiThu(n.loai)).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(DinhDangTien.day(n.tong ?? 0))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    ThanhTienDoTien(tiLe: (n.tong ?? 0) / lonNhat, mau: AppColors.success.opacity(0.8), cao: 5)
                }
            }
        }
        .theTien()
    }

    private func tenLoaiThu(_ m: String?) -> String {
        KhoanThu.tenLoai.first { $0.0 == m }.map { T($0.1) } ?? (m ?? "")
    }

    // MARK: Sổ tiết kiệm

    private func theTietKiem(_ p: GoiPhanTich) -> some View {
        let ds = p.soTietKiem ?? []
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TieuDeKhoiTien(bieuTuong: "lock.shield.fill", tieuDe: T("Sổ tiết kiệm"), mau: AppColors.secondary)
            if ds.isEmpty {
                Text(T("Chưa có sổ tiết kiệm đang gửi.")).font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            ForEach(Array(ds.enumerated()), id: \.offset) { _, s in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.nganHang ?? "").font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                        Text("\(HienThiPhanTich.phanTram(s.laiSuatNam, soLe: 2))/\(T("năm")) · \(s.kyHanThang ?? 0) \(T("tháng"))")
                            .font(.caption2).foregroundStyle(AppColors.textTertiary)
                        if let d = s.ngayDaoHan {
                            Text("\(T("Đáo hạn")) \(NgayTien.ngayDay(d))" + (s.conNgay.map { " · \(T("còn")) \($0) \(T("ngày"))" } ?? ""))
                                .font(.caption2).foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(DinhDangTien.day(s.soTien ?? 0, s.tienTe ?? "VND"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        if let l = s.laiKhiDaoHan {
                            Text("+\(DinhDangTien.day(l, s.tienTe ?? "VND")) \(T("lãi"))")
                                .font(.caption2).foregroundStyle(AppColors.success)
                        }
                    }
                }
            }
        }
        .theTien()
    }

    // MARK: Tiện

    private func oNho(_ nhan: String, _ gt: String, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nhan).font(.caption2).foregroundStyle(AppColors.textTertiary).lineLimit(2)
            Text(gt).font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(mau).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dongSo(_ nhan: String, _ gt: String, _ mau: Color) -> some View {
        HStack {
            Text(nhan).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(gt).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(mau)
        }
    }

    private func nhan(_ chu: String, _ mau: Color) -> some View {
        Text(chu).font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(mau.opacity(0.14)).foregroundStyle(mau)
            .clipShape(Capsule())
    }
}
