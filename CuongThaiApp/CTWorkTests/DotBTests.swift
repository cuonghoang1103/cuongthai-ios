import XCTest
@testable import CTWork

/// Kiểm thử đợt B (21/10/2026) — Board · Backlog · List · tìm kiếm · ghim · dịch tên mặc định.
/// Toàn hàm THUẦN (không mạng): dịch tên, JQL (gợi ý/bọc nháy/ORDER BY), ghim navPins (cốt lõi, đổi ghim, chuyển bản cũ,
/// thân PATCH), xếp hạng khi thả, chia làn board, đổi trạng thái hàng loạt theo tên.
final class DotBTests: XCTestCase {
    override func tearDown() {
        KhoiDongKiemThuCTW.veTiengAnh()
        super.tearDown()
    }

    private var cfg: CTWProjectConfig {
        let d = DuLieuGia.traLoi(method: "GET", path: "/api/v1/work/projects/7", body: [:])
        return try! JSONDecoder().decode(APIResponse<CTWProjectConfig>.self, from: d).data!
    }

    // MARK: Tên mặc định

    func testDichTenMacDinhChiKhiTiengViet() {
        let cu = NgonNguCTW.cheDo
        defer { NgonNguCTW.dat(cu) }
        NgonNguCTW.dat(.vi); CTWDinhDang.locale = NgonNguCTW.locale
        XCTAssertEqual(CTWTen.trangThai("To Do"), "Cần làm")
        XCTAssertEqual(CTWTen.trangThai("  in progress "), "Đang làm", "so khớp không phân biệt hoa thường/khoảng trắng")
        XCTAssertEqual(CTWTen.trangThai("Done"), "Hoàn thành", "không lẫn với nút \"Done\" (Xong) của catalog chính")
        XCTAssertEqual(CTWTen.trangThai("Waiting for client"), "Waiting for client", "tên tự đặt giữ nguyên")
        XCTAssertEqual(CTWTen.loai("Sub-task"), "Việc con")
        XCTAssertEqual(CTWTen.loai("Story"), "Story")
        XCTAssertEqual(CTWTen.loai("Requirement"), "Yêu cầu")
        XCTAssertEqual(CTWTen.trangThaiCau("IN REVIEW"), "Đang review")
        XCTAssertEqual(CTWTen.trangThaiCau("Ready for QA"), "Ready for QA", "tên tự đặt ⇒ kiểu câu như web")
        NgonNguCTW.dat(.en); CTWDinhDang.locale = NgonNguCTW.locale
        XCTAssertEqual(CTWTen.trangThai("To Do"), "To Do", "tiếng Anh ⇒ nguyên văn (web statusNameIn 'en')")
        XCTAssertEqual(CTWTen.trangThaiCau("IN REVIEW"), "In review")
    }

