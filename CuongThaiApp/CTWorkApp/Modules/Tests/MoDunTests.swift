import SwiftUI

// MARK: - Đăng ký mô-đun Kiểm thử (Xray + mẫu FPT)
//
// Hiện khi dự án có loại thẻ TEST (đúng cách web nhận "đã bật kiểm thử" —
// `testing-ui.tsx:49`). Ẩn với khách (CLIENT): kiểm thử là việc nội bộ của đội.
// Deep link `/work/<ws>/<KEY>/tests?run=<id>` hoặc `?cycle=<id>`.

extension CTWModule {
    static let tests = CTWModule(
        id: "tests", ten: "Tests", bieuTuong: "checkmark.seal", nhom: .chatLuong,
        moTa: "Test cycles, run tests on your phone, FPT reports", thuTu: 30, doanWeb: "tests",
        hien: { cfg in
            #if DEBUG
            if XemThuCTW.conCua("tests") != nil { return true }
            #endif
            guard let cfg else { return false }
            if cfg.role == "CLIENT" { return false }
            return cfg.dsLoai.contains { ($0.key ?? "").uppercased() == "TEST" }
        },
        man: { c in AnyView(KiemThuCTW(pid: c.pid, maDuAn: c.maDuAn)) },
        dichDen: { v in
            AnyView(
                v.navigationDestination(for: RouteChuKyCTW.self) { r in ChuKyCTW(pid: r.pid, id: r.id, ten: r.ten) }
                    .navigationDestination(for: RouteLuotChayCTW.self) { r in ChayTestCTW(pid: r.pid, id: r.id) }
                    .navigationDestination(for: RouteTestCTW.self) { r in TestChiTietCTW(pid: r.pid, so: r.so, ten: r.ten) }
                    .navigationDestination(for: RouteFptHamCTW.self) { r in FptHamCTW(pid: r.pid, id: r.id, ten: r.ten) }
                    .navigationDestination(for: RouteFptModuleCTW.self) { r in FptModuleCTW(pid: r.pid, kieu: r.kieu, id: r.id, ten: r.ten) }
            )
        })
}

// MARK: Route con

struct RouteChuKyCTW: Hashable { var pid: Int; var id: Int; var ten: String }
struct RouteLuotChayCTW: Hashable { var pid: Int; var id: Int }
struct RouteTestCTW: Hashable { var pid: Int; var so: Int; var ten: String }
struct RouteFptHamCTW: Hashable { var pid: Int; var id: Int; var ten: String }
struct RouteFptModuleCTW: Hashable { var pid: Int; var kieu: String; var id: Int; var ten: String }
