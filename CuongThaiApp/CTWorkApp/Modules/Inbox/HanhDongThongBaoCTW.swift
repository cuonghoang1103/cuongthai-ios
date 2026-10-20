import Foundation
import UIKit
import UserNotifications

// MARK: - Hành động NGAY trên thông báo (hộp thư + nút trên thông báo đẩy)
//
// Một chỗ cho ba việc, dùng ở cả hộp thư lẫn nút của thông báo đẩy:
//   · Đánh dấu đã đọc — `PATCH /social/notifications {ids}`
//   · Trả lời — theo `url` của thông báo:
//       `/work/<ws>/<KEY>/issue/<n>?comment=<c>` ⇒ bình luận trả lời trong luồng (`parentId = c`)
//       `/work/<ws>/<KEY>/chat?c=<kênh>&m=<tin>&t=<chuỗi>` ⇒ trả lời trong chuỗi (`parentId = t ?? m`)
//   · Duyệt / Từ chối — `POST /projects/:pid/approvals/:aid/decide` (`approvalId` trong payload)
// `pid` lấy bằng `GET /work/resolve/<ws>/<KEY>` (không đổi dự án đang chọn của người dùng).
//
// Nút trên thông báo đẩy (UNNotificationCategory) HIỆN theo `aps.category` máy chủ gửi
// (`api-backend/src/services/push/goiDayCtw.ts`, 18/10/2026): CTW_REPLY · CTW_APPROVAL (+ `approvalId`
// ở cấp ngoài cùng — chỉ khi người nhận đang tới lượt duyệt) · CTW_MEETING (+ `meetingUrl`) · CTW_DEFAULT.
// `thread-id` = `ctw-<issueKey>` / `ctw-<KEY>-chat-<cid>` ⇒ iOS tự xếp chồng theo thẻ/kênh.

enum HanhDongThongBaoCTW {
    enum Loi: LocalizedError {
        case khongRo
        var errorDescription: String? { String(localized: "This notification can't be answered here. Open it instead.") }
    }

    static func daDoc(_ ids: [Int]) async throws {
        guard !ids.isEmpty else { return }
        try await APIClient.shared.send(.markNotificationsRead(ids: ids))
    }

    static func timPid(_ d: DuongDanCTW) async throws -> Int {
        guard let ma = d.maDuAn else { throw Loi.khongRo }
        if let l = await AppState.shared.luaChon, l.slug == d.slug, l.maDuAn.caseInsensitiveCompare(ma) == .orderedSame { return l.pid }
        let r: CTWResolve = try await APIClient.shared.request(.workTimDuAn(slug: d.slug, ma: ma))
        return r.projectId
    }

    /// Trả lời đúng chỗ thông báo trỏ tới (bình luận thẻ hoặc chuỗi chat).
    static func traLoi(duongDan: String, chu: String) async throws {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, let d = DuongDanCTW.tach(duongDan) else { throw Loi.khongRo }
        let pid = try await timPid(d)
        switch d.doan {
        case "issue":
            guard let so = d.phanCon.first.flatMap(Int.init) else { throw Loi.khongRo }
            var than: [String: Any] = ["bodyJson": CTWNode.docTuChu(s)]
            if let c = d.tham["comment"].flatMap(Int.init) { than["parentId"] = c }
            try await APIClient.shared.send(.workThemBinhLuan(pid: pid, so: so, than: than))
        case "chat":
            guard let cid = d.tham["c"].flatMap(Int.init) else { throw Loi.khongRo }
            let goc = d.tham["t"].flatMap(Int.init) ?? d.tham["m"].flatMap(Int.init)
            let _: CTWChatMessage = try await APIClient.shared.request(
                CTWAPI.guiTin(pid: pid, cid: cid, chu: s, traLoi: goc, khoa: "ios-n-\(UUID().uuidString.prefix(21))"))
        default:
            throw Loi.khongRo
        }
    }

    static func pheDuyet(duongDan: String, approvalId: Int, dongY: Bool) async throws {
        guard let d = DuongDanCTW.tach(duongDan) else { throw Loi.khongRo }
        let pid = try await timPid(d)
        try await APIClient.shared.send(CTWAPI.tbPheDuyet(pid: pid, aid: approvalId, dongY: dongY))
    }

    /// Lối lùi khi gói đẩy KHÔNG mang `approvalId` (máy chủ cũ): tìm lại thông báo đầy đủ trong
    /// vài trang CT Work mới nhất (`surface=work` ⇒ không phải lội qua thông báo mạng xã hội).
    static func timThongBao(id: Int) async -> CTWThongBao? {
        var cursor: Int?
        for _ in 0..<2 {
            guard let r: CTWTrangThongBao = try? await APIClient.shared.request(CTWAPI.tbDanhSach(cursor: cursor, limit: 50)) else { return nil }
            if let n = r.items.first(where: { $0.id == id }) { return n }
            guard r.pagination?.hasNextPage == true, let c = r.pagination?.nextCursor else { return nil }
            cursor = c
        }
        return nil
    }
}

// MARK: - Category + nút trên thông báo đẩy

enum NutThongBaoCTW {
    static let traLoi = "CTW_REPLY"
    static let pheDuyet = "CTW_APPROVAL"
    static let hop = "CTW_MEETING"
    static let thuong = "CTW_DEFAULT"

