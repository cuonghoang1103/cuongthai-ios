import SwiftUI

// MARK: - Đăng ký mô-đun Forms (chỉ đội dự án — khách bị máy chủ chặn 403)

extension CTWModule {
    static let forms = CTWModule(
        id: "forms", ten: "Forms", bieuTuong: "list.bullet.rectangle.portrait", nhom: .giaoTiep,
        moTa: "Request forms and their responses", thuTu: 34, doanWeb: "forms",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(DsFormCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteFormCTW.self) { r in FormCTW(pid: r.pid, form: r.form) })
        })
}
