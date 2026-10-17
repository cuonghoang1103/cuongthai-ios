import SwiftUI

// MARK: - Đăng ký mô-đun Docs (đọc · tìm · tạo · sửa · lịch sử · bình luận) + KB
//
// Ẩn khi dự án tắt mô-đun `docs`. Deep link `/work/<ws>/<KEY>/docs/<n>`.
// KB (`/work/<ws>/<KEY>/kb`): bài viết = trang Docs ⇒ chỉ hiện khi Docs bật, và chỉ
// cho ĐỘI dự án (khách cổng bị máy chủ từ chối — `kb.service.ts`).

extension CTWModule {
    static let docs = CTWModule(
        id: "docs", ten: "Docs", bieuTuong: "doc.text", nhom: .taiLieu,
        moTa: "Pages, specs and meeting notes", thuTu: 10, doanWeb: "docs",
        hien: { cfg in cfg?.batMoDun("docs") ?? true },
        man: { c in AnyView(TaiLieuCTW(pid: c.pid)) },
        dichDen: { v in
            AnyView(v
                .navigationDestination(for: RouteTaiLieuCTW.self) { r in TrangTaiLieuCTW(pid: r.pid, so: r.so, ten: r.ten) }
                .navigationDestination(for: RouteLichSuTrangCTW.self) { r in
                    LichSuTrangCTW(pid: r.pid, so: r.so, ten: r.ten, quanLy: r.quanLy)
                }
                .navigationDestination(for: RoutePhienBanTrangCTW.self) { r in
                    PhienBanTrangCTW(pid: r.pid, so: r.so, n: r.n, quanLy: r.quanLy)
                }
                .navigationDestination(for: RouteThungRacCTW.self) { r in ThungRacTrangCTW(pid: r.pid) })
        })

    static let kb = CTWModule(
        id: "kb", ten: "Knowledge base", bieuTuong: "books.vertical", nhom: .taiLieu,
        moTa: "Help articles for the team and clients", thuTu: 12, doanWeb: "kb",
        hien: { cfg in (cfg?.batMoDun("docs") ?? true) && cfg?.role != "CLIENT" },
        man: { c in AnyView(KhoKienThucCTW(pid: c.pid)) })
}