    static let nutTraLoi = "ctw.reply"
    static let nutDaDoc = "ctw.read"
    static let nutDuyet = "ctw.approve"
    static let nutTuChoi = "ctw.reject"
    static let nutVaoHop = "ctw.join"

    /// Đăng ký 4 category. Máy chủ chọn bằng `aps.category`:
    ///   CTW_REPLY    — WORK_COMMENT / WORK_MENTION (thẻ + chat) + tin chat kênh ALL: Reply (ô nhập) · Mark as read
    ///   CTW_APPROVAL — WORK_ALERT có `approvalId` đang chờ mình: Approve · Reject · Mark as read
    ///   CTW_MEETING  — nhắc họp có `meetingUrl`: Join (mở app ra tiền cảnh) · Mark as read
    ///   CTW_DEFAULT  — còn lại: Mark as read
    static func dangKy() {
        let daDoc = UNNotificationAction(identifier: nutDaDoc, title: String(localized: "Mark as Read"), options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark.circle"))
        let traLoi = UNTextInputNotificationAction(identifier: nutTraLoi, title: String(localized: "Reply"), options: [.authenticationRequired],
                                                   icon: UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.left"),
                                                   textInputButtonTitle: String(localized: "Send"), textInputPlaceholder: String(localized: "Reply…"))
        let duyet = UNNotificationAction(identifier: nutDuyet, title: String(localized: "Approve"), options: [.authenticationRequired],
                                         icon: UNNotificationActionIcon(systemImageName: "checkmark.seal"))
        let tuChoi = UNNotificationAction(identifier: nutTuChoi, title: String(localized: "Reject"), options: [.authenticationRequired, .destructive],
                                          icon: UNNotificationActionIcon(systemImageName: "xmark.seal"))
        // Join cần MỞ app (`.foreground`) — mở link Meet/Zoom phải có giao diện; không cần mở khoá
        // riêng vì app sẽ mở và iOS tự đòi mở khoá máy.
        let vaoHop = UNNotificationAction(identifier: nutVaoHop, title: String(localized: "Join"), options: [.foreground],
                                          icon: UNNotificationActionIcon(systemImageName: "video.fill"))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Self.hop, actions: [vaoHop, daDoc], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: Self.traLoi, actions: [traLoi, daDoc], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: Self.pheDuyet, actions: [duyet, tuChoi, daDoc], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: Self.thuong, actions: [daDoc], intentIdentifiers: [], options: []),
        ])
    }

    /// Nút chạy NỀN (không mở màn). `nutVaoHop` KHÔNG thuộc nhóm này — nó mở app rồi mở link.
    static func laNutCuaCTW(_ id: String) -> Bool { [nutTraLoi, nutDaDoc, nutDuyet, nutTuChoi].contains(id) }

    /// Link vào họp hợp lệ trong gói đẩy (chỉ http/https — không mở scheme lạ từ máy chủ).
    static func linkHop(_ info: [AnyHashable: Any]) -> URL? {
        guard let s = info["meetingUrl"] as? String, let u = URL(string: s),
              let sc = u.scheme?.lowercased(), sc == "https" || sc == "http" else { return nil }
        return u
    }

    /// Xử lý một nút (app có thể đang chạy NỀN — không mở giao diện). Gọi `xong` khi
    /// mọi lời gọi mạng kết thúc (iOS cho ~30 giây). Hỏng ⇒ đăng một thông báo cục bộ
    /// báo lỗi để người dùng biết hành động KHÔNG thành.
    static func xuLy(nut: String, thongBaoId id: Int?, duongDan duong: String?, approvalId: Int?, chu: String?,
                     xong: @escaping () -> Void) {
        let nen = UIApplication.shared.beginBackgroundTask(withName: "ctw.notification.action")
        Task { @MainActor in
            defer {
                xong()
                if nen != .invalid { UIApplication.shared.endBackgroundTask(nen) }
            }
            do {
                switch nut {
                case nutTraLoi:
                    guard let duong, let chu else { throw HanhDongThongBaoCTW.Loi.khongRo }
                    try await HanhDongThongBaoCTW.traLoi(duongDan: duong, chu: chu)
                case nutDuyet, nutTuChoi:
                    var aid = approvalId
                    if aid == nil, let id { aid = await HanhDongThongBaoCTW.timThongBao(id: id)?.payload?.approvalId }
                    guard let duong, let aid else { throw HanhDongThongBaoCTW.Loi.khongRo }
                    try await HanhDongThongBaoCTW.pheDuyet(duongDan: duong, approvalId: aid, dongY: nut == nutDuyet)
                default:
                    break
                }
                if let id { try? await HanhDongThongBaoCTW.daDoc([id]) }
                await AppState.shared.taiSoChuaDoc()
            } catch {
                let c = UNMutableNotificationContent()
                c.title = "CT Work"
                c.body = nut == nutTraLoi ? String(localized: "Your reply wasn't sent: \(CTW.loi(error))") : String(localized: "That action didn't go through: \(CTW.loi(error))")
                if let duong { c.userInfo = ["duongDan": duong] }
                try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ctw.loi.\(UUID().uuidString)", content: c, trigger: nil))
            }
        }
    }
}
