import SwiftUI

// MARK: - Màu theo mức cảnh báo
//
// Đỏ = nguy / quá hạn · cam = cảnh báo · xanh ngọc = tin. Cam lấy `accent`
// chứ không lấy `warning`: `warning` ở chế độ tối là VÀNG (#FAD129), đặt cạnh
// đỏ thì người ta đọc thành "ổn", sai với ý "cần để mắt".
enum MauTien {
    static func muc(_ m: String?) -> Color {
        switch m {
        case "nguy": return AppColors.error
        case "canh": return AppColors.accent
        default: return AppColors.secondary
        }
    }

    static func bieuTuong(_ m: String?) -> String {
        switch m {
        case "nguy": return "exclamationmark.octagon.fill"
        case "canh": return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }

    /// Mức nặng nhất trong danh sách — để tô biểu tượng ở đầu khối.
    static func nangNhat(_ ds: [CanhBaoTien]) -> String? {
        if ds.contains(where: { $0.muc == "nguy" }) { return "nguy" }
        if ds.contains(where: { $0.muc == "canh" }) { return "canh" }
        return ds.isEmpty ? nil : "tin"
    }

    /// Máy chủ có phát cảnh báo mã `ma` không, và ở mức nào. Dùng để TÔ MÀU
    /// chỉ số theo đúng ngưỡng của máy chủ, thay vì app tự đặt ngưỡng thứ hai.
    static func theoMa(_ ds: [CanhBaoTien]?, _ ma: String) -> Color? {
        guard let c = ds?.first(where: { $0.ma == ma }) else { return nil }
        return muc(c.muc)
    }
}

// MARK: - Khung thẻ dùng chung

extension View {
    func theTien() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .cornerRadius(CornerRadius.large)
    }
}

struct TieuDeKhoiTien: View {
    let bieuTuong: String
    let tieuDe: String
    var mau: Color = AppColors.primary
    var phu: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: bieuTuong).foregroundStyle(mau)
            Text(tieuDe).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            Spacer(minLength: 0)
            if let phu {
                Text(phu).font(.caption).foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

/// Một ô chỉ số: nhãn nhỏ, giá trị to, dòng phụ.
struct OChiSoTien: View {
    let nhan: String
    let giaTri: String
    var mau: Color = AppColors.textPrimary
    var phu: String?
    var bieuTuong: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let b = bieuTuong {
                    Image(systemName: b).font(.caption2).foregroundStyle(mau)
                }
                Text(nhan).font(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(2)
            }
            Text(giaTri)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(mau)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let p = phu {
                Text(p).font(.caption2).foregroundStyle(AppColors.textTertiary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(Spacing.sm + 2)
        .background(AppColors.backgroundTertiary.opacity(0.6))
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Khối cảnh báo

struct KhoiCanhBaoTien: View {
    @ObservedObject var vm: TienVM
    let ds: [CanhBaoTien]
    var toiDa: Int = 5
    var tieuDe: String = "Cảnh báo"
    /// `false` khi đang ở CHÍNH màn phân tích — không tự mở lại chính nó.
    var choXemHet = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(MauTien.muc(MauTien.nangNhat(ds)))
                Text(T(tieuDe)).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                Text("\(ds.count)")
                    .font(.captionBold)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(MauTien.muc(MauTien.nangNhat(ds)).opacity(0.15))
                    .foregroundStyle(MauTien.muc(MauTien.nangNhat(ds)))
                    .clipShape(Capsule())
                Spacer(minLength: 0)
                if choXemHet, ds.count > toiDa {
                    NavigationLink { PhanTichView(vm: vm) } label: {
                        Text(T("Xem hết")).font(.caption).foregroundStyle(AppColors.primary)
                    }
                }
            }
            ForEach(Array(ds.prefix(toiDa))) { c in DongCanhBaoTien(vm: vm, c: c) }
        }
        .theTien()
    }
}

struct DongCanhBaoTien: View {
    @ObservedObject var vm: TienVM
    let c: CanhBaoTien

    var body: some View {
        if let d = DichLienKetTien.dich(c.lienKet) {
            NavigationLink { ManLienKetTien(vm: vm, dich: d) } label: { noiDung(coMuiTen: true) }
                .buttonStyle(.plain)
        } else {
            noiDung(coMuiTen: false)
        }
    }

    private func noiDung(coMuiTen: Bool) -> some View {
        let mau = MauTien.muc(c.muc)
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: MauTien.bieuTuong(c.muc))
                .font(.system(size: 15))
                .foregroundStyle(mau)
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.tieuDe ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let ct = c.chiTiet, !ct.isEmpty {
                    Text(ct).font(.caption).foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if coMuiTen {
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
                    .padding(.top, 3)
            }
        }
        .padding(Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mau.opacity(0.08))
        .overlay(alignment: .leading) {
            Rectangle().fill(mau).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .contentShape(Rectangle())
    }
}

/// Mở đúng màn mà `canhBao[].lienKet` trỏ tới.
struct ManLienKetTien: View {
    @ObservedObject var vm: TienVM
    let dich: DichLienKetTien

    var body: some View {
        switch dich {
        case .no(let id): ChiTietNoView(vm: vm, noId: id)
        case .dsNo: NoView(vm: vm)
        case .chiTieu: ChiTieuView(vm: vm)
        case .thuNhap: ThuNhapView(vm: vm)
        case .tietKiem: TietKiemView(vm: vm)
        case .dauTu: DauTuView(vm: vm)
        }
    }
}

// MARK: - Khối sức khoẻ tài chính

struct KhoiSucKhoeTaiChinh: View {
    @ObservedObject var vm: TienVM
    let p: GoiPhanTich
    /// Ép số cột (vd. 2 khi thẻ chỉ chiếm nửa màn iPad). `nil` = theo cỡ màn.
    var soCot: Int?
    @Environment(\.horizontalSizeClass) private var beRong

    var body: some View {
        NavigationLink { PhanTichView(vm: vm) } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square.fill").foregroundStyle(AppColors.primary)
                    Text(T("Sức khoẻ tài chính")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                    Text(T("Phân tích")).font(.caption).foregroundStyle(AppColors.primary)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(AppColors.textTertiary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm, alignment: .top),
                                         count: soCot ?? (beRong == .regular ? 3 : 2)),
                          alignment: .leading, spacing: Spacing.sm) {
                    CacChiSoSucKhoe(p: p)
                }
                if p.coUsdChuaQuyDoi == true {
                    Text(T("Có khoản USD chưa quy đổi được nên chưa cộng vào các chỉ số — cần tỷ giá."))
                        .font(.caption2).foregroundStyle(AppColors.accent)
                }
            }
            .theTien()
        }
        .buttonStyle(.plain)
    }
}

