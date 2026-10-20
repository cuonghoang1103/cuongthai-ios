import XCTest
@testable import CTWork

/// "Create with CuongMini" + New project + AI usage (21/10/2026). Dữ liệu mẫu `Debug/XemThuCTW+TaoCM.swift` /
/// `XemThuCTW+AIUsage.swift` viết theo hình dạng `banNhap.service.ts → present()` / `aiUsage.service.ts → buildReport`.
final class TaoCuongMiniTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    func testBanNhapCacPha() throws {
        let dien = try giai(CTWBanNhapCM.self, "/work/setup-drafts/501")
        XCTAssertEqual(dien.status, "DRAFT")
        XCTAssertEqual(dien.input?.team?.members?.count, 3)
        XCTAssertEqual(dien.input?.timeline?.endDate, "2026-12-15")
        XCTAssertNil(dien.hieu, "understanding: null ⇒ chưa có tóm tắt")
        XCTAssertEqual(dien.sources?.first?.status, "OK")

        let hieu = try giai(CTWBanNhapCM.self, "/work/setup-drafts/502")
        XCTAssertEqual(hieu.hieu?.questions?.count, 2)
        XCTAssertEqual(hieu.hieu?.team?.first?.proposedRole, "Leader + Backend")

        let kh = try giai(CTWBanNhapCM.self, "/work/setup-drafts/503")
        let p = try XCTUnwrap(kh.keHoach?.projects?.first)
        XCTAssertEqual(p.key, "NTS")
        XCTAssertEqual(p.epic.count, 2)
        XCTAssertEqual(p.con("e2").map(\.ref), ["st3", "st4"])
        XCTAssertEqual(p.tongDiem, 21, "điểm story/task, không cộng epic/subtask")
        XCTAssertEqual(kh.keHoach?.members?.first { $0.leader == true }?.ref, "m1")

