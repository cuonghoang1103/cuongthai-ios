import SwiftUI

// MARK: - Màn Reports: thanh tab chip + nội dung từng báo cáo
//
// Cùng bộ báo cáo với web `app/work/[ws]/[key]/reports` (Health/Burndown/Velocity/Flow/…),
// dựng bằng Swift Charts. Tab "People vs Agents" chỉ hiện khi dự án có AI agent.
// Deep link `/work/<ws>/<KEY>/reports?tab=<id>` mở đúng tab.

enum TabBaoCaoCTW: String, CaseIterable, Hashable {
    case tongQuan = "overview", burndown, velocity, flow, taoXong = "created", phanBo = "distribution", epics, thoiGian = "time", agents

    var ten: String {
        switch self {
        case .tongQuan: return String(localized: "Overview")
        case .burndown: return String(localized: "Burndown")
        case .velocity: return String(localized: "Velocity")
        case .flow: return String(localized: "Flow")
        case .taoXong: return String(localized: "Created vs resolved")
        case .phanBo: return String(localized: "Distribution")
        case .epics: return String(localized: "Epics")
        case .thoiGian: return String(localized: "Time")
        case .agents: return String(localized: "People vs Agents")
        }
    }
    var bieuTuong: String {
        switch self {
        case .tongQuan: return "heart.text.square"
        case .burndown: return "chart.line.downtrend.xyaxis"
        case .velocity: return "chart.bar"
        case .flow: return "water.waves"
        case .taoXong: return "arrow.left.arrow.right"
        case .phanBo: return "chart.bar.doc.horizontal"
        case .epics: return "bolt.horizontal"
        case .thoiGian: return "clock"
        case .agents: return "sparkles"
        }
    }

    /// Tên tab web (`?tab=`) → tab app.
    static func tuWeb(_ s: String?) -> TabBaoCaoCTW? {
        switch s {
        case "health", "overview": return .tongQuan
        case "burndown": return .burndown
        case "velocity": return .velocity
        case "flow": return .flow
        case "created": return .taoXong
        case "distribution": return .phanBo
        case "epics": return .epics
        case "time": return .thoiGian
        case "agents": return .agents
        default: return nil
        }
    }
}

struct BaoCaoCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var tab: TabBaoCaoCTW = .tongQuan
    @State private var lamMoi = 0
    @State private var sprints: [CTWSprintDu] = []

    private var pid: Int { nguCanh.pid }
    private var cfg: CTWProjectConfig? { app.cauHinhDuAn }
    private var coAgent: Bool { cfg?.dsThanhVien.contains(where: \.laAgent) == true }
    private var cacTab: [TabBaoCaoCTW] {
        TabBaoCaoCTW.allCases.filter { t in
            if t == .agents { return coAgent }
            if t == .burndown || t == .velocity { return cfg?.type != "KANBAN" }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ThanhTabCTW(tab: cacTab.map { (id: $0, ten: $0.ten, bieuTuong: $0.bieuTuong) }, chon: $tab)
                .padding(.vertical, 6)
            Divider()
            ScrollView {
                noiDung
                    .padding(Spacing.md)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
            }
            .refreshable { lamMoi += 1 }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if sprints.isEmpty, let ds: [CTWSprintDu] = try? await APIClient.shared.request(CTWAPI.dsSprint(pid: pid)) {
                sprints = TinhSprintCTW.sap(ds).filter { !$0.chuaBatDau }
            }
        }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "reports" else { return }
            defer { app.dichCho = nil }
            if let t = TabBaoCaoCTW.tuWeb(d.duongDan.tham["tab"]), cacTab.contains(t) { tab = t }
        }
        #if DEBUG
        .onAppear { if let c = XemThuCTW.conCua("reports"), let t = TabBaoCaoCTW.tuWeb(c) { tab = t } }
        #endif
    }

    @ViewBuilder private var noiDung: some View {
        let rong = beRong == .regular
        switch tab {
        case .tongQuan: TabTongQuanBaoCaoCTW(pid: pid, lamMoi: lamMoi, rong: rong)
        case .burndown: TabBurndownBaoCaoCTW(pid: pid, sprints: sprints, lamMoi: lamMoi, rong: rong)
        case .velocity: TabVelocityBaoCaoCTW(pid: pid, lamMoi: lamMoi)
        case .flow: TabFlowBaoCaoCTW(pid: pid, lamMoi: lamMoi, rong: rong)
        case .taoXong: TabTaoXongBaoCaoCTW(pid: pid, lamMoi: lamMoi)
        case .phanBo: TabPhanBoBaoCaoCTW(pid: pid, lamMoi: lamMoi, rong: rong)
        case .epics: TabEpicsBaoCaoCTW(pid: pid, lamMoi: lamMoi)
        case .thoiGian: TabThoiGianBaoCaoCTW(pid: pid, lamMoi: lamMoi)
        case .agents: TabAgentsBaoCaoCTW(pid: pid, sprints: sprints, lamMoi: lamMoi, rong: rong)
        }
    }
}
