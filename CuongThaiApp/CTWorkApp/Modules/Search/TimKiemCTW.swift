import SwiftUI

// MARK: - Màn "Tìm mọi thứ" (⌘K) — như bảng lệnh của web `components/work/CommandPalette.tsx` (21/10/2026)
//
// Gõ là ra, theo nhóm:
//   · Chuyển tới — gõ đúng mã thẻ (`NW-12`, hoặc `12`/`#12` trong dự án đang chọn) ⇒ dòng đầu mở thẳng thẻ.
//   · Chức năng — mọi mô-đun HIỆN ĐƯỢC của dự án (`CTWDangKyMoDun.hienDuoc`) + màn cấp app; khớp tên vi + en, từ khoá
//     (`CTWTuKhoaMoDun`), bỏ dấu ("bao cao" ⇒ Báo cáo). Tức thì, không gọi mạng.
//   · Lệnh — Tạo thẻ, Đổi dự án, Tạo cùng CuongMini, Dự án mới, Đổi ngôn ngữ.
//   · Dự án / Không gian — từ `GET /work/search/facets` (một lời gọi, dự án xem được ở mọi không gian).
//   · Thẻ — `GET /work/search` (từ 2 ký tự, như web): một lượt trong dự án đang chọn (`project = KEY`, lên trước) + một
//     lượt mọi dự án; dòng cuối "Tìm mọi thẻ khớp …" ⇒ ô tìm My Work (bộ lọc như trang Search của web).
//   · Tài liệu — `GET /work/search/docs` (máy chủ tự lọc theo quyền xem tài liệu từng dự án).
//   · Thành viên — người trong dự án đang chọn (cấu hình dự án đã có sẵn) ⇒ List thẻ đang mở của họ.
//   · Chân: "Tìm nâng cao (JQL)…" ⇒ List của dự án với `text ~ "…"`.
// Ô trống: tìm gần đây (`TimGanDayCTW`, chung với My Work) · thẻ xem gần đây (`TheGanDayCTW`) · hay dùng (`DungNhieuCTW`).
// Gọi mạng chờ 250 ms sau phím cuối; phần cục bộ cập nhật ngay.

/// Dự án từ `/search/facets` (có không gian — mô hình `CTWTimFacets.DuAn` của My Work bỏ trường này).
struct CTWDuAnTim: Codable, Hashable, Identifiable {
    struct KhongGian: Codable, Hashable { var slug: String; var name: String? }
    var id: Int
    var key: String
    var name: String?
    var archived: Bool?
    var workspace: KhongGian?
}

private struct CTWFacetDuAn: Codable { var projects: [CTWDuAnTim]? }

/// Một trang tài liệu từ `GET /work/search/docs` (`pages.searchDocsGlobal`).
struct CTWTrangTim: Codable, Hashable, Identifiable {
    struct DuAn: Codable, Hashable { var id: Int?; var key: String?; var name: String?; var workspaceSlug: String? }
    var id: Int
    var number: Int
    var title: String?
    var status: String?
    var snippet: String?
    var project: DuAn?
}

extension CTWAPI {
    static var timDuAnFacets: APIEndpoint { CTWAPI.get("/search/facets") }
    static func timTaiLieu(q: String, limit: Int = 6) -> APIEndpoint { get("/search/docs", ["q": String(q.prefix(200)), "limit": limit]) }
}

@MainActor
final class TimKiemVM: ObservableObject {
    /// Đệm qua các lần mở (danh sách dự án/không gian ít đổi) — mở lại là có ngay.
    private static var duAnDem: [CTWDuAnTim] = []
    private static var khongGianDem: [CTWWorkspace] = []

    @Published var duAn: [CTWDuAnTim] = TimKiemVM.duAnDem
    @Published var khongGian: [CTWWorkspace] = TimKiemVM.khongGianDem
    @Published var theDuAn: [CTWSearchItem] = []
    @Published var theKhac: [CTWSearchItem] = []
    @Published var tongThe: Int?
    @Published var trang: [CTWTrangTim] = []
    @Published var dangTim = false
    @Published var loi = false
    /// Chữ của kết quả đang hiện (để không lẫn kết quả cũ với chữ mới).
    @Published var chuDaTim = ""

