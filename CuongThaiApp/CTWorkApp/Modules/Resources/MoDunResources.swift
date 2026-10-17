import SwiftUI

// MARK: - Đăng ký mô-đun Resources — `/work/<ws>/<KEY>/resources`
// Ẩn khi dự án tắt mô-đun `resources` (máy chủ trả 403 MODULE_DISABLED).

extension CTWModule {
    static let resources = CTWModule(
        id: "resources", ten: "Resources", bieuTuong: "link", nhom: .taiLieu,
        moTa: "Repos, designs, drives and handy links", thuTu: 30, doanWeb: "resources",
        hien: { cfg in cfg?.batMoDun("resources") ?? true },
        man: { c in AnyView(ResourcesCTW(nguCanh: c)) })
}
