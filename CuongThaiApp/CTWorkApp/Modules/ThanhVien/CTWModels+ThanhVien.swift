import Foundation

// MARK: - Model mảng Thành viên + Tin nhắn riêng (21/10/2026)
//
// `GET /api/v1/work/me/people` — api-backend `src/services/work/people.service.ts › listPeople`.
// Tin nhắn riêng dùng LẠI model của app chính (`MessageThread`, `Message`, `MessageReaction`, `MocDoc` —
// Shared/Models/Models.swift, target này đã biên dịch) vì máy chủ là MỘT hệ Messenger chung web + hai app.
// Ngày là `String` (APIClient dựng `JSONDecoder()` trần — khai `Date` là hỏng cả lượt giải mã, KIEN_TRUC mục 9).

struct CTWDanhBa: Codable, Hashable {
    /// Người XEM đang bật "Hiển thị trạng thái hoạt động" — tắt ⇒ máy chủ đã ẩn trạng thái của mọi người (luật đối ứng).
    var viewerShowsActiveStatus: Bool?
    var people: [CTWThanhVien]?
}

struct CTWThanhVien: Codable, Hashable, Identifiable {
    var id: Int
    var username: String?
    var fullName: String?
    var displayName: String?
    var avatarUrl: String?
    /// `HUMAN` | `AGENT`.
    var kind: String?
    var workspaces: [KhongGian]?
    /// Dự án CHUNG với người xem.
    var projects: [DuAn]?
    /// Người xem đã chặn người này.
    var blocked: Bool?
    var presence: TrangThai?

    struct KhongGian: Codable, Hashable { var id: Int; var name: String?; var slug: String?; var role: String? }
    struct DuAn: Codable, Hashable { var id: Int; var key: String?; var name: String?; var role: String? }
    struct TrangThai: Codable, Hashable {
        /// false ⇒ KHÔNG vẽ chấm, KHÔNG viết "hoạt động … trước" (máy chủ đã che).
        var visible: Bool?
        var online: Bool?
        var lastActiveAt: String?
    }

    var ten: String { displayName ?? fullName ?? username ?? "—" }
    var laAgent: Bool { kind == "AGENT" }
    var nguoi: CTWUser { CTWUser(id: id, username: username, fullName: fullName, displayName: displayName, avatarUrl: avatarUrl, kind: kind) }

    /// Dòng phụ: vai + không gian/dự án chung ("Admin · Northwind Studio · NW, WEB").
    var dongPhu: String {
        var phan: [String] = []
        if let w = workspaces?.first {
            if let r = w.role { phan.append(CTWThanhVien.tenVai(r)) }
            if let n = w.name { phan.append(workspaces!.count > 1 ? String(localized: "\(n) +\(workspaces!.count - 1)") : n) }
        }
        let ma = (projects ?? []).compactMap(\.key).prefix(3)
        if !ma.isEmpty { phan.append(ma.joined(separator: ", ")) }
        return phan.joined(separator: " · ")
    }

    static func tenVai(_ r: String) -> String {
        switch r.uppercased() {
        case "OWNER": return String(localized: "Owner")
        case "ADMIN": return String(localized: "Admin")
        case "MEMBER": return String(localized: "Member")
        case "GUEST": return String(localized: "Guest")
        case "VIEWER": return String(localized: "Viewer")
        case "CLIENT": return String(localized: "Client")
        default: return r.capitalized
        }
    }
}

/// `GET /messages/unread-count` ⇒ `{count}`.
struct CTWSoTinNhanChuaDoc: Codable { var count: Int? }

/// `POST /messages/threads/:id/messages` cho tin chỉ đi một đường — để `Message` (model app chính) giải mã.
struct CTWTinNhanGuiDi: Hashable, Identifiable {
    /// Id tạm âm (tin đang gửi chưa có id máy chủ).
    var id: Int
    var noiDung: String
    var traLoi: Int?
    var anhCucBo: [Data] = []
    var tenTep: [String] = []
    var loi: String?
}
