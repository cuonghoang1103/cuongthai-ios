import SwiftUI

// MARK: - Đăng ký mô-đun Calendar (hạn thẻ · sprint · phát hành · họp; thêm vào Lịch iOS)
//
// Web không có trang lịch riêng ⇒ không nhận deep link (`doanWeb` = nil).

extension CTWModule {
    static let calendar = CTWModule(
        id: "calendar", ten: "Calendar", bieuTuong: "calendar", nhom: .keHoach,
        moTa: "Due dates, sprints, releases and meetings", thuTu: 40,
        man: { c in AnyView(LichCTW(nguCanh: c)) })
}
