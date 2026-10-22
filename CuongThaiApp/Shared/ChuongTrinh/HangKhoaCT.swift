import SwiftUI
#if canImport(Kingfisher)
import Kingfisher
#endif

// ════════════════════════════════════════════════════════════════
// Mảnh giao diện của Chương trình đào tạo — giọng "danh mục môn học của một
// trường": giấy ấm, mực xanh đen, một màu nhấn đỏ sẫm, kẻ mảnh, chữ có chân cho
// tiêu đề, số dạng bảng. Không gradient tím-hồng, không emoji, không lấp lánh.
// Cùng bảng màu với web (`chuongTrinh.module.css`: ink-navy + oxblood).
// ════════════════════════════════════════════════════════════════

/// Bảng màu RIÊNG của màn chương trình (web cũng khoanh bảng màu trong lớp `.goc`).
/// Nền/chữ/kẻ lấy thẳng token của `Theme`; chỉ màu nhấn + nền ảnh dự phòng là riêng.
enum MauCT {
    static let giay = AppColors.backgroundPrimary
    static let giay2 = AppColors.backgroundTertiary
    static let the = AppColors.backgroundCard
    static let muc = AppColors.textPrimary
    static let muc2 = AppColors.textSecondary
    static let muc3 = AppColors.textTertiary
    static let ke = AppColors.divider
    static let keDam = AppColors.textPrimary
    /// Đỏ sẫm (oxblood) — ≥ 7:1 trên giấy sáng, ≥ 7:1 trên nền tối.
    static let nhan = Color.theoCheDo(sang: Color(hex: 0x8C2F24), toi: Color(hex: 0xE8957F))
    static let nhanNhat = Color.theoCheDo(sang: Color(hex: 0x8C2F24).opacity(0.07), toi: Color(hex: 0xE8957F).opacity(0.10))
    /// Ô mực khi khoá không có ảnh bìa / ảnh hỏng.
    static let nenAnh = Color.theoCheDo(sang: Color(hex: 0x1F2A3D), toi: Color(hex: 0x252D3E))
    static let chuTrenNenAnh = Color(hex: 0xF3F0E8)
}

enum ChuCTFont {
    /// Tiêu đề có chân, co giãn theo Dynamic Type.
    static func serif(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

// MARK: - Ảnh bìa

/// Ảnh bìa 16:9. Không có ảnh / ảnh hỏng ⇒ ô mực mang mã môn hoặc vế đầu của tên (như web) —
/// không dùng ảnh minh hoạ chung chung.
struct AnhBiaCT: View {
    let url: String?
    let chuDuPhong: String
    var coChu: CGFloat = 13

    @State private var hong = false
    @Environment(\.displayScale) private var tiLe

    var body: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(MauCT.nenAnh)
            .overlay {
                if let u = url.flatMap(URL.init(string:)), !hong {
                    anh(u)
                } else {
                    Text(chuDuPhong)
                        .font(.system(size: coChu, weight: .regular, design: .serif))
                        .foregroundColor(MauCT.chuTrenNenAnh)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(6)
                }
            }
            .clipped()
            .overlay(Rectangle().stroke(MauCT.ke, lineWidth: 0.5))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func anh(_ u: URL) -> some View {
        #if canImport(Kingfisher)
        KFImage(u)
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 480, height: 270)))
            .scaleFactor(tiLe)
            .cacheOriginalImage(false)
            .onFailure { _ in hong = true }
            .fade(duration: 0.18)
            .resizable()
            .scaledToFill()
        #else
        AsyncImage(url: u) { pha in
            if let img = pha.image { img.resizable().scaledToFill() }
        }
        #endif
    }

    static func chuCho(_ m: MonChuongTrinh, ten: String) -> String {
        if let ma = m.courseCode, !ma.isEmpty { return ma }
        let dau = ten.split(whereSeparator: { ":—(".contains($0) }).first.map(String.init) ?? ten
        return dau.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Nhãn + tiến độ

/// "Sắp ra mắt" — chữ + viền mảnh màu nhấn, không nền rực.
struct NhanSapRaMat: View {
    var body: some View {
        Text(T("Sắp ra mắt"))
            .font(.caption2.weight(.semibold))
            .foregroundColor(MauCT.nhan)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .overlay(Rectangle().stroke(MauCT.nhan, lineWidth: 1))
            .fixedSize()
    }
}

struct TienDoCT: View {
    let phanTram: Int
    var coChu = true
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if coChu {
                Text(phanTram >= 100 ? ChuCT.tienDo(100, nn.ngonNgu == .anh)
                     : "\(T("Tiếp tục")) · \(phanTram)%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(MauCT.nhan)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(MauCT.ke)
                    Rectangle().fill(MauCT.nhan)
                        .frame(width: g.size.width * CGFloat(max(2, min(100, phanTram))) / 100)
                }
            }
            .frame(height: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ChuCT.tienDo(phanTram, nn.ngonNgu == .anh))
    }
}

