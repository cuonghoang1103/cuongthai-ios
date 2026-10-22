import Foundation
import UniformTypeIdentifiers

// MARK: - Bảng tin — đường API (hợp đồng `api-backend/docs/ctw-feed-hop-dong-api.md`)
//
// Mọi đường dưới `/api/v1/work` (`CTWAPI.get/goi`). Tải tệp có HAI đường (§6):
//   A. `POST /feed/uploads` multipart (ảnh — máy chủ làm thumbnail; tệp/video ≤ 25 MB)
//   B. `presign` ⇒ PUT thẳng R2 (đúng header `Content-Type` đã ký) ⇒ `complete` (+ `poster` cho video)
// Hai đường tự dựng `URLRequest` (cần tiến độ + huỷ) nhưng vẫn qua `URLSession.shared` ⇒ máy chủ giả (DEBUG) chặn được.

extension CTWAPI {
    // §2 Phạm vi + cài đặt
    static func bangTinPhamVi() -> APIEndpoint { get("/feed/scopes") }
    static func bangTinTheoDoi(ws: Int, pid: Int?, muc: String) -> APIEndpoint {
        goi("/feed/follow", "PUT", ["workspaceId": ws, "projectId": pid.map { $0 as Any } ?? NSNull(), "level": muc])
    }
    static func bangTinNguoiNhac(ws: Int, pid: Int?, q: String) -> APIEndpoint {
        var t: [String: Any] = ["workspaceId": ws, "q": String(q.prefix(60))]
        if let pid { t["projectId"] = pid }
        return get("/feed/mentionable", t)
    }

    // §3 Bảng tin
    static func bangTin(_ loc: LocBangTin, cursor: String?, limit: Int = 20) -> APIEndpoint {
        var q = loc.thamSo
        if let cursor { q["cursor"] = cursor }
        q["limit"] = limit
        return get("/feed", q)
    }
    static func bangTinDemMoi(since: String, ws: Int?, pid: Int?) -> APIEndpoint {
        var q: [String: Any] = ["since": since]
        if let ws { q["workspaceId"] = ws }
        if let pid { q["projectId"] = pid }
        return get("/feed/new-count", q)
    }

    // §4 Bài
    static func baiMoi(_ than: [String: Any]) -> APIEndpoint { goi("/feed/posts", "POST", than) }
    static func bai(_ id: Int) -> APIEndpoint { get("/feed/posts/\(id)") }
    static func suaBai(_ id: Int, _ than: [String: Any]) -> APIEndpoint { goi("/feed/posts/\(id)", "PATCH", than) }
    static func xoaBai(_ id: Int) -> APIEndpoint { goi("/feed/posts/\(id)", "DELETE", nil) }
    static func ghimBai(_ id: Int, _ ghim: Bool) -> APIEndpoint { goi("/feed/posts/\(id)/pin", "PUT", ["pinned": ghim]) }
    static func goBai(_ id: Int, _ an: Bool) -> APIEndpoint { goi("/feed/posts/\(id)/moderation", "PUT", ["hidden": an]) }
    static func camXucBai(_ id: Int, _ k: CamXucBangTin?) -> APIEndpoint {
        k.map { goi("/feed/posts/\(id)/reaction", "PUT", ["kind": $0.rawValue]) } ?? goi("/feed/posts/\(id)/reaction", "DELETE", nil)
    }
    static func nguoiThaCamXuc(_ id: Int, kind: String?, cursor: String?) -> APIEndpoint {
        var q: [String: Any] = [:]
        if let kind { q["kind"] = kind }
        if let cursor { q["cursor"] = cursor }
        return get("/feed/posts/\(id)/reactions", q)
    }
    static func luuBai(_ id: Int, _ luu: Bool) -> APIEndpoint { goi("/feed/posts/\(id)/save", "PUT", ["saved": luu]) }
    static func anBai(_ id: Int, _ an: Bool) -> APIEndpoint { goi("/feed/posts/\(id)/hide", "PUT", ["hidden": an]) }
    static func baoCaoBai(_ id: Int, lyDo: String, chiTiet: String?) -> APIEndpoint {
        var t: [String: Any] = ["reason": lyDo]
        if let chiTiet, !chiTiet.isEmpty { t["detail"] = String(chiTiet.prefix(1000)) }
        return goi("/feed/posts/\(id)/report", "POST", t)
    }
    static func bauChon(_ id: Int, _ luaChon: [String]) -> APIEndpoint { goi("/feed/posts/\(id)/vote", "PUT", ["optionIds": luaChon]) }

