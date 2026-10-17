import SwiftUI

// MARK: - Đăng ký mô-đun Lớp học
//
// Lớp sống ở cấp tài khoản (`/work/classes`), không theo dự án ⇒ không nhận deep link
// theo đoạn dự án (`doanWeb: nil`). Hiện với mọi tài khoản: sinh viên chưa có lớp thì
// màn nói rõ cách tham gia.

extension CTWModule {
    static let classes = CTWModule(
        id: "classes", ten: "Classes", bieuTuong: "graduationcap", nhom: .duAn,
        moTa: "Class stream, assignments and teaching overview", thuTu: 80, doanWeb: nil,
        man: { _ in AnyView(LopHocCTW()) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteLopCTW.self) { r in r.man })
        })
}
