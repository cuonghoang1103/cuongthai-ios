import SwiftUI

// MARK: - CT Work — cổng vào module
//
// Hai phần: "My Work" (việc đang giao cho mình, mọi dự án) và "Projects"
// (không gian → dự án → bảng → thẻ). Chữ hiện ra bằng TIẾNG ANH.
//
// Điều hướng bằng `NavigationStack(path:)` để thông báo đẩy (`appState.
// ctWorkDich`) đẩy thẳng tới đúng thẻ được.

enum CTWRoute: Hashable {
    case khongGian(slug: String, ten: String)
    case bang(pid: Int, ten: String)
    /// Bảng mở theo mã (`/work/<ws>/<KEY>`) — phải tra id dự án trước.
    case bangTheoMa(slug: String, ma: String)
    case the(pid: Int, so: Int)
    /// Thẻ mở theo đường dẫn web — tra id dự án trước.
    case theTheoMa(slug: String, ma: String, so: Int)
}

struct CTWorkView: View {
    /// `true` khi mở dạng tấm phủ toàn màn (iPhone) — cần nút Close.
    var coNutDong = false

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dong
    @State private var duong: [CTWRoute] = []
    @State private var phan: Phan = .myWork

    enum Phan: String, CaseIterable, Identifiable {
        case myWork = "My Work", projects = "Projects"
        var id: String { rawValue }
        var ten: String { self == .myWork ? String(localized: "My Work") : String(localized: "Projects") }
    }

    var body: some View {
        NavigationStack(path: $duong) {
            VStack(spacing: 0) {
                Picker("Section", selection: $phan) {
                    ForEach(Phan.allCases) { Text($0.ten).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)

                switch phan {
                case .myWork: CTWMyWorkView()
                case .projects: CTWWorkspacesView()
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("CT Work")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if coNutDong {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dong() }
                    }
                }
            }
            .navigationDestination(for: CTWRoute.self) { r in
                switch r {
                case .khongGian(let slug, let ten): CTWWorkspaceView(slug: slug, ten: ten)
                case .bang(let pid, let ten): CTWBoardView(pid: pid, ten: ten)
                case .bangTheoMa(let slug, let ma):
                    CTWResolver(slug: slug, ma: ma) { pid in CTWBoardView(pid: pid, ten: ma) }
                case .the(let pid, let so): CTWIssueView(pid: pid, so: so)
                case .theTheoMa(let slug, let ma, let so):
                    CTWResolver(slug: slug, ma: ma) { pid in CTWIssueView(pid: pid, so: so) }
                }
            }
        }
        // Đích từ thông báo đẩy. `.task(id:)` chứ không `.onChange`: cờ có
        // thể được đặt TRƯỚC khi màn này tồn tại (mở nguội từ thông báo).
        .task(id: appState.ctWorkDich) {
            guard let d = appState.ctWorkDich else { return }
            appState.ctWorkDich = nil
            if let ma = d.maDuAn, let so = d.so {
                duong = [.theTheoMa(slug: d.slug, ma: ma, so: so)]
            } else if let ma = d.maDuAn {
                duong = [.bangTheoMa(slug: d.slug, ma: ma)]
            } else {
                phan = .projects
                duong = [.khongGian(slug: d.slug, ten: d.slug)]
            }
        }
    }
}

// MARK: - Tra id dự án từ slug + mã

struct CTWResolver<Noi: View>: View {
    let slug: String
    let ma: String
    @ViewBuilder let noiDung: (Int) -> Noi

    @State private var pid: Int?
    @State private var loi: String?

