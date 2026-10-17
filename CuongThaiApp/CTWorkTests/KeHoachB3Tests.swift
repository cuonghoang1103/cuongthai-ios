import XCTest
@testable import CTWork

/// Kiểm thử mảng B3 — Time · Poker · Retro · OKR · Workspace.
/// (1) giải mã dữ liệu mẫu (đúng hình dạng backend) bằng CHÍNH model của app;
/// (2) phép tính thuần: tổng giờ tuần/ngày, đổi phút ⇄ chữ, giây trôi đồng hồ, đếm ngược poker,
///     sắp thẻ retro, tiến độ KR, cây mục tiêu.
final class KeHoachB3Tests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET",
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: [:])
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    // MARK: Giải mã

    func testGiaiMaDongHoVaWorklog() throws {
        let g = try giai(CTWDongHoGoi.self, "/work/me/timer")
        XCTAssertEqual(g.timer?.issueKey, "NW-12")
        XCTAssertTrue(g.timer?.dangChay == true)
        let dung = try giai(CTWKetQuaDung.self, "/work/me/timer/stop", method: "POST")
        XCTAssertEqual(dung.minutes, 83)
        let ds = try giai([CTWWorklog].self, "/work/projects/7/issues/12/worklogs")
        XCTAssertEqual(ds.count, 4)
        XCTAssertTrue(ds.contains { $0.user?.laAgent == true && $0.source == "AGENT_AUTO" })
        let md = try giai(CTWWorklogMacDinh.self, "/work/projects/7/issues/12/worklog-defaults")
        XCTAssertEqual(md.activities?.count, 6)
        let bc = try giai(CTWBaoCaoGio.self, "/work/projects/7/reports/time")
        XCTAssertEqual(bc.people?.first?.user?.id, 1)
        _ = try giai(CTWBangGioTuan.self, "/work/projects/7/finance/timesheet")
    }

    func testGiaiMaPokerRetro() throws {
        let ds = try giai(CTWPokerDs.self, "/work/projects/7/poker")
        XCTAssertEqual(ds.sessions?.count, 3)
        let p = try giai(CTWPokerPhong.self, "/work/projects/7/poker/3")
        XCTAssertEqual(p.mucHienTai?.state, "REVEALED")
        XCTAssertEqual(p.mucHienTai?.distribution?.suggested, "5")
        XCTAssertEqual(p.mucHienTai?.votes?.count, 4)
        let up = try giai(CTWPokerPhong.self, "/work/projects/7/poker/4")
        XCTAssertNil(up.mucHienTai?.votes, "bài úp khi đang bầu — không lộ giá trị")
        XCTAssertEqual(PokerTinh.boBai(up).first, "XS")
        let r = try giai(CTWRetroDs.self, "/work/projects/7/retros")
        XCTAssertEqual(r.retros?.count, 2)
        let b = try giai(CTWRetro.self, "/work/projects/7/retros/2")
        XCTAssertEqual(b.columns, ["START", "STOP", "CONTINUE"])
        XCTAssertEqual(b.actions?.count, 2)
    }

    func testGiaiMaOkrVaKhongGian() throws {
        let o = try giai(CTWOkrView.self, "/work/projects/7/okrs")
        XCTAssertEqual(o.cycle?.name, "Q4 2026")
        XCTAssertFalse((o.objectives ?? []).isEmpty)
        let w = try giai(CTWOkrView.self, "/work/workspaces/1/okrs")
        let cay = OkrTinh.cay(w.objectives ?? [])
        XCTAssertEqual(cay.count, 1, "objective dự án nằm dưới objective không gian")
        XCTAssertEqual(cay.first?.con.count, 2)
        let pf = try giai(CTWPortfolio.self, "/work/workspaces/1/portfolio")
        XCTAssertEqual(pf.projects?.count, 3)
        XCTAssertEqual(pf.projects?.first { $0.key == "WEB" }?.health?.rag, "RED")
        let wl = try giai(CTWWorkload.self, "/work/workspaces/1/workload")
        XCTAssertEqual(wl.people?.first?.level, "over")
        let doi = try giai([CTWDoi].self, "/work/workspaces/1/teams")
        XCTAssertEqual(doi.first?.members?.first { $0.teamRole == "LEAD" }?.id, 1)
        _ = try giai(CTWHangDoi.self, "/work/workspaces/1/teams/1/queue")
        let ag = try giai(CTWAgentDashboard.self, "/work/workspaces/1/agents/dashboard")
        XCTAssertTrue(ag.agents?.first?.nguoi.laAgent == true, "agent luôn mang nhãn AI (4.7)")
        XCTAssertGreaterThan(WorkspaceTinh.tiLeTuKhai(ag.totals?.costSource), 0.5)
    }

    // MARK: Giờ

    func testTongGioTuanVaNgay() {
        let n1 = CTWBaoCaoGio.Nguoi(user: nil, byDay: ["2026-10-12": 90, "2026-10-14": 30, "2026-10-19": 999],
                                    issues: [.init(number: 1, title: "A", minutes: 60), .init(number: 2, title: "B", minutes: 60)])
        let n2 = CTWBaoCaoGio.Nguoi(user: nil, byDay: ["2026-10-12": 15], issues: [.init(number: 1, title: "A", minutes: 15)])
        let ngay = TinhGioCTW.theoNgay([n1, n2], tuThuHai: "2026-10-12")
        XCTAssertEqual(ngay.count, 7)
        XCTAssertEqual(ngay.first?.ngay, "2026-10-12")
        XCTAssertEqual(ngay.last?.ngay, "2026-10-18")
        XCTAssertEqual(ngay[0].phut, 105)
        XCTAssertEqual(ngay[1].phut, 0)
        XCTAssertEqual(TinhGioCTW.tongTuan(ngay), 135, "ngày ngoài tuần (19/10) không cộng vào")
        let the = TinhGioCTW.theoThe([n1, n2])
        XCTAssertEqual(the.first?.number, 1)
        XCTAssertEqual(the.first?.minutes, 75)
    }

    func testDoiPhutVaChu() {
        XCTAssertEqual(TinhGioCTW.chuPhut(0), "0m")
        XCTAssertEqual(TinhGioCTW.chuPhut(45), "45m")
        XCTAssertEqual(TinhGioCTW.chuPhut(60), "1h")
        XCTAssertEqual(TinhGioCTW.chuPhut(90), "1h 30m")
        XCTAssertEqual(TinhGioCTW.docPhut("1h 30m"), 90)
        XCTAssertEqual(TinhGioCTW.docPhut("1.5h"), 90)
        XCTAssertEqual(TinhGioCTW.docPhut("1,5h"), 90)
        XCTAssertEqual(TinhGioCTW.docPhut("90m"), 90)
        XCTAssertEqual(TinhGioCTW.docPhut("90"), 90)
        XCTAssertEqual(TinhGioCTW.docPhut("1:30"), 90)
        XCTAssertNil(TinhGioCTW.docPhut("abc"))
        XCTAssertNil(TinhGioCTW.docPhut("25h"), "quá 24 giờ một lần ghi")
        XCTAssertNil(TinhGioCTW.docPhut("0"))
        XCTAssertNil(TinhGioCTW.docPhut("1:75"))
    }

    func testGiayTroiDongHo() {
        let goc = Date(timeIntervalSince1970: 1_000_000)
        var d = CTWDongHoChay(running: true, elapsedSec: 600)
        XCTAssertEqual(TinhGioCTW.giayTroi(d, taiLuc: goc, bayGio: goc.addingTimeInterval(65)), 665)
        XCTAssertEqual(TinhGioCTW.giayTroi(d, taiLuc: goc, bayGio: goc.addingTimeInterval(-5)), 600, "đồng hồ máy lùi không làm giảm")
        d.running = false
        XCTAssertEqual(TinhGioCTW.giayTroi(d, taiLuc: goc, bayGio: goc.addingTimeInterval(65)), 600, "tạm dừng ⇒ đứng yên")
        XCTAssertEqual(TinhGioCTW.phutSeGhi(giay: 29), 0, "dưới 30 giây không ghi")
        XCTAssertEqual(TinhGioCTW.phutSeGhi(giay: 30), 1)
        XCTAssertEqual(TinhGioCTW.phutSeGhi(giay: 100_000), 1440)
        XCTAssertEqual(CTWSo.dongHo(giay: 3725), "1:02:05")
        XCTAssertEqual(CTWSo.dongHo(giay: 125), "02:05")
    }

    func testLiveActivityTrangThai() {
        let luc = Date(timeIntervalSince1970: 2_000_000)
        let d = CTWDongHoChay(projectId: 7, issueNumber: 12, issueKey: "NW-12", issueTitle: "X", projectKey: "NW", workspaceSlug: "nw",
                              running: true, elapsedSec: 300)
        let s = d.trangThaiLiveActivity(taiLuc: luc)
        XCTAssertEqual(s.runningSince, luc.addingTimeInterval(-300))
        XCTAssertEqual(s.elapsedSec, 0)
        XCTAssertEqual(d.thuocTinhLiveActivity?.issueNumber, 12)
        var p = d
        p.running = false
        XCTAssertNil(p.trangThaiLiveActivity(taiLuc: luc).runningSince)
        XCTAssertEqual(p.trangThaiLiveActivity(taiLuc: luc).elapsedSec, 300)
    }

    // MARK: Poker · Retro · OKR

    func testDemNguocPokerTheoGioMayChu() {
        let tai = Date(timeIntervalSince1970: 5_000_000)
        // Máy chủ nhanh hơn máy 120 giây; còn 60 giây theo máy chủ.
        let f = ISO8601DateFormatter()
        let mayChu = f.string(from: tai.addingTimeInterval(120))
        let ketThuc = f.string(from: tai.addingTimeInterval(180))
        XCTAssertEqual(PokerTinh.giayConLai(ketThuc: ketThuc, serverNow: mayChu, taiLuc: tai, bayGio: tai), 60)
        XCTAssertEqual(PokerTinh.giayConLai(ketThuc: ketThuc, serverNow: mayChu, taiLuc: tai, bayGio: tai.addingTimeInterval(90)), 0)
        XCTAssertNil(PokerTinh.giayConLai(ketThuc: nil, serverNow: mayChu, taiLuc: tai, bayGio: tai))
    }

    func testSapTheRetro() {
        let a = CTWUser(id: 4, kind: "HUMAN")
        let x = CTWUser(id: 7, kind: "HUMAN")
        let the = [CTWRetroThe(id: 1, column: "STOP", body: "a", votes: 1, author: a),
                   CTWRetroThe(id: 2, column: "STOP", body: "b", votes: 5, author: a),
                   CTWRetroThe(id: 3, column: "STOP", body: "c", groupId: 1, votes: 9, author: a),
                   CTWRetroThe(id: 4, column: "STOP", body: "d", votes: 3, author: x),
                   CTWRetroThe(id: 5, column: "START", body: "e", votes: 2, author: a),
                   CTWRetroThe(id: 6, column: "STOP", body: "f", votes: 2, author: a)]
        let kq = RetroTinh.theCua(cot: "STOP", the: the, an: [6], chan: [7])
        XCTAssertEqual(kq.map(\.the.id), [2, 1, 3], "sắp theo phiếu; con đi sau đầu nhóm; ẩn thẻ đã báo cáo + người đã chặn")
        XCTAssertEqual(kq.map(\.con), [false, false, true])
    }

    func testTienDoKR() {
        XCTAssertEqual(OkrTinh.tienDo(metric: "NUMBER", dau: 20, dich: 60, hienTai: 40), 0.5, accuracy: 0.0001)
        XCTAssertEqual(OkrTinh.tienDo(metric: "NUMBER", dau: 20, dich: 60, hienTai: 80), 1)
        XCTAssertEqual(OkrTinh.tienDo(metric: "NUMBER", dau: 20, dich: 60, hienTai: 10), 0)
        XCTAssertEqual(OkrTinh.tienDo(metric: "NUMBER", dau: 10, dich: 0, hienTai: 4), 0.6, accuracy: 0.0001, "mục tiêu giảm")
        XCTAssertEqual(OkrTinh.tienDo(metric: "BOOLEAN", dau: 0, dich: 1, hienTai: 1), 1)
        XCTAssertEqual(OkrTinh.tienDo(metric: "BOOLEAN", dau: 0, dich: 1, hienTai: 0.5), 0)
    }

    func testDangKyMoDunB3() {
        for id in ["time", "poker", "retros", "okrs", "workspace"] {
            XCTAssertNotNil(CTWDangKyMoDun.moDun(id), "mô-đun \(id) đã đăng ký")
        }
        XCTAssertEqual(CTWDangKyMoDun.moDun(choDoan: "poker")?.id, "poker")
        XCTAssertEqual(CTWDangKyMoDun.moDun(choDoan: "retros")?.id, "retros")
    }
}
