import SwiftUI

// MARK: - Đăng ký mô-đun Time tracking (đồng hồ bấm giờ + ghi giờ + bảng giờ tuần của tôi)
//
// Không có đoạn web riêng (web để chấm công trong chi tiết thẻ + Reports → Time) ⇒ `doanWeb` nil.
// Khách cổng (CLIENT) không ghi giờ được ⇒ ẩn.

extension CTWModule {
    static let time = CTWModule(
        id: "time", ten: "Time tracking", bieuTuong: "stopwatch", nhom: .keHoach,
        moTa: "Timer, log time and your week", thuTu: 80, doanWeb: nil,
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(TimeCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteWorklogCTW.self) { r in
                DsWorklogTheCTW(pid: r.pid, so: r.so, tieuDe: r.tieuDe)
            })
        })
}
