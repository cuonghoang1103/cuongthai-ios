import SwiftUI

// MARK: - Đăng ký mô-đun Docs (đọc + tìm; sửa = đợt sau)
//
// Ẩn khi dự án tắt mô-đun `docs`. Deep link `/work/<ws>/<KEY>/docs/<n>`.

extension CTWModule {
    static let docs = CTWModule(
        id: "docs", ten: "Docs", bieuTuong: "doc.text", nhom: .taiLieu,
        moTa: "Pages, specs and meeting notes", thuTu: 10, doanWeb: "docs",
        hien: { cfg in cfg?.batMoDun("docs") ?? true },
        man: { c in AnyView(TaiLieuCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteTaiLieuCTW.self) { r in
                TrangTaiLieuCTW(pid: r.pid, so: r.so, ten: r.ten)
            })
        })
}