        let xong = try giai(CTWBanNhapCM.self, "/work/setup-drafts/504")
        XCTAssertEqual(xong.result?.projects?.first?.issues, 42)
        let doc = try giai(CTWBanNhapCM.self, "/work/setup-drafts/505")
        XCTAssertTrue(doc.dangChay)
        XCTAssertEqual(doc.progress?.map(\.key), ["read", "understand"])
    }

    /// Sửa vài trường trên cây JSON rồi gửi lại ⇒ trường app KHÔNG khai (pages, tests, meetings, dod…) vẫn còn nguyên.
    func testSuaKeHoachGiuTruongKhongKhai() throws {
        let kh = try XCTUnwrap(try giai(CTWBanNhapCM.self, "/work/setup-drafts/503").plan)
        var j = kh
        j.suaDuAn(0) { p in
            p.suaTrongMang("items", ref: "st1") { $0["title"] = .chuoi("Mới"); $0["points"] = .so(3); $0["locked"] = .bool(true) }
            p.suaTrongMang("sprints", ref: "s2") { $0["goal"] = .chuoi("Mục tiêu mới") }
        }
        j.suaTrongMang("members", ref: "m2") { $0["leader"] = .bool(true) }
        let p = try XCTUnwrap(j["projects"]?.mang?.first)
        let st1 = try XCTUnwrap(p["items"]?.mang?.first { $0["ref"]?.chuoi == "st1" })
        XCTAssertEqual(st1["title"], .chuoi("Mới"))
        XCTAssertEqual(st1["milestoneRef"], .null, "trường không hiển thị vẫn còn")
        XCTAssertEqual(st1["blockedBy"], .mang([]))
        XCTAssertNotNil(p["dod"]); XCTAssertNotNil(p["pages"]); XCTAssertNotNil(p["meetings"])
        XCTAssertEqual(j["portfolio"], .null)
        // Gửi đi: số nguyên ra số nguyên (zod .int()).
        let d = try JSONEncoder().encode(j)
        let s = String(decoding: d, as: UTF8.self)
        XCTAssertTrue(s.contains("\"points\":3") || s.contains("\"points\" : 3"), "3 phải mã hoá là 3, không 3.0")
        XCTAssertFalse(s.contains("3.0"))
        // Foundation (thân yêu cầu) giữ NSNull.
        let f = try XCTUnwrap(j.foundation as? [String: Any])
        XCTAssertTrue(f["portfolio"] is NSNull)
        XCTAssertEqual(j.giai(CTWKeHoachCM.self)?.members?.first { $0.ref == "m2" }?.leader, true)
    }

    func testDauVaoSachVaGuiLai() throws {
        var dv = CTWDauVaoCM()
        dv.overview?.name = "Nhà trọ sinh viên"
        dv.overview?.key = "nt-s 1"
        dv.team?.members = [CTWThanhVienCM(name: "An", email: "an@fpt"), CTWThanhVienCM(name: "  "), CTWThanhVienCM(name: "Bình", email: "binh@fpt.edu.vn")]
        dv.timeline?.endDate = "15/12/2026"
        dv.timeline?.milestones = [CTWMocCM(name: "R1", date: "2026-10-05"), CTWMocCM(name: "", date: "2026-10-06")]
        let s = dv.sach()
        XCTAssertEqual(s.overview?.key, "NTS1")
        XCTAssertEqual(s.team?.members?.map(\.name), ["An", "Bình"], "dòng không tên bị bỏ")
        XCTAssertEqual(s.team?.members?.first?.email, "", "email sai dạng ⇒ rỗng")
        XCTAssertEqual(s.timeline?.endDate, "", "ngày không phải YYYY-MM-DD ⇒ rỗng")
        XCTAssertEqual(s.timeline?.milestones?.count, 1)
        XCTAssertTrue(dv.docDuoc(coNguon: false))
        XCTAssertFalse(CTWDauVaoCM().docDuoc(coNguon: false))
        XCTAssertTrue(CTWDauVaoCM().docDuoc(coNguon: true))
        // Mã hoá: không có trường `id` của SwiftUI lọt lên máy chủ.
        let t = try XCTUnwrap(CTWJSON.tu(s))
        XCTAssertNil(t["team"]?["members"]?.mang?.first?["id"])
        XCTAssertEqual(t["reviewFirst"], .bool(false))
    }

    func testMaDuAnTuTen() {
        XCTAssertEqual(MaDuAnCTW.tuTen("SWP391 Group 3"), "SG3")
        XCTAssertEqual(MaDuAnCTW.tuTen("Website"), "WEB")
        XCTAssertEqual(MaDuAnCTW.tuTen("Nhà trọ sinh viên"), "NTSV")
        XCTAssertEqual(MaDuAnCTW.tuTen("Đặt lịch"), "DL")
        XCTAssertEqual(MaDuAnCTW.tuTen(""), "")
        XCTAssertTrue(MaDuAnCTW.hopLe("NTS"))
        XCTAssertFalse(MaDuAnCTW.hopLe("1AB"))
        XCTAssertFalse(MaDuAnCTW.hopLe("A"))
        XCTAssertEqual(MauDuAnCTW.CAPSTONE.loai, .SCHOOL)
        XCTAssertEqual(LoaiDuAnCTW.CLIENT.mauGoiY, .FREELANCE)
    }

    func testNhanBuocVaCanhBao() {
        XCTAssertEqual(NhanCM.buoc("epics:e1:Tìm phòng"), String(localized: "Write stories and subtasks for each epic"))
        XCTAssertEqual(NhanCM.buoc("lạ:x:y"), "lạ y")
        XCTAssertEqual(NhanCM.diem(5), "5")
        XCTAssertEqual(NhanCM.diem(2.5), "2.5")
        XCTAssertNil(NhanCM.diem(nil))
    }

    func testLoiKhongLotMoiMua() {
        let e = APIError.coMa(ma: "WORK_SETUP_KEY_REQUIRED", thongDiep: "Unlock CuongMini Optimum with your key")
        XCTAssertFalse(BanNhapCMVM.cauLoi(e).localizedCaseInsensitiveContains("unlock"))
    }

    func testTaoDuAnVaDuocTao() throws {
        let p = try giai(CTWDuAnMoi.self, "/work/workspaces/1/projects", method: "POST", body: ["key": "NTS", "name": "Nhà trọ"])
        XCTAssertEqual(p.key, "NTS")
        XCTAssertTrue(TaoMoiCTW.duocTao(CTWWorkspace(id: 1, name: "A", slug: "a", role: "MEMBER")))
        XCTAssertFalse(TaoMoiCTW.duocTao(CTWWorkspace(id: 1, name: "A", slug: "a", role: "GUEST")))
        XCTAssertFalse(TaoMoiCTW.duocTao(CTWWorkspace(id: 1, name: "A", slug: "a", role: nil)))
    }

    func testAIUsage() throws {
        let r = try giai(CTWAIUBaoCao.self, "/work/projects/7/ai-usage")
        XCTAssertEqual(r.canSeeAll, true)
        XCTAssertEqual(r.people?.count, 3)
        XCTAssertEqual(r.people?.last?.agentUsd, 1.27)
        XCTAssertEqual(r.notes?.agentSelfReported, true)
        XCTAssertEqual(r.writes?.first { $0.ok == false }?.errorCode, "WORK_AGENT_FORBIDDEN")
        let w = try giai(CTWAIUBaoCao.self, "/work/workspaces/1/ai-usage")
        XCTAssertEqual(w.projects?.count, 2)
        XCTAssertEqual(NhanAIU.usd(0.0042), "$0.0042")
        XCTAssertEqual(NhanAIU.usd(1.2), "$1.20")
        XCTAssertEqual(NhanAIU.usd(0), "—")
    }
}
