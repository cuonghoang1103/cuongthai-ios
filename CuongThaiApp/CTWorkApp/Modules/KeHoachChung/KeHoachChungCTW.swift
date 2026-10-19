import SwiftUI

// MARK: - Dùng chung cho mảng B (Kế hoạch & theo dõi tiến độ)
//
// Ngày tháng, trạng thái tải, thanh chọn tab, đường dẫn không gian. Các mô-đun Sprints,
// Timeline, Releases, Reports, Dashboards, Calendar, Stages, Poker, Retro, OKR, Time,
// Workspace dùng lại những thứ ở đây để cùng một cách nói chuyện với máy chủ.

// MARK: Ngày

/// Hai kiểu ngày backend trả (đã đối chiếu service):
///   · `YMD` — chuỗi "YYYY-MM-DD" do service tự dựng (đa số số liệu báo cáo, theo giờ VN).
///   · ISO đầy đủ — cột `DateTime`. Cột `@db.Date` ra "YYYY-MM-DDT00:00:00.000Z" (lấy 10 ký tự đầu).
///   ⚠️ Sprint lưu lúc 00:00 giờ VN = 17:00Z HÔM TRƯỚC ⇒ cắt 10 ký tự là SỚM một ngày.
///      Mốc thời điểm thật (sprint, họp) đọc bằng `thoiDiem` rồi đổi sang ngày theo giờ VN/máy.
enum NgayCTW {
    static let mui = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

