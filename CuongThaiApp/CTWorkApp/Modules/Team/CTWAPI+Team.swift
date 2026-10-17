import Foundation

// MARK: - CTWAPI — Team (thành viên dự án, nhóm không gian, link mời)
// Nguồn: work.routes.ts:409-436 (invite-links), :512 (members), :1675 (teams); work.uxc.routes.ts:42.

extension CTWAPI {
    /// Đổi vai trò dự án — chỉ ADMIN dự án (`permissions.manageMembers`).
    static func doiVaiTro(pid: Int, uid: Int, vaiTro: String) -> APIEndpoint {
        goi("/projects/\(pid)/members/\(uid)", "PUT", ["role": vaiTro])
    }
    static func xoaThanhVien(pid: Int, uid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/members/\(uid)", "DELETE", nil)
    }
    static func nhomKhongGian(wsId: Int) -> APIEndpoint { get("/workspaces/\(wsId)/teams") }
    static func tongQuanNhom(pid: Int) -> APIEndpoint { get("/projects/\(pid)/team-overview") }

    /// Tạo link mời (OWNER/ADMIN không gian; có `projectId` thì phải là ADMIN dự án đó).
    static func taoLinkMoi(wsId: Int, vaiTro: String, pid: Int?, vaiTroDuAn: String?, soLan: Int, soNgay: Int) -> APIEndpoint {
        var b: [String: Any] = ["role": vaiTro, "maxUses": soLan, "expiresInDays": soNgay]
        if let pid { b["projectId"] = pid }
        if let vaiTroDuAn { b["projectRole"] = vaiTroDuAn }
        return goi("/workspaces/\(wsId)/invite-links", "POST", b)
    }
}