    func testBangTenMacDinhDuBanViVaDuKhoa() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CTWorkApp/TenMacDinhCTW.xcstrings")
        let j = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let ds = try XCTUnwrap(j["strings"] as? [String: Any])
        for k in Set(CTWTen.khoaTrangThai.values).union(CTWTen.khoaLoai.values) {
            let muc = try XCTUnwrap(ds[k] as? [String: Any], "thiếu khoá \(k)")
            let vi = ((muc["localizations"] as? [String: Any])?["vi"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertFalse((vi?["value"] as? String ?? "").isEmpty, "\(k) thiếu bản vi")
        }
    }

    // MARK: JQL

    func testBocNhayVaThuTu() {
        XCTAssertEqual(CTWJql.boc("NW"), "NW")
        XCTAssertEqual(CTWJql.boc("In Progress"), "\"In Progress\"")
        XCTAssertEqual(CTWJql.boc("say \"hi\""), "\"say \\\"hi\\\"\"")
        let t = CTWJql.thuTu("status = Done ORDER BY updated DESC")
        XCTAssertEqual(t.goc, "status = Done"); XCTAssertEqual(t.truong, "updated"); XCTAssertTrue(t.giam)
        XCTAssertEqual(CTWJql.voiThuTu("status = Done ORDER BY updated DESC", truong: "priority", giam: false), "status = Done ORDER BY priority ASC")
        XCTAssertEqual(CTWJql.voiThuTu("", truong: "key", giam: true), "ORDER BY key DESC")
    }

    func testGoiYTruongToanTuGiaTri() {
        let nc = CTWJql.NguCanh(cfg: cfg)
        XCTAssertTrue(CTWJql.goiY("", caret: 0, nc).ds.contains { $0.nhan == "status" }, "đầu câu ⇒ trường")
        let sta = CTWJql.goiY("sta", caret: 3, nc)
        XCTAssertEqual(sta.tu, 0)
        XCTAssertEqual(sta.ds.first?.nhan, "status", "khớp đầu chữ lên trước")
        XCTAssertTrue(CTWJql.goiY("status ", caret: 7, nc).ds.contains { $0.nhan == "IN" }, "sau trường ⇒ toán tử")
        let gt = CTWJql.goiY("status = ", caret: 9, nc).ds.map(\.chen)
        XCTAssertTrue(gt.contains("\"In Progress\""), "giá trị là TÊN GỐC, bọc nháy: \(gt)")
        let ds = CTWJql.goiY("assignee IN (", caret: 13, nc).ds.map(\.nhan)
        XCTAssertTrue(ds.contains("currentUser()") && ds.contains("linh"), "\(ds)")
        XCTAssertEqual(CTWJql.goiY("status = Done ", caret: 14, nc).ds.map(\.nhan), ["AND", "OR", "ORDER BY"])
        XCTAssertEqual(CTWJql.goiY("status = Done ORDER BY ", caret: 23, nc).ds.first?.nhan, "key")
        XCTAssertTrue(CTWJql.goiY("summary ~ \"lo", caret: 13, nc).ds.isEmpty, "trong chuỗi nháy ⇒ không gợi ý")
        let (moi, con) = CTWJql.chapNhan(.init(nhan: "status", chen: "status"), text: "sta", tu: 0, caret: 3)
        XCTAssertEqual(moi, "status "); XCTAssertEqual(con, 7)
    }

    // MARK: Ghim

    func testCotLoiTheoLoaiDuAnNhuWeb() {
        XCTAssertEqual(CTWGhim.cotLoiWeb(kind: "PERSONAL", template: nil, type: "SCRUM"), ["board", "list", "docs", "timeline"])
        XCTAssertEqual(CTWGhim.cotLoiWeb(kind: "SCHOOL", template: nil, type: "SCRUM"),
                       ["board", "backlog", "list", "docs", "chat", "meetings", "submit", "timeline"])
        XCTAssertEqual(CTWGhim.cotLoiWeb(kind: nil, template: "SWT301", type: "KANBAN"),
                       ["board", "list", "docs", "chat", "meetings", "submit", "timeline", "tests"], "mẫu ⇒ loại SCHOOL + tests, Kanban bỏ backlog")
        XCTAssertEqual(CTWGhim.loaiDuAn(kind: nil, template: "FREELANCE"), "CLIENT")
        XCTAssertEqual(CTWGhim.loaiDuAn(kind: nil, template: nil), "SOFTWARE")
        XCTAssertEqual(CTWGhim.cotLoi(kind: "PERSONAL", template: nil, type: nil).last, "ai")
    }

    func testDoiGhimVaThuTuChinh() {
        let core = CTWGhim.cotLoi(kind: "PERSONAL", template: nil, type: nil)
        var e = CTWGhim.doiGhim("chat", bat: true, cotLoi: core, nil)
        XCTAssertEqual(e, CTWGhimMuc(pin: ["chat"], hide: []))
        e = CTWGhim.doiGhim("docs", bat: false, cotLoi: core, e)
        XCTAssertEqual(e, CTWGhimMuc(pin: ["chat"], hide: ["docs"]))
        XCTAssertEqual(CTWGhim.thuTuChinh(cotLoi: core, e), ["board", "list", "timeline", "ai", "chat"])
        e = CTWGhim.doiGhim("docs", bat: true, cotLoi: core, e)
        XCTAssertEqual(e, CTWGhimMuc(pin: ["chat"], hide: []), "ghim lại mục cốt lõi ⇒ bỏ khỏi hide, không vào pin")
        // Mục lạ do web ghim (vd "list", "connect") được giữ nguyên khi iOS đổi mục khác.
        let web = CTWGhimMuc(pin: ["connect"], hide: ["list"])
        XCTAssertEqual(CTWGhim.doiGhim("time", bat: true, cotLoi: core, web), CTWGhimMuc(pin: ["connect", "time"], hide: ["list"]))
    }

    func testChuyenGhimCu() {
        let core = CTWGhim.cotLoi(kind: "SOFTWARE", template: nil, type: "SCRUM")
        XCTAssertNil(CTWGhim.tuBanCu(CTWGhim.macDinhCu, cotLoi: core), "chưa đổi gì ⇒ để cốt lõi theo loại dự án")
        let cu = ["ai", "board", "backlog", "chat", "meetings", "calendar", "code", "time"]   // bỏ docs, thêm time
        XCTAssertEqual(CTWGhim.tuBanCu(cu, cotLoi: core), CTWGhimMuc(pin: ["time"], hide: ["docs"]))
    }

    func testThanPatchChiMotDuAn() throws {
        let t = CTWGhim.thanPatch(pid: 7, CTWGhimMuc(pin: ["time"], hide: []))
        let d = try JSONSerialization.data(withJSONObject: t, options: [.sortedKeys])
        XCTAssertEqual(String(data: d, encoding: .utf8), #"{"preferences":{"work":{"navPins":{"7":{"hide":[],"pin":["time"]}}}}}"#)
        let x = try JSONSerialization.data(withJSONObject: CTWGhim.thanPatch(pid: 9, nil), options: [.sortedKeys])
        XCTAssertEqual(String(data: x, encoding: .utf8), #"{"preferences":{"work":{"navPins":{"9":null}}}}"#)
    }

    func testGiaiMaTuyChonNavPins() throws {
        let j = #"{"theme":"dark","preferences":{"academy":{"x":1},"work":{"locale":"vi","navPins":{"7":{"pin":["chat"],"hide":[]},"8":{"pin":"bad"}}}}}"#
        let tc = try JSONDecoder().decode(CTWTuyChonNguoiDung.self, from: Data(j.utf8))
        XCTAssertEqual(tc.navPins["7"], CTWGhimMuc(pin: ["chat"], hide: []))
        XCTAssertEqual(tc.navPins["8"], CTWGhimMuc(pin: [], hide: []), "mục hỏng không làm hỏng cả bản đồ")
        let rong = try JSONDecoder().decode(CTWTuyChonNguoiDung.self, from: Data(#"{"preferences":{}}"#.utf8))
        XCTAssertTrue(rong.navPins.isEmpty)
    }

    // MARK: Xếp hạng

    func testXepHangKhiTha() {
        // Kéo 3 lên trên 1.
        XCTAssertEqual(CTWXepHang.viTriTha(dich: [1, 2, 3], dangKeo: 3, chenTruoc: 1), .init(truoc: nil, sau: 1, thuTu: [3, 1, 2]))
        // Kéo 1 xuống cuối.
        XCTAssertEqual(CTWXepHang.viTriTha(dich: [1, 2, 3], dangKeo: 1, chenTruoc: nil), .init(truoc: 3, sau: nil, thuTu: [2, 3, 1]))
        // Thẻ từ khung khác thả vào giữa.
        XCTAssertEqual(CTWXepHang.viTriTha(dich: [1, 2, 3], dangKeo: 9, chenTruoc: 2), .init(truoc: 1, sau: 2, thuTu: [1, 9, 2, 3]))
        // Khung rỗng.
        XCTAssertEqual(CTWXepHang.viTriTha(dich: [], dangKeo: 9, chenTruoc: nil), .init(truoc: nil, sau: nil, thuTu: [9]))
        // Thả về đúng chỗ ⇒ không gọi mạng.
        XCTAssertNil(CTWXepHang.viTriTha(dich: [1, 2, 3], dangKeo: 2, chenTruoc: 3))
        XCTAssertNil(CTWXepHang.viTriTha(dich: [1, 2, 3], dangKeo: 2, chenTruoc: 2))
        // Lên/xuống một bậc.
        XCTAssertEqual(CTWXepHang.dichMotBac(dich: [1, 2, 3], the: 2, len: true)?.thuTu, [2, 1, 3])
        XCTAssertEqual(CTWXepHang.dichMotBac(dich: [1, 2, 3], the: 2, len: false)?.thuTu, [1, 3, 2])
        XCTAssertNil(CTWXepHang.dichMotBac(dich: [1, 2, 3], the: 1, len: true))
    }

    // MARK: Board

    private func the(_ so: Int, nguoi: Int? = nil, cha: Int? = nil, loai: Int = 3, uuTien: Int = 3, rank: String? = nil) -> CTWIssueCard {
        CTWIssueCard(id: 100 + so, number: so, title: "T\(so)", typeId: loai, statusId: 1, parentId: cha, priority: uuTien, assigneeId: nguoi, rank: rank ?? "a\(so)")
    }

    func testChiaLanTheoNguoiEpicUuTienViecCon() {
        let c = cfg
        let ds = [the(1, nguoi: 2), the(2), the(3, nguoi: 1), the(4, nguoi: 77),
                  the(5, cha: 103, loai: 5), the(6, cha: 900)]   // 5 là việc con của thẻ 3 (đang trên board)
        let nguoi = CTWBangNhom.chiaLan(.assignee, ds, cfg: c, epicTen: [:])
        XCTAssertEqual(nguoi.map(\.key), ["u:1", "u:2", "u:77", "u:0"], "theo tên, Unassigned cuối")
        XCTAssertEqual(nguoi.first?.the.map(\.number), [3], "việc con đi theo cha, không thành thẻ rời")
        XCTAssertEqual(nguoi[2].tieuDeMacDinh, .thanhVienCu)
        let epic = CTWBangNhom.chiaLan(.epic, ds, cfg: c, epicTen: [900: (so: 9, ten: "Launch")])
        XCTAssertEqual(epic.map(\.key), ["e:900", "e:0"])
        XCTAssertEqual(epic[0].tieuDe, "Launch")
        let ut = CTWBangNhom.chiaLan(.priority, [the(1, uuTien: 4), the(2, uuTien: 1)], cfg: c, epicTen: [:])
        XCTAssertEqual(ut.map(\.uuTien), [1, 4])
        let con = CTWBangNhom.chiaLan(.subtasks, ds, cfg: c, epicTen: [:])
        XCTAssertEqual(con.first?.key, "p:103"); XCTAssertEqual(con.first?.the.map(\.number), [5])
        XCTAssertEqual(con.last?.key, "other"); XCTAssertFalse(con.last!.the.contains { $0.number == 3 || $0.number == 5 })
        XCTAssertEqual(CTWBangNhom.chiaLan(.none, ds, cfg: c, epicTen: [:]).first?.the.count, 5)
    }

    func testBoLocBang() {
        var l = CTWBoLocBang()
        let t = the(1, nguoi: 2, uuTien: 1)
        let ct = CTWBangNhom.cuoiTuan()
        XCTAssertTrue(l.khop(t, cfg: cfg, toi: 1, epicCua: nil, cuoiTuan: ct))
        l.chiCuaToi = true
        XCTAssertFalse(l.khop(t, cfg: cfg, toi: 1, epicCua: nil, cuoiTuan: ct))
        l = CTWBoLocBang(); l.nguoi = [0]
        XCTAssertFalse(l.khop(t, cfg: cfg, toi: 1, epicCua: nil, cuoiTuan: ct), "0 = chưa giao")
        l = CTWBoLocBang(); l.uuTien = [1]; l.epic = [0]
        XCTAssertTrue(l.khop(t, cfg: cfg, toi: 1, epicCua: nil, cuoiTuan: ct))
        XCTAssertFalse(l.khop(t, cfg: cfg, toi: 1, epicCua: 900, cuoiTuan: ct))
        XCTAssertEqual(l.soBat, 2)
    }

    func testHangLoatTheoTenTrangThai() {
        let c = cfg
        XCTAssertEqual(CTWHangLoat.tenTrangThai(c).map(\.name), ["To Do", "In Progress", "In Review", "Done"])
        let (nhom, thieu) = CTWHangLoat.nhomTheoTen(c, the: [the(1), the(2)], ten: "Done")
        XCTAssertEqual(nhom, [4: [1, 2]]); XCTAssertTrue(thieu.isEmpty)
        XCTAssertEqual(CTWHangLoat.nhomTheoTen(c, the: [the(1)], ten: "Nope").thieu, [1])
    }

    // MARK: Bộ lọc cơ bản ⇒ JQL (List + tìm toàn cục) — luôn TÊN GỐC kể cả khi app đang tiếng Việt

    func testBoLocCoBanThanhJqlTenGoc() {
        let cu = NgonNguCTW.cheDo
        defer { NgonNguCTW.dat(cu) }
        NgonNguCTW.dat(.vi); CTWDinhDang.locale = NgonNguCTW.locale
        var l = CTWAPI.BoLoc()
        l.type = [2, 4]; l.status = [2]; l.assignee = [1, 0, 3]; l.label = [1]; l.sprint = "backlog"; l.q = "say \"hi\""
        let j = DanhSachCTW.tuCoBan(l, uuTien: [2, 1], cfg: cfg, toi: 1)
        XCTAssertEqual(j, #"type IN (Story, Bug) AND status = "In Progress" AND assignee IN (currentUser(), EMPTY, minh) AND labels = ios AND priority IN (Highest, High) AND sprint IS EMPTY AND summary ~ "say \"hi\"""#)
        XCTAssertEqual(DanhSachCTW.tuCoBan(CTWAPI.BoLoc(), uuTien: [], cfg: cfg, toi: 1), "statusCategory != Done")
    }

    func testTimToanCucThanhJql() {
        var b = BoLocTimCTW()
        XCTAssertEqual(b.jql(coChu: false), "ORDER BY updated DESC")
        b.duAn = ["NW", "WEB"]; b.nhom = ["DONE", "TODO"]; b.nguoi = ["me", "none"]; b.capNhat = 7; b.loai = ["Bug"]
        XCTAssertEqual(b.jql(coChu: true), #"project IN (NW, WEB) AND type = Bug AND statusCategory IN ("To Do", Done) AND assignee IN (currentUser(), EMPTY) AND updated >= -7d"#)
        XCTAssertTrue(b.jql(coChu: false).hasSuffix("ORDER BY updated DESC"), "không có chữ ⇒ mới cập nhật lên đầu")
    }

    /// Dữ liệu mẫu (màn thử `them`) đi đúng đường giải mã của app: tuỳ chọn người dùng ⇒ navPins.
    func testMayChuGiaTraNavPins() throws {
        let d = DuLieuGia.traLoi(method: "GET", path: "/api/v1/users/me/preferences", body: [:])
        let tc = try XCTUnwrap(JSONDecoder().decode(APIResponse<CTWTuyChonNguoiDung>.self, from: d).data)
        XCTAssertEqual(tc.navPins["7"], CTWGhimMuc(pin: ["time", "sprints"], hide: ["code"]))
        let p = DuLieuGia.traLoi(method: "GET", path: "/api/v1/profile", body: [:])
        XCTAssertNoThrow(try JSONDecoder().decode(APIResponse<User>.self, from: p), "hồ sơ giả phải giải mã được — không thì ghim không đồng bộ ở màn thử")
    }
}
