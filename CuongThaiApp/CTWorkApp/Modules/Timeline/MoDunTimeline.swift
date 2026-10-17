import SwiftUI

// MARK: - Đăng ký mô-đun Timeline (roadmap: Gantt + danh sách theo tháng)
//
// Deep link `/work/<ws>/<KEY>/timeline`. Không có cổng mô-đun ở máy chủ (mọi vai `project.view`).

extension CTWModule {
    static let timeline = CTWModule(
        id: "timeline", ten: "Timeline", bieuTuong: "calendar.day.timeline.left", nhom: .keHoach,
        moTa: "Roadmap of epics, dates and dependencies", thuTu: 20, doanWeb: "timeline",
        man: { c in AnyView(TimelineCTW(pid: c.pid)) })
}
