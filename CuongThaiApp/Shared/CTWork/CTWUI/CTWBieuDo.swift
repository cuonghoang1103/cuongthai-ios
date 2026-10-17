import SwiftUI
import Charts

// MARK: - CTWUI — BIỂU ĐỒ & CHỈ SỐ (mảng B: kế hoạch, báo cáo, chấm công)
//
// Thành phần dùng chung cho mọi màn có số liệu: thẻ chỉ số, khung biểu đồ có
// chú giải + "xem dạng bảng", thanh tiến độ nhiều đoạn, vòng tiến độ, bảng màu
// chuỗi số liệu.
//
// Luật (theo phương pháp dataviz đã kiểm):
//   · Màu chuỗi gán THEO THỨ TỰ CỐ ĐỊNH (`CTWMauChuoi.mau(i)`), không xoay vòng
//     quá 8 — chuỗi thứ 9 trở đi gộp "Other" ở nơi gọi.
//   · Màu theo THỰC THỂ, không theo hạng: lọc bớt chuỗi không được tô lại.
//   · Hai chuỗi trở lên LUÔN có chú giải; chữ dùng màu chữ, không dùng màu chuỗi.
//   · Một trục y duy nhất — không biểu đồ hai trục.
//   · Màu trạng thái (xong/cảnh báo/lỗi) DÀNH RIÊNG, luôn đi kèm chữ/biểu tượng.
//   · Mọi biểu đồ có lối "xem dạng bảng" (VoiceOver + người mù màu).

/// Bảng 8 màu phân loại — thứ tự đã kiểm khả năng phân biệt cho người mù màu
/// (ΔE kề nhau ≥ 8 ở cả nền sáng lẫn tối). Bản tối là cùng tông, nấc khác.
enum CTWMauChuoi {
    static let bang: [Color] = [
        Color.theoCheDo(sang: Color(hex: 0x2A78D6), toi: Color(hex: 0x3987E5)), // lam
        Color.theoCheDo(sang: Color(hex: 0xEB6834), toi: Color(hex: 0xD95926)), // cam
        Color.theoCheDo(sang: Color(hex: 0x1BAF7A), toi: Color(hex: 0x199E70)), // ngọc
        Color.theoCheDo(sang: Color(hex: 0xEDA100), toi: Color(hex: 0xC98500)), // vàng
        Color.theoCheDo(sang: Color(hex: 0xE87BA4), toi: Color(hex: 0xD55181)), // hồng
        Color.theoCheDo(sang: Color(hex: 0x008300), toi: Color(hex: 0x008300)), // lục
        Color.theoCheDo(sang: Color(hex: 0x6250D6), toi: Color(hex: 0x9085E9)), // tím
        Color.theoCheDo(sang: Color(hex: 0xE34948), toi: Color(hex: 0xE66767)), // đỏ
    ]
    /// Màu "Other"/phần còn lại — xám trung tính.
    static let khac = Color.theoCheDo(sang: Color(hex: 0x9A9AA3), toi: Color(hex: 0x6B6B75))
    static func mau(_ i: Int) -> Color { i >= 0 && i < bang.count ? bang[i] : khac }

    /// Màu cho nhóm trạng thái quy trình (TODO / IN_PROGRESS / DONE) — dùng
    /// cùng hệ với chip trạng thái của thẻ.
    static func nhom(_ category: String?) -> Color {
        switch category {
        case "DONE": return AppColors.success
        case "IN_PROGRESS": return bang[0]
        default: return khac
        }
    }
}

// MARK: - Thẻ chỉ số