    func napNen() async {
        async let f: CTWFacetDuAn? = try? APIClient.shared.request(CTWAPI.timDuAnFacets)
        async let w: [CTWWorkspace]? = try? APIClient.shared.request(.workDsKhongGian)
        if let ds = await f?.projects { duAn = ds.filter { $0.archived != true }; Self.duAnDem = duAn }
        if let ds = await w { khongGian = ds; Self.khongGianDem = ds }
    }

    func tim(_ chu: String, maDuAn: String?) async {
        let t = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else {
            theDuAn = []; theKhac = []; trang = []; tongThe = nil; loi = false; dangTim = false; chuDaTim = t
            return
        }
        dangTim = true
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else { return }
        async let g: CTWSearchResult = APIClient.shared.request(CTWAPI.timToanCucLoc(q: t, jql: "", limit: 10))
        async let h: CTWSearchResult? = maDuAn == nil ? nil
            : try? APIClient.shared.request(CTWAPI.timToanCucLoc(q: t, jql: "project = \(CTWJql.boc(maDuAn ?? ""))", limit: 5))
        async let d: [CTWTrangTim]? = try? APIClient.shared.request(CTWAPI.timTaiLieu(q: t))
        do {
            let rg = try await g
            let rh = await h
            let rd = await d
            guard !Task.isCancelled else { return }
            let o = rh?.items ?? []
            let co = Set(o.map(\.id))
            theDuAn = o
            theKhac = (rg.items ?? []).filter { !co.contains($0.id) }
            tongThe = rg.total
            trang = rd ?? []
            loi = false
        } catch {
            guard !Task.isCancelled else { return }
            loi = true
            theDuAn = []; theKhac = []; tongThe = nil
            trang = await d ?? []
        }
        chuDaTim = t
        dangTim = false
    }
}

struct TimKiemCTW: View {
    let chuDau: String
    /// Khung đang là iPad rộng (đọc NGOÀI tấm phủ — trong tấm phủ iPad cỡ ngang là compact).
    let rong: Bool

    @EnvironmentObject private var app: AppState
    @ObservedObject private var ganDay = TimGanDayCTW.shared
    @ObservedObject private var ngonNgu = NgonNguApCTW.shared
    /// Danh bạ Thành viên (mọi người cùng không gian + trạng thái) — để gõ tên ra hồ sơ / nhắn tin.
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @StateObject private var vm = TimKiemVM()
    @State private var q = ""
    @State private var moRongChucNang = false
    @FocusState private var dangGo: Bool
    private var dh: DieuHuongTimCTW { .shared }

    init(chuDau: String = "", rong: Bool) {
        self.chuDau = chuDau
        self.rong = rong
        _q = State(initialValue: chuDau)
    }