    // §5 Bình luận
    static func binhLuanBai(_ id: Int, cha: Int?, cursor: String?, limit: Int = 20) -> APIEndpoint {
        var q: [String: Any] = ["limit": limit]
        if let cha { q["parentId"] = cha }
        if let cursor { q["cursor"] = cursor }
        return get("/feed/posts/\(id)/comments", q)
    }
    static func guiBinhLuan(_ id: Int, chu: String, cha: Int?, khoa: String) -> APIEndpoint {
        var t: [String: Any] = ["body": chu, "clientKey": khoa]
        if let cha { t["parentId"] = cha }
        return goi("/feed/posts/\(id)/comments", "POST", t)
    }
    static func suaBinhLuanBai(_ cid: Int, chu: String) -> APIEndpoint { goi("/feed/comments/\(cid)", "PATCH", ["body": chu]) }
    static func xoaBinhLuanBai(_ cid: Int) -> APIEndpoint { goi("/feed/comments/\(cid)", "DELETE", nil) }
    static func camXucBinhLuan(_ cid: Int, _ k: CamXucBangTin?) -> APIEndpoint {
        k.map { goi("/feed/comments/\(cid)/reaction", "PUT", ["kind": $0.rawValue]) } ?? goi("/feed/comments/\(cid)/reaction", "DELETE", nil)
    }
    static func goBinhLuan(_ cid: Int, _ an: Bool) -> APIEndpoint { goi("/feed/comments/\(cid)/moderation", "PUT", ["hidden": an]) }
    static func baoCaoBinhLuan(_ cid: Int, lyDo: String, chiTiet: String?) -> APIEndpoint {
        var t: [String: Any] = ["reason": lyDo]
        if let chiTiet, !chiTiet.isEmpty { t["detail"] = String(chiTiet.prefix(1000)) }
        return goi("/feed/comments/\(cid)/report", "POST", t)
    }

    // §6 Tải tệp
    static func xinTaiLenBangTin(ws: Int, ten: String, mime: String, coByte: Int, kind: String) -> APIEndpoint {
        goi("/feed/uploads/presign", "POST", ["workspaceId": ws, "fileName": ten, "mime": mime, "size": coByte, "kind": kind])
    }
    static func xongTaiLenBangTin(_ id: Int, rong: Int?, cao: Int?, thoiLuongMs: Int?) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let rong { t["width"] = rong }
        if let cao { t["height"] = cao }
        if let thoiLuongMs { t["durationMs"] = thoiLuongMs }
        return goi("/feed/uploads/\(id)/complete", "POST", t)
    }
    static func moTaTep(_ id: Int, alt: String) -> APIEndpoint { goi("/feed/uploads/\(id)", "PATCH", ["alt": alt]) }
    static func xoaNhapTep(_ id: Int) -> APIEndpoint { goi("/feed/uploads/\(id)", "DELETE", nil) }
    static func duongTep(_ id: Int, kieu: String = "full", taiVe: Bool = false) -> APIEndpoint {
        var q: [String: Any] = ["variant": kieu]
        if taiVe { q["download"] = 1 }
        return get("/feed/attachments/\(id)/url", q)
    }
    static func xemTruocLink(_ url: String) -> APIEndpoint { goi("/feed/link-preview", "POST", ["url": url]) }

    // §7 Kiểm duyệt
    static func baoCaoBangTin(ws: Int?, trangThai: String, cursor: String?) -> APIEndpoint {
        var q: [String: Any] = ["status": trangThai]
        if let ws { q["workspaceId"] = ws }
        if let cursor { q["cursor"] = cursor }
        return get("/feed/reports", q)
    }
    static func xuLyBaoCao(_ id: Int, go: Bool) -> APIEndpoint {
        goi("/feed/reports/\(id)/resolve", "POST", ["action": go ? "remove" : "dismiss"])
    }
}

// MARK: - Bộ lọc bảng tin → tham số `GET /feed`

