import Foundation

// MARK: - Model Releases (phiên bản)
//
// Đối chiếu backend `planning.service.ts`:
//   · `VERSION_SELECT` (:29-32) — `startDate`/`releaseDate` là cột `@db.Date` ⇒ ISO nửa đêm Z
//     ("2026-10-30T00:00:00.000Z"), lấy 10 ký tự đầu. `releaseNotes` là markdown.
//   · `GET /versions` (:35-58) thêm `total`/`done`/`overdue` (chỉ đếm thẻ level ≥ 0).
//   · `GET /versions/:id` (:159-169) ⇒ `{version, issues: IssueCard[]}` — KHÔNG có tiến độ; tự tính.
//   · `POST /versions/:id/release` (:126-145) ⇒ `{version, moved}`.
//   · `GET /reports/release-burnup` (`flowReports.service.ts:160-202`).

struct PhienBanCTW: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var description: String?
    var startDate: String?
    var releaseDate: String?
    /// UNRELEASED | RELEASED | ARCHIVED
    var status: String?
    var releasedAt: String?
    var releaseNotes: String?
    var position: Int?
    var createdAt: String?
    var total: Int?
    var done: Int?
    var overdue: Bool?

    var daPhatHanh: Bool { status == "RELEASED" }
    var daLuuTru: Bool { status == "ARCHIVED" }
    /// Tỉ lệ xong theo SỐ THẺ (0…1) — đúng như web.
    var tiLe: Double {
        guard let t = total, t > 0 else { return daPhatHanh ? 1 : 0 }
        return Double(done ?? 0) / Double(t)
    }
}

struct PhienBanChiTietCTW: Codable {
    var version: PhienBanCTW?
    var issues: [CTWIssueCard]?
}

struct KetQuaPhatHanhCTW: Codable {
    var version: PhienBanCTW?
    var moved: Int?
}

struct DiemBurnupPBCTW: Codable, Hashable, Identifiable {
    var day: String
    var scope: Double?
    var done: Double?
    var remaining: Double?
    var ideal: Double?
    var id: String { day }
}

struct BurnupPhatHanhCTW: Codable {
    var unit: String?
    var byCount: Bool?
    var points: [DiemBurnupPBCTW]?
    /// Câu mô tả phạm vi số liệu (tiếng Anh cố định của máy chủ).
    var scope: String?
    /// YMD — ngày dự báo xong theo nhịp gần đây (nil = chưa đủ số liệu).
    var forecast: String?
}

/// Tiến độ một phiên bản theo NHÓM trạng thái (Done / In progress / To do) — tính từ danh sách thẻ.
struct TienDoPhienBanCTW: Equatable {
    var xong = 0
    var dangLam = 0
    var chuaLam = 0
    var tong: Int { xong + dangLam + chuaLam }
    var tiLe: Double { tong == 0 ? 0 : Double(xong) / Double(tong) }

    /// `nhom(statusId)` trả category của trạng thái (TODO/IN_PROGRESS/DONE). Thẻ đã `resolvedAt`
    /// luôn tính là xong (khớp cách máy chủ đếm `done`).
    static func tinh(_ the: [CTWIssueCard], nhom: (Int) -> String?) -> TienDoPhienBanCTW {
        var t = TienDoPhienBanCTW()
        for c in the {
            if c.resolvedAt != nil || nhom(c.statusId) == "DONE" { t.xong += 1 }
            else if nhom(c.statusId) == "IN_PROGRESS" { t.dangLam += 1 }
            else { t.chuaLam += 1 }
        }
        return t
    }
}