/// Dòng thông số "Cơ bản / 24 bài / 3,2 giờ / Frontend" — tự xuống dòng.
struct MetaKhoaCT: View {
    let m: MonChuongTrinh
    var hienKy = false
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var phan: [String] {
        let anh = nn.ngonNgu == .anh
        if m.laSapRaMat {
            return [CapDoCT.nhan(m.level),
                    (m.soBaiDuKien ?? 0) > 0 ? ChuCT.khung(m.soChuongDuKien ?? 0, m.soBaiDuKien ?? 0, anh) : nil,
                    m.categoryName].compactMap { $0 }
        }
        return [hienKy ? m.loTrinhKy.map { ChuCT.ky($0, anh) } : nil,
                CapDoCT.nhan(m.level),
                m.soBai > 0 ? ChuCT.bai(m.soBai, anh) : nil,
                ChuCT.gio(m.soGiay, anh).nilNeuRong,
                m.categoryName].compactMap { $0 }
    }

    var body: some View {
        FlowRow(spacing: 0) {
            ForEach(Array(phan.enumerated()), id: \.offset) { i, x in
                HStack(spacing: 0) {
                    Text(x)
                    if i < phan.count - 1 {
                        Text("  /  ").foregroundColor(MauCT.muc3.opacity(0.55))
                    }
                }
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundColor(MauCT.muc3)
    }
}

extension String {
    var nilNeuRong: String? { isEmpty ? nil : self }
}

// MARK: - Một hàng khoá (kiểu bảng môn học)

/// Số thứ tự · ảnh · tên + mô tả + thông số · tiến độ/nhãn. `soThuTu` chỉ hiện ở màn rộng (web cũng ẩn trên điện thoại).
struct HangKhoaCT: View {
    let m: MonChuongTrinh
    var soThuTu: Int? = nil
    var hienKy = false
    var rong = false

    @ObservedObject private var nn = QuanLyNgonNguApp.shared
    @Environment(\.dynamicTypeSize) private var coChu

    var body: some View {
        let anh = nn.ngonNgu == .anh
        let ten = m.ten(anh)
        Group {
            if coChu.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    AnhBiaCT(url: m.thumbnailUrl, chuDuPhong: AnhBiaCT.chuCho(m, ten: ten))
                    noiDung(ten, anh)
                }
            } else {
                HStack(alignment: .top, spacing: rong ? 20 : 14) {
                    if rong {
                        Text(soThuTu.map(String.init) ?? "")
                            .font(ChuCTFont.serif(.title3))
                            .monospacedDigit()
                            .foregroundColor(MauCT.muc3)
                            .frame(width: 22, alignment: .leading)
                            .padding(.top, 1)
                    }
                    AnhBiaCT(url: m.thumbnailUrl, chuDuPhong: AnhBiaCT.chuCho(m, ten: ten), coChu: rong ? 14 : 11)
                        .frame(width: rong ? 148 : 104)
                    noiDung(ten, anh)
                    if rong { cotPhai.frame(width: 128, alignment: .trailing) }
                }
            }
        }
        .padding(.vertical, rong ? 18 : 14)
        .padding(.horizontal, rong ? 8 : 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nhanDoc(ten, anh))
        .accessibilityHint(m.laSapRaMat ? T("Xem mục lục dự kiến") : T("Mở khoá học"))
    }

