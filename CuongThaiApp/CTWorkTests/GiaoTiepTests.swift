import XCTest
@testable import CTWork

/// Kiểm thử ĐƠN VỊ mảng Giao tiếp (Chat · Họp · Hộp thư).
///
/// Giải mã dữ liệu mẫu (`Debug/XemThuCTW+GiaoTiep.swift`, viết theo hình dạng backend)
/// bằng CHÍNH model của app — một trường lệch kiểu là cả màn trống câm (CLAUDE.md C3/C4).
final class GiaoTiepTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    // MARK: Chat

    func testDanhSachKenh() throws {
        let ds = try giai(CTWChannelList.self, "/work/projects/7/chat/channels")
        let k = try XCTUnwrap(ds.channels)
        XCTAssertEqual(k.filter(\.laRieng).map(\.name), ["dm-1-2", "leads", "alex-linh"])
        // Nhắn riêng 1-1 (`POST /chat/dm` ⇒ kênh PRIVATE `dm-<a>-<b>`): app đổi tên thành người kia.
        let gian = ChatCTW.gianDM(k, toi: 1, thanhVien: [CTWUser(id: 2, username: "linh", fullName: "Linh Tran")])
        XCTAssertEqual(gian.first { $0.id == 7 }?.name, "Linh Tran")
        XCTAssertEqual(gian.first { $0.id == 7 }?.laDM, true)
        XCTAssertEqual(gian.filter(\.laDM).count, 1, "nhóm riêng thường không bị nhận nhầm là DM")
        XCTAssertNotNil(k.first { $0.name == "ios-dev" }?.call?.url, "kênh có cuộc gọi đang mở")
        XCTAssertEqual(k.first { $0.name == "client-acme" }?.laKhach, true)
        XCTAssertEqual(ds.me?.canCreate, true)
    }

    func testTinDuLoai() throws {
        let p = try giai(CTWChatPage.self, "/work/projects/7/chat/channels/1/messages")
        let t = try XCTUnwrap(p.messages)
        XCTAssertEqual(p.hasMoreBefore, true)
        XCTAssertTrue(t.contains { $0.laCuocGoi && $0.meta?.url?.hasPrefix("https://") == true }, "tin hệ thống cuộc gọi có url")
        XCTAssertTrue(t.contains { $0.daGhim }, "tin ghim")
        XCTAssertEqual(t.first { $0.id == 399 }?.files?.filter(\.laAnh).count, 2)
        let voice = try XCTUnwrap(t.first { $0.id == 405 }?.files?.first)
        XCTAssertTrue(voice.laGiongNoi)
        XCTAssertEqual(voice.voice?.transcriptStatus, "DONE")
        XCTAssertEqual(t.first { $0.id == 403 }?.files?.first?.bieuTuong, "doc.richtext")
        XCTAssertEqual(t.first { $0.id == 407 }?.links?.first?.domain, "figma.com")
        XCTAssertEqual(t.first { $0.id == 404 }?.author?.laAgent, true, "tin của agent phải nhận ra để gắn nhãn AI")
    }

    func testTinKhoanDung() throws {
        // `meta`/`files` sai kiểu ⇒ bỏ phần đó, KHÔNG hỏng cả tin.
        let json = #"{"id":5,"kind":"SYSTEM","body":"x","meta":"oops","files":{"bad":1},"pinned":{"at":"2026-10-18T00:00:00.000Z","byId":2}}"#
        let m = try JSONDecoder().decode(CTWChatMessage.self, from: Data(json.utf8))
        XCTAssertNil(m.meta)
        XCTAssertNil(m.files)
        XCTAssertTrue(m.daGhim)
    }

    func testChuoiVaThanhVien() throws {
        let c = try giai(CTWChatThread.self, "/work/projects/7/chat/channels/1/messages/404/thread")
        XCTAssertEqual(c.root?.id, 404)
        XCTAssertEqual(c.replies?.count, 2)
        let tv = try giai([CTWChannelMember].self, "/work/projects/7/chat/channels/1/members")
        XCTAssertEqual(tv.first { $0.username == "scout" }?.nguoi.laAgent, true)
        XCTAssertNil(tv.first { $0.username == "scout" }?.online, "agent không có trạng thái online")
        let kq = try giai(CTWReactionKQ.self, "/work/projects/7/chat/channels/1/messages/402/reactions/%F0%9F%8E%89", method: "PUT")
        XCTAssertEqual(kq.reactions?.first?.mine, true)
        let prefs = try giai(CTWChatPrefs.self, "/work/chat/prefs")
        XCTAssertEqual(prefs.notify, "ALL")
    }

    func testToNhacTrongChu() {
        let a = CTWChatChu.dung("Hi @alex and @linh, email a@b.com", toi: "alex")
        let s = String(a.characters)
        XCTAssertEqual(s, "Hi @alex and @linh, email a@b.com")
        // `@alex` (tôi) có nền; `a@b.com` không bị coi là nhắc.
        let co = a.runs.filter { $0.backgroundColor != nil }.map { String(a[$0.range].characters) }
        XCTAssertEqual(co, ["@alex"])
        let toMau = a.runs.filter { $0.foregroundColor != nil }.map { String(a[$0.range].characters) }
        XCTAssertEqual(toMau, ["@alex", "@linh"])
    }

    func testHangChoMaHoa() throws {
        let t = TinChoGuiCTW(id: "ios-abc", pid: 7, cid: 1, parentId: 404, body: "offline hello", taoLuc: Date(), trangThai: .loi, loi: "x")
        let d = try JSONEncoder().encode([t])
        let lai = try JSONDecoder().decode([TinChoGuiCTW].self, from: d)
        XCTAssertEqual(lai.first, t)
        XCTAssertTrue(t.id.range(of: "^[\\w-]+$", options: .regularExpression) != nil, "clientKey phải khớp regex máy chủ")
    }

    func testDuongDanChat() throws {
        let d = try XCTUnwrap(DuongDanCTW.tach("/work/northwind/NW/chat?c=1&m=421&t=404"))
        XCTAssertEqual(d.doan, "chat")
        XCTAssertEqual(d.tham["c"], "1")
        XCTAssertEqual(d.tham["t"], "404")
        XCTAssertEqual(CTWDangKyMoDun.moDun(choDoan: "meetings")?.id, "meetings")
    }

    // MARK: Họp

    func testDanhSachHop() throws {
        let l = try giai(CTWMeetingList.self, "/work/projects/7/meetings")
        let ds = try XCTUnwrap(l.items)
        XCTAssertEqual(ds.count, 5)
        XCTAssertTrue(ds[0].sapHoacDangHop, "cuộc họp đang diễn ra ⇒ nút Join")
        XCTAssertEqual(ds[0].tenNhaCungCap, "Google Meet")
        XCTAssertTrue(ds.contains { $0.daHuy })
        XCTAssertNil(ds.first { $0.number == 6 }?.urlHop, "họp tại phòng — không có link")
    }

    func testChiTietPhongBanGhi() throws {
        let h = try giai(CTWMeeting.self, "/work/projects/7/meetings/3")
        XCTAssertEqual(h.decisions?.count, 2)
        XCTAssertEqual(h.actions?.count, 3)
        XCTAssertEqual(h.actions?.first?.issue?.key, "NW-19")
        XCTAssertFalse(CTWTipTap.khoi(h.minutesJson).isEmpty)
        XCTAssertTrue((h.minutesJson?.chuTron ?? "").contains("iPad split view"))
        XCTAssertEqual(h.attendees?.first { $0.isClient == true }?.id, 5)
        let r = try giai(CTWMeetingRoom.self, "/work/projects/7/meetings/3/room")
        XCTAssertEqual(r.agenda?.count, 3)
        XCTAssertEqual(r.me?.rsvp, "YES")
        XCTAssertEqual(r.drafts?.first?.status, "PROPOSED")
        XCTAssertEqual(r.drafts?.first?.content?.actions?.last?.unsupported, true)
        let t = try giai(CTWHopTranscript.self, "/work/projects/7/meetings/3/transcript")
        XCTAssertEqual(t.recordings?.first?.lines?.count, 3)
        XCTAssertEqual(t.speakers?.count, 2)
        let tao = try giai(CTWHopTaoTheKQ.self, "/work/projects/7/meetings/3/actions/issues", method: "POST")
        XCTAssertEqual(tao.created?.first?.key, "NW-41")
    }

    func testPhongKhoanDung() throws {
        let json = #"{"number":1,"agenda":"bad","attendees":[{"userId":3,"rsvp":"NO","user":{"id":3}}],"drafts":[{"id":1,"status":"PROPOSED","content":null}]}"#
        let r = try JSONDecoder().decode(CTWMeetingRoom.self, from: Data(json.utf8))
        XCTAssertNil(r.agenda)
        XCTAssertEqual(r.attendees?.first?.rsvp, "NO")
        XCTAssertNil(r.drafts?.first?.content)
    }

    // MARK: Hộp thư

    func testThongBaoPhanLoai() throws {
        let tr = try giai(CTWTrangThongBao.self, "/social/notifications")
        let ds = tr.items
        let duyet = try XCTUnwrap(ds.first { $0.id == 12 })
        XCTAssertTrue(duyet.laPheDuyet)
        XCTAssertEqual(duyet.payload?.approvalId, 31)
        XCTAssertEqual(duyet.loai, "approvals")
        let nhac = try XCTUnwrap(ds.first { $0.id == 11 })
        XCTAssertTrue(nhac.laChat && nhac.traLoiDuoc)
        XCTAssertEqual(nhac.loai, "mentions")
        XCTAssertEqual(ds.first { $0.id == 10 }?.khoaNhom, nhac.khoaNhom, "cùng kênh ⇒ cùng nhóm")
        XCTAssertEqual(ds.first { $0.id == 8 }?.loai, "assigned")
        XCTAssertFalse(ds.first { $0.id == 5 }?.laPheDuyet ?? true, "trả lời RSVP không phải yêu cầu duyệt")
        XCTAssertNil(ds.first { $0.id == 6 }?.sender, "cảnh báo hệ thống không có người gửi")
    }

    func testTaiTrongKhongBaoGioNem() throws {
        let json = #"{"items":[{"id":1,"type":"WORK_ALERT","isRead":false,"payload":{"approvalId":"x","url":5}}],"pagination":{"nextCursor":null,"hasNextPage":false}}"#
        let tr = try JSONDecoder().decode(CTWTrangThongBao.self, from: Data(json.utf8))
        XCTAssertNil(tr.items.first?.payload?.approvalId)
        XCTAssertNil(tr.items.first?.payload?.url)
    }

    func testNutThongBao() {
        XCTAssertTrue(NutThongBaoCTW.laNutCuaCTW(NutThongBaoCTW.nutTraLoi))
        XCTAssertTrue(NutThongBaoCTW.laNutCuaCTW(NutThongBaoCTW.nutDuyet))
        XCTAssertFalse(NutThongBaoCTW.laNutCuaCTW("com.apple.UNNotificationDefaultActionIdentifier"))
        let e = CTWAPI.tbPheDuyet(pid: 7, aid: 31, dongY: false)
        XCTAssertEqual(e.path, "/api/v1/work/projects/7/approvals/31/decide")
        XCTAssertEqual(e.body?["decision"] as? String, "REJECT")
        let c = try? giai(CTWCaiDatBao.self, "/work/me/notify-settings")
        XCTAssertEqual(c?.quietStart, 22)
    }

    @MainActor
    func testMoDunHopDaDangKy() {
        XCTAssertNotNil(CTWDangKyMoDun.moDun("meetings"))
        XCTAssertEqual(CTWDangKyMoDun.moDun("meetings")?.nhom, .giaoTiep)
        let json = #"{"id":1,"key":"A","name":"A","modules":{"meetings":false}}"#
        let cfg = try? JSONDecoder().decode(CTWProjectConfig.self, from: Data(json.utf8))
        XCTAssertFalse(CTWDangKyMoDun.hienDuoc(cfg).contains { $0.id == "meetings" }, "dự án tắt mô-đun ⇒ ẩn")
    }
}
