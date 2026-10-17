#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng B (Kế hoạch & theo dõi tiến độ) — máy chủ giả `CT_XEM_MAN=mod:<id>`
//
// Ba tệp con theo nhóm mô-đun (mỗi nhóm một người làm, không giẫm nhau):
//   · B1 — Sprints · Reports · Dashboards          (`XemThuCTW+B1.swift`)
//   · B2 — Timeline · Releases · Stages · Calendar  (`XemThuCTW+B2.swift`)
//   · B3 — Time · Poker · Retro · OKR · Workspace   (`XemThuCTW+B3.swift`)
// Hình dạng dữ liệu đối chiếu service backend (xem chú thích trong từng tệp).
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

enum DuLieuGiaB {
    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        if let r = DuLieuGiaB1.route(m, p, b) { return r }
        if let r = DuLieuGiaB2.route(m, p, b) { return r }
        if let r = DuLieuGiaB3.route(m, p, b) { return r }
        return nil
    }
}
#endif
