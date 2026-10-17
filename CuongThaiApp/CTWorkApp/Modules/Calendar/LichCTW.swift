import SwiftUI

// MARK: - Lịch — tháng + agenda
//
// Gộp hạn thẻ của tôi (mọi dự án), sprint/version/stage của dự án đang chọn và họp sắp tới.
// iPhone: lưới tháng trên, agenda dưới. iPad: lưới tháng trái, agenda phải.
// Mỗi sự kiện có nút "Add to Calendar" (EventKitUI, không xin quyền — xem `ThemSuKienLichB2`).

@MainActor
final class LichVM: ObservableObject {
    let pid: Int
    @Published var trangThai: TaiCTW<[SuKienLichCTW]> = .dangTai
    @Published var coHop = false
    @Published var link: LinkLichCTW?
    @Published var loi: String?

    init(pid: Int) { self.pid = pid }

    func tai(cfg: CTWProjectConfig?) async {
        async let m: TLMocCTW? = try? APIClient.shared.request(CTWAPI.mocThoiGian(pid: pid))
        async let h: DsHopLichCTW? = try? APIClient.shared.request(CTWAPI.hopSapToi(pid: pid))
        async let l: LinkLichCTW? = try? APIClient.shared.request(CTWAPI.linkLich())
        do {
            let v: CTWMyWork = try await APIClient.shared.request(.workViecCuaToi)
            let moc = await m ?? TLMocCTW()
            let hop = await h
            coHop = hop != nil
            link = await l
            trangThai = .xong(GopLichCTW.dung(viec: v.items ?? [], moc: moc, sprintCfg: cfg?.sprints ?? [], hop: hop?.items ?? []))
        } catch {
            if trangThai.giaTri == nil { trangThai = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) }
        }
    }

    /// Tạo link đăng ký .ics mới (thu hồi link cũ) ⇒ URL `webcal://…`.
    func dangKy() async -> URL? {
        do {
            let r: LinkLichMoiCTW = try await APIClient.shared.request(CTWAPI.taoLinkLich())
            guard let p = r.path, var c = URLComponents(string: APIClient.diaChiGoc + "/api/v1" + p) else { return nil }
            c.scheme = "webcal"
            link = LinkLichCTW(active: true)
            return c.url
        } catch {
            loi = CTW.loi(error)
            return nil
        }
    }
}

struct LichCTW: View {
    let nguCanh: CTWNguCanh
    @StateObject private var vm: LichVM
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong
    @Environment(\.openURL) private var moURL
    @State private var thang = Date()
    @State private var chon = Date()
    @State private var loc: Set<LoaiSuKienLichCTW> = Set(LoaiSuKienLichCTW.allCases)
    @State private var tamPhu: TamPhu?
    @State private var hoiDangKy = false