    var body: some View {
        Group {
            if let pid {
                noiDung(pid)
            } else if let loi {
                VStack(spacing: Spacing.md) {
                    CTWErrorBanner(text: loi)
                    Button("Try again") { Task { await tra() } }
                        .buttonStyle(.bordered)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .task { if pid == nil { await tra() } }
    }

    private func tra() async {
        loi = nil
        do {
            let r: CTWResolve = try await APIClient.shared.request(.workTimDuAn(slug: slug, ma: ma))
            pid = r.projectId
        } catch {
            loi = CTW.loi(error)
        }
    }
}

// MARK: - My Work

@MainActor
final class CTWMyWorkVM: ObservableObject {
    @Published var duLieu: CTWMyWork?
    @Published var dangTai = false
    @Published var loi: String?

    func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            duLieu = try await APIClient.shared.request(.workViecCuaToi)
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    /// Nhóm theo thứ tự cấp bách. Một thẻ chỉ nằm ở MỘT nhóm — nhóm đầu tiên nó khớp.
    var nhom: [(ten: String, mau: Color, items: [CTWMyWorkItem])] {
        let items = duLieu?.items ?? []
        var daXep = Set<String>()
        func lay(_ dk: (CTWMyWorkItem) -> Bool) -> [CTWMyWorkItem] {
            let r = items.filter { !daXep.contains($0.key) && dk($0) }
            r.forEach { daXep.insert($0.key) }
            return r
        }
        let out: [(String, Color, [CTWMyWorkItem])] = [
            (String(localized: "Overdue"), AppColors.error, lay { $0.bucket == "overdue" }),
            (String(localized: "Due today"), AppColors.warning, lay { $0.bucket == "today" }),
            (String(localized: "Due soon"), AppColors.accent, lay { $0.bucket == "soon" }),
            (String(localized: "In progress"), AppColors.info, lay { $0.status?.category == "IN_PROGRESS" }),
            (String(localized: "Other"), AppColors.textTertiary, lay { _ in true }),
        ]
        return out.filter { !$0.2.isEmpty }.map { (ten: $0.0, mau: $0.1, items: $0.2) }
    }
}

struct CTWMyWorkView: View {
    @StateObject private var vm = CTWMyWorkVM()

    var body: some View {
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if let c = vm.duLieu?.counts {
                demSo(c)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if vm.duLieu != nil && vm.nhom.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.ctw(size: 34, weight: .semibold)).foregroundColor(AppColors.success)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(AppColors.success.opacity(0.12)))
                        .padding(.bottom, 4)
                    Text("Nothing assigned to you")
                        .font(.ctw(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text("Open issues assigned to you in any project show up here.")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(vm.nhom, id: \.ten) { n in
                Section {
                    ForEach(n.items) { item in hang(item) }
                } header: {
                    HStack(spacing: 6) {
                        Circle().fill(n.mau).frame(width: 8, height: 8)
                        Text(n.ten)
                        Text("\(n.items.count)").foregroundColor(AppColors.textTertiary)
                    }
                    .font(.ctw(size: 13, weight: .semibold))
                }
            }
        }
        .ctwKieuDanhSach()
        .scrollContentBackground(.hidden)
        .overlay {
            if vm.dangTai && vm.duLieu == nil && vm.loi == nil { ProgressView() }
        }
        .refreshable { await vm.tai() }
        .task { if vm.duLieu == nil { await vm.tai() } }
    }

    private func demSo(_ c: CTWMyWorkCounts) -> some View {
        HStack(spacing: Spacing.sm) {
            o("Overdue", "exclamationmark.circle.fill", c.overdue ?? 0, AppColors.error)
            o("Today", "sun.max.fill", c.dueToday ?? 0, AppColors.warning)
            o("Soon", "clock.fill", c.dueSoon ?? 0, AppColors.accent)
            o("In progress", "arrow.triangle.2.circlepath", c.inProgress ?? 0, AppColors.info)
        }
    }

    private func o(_ ten: LocalizedStringKey, _ icon: String, _ so: Int, _ mau: Color) -> some View {
        let dang = so > 0
        return VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.ctw(size: 13, weight: .semibold))
                .foregroundColor(dang ? mau : AppColors.textTertiary)
            Text("\(so)").font(.ctw(size: 22, weight: .bold).monospacedDigit())
                .foregroundColor(dang ? mau : AppColors.textTertiary)
            Text(ten).font(.ctw(size: 10.5, weight: .medium)).foregroundColor(AppColors.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(dang ? mau.opacity(0.10) : AppColors.backgroundCard)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(dang ? mau.opacity(0.25) : AppColors.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ten): \(so)")
    }

    @ViewBuilder
    private func maTrangThai(_ item: CTWMyWorkItem) -> some View {
        HStack(spacing: 8) {
            Text(item.key).font(.ctw(size: 12, weight: .semibold).monospaced())
                .foregroundColor(AppColors.textSecondary).fixedSize()
            CTWPriorityIcon(priority: item.priority)
            if let s = item.status?.name {
                HStack(spacing: 4) {
                    Circle().fill(CTW.mauNhom(item.status?.category)).frame(width: 5, height: 5)
                    Text(s).font(.ctw(size: 11, weight: .semibold))
                        .foregroundColor(CTW.mauNhom(item.status?.category)).fixedSize()
                }
            }
        }
    }

    @ViewBuilder private func hanThe(_ item: CTWMyWorkItem) -> some View {
        if let d = CTW.ngayNgan(item.dueDate) {
            let tre = item.bucket == "overdue"
            // HStack chứ không `Label`: Label trong hàng List co lại thành CHỈ biểu tượng khi chật (mất ngày).
            HStack(spacing: 3) {
                Image(systemName: "calendar").accessibilityHidden(true)
                Text(d)
            }
            .font(.ctw(size: 11, weight: tre ? .semibold : .regular))
            .foregroundColor(tre ? AppColors.error : AppColors.textSecondary)
            .fixedSize()
            .accessibilityLabel("Due \(d)")
        }
    }

    @ViewBuilder
    private func hang(_ item: CTWMyWorkItem) -> some View {
        let noiDung = HStack(alignment: .top, spacing: 11) {
            Image(systemName: CTW.bieuTuongLoai(key: item.type?.key))
                .font(.ctw(size: 10, weight: .bold)).foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(CTW.mau(item.type?.color, macDinh: AppColors.info)))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                // Chữ lớn (Dynamic Type) ⇒ một hàng không đủ chỗ: xuống hai hàng thay vì cắt "Oct 18" thành "ct 18".
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        maTrangThai(item)
                        Spacer(minLength: 0)
                        hanThe(item)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        maTrangThai(item)
                        hanThe(item)
                    }
                }
            }
        }
        .padding(.vertical, 4)

