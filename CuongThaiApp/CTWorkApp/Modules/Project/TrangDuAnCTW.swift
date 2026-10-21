import SwiftUI

// MARK: - Trang dự án (tab Projects trên iPhone)
//
// 20/10/2026 — phản hồi chủ app: "web và app desktop có bảng kéo thả từng task, sao ở đây không có?". Bảng CÓ, nhưng
// nằm ở Projects → dự án → dòng "Board" nên không ai tìm thấy. Giờ mở tab Projects là VÀO THẲNG dự án như web:
//   · Đầu trang: dấu + tên dự án là một MENU (đổi nhanh giữa dự án gần đây, "All projects…", mở trên web).
//   · Dưới: công tắc Board · Backlog · List · More (nhớ lựa chọn). Board là mặc định.
//   · More = mô-đun đã ghim khác (AI, Chat, Docs, Meetings…) + "More tools" (như trước 20/10).
// Thêm mô-đun mới KHÔNG phải sửa tệp này.

struct TrangDuAnCTW: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    /// MỘT tấm phủ cho cả màn (bẫy C5: hai `.sheet` cùng view chỉ cái cuối chạy).
    @State private var tamPhu: TamPhu?
    private enum TamPhu: String, Identifiable { case chonDuAn, web; var id: String { rawValue } }

    @AppStorage("ctw.duAn.che") private var che: CheDo = .board
    @ObservedObject private var ganDay = DuAnGanDayCTW.shared

    enum CheDo: String, CaseIterable, Identifiable {
        case board, backlog, list, more
        var id: String { rawValue }
        var ten: LocalizedStringKey {
            switch self {
            case .board: return "Board"
            case .backlog: return "Backlog"
            case .list: return "List"
            case .more: return "More"
            }
        }
    }

    var body: some View {
        Group {
            if let l = app.luaChon {
                VStack(spacing: 0) {
                    Picker("Project view", selection: $che) {
                        ForEach(CheDo.allCases) { c in Text(c.ten).tag(c) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("project.views")
                    .onChange(of: che) { _, _ in CTWRung.chon() }

                    switch che {
                    case .board: CTWBoardView(pid: l.pid, ten: l.tenDuAn).id("board-\(l.pid)")
                    case .backlog: BacklogCTW(pid: l.pid, cheDoDau: .backlog, nhung: true).id("backlog-\(l.pid)")
                    case .list: BacklogCTW(pid: l.pid, cheDoDau: .tatCa, nhung: true).id("list-\(l.pid)")
                    case .more: congCu(l)
                    }
                }
                .background(AppColors.backgroundPrimary)
                .navigationTitle(l.tenDuAn)
                .ctwTieuDeNho()
                .toolbar {
                    ToolbarItem(placement: .principal) { menuDuAn(l) }
                }
            } else {
                ChuaChonDuAnCTW(lyDo: String(localized: "Pick the workspace and project you want to work on. CT Work remembers your choice."))
                    .navigationTitle("Projects")
            }
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .chonDuAn: ChonDuAnCTW()
            case .web:
                if let l = app.luaChon, let u = URL(string: "\(APIClient.diaChiGoc)/work/\(CTWAPI.doan(l.slug))/\(CTWAPI.doan(l.maDuAn))") {
                    SafariCTW(url: u).ignoresSafeArea()
                }
            }
        }
        // Đích chờ của một mô-đun trong trang này (vd trang tài liệu từ thông báo). Board/Backlog ⇒ đổi công tắc;
        // mô-đun khác ⇒ đẩy màn mô-đun (mô-đun tự mở phần con rồi xoá cờ).
        .task(id: app.dichCho) {
            guard let d = app.dichCho, let m = CTWDangKyMoDun.moDun(d.moDun), m.viTriIPhone == .trangDuAn else { return }
            if m.id == "board" || m.id == "backlog" {
                // `/backlog/list` (màn Tìm mọi thứ › Tìm nâng cao JQL, Thành viên) ⇒ công tắc List.
                che = m.id == "board" ? .board : (d.duongDan.phanCon.first == "list" ? .list : .backlog)
                nganXep.duong = NavigationPath()
                app.dichCho = nil
                return
            }
            var p = NavigationPath()
            p.append(RouteMoDunCTW(id: m.id))
            nganXep.duong = p
        }
        #if DEBUG
        .onAppear {
            switch XemThuCTW.man?.lowercased() {
            case "board", "mod:board": che = .board
            case "backlog", "mod:backlog": che = .backlog
            case "list": che = .list
            case "duan": che = .more
            default: break
            }
            if let id = XemThuCTW.moDunMoSan, id != "board", id != "backlog", nganXep.duong.isEmpty {
                nganXep.duong.append(RouteMoDunCTW(id: id))
            }
            if XemThuCTW.man == "them", nganXep.duong.isEmpty { nganXep.duong.append(RouteThemCTW()) }
        }
        #endif
    }

    // MARK: Đầu trang — menu dự án

    private func menuDuAn(_ l: LuaChonCTW) -> some View {
        Menu {
            let khac = ganDay.ds.filter { $0.pid != l.pid }
            if !khac.isEmpty {
                Section("Recent projects") {
                    ForEach(khac, id: \.pid) { g in
                        Button { app.luaChon = g } label: {
                            Label {
                                Text(verbatim: "\(g.tenDuAn) · \(g.maDuAn)")
                            } icon: { Image(systemName: "clock.arrow.circlepath") }
                        }
                    }
                }
            }
            Button { tamPhu = .chonDuAn } label: { Label("All projects…", systemImage: "rectangle.3.group") }
            Button { tamPhu = .web } label: { Label("Open on the web", systemImage: "safari") }
        } label: {
            HStack(spacing: 7) {
                CTWProjectMark(ma: l.maDuAn, co: 22)
                Text(l.tenDuAn)
                    .font(.ctw(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.ctw(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: 260)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Project: \(l.tenDuAn)"))
        .accessibilityHint(Text("Switch project"))
        .accessibilityIdentifier("project.switch")
    }

    // MARK: More — mô-đun đã ghim khác + More tools

    @ObservedObject private var ghim = GhimMoDunCTW.shared

    /// Mô-đun đã ghim, thuộc trang dự án, trừ Board/Backlog (đã có trên công tắc). Chat là tab riêng trên iPhone.
    private var ghimDuoc: [CTWModule] {
        CTWDangKyMoDun.daGhim(app.cauHinhDuAn).filter { $0.viTriIPhone == .trangDuAn && $0.id != "board" && $0.id != "backlog" }
    }

    private func congCu(_ l: LuaChonCTW) -> some View {
        List {
            Section { dau(l) }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            Section {
                ForEach(ghimDuoc) { m in
                    NavigationLink(value: RouteMoDunCTW(id: m.id)) { hang(m) }
                }
                NavigationLink(value: RouteThemCTW()) {
                    HStack(spacing: 13) {
                        Image(systemName: "square.grid.2x2")
                            .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.backgroundTertiary))
                        Text("More tools").font(.ctw(size: 16, weight: .medium)).foregroundColor(AppColors.textPrimary)
                        Spacer(minLength: 0)
                        let n = CTWDangKyMoDun.soConLai(app.cauHinhDuAn)
                        if n > 0 { Text("\(n)").font(.ctw(size: 14).monospacedDigit()).foregroundColor(AppColors.textTertiary) }
                    }
                    .padding(.vertical, 3)
                }
                .accessibilityIdentifier("project.more")
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .refreshable { await app.napCauHinhDuAn() }
    }

    private func dau(_ l: LuaChonCTW) -> some View {
        HStack(spacing: 14) {
            CTWProjectMark(ma: l.maDuAn, co: 48, caMa: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tenDuAn).font(.ctw(size: 18, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(moTaDuAn(l)).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Button { tamPhu = .chonDuAn } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.ctw(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppColors.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .foregroundColor(AppColors.primary)
            .accessibilityLabel("Switch project")
        }
        .padding(14)
        .ctwThe(14)
        .padding(.vertical, 4)
    }

    private func moTaDuAn(_ l: LuaChonCTW) -> String {
        var p = [l.tenKhongGian]
        if let t = app.cauHinhDuAn?.type { p.append(CTWMauTrangThai.nhan(t)) }
        if let r = app.cauHinhDuAn?.role { p.append(CTWMauTrangThai.nhan(r)) }
        return p.joined(separator: " · ")
    }

    private func hang(_ m: CTWModule) -> some View {
        HStack(spacing: 13) {
            Image(systemName: m.bieuTuong)
                .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(m.ten).font(.ctw(size: 16, weight: .medium)).foregroundColor(AppColors.textPrimary)
                if !m.moTa.isEmpty {
                    Text(m.moTa).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Dự án gần đây (đổi nhanh ở đầu trang + mục "Recent" trong bảng chọn dự án)

@MainActor
final class DuAnGanDayCTW: ObservableObject {
    static let shared = DuAnGanDayCTW()
    private static let khoa = "com.cuongthai.ctwork.duAnGanDay"
    private static let toiDa = 6

    @Published private(set) var ds: [LuaChonCTW]

    private init() {
        ds = (UserDefaults.standard.data(forKey: Self.khoa)).flatMap { try? JSONDecoder().decode([LuaChonCTW].self, from: $0) } ?? []
    }

    /// Gọi từ `didSet` của `AppState.luaChon` — chỉ chạm UserDefaults (KHÔNG đọc `AppState.shared`).
    nonisolated static func ghi(_ l: LuaChonCTW?) {
        guard let l else { return }
        Task { @MainActor in shared.them(l) }
    }

    nonisolated static func xoaHet() {
        Task { @MainActor in
            shared.ds = []
            UserDefaults.standard.removeObject(forKey: khoa)
        }
    }

    private func them(_ l: LuaChonCTW) {
        var m = ds.filter { $0.pid != l.pid }
        m.insert(l, at: 0)
        ds = Array(m.prefix(Self.toiDa))
        if let d = try? JSONEncoder().encode(ds) { UserDefaults.standard.set(d, forKey: Self.khoa) }
    }
}
