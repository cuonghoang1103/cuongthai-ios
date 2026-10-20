import SwiftUI

// MARK: - Chọn không gian + dự án (nhớ lựa chọn)

@MainActor
final class ChonDuAnVM: ObservableObject {
    @Published var nhom: [(ws: CTWWorkspace, duAn: [CTWProjectSummary])] = []
    @Published var dangTai = false
    @Published var loi: String?
    @Published var daTai = false

    func tai() async {
        dangTai = true
        defer { dangTai = false; daTai = true }
        do {
            let ds: [CTWWorkspace] = try await APIClient.shared.request(.workDsKhongGian)
            var kq: [(CTWWorkspace, [CTWProjectSummary])] = []
            try await withThrowingTaskGroup(of: (Int, CTWWorkspaceDetail?).self) { g in
                for (i, ws) in ds.enumerated() {
                    g.addTask {
                        let d: CTWWorkspaceDetail? = try? await APIClient.shared.request(.workKhongGian(slug: ws.slug))
                        return (i, d)
                    }
                }
                var chiTiet: [Int: CTWWorkspaceDetail] = [:]
                for try await (i, d) in g { if let d { chiTiet[i] = d } }
                for (i, ws) in ds.enumerated() {
                    kq.append((ws, (chiTiet[i]?.projects ?? []).filter { $0.archivedAt == nil }))
                }
            }
            nhom = kq.map { (ws: $0.0, duAn: $0.1) }
            CTWChiaSeNhom.ghiDuAn(nhom, macDinh: AppState.shared.luaChon?.pid)
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }
}

struct ChonDuAnCTW: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @StateObject private var vm = ChonDuAnVM()
    @ObservedObject private var ganDay = DuAnGanDayCTW.shared
    @State private var tim = ""

    /// Dự án gần đây còn tồn tại (đối chiếu danh sách vừa tải — dự án đã lưu trữ/bị rời thì bỏ).
    private var dsGanDay: [(ws: CTWWorkspace, p: CTWProjectSummary)] {
        guard tim.isEmpty else { return [] }
        return ganDay.ds.compactMap { g in
            for n in vm.nhom { if let p = n.duAn.first(where: { $0.id == g.pid }) { return (n.ws, p) } }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let loi = vm.loi {
                    CTWErrorBanner(text: loi).listRowBackground(Color.clear)
                }
                if vm.daTai && vm.nhom.isEmpty && vm.loi == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group").font(.ctw(size: 30)).foregroundColor(AppColors.primary)
                        Text("No workspaces yet").font(.headline)
                        Text("When a teammate invites you to a CT Work workspace, it shows up here.")
                            .font(.subheadline).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
                    .listRowBackground(Color.clear)
                }
                // 20/10/2026: dự án gần đây lên đầu — người làm nhiều dự án (SWP, LAB, đồ án) đổi qua lại một chạm.
                if !dsGanDay.isEmpty {
                    Section {
                        ForEach(dsGanDay, id: \.p.id) { g in
                            Button { chon(g.ws, g.p) } label: { hang(g.p, chon: app.luaChon?.pid == g.p.id, khongGian: g.ws.name) }
                                .buttonStyle(.plain)
                        }
                    } header: {
                        Label("Recent", systemImage: "clock.arrow.circlepath").textCase(nil)
                    }
                }
                ForEach(vm.nhom, id: \.ws.id) { n in
                    let ds = n.duAn.filter { tim.isEmpty || $0.name.localizedCaseInsensitiveContains(tim) || $0.key.localizedCaseInsensitiveContains(tim) }
                    if !ds.isEmpty || tim.isEmpty {
                        Section {
                            if ds.isEmpty {
                                Text("No projects").foregroundColor(AppColors.textTertiary)
                            }
                            ForEach(ds) { p in
                                Button { chon(n.ws, p) } label: { hang(p, chon: app.luaChon?.pid == p.id) }
                                    .buttonStyle(.plain)
                            }
                        } header: {
                            HStack(spacing: 7) {
                                Text(String(n.ws.name.prefix(1)).uppercased())
                                    .font(.ctw(size: 11, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(CTWKieuWeb.mau(n.ws.slug)))
                                    .accessibilityHidden(true)
                                Text(verbatim: n.ws.name).foregroundColor(AppColors.textPrimary)
                                if let r = n.ws.role { Text(verbatim: "· \(CTWMauTrangThai.nhan(r))").foregroundColor(AppColors.textTertiary) }
                            }
                            .font(.ctw(size: 13, weight: .semibold))
                            .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $tim, prompt: "Find a project")
            .overlay { if vm.dangTai && vm.nhom.isEmpty { CTWKhungTai(soHang: 4, coAvatar: false) } }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } }
            }
            .refreshable { await vm.tai() }
            .task { if !vm.daTai { await vm.tai() } }
        }
    }

    private func hang(_ p: CTWProjectSummary, chon: Bool, khongGian: String? = nil) -> some View {
        HStack(spacing: 12) {
            CTWProjectMark(ma: p.key, co: 38, caMa: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                Text([khongGian, p.type.map { CTWMauTrangThai.nhan($0) }, p.openIssues.map { $0 == 1 ? String(localized: "1 open issue") : String(localized: "\($0) open issues") }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if chon {
                Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.primary)
                    .accessibilityLabel(Text("Current project"))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func chon(_ ws: CTWWorkspace, _ p: CTWProjectSummary) {
        app.luaChon = LuaChonCTW(slug: ws.slug, tenKhongGian: ws.name, pid: p.id, maDuAn: p.key, tenDuAn: p.name)
        dong()
    }
}
