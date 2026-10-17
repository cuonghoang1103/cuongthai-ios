import SwiftUI

// MARK: - Đăng ký mô-đun Team — `/work/<ws>/<KEY>/team`
// Hiện với mọi vai trò (khách cổng chỉ thấy danh sách, khối khối-lượng-việc bị máy chủ chặn ⇒ ẩn).

extension CTWModule {
    static let team = CTWModule(
        id: "team", ten: "Team", bieuTuong: "person.2", nhom: .quanTri,
        moTa: "Members, roles, workload and invites", thuTu: 10, doanWeb: "team",
        man: { c in AnyView(TeamCTW(nguCanh: c)) })
}
