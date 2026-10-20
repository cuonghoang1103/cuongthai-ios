import Foundation

// MARK: - CTWAPI — "Create with CuongMini" + tạo dự án
//
// Đối chiếu api-backend `src/routes/work.taoCuongMini.routes.ts` (commit ee507275) và `work.routes.ts`
// (`POST /workspaces/:wsId/projects`, `POST /projects/:pid/sample-data`). `ws` là id SỐ.
// Quyền: máy chủ kiểm `workspace.createProject` (OWNER/ADMIN/MEMBER) + chỉ người tạo bản nháp; agent bị chặn.
// Không gọi: `/setup/models` + `/setup/unlock` (mở khoá model bằng khoá chung — iOS chỉ dùng model mặc định, KHÔNG có
// đường "mở khoá" nào trong app; App Store 3.1.1).

extension CTWAPI {
    // Bản nháp
    static func cmDsBanNhap(ws: Int) -> APIEndpoint { get("/workspaces/\(ws)/setup-drafts") }
    static func cmTaoBanNhap(ws: Int, cheDo: String, dauVao: CTWDauVaoCM) -> APIEndpoint {
        goi("/workspaces/\(ws)/setup-drafts", "POST", ["mode": cheDo, "input": CTWJSON.tu(dauVao.sach())?.foundation ?? [:]])
    }
    static func cmBanNhap(id: Int) -> APIEndpoint { get("/setup-drafts/\(id)") }
    /// PATCH — chỉ gửi phần đổi (`input` / `understanding` / `plan` / `model`).
    static func cmSua(id: Int, dauVao: CTWDauVaoCM? = nil, hieu: CTWJSON? = nil, keHoach: CTWJSON? = nil, model: String? = nil) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let dauVao { t["input"] = CTWJSON.tu(dauVao.sach())?.foundation }
        if let hieu { t["understanding"] = hieu.foundation }
        if let keHoach { t["plan"] = keHoach.foundation }
        if let model { t["model"] = model }
        return goi("/setup-drafts/\(id)", "PATCH", t)
    }
    static func cmXoa(id: Int) -> APIEndpoint { goi("/setup-drafts/\(id)", "DELETE", nil) }
    static func cmThemLink(id: Int, url: String, loai: String) -> APIEndpoint {
        goi("/setup-drafts/\(id)/links", "POST", ["url": String(url.prefix(2000)), "category": loai])
    }
    static func cmXoaNguon(id: Int, sid: String) -> APIEndpoint { goi("/setup-drafts/\(id)/sources/\(doan(sid))", "DELETE", nil) }
    static func cmDanhSach(ws: Int, chu: String) -> APIEndpoint { goi("/workspaces/\(ws)/setup/roster", "POST", ["text": String(chu.prefix(400_000))]) }

    // Việc của CuongMini (job chạy ở máy chủ — trả 202 + bản nháp `busy`, app hỏi lại mỗi 1,5 s)
    static func cmDoc(id: Int, docLai: String? = nil) -> APIEndpoint {
        var t: [String: Any] = [:]
        if let docLai, !docLai.isEmpty { t["reread"] = String(docLai.prefix(6000)) }
        return goi("/setup-drafts/\(id)/understand", "POST", t)
    }
    static func cmChapNhan(id: Int, hieu: CTWJSON?, xemTruoc: Bool, guiMoi: Bool) -> APIEndpoint {
        var t: [String: Any] = ["reviewFirst": xemTruoc, "sendInvites": guiMoi]
        if let hieu { t["understanding"] = hieu.foundation }
        return goi("/setup-drafts/\(id)/accept", "POST", t)
    }
    static func cmNhoSua(id: Int, loiDan: String) -> APIEndpoint { goi("/setup-drafts/\(id)/revise", "POST", ["instruction": String(loiDan.prefix(4000))]) }
    static func cmCanLai(id: Int) -> APIEndpoint { goi("/setup-drafts/\(id)/rebalance", "POST") }
    static func cmTao(id: Int, guiMoi: Bool) -> APIEndpoint { goi("/setup-drafts/\(id)/apply", "POST", ["sendInvites": guiMoi]) }
    static func cmHuy(id: Int) -> APIEndpoint { goi("/setup-drafts/\(id)/cancel", "POST") }

    // Tạo dự án thường (hộp "New project" của web — `workspace/CreateProjectDialog.tsx`)
    static func taoDuAn(ws: Int, ten: String, ma: String, loaiBang: String, mau: String, loai: String, quyen: String, moTa: String?) -> APIEndpoint {
        var t: [String: Any] = ["name": String(ten.prefix(120)), "key": ma, "type": loaiBang, "template": mau, "kind": loai, "visibility": quyen]
        if let moTa, !moTa.isEmpty { t["description"] = String(moTa.prefix(5000)) }
        return goi("/workspaces/\(ws)/projects", "POST", t)
    }
    static func themDuLieuMau(pid: Int) -> APIEndpoint { goi("/projects/\(pid)/sample-data", "POST") }
}

/// `POST /workspaces/:wsId/projects` ⇒ `{id, key, name, kind, modules}`.
struct CTWDuAnMoi: Codable { var id: Int; var key: String; var name: String; var kind: String? }