    private var chu: String { q.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cfg: CTWProjectConfig? { app.cauHinhDuAn }

    // MARK: Dữ liệu cục bộ

    private var tatCaChucNang: [MucTimCTW] {
        let mod = CTWDangKyMoDun.hienDuoc(cfg).filter { m in m.id != "code" || app.codeDaNoi == true }
        // `hienDuoc` bỏ mô-đun cấp ứng dụng (Tin nhắn, Thành viên — không thuộc dự án) ⇒ thêm riêng, ngay sau màn cấp app.
        return CTWXepHangTim.manApp + CTWDangKyMoDun.capUngDung.map(CTWXepHangTim.muc) + mod.map(CTWXepHangTim.muc)
    }

    private var dsLenh: [MucTimCTW] {
        CTWXepHangTim.lenh(taoThe: cfg?.coTheTao == true, taoDuAn: !khongGianTao.isEmpty,
                           coDuAn: app.luaChon != nil, ngonNguHienTai: ngonNgu.cheDo)
    }

    private var khongGianTao: [CTWWorkspace] { vm.khongGian.filter(TaoMoiCTW.duocTao) }

    private var dem: [String: Int] { DungNhieuCTW.bang() }

    private var chucNang: [MucTimCTW] { CTWXepHangTim.xep(chu, tatCaChucNang, dem: dem) }
    private var lenh: [MucTimCTW] { CTWXepHangTim.xep(chu, dsLenh, dem: dem) }

    private var maGo: CTWMaTheGo? { CTWMaTheGo.tach(chu) }

    private var duAnKhop: [CTWDuAnTim] {
        let f = CTWBoDau.chuan(chu)
        return vm.duAn.compactMap { p -> (CTWDuAnTim, Int)? in
            guard let d = CTWKhopTim.diem(f, ten: [CTWBoDau.chuan(p.key), CTWBoDau.chuan(p.name ?? "")]) else { return nil }
            return (p, d + (p.id == app.luaChon?.pid ? 1 : 0))
        }.sorted { $0.1 > $1.1 }.prefix(6).map(\.0)
    }

    private var khongGianKhop: [(slug: String, ten: String)] {
        let f = CTWBoDau.chuan(chu)
        var thay = Set<String>()
        var ds: [(String, String)] = []
        for p in vm.duAn {
            guard let w = p.workspace, !thay.contains(w.slug) else { continue }
            thay.insert(w.slug)
            if CTWKhopTim.diem(f, ten: [CTWBoDau.chuan(w.name ?? w.slug), CTWBoDau.chuan(w.slug)]) != nil { ds.append((w.slug, w.name ?? w.slug)) }
        }
        return Array(ds.prefix(4)).map { (slug: $0.0, ten: $0.1) }
    }

    /// Người khớp tên: danh bạ Thành viên (mọi không gian) trước, rồi thành viên dự án đang chọn chưa có trong đó.
    private var nguoiKhop: [CTWUser] {
        let f = CTWBoDau.chuan(chu)
        guard f.count >= 2 else { return [] }
        var thay = Set<Int>()
        var ds: [CTWUser] = []
        for u in kho.danhBa.map(\.nguoi) + (cfg?.dsThanhVien ?? []) where !thay.contains(u.id) {
            thay.insert(u.id)
            if CTWKhopTim.diem(f, ten: [CTWBoDau.chuan(u.ten), CTWBoDau.chuan(u.username ?? "")]) != nil { ds.append(u) }
        }
        return Array(ds.prefix(5))
    }

    /// Thẻ khớp đúng mã đang gõ (đã có trong kết quả máy chủ) — để dòng "Chuyển tới" có tiêu đề.
    private var theTheoMa: CTWSearchItem? {
        guard let m = maGo else { return nil }
        let k = m.ma(app.luaChon?.maDuAn)?.uppercased()
        return (vm.theDuAn + vm.theKhac).first { ($0.key ?? "").uppercased() == k }
    }

    private var theDuAn: [CTWSearchItem] { vm.chuDaTim == chu ? vm.theDuAn.filter { $0.id != theTheoMa?.id } : [] }
    private var theKhac: [CTWSearchItem] { vm.chuDaTim == chu ? vm.theKhac.filter { $0.id != theTheoMa?.id }.prefix(max(0, 10 - theDuAn.count)).map { $0 } : [] }
    private var trang: [CTWTrangTim] { vm.chuDaTim == chu ? vm.trang : [] }

    private var khongCoGi: Bool {
        !chu.isEmpty && maGo == nil && chucNang.isEmpty && lenh.isEmpty && duAnKhop.isEmpty && khongGianKhop.isEmpty
            && nguoiKhop.isEmpty && theDuAn.isEmpty && theKhac.isEmpty && trang.isEmpty
    }

    // MARK: Giao diện

    var body: some View {
        VStack(spacing: 0) {
            oTim
            List {
                if chu.isEmpty { phanTrong } else { phanKetQua }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.defaultMinListRowHeight, 48)
        }
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .background {
            // ⌘K lần nữa ⇒ đóng (như web); Esc ⇒ nút Đóng (`.cancelAction`).
            Button("Close search") { dh.tamPhu = nil }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
        }
        .task { await vm.napNen() }
        .task { if kho.danhBa.isEmpty { await kho.taiDanhBa() } }
        .task(id: "\(chu)|\(app.luaChon?.maDuAn ?? "")") { await vm.tim(chu, maDuAn: app.luaChon?.maDuAn) }
        .task {
            // Tự đặt con trỏ vào ô tìm — đợi tấm phủ trượt lên xong (đặt sớm bị bỏ qua).
            try? await Task.sleep(nanoseconds: 350_000_000)
            dangGo = true
        }
        .onAppear { ganDay.nap() }
    }

    private var oTim: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                TextField(app.luaChon.map { String(localized: "Search \($0.maDuAn) and all features, issues, projects…") }
                          ?? String(localized: "Search features, issues, projects…"), text: $q)
                    .focused($dangGo)
                    .submitLabel(.go)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(moDauTien)
                    .accessibilityIdentifier("search.field")
                if vm.dangTim && !chu.isEmpty {
                    ProgressView().controlSize(.small)
                } else if !q.isEmpty {
                    Button { q = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Clear"))
                }
            }
            .font(.ctw(size: 16))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(AppColors.backgroundSecondary))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(dangGo ? AppColors.primary : AppColors.border, lineWidth: dangGo ? 1.2 : 0.5))
            Button("Close") { dh.tamPhu = nil }
                .keyboardShortcut(.cancelAction)
                .font(.ctw(size: 16, weight: .medium))
                .foregroundColor(AppColors.primary)
                .accessibilityIdentifier("search.close")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: Ô trống

    @ViewBuilder private var phanTrong: some View {
        let tim = Array(ganDay.ds.prefix(5))
        if !tim.isEmpty {
            Section {
                ForEach(tim, id: \.self) { s in
                    Button { q = s } label: {
                        hang(bieuTuong: "clock.arrow.circlepath", tieuDe: Text(verbatim: s), mauBieuTuong: AppColors.textTertiary) {
                            Image(systemName: "arrow.up.left").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .swipeActions { Button(role: .destructive) { ganDay.xoa(s) } label: { Label("Remove", systemImage: "trash") } }
                }
            } header: {
                HStack {
                    Text("Recent searches")
                    Spacer()
                    Button("Clear") { ganDay.xoa() }.font(.ctw(size: 13)).textCase(nil)
                }
            }
        }
        let the = theGanDay
        if !the.isEmpty {
            Section("Recently viewed") {
                ForEach(the) { t in
                    Button { chonDich("issue:\(t.ma)") { dh.moThe(slug: t.slug, ma: t.maDuAn, so: t.so) } } label: {
                        hangThe(ma: t.ma, tieuDe: t.tieuDe, phu: nil, loai: nil, trangThai: nil, nguoi: nil)
                    }
                }
            }
        }
        Section("Frequently used") {
            ForEach(hayDung) { m in nutMuc(m) }
        }
        Section("Commands") {
            ForEach(dsLenh) { m in nutMuc(m) }
        }
    }

    private var theGanDay: [TheGanDayCTW] {
        #if DEBUG
        if XemThuCTW.man?.lowercased() == "tim" { return DuLieuGiaTimKiem.theGanDay }
        #endif
        return Array(TheGanDayCTW.ds().prefix(5))
    }

    /// Hay dùng: theo số lần mở; chưa có gì ⇒ mô-đun đã ghim của dự án + My Work/Inbox.
    private var hayDung: [MucTimCTW] {
        let tat = tatCaChucNang
        let d = dem
        let co = tat.filter { (d[$0.id] ?? 0) > 0 }.sorted { (d[$0.id] ?? 0) > (d[$1.id] ?? 0) }
        var ds = Array(co.prefix(6))
        if ds.count < 6 {
            let ghim = CTWDangKyMoDun.daGhim(cfg).map { "mod:\($0.id)" } + ["app:mywork", "app:inbox"]
            for id in ghim where ds.count < 6 && !ds.contains(where: { $0.id == id }) {
                if let m = tat.first(where: { $0.id == id }) { ds.append(m) }
            }
        }
        return ds
    }

    // MARK: Kết quả

    @ViewBuilder private var phanKetQua: some View {
        if let m = maGo, let ma = m.ma(app.luaChon?.maDuAn) {
            Section("Jump to") {
                Button { moTheTheoMa(m) } label: {
                    if let t = theTheoMa {
                        hangThe(item: t)
                    } else {
                        hang(bieuTuong: "arrow.right.circle.fill", tieuDe: Text("Open \(ma)"), mauBieuTuong: AppColors.primary) { EmptyView() }
                    }
                }
                .accessibilityIdentifier("search.jump")
            }
        }
        if !chucNang.isEmpty {
            Section("Features & screens") {
                ForEach(moRongChucNang ? chucNang : Array(chucNang.prefix(8))) { m in nutMuc(m) }
                if chucNang.count > 8 && !moRongChucNang {
                    Button { moRongChucNang = true } label: {
                        Text("Show \(chucNang.count - 8) more").font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        if !lenh.isEmpty {
            Section("Commands") { ForEach(lenh) { m in nutMuc(m) } }
        }
        if !duAnKhop.isEmpty {
            Section("Projects") {
                ForEach(duAnKhop) { p in
                    Button { chonDuAn(p) } label: {
                        HStack(spacing: 12) {
                            CTWProjectMark(ma: p.key, co: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: p.name ?? p.key).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text(verbatim: [p.key, p.workspace?.name].compactMap { $0 }.joined(separator: " · "))
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if p.id == app.luaChon?.pid {
                                Text("Current").font(.ctw(size: 11, weight: .medium)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("search.project.\(p.key)")
                }
            }
        }
        if chu.count >= 2 {
            Section {
                ForEach(theDuAn + theKhac) { t in
                    Button { chonDich("issue:\(t.key ?? "")") { moItem(t) } } label: { hangThe(item: t) }
                        .accessibilityIdentifier("search.issue.\(t.key ?? "")")
                }
                if vm.chuDaTim == chu && vm.loi {
                    Text("Search failed. Try again.").font(.ctw(size: 14)).foregroundColor(AppColors.error)
                }
                Button { chonDich(nil) { dh.moTimMoiThe(chu) } } label: {
                    hang(bieuTuong: "text.magnifyingglass", tieuDe: Text("Search all issues for “\(chu)”"), mauBieuTuong: AppColors.textSecondary) {
                        if let n = vm.tongThe, vm.chuDaTim == chu {
                            Text(CTWDinhDang.so(n)).font(.ctw(size: 12).monospacedDigit()).foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .accessibilityIdentifier("search.allIssues")
            } header: { Text("Issues") }
        }
        if !trang.isEmpty {
            Section("Docs") {
                ForEach(trang) { p in
                    Button { chonDich("doc") { moTrang(p) } } label: {
                        HStack(spacing: 12) {
                            bieuTuongO("doc.text.fill", AppColors.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: p.title ?? String(localized: "Untitled")).font(.ctw(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text(verbatim: [p.project?.key, p.snippet].compactMap { $0 }.joined(separator: " · "))
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        if !nguoiKhop.isEmpty {
            Section {
                ForEach(nguoiKhop) { u in
                    let trongDanhBa = kho.thanhVien(u.id) != nil
                    let moc = kho.moc(u.id)
                    HStack(spacing: 8) {
                        // Chạm tên ⇒ hồ sơ (Thành viên: Nhắn tin · thẻ được giao · Chặn · Báo cáo); ngoài danh bạ ⇒ thẻ của họ.
                        Button { chonDich("person") { moNguoi(u) } } label: {
                            HStack(spacing: 12) {
                                AvatarHoatDongCTW(user: u, size: 30, moc: moc)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(verbatim: u.ten).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                        if u.laAgent { CTWNhanAI() }
                                    }
                                    Text(trongDanhBa ? phuNguoi(moc) : String(localized: "Open issues assigned to them"))
                                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.person.\(u.id)")
                        // Nhắn tin thẳng (chat 1-1) — không cho agent / chính mình.
                        if trongDanhBa, !u.laAgent, u.id != app.currentUser?.id {
                            Button { chonDich("person") { nhanTin(u) } } label: {
                                Image(systemName: "bubble.left.fill")
                                    .font(.ctw(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Text("Message \(u.ten)"))
                            .accessibilityIdentifier("search.dm.\(u.id)")
                        }
                    }
                }
            } header: { Text("Members") }
        }
        if !khongGianKhop.isEmpty {
            Section("Workspaces") {
                ForEach(khongGianKhop, id: \.slug) { w in
                    Button { chonDich("ws") { dh.moKhongGian(slug: w.slug) } } label: {
                        hang(bieuTuong: "building.2", tieuDe: Text(verbatim: w.ten), mauBieuTuong: AppColors.textSecondary) { EmptyView() }
                    }
                }
            }
        }
        if khongCoGi && !vm.dangTim && vm.chuDaTim == chu {
            Section {
                VStack(spacing: 6) {
                    Text("No results").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text("Try another word, an issue key like NW-12, or a feature name like “board” or “báo cáo”.")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .listRowBackground(Color.clear)
            }
        }
        if app.luaChon != nil, chu.count >= 2 {
            Section {
                Button { chonDich(nil) { dh.moJql(jqlChu) } } label: {
                    hang(bieuTuong: "line.3.horizontal.decrease.circle", tieuDe: Text("Advanced search (JQL)…"), mauBieuTuong: AppColors.textSecondary) {
                        Image(systemName: "chevron.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                    }
                }
                .accessibilityIdentifier("search.jql")
            } footer: {
                Text(verbatim: jqlChu).font(.ctw(size: 12).monospaced())
            }
        }
    }

    private var jqlChu: String { "text ~ \(CTWJql.boc(chu)) ORDER BY updated DESC" }

    // MARK: Hàng

    private func bieuTuongO(_ ten: String, _ mau: Color) -> some View {
        Image(systemName: ten)
            .font(.ctw(size: 14, weight: .semibold))
            .foregroundColor(mau)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(mau.opacity(0.12)))
            .accessibilityHidden(true)
    }

    private func hang<T: View>(bieuTuong: String, tieuDe: Text, phu: String? = nil, mauBieuTuong: Color, @ViewBuilder cuoi: () -> T) -> some View {
        HStack(spacing: 12) {
            bieuTuongO(bieuTuong, mauBieuTuong)
            VStack(alignment: .leading, spacing: 2) {
                tieuDe.font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                if let phu, !phu.isEmpty {
                    Text(verbatim: phu).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            cuoi()
        }
        .contentShape(Rectangle())
    }

    private func nutMuc(_ m: MucTimCTW) -> some View {
        Button { chonMuc(m) } label: {
            hang(bieuTuong: m.bieuTuong, tieuDe: Text(verbatim: m.ten), phu: m.moTa,
                 mauBieuTuong: m.nhom == .lenh ? AppColors.success : AppColors.primary) {
                if case .moDun(let id) = m.dich, let l = app.luaChon, CTWDangKyMoDun.moDun(id).map({ !$0.capUngDung }) == true {
                    Text(verbatim: l.maDuAn).font(.ctw(size: 11, weight: .semibold).monospaced()).foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .accessibilityIdentifier("search.row.\(m.id)")
    }

    private func hangThe(item t: CTWSearchItem) -> some View {
        hangThe(ma: t.key ?? "#\(t.number)", tieuDe: t.title, phu: t.project?.name, loai: t.type.map {
            CTWIssueType(id: 0, key: $0.key, name: $0.name ?? "", color: $0.color)
        }, trangThai: t.status, nguoi: t.assignee)
    }

    private func hangThe(ma: String, tieuDe: String, phu: String?, loai: CTWIssueType?, trangThai: CTWSearchItem.TrangThai?, nguoi: CTWUser?) -> some View {
        HStack(spacing: 10) {
            if let loai { CTWTypeIcon(type: loai, size: 16).frame(width: 30) } else { bieuTuongO("number", AppColors.textSecondary) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: ma).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                    if let phu { Text(verbatim: "· \(phu)").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1) }
                }
                Text(verbatim: tieuDe).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                if let s = trangThai, s.name != nil {
                    CTWStatusChip(ten: s.name, category: s.category)
                }
            }
            Spacer(minLength: 4)
            if let nguoi { CTWAvatar(user: nguoi, size: 24) }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    // MARK: Hành động

    /// Ghi "tìm gần đây" + đếm, rồi đóng tấm phủ và đi.
    private func chonDich(_ dem: String?, _ di: @escaping @MainActor () -> Void) {
        if chu.count >= 2 { ganDay.them(chu) }
        dh.dongRoi(di)
    }

    private func chonMuc(_ m: MucTimCTW) {
        if chu.count >= 2 { ganDay.them(chu) }
        DungNhieuCTW.dem(m.id)
        switch m.dich {
        case .moDun(let id): dh.dongRoi { dh.moMoDun(id) }
        case .viecCuaToi: dh.dongRoi { app.muc = .viecCuaToi }
        case .agenda:
            dh.dongRoi {
                UserDefaults.standard.set(1, forKey: "ctw.myWork.che")
                app.muc = .viecCuaToi
            }
        case .hopThu: dh.dongRoi { app.muc = .hopThu }
        case .taiKhoan: dh.dongRoi { app.muc = .taiKhoan }
        case .congCuKhac: dh.dongRoi { app.muc = .them }
        case .caiDatThongBao: dh.doiTamPhu(.caiDatThongBao)
        case .taoThe:
            if let cfg { dh.doiTamPhu(.taoThe(cfg)) }
        case .doiDuAn: dh.doiTamPhu(.chonDuAn)
        case .taoCuongMini: if let w = khongGianUuTien { dh.doiTamPhu(.taoCuongMini(w, nil)) }
        case .duAnMoi: if let w = khongGianUuTien { dh.doiTamPhu(.duAnMoi(w)) }
        case .ngonNgu(let c):
            // Đổi ngôn ngữ dựng lại cả cây (GocCTW `.id`) — đóng tấm phủ trước cho gọn.
            dh.dongRoi { NgonNguApCTW.shared.dat(c) }
        }
    }

    /// Không gian để tạo dự án: không gian đang mở nếu được phép, không thì cái đầu tiên được phép.
    private var khongGianUuTien: CTWWorkspace? {
        khongGianTao.first { $0.slug == app.luaChon?.slug } ?? khongGianTao.first
    }

    private func moItem(_ t: CTWSearchItem) {
        guard let slug = t.workspace?.slug ?? (t.project?.key == app.luaChon?.maDuAn ? app.luaChon?.slug : nil),
              let ma = t.project?.key else { return }
        dh.moThe(slug: slug, ma: ma, so: t.number)
    }

    private func moTheTheoMa(_ m: CTWMaTheGo) {
        if let t = theTheoMa { chonDich("issue") { moItem(t) }; return }
        let l = app.luaChon
        if let l, m.maDuAn == nil || m.maDuAn == l.maDuAn.uppercased() {
            chonDich("issue") { dh.moThe(slug: l.slug, ma: l.maDuAn, so: m.so) }
        } else if let k = m.ma(nil) {
            // Dự án khác chưa thấy trong kết quả ⇒ hỏi máy chủ không gian của mã đó (như `ctwork://issue/KEY-12`).
            chonDich("issue") { Task { await DinhTuyenCTW.moTheoKhoa(k) } }
        }
    }

    private func chonDuAn(_ p: CTWDuAnTim) {
        guard let w = p.workspace else { return }
        DungNhieuCTW.dem("project")
        chonDich(nil) {
            dh.moDuAn(LuaChonCTW(slug: w.slug, tenKhongGian: w.name ?? w.slug, pid: p.id, maDuAn: p.key, tenDuAn: p.name ?? p.key))
        }
    }

    private func moTrang(_ p: CTWTrangTim) {
        guard let ma = p.project?.key, let slug = p.project?.workspaceSlug ?? app.luaChon?.slug else { return }
        dh.moTrang(slug: slug, ma: ma, so: p.number)
    }

    /// Người trong danh bạ ⇒ hồ sơ ở Thành viên (có Nhắn tin + thẻ được giao). Ngoài danh bạ (chưa tải được) ⇒ List thẻ
    /// đang mở của người đó như trước.
    private func moNguoi(_ u: CTWUser) {
        if kho.thanhVien(u.id) != nil { kho.moHoSo(u.id); return }
        guard let un = u.username else { dh.moMoDun("team"); return }
        dh.moJql("assignee = \(CTWJql.boc(un)) AND statusCategory != Done ORDER BY updated DESC")
    }

    /// Mở (tạo nếu chưa có) hội thoại 1-1 rồi vào màn chat; lỗi ⇒ hồ sơ (ở đó có nút Nhắn tin + câu lỗi).
    private func nhanTin(_ u: CTWUser) {
        Task { @MainActor in
            do { kho.moHoiThoai(try await kho.moVoi(u.id).id) } catch { kho.moHoSo(u.id) }
        }
    }

    /// Dòng phụ của một người trong danh bạ: trạng thái hoạt động ("Đang hoạt động", "Hoạt động 5 phút trước"…) hoặc "Xem hồ sơ".
    private func phuNguoi(_ moc: TrangThaiHoatDongCTW.Moc) -> String {
        let c = TrangThaiHoatDongCTW.chu(moc)
        return c.isEmpty ? String(localized: "View profile") : c
    }

    /// Return trên bàn phím ⇒ mở kết quả đầu tiên (như Enter của web).
    private func moDauTien() {
        if let m = maGo, m.ma(app.luaChon?.maDuAn) != nil { moTheTheoMa(m); return }
        if let m = chucNang.first { chonMuc(m); return }
        if let m = lenh.first { chonMuc(m); return }
        if let p = duAnKhop.first { chonDuAn(p); return }
        if let t = (theDuAn + theKhac).first { chonDich("issue") { moItem(t) }; return }
        if chu.count >= 2 { chonDich(nil) { dh.moTimMoiThe(chu) } }
    }
}
