import WidgetKit
import SwiftUI

// ════════════════════════════════════════════════════════════════
// WIDGET TIỀN NONG
//
// Đọc DUY NHẤT `KhoAnhChupTien` — không mạng, không khoá đăng nhập.
// Xem chú thích dài trong `AnhChupTien.swift` về vì sao.
// ════════════════════════════════════════════════════════════════

struct MocTien: TimelineEntry {
    let date: Date
    let anh: AnhChupTien?
}

struct NguonTien: TimelineProvider {
    func placeholder(in context: Context) -> MocTien {
        MocTien(date: Date(), anh: Self.mau)
    }

    func getSnapshot(in context: Context, completion: @escaping (MocTien) -> Void) {
        // Trong thư viện widget (context.isPreview) thì chưa chắc app đã chạy
        // lần nào — hiện số mẫu thay vì ô trống, không thì người dùng nhìn
        // thấy widget rỗng và bỏ qua không thêm.
        completion(MocTien(date: Date(), anh: KhoAnhChupTien.doc() ?? (context.isPreview ? Self.mau : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MocTien>) -> Void) {
        let moc = MocTien(date: Date(), anh: KhoAnhChupTien.doc())
        // Làm mới lúc 0h05 hôm sau: "chi hôm nay" và số ngày còn lại tới hạn
        // đều đổi theo ngày. App cũng gọi `reloadAllTimelines()` mỗi lần ghi
        // tiền, nên đây chỉ là lưới đỡ cho trường hợp app không mở cả ngày.
        let mai = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
            .addingTimeInterval(300)
        completion(Timeline(entries: [moc], policy: .after(mai)))
    }

    static let mau: AnhChupTien = {
        var a = AnhChupTien()
        a.duNo = "150 tr"; a.duNoSo = 150_000_000
        a.laiMoiThang = "5,7 tr"
        a.chiHomNayChu = "340 k"; a.chiHomNay = 340_000
        a.hanMucNgay = 500_000; a.hanMucNgayChu = "500 k"
        a.kyToi = [
            .init(id: 1, debtId: 1, ten: "Momo", soTien: "3,9 tr", ngay: Date(), quaHan: false),
            .init(id: 2, debtId: 2, ten: "Shoppe 1", soTien: "3 tr",
                  ngay: Date().addingTimeInterval(4 * 86_400), quaHan: false),
        ]
        return a
    }()
}

// MARK: - Màu (widget KHÔNG dùng được AppColors của app)

private enum M {
    static let chinh = Color(red: 0.478, green: 0.271, blue: 0.910)
    static let canh  = Color(red: 0.937, green: 0.604, blue: 0.145)
    static let do_   = Color(red: 0.898, green: 0.224, blue: 0.208)
    static let mo    = Color.secondary
}

// MARK: - Khung nhìn

struct ManTienWidget: View {
    @Environment(\.widgetFamily) private var co
    let moc: MocTien

    var body: some View {
        if let a = moc.anh {
            switch co {
            case .accessoryInline:      dongMotHang(a)
            case .accessoryRectangular: oManKhoa(a)
            case .systemMedium:         oVua(a)
            default:                    oNho(a)
            }
        } else {
            chuaCoDuLieu
        }
    }

    /// ⚠️ Phải nói rõ vì sao trống VÀ cách sửa. Widget trống không lời giải
    /// thích là thứ người dùng gỡ đi sau hai ngày.
    private var chuaCoDuLieu: some View {
        VStack(spacing: 4) {
            Image(systemName: "creditcard")
            Text("Mở Tiền nong một lần")
                .font(.caption2).multilineTextAlignment(.center)
        }
        .foregroundStyle(M.mo)
    }

    // ─── Màn khoá ───────────────────────────────────────────────

    private func dongMotHang(_ a: AnhChupTien) -> some View {
        if let k = a.kyToi.first {
            Text("\(k.ten) \(k.soTien) · \(ngayGon(k.ngay))")
        } else {
            Text("Nợ \(a.duNo) · lãi \(a.laiMoiThang)/th")
        }
    }

    private func oManKhoa(_ a: AnhChupTien) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let k = a.kyToi.first {
                Text(k.quaHan ? "QUÁ HẠN · \(k.ten)" : "\(k.ten) · \(ngayGon(k.ngay))")
                    .font(.caption2).fontWeight(.semibold)
                Text(k.soTien).font(.headline)
                Text("Nợ \(a.duNo) · lãi \(a.laiMoiThang)/th")
                    .font(.caption2).foregroundStyle(M.mo)
            } else {
                Text("Tiền nong").font(.caption2).fontWeight(.semibold)
                Text(a.duNo).font(.headline)
                Text("lãi \(a.laiMoiThang)/tháng").font(.caption2).foregroundStyle(M.mo)
            }
        }
    }

