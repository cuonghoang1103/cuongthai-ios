import XCTest
import SwiftUI
@testable import CTWork

/// Mảng "dịch vụ" (Service desk · Intake · Forms · Cổng khách · Lớp học · Nộp sản phẩm):
/// giải mã dữ liệu mẫu (đúng hình dạng service backend) bằng model thật + luật thuần.
final class DichVuCTWTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    // MARK: Service desk

    func testHangChoVaTicket() throws {
        let h = try giai(CTWDeskHang.self, "/work/projects/7/desk/queue")
        XCTAssertEqual(h.items?.count, 4)
        XCTAssertEqual(h.counts?["breached"], 1)
        XCTAssertEqual(h.canWork, true)
        let vo = try XCTUnwrap(h.items?.first { $0.number == 45 })
        XCTAssertEqual(vo.firstResponse?.status, "BREACHED")
        XCTAssertNil(vo.assignee, "assignee null ⇒ nil, không hỏng cả hàng chờ")
        XCTAssertEqual(h.items?.first { $0.number == 48 }?.assignee?.laAgent, true)

        let t = try giai(CTWDeskChiTiet.self, "/work/projects/7/issues/52/desk")
        XCTAssertEqual(t.ticket?.priority, "P2")
        XCTAssertEqual(t.ticket?.fields?.last?.value?.hienThi, "120", "giá trị số trong trường ticket vẫn đọc được")
        XCTAssertEqual(t.ticket?.events?.count, 3)
        let bl = try giai([CTWComment].self, "/work/projects/7/issues/52/comments")
        XCTAssertEqual(bl.filter { $0.visibility == "INTERNAL" }.count, 2)
    }

    func testMauVaNhanSla() {
        XCTAssertEqual(CTWDesk.nhanSla(CTWSla(status: "AT_RISK", label: "2h left")), "2h left")
        XCTAssertEqual(CTWDesk.nhanSla(CTWSla(status: "ON_TRACK", paused: true)), "Paused")
        XCTAssertEqual(CTWDesk.nhanSla(nil), "—")
        XCTAssertEqual(CTWDesk.mauSla(CTWSla(status: "BREACHED", paused: true)), AppColors.error, "vỡ hạn thì đỏ kể cả khi đang tạm dừng")
        XCTAssertEqual(CTWDesk.mauSla(CTWSla(status: "MET")), AppColors.success)
        XCTAssertEqual(CTWDesk.mauSla(CTWSla(status: "AT_RISK")), AppColors.warning)
        XCTAssertEqual(CTWDesk.mauSla(CTWSla(status: "ON_TRACK", paused: true)), AppColors.textSecondary)
        XCTAssertEqual(CTWDesk.cheDo.map(\.ma), ["open", "unassigned", "mine", "at_risk", "breached", "waiting", "resolved"])
    }

    func testGiaTriTuDo() throws {
        let json = #"{"a":"x","b":3,"c":2.5,"d":true,"e":["p","q"],"f":null,"g":{"name":"file.pdf"}}"#
        let m = try JSONDecoder().decode([String: CTWGiaTri].self, from: Data(json.utf8))
        XCTAssertEqual(m["a"]?.hienThi, "x")
        XCTAssertEqual(m["b"]?.hienThi, "3")
        XCTAssertEqual(m["c"]?.hienThi, "2.50")
        XCTAssertEqual(m["d"]?.hienThi, "Yes")
        XCTAssertEqual(m["e"]?.hienThi, "p, q")
        XCTAssertEqual(m["f"]?.hienThi, "")
        XCTAssertEqual(m["g"], .rong, "object lạ (tệp) không làm hỏng cả câu trả lời")
    }

    // MARK: Intake · Forms

    func testIntakeVaForms() throws {
        let d = try giai(CTWDsDeXuat.self, "/work/projects/7/intake/proposals")
        XCTAssertEqual(d.proposals?.count, 3)
        XCTAssertEqual(d.counts?["PENDING"], 3)
        XCTAssertEqual(d.proposals?.first?.nguoiGui, "Minh Vo")
        let q = try giai(CTWDeXuat.self, "/work/projects/7/intake/proposals/88/decide", method: "POST", body: ["decision": "ACCEPT"])
        XCTAssertEqual(q.status, "ACCEPTED")
        XCTAssertEqual(q.issue?.key, "NW-44")

        let f = try giai(CTWDsForm.self, "/work/projects/7/forms")
        XCTAssertEqual(f.forms?.count, 2)
        XCTAssertEqual(f.forms?.last?.closed, "FULL")
        XCTAssertEqual(CTWFormNhan.lyDoDong("FULL"), "Response limit reached")
        let r = try giai(CTWTraLoiForm.self, "/work/projects/7/forms/3/responses")
        XCTAssertEqual(r.responses?.first?.answers?["f3"]?.hienThi, "5")
        XCTAssertEqual(r.summary?.first?.counts?.first?.n, 2)
        XCTAssertEqual(r.summary?.last?.average, 3.5)
    }

    // MARK: Cổng khách

    func testCongKhach() throws {
        let t = try giai(CTWPortalTongQuan.self, "/work/projects/7/portal/overview")
        XCTAssertEqual(t.stages?.count, 4)
        XCTAssertEqual(t.waitingOnClient?.first?.kind, "UAT")
        XCTAssertEqual(t.viewer?.preview, true)
        let ds = try giai(CTWPortalDsYeuCau.self, "/work/projects/7/portal/requests")
        XCTAssertEqual(ds.items?.first?.mine, true)
        let ct = try giai(CTWPortalYeuCauCT.self, "/work/projects/7/portal/requests/52")
        XCTAssertEqual(ct.comments?.count, 2)
        XCTAssertEqual(ct.attachments?.first?.laAnh, true)
        let dy = try giai(CTWPortalDsDuyet.self, "/work/projects/7/portal/approvals")
        XCTAssertEqual(dy.items?.first?.canDecide, true)
        XCTAssertEqual(dy.items?.first?.steps?.last?.isClient, true)
        let tl = try giai(CTWPortalTaiLieu.self, "/work/projects/7/portal/documents")
        XCTAssertEqual(tl.pages?.count, 2)
        // UAT có route quyết định riêng của cổng; loại khác dùng route phê duyệt chung.
        let uat = try XCTUnwrap(dy.items?.first)
        XCTAssertEqual(CTWAPI.portalQuyet(pid: 7, d: uat, dongY: true, yKien: "").path, "/api/v1/work/projects/7/portal/uat/41/decide")
        let doc = try XCTUnwrap(dy.items?.last)
        XCTAssertEqual(CTWAPI.portalQuyet(pid: 7, d: doc, dongY: false, yKien: "x").path, "/api/v1/work/projects/7/approvals/33/decide")
    }

    // MARK: Lớp học · Nộp sản phẩm

    func testLopHoc() throws {
        let ds = try giai(CTWDsLop.self, "/work/classes")
        XCTAssertEqual(ds.teaching?.first?.role, "TEACHER")
        XCTAssertEqual(ds.enrolled?.first?.laSinhVien, true)
        let l = try giai(CTWLopChiTiet.self, "/work/classes/4")
        XCTAssertEqual(l.groups?.count, 2)
        XCTAssertEqual(l.groups?.first?.project?.key, "SWP")
        let bt = try giai(CTWDsBaiTap.self, "/work/classes/4/assignments")
        XCTAssertEqual(bt.assignments?.last?.my?.grade?.points, 8.5)
        let ct = try giai(CTWBaiTapChiTiet.self, "/work/classes/4/assignments/12")
        XCTAssertEqual(ct.submission?.links?.first?.label, "DrawSQL diagram")
        XCTAssertEqual(ct.submission?.files?.count, 1)
        let tin = try giai(CTWBangTinLop.self, "/work/classes/4/stream")
        XCTAssertEqual(tin.posts?.first?.pinned, true)
        XCTAssertEqual(tin.posts?.first?.comments?.first?.body, "Noted, thanks!")
        let gd = try giai(CTWTongQuanGiangDay.self, "/work/teaching/overview")
        XCTAssertEqual(gd.totals?.red, 1)
        XCTAssertEqual(gd.groups?.first?.health?.reasons?.first?.code, "OVERDUE")
        XCTAssertEqual(gd.groups?.first?.docs?["R3"], "MISSING")
    }

    func testLuatNopBai() {
        XCTAssertFalse(CTWLopNhan.nopDuoc(nil))
        XCTAssertFalse(CTWLopNhan.nopDuoc(CTWBaiNop(text: "   ")), "chỉ khoảng trắng ⇒ chưa có gì để nộp")
        XCTAssertTrue(CTWLopNhan.nopDuoc(CTWBaiNop(text: "my answer")))
        XCTAssertTrue(CTWLopNhan.nopDuoc(CTWBaiNop(links: [CTWLienKetNop(url: "https://a.b", label: nil)])))
        XCTAssertFalse(CTWLopNhan.nopDuoc(CTWBaiNop(needsGroup: true, text: "x")), "bài nhóm mà chưa vào nhóm")
        XCTAssertFalse(CTWLopNhan.nopDuoc(CTWBaiNop(status: "TURNED_IN", text: "x")), "đã nộp thì phải rút lại trước")
        XCTAssertFalse(CTWLopNhan.nopDuoc(CTWBaiNop(canTurnIn: false, text: "x")), "máy chủ nói không ⇒ không")
        XCTAssertEqual(CTWLopNhan.trangThaiNop("LATE"), "Turned in late")
        XCTAssertEqual(CTWLopNhan.trangThaiNop(nil), "Assigned")
        XCTAssertEqual(CTWLopNhan.diem(8.5), "8.5")
        XCTAssertEqual(CTWLopNhan.diem(10), "10")
        XCTAssertEqual(CTWLopNhan.diem(nil), "—")
    }

    func testNopSanPham() throws {
        let n = try giai(CTWNopSanPham.self, "/work/projects/7/submissions")
        XCTAssertEqual(n.gate?.mode, "hard")
        XCTAssertEqual(n.totals?.overdue, 1)
        XCTAssertEqual(n.members?.count, 3)
        XCTAssertEqual(n.members?.first?.items?.first?.attachmentCount, 2)
        XCTAssertNil(n.members?.first?.items?.last?.onTime)
    }

    func testDangKyMoDun() {
        for id in ["desk", "intake", "forms", "portal", "classes", "submit"] {
            XCTAssertNotNil(CTWDangKyMoDun.moDun(id), "thiếu mô-đun \(id)")
        }
        XCTAssertNil(CTWDangKyMoDun.moDun("classes")?.doanWeb, "lớp học ở cấp tài khoản — không nhận đoạn dự án")
    }
}