    private enum TamPhu: Identifiable {
        case hop(HopLichCTW), them(SuKienLichCTW)
        var id: String {
            switch self {
            case .hop(let h): return "hop-\(h.id)"
            case .them(let s): return "them-\(s.id)"
            }
        }
    }

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: LichVM(pid: nguCanh.pid))
    }

    var body: some View {
        KhungTaiCTW(trangThai: vm.trangThai, thuLai: { Task { await vm.tai(cfg: app.cauHinhDuAn) } }) { ds in
            let hien = ds.filter { loc.contains($0.loai) }
            let theoNgay = GopLichCTW.theoNgay(hien)
            if beRong == .regular {
                HStack(alignment: .top, spacing: 16) {
                    ScrollView { VStack(spacing: 14) { luoi(theoNgay); thanhLoc(ds); if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil } } } .padding(Spacing.md) }
                        .frame(width: 440)
                    ScrollView { agenda(theoNgay).padding(Spacing.md) }
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil } }
                        luoi(theoNgay)
                        thanhLoc(ds)
                        agenda(theoNgay)
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { hoiDangKy = true } label: { Label("Subscribe in Calendar app…", systemImage: "calendar.badge.plus") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Calendar options")
            }
        }
        .confirmationDialog("Subscribe to your CT Work calendar?", isPresented: $hoiDangKy, titleVisibility: .visible) {
            Button("Create subscription link") {
                Task { if let u = await vm.dangKy() { moURL(u) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(vm.link?.active == true
                 ? "You already have a subscription link. Creating a new one stops the old link from updating anywhere it's used. Your Calendar app will then show your due dates, sprints, releases and meetings."
                 : "Your Calendar app will show your due dates, sprints, releases and meetings, and keep them updated. The link is private to you.")
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .hop(let h): ChiTietHopLichCTW(hop: h) { s in tamPhu = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tamPhu = .them(s) } }
            case .them(let s): ThemSuKienLichB2(suKien: s, lienKet: lienKet(s)).ignoresSafeArea()
            }
        }
        .task { await vm.tai(cfg: app.cauHinhDuAn) }
        .refreshable { await vm.tai(cfg: app.cauHinhDuAn) }
    }

    // MARK: Lưới tháng

    private func luoi(_ theoNgay: [String: [SuKienLichCTW]]) -> some View {
        let o = GopLichCTW.oThang(thang)
        let lich = Calendar.current
        let thangNay = lich.component(.month, from: thang)
        return VStack(spacing: 10) {
            HStack {
                Text(tenThang(thang)).font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Today") { withAnimation { thang = Date(); chon = Date() } }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minHeight: 44)
                nutThang("chevron.left", "Previous month", -1)
                nutThang("chevron.right", "Next month", 1)
            }
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i].prefix(beRong == .regular ? 3 : 1))
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(o, id: \.self) { d in
                    let k = khoaMay(d)
                    let sk = theoNgay[k] ?? []
                    let trongThang = lich.component(.month, from: d) == thangNay
                    oNgay(d, sk: sk, trongThang: trongThang)
                }
            }
        }
        .padding(14)
        .ctwThe(16)
        .gesture(DragGesture(minimumDistance: 30).onEnded { g in
            if abs(g.translation.width) > abs(g.translation.height) { doiThang(g.translation.width < 0 ? 1 : -1) }
        })
    }

    private func nutThang(_ icon: String, _ ten: String, _ n: Int) -> some View {
        Button { doiThang(n) } label: {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44)
        }
        .accessibilityLabel(ten)
    }

    private func doiThang(_ n: Int) {
        CTWRung.chon()
        withAnimation(.easeInOut(duration: 0.2)) { thang = Calendar.current.date(byAdding: .month, value: n, to: thang) ?? thang }
    }

    private func oNgay(_ d: Date, sk: [SuKienLichCTW], trongThang: Bool) -> some View {
        let lich = Calendar.current
        let laChon = lich.isDate(d, inSameDayAs: chon)
        let homNay = lich.isDateInToday(d)
        let loai = Array(Set(sk.map(\.loai))).sorted { $0.rawValue < $1.rawValue }.prefix(3)
        let coQuaHan = sk.contains { $0.quaHan }
        return Button {
            CTWRung.chon()
            chon = d
            if !trongThang { thang = d }
        } label: {
            VStack(spacing: 3) {
                Text("\(lich.component(.day, from: d))")
                    .font(.system(size: 15, weight: homNay || laChon ? .bold : .regular).monospacedDigit())
                    .foregroundColor(laChon ? AppColors.onPrimary : (homNay ? AppColors.primary : (trongThang ? AppColors.textPrimary : AppColors.textTertiary)))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(laChon ? AppColors.primary : Color.clear))
                    .overlay(Circle().strokeBorder(homNay && !laChon ? AppColors.primary : Color.clear, lineWidth: 1.2))
                HStack(spacing: 3) {
                    ForEach(Array(loai), id: \.self) { l in
                        Circle().fill(l == .han && coQuaHan ? AppColors.error : l.mau).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
            .opacity(trongThang ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(NgayCTW.day(d))\(sk.isEmpty ? "" : ", \(sk.count) event\(sk.count == 1 ? "" : "s")")")
        .accessibilityAddTraits(laChon ? .isSelected : [])
    }

    // MARK: Lọc

    private func thanhLoc(_ ds: [SuKienLichCTW]) -> some View {
        let co = Set(ds.map(\.loai))
        let cac = LoaiSuKienLichCTW.allCases.filter { co.contains($0) || ($0 == .hop && vm.coHop) || $0 == .han }
        return CTWThanhLoc(chip: cac.map { CTWChipLoc(id: $0.rawValue, nhan: $0.ten, bieuTuong: $0.bieuTuong, bat: loc.contains($0)) }) { c in
            guard let l = LoaiSuKienLichCTW(rawValue: c.id) else { return }
            if loc.contains(l) { loc.remove(l) } else { loc.insert(l) }
        }
        .padding(.horizontal, -Spacing.md)
    }

    // MARK: Agenda

    private func agenda(_ theoNgay: [String: [SuKienLichCTW]]) -> some View {
        let k = khoaMay(chon)
        let homNayChon = theoNgay[k] ?? []
        // 14 ngày sau ngày đang chọn.
        let sapToi: [(Date, [SuKienLichCTW])] = (1...14).compactMap { i in
            guard let d = Calendar.current.date(byAdding: .day, value: i, to: chon) else { return nil }
            let s = theoNgay[khoaMay(d)] ?? []
            return s.isEmpty ? nil : (d, s)
        }
        return VStack(alignment: .leading, spacing: 12) {
            CTWSectionHeader("calendar", Calendar.current.isDateInToday(chon) ? "Today · \(NgayCTW.ngan(chon))" : NgayCTW.day(chon),
                             count: homNayChon.isEmpty ? nil : "\(homNayChon.count)")
            if homNayChon.isEmpty {
                Text("Nothing scheduled.").font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).ctwThe(12)
            } else {
                VStack(spacing: 0) { ForEach(homNayChon) { s in hang(s); if s.id != homNayChon.last?.id { Divider().padding(.leading, 52) } } }
                    .ctwThe(14)
            }
            if !sapToi.isEmpty {
                CTWSectionHeader("clock", "Coming up").padding(.top, 6)
                ForEach(sapToi, id: \.0) { d, s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Calendar.current.isDateInTomorrow(d) ? "Tomorrow · \(NgayCTW.ngan(d))" : thuNgayMay(d))
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        VStack(spacing: 0) { ForEach(s) { x in hang(x); if x.id != s.last?.id { Divider().padding(.leading, 52) } } }
                            .ctwThe(14)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func hang(_ s: SuKienLichCTW) -> some View {
        let noi = HStack(spacing: 12) {
            Image(systemName: s.loai.bieuTuong).font(.system(size: 13, weight: .semibold))
                .foregroundColor(s.quaHan ? AppColors.error : s.loai.mau)
                .frame(width: 30, height: 30)
                .background(Circle().fill((s.quaHan ? AppColors.error : s.loai.mau).opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(s.tieuDe).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 4) {
                    Text(s.caNgay ? "All day" : NgayCTW.gio(s.batDau))
                    if let p = s.phu, !p.isEmpty { Text("·"); Text(p).lineLimit(1) }
                    if s.quaHan { Text("· Overdue").foregroundColor(AppColors.error) }
                }
                .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        HStack(spacing: 0) {
            Group {
                if s.loai == .han, let slug = s.slug, let ma = s.maDuAn, let so = s.so {
                    NavigationLink(value: CTWRoute.theTheoMa(slug: slug, ma: ma, so: so)) { noi.contentShape(Rectangle()) }
                } else if s.loai == .phatHanh, let id = s.idPhienBan {
                    NavigationLink(value: RoutePhienBanCTW(pid: nguCanh.pid, id: id, ten: s.tieuDe)) { noi.contentShape(Rectangle()) }
                } else if let h = s.hop {
                    Button { tamPhu = .hop(h) } label: { noi.contentShape(Rectangle()) }
                } else {
                    noi
                }
            }
            .buttonStyle(.plain)
            Button { tamPhu = .them(s) } label: {
                Image(systemName: "calendar.badge.plus").font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.primary).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add to Calendar")
        }
        .padding(.leading, 12).padding(.vertical, 6)
        .contextMenu {
            Button { tamPhu = .them(s) } label: { Label("Add to Calendar", systemImage: "calendar.badge.plus") }
        }
    }

    // MARK: Tiện ích

    private func lienKet(_ s: SuKienLichCTW) -> URL? {
        if let u = s.hop?.meetingUrl, let url = URL(string: u) { return url }
        if s.loai == .han, let slug = s.slug, let ma = s.maDuAn, let so = s.so {
            return URL(string: "\(APIClient.diaChiGoc)/work/\(CTWAPI.doan(slug))/\(CTWAPI.doan(ma))/issue/\(so)")
        }
        return nil
    }

    private func khoaMay(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    private func tenThang(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: d)
    }

    private func thuNgayMay(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: d)
    }
}

// MARK: - Chi tiết họp

struct ChiTietHopLichCTW: View {
    let hop: HopLichCTW
    let themLich: (SuKienLichCTW) -> Void
    @Environment(\.dismiss) private var dong
    @Environment(\.openURL) private var moURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(hop.typeLabel ?? "Meeting").font(.system(size: 12, weight: .semibold)).foregroundColor(LoaiSuKienLichCTW.hop.mau)
                        Text(hop.title ?? "Meeting").font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        if let a = NgayCTW.thoiDiem(hop.startsAt) {
                            let b = NgayCTW.thoiDiem(hop.endsAt)
                            Label("\(ngayMay(a)) · \(NgayCTW.gio(a))\(b.map { " – \(NgayCTW.gio($0))" } ?? "")", systemImage: "clock")
                                .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let l = hop.location, !l.isEmpty {
                    Section("Location") { Label(l, systemImage: "mappin.and.ellipse") }
                }
                if let u = hop.meetingUrl, let url = URL(string: u) {
                    Section {
                        Button { moURL(url) } label: {
                            Label("Join \(tenNhaCungCap)", systemImage: "video.fill")
                        }
                    }
                }
                if let o = hop.organizer {
                    Section("Organizer") { nguoi(o) }
                }
                let ds = hop.attendees ?? []
                if !ds.isEmpty {
                    Section("Attendees · \(ds.count)") { ForEach(ds) { nguoi($0) } }
                }
                Section {
                    Button {
                        if let s = suKien { themLich(s) }
                    } label: { Label("Add to Calendar", systemImage: "calendar.badge.plus") }
                }
            }
            .navigationTitle(hop.key ?? "Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
        }
    }

    private var suKien: SuKienLichCTW? {
        guard let a = NgayCTW.thoiDiem(hop.startsAt) else { return nil }
        return SuKienLichCTW(id: "hop-\(hop.id)", loai: .hop, tieuDe: hop.title ?? "Meeting", phu: hop.location,
                             batDau: a, ketThuc: NgayCTW.thoiDiem(hop.endsAt), caNgay: false, hop: hop)
    }

    private var tenNhaCungCap: String {
        switch hop.provider {
        case "MEET": return "Google Meet"
        case "ZOOM": return "Zoom"
        case "TEAMS": return "Microsoft Teams"
        case "JITSI": return "Jitsi"
        default: return "meeting"
        }
    }

    private func nguoi(_ u: CTWUser) -> some View {
        HStack(spacing: 10) {
            CTWAvatar(user: u, size: 28)
            Text(u.ten).foregroundColor(AppColors.textPrimary)
            if u.laAgent { CTWNhanAI() }
        }
    }

    private func ngayMay(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d"
        return f.string(from: d)
    }
}