    // ─── Màn chính ──────────────────────────────────────────────

    private func oNho(_ a: AnhChupTien) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            nhan("Tổng dư nợ")
            Text(a.duNo).font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(M.canh).minimumScaleFactor(0.6).lineLimit(1)
            nhan("Lãi mỗi tháng")
            Text(a.laiMoiThang).font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(M.do_).minimumScaleFactor(0.6).lineLimit(1)
            Spacer(minLength: 0)
            thanhChi(a)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func oVua(_ a: AnhChupTien) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                nhan("Tổng dư nợ")
                Text(a.duNo).font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(M.canh).minimumScaleFactor(0.6).lineLimit(1)
                nhan("Lãi mỗi tháng")
                Text(a.laiMoiThang).font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(M.do_).lineLimit(1)
                Spacer(minLength: 0)
                thanhChi(a)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                nhan(a.kyToi.isEmpty ? "Không có kỳ nào sắp tới" : "Sắp phải trả")
                // Chạm vào bất cứ đâu trên widget đều mở màn Tiền nong —
                // nơi những kỳ này hiện lại kèm Ô TÍCH. Không dựng thêm
                // đường riêng tới từng khoản: nó cũng chỉ tới đúng chỗ ấy,
                // mà lại thêm một tầng định tuyến nữa để sai.
                ForEach(a.kyToi) { k in
                    HStack(spacing: 5) {
                        Circle().fill(k.quaHan ? M.do_ : M.canh).frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(k.ten).font(.caption2).lineLimit(1)
                            Text(ngayGon(k.ngay)).font(.system(size: 9)).foregroundStyle(M.mo)
                        }
                        Spacer(minLength: 2)
                        Text(k.soTien).font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nhan(_ s: String) -> some View {
        Text(s).font(.system(size: 10)).foregroundStyle(M.mo)
    }

    @ViewBuilder
    private func thanhChi(_ a: AnhChupTien) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(a.nhanChi).font(.system(size: 10)).foregroundStyle(M.mo)
                Spacer(minLength: 0)
                Text(a.chiHomNayChu).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            if let t = a.tiLeHanMuc, let h = a.hanMucNgayChu {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(M.mo.opacity(0.25))
                        Capsule().fill(t >= 1 ? M.do_ : M.chinh)
                            .frame(width: max(3, g.size.width * t))
                    }
                }
                .frame(height: 4)
                Text("hạn mức \(h)").font(.system(size: 9)).foregroundStyle(M.mo)
            }
        }
    }

    private func ngayGon(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return f.string(from: d)
    }
}

// MARK: - Khai báo

struct TienWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TienWidget", provider: NguonTien()) { moc in
            ManTienWidget(moc: moc)
                .containerBackground(.fill.tertiary, for: .widget)
                // Chạm vào phần nền mở thẳng màn Tiền nong.
                .widgetURL(URL(string: "cuongthai://tien"))
        }
        .configurationDisplayName("Tiền nong")
        .description("Tổng dư nợ, lãi mỗi tháng và kỳ sắp phải trả.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryInline])
    }
}

@main
struct BoWidgetCuongThai: WidgetBundle {
    var body: some Widget { TienWidget() }
}
