import SwiftUI

// MARK: - Đăng ký mô-đun Code (trang Code kiểu GitHub — web 18/10/2026)
//
// CHỈ hiện khi dự án đã nối GitHub/GitLab (`GET /code/status` ⇒ `connected`, nạp cùng cấu hình dự án ở
// `AppState.napCauHinhDuAn` → `codeDaNoi`) và người dùng KHÔNG phải khách cổng (máy chủ: CLIENT ⇒ 403).
// Deep link / thông báo Git: `/work/<ws>/<KEY>/code?tab=pulls&pr=12` · `?tab=activity&event=e45` · `?tab=source`.
// Route con: `RouteCodeCTW` (thư mục, tệp, lịch sử, commit).

extension CTWModule {
    static let code = CTWModule(
        id: "code", ten: "Code", bieuTuong: "chevron.left.forwardslash.chevron.right", nhom: .duAn,
        moTa: "Git activity, branches, pull requests and source", thuTu: 40, doanWeb: "code",
        hien: { cfg in
            guard let cfg, cfg.role != "CLIENT" else { return false }
            return AppState.shared.codeDaNoi == true
        },
        man: { c in AnyView(CodeCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteCodeCTW.self) { r in r.man })
        })
}
