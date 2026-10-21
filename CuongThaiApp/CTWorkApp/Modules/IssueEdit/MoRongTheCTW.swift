import SwiftUI

// MARK: - Chi tiết thẻ của app CT Work: cắm phần CHỈ app này có vào `CTWIssueView` (Shared, app chính cũng dùng)
//
// · Ghi giờ ngay trong thẻ: `NutGhiGioTheCTW` (mô-đun Time — Start timer / Log time, chung đồng hồ + Live Activity).
// · Mở tài liệu liên kết: đẩy `RouteTaiLieuCTW` (đích của mô-đun Docs, đăng ký ở `ctwDichDen`).
// · Nút "CuongMini" cạnh trạng thái (`NutCuongMiniTheCTW`, Modules/AI/CuongMiniCTW.swift) — việc một chạm + hỏi về thẻ.
// App chính không có hai mô-đun đó ⇒ `CTWIssueView(moRong: nil)` tự ẩn phần tương ứng.

extension CTWIssueMoRong {
    @MainActor
    static var ctwApp: CTWIssueMoRong {
        CTWIssueMoRong(
            nutGhiGio: { pid, so, tieuDe, daGhi in
                AnyView(NutGhiGioTheCTW(pid: pid, so: so, tieuDe: tieuDe, daGhi: daGhi))
            },
            lienKetTrang: { pid, so, ten, nhan in
                AnyView(NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: so, ten: ten)) { nhan }.buttonStyle(.plain))
            },
            nutCuongMini: { cfg, so, loai, tieuDe in
                nutCuongMini(cfg: cfg, the: TheCuongMini(so: so, loai: loai, tieuDe: tieuDe))
            })
    }
}