/// Một phạm vi + bộ lọc. Không `ws`/`pid` = bảng tin GỘP (My Work › Bảng tin).
struct LocBangTin: Hashable, Codable {
    enum Kieu: String, Codable, CaseIterable { case all, mine, media, saved, files }
    var ws: Int?
    var pid: Int?
    /// `level=workspace` — chỉ bài cấp không gian.
    var chiKhongGian = false
    var kieu: Kieu = .all
    var tacGia: Int?
    var q: String?

    static let gop = LocBangTin()
    static func duAn(_ pid: Int) -> LocBangTin { LocBangTin(pid: pid) }
    static func khongGian(_ ws: Int) -> LocBangTin { LocBangTin(ws: ws) }

    var thamSo: [String: Any] {
        var t: [String: Any] = [:]
        if let pid { t["projectId"] = pid } else if let ws { t["workspaceId"] = ws }
        if chiKhongGian, ws != nil, pid == nil { t["level"] = "workspace" }
        if kieu != .all { t["filter"] = kieu.rawValue }
        if let tacGia { t["author"] = tacGia }
        if let q, !q.trimmingCharacters(in: .whitespaces).isEmpty { t["q"] = q }
        return t
    }

    /// Máy chủ trả mục ghim riêng CHỈ khi lọc theo MỘT phạm vi, `filter=all`, không `q`/`author` (hợp đồng §3).
    var coMucGhim: Bool { (ws != nil || pid != nil) && kieu == .all && tacGia == nil && (q ?? "").isEmpty }

    /// Một bài thuộc phạm vi này không (lọc sự kiện socket `post.created`).
    func thuoc(ws w: Int?, pid p: Int?) -> Bool {
        if let pid { return p == pid }
        if let ws {
            if chiKhongGian { return w == ws && p == nil }
            return w == ws
        }
        return true
    }
}

// MARK: - Tải tệp lên (đường A + B, có tiến độ + huỷ)

enum TaiLenBangTin {
    static let tranAnh = 20 * 1024 * 1024
    static let tranQuaMayChu = 25 * 1024 * 1024
    static let tranVideo = 200 * 1024 * 1024
    static let tranTep = 100 * 1024 * 1024

    enum Loi: LocalizedError {
        case quaLon(Int), hong(Int), khongDocDuoc
        var errorDescription: String? {
            switch self {
            case .quaLon(let mb): return String(localized: "This file is too large (max \(mb) MB).")
            case .hong(let ma): return String(localized: "Upload failed (\(ma)). Please try again.")
            case .khongDocDuoc: return String(localized: "Couldn't read this file.")
            }
        }
    }

