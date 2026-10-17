import SwiftUI

// MARK: - Đăng ký mô-đun Backlog (sprint + backlog + danh sách có lọc)

extension CTWModule {
    static let backlog = CTWModule(
        id: "backlog", ten: "Backlog & issues", bieuTuong: "list.bullet.rectangle", nhom: .duAn,
        moTa: "Sprints, backlog and filtered issue lists", thuTu: 20, doanWeb: "backlog",
        man: { c in AnyView(BacklogCTW(pid: c.pid)) })
}
