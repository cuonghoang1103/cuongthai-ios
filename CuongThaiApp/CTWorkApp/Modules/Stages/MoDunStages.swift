import SwiftUI

// MARK: - Đăng ký mô-đun Stages (giai đoạn dự án theo cổng duyệt)
//
// Chỉ hiện khi dự án BẬT mô-đun `stages` (map `modules` của `GET /projects/:pid` có đủ mọi khoá
// studio — thiếu cấu hình ⇒ ẩn, vì máy chủ trả 403 `MODULE_DISABLED` khi tắt).

extension CTWModule {
    static let stages = CTWModule(
        id: "stages", ten: "Stages", bieuTuong: "flag.checkered", nhom: .keHoach,
        moTa: "Delivery phases and gate reviews", thuTu: 50, doanWeb: "stages",
        hien: { cfg in cfg?.modules?.tatCa["stages"] == true },
        man: { c in AnyView(GiaiDoanDuAnCTW(pid: c.pid, maDuAn: c.maDuAn)) })
}
