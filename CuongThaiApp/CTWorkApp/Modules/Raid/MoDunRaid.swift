import SwiftUI

// MARK: - Đăng ký mô-đun RAID log
//
// Hiện khi dự án bật `raid` và vai trò xem được quản trị dự án. Deep link
// `/work/<ws>/<KEY>/raid/<n>`.

extension CTWModule {
    static let raid = CTWModule(
        id: "raid", ten: "RAID log", bieuTuong: "exclamationmark.triangle", nhom: .quanLy,
        moTa: "Risks, assumptions, issues, dependencies", thuTu: 30, doanWeb: "raid",
        hien: { cfg in (cfg?.batMoDun("raid") ?? true) && GovQuyen.co(cfg, "viewGovernance") && !GovQuyen.laKhach(cfg) },
        man: { c in AnyView(RaidCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteRaidCTW.self) { r in ChiTietRaidCTW(pid: r.pid, so: r.so) })
        })
}
