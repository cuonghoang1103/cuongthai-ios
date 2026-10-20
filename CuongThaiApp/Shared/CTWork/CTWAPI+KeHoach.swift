import Foundation

// MARK: - CTWAPI — sửa hàng loạt · di chuyển/xếp hạng · JQL · bộ lọc đã lưu · xuất CSV (đợt B, 21/10/2026)
//
// Hình dạng đối chiếu backend `src/routes/work.routes.ts` (đọc handler + zod, không đoán):
//   POST /projects/:pid/issues/bulk  {numbers ≤200, patch:{sprintId?,assigneeId?,priority?,statusId?,parentId?,addLabelIds?,delete?}}
//        ⇒ {updated:[number], failed:[{number,error}]} — thẻ hỏng báo riêng, thẻ khác vẫn đi (`sprints.service.bulkUpdate`).
//   POST /projects/:pid/issues/:num/move  {statusId?, sprintId?(null = backlog), beforeIssueId?, afterIssueId?, version?}
//        `beforeIssueId` = thẻ đứng NGAY TRÊN chỗ thả, `afterIssueId` = thẻ NGAY DƯỚI (`issueChange.moveIssue` ⇒ rankBetween).
//   GET  /projects/:pid/search?jql=&limit(≤500)&offset ⇒ {total, items:[IssueCard], offset, limit} (`CTWKetQuaJql`, mô-đun Reports);
//        JQL sai ⇒ 400 WORK_JQL_ERROR.
//   GET/POST/DELETE /projects/:pid/filters ⇒ SavedFilter {id,name,query,shared,ownerId,updatedAt,owner{username}}.
//   GET  /projects/:pid/export?format=csv&jql= ⇒ tệp CSV thô (KHÔNG phong bì JSON).
//   GET  /workspaces/:wsId/teams ⇒ bộ phận (lọc board khi dự án bật mô-đun `teams`).
// Dùng chung app chính + app CT Work (board nằm ở Shared).

extension CTWAPI {
    static func suaHangLoat(pid: Int, so: [Int], patch: [String: Any]) -> APIEndpoint {
        goi("/projects/\(pid)/issues/bulk", "POST", ["numbers": Array(so.prefix(200)), "patch": patch])
    }

    /// Di chuyển một thẻ: đổi sprint (`sprint`: `.some(nil)` = về backlog) và/hoặc xếp hạng giữa hai hàng xóm.
    static func diChuyen(pid: Int, so: Int, sprint: Int??, truoc: Int?, sau: Int?, statusId: Int? = nil, version: Int?) -> APIEndpoint {
        var than: [String: Any] = [:]
        if let sprint { than["sprintId"] = sprint ?? NSNull() }
        if let truoc { than["beforeIssueId"] = truoc }
        if let sau { than["afterIssueId"] = sau }
        if let statusId { than["statusId"] = statusId }
        if let version { than["version"] = version }
        return goi("/projects/\(pid)/issues/\(so)/move", "POST", than)
    }

    static func timTheoJql(pid: Int, jql: String, limit: Int = 100, offset: Int = 0) -> APIEndpoint {
        var q: [String: Any] = ["jql": String(jql.prefix(4000)), "limit": limit]
        if offset > 0 { q["offset"] = offset }
        return get("/projects/\(pid)/search", q)
    }

    static func boLocDaLuu(pid: Int) -> APIEndpoint { get("/projects/\(pid)/filters") }
    static func luuBoLoc(pid: Int, id: Int? = nil, ten: String, jql: String, chiaSe: Bool) -> APIEndpoint {
        var than: [String: Any] = ["name": String(ten.prefix(100)), "query": String(jql.prefix(4000)), "shared": chiaSe]
        if let id { than["id"] = id }
        return goi("/projects/\(pid)/filters", "POST", than)
    }
    static func xoaBoLoc(pid: Int, id: Int) -> APIEndpoint { goi("/projects/\(pid)/filters/\(id)", "DELETE") }

    /// CSV thô — đọc bằng `APIClient.requestRaw`.
    static func xuatCsv(pid: Int, jql: String) -> APIEndpoint {
        get("/projects/\(pid)/export", ["format": "csv", "jql": String(jql.prefix(4000))])
    }

    static func boPhanKhongGian(wsId: Int) -> APIEndpoint { get("/workspaces/\(wsId)/teams") }
}

// MARK: Model

struct CTWKetQuaHangLoat: Codable {
    struct Hong: Codable, Hashable { var number: Int; var error: String? }
    var updated: [Int]?
    var failed: [Hong]?
}

struct CTWBoLocLuu: Codable, Hashable, Identifiable {
    struct ChuSoHuu: Codable, Hashable { var username: String? }
    var id: Int
    var name: String
    var query: String
    var shared: Bool?
    var ownerId: Int?
    var updatedAt: String?
    var owner: ChuSoHuu?
}

/// Bộ phận của không gian — chỉ trường board cần (model đầy đủ ở mô-đun Team của app CT Work).
struct CTWBoPhan: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var key: String?
    var color: String?
}

// MARK: - Sửa hàng loạt — logic thuần (web `board/bulk.ts`)

