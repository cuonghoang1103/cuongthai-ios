import XCTest
@testable import CTWork

/// Kiểm thử các tuyến backend 18/10/2026 + mảng D (widget/Siri/Spotlight/Share/Face ID).
///
/// Dữ liệu mẫu (`Debug/XemThuCTW+D.swift`, `XemThuCTW+GiaoTiep.swift`) viết theo HÌNH DẠNG của
/// `api-backend` (`meAgenda.service.ts`, `contentReport.service.ts`, `work.ios.routes.ts`,
/// `notify.ts → getNotifySettings`, `goiDayCtw.ts`) — giải mã bằng chính model của app.
final class MangDTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    // MARK: /me/agenda

    func testAgendaGiaiMaDuLoai() throws {
        let a = try giai(CTWAgenda.self, "/work/me/agenda")
        let ds = try XCTUnwrap(a.items)
        XCTAssertEqual(Set(ds.map(\.type)), ["due", "meeting", "sprint", "release", "stage"])
        let due = try XCTUnwrap(ds.first { $0.type == "due" })
        XCTAssertEqual(due.key, "NW-12")
        XCTAssertEqual(due.status?.name, "In Progress", "status của `due` là OBJECT")
        let sp = try XCTUnwrap(ds.first { $0.type == "sprint" })
        XCTAssertEqual(sp.statusText, "ACTIVE", "status của sprint là CHUỖI — giải mã mềm, không hỏng cả lịch")
        let hop = try XCTUnwrap(ds.first { $0.type == "meeting" })
        XCTAssertNotNil(hop.meetingUrl)
        XCTAssertEqual(hop.project?.workspaceSlug, "northwind")
        XCTAssertEqual(a.counts?.meeting, 2)
    }

    func testAgendaRaSuKienLich() throws {
        let a = try giai(CTWAgenda.self, "/work/me/agenda")
        let sk = GopLichCTW.tuAgenda(a.items ?? [])
        XCTAssertTrue(sk.contains { $0.loai == .hop && $0.hop?.meetingUrl != nil })
        XCTAssertEqual(sk.filter { $0.loai == .sprint }.count, 4, "mỗi sprint ⇒ bắt đầu + kết thúc")
        XCTAssertTrue(sk.contains { $0.loai == .han && $0.maDuAn == "WEB" }, "hạn thẻ của dự án KHÁC cũng có (xuyên dự án)")
    }

    @MainActor
    func testAgendaChuanHoaSprintDaChay() throws {
        let hn = "2026-10-18"
        var cu = CTWAgendaItem(type: "sprint", date: "2026-10-09", id: 1, title: "S7"); cu.end = "2026-10-18"
        var xong = CTWAgendaItem(type: "sprint", date: "2026-10-01", id: 2, title: "S6"); xong.end = "2026-10-08"
        let moi = CTWAgendaItem(type: "sprint", date: "2026-10-20", id: 3, title: "S8")
        let kq = AgendaCuaToiVM.chuanHoa([cu, xong, moi], homNay: hn)
        XCTAssertEqual(kq.map(\.id), [1, 3], "sprint đã xong trước hôm nay bị bỏ")
        XCTAssertEqual(kq[0].date, hn)
        XCTAssertEqual(kq[0].event, "ends")
        XCTAssertEqual(kq[1].event, "starts")
    }

    func testKhoangAgendaKhongVuotTran() {
        let (tu, den) = CTWAgendaKhoang.cat(tu: "2026-01-01", den: "2026-12-31")
        XCTAssertEqual(tu, "2026-01-01")
        XCTAssertEqual(den, "2026-05-01", "trần 120 ngày của máy chủ — vượt ⇒ 400")
        XCTAssertEqual(CTWAgendaKhoang.cat(tu: "2026-10-01", den: "2026-10-31").1, "2026-10-31")
    }

    // MARK: /me/timesheet

    func testBangGioCuaToiXuyenDuAn() throws {
        let bg = try giai(CTWBangGioCuaToi.self, "/work/me/timesheet")
        XCTAssertEqual(bg.days?.count, 7)
        XCTAssertEqual(Set(bg.projects?.compactMap(\.project?.key) ?? []), ["NW", "WEB"])
        XCTAssertEqual(bg.projects?.first?.timesheetStatus, "SUBMITTED")
        let ngay = TinhGioCTW.theoNgay(bg, tuThuHai: try XCTUnwrap(bg.weekStart))
        XCTAssertEqual(ngay.count, 7)
        XCTAssertEqual(TinhGioCTW.tongTuan(ngay), bg.totalMin)
        let dong = TinhGioCTW.dongThe(bg)
        XCTAssertTrue(dong.contains { $0.ma == "WEB-3" && $0.pid == 8 }, "dòng thẻ mang pid ĐÚNG dự án của nó")
        XCTAssertEqual(dong.map(\.phut), dong.map(\.phut).sorted(by: >))
    }

    // MARK: Thông báo — surface=work, push theo loại, múi giờ, nút Join

    func testDuongThongBaoTheoBeMat() {
        XCTAssertEqual(CTWAPI.tbDanhSach(cursor: 9, limit: 50).path, "/api/v1/social/notifications?surface=work&limit=50&cursor=9")
        XCTAssertEqual(CTWAPI.tbSoChuaDoc().path, "/api/v1/social/notifications/unread-count?surface=work")
        let doc = CTWAPI.tbDocHet()
        XCTAssertEqual(doc.method, "PATCH")
        XCTAssertEqual(doc.body?["surface"] as? String, "work")
        XCTAssertEqual(doc.body?["all"] as? Bool, true)
    }

    func testCaiDatDayTheoLoaiVaMuiGio() throws {
        let c = try giai(CTWCaiDatBao.self, "/work/me/notify-settings")
        XCTAssertEqual(c.push?.mention, true)
        XCTAssertEqual(c.push?.chatAll, false)
        XCTAssertEqual(c.timezone, "Asia/Ho_Chi_Minh")
        let sau = try giai(CTWCaiDatBao.self, "/work/me/notify-settings", method: "PUT", body: ["push": ["chatAll": true], "timezone": "Asia/Tokyo"])
        XCTAssertEqual(sau.push?.chatAll, true)
        XCTAssertEqual(sau.timezone, "Asia/Tokyo")
        // Máy chủ cũ không có `push` ⇒ app coi như BẬT (giống `pushPrefsFrom` của máy chủ).
        let cu = try JSONDecoder().decode(CTWCaiDatBao.self, from: Data(#"{"emailMode":"INSTANT","quietStart":null,"quietEnd":null}"#.utf8))
        XCTAssertNil(cu.push)
        XCTAssertNil(cu.timezone)
        let so = try giai(CTWSoChuaDoc.self, "/social/notifications/unread-count")
        XCTAssertEqual(so.unreadCount, 5)
    }

    func testNhacHopCoNutJoin() throws {
        let tr = try giai(CTWTrangThongBao.self, "/social/notifications")
        let nhac = try XCTUnwrap(tr.items.first { $0.id == 9 })
        XCTAssertEqual(nhac.linkVaoHop?.host, "meet.google.com")
        XCTAssertFalse(nhac.laPheDuyet)
        XCTAssertNil(tr.items.first { $0.id == 12 }?.linkVaoHop, "phê duyệt không có Join")
        XCTAssertEqual(NutThongBaoCTW.linkHop(["meetingUrl": "https://zoom.us/j/1"])?.host, "zoom.us")
        XCTAssertNil(NutThongBaoCTW.linkHop(["meetingUrl": "javascript:alert(1)"]), "chỉ mở http/https")
        XCTAssertFalse(NutThongBaoCTW.laNutCuaCTW(NutThongBaoCTW.nutVaoHop), "Join mở app, không chạy nền")
    }

    // MARK: Báo cáo nội dung (1.2)

    func testBaoCaoMotCua() throws {
        let e = CTWAPI.baoCaoNoiDung(CTWDichBaoCao("page_comment", 44), lyDo: "spam", chiTiet: "ad")
        XCTAssertEqual(e.path, "/api/v1/work/report")
        XCTAssertEqual(e.body?["kind"] as? String, "page_comment")
        XCTAssertEqual(e.body?["id"] as? Int, 44)
        XCTAssertEqual(e.body?["reason"] as? String, "spam")
        XCTAssertEqual(e.body?["detail"] as? String, "ad")
        XCTAssertEqual(CTWDichBaoCao.cacLoai.count, 14, "đúng 14 loại của REPORT_KINDS")
        // Mã lý do của app TRÙNG `COMMENT_REPORT_REASONS` của máy chủ (khác ⇒ 400).
        XCTAssertEqual(Set(CTWBaoCao.lyDo.map(\.ma)), ["spam", "harassment", "hate", "sexual", "violence", "other"])
        let kq = try giai(CTWKetQuaBaoCao.self, "/work/report", method: "POST", body: ["kind": "chat_message", "id": 1, "reason": "spam"])
        XCTAssertEqual(kq.reported, true)
        XCTAssertEqual(kq.duplicate, false)
        XCTAssertEqual(CTWAPI.baoCaoHop(pid: 7, so: 3, lyDo: "hate").path, "/api/v1/work/projects/7/meetings/3/report")
    }

    // MARK: Docs — baseVersion + so sánh

    func testSuaTrangGuiBaseVersion() {
        let e = CTWAPI.suaTrang(pid: 7, so: 3, phienBan: 12, markdown: "x")
        XCTAssertEqual(e.body?["baseVersion"] as? Int, 12)
        XCTAssertNil(e.body?["version"], "không gửi `version` cũ nữa")
        XCTAssertTrue(CTWSuaTrang.laXungDotTrang(APIError.coMa(ma: "WORK_PAGE_CONFLICT", thongDiep: "changed")))
        XCTAssertFalse(CTWSuaTrang.laXungDotTrang(APIError.coMa(ma: "WORK_EDIT_LOCKED", thongDiep: "locked")))
    }

    func testSoSanhDong() {
        let kq = CTWSuaTrang.soSanhDong(cuaToi: "a\nb\nc", banMoi: "a\nB\nc\nd")
        XCTAssertEqual(kq, [.giong("a"), .chiCuaToi("b"), .chiBanMoi("B"), .giong("c"), .chiBanMoi("d")])
        XCTAssertEqual(CTWSuaTrang.soSanhDong(cuaToi: "", banMoi: ""), [.giong("")])
    }

    // MARK: DM · dashboard · yêu cầu

    func testMoDMVaMotMuc() throws {
        XCTAssertEqual(CTWAPI.moDM(pid: 7, userId: 2).path, "/api/v1/work/projects/7/chat/dm")
        let dm = try giai(CTWKenhDM.self, "/work/projects/7/chat/dm", method: "POST", body: ["userId": 2])
        XCTAssertEqual(dm.kind, "DM")
        XCTAssertEqual(dm.with?.id, 2)
        let k = CTWChannel(id: 7, name: "dm-1-2", kind: "PRIVATE")
        XCTAssertEqual(k.idNguoiKiaDM(toi: 2), 1)
        XCTAssertNil(k.idNguoiKiaDM(toi: 5), "không phải DM của mình")
        XCTAssertNil(CTWChannel(id: 8, name: "dm-team", kind: "PRIVATE").idNguoiKiaDM(toi: 1))
        let db = try giai(CTWDashboardDb.self, "/work/projects/7/dashboards/5")
        XCTAssertEqual(db.id, 5)
        XCTAssertEqual(db.canEdit, true)
        XCTAssertFalse(db.widgets?.isEmpty ?? true)
        let r = try giai(CTWSwrRequirement.self, "/work/projects/7/swr/requirements/31")
        XCTAssertEqual(r.number, 31)
    }

    // MARK: Widget "hôm nay" + Siri

    @MainActor
    func testAnhChupViecHomNay() throws {
        let a = try giai(CTWAgenda.self, "/work/me/agenda")
        let hn = DuLieuGia.ngay(0)
        let qh = CTWMyWorkItem(key: "NW-9", number: 9, title: "Fix login crash", bucket: "overdue")
        let anh = CTWChiaSeNhom.dungViecHomNay(agenda: a.items ?? [], quaHan: [qh], homNay: hn)
        XCTAssertEqual(anh.ngay, hn)
        XCTAssertEqual(anh.viec.first?.loai, "meeting", "họp lên đầu")
        XCTAssertTrue(anh.viec.contains { $0.loai == "overdue" && $0.ma == "NW-9" })
        XCTAssertTrue(anh.viec.contains { $0.loai == "sprint" && $0.tieuDe.hasSuffix("ends") }, "sprint kết thúc hôm nay")
        XCTAssertFalse(anh.viec.contains { $0.ma == "NW-21" }, "hạn ngày khác không vào 'hôm nay'")
        let cau = ViecHomNayYD.cau(anh.viec)
        XCTAssertTrue(cau.contains("1 meeting"), cau)
        XCTAssertTrue(cau.contains("due today"), cau)
        XCTAssertTrue(cau.contains("1 overdue"), cau)
        XCTAssertEqual(ViecHomNayYD.cau([]), "Nothing is due today and you have no meetings. Enjoy.")
    }

    @MainActor
    func testSpotlightDuongDan() {
        XCTAssertEqual(CTWChiaSeNhom.duongDanTuSpotlight("ctw-issue-NW-12|/work/northwind/NW/issue/12"), "/work/northwind/NW/issue/12")
        XCTAssertNil(CTWChiaSeNhom.duongDanTuSpotlight("ctw-issue-NW-12|https://evil.example/x"))
        XCTAssertNil(CTWChiaSeNhom.duongDanTuSpotlight("other"))
        let t = TheGanDayCTW(pid: 7, slug: "northwind", maDuAn: "NW", so: 12, tieuDe: "Push", xemLuc: Date())
        XCTAssertEqual(t.duongDan, "/work/northwind/NW/issue/12")
        XCTAssertEqual(t.ma, "NW-12")
    }

    // MARK: 3.1.1 — trình duyệt trong app chặn đường mua

    func testChanDuongMuaTrongTrinhDuyet() {
        let c = { (s: String) in TrinhDuyetCuongThaiCTW.laDuongMua(URL(string: s)!) }
        XCTAssertTrue(c("https://cuongthai.com/pro"))
        XCTAssertTrue(c("https://cuongthai.com/pro/checkout?plan=year"))
        XCTAssertTrue(c("https://cuongthai.com/pricing"))
        XCTAssertTrue(c("https://sandbox.vnpayment.vn/paymentv2/vpcpay.html"))
        XCTAssertFalse(c("https://cuongthai.com/work/northwind/NW/docs/3"))
        XCTAssertFalse(c("https://cuongthai.com/projects"), "/projects không phải /pro")
        XCTAssertFalse(c("https://cuongthai.com/chinh-sach-bao-mat"))
        XCTAssertTrue(TrinhDuyetCuongThaiCTW.laCuaCuongThai(URL(string: "https://cuongthai.com/work")!))
        XCTAssertFalse(TrinhDuyetCuongThaiCTW.laCuaCuongThai(URL(string: "https://figma.com/x")!))
    }

    func testDongHoAnhChupTrangThai() {
        let d = CTWDongHoChay(projectId: 7, issueNumber: 12, issueKey: "NW-12", issueTitle: "Push", projectKey: "NW",
                              workspaceSlug: "northwind", running: true, elapsedSec: 60)
        let luc = Date(timeIntervalSince1970: 1_000_000)
        let s = d.trangThaiLiveActivity(taiLuc: luc)
        XCTAssertEqual(s.runningSince, luc.addingTimeInterval(-60))
        XCTAssertEqual(s.elapsedSec, 0)
        XCTAssertEqual(d.thuocTinhLiveActivity?.issueNumber, 12)
    }
}
