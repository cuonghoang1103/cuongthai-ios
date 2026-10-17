import SwiftUI

// MARK: - Đăng ký mô-đun AI Agents
// Trang web ở cấp KHÔNG GIAN (`/work/<ws>/agents`) ⇒ không nhận deep link theo đoạn dự án
// (`doanWeb: nil`). Ẩn với khách cổng (máy chủ cũng trả 403 cho GUEST).

extension CTWModule {
    static let agents = CTWModule(
        id: "agents", ten: "AI agents", bieuTuong: "sparkles", nhom: .quanTri,
        moTa: "AI team members, status and current work", thuTu: 20, doanWeb: nil,
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(ManAgentsCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteAgentCTW.self) { r in AgentChiTietCTW(r: r) })
        })
}

/// Bọc để đọc `workspace.id` từ cấu hình dự án lúc dựng (khung chỉ đưa slug).
private struct ManAgentsCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    var body: some View {
        if let cfg = app.cauHinhDuAn {
            AgentsCTW(nguCanh: nguCanh, wsId: cfg.workspace?.id).id(cfg.workspace?.id ?? 0)
        } else {
            CTWKhungTai(soHang: 4).frame(maxHeight: .infinity, alignment: .top).background(AppColors.backgroundPrimary)
        }
    }
}
