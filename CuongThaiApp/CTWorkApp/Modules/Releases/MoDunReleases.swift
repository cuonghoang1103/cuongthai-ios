import SwiftUI

// MARK: - Đăng ký mô-đun Releases (phiên bản: tiến độ, burnup, ghi chú phát hành)
//
// Deep link `/work/<ws>/<KEY>/releases?v=<id>`. Route con: `RoutePhienBanCTW` (một phiên bản) —
// mô-đun Calendar cũng đẩy route này khi chạm một ngày phát hành.

extension CTWModule {
    static let releases = CTWModule(
        id: "releases", ten: "Releases", bieuTuong: "shippingbox", nhom: .keHoach,
        moTa: "Versions, progress and release notes", thuTu: 30, doanWeb: "releases",
        man: { c in AnyView(ReleasesCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RoutePhienBanCTW.self) { r in ChiTietPhienBanCTW(route: r) })
        })
}