        if let slug = item.workspace?.slug, let ma = item.project?.key {
            NavigationLink(value: CTWRoute.theTheoMa(slug: slug, ma: ma, so: item.number)) { noiDung }
        } else {
            noiDung
        }
    }
}

// MARK: - Không gian

@MainActor
final class CTWWorkspacesVM: ObservableObject {
    @Published var ds: [CTWWorkspace]?
    @Published var loi: String?
    @Published var dangTai = false

    func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            ds = try await APIClient.shared.request(.workDsKhongGian)
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }
}

struct CTWWorkspacesView: View {
    @StateObject private var vm = CTWWorkspacesVM()

    var body: some View {
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if let ds = vm.ds, ds.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.ctw(size: 32, weight: .semibold)).foregroundColor(AppColors.primary)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(AppColors.primary.opacity(0.12)))
                        .padding(.bottom, 4)
                    Text("No workspaces yet")
                        .font(.ctw(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text("When a teammate invites you to a CT Work workspace, it appears here.")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(vm.ds ?? []) { ws in
                NavigationLink(value: CTWRoute.khongGian(slug: ws.slug, ten: ws.name)) {
                    HStack(spacing: 13) {
                        Text(String(ws.name.prefix(1)).uppercased())
                            .font(.ctw(size: 17, weight: .bold)).foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LinearGradient(colors: [AppColors.primaryLight, AppColors.primary],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ws.name).font(.ctw(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Text(moTa(ws)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .ctwKieuDanhSach()
        .scrollContentBackground(.hidden)
        .overlay { if vm.dangTai && vm.ds == nil && vm.loi == nil { ProgressView() } }
        .refreshable { await vm.tai() }
        .task { if vm.ds == nil { await vm.tai() } }
    }

    private func moTa(_ ws: CTWWorkspace) -> String {
        var p: [String] = []
        if let n = ws.projectCount { p.append(n == 1 ? String(localized: "1 project") : String(localized: "\(n) projects")) }
        if let n = ws.memberCount { p.append(n == 1 ? String(localized: "1 member") : String(localized: "\(n) members")) }
        if let r = ws.role { p.append(r.capitalized) }
        return p.joined(separator: " · ")
    }
}

struct CTWWorkspaceView: View {
    let slug: String
    let ten: String

    @State private var ws: CTWWorkspaceDetail?
    @State private var loi: String?

    var body: some View {
        List {
            if let loi {
                CTWErrorBanner(text: loi).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if let mt = ws?.description, !mt.isEmpty {
                Text(mt).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    .listRowBackground(Color.clear)
            }
            let ds = (ws?.projects ?? []).filter { $0.archivedAt == nil }
            if ws != nil && ds.isEmpty {
                Text("No projects in this workspace yet.")
                    .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    .listRowBackground(Color.clear)
            }
            Section(ds.isEmpty ? "" : "Projects") {
                ForEach(ds) { p in
                    NavigationLink(value: CTWRoute.bang(pid: p.id, ten: p.name)) {
                        HStack(spacing: 12) {
                            Text(p.key)
                                .font(.ctw(size: 11, weight: .bold).monospaced())
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, 7).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.name).font(.ctw(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                Text(moTa(p)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .ctwKieuDanhSach()
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .navigationTitle(ws?.name ?? ten)
        .overlay { if ws == nil && loi == nil { ProgressView() } }
        .refreshable { await tai() }
        .task { if ws == nil { await tai() } }
    }

    private func moTa(_ p: CTWProjectSummary) -> String {
        var s: [String] = []
        if let t = p.type { s.append(t.capitalized) }
        if let n = p.openIssues { s.append(n == 1 ? String(localized: "1 open issue") : String(localized: "\(n) open issues")) }
        if let r = p.role { s.append(r.capitalized) }
        return s.joined(separator: " · ")
    }

    private func tai() async {
        do {
            ws = try await APIClient.shared.request(.workKhongGian(slug: slug))
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }
}