    private func noiDung(_ ten: String, _ anh: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let ma = m.courseCode, !ma.isEmpty {
                Text(ma)
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundColor(MauCT.muc3)
            }
            Text(ten)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(MauCT.muc)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if rong, let mt = m.moTa(anh) {
                Text(mt)
                    .font(.footnote)
                    .foregroundColor(MauCT.muc2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MetaKhoaCT(m: m, hienKy: hienKy)
            if !rong {
                if m.laSapRaMat {
                    NhanSapRaMat().padding(.top, 3)
                } else if let p = m.progress, m.daGhiDanh {
                    TienDoCT(phanTram: p).frame(maxWidth: 190).padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var cotPhai: some View {
        if m.laSapRaMat {
            NhanSapRaMat()
        } else if let p = m.progress, m.daGhiDanh {
            TienDoCT(phanTram: p)
        } else {
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.medium))
                .foregroundColor(MauCT.muc3)
                .frame(maxHeight: .infinity)
        }
    }

    private func nhanDoc(_ ten: String, _ anh: Bool) -> String {
        var phan = [ten]
        if m.laSapRaMat { phan.append(T("Sắp ra mắt")) }
        phan += MetaKhoaCT(m: m, hienKy: hienKy).phan
        if let p = m.progress, m.daGhiDanh { phan.append(ChuCT.tienDo(p, anh)) }
        return phan.joined(separator: ", ")
    }
}

// MARK: - Thẻ khoá (chế độ "Tất cả")

struct TheKhoaCT: View {
    let m: MonChuongTrinh
    @ObservedObject private var nn = QuanLyNgonNguApp.shared

    var body: some View {
        let anh = nn.ngonNgu == .anh
        let ten = m.ten(anh)
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(MauCT.keDam).frame(height: 1.5)
            AnhBiaCT(url: m.thumbnailUrl, chuDuPhong: AnhBiaCT.chuCho(m, ten: ten), coChu: 15)
                .padding(.top, 12)
            Text(dongTren(anh))
                .font(.caption2.weight(m.laSapRaMat ? .semibold : .regular).monospacedDigit())
                .foregroundColor(m.laSapRaMat ? MauCT.nhan : MauCT.muc3)
                .lineLimit(1)
                .padding(.top, 10)
            Text(ten)
                .font(ChuCTFont.serif(.headline))
                .foregroundColor(MauCT.muc)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            Spacer(minLength: 8)
            if let p = m.progress, m.daGhiDanh {
                TienDoCT(phanTram: p)
            } else {
                MetaKhoaCT(m: m)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(([ten, dongTren(anh)] + MetaKhoaCT(m: m).phan).joined(separator: ", "))
    }

    private func dongTren(_ anh: Bool) -> String {
        let dau = m.laSapRaMat ? T("Sắp ra mắt") : (m.loTrinhKy.map { ChuCT.hocKy($0, anh) } ?? T("Khoá mới"))
        return [dau, m.categoryName].compactMap { $0 }.joined(separator: " · ")
    }
}

// MARK: - Tiêu đề phần lớn (Năm, Khoá mới, Môn tự chọn)

struct TieuDePhanCT: View {
    var keo: String? = nil
    let tieuDe: String
    var moTa: String? = nil
    var rong = false
    @ScaledMetric(relativeTo: .largeTitle) private var coLon: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var coRong: CGFloat = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(MauCT.keDam).frame(height: 2.5)
            let khoiChu = VStack(alignment: .leading, spacing: 4) {
                if let keo {
                    Text(keo).font(.footnote.monospacedDigit()).foregroundColor(MauCT.muc3)
                }
                Text(tieuDe)
                    .font(.system(size: rong ? coRong : coLon, weight: .regular, design: .serif))
                    .foregroundColor(MauCT.muc)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            if rong, let moTa {
                HStack(alignment: .bottom, spacing: 40) {
                    khoiChu.frame(maxWidth: .infinity, alignment: .leading)
                    Text(moTa)
                        .font(.body)
                        .foregroundColor(MauCT.muc2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 16)
            } else {
                khoiChu.padding(.top, 14)
                if let moTa {
                    Text(moTa)
                        .font(.callout)
                        .foregroundColor(MauCT.muc2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Đường kẻ mảnh giữa các hàng.
struct KeMong: View {
    var body: some View { Rectangle().fill(MauCT.ke).frame(height: 0.5) }
}
