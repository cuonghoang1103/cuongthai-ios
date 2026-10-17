import SwiftUI

// MARK: - Đăng ký mô-đun Portfolio & workload (cấp không gian)
//
// Web: `/work/<ws>/portfolio`, `/workload`, `/teams`, `/workload?tab=agents` — không nằm dưới mã dự án
// nên `doanWeb` nil (deep link cấp không gian không đi qua bảng mô-đun dự án). Khách cổng (CLIENT) ẩn.

extension CTWModule {
    static let workspace = CTWModule(
        id: "workspace", ten: "Portfolio & workload", bieuTuong: "square.grid.3x2", nhom: .keHoach,
        moTa: "Across all projects in this workspace", thuTu: 95, doanWeb: nil,
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(WorkspaceCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteDoiCTW.self) { r in
                HangDoiCTW(ws: r.ws, doi: r.doi, ten: r.ten)
            })
        })
}