    static func mime(cho ten: String) -> String {
        UTType(filenameExtension: (ten as NSString).pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }

    /// Theo dõi tiến độ gửi thân (`didSendBodyData`) của MỘT task — gắn bằng `delegate:` của `URLSession.shared`.
    final class TheoDoi: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        let baoTienDo: @Sendable (Double) -> Void
        init(_ f: @escaping @Sendable (Double) -> Void) { baoTienDo = f }
        func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                        totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            guard totalBytesExpectedToSend > 0 else { return }
            baoTienDo(min(1, Double(totalBytesSent) / Double(totalBytesExpectedToSend)))
        }
    }

    /// Đường A — `POST /feed/uploads` multipart (`file`, `workspaceId`, `alt`).
    static func quaMayChu(ws: Int, du: Data, ten: String, mime: String, alt: String? = nil,
                          tienDo: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> CTWFeedAttachment {
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/work/feed/uploads") else { throw APIError.invalidURL }
        let ranh = "Boundary-\(UUID().uuidString)"
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.timeoutInterval = 300
        r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        r.setValue("multipart/form-data; boundary=\(ranh)", forHTTPHeaderField: "Content-Type")
        if let token = StorageManager.shared.getAuthToken() { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var than = Data()
        func noi(_ s: String) { than.append(Data(s.utf8)) }
        noi("--\(ranh)\r\nContent-Disposition: form-data; name=\"workspaceId\"\r\n\r\n\(ws)\r\n")
        if let alt, !alt.isEmpty { noi("--\(ranh)\r\nContent-Disposition: form-data; name=\"alt\"\r\n\r\n\(alt)\r\n") }
        let tenAnToan = ten.replacingOccurrences(of: "\"", with: "")
        noi("--\(ranh)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(tenAnToan)\"\r\nContent-Type: \(mime)\r\n\r\n")
        than.append(du)
        noi("\r\n--\(ranh)--\r\n")
        let (d, res) = try await URLSession.shared.upload(for: r, from: than, delegate: TheoDoi(tienDo))
        return try giaiMa(d, res)
    }

    /// Đường B — xin URL ký ⇒ PUT thẳng ⇒ complete. Trả bản nháp READY.
    static func quaUrlKy(ws: Int, tepCucBo: URL, ten: String, mime: String, kind: String, coByte: Int,
                         rong: Int? = nil, cao: Int? = nil, thoiLuongMs: Int? = nil,
                         tienDo: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> CTWFeedAttachment {
        let xin: CTWFeedXinTaiLen = try await APIClient.shared.request(
            CTWAPI.xinTaiLenBangTin(ws: ws, ten: ten, mime: mime, coByte: coByte, kind: kind))
        guard let u = URL(string: xin.uploadUrl) else { throw Loi.hong(0) }
        var r = URLRequest(url: u)
        r.httpMethod = xin.method ?? "PUT"
        r.timeoutInterval = 900
        // PHẢI gửi đúng header đã ký (chữ ký khoá `Content-Type`) — sai một ký tự ⇒ R2 trả 403.
        let dau = xin.headers ?? ["Content-Type": mime]
        for (k, v) in dau { r.setValue(v, forHTTPHeaderField: k) }
        if dau["Content-Type"] == nil { r.setValue(mime, forHTTPHeaderField: "Content-Type") }
        do {
            let (_, res) = try await URLSession.shared.upload(for: r, fromFile: tepCucBo, delegate: TheoDoi(tienDo))
            let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(ma) else { throw Loi.hong(ma) }
        } catch {
            // PUT hỏng (mạng chặn R2, CSP…) mà tệp ≤ 25 MB ⇒ lùi về đường A như web; bỏ nháp PENDING.
            _ = try? await APIClient.shared.send(CTWAPI.xoaNhapTep(xin.attachment.id))
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            guard coByte <= tranQuaMayChu, let du = try? Data(contentsOf: tepCucBo) else { throw error }
            return try await quaMayChu(ws: ws, du: du, ten: ten, mime: mime, tienDo: tienDo)
        }
        return try await APIClient.shared.request(CTWAPI.xongTaiLenBangTin(xin.attachment.id, rong: rong, cao: cao, thoiLuongMs: thoiLuongMs))
    }

    /// `POST /feed/uploads/:id/poster` — ảnh khung đầu của video (tuỳ chọn, hỏng thì bỏ qua).
    static func anhBia(_ id: Int, jpeg: Data) async throws -> CTWFeedAttachment {
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/work/feed/uploads/\(id)/poster") else { throw APIError.invalidURL }
        let ranh = "Boundary-\(UUID().uuidString)"
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        r.setValue("multipart/form-data; boundary=\(ranh)", forHTTPHeaderField: "Content-Type")
        if let token = StorageManager.shared.getAuthToken() { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var than = Data()
        than.append(Data("--\(ranh)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"poster.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        than.append(jpeg)
        than.append(Data("\r\n--\(ranh)--\r\n".utf8))
        let (d, res) = try await URLSession.shared.upload(for: r, from: than)
        return try giaiMa(d, res)
    }

    private static func giaiMa(_ d: Data, _ res: URLResponse) throws -> CTWFeedAttachment {
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(ma) else {
            if let e = try? JSONDecoder().decode(EmptyEnvelope.self, from: d), let m = e.message, !m.isEmpty {
                if let c = e.code, !c.isEmpty { throw APIError.coMa(ma: c, thongDiep: m) }
                throw APIError.serverError(m)
            }
            throw Loi.hong(ma)
        }
        let goi = try JSONDecoder().decode(APIResponse<CTWFeedAttachment>.self, from: d)
        guard goi.success, let a = goi.data else { throw APIError.serverError(goi.message ?? "Upload failed") }
        return a
    }
}
