import XCTest
@testable import CTWork

/// Kiểm thử mảng B2 — Timeline · Releases · Stages · Calendar.
/// Giải mã dữ liệu mẫu (đúng hình dạng backend) bằng model thật + kiểm phần tính toán thuần.
final class KeHoachB2Tests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET",
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: [:])
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    private func ngay(_ s: String) -> Date { NgayCTW.ngay(s)! }

    // MARK: Giải mã

    func testGiaiMaTimelineVaMoc() throws {
        let d = try giai(TLDuLieuCTW.self, "/work/projects/7/timeline")
        XCTAssertEqual(d.items?.filter(\.laEpic).count, 2)
        XCTAssertEqual(d.dependencies?.count, 3)
        XCTAssertEqual(d.conflicts?.first?.from, 114, "cạnh dùng ISSUE ID, không phải số thẻ")
        let m = try giai(TLMocCTW.self, "/work/projects/7/timeline/markers")
        XCTAssertEqual(m.sprints?.count, 3)
        XCTAssertFalse((m.versions ?? []).isEmpty)
        XCTAssertEqual(m.versions?.first?.release?.count, 10, "markers trả YMD")
        XCTAssertEqual(m.stages?.count, 5)
    }

    func testGiaiMaPhienBan() throws {
        let ds = try giai([PhienBanCTW].self, "/work/projects/7/versions")
        XCTAssertEqual(ds.count, 5)
        XCTAssertTrue(ds.contains { $0.overdue == true })
        XCTAssertEqual(ds.first { $0.id == 2 }?.releaseDate?.hasSuffix("T00:00:00.000Z"), true, "cột @db.Date ⇒ ISO nửa đêm")
        let ct = try giai(PhienBanChiTietCTW.self, "/work/projects/7/versions/2")
        XCTAssertEqual(ct.version?.name, "1.0")
        XCTAssertFalse((ct.issues ?? []).isEmpty)
        let b = try giai(BurnupPhatHanhCTW.self, "/work/projects/7/reports/release-burnup")
        XCTAssertEqual(b.points?.count, 15)
        XCTAssertNotNil(NgayCTW.ngay(b.forecast))
        let kq = try giai(KetQuaPhatHanhCTW.self, "/work/projects/7/versions/2/release", method: "POST")
        XCTAssertEqual(kq.version?.status, "RELEASED")
    }

    func testGiaiMaGiaiDoanVaLich() throws {
        let gd = try giai([GiaiDoanCTW].self, "/work/projects/7/stages")
        XCTAssertEqual(gd.map(\.status), ["DONE", "DONE", "GATE_REVIEW", "NOT_STARTED", "NOT_STARTED"])
        XCTAssertEqual(gd[2].gateIssue?.number, 20)
        XCTAssertEqual(gd[2].pendingApprovalId, 41)
        let tt = TomTatGiaiDoanCTW.tinh(gd)
        XCTAssertEqual(tt, TomTatGiaiDoanCTW(xong: 2, tong: 5, hienTai: "Build"))
        XCTAssertEqual(gd[2].tiLe, 19.0 / 24.0, accuracy: 0.0001)
        let h = try giai(DsHopLichCTW.self, "/work/projects/7/meetings")
        XCTAssertFalse((h.items ?? []).isEmpty)
        let l = try giai(LinkLichMoiCTW.self, "/work/me/calendar-link", method: "POST")
        XCTAssertEqual(l.path?.hasSuffix(".ics"), true)
    }

    // MARK: Gantt

    func testThanhTheoNgay() {
        let sp: TLBoDungCTW.Khoang = [21: (ngay("2026-10-12"), ngay("2026-10-25"))]
        let vs: TLBoDungCTW.Khoang = [3: (ngay("2026-11-01"), ngay("2026-11-20"))]
        // start + due ⇒ thanh đầy đủ
        let a = TLMucCTW(id: 1, number: 1, title: "a", start: "2026-10-14", due: "2026-10-16")
        XCTAssertEqual(TLBoDungCTW.thanhRieng(a, sprint: sp, version: vs), TLThanhCTW(batDau: ngay("2026-10-14"), ketThuc: ngay("2026-10-16"), kieu: .day))
        // chỉ due ⇒ 1 ngày
        let b = TLMucCTW(id: 2, number: 2, title: "b", due: "2026-10-20")
        XCTAssertEqual(TLBoDungCTW.thanhRieng(b, sprint: sp, version: vs)?.kieu, .motNgay)
        // chỉ start ⇒ mở đuôi 5 ngày
        let c = TLMucCTW(id: 3, number: 3, title: "c", start: "2026-10-20")
        XCTAssertEqual(TLBoDungCTW.thanhRieng(c, sprint: sp, version: vs)?.ketThuc, ngay("2026-10-24"))
        // không ngày ⇒ khoảng sprint, rồi khoảng version, rồi không có
        let d = TLMucCTW(id: 4, number: 4, title: "d", sprintId: 21, fixVersionId: 3)
        XCTAssertEqual(TLBoDungCTW.thanhRieng(d, sprint: sp, version: vs), TLThanhCTW(batDau: ngay("2026-10-12"), ketThuc: ngay("2026-10-25"), kieu: .suyRa))
        let e = TLMucCTW(id: 5, number: 5, title: "e", fixVersionId: 3)
        XCTAssertEqual(TLBoDungCTW.thanhRieng(e, sprint: sp, version: vs)?.batDau, ngay("2026-11-01"))
        XCTAssertNil(TLBoDungCTW.thanhRieng(TLMucCTW(id: 6, number: 6, title: "f"), sprint: sp, version: vs))
        // start > due (dữ liệu bẩn) ⇒ vẫn ra thanh đúng chiều
        let g = TLMucCTW(id: 7, number: 7, title: "g", start: "2026-10-20", due: "2026-10-18")
        XCTAssertEqual(TLBoDungCTW.thanhRieng(g, sprint: sp, version: vs)?.batDau, ngay("2026-10-18"))
    }

    func testEpicKhongNgayPhuCon() {
        let ds = [
            TLMucCTW(id: 10, number: 10, title: "Epic", level: 1),
            TLMucCTW(id: 11, number: 11, title: "x", parentId: 10, level: 0, start: "2026-10-05", due: "2026-10-08"),
            TLMucCTW(id: 12, number: 12, title: "y", parentId: 10, level: 0, due: "2026-10-30"),
        ]
        let t = TLBoDungCTW.tatCaThanh(ds, sprint: [:], version: [:])
        XCTAssertEqual(t[10], TLThanhCTW(batDau: ngay("2026-10-05"), ketThuc: ngay("2026-10-30"), kieu: .suyRa))
    }

    func testHinhHocTheoZoom() {
        let goc = ngay("2026-10-05")
        let tuan = TLHinhHocCTW(goc: goc, soNgay: 60, rongNgay: TLZoomCTW.tuan.rongNgay)
        let t = TLThanhCTW(batDau: ngay("2026-10-07"), ketThuc: ngay("2026-10-09"), kieu: .day)
        XCTAssertEqual(tuan.khung(t).x, 64)
        XCTAssertEqual(tuan.khung(t).rong, 96, "3 ngày × 32pt (hai đầu tính cả ngày)")
        let thang = TLHinhHocCTW(goc: goc, soNgay: 60, rongNgay: TLZoomCTW.thang.rongNgay)
        XCTAssertEqual(thang.khung(t).rong, 30)
        XCTAssertEqual(thang.rongTong, 600)
        let mot = TLThanhCTW(batDau: ngay("2026-10-07"), ketThuc: ngay("2026-10-07"), kieu: .motNgay)
        XCTAssertEqual(tuan.khung(mot).rong, 32, "thanh tối thiểu một ngày")
    }

    func testPhamViTrucChuaHomNay() {
        let hn = ngay("2026-10-18")
        let t = [TLThanhCTW(batDau: ngay("2026-11-02"), ketThuc: ngay("2026-11-05"), kieu: .day)]
        let p = TLBoDungCTW.phamVi(t, homNay: hn)
        XCTAssertLessThanOrEqual(p.goc, hn)
        XCTAssertEqual(NgayCTW.lichVN.component(.weekday, from: p.goc), 2, "trục bắt đầu thứ Hai")
        XCTAssertGreaterThanOrEqual(p.soNgay, 56)
        XCTAssertGreaterThan(NgayCTW.cong(p.goc, ngay: p.soNgay), ngay("2026-11-05"))
    }

    func testHangTheoCayVaAnKhongLich() {
        let ds = [
            TLMucCTW(id: 10, number: 10, title: "E", level: 1, start: "2026-10-01", due: "2026-10-10"),
            TLMucCTW(id: 11, number: 11, title: "con", parentId: 10, level: 0, due: "2026-10-03"),
            TLMucCTW(id: 12, number: 12, title: "con không lịch", parentId: 10, level: 0),
            TLMucCTW(id: 13, number: 13, title: "lẻ", level: 0, due: "2026-10-04"),
        ]
        let h = TLBoDungCTW.hang(ds, anKhongLich: false, coThanh: [10, 11, 13])
        XCTAssertEqual(h.map(\.id), ["muc-10", "muc-11", "muc-12", "nhom-No epic", "muc-13"])
        let an = TLBoDungCTW.hang(ds, anKhongLich: true, coThanh: [10, 11, 13])
        XCTAssertFalse(an.contains { $0.id == "muc-12" })
        if case .muc(_, let thut) = h[1] { XCTAssertTrue(thut) } else { XCTFail() }
    }

    func testNhomTheoThang() {
        let ds = [
            TLMucCTW(id: 1, number: 1, title: "a", due: "2026-11-03"),
            TLMucCTW(id: 2, number: 2, title: "b", start: "2026-10-20"),
            TLMucCTW(id: 3, number: 3, title: "c", due: "2026-10-05"),
            TLMucCTW(id: 4, number: 4, title: "d"),
        ]
        let n = TLBoDungCTW.theoThang(ds, thanh: [:])
        XCTAssertEqual(n.count, 3)
        XCTAssertEqual(n[0].ds.map(\.number), [3, 2], "trong tháng sắp theo ngày")
        XCTAssertEqual(n[1].ds.map(\.number), [1])
        XCTAssertNil(n[2].thang)
        XCTAssertEqual(n[2].ds.map(\.number), [4])
    }

    // MARK: Releases

    func testTienDoPhienBanTheoNhom() {
        func the(_ so: Int, _ st: Int, xong: Bool = false) -> CTWIssueCard {
            CTWIssueCard(id: so, number: so, title: "t", typeId: 1, statusId: st, resolvedAt: xong ? "2026-10-01T00:00:00Z" : nil)
        }
        let nhom: (Int) -> String? = { [1: "TODO", 2: "IN_PROGRESS", 3: "IN_PROGRESS", 4: "DONE"][$0] }
        let t = TienDoPhienBanCTW.tinh([the(1, 1), the(2, 2), the(3, 3), the(4, 4), the(5, 1, xong: true)], nhom: nhom)
        XCTAssertEqual(t, TienDoPhienBanCTW(xong: 2, dangLam: 2, chuaLam: 1))
        XCTAssertEqual(t.tiLe, 0.4, accuracy: 0.0001)
        XCTAssertEqual(TienDoPhienBanCTW.tinh([], nhom: nhom).tiLe, 0)
        let v = PhienBanCTW(id: 1, name: "1.0", total: 14, done: 6)
        XCTAssertEqual(v.tiLe, 6.0 / 14.0, accuracy: 0.0001)
    }

    // MARK: Calendar

    func testGopLichTheoNgay() {
        let viec = [CTWMyWorkItem(key: "NW-1", number: 1, title: "Một", dueDate: "2026-10-20",
                                  project: CTWMyWorkProject(key: "NW", name: "N"), workspace: CTWMyWorkSpace(slug: "nw", name: "N")),
                    CTWMyWorkItem(key: "NW-2", number: 2, title: "Hai", dueDate: "2026-10-10"),
                    CTWMyWorkItem(key: "NW-3", number: 3, title: "Không hạn")]
        let moc = TLMocCTW(sprints: [TLMocSprintCTW(id: 5, name: "S5", status: "CLOSED", start: "2026-10-01", end: "2026-10-14")],
                           versions: [TLMocVersionCTW(id: 2, name: "1.0", status: "UNRELEASED", release: "2026-10-20")],
                           stages: [])
        let ds = GopLichCTW.dung(viec: viec, moc: moc, sprintCfg: [], hop: [], homNay: ngay("2026-10-18"))
        XCTAssertEqual(ds.filter { $0.loai == .han }.count, 2, "thẻ không hạn không lên lịch")
        XCTAssertEqual(ds.filter { $0.loai == .sprint }.count, 2, "sprint ⇒ hai sự kiện bắt đầu/kết thúc")
        XCTAssertTrue(ds.first { $0.id == "han-NW-2" }?.quaHan == true)
        XCTAssertFalse(ds.first { $0.id == "han-NW-1" }?.quaHan == true)
        let g = GopLichCTW.theoNgay(ds)
        XCTAssertEqual(g["2026-10-20"]?.map(\.loai).sorted { $0.rawValue < $1.rawValue }, [.han, .phatHanh])
        XCTAssertEqual(g["2026-10-14"]?.first?.tieuDe, "S5 ends")
    }

    func testSprintCauHinhThangMarkerLechNgay() {
        // Sprint lưu 00:00 VN = 17:00Z hôm trước: markers (cắt UTC) báo 2026-10-11, cfg (ISO) đúng 2026-10-12.
        let moc = TLMocCTW(sprints: [TLMocSprintCTW(id: 21, name: "S6", status: "ACTIVE", start: "2026-10-11", end: "2026-10-24")])
        let cfg = [CTWSprint(id: 21, name: "S6", state: "ACTIVE", startAt: "2026-10-11T17:00:00.000Z", endAt: "2026-10-25T17:00:00.000Z")]
        let ds = GopLichCTW.dung(viec: [], moc: moc, sprintCfg: cfg, hop: [])
        XCTAssertEqual(ds.filter { $0.loai == .sprint }.count, 2)
        XCTAssertEqual(ds.first { $0.id == "sp-21-a" }.map { NgayCTW.ymd($0.batDau) }, "2026-10-12")
    }

    func testHopSapTheoGioVaBoHuy() {
        let h = [HopLichCTW(id: 1, title: "Muộn", status: "SCHEDULED", startsAt: "2026-10-20T08:00:00.000Z"),
                 HopLichCTW(id: 2, title: "Sớm", status: "SCHEDULED", startsAt: "2026-10-20T02:00:00.000Z"),
                 HopLichCTW(id: 3, title: "Huỷ", status: "CANCELLED", startsAt: "2026-10-20T03:00:00.000Z")]
        let ds = GopLichCTW.dung(viec: [], moc: TLMocCTW(), sprintCfg: [], hop: h)
        XCTAssertEqual(ds.count, 2)
        let g = GopLichCTW.theoNgay(ds)
        let ngayHop = g.values.flatMap { $0 }.sorted { $0.batDau < $1.batDau }
        XCTAssertEqual(ngayHop.map(\.tieuDe), ["Sớm", "Muộn"])
    }

    func testLuoiThangBatDauThuHai() {
        var l = Calendar(identifier: .gregorian)
        l.timeZone = TimeZone(identifier: "UTC")!
        let o = GopLichCTW.oThang(l.date(from: DateComponents(year: 2026, month: 10, day: 18))!, lich: l)
        XCTAssertEqual(o.count, 42)
        XCTAssertEqual(l.component(.weekday, from: o[0]), 2)
        // 1/10/2026 là thứ Năm ⇒ ô đầu = 28/9.
        XCTAssertEqual(l.dateComponents([.month, .day], from: o[0]), DateComponents(month: 9, day: 28))
    }
}