/// Ô chỉ số: con số lớn + nhãn + dòng phụ. Dùng cho đầu báo cáo (tổng điểm,
/// số thẻ, giờ đã ghi…) — một con số thì đừng vẽ biểu đồ.
struct CTWTheChiSo: View {
    let nhan: String
    let giaTri: String
    var phu: String?
    var bieuTuong: String?
    var mau: Color = AppColors.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let bieuTuong {
                    Image(systemName: bieuTuong).font(.system(size: 11, weight: .semibold)).foregroundColor(mau)
                }
                Text(nhan).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(giaTri).font(.system(size: 22, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let phu {
                Text(phu).font(.system(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .ctwThe(12)
        .accessibilityElement(children: .combine)
    }
}

/// Lưới thẻ chỉ số tự giãn (2 cột iPhone, 4 cột iPad).
struct CTWLuoiChiSo<C: View>: View {
    @ViewBuilder let noiDung: () -> C
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) { noiDung() }
    }
}

// MARK: - Chú giải

struct CTWMucChuGiai: Identifiable, Hashable {
    var id: String { ten }
    var ten: String
    var mau: Color
    /// Đường nét đứt (đường lý tưởng, mốc chuẩn).
    var netDut = false
}

struct CTWChuGiai: View {
    let muc: [CTWMucChuGiai]
    var body: some View {
        // Flow đơn giản: cuộn ngang khi quá dài (chữ fixedSize — bẫy cắt chữ).
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(muc) { m in
                    HStack(spacing: 5) {
                        if m.netDut {
                            Rectangle().fill(m.mau).frame(width: 12, height: 2)
                                .mask(HStack(spacing: 2) { ForEach(0..<3, id: \.self) { _ in Rectangle().frame(width: 3) } })
                        } else {
                            RoundedRectangle(cornerRadius: 2).fill(m.mau).frame(width: 10, height: 10)
                        }
                        Text(m.ten).font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.textSecondary).fixedSize()
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Khung biểu đồ

/// Một hàng của bảng số liệu (lối "xem dạng bảng").
struct CTWHangBang: Identifiable, Hashable {
    var id: String { nhan }
    var nhan: String
    var giaTri: [String]
}

/// Mặt thẻ chứa một biểu đồ: tiêu đề, dòng phụ, chú giải, nút chuyển sang
/// bảng số liệu. Biểu đồ đặt trong `noiDung`.
struct CTWKhungBieuDo<C: View>: View {
    let tieuDe: String
    var phu: String?
    var chuGiai: [CTWMucChuGiai] = []
    /// Cột + hàng cho chế độ bảng. Rỗng ⇒ không có nút bảng.
    var cot: [String] = []
    var hang: [CTWHangBang] = []
    var cao: CGFloat = 220
    @ViewBuilder let noiDung: () -> C
    @State private var xemBang = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tieuDe).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    if let phu {
                        Text(phu).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if !hang.isEmpty {
                    Button { withAnimation(.easeInOut(duration: 0.15)) { xemBang.toggle() } } label: {
                        Image(systemName: xemBang ? "chart.xyaxis.line" : "tablecells")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityLabel(xemBang ? "Show chart" : "Show data table")
                }
            }
            if chuGiai.count >= 2 && !xemBang { CTWChuGiai(muc: chuGiai) }
            if xemBang {
                CTWBangSoLieu(cot: cot, hang: hang)
            } else {
                noiDung().frame(height: cao)
            }
        }
        .padding(14)
        .ctwThe(14)
    }
}

/// Bảng số liệu gọn — chữ số canh phải, đơn cách.
struct CTWBangSoLieu: View {
    let cot: [String]
    let hang: [CTWHangBang]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(Array(cot.enumerated()), id: \.offset) { i, c in
                    Text(c).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : .trailing)
                }
            }
            .padding(.vertical, 6)
            Divider()
            ForEach(hang) { h in
                HStack {
                    Text(h.nhan).font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                    ForEach(Array(h.giaTri.enumerated()), id: \.offset) { _, v in
                        Text(v).font(.system(size: 12).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
                Divider().opacity(0.5)
            }
        }
    }
}

// MARK: - Tiến độ

/// Một đoạn của thanh tiến độ nhiều đoạn.
struct CTWDoanTienDo: Identifiable, Hashable {
    var id: String { ten }
    var ten: String
    var giaTri: Double
    var mau: Color
}

/// Thanh tiến độ nhiều đoạn (xong / đang làm / chưa làm). Khe 2pt giữa các đoạn.
struct CTWThanhTienDo: View {
    let doan: [CTWDoanTienDo]
    var cao: CGFloat = 8

    var body: some View {
        let tong = max(doan.map(\.giaTri).reduce(0, +), 0.0001)
        GeometryReader { g in
            let co = doan.filter { $0.giaTri > 0 }
            let khe: CGFloat = co.count > 1 ? 2 : 0
            let rong = max(g.size.width - khe * CGFloat(max(co.count - 1, 0)), 0)
            HStack(spacing: khe) {
                if co.isEmpty {
                    Capsule().fill(AppColors.backgroundTertiary)
                } else {
                    ForEach(co) { d in
                        Rectangle().fill(d.mau).frame(width: rong * CGFloat(d.giaTri / tong))
                    }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: cao)
        .background(Capsule().fill(AppColors.backgroundTertiary))
        .accessibilityElement()
        .accessibilityLabel(doan.map { "\($0.ten) \(CTWSo.gon($0.giaTri))" }.joined(separator: ", "))
    }
}

/// Vòng tiến độ (0…1) với phần trăm ở giữa.
struct CTWVongTienDo: View {
    let tiLe: Double
    var co: CGFloat = 54
    var net: CGFloat = 6
    var mau: Color = AppColors.primary
    var chu: String?

    var body: some View {
        let t = min(max(tiLe, 0), 1)
        ZStack {
            Circle().stroke(AppColors.backgroundTertiary, lineWidth: net)
            Circle().trim(from: 0, to: t)
                .stroke(mau, style: StrokeStyle(lineWidth: net, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(chu ?? "\(Int((t * 100).rounded()))%")
                .font(.system(size: co * 0.24, weight: .bold).monospacedDigit())
                .foregroundColor(AppColors.textPrimary)
                .minimumScaleFactor(0.6)
        }
        .frame(width: co, height: co)
        .accessibilityElement()
        .accessibilityLabel("\(Int((t * 100).rounded())) percent")
    }
}

// MARK: - Định dạng số

enum CTWSo {
    /// 3 → "3", 2.5 → "2.5", 12.25 → "12.3".
    static func gon(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.1f", v)
    }
    /// Giây → "2h 05m" / "45m" / "0m".
    static func gio(giay s: Int) -> String {
        let p = max(s, 0) / 60
        let h = p / 60, m = p % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : String(format: "%dh %02dm", h, m)
    }
    /// Giây → "1.5h" (trục biểu đồ, ô bảng giờ).
    static func gioThapPhan(giay s: Int) -> String {
        let h = Double(s) / 3600
        return h == 0 ? "0" : (h < 10 ? String(format: "%.1fh", h) : "\(Int(h.rounded()))h")
    }
    /// Đồng hồ bấm giờ "1:02:05" / "02:05".
    static func dongHo(giay s: Int) -> String {
        let s = max(s, 0)
        let h = s / 3600, m = (s % 3600) / 60, g = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, g) : String(format: "%02d:%02d", m, g)
    }
    /// USD ước lượng.
    static func usd(_ v: Double) -> String {
        v < 0.01 && v > 0 ? "<$0.01" : String(format: "$%.2f", v)
    }
}
