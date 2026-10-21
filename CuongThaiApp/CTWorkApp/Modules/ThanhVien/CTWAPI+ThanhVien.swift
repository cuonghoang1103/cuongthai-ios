import Foundation

// MARK: - Đường API mảng Thành viên + Tin nhắn riêng
//
// Thành viên: `/api/v1/work/me/people` (work.ios.routes.ts). Tin nhắn riêng: `/api/v1/messages/*`
// (messages.routes.ts — CÙNG hệ với web /messages và app chính). Các case sẵn có của `APIEndpoint` được dùng lại
// (`getThreads`, `getMessages`, `markRead`, `openThread`, `toggleMessageReaction`, `recallMessage`, `getThreadReads`,
// `getUnreadMessageCount`, `baoHoatDong`); đường cần thân khác (`parentMessageId` + `fileIds` cùng lúc, `category` của
// báo cáo) đi `.tuyChinh` với thân dựng ở các hàm THUẦN dưới (kiểm ở `ThanhVienCTWTests`).

extension CTWAPI {
    static func thanhVien() -> APIEndpoint { get("/me/people") }
}

enum TinNhanAPI {
    static func goc(_ d: String) -> String { "/api/v1/messages" + d }

    /// Thân gửi một tin: chữ (có thể rỗng khi chỉ gửi tệp), tệp đã tải lên (`fileId` của `POST /messages/upload`),
    /// tin được trả lời. Khoá rỗng KHÔNG gửi (máy chủ hiểu `parentMessageId: null` là không trả lời, nhưng giữ thân gọn).
    static func thanGui(noiDung: String, tepIds: [Int], traLoi: Int?) -> [String: Any] {
        var m: [String: Any] = ["content": noiDung]
        if !tepIds.isEmpty { m["fileIds"] = tepIds }
        if let traLoi { m["parentMessageId"] = traLoi }
        return m
    }

    static func gui(threadId: Int, noiDung: String, tepIds: [Int], traLoi: Int?) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/messages"), phuongThuc: "POST",
                  than: thanGui(noiDung: noiDung, tepIds: tepIds, traLoi: traLoi))
    }

    /// Mã loại báo cáo máy chủ nhận (`ALLOWED_BLOCK_REASONS` — messaging-safety.service.ts).
    static let loaiBaoCao = ["spam", "harassment", "hate", "impersonation", "other"]

    static func thanBaoCao(lyDo: String, loai: String) -> [String: Any] {
        let l = loaiBaoCao.contains(loai) ? loai : "other"
        return ["reason": String(lyDo.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)), "category": l]
    }

    static func baoCao(threadId: Int, lyDo: String, loai: String) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/report"), phuongThuc: "POST", than: thanBaoCao(lyDo: lyDo, loai: loai))
    }

    /// `PUT /profile` chỉ một trường — máy chủ bỏ qua mọi trường vắng (`auth.service › updateProfile`, `!== undefined`).
    static func thanTrangThaiHoatDong(_ bat: Bool) -> [String: Any] { ["showActiveStatus": bat] }

    static func datTrangThaiHoatDong(_ bat: Bool) -> APIEndpoint { .updateProfile(thanTrangThaiHoatDong(bat)) }
}