enum CTWHangLoat {
    /// Tên trạng thái gộp MỌI quy trình (To do → In progress → Done, rồi theo vị trí). Đổi trạng thái hàng loạt đi
    /// THEO TÊN vì mỗi quy trình có id riêng (Bug "Done" ≠ Story "Done").
    static func tenTrangThai(_ cfg: CTWProjectConfig) -> [CTWStatus] {
        let bac = ["TODO": 0, "IN_PROGRESS": 1, "DONE": 2]
        var gap: [String: (CTWStatus, Int)] = [:]
        for s in cfg.tatCaTrangThai where gap[s.name] == nil {
            gap[s.name] = (s, (bac[s.category ?? "TODO"] ?? 0) * 1000 + (s.position ?? 0))
        }
        return gap.values.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.name < $1.0.name }.map(\.0)
    }

    /// Chia thẻ theo id trạng thái mang tên `ten` trong quy trình của loại thẻ. Thẻ mà quy trình không có tên đó ⇒ `thieu`.
    static func nhomTheoTen(_ cfg: CTWProjectConfig, the: [CTWIssueCard], ten: String) -> (nhom: [Int: [Int]], thieu: [Int]) {
        var nhom: [Int: [Int]] = [:]
        var thieu: [Int] = []
        for t in the {
            guard let st = cfg.quyTrinh(choLoai: t.typeId)?.statuses?.first(where: { $0.name == ten }) else { thieu.append(t.number); continue }
            nhom[st.id, default: []].append(t.number)
        }
        return (nhom, thieu)
    }

    /// Gửi hàng loạt; đổi trạng thái theo tên thì một lượt cho mỗi id trạng thái. Trả (đã đổi, hỏng).
    static func apDung(pid: Int, cfg: CTWProjectConfig, the: [CTWIssueCard], patch: [String: Any]?, tenTrangThai: String?) async throws -> CTWKetQuaHangLoat {
        if let ten = tenTrangThai {
            let (nhom, thieu) = nhomTheoTen(cfg, the: the, ten: ten)
            var daDoi: [Int] = []
            var hong: [CTWKetQuaHangLoat.Hong] = thieu.map {
                .init(number: $0, error: String(localized: "This issue's workflow has no “\(CTWTen.trangThai(ten))” status"))
            }
            for (sid, so) in nhom.sorted(by: { $0.key < $1.key }) {
                let r: CTWKetQuaHangLoat = try await APIClient.shared.request(CTWAPI.suaHangLoat(pid: pid, so: so, patch: ["statusId": sid]))
                daDoi += r.updated ?? []
                hong += r.failed ?? []
            }
            return CTWKetQuaHangLoat(updated: daDoi, failed: hong)
        }
        return try await APIClient.shared.request(CTWAPI.suaHangLoat(pid: pid, so: the.map(\.number), patch: patch ?? [:]))
    }
}

// MARK: - Xếp hạng khi thả (web Backlog `onDragEnd`) — logic thuần

enum CTWXepHang {
    struct KetQua: Equatable {
        /// Thẻ ngay TRÊN chỗ thả (`beforeIssueId`), nil = đầu khung.
        var truoc: Int?
        /// Thẻ ngay DƯỚI (`afterIssueId`), nil = cuối khung.
        var sau: Int?
        /// Thứ tự mới của khung đích (id) — vẽ lạc quan trước khi máy chủ trả lời.
        var thuTu: [Int]
    }

    /// `dich` = id các thẻ của khung đích theo thứ tự hiện tại (có thể chứa chính thẻ đang kéo nếu kéo trong cùng khung).
    /// `chenTruoc` = id thẻ mà người dùng thả LÊN (thẻ kéo sẽ đứng ngay trên nó); nil = thả xuống cuối khung.
    /// Trả nil khi thứ tự không đổi (thả về đúng chỗ cũ).
    static func viTriTha(dich: [Int], dangKeo: Int, chenTruoc: Int?) -> KetQua? {
        let conLai = dich.filter { $0 != dangKeo }
        var i = conLai.count
        if let c = chenTruoc, c != dangKeo, let j = conLai.firstIndex(of: c) { i = j }
        if let c = chenTruoc, c == dangKeo { return nil }
        let thuTu = Array(conLai[..<i]) + [dangKeo] + Array(conLai[i...])
        if thuTu == dich { return nil }
        return KetQua(truoc: i > 0 ? conLai[i - 1] : nil, sau: i < conLai.count ? conLai[i] : nil, thuTu: thuTu)
    }

    /// Chuyển thẻ lên/xuống một bậc trong khung (đường thay cho kéo — VoiceOver, một tay).
    static func dichMotBac(dich: [Int], the: Int, len: Bool) -> KetQua? {
        guard let i = dich.firstIndex(of: the) else { return nil }
        if len {
            guard i > 0 else { return nil }
            return viTriTha(dich: dich, dangKeo: the, chenTruoc: dich[i - 1])
        }
        guard i + 1 < dich.count else { return nil }
        return viTriTha(dich: dich, dangKeo: the, chenTruoc: i + 2 < dich.count ? dich[i + 2] : nil)
    }
}