/// Sáu ô chỉ số — dùng chung cho thẻ ở màn chính và đầu màn Phân tích.
struct CacChiSoSucKhoe: View {
    let p: GoiPhanTich

    var body: some View {
        let cb = p.canhBao
        let rong = p.dongTien?.thangNay?.rong
        OChiSoTien(nhan: T("Dòng tiền ròng tháng này"),
                   giaTri: rong.map { DinhDangTien.ngan($0) } ?? "—",
                   mau: (rong ?? 0) >= 0 ? AppColors.success : AppColors.error,
                   phu: T("Thu − chi − trả nợ"),
                   bieuTuong: "arrow.left.arrow.right")

        OChiSoTien(nhan: T("Trả nợ / thu nhập"),
                   giaTri: HienThiPhanTich.phanTram(p.chiSo?.tyLeNoTrenThu),
                   mau: MauTien.theoMa(cb, "dti") ?? AppColors.success,
                   phu: T("Ngân hàng coi trên 35–40% là cao"),
                   bieuTuong: "percent")

        OChiSoTien(nhan: T("Quỹ khẩn cấp"),
                   giaTri: p.quyKhanCap?.soThang.map { "\(HienThiPhanTich.soThang($0)) \(T("tháng"))" } ?? "—",
                   mau: MauTien.theoMa(cb, "quy_khan_cap") ?? AppColors.success,
                   phu: p.quyKhanCap?.soThangKeCaTietKiem.map {
                       "\(T("Kể cả tiết kiệm")): \(HienThiPhanTich.soThang($0)) \(T("tháng")) · \(T("nên 3–6"))"
                   } ?? T("Nên có 3–6 tháng"),
                   bieuTuong: "lifepreserver")

        OChiSoTien(nhan: T("Chi so với cùng kỳ tháng trước"),
                   giaTri: HienThiPhanTich.phanTramCoDau(p.chiTieu?.soVoiCungKyPct),
                   mau: MauTien.theoMa(cb, "chi_tang")
                       ?? ((p.chiTieu?.soVoiCungKyPct ?? 0) <= 0 ? AppColors.success : AppColors.textPrimary),
                   phu: "\(T("Tháng này")) \(DinhDangTien.ngan(p.chiTieu?.thangNay ?? 0)) · \(T("cùng kỳ")) \(DinhDangTien.ngan(p.chiTieu?.cungKyThangTruoc ?? 0))",
                   bieuTuong: "chart.line.uptrend.xyaxis")

        OChiSoTien(nhan: T("Dự báo chi cả tháng"),
                   giaTri: p.chiTieu?.duBaoCuoiThang.map { DinhDangTien.ngan($0) } ?? "—",
                   mau: MauTien.theoMa(cb, "du_bao_am") ?? AppColors.textPrimary,
                   phu: p.chiTieu?.ngayTrongThang.map { n in
                       "\(T("Theo nhịp")) \(n)/\(p.chiTieu?.soNgayThang ?? 30) \(T("ngày đầu"))"
                   },
                   bieuTuong: "calendar.badge.clock")

        OChiSoTien(nhan: T("Nợ phải trả tháng này"),
                   giaTri: p.no?.thangNay?.tongNghiaVu.map { DinhDangTien.ngan($0) } ?? "—",
                   mau: (p.no?.quaHan?.isEmpty == false) ? AppColors.error : AppColors.textPrimary,
                   phu: "\(T("Còn")) \(DinhDangTien.ngan(p.no?.thangNay?.conPhaiTra ?? 0)) · \(T("đã trả")) \(DinhDangTien.ngan(p.no?.thangNay?.daTra ?? 0))",
                   bieuTuong: "calendar")
    }
}