    static var lichVN: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = mui
        c.firstWeekday = 2
        return c
    }

    /// ISO (có/không phần lẻ giây) → Date.
    static func thoiDiem(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        // Chỉ có ngày "YYYY-MM-DD" ⇒ nửa đêm giờ VN.
        return ngay(s)
    }

    /// "YYYY-MM-DD" (hoặc 10 ký tự đầu của ISO) → Date nửa đêm giờ VN.
    static func ngay(_ s: String?) -> Date? {
        guard let s, s.count >= 10 else { return nil }
        let p = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return lichVN.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    /// Date → "YYYY-MM-DD" theo giờ VN (khớp cách máy chủ chia ngày).
    static func ymd(_ d: Date) -> String {
        let c = lichVN.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// Mốc thời điểm (sprint startAt/endAt) → ngày VN "YYYY-MM-DD".
    static func ngayCua(_ iso: String?) -> String? {
        guard let iso else { return nil }
        if iso.count == 10 { return iso }
        return thoiDiem(iso).map(ymd)
    }

    /// Thứ Hai của tuần chứa `d` (giờ VN).
    static func dauTuan(_ d: Date) -> Date {
        let l = lichVN
        let bd = l.startOfDay(for: d)
        let thu = l.component(.weekday, from: bd) // 1 = CN
        let lui = (thu + 5) % 7
        return l.date(byAdding: .day, value: -lui, to: bd) ?? bd
    }

    static func cong(_ d: Date, ngay n: Int) -> Date { lichVN.date(byAdding: .day, value: n, to: d) ?? d }

    /// Số ngày từ a tới b (theo ngày lịch VN).
    static func soNgay(_ a: Date, _ b: Date) -> Int {
        lichVN.dateComponents([.day], from: lichVN.startOfDay(for: a), to: lichVN.startOfDay(for: b)).day ?? 0
    }

    private static func dinhDang(_ mau: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = mui
        f.dateFormat = mau
        return f
    }
    /// "Oct 18"
    static func ngan(_ d: Date) -> String { dinhDang("MMM d").string(from: d) }
    /// "Oct 18, 2026"
    static func day(_ d: Date) -> String { dinhDang("MMM d, yyyy").string(from: d) }
    /// "Mon 18"
    static func thuNgay(_ d: Date) -> String { dinhDang("EEE d").string(from: d) }
    /// "October 2026"
    static func thang(_ d: Date) -> String { dinhDang("MMMM yyyy").string(from: d) }
    /// "14:05" theo giờ MÁY (họp có giờ thật — người dùng đọc theo giờ của mình).
    static func gio(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    /// "YYYY-MM-DD" → "Oct 18" (nil nếu hỏng).
    static func nganTu(_ s: String?) -> String? { ngay(s).map(ngan) }
}

// MARK: Trạng thái tải

/// Dữ liệu một màn: đang tải / lỗi / có dữ liệu. Màn chỉ việc `switch`.
enum TaiCTW<T> {
    case dangTai
    case loi(String)
    case xong(T)

    var giaTri: T? { if case .xong(let v) = self { return v }; return nil }
    var dangTai: Bool { if case .dangTai = self { return true }; return false }
}

/// Khung chuẩn cho một màn đọc dữ liệu: skeleton khi tải lần đầu, ô lỗi + Thử lại, rồi nội dung.
struct KhungTaiCTW<T, C: View>: View {
    let trangThai: TaiCTW<T>
    var soHang = 5
    let thuLai: () -> Void
    @ViewBuilder let noiDung: (T) -> C

    var body: some View {
        switch trangThai {
        case .dangTai: CTWKhungTai(soHang: soHang, coAvatar: false).frame(maxHeight: .infinity, alignment: .top)
        case .loi(let l): CTWOLoi(loi: l, thuLai: thuLai).frame(maxHeight: .infinity)
        case .xong(let v): noiDung(v)
        }
    }
}

// MARK: Thanh tab ngang (báo cáo, chế độ xem)

/// Thanh chọn tab cuộn ngang kiểu "chip" — nhiều tab hơn `Picker(.segmented)` chứa được.
struct ThanhTabCTW<ID: Hashable>: View {
    let tab: [(id: ID, ten: String, bieuTuong: String?)]
    @Binding var chon: ID

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tab, id: \.id) { t in
                        let bat = t.id == chon
                        Button {
                            CTWRung.chon()
                            withAnimation(.easeInOut(duration: 0.15)) { chon = t.id }
                        } label: {
                            HStack(spacing: 5) {
                                if let b = t.bieuTuong { Image(systemName: b).font(.ctw(size: 11, weight: .semibold)) }
                                Text(t.ten).font(.ctw(size: 13, weight: .semibold)).fixedSize()
                            }
                            .foregroundColor(bat ? AppColors.onPrimary : AppColors.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(bat ? AppColors.primary : AppColors.backgroundCard))
                            .overlay(Capsule().strokeBorder(bat ? Color.clear : AppColors.border, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .id(t.id)
                        .accessibilityAddTraits(bat ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 4)
            }
            .onChange(of: chon) { _, moi in withAnimation { cuon.scrollTo(moi, anchor: .center) } }
        }
    }
}

// MARK: Không gian

extension AppState {
    /// Id SỐ của không gian đang chọn — các route `/workspaces/:wsId/...` chỉ nhận số (slug ⇒ 400).
    /// Lấy từ cấu hình dự án đã nạp; chưa có thì hỏi `GET /workspaces/by-slug/:slug`.
    func idKhongGian() async -> Int? {
        if let id = cauHinhDuAn?.workspace?.id { return id }
        guard let slug = luaChon?.slug else { return nil }
        let w: CTWWorkspaceDetail? = try? await APIClient.shared.request(.workKhongGian(slug: slug))
        return w?.id
    }
}

// MARK: Nhãn "AI agent" + chi phí tự khai

/// Nhãn nguồn chi phí agent (4.7 + quy ước web): phần lớn là SỐ TỰ KHAI của agent, không phải số đo.
struct NhanTuKhaiCTW: View {
    var body: some View {
        Label("self-reported", systemImage: "info.circle")
            .font(.ctw(size: 10, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(AppColors.backgroundTertiary))
            .accessibilityLabel("Cost is self-reported by the agent")
    }
}
