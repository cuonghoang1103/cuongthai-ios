import XCTest
@testable import CTWork

/// Kiểm thử mảng Team · AI agents · Assets · Resources · Diagrams · Finance.
/// Dữ liệu mẫu (`Debug/XemThuCTW+ToChuc.swift`) viết theo hình dạng thật của service;
/// giải mã bằng chính model của app ⇒ bắt lệch kiểu (CLAUDE.md C3/C4).
final class ToChucCTWTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    // MARK: Giải mã

    func testTeam() throws {
        let t = try giai(CTWTongQuanNhom.self, "/work/projects/7/team-overview")
        XCTAssertEqual(t.totals?.members, 6)
        XCTAssertEqual(t.people?.first { $0.user?.laAgent == true }?.name, "Scout")
        let n = try giai([CTWNhomKhongGian].self, "/work/workspaces/1/teams")
        // Mảng B (XemThuCTW+B3) cũng trả mẫu cho cùng đường — chỉ chắc hình dạng, không chắc số lượng.
        XCTAssertGreaterThanOrEqual(n.count, 2)
        XCTAssertEqual(n[0].members?.first { $0.teamRole == "LEAD" }?.nguoi.ten, "Alex Morgan")
        XCTAssertTrue(n[0].members?.contains { $0.nguoi.laAgent } == true)
        let l = try giai(CTWLinkMoi.self, "/work/workspaces/1/invite-links", method: "POST", body: ["maxUses": 10, "expiresInDays": 3])
        XCTAssertTrue(l.url.contains("/work/invite/"))
        XCTAssertEqual(l.maxUses, 10)
    }

    func testAgents() throws {
        let ds = try giai([CTWAgentHoSo].self, "/work/workspaces/1/agents")
        XCTAssertEqual(ds.first?.user?.laAgent, true)
        XCTAssertNil(ds.first?.canManage, "danh sách không có canManage — chỉ chi tiết có")
        let a = try giai(CTWAgentHoSo.self, "/work/workspaces/1/agents/4")
        XCTAssertEqual(a.canManage, true)
        XCTAssertEqual(a.projects?.count, 2)
        let p = try giai(CTWAgentHoSo.self, "/work/workspaces/1/agents/4/pause", method: "POST")
        XCTAssertEqual(p.status, "PAUSED")
        let ls = try giai([CTWAgentLeaseLichSu].self, "/work/workspaces/1/agents/4/leases")
        XCTAssertEqual(ls.first?.issue?.key, "NW-16")
        let chip = try giai([CTWAgentChip].self, "/work/projects/7/agent-leases")
        XCTAssertEqual(chip.first?.agentUserId, 9)
    }

    func testTaiSanNguonLucSoDo() throws {
        let t = try giai(CTWDsTaiSan.self, "/work/projects/7/assets")
        XCTAssertEqual(t.items?.count, 5)
        XCTAssertEqual(t.summary?.annualCost?["USD"], 279)
        XCTAssertEqual(t.items?.first { $0.attributionRequired == true }?.links?.first?.kind, "PAGE")
        let mot = try giai(CTWTaiSan.self, "/work/projects/7/assets/3")
        XCTAssertEqual(mot.key, "AST-3")
        XCTAssertNil(mot.expiresAt)

        let r = try giai(CTWDsNguonLuc.self, "/work/projects/7/resources")
        XCTAssertEqual(r.items?.count, 5)
        XCTAssertEqual(r.items?.first?.github?.stars, 48)
        XCTAssertEqual(r.broken, 1)

        let d = try giai(CTWDsSoDo.self, "/work/projects/7/diagrams")
        XCTAssertEqual(d.items?.count, 4)
        XCTAssertEqual(d.items?.first { $0.updatedBy?.isAgent == true }?.updatedBy?.nguoi.laAgent, true)
        let ct = try giai(CTWSoDoChiTiet.self, "/work/projects/7/diagrams/2")
        XCTAssertEqual(ct.banMacDinh, 3, "mặc định xem bản ĐÃ DUYỆT, không phải bản mới nhất")
        XCTAssertEqual(ct.versions?.count, 4)
        XCTAssertEqual(ct.comments?.count, 2)
    }

    func testTaiChinh() throws {
        let c = try giai(CTWTaiChinhCaiDat.self, "/work/projects/7/finance/settings")
        XCTAssertEqual(c.access?.manage, true)
        let s = try giai(CTWTaiChinhTongQuan.self, "/work/projects/7/finance/summary")
        XCTAssertEqual(s.summary?.alerts, ["WARN", "FORECAST_OVER"])
        XCTAssertEqual(s.byStage?.count, 3)
        XCTAssertNil(s.byCategory?.first?.id)
        let m = try giai(CTWDsMocThanhToan.self, "/work/projects/7/finance/payments")
        XCTAssertEqual(m.items?.first { $0.overdue == true }?.status, "DUE")
        let e = try giai([CTWChiPhi].self, "/work/projects/7/finance/expenses")
        XCTAssertEqual(e.count, 2)
        let t = try giai(CTWDsBangCong.self, "/work/projects/7/finance/timesheets")
        XCTAssertEqual(t.items?.first { $0.status == "RETURNED" }?.returnReason, "Missing Thursday entries")
    }

    // MARK: Logic hiển thị

    func testChipAgent() {
        let bayGio = Date()
        let iso = ISO8601DateFormatter()
        let tuongLai = iso.string(from: bayGio.addingTimeInterval(600))
        let quaKhu = iso.string(from: bayGio.addingTimeInterval(-600))
        XCTAssertEqual(CTWAgentHienThi.chip(status: "ACTIVE", expiresAt: tuongLai, pct: 72, bayGio: bayGio).chu, "working · 72%")
        XCTAssertEqual(CTWAgentHienThi.chip(status: "ACTIVE", expiresAt: tuongLai, pct: nil, bayGio: bayGio).chu, "working")
        XCTAssertEqual(CTWAgentHienThi.chip(status: "ACTIVE", expiresAt: quaKhu, pct: 72, bayGio: bayGio).chu, "stalled",
                       "ACTIVE mà quá hạn = mất nhịp tim ⇒ stalled (như web)")
        XCTAssertTrue(CTWAgentHienThi.chip(status: "EXPIRED", expiresAt: tuongLai, pct: 40, bayGio: bayGio).ket)
        XCTAssertEqual(AgentsCTW.tachMa("NW-16")?.0, "NW")
        XCTAssertEqual(AgentsCTW.tachMa("MY-APP-7")?.1, 7, "mã dự án có gạch ⇒ tách ở gạch cuối")
        XCTAssertNil(AgentsCTW.tachMa("NW"))
    }

    func testNhanHanTaiSan() {
        XCTAssertEqual(CTWTaiSanHienThi.nhanHan(.init(state: "EXPIRING", daysLeft: 44)).chu, "Expires in 44 days")
        XCTAssertEqual(CTWTaiSanHienThi.nhanHan(.init(state: "EXPIRING", daysLeft: 1)).chu, "Expires in 1 day")
        XCTAssertEqual(CTWTaiSanHienThi.nhanHan(.init(state: "EXPIRING", daysLeft: 0)).chu, "Expires today")
        XCTAssertEqual(CTWTaiSanHienThi.nhanHan(.init(state: "EXPIRED", daysLeft: -3)).chu, "Expired 3 days ago")
        XCTAssertEqual(CTWTaiSanHienThi.nhanHan(.init(state: "NONE", daysLeft: nil)).chu, "No expiry")
        XCTAssertEqual(CTWTaiSanHienThi.nhanHan(nil).chu, "No expiry")
    }

    func testDinhDangTien() {
        XCTAssertEqual(CTWTien.dinhDang(471_698_113, "VND"), "471,698,113 VND", "VND không có phần lẻ")
        XCTAssertEqual(CTWTien.dinhDang(99, "usd"), "99 USD")
        XCTAssertEqual(CTWTien.dinhDang(2040.5, "USD"), "2,040.50 USD")
        XCTAssertEqual(CTWTien.dinhDang(nil, "USD"), "—")
        XCTAssertEqual(CTWTien.gon(471_698_113, "VND"), "472M VND")
        XCTAssertEqual(CTWTien.gon(12_000_000, "VND"), "12.0M VND")
        XCTAssertEqual(CTWTien.gon(-71_698_113, "VND"), "-71.7M VND")
        XCTAssertEqual(CTWTien.cpi(0.848), "0.85")
        XCTAssertEqual(CTWTien.phanTram(82.5), "82.5%")
        XCTAssertEqual(CTWTien.phanTram(70), "70%")
        XCTAssertEqual(CTWTien.gio(2400), "40 h")
        XCTAssertEqual(CTWTien.gio(90), "1.5 h")
    }
}
