import SwiftUI

// MARK: - Đăng ký mô-đun Yêu cầu (SRS) + Wiegers (SWR302)
//
// Không có cờ `modules` cho mảng này ở máy chủ — cổng thật là `srsCtx` (khách/khách mời
// ⇒ 403 WORK_INTERNAL_ONLY). App ẩn với vai CLIENT như web; còn lại màn tự nói "Team only".

extension CTWModule {
    static let requirements = CTWModule(
        id: "requirements", ten: "Requirements", bieuTuong: "list.bullet.clipboard", nhom: .chatLuong,
        moTa: "Use cases, business rules, screens and traceability", thuTu: 10, doanWeb: "requirements",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(YeuCauCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteYeuCauCTW.self) { r in
                switch r {
                case .uc(let pid, let n): ChiTietUCCTW(pid: pid, n: n)
                case .man(let pid, let id): ChiTietManSrsCTW(pid: pid, id: id)
                }
            })
        })

    static let wiegers = CTWModule(
        id: "wiegers", ten: "Wiegers", bieuTuong: "books.vertical", nhom: .chatLuong,
        moTa: "Requirements lifecycle, features, stakeholders, glossary", thuTu: 20, doanWeb: "wiegers",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(WiegersCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteWiegersCTW.self) { r in r.man })
        })
}
