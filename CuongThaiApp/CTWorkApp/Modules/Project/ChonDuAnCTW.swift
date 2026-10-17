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
    @State private var tim = ""

    var body: some View {
        NavigationStack {
            List {
                if let loi = vm.loi {
                    CTWErrorBanner(text: loi).listRowBackground(Color.clear)
                }
                if vm.daTai && vm.nhom.isEmpty && vm.loi == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group").font(.system(size: 30)).foregroundColor(AppColors.primary)
                        Text("No workspaces yet").font(.headline)
                        Text("When a teammate invites you to a CT Work workspace, it shows up here.")
                            .font(.subheadline).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
                    .listRowBackground(Color.clear)
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
                            HStack(spacing: 6) {
                                Text(n.ws.name)
                                if let r = n.ws.role { Text("· \(r.capitalized)").foregroundColor(AppColors.textTertiary) }
                            }
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

    private func hang(_ p: CTWProjectSummary, chon: Bool) -> some View {
        HStack(spacing: 12) {
            Text(p.key)
                .font(.system(size: 11, weight: .bold).monospaced())
                .foregroundColor(AppColors.primary)
                .frame(minWidth: 44)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text([p.type?.capitalized, p.openIssues.map { $0 == 1 ? "1 open issue" : "\($0) open issues" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            if chon { Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.primary) }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func chon(_ ws: CTWWorkspace, _ p: CTWProjectSummary) {
        app.luaChon = LuaChonCTW(slug: ws.slug, tenKhongGian: ws.name, pid: p.id, maDuAn: p.key, tenDuAn: p.name)
        dong()
    }
}
