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

    /// `tinId` (build 7, R4): báo cáo MỘT tin trong hội thoại — máy chủ (api-backend 48d4d79a) ghi `thread_reports.message_id`,
    /// báo admin kèm nguyên văn tin và ẨN tin đó với người báo cáo ở mọi lần tải sau. nil = báo cáo cả hội thoại (như cũ).
    static func thanBaoCao(lyDo: String, loai: String, tinId: Int? = nil) -> [String: Any] {
        let l = loaiBaoCao.contains(loai) ? loai : "other"
        var t: [String: Any] = ["reason": String(lyDo.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)), "category": l]
        if let tinId, tinId > 0 { t["messageId"] = tinId }
        return t
    }

    static func baoCao(threadId: Int, lyDo: String, loai: String, tinId: Int? = nil) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/report"), phuongThuc: "POST", than: thanBaoCao(lyDo: lyDo, loai: loai, tinId: tinId))
    }

    /// Khoá ẩn tại máy của một tin đã báo cáo (`AnNoiDungChungCTW`) — ẩn NGAY, và vẫn ẩn khi máy chủ cũ (chưa có
    /// `messageId`) còn trả tin đó ở lần tải sau.
    static func khoaAnTin(_ id: Int) -> String { "dm-msg-\(id)" }

    /// Bỏ tin đã báo cáo (ẩn tại máy) khỏi danh sách.
    @MainActor static func locDaAn(_ ds: [Message]) -> [Message] {
        let an = AnNoiDungChungCTW.shared
        return ds.filter { !an.biAn(khoaAnTin($0.id)) }
    }

    /// `PUT /profile` chỉ một trường — máy chủ bỏ qua mọi trường vắng (`auth.service › updateProfile`, `!== undefined`).
    static func thanTrangThaiHoatDong(_ bat: Bool) -> [String: Any] { ["showActiveStatus": bat] }

    static func datTrangThaiHoatDong(_ bat: Bool) -> APIEndpoint { .updateProfile(thanTrangThaiHoatDong(bat)) }

    // MARK: 1.1 — Messenger + hồ sơ (22/10/2026). Mọi đường đều CÓ SẴN trên máy chủ (messages.routes.ts, gifs.routes.ts,
    // sticker.routes.ts, user.routes.ts); chỉ `offset` của /gifs là mới (nhánh ctw-msg2-be) — máy chủ cũ bỏ qua nó.

    static func guiMedia(threadId: Int, url: String, kieu: String, traLoi: Int?) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/messages"), phuongThuc: "POST", than: GuiMediaCTW.than(url: url, kieu: kieu, traLoi: traLoi))
    }

    static func chuyenTiep(_ m: Message, toi threadId: Int) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/messages"), phuongThuc: "POST", than: ChuyenTiepCTW.than(m))
    }

    static func gif(q: String, offset: Int) -> APIEndpoint { .tuyChinh(duong: TrangGifCTW.duong(q: q, offset: offset), phuongThuc: "GET", than: nil) }
    static func goiNhanDan() -> APIEndpoint { .tuyChinh(duong: "/api/v1/stickers/packs", phuongThuc: "GET", than: nil) }
    static func nhanDan(goi: Int) -> APIEndpoint { .tuyChinh(duong: "/api/v1/stickers/packs/\(goi)/stickers", phuongThuc: "GET", than: nil) }

    /// Ghim / bỏ đánh dấu… — một ô tuỳ chọn riêng của người xem (`PATCH /threads/:id/preference`).
    static func tuyChon(threadId: Int, o: String, giaTri: String?) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/preference"), phuongThuc: "PATCH", than: ["slot": o, "value": giaTri as Any? ?? NSNull()])
    }
    static func danhDauChuaDoc(threadId: Int) -> APIEndpoint { .tuyChinh(duong: goc("/threads/\(threadId)/mark-unread"), phuongThuc: "POST", than: [:]) }
    static func tatThongBao(threadId: Int, phut: Int?) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/mute-for"), phuongThuc: "POST", than: TatThongBaoCTW.than(phut))
    }
    /// "Xoá cuộc trò chuyện" — CHỈ phía tôi (người kia vẫn giữ); khôi phục được ở web (tab "Đã xoá").
    static func xoaPhiaToi(threadId: Int) -> APIEndpoint { .tuyChinh(duong: goc("/threads/\(threadId)/hard"), phuongThuc: "DELETE", than: nil) }
    static func bietDanh(threadId: Int, nguoi: Int, ten: String) -> APIEndpoint {
        .tuyChinh(duong: goc("/threads/\(threadId)/nickname"), phuongThuc: "PUT", than: ["targetId": nguoi, "alias": ten])
    }

    /// Hồ sơ công khai (cùng trang /profile/:id của web): bio, ảnh bìa, chức danh… — `GET /users/:id`.
    static func hoSoCongKhai(_ id: Int) -> APIEndpoint { .tuyChinh(duong: "/api/v1/users/\(id)", phuongThuc: "GET", than: nil) }
}
