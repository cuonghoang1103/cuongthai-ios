import XCTest
@testable import CTWork

/// Kiểm thử mảng B1 — Sprints · Reports · Dashboards.
///
/// (1) Giải mã dữ liệu mẫu (`XemThuCTW+B1.swift`, viết theo hình dạng service backend) bằng
///     CHÍNH model của app — bắt kiểu lệch (CLAUDE.md C3/C4).
/// (2) Hàm tính thuần: chỉ số/burndown/burnup/dự báo sprint, đếm thẻ, phân bố, CFD, created-resolved.
final class KeHoachB1Tests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET",
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: [:])
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    // MARK: Giải mã

    func testGiaiMaSprint() throws {
        let ds = try giai([CTWSprintDu].self, "/work/projects/7/sprints")
        XCTAssertEqual(ds.filter(\.dangChay).map(\.id), [21])
        XCTAssertTrue(ds.contains { $0.chuaBatDau && $0.id == 22 })
        XCTAssertGreaterThanOrEqual(ds.filter(\.daDong).count, 3)
        let sap = TinhSprintCTW.sap(ds)
        XCTAssertEqual(sap.first?.id, 21, "sprint đang chạy đứng đầu")
        XCTAssertEqual(sap[1].id, 22, "rồi tới sprint chưa bắt đầu")
        XCTAssertEqual(sap[2].id, 20, "sprint đóng gần nhất trước")

        let bd = try giai(CTWBurndown.self, "/work/projects/7/reports/burndown")
        XCTAssertEqual(bd.unit, "POINTS")
        XCTAssertEqual(bd.points?.count, 15)
        XCTAssertNil(bd.points?.last?.remaining, "ngày tương lai = null")
        let bc = try giai(CTWBaoCaoSprint.self, "/work/projects/7/reports/sprint")
        XCTAssertEqual(bc.report?.soXong, 2)
        XCTAssertEqual(bc.report?.added, [20])
        let ht = try giai(CTWSprintCompleteKetQua.self, "/work/projects/7/sprints/21/complete", method: "POST")
        XCTAssertNotNil(ht.report)
    }

    func testGiaiMaBaoCao() throws {
        let v = try giai(CTWVelocity.self, "/work/projects/7/reports/velocity")
        XCTAssertEqual(v.sprints?.count, 5)
        XCTAssertEqual(v.average ?? 0, 22.7, accuracy: 0.01)
        XCTAssertEqual(try giai(CTWEpicsBaoCao.self, "/work/projects/7/reports/epics").epics?.count, 3)
        let k = try giai(CTWKpis.self, "/work/projects/7/reports/kpis")
        XCTAssertEqual(k.sprint?.status, "AT_RISK")
        XCTAssertNil(k.blocked?.previous)
        let i = try giai(CTWInsights.self, "/work/projects/7/insights")
        XCTAssertEqual(i.stale?.first?.idleDays, 9)
        XCTAssertEqual(i.sprintRisk?.atRisk, true)
        let c = try giai(CTWCfd.self, "/work/projects/7/reports/cfd")
        XCTAssertEqual(c.bands?.count, 4)
        XCTAssertEqual(c.points?.count, 30)
        XCTAssertNotNil(c.points?.first?.giaTri["s4"], "khoá động của dải giải mã được")
        XCTAssertEqual(try giai(CTWThroughput.self, "/work/projects/7/reports/throughput").weeks?.count, 12)
        XCTAssertEqual(try giai(CTWCycleTime.self, "/work/projects/7/reports/cycle-time").cycle?.p85, 6)
        let t = try giai(CTWTaiTheoNguoi.self, "/work/projects/7/reports/load-by-person")
        XCTAssertNil(t.people?.last?.user, "hàng 'Unassigned' có user = null")
        XCTAssertEqual(try giai([CTWTaoXongNgay].self, "/work/projects/7/stats/created-resolved").count, 31)
        let tk = try giai(CTWThongKe.self, "/work/projects/7/stats")
        XCTAssertEqual(tk.total, (tk.groups ?? []).compactMap(\.count).reduce(0, +))
        let s = try giai(CTWKetQuaJql.self, "/work/projects/7/search")
        XCTAssertEqual(s.total, s.items?.count)
        let tg = try giai(CTWBaoCaoThoiGian.self, "/work/projects/7/reports/time")
        XCTAssertTrue((tg.people ?? []).contains { $0.userKind == "AGENT" })
    }

    func testGiaiMaNguoiVsAgent() throws {
        let r = try giai(CTWNguoiVsAgent.self, "/work/projects/7/reports/agents")
        let a = try XCTUnwrap(r.agents?.first)
        XCTAssertEqual(a.agent?.displayName, "Scout")
        XCTAssertEqual(a.agent?.owner?.ten, "Linh Tran")
        // Chi phí tự khai + đo được cộng lại đúng tổng (web ghi nhãn "self-reported").
        let n = try XCTUnwrap(a.costSource)
        XCTAssertEqual((n.reported ?? 0) + (n.gateway ?? 0), a.costUsd ?? 0, accuracy: 0.0001)
        XCTAssertNil(r.humans?.first?.cost, "chi phí người ẩn khi không có quyền tài chính")
        XCTAssertNil(r.currency)
    }

    func testGiaiMaDashboard() throws {
        let ds = try giai([CTWDashboardDb].self, "/work/projects/7/dashboards")
        let d = try XCTUnwrap(ds.first)
        XCTAssertEqual(d.widgets?.first?.kind, "kpis")
        XCTAssertTrue((d.widgets ?? []).contains { $0.kind == "pie" && $0.groupBy == "status" })
        let m = try giai(CTWDsMauBaoCaoDb.self, "/work/projects/7/report-builder/templates")
        XCTAssertEqual(m.builtins?.first?.ref, "builtin:weekly")
        let bc = try giai(CTWBaoCaoDungDb.self, "/work/projects/7/report-builder/preview", method: "POST")
        let loai = (bc.blocks ?? []).map(\.type)
        XCTAssertEqual(loai, ["heading", "kpis", "chart", "issues", "risks", "ai"])
        XCTAssertEqual(bc.blocks?[3].rows?.count, 2)
        XCTAssertTrue(bc.blocks?[2].svg?.hasPrefix("<svg") == true)
    }

    // MARK: Tính sprint

    private func bd(_ con: [Double?], tong: [Double?], state: String = "ACTIVE", cam: Double? = nil, xong: Double? = nil) -> CTWBurndown {
        let ngay0 = Date(timeIntervalSince1970: 1_790_000_000) // ngày cố định
        let diem = con.enumerated().map { i, c in
            CTWBurndownDiem(day: NgayCTW.ymd(NgayCTW.cong(ngay0, ngay: i)), remaining: c, total: tong[i],
                            done: c.flatMap { c in tong[i].map { $0 - c } }, ideal: 10 - Double(i))
        }
        return CTWBurndown(sprint: CTWSprintBaoCao(id: 1, state: state, committedPoints: cam, completedPoints: xong), unit: "POINTS", points: diem)
    }

    func testChiSoSprint() {
        // Đang chạy: committed lấy từ sprint, completed/remaining từ ngày biết gần nhất.
        let a = TinhSprintCTW.chiSo(bd([10, 8, 6, nil, nil], tong: [10, 10, 11, nil, nil], cam: 10))
        XCTAssertEqual(a, ChiSoSprintCTW(cam: 10, xong: 5, con: 6))
        XCTAssertEqual(a.tiLe, 0.5, accuracy: 0.0001)
        // Không có committedPoints ⇒ lấy total của ngày đầu.
        XCTAssertEqual(TinhSprintCTW.chiSo(bd([12, 9], tong: [12, 12])).cam, 12)
        // Đã đóng ⇒ completed = completedPoints của sprint.
        XCTAssertEqual(TinhSprintCTW.chiSo(bd([10, 2], tong: [10, 10], state: "CLOSED", cam: 10, xong: 9)).xong, 9)
        // Không có điểm nào ⇒ remaining = committed, tỉ lệ 0.
        let r = TinhSprintCTW.chiSo(CTWBurndown(sprint: CTWSprintBaoCao(id: 1, committedPoints: 7), unit: nil, points: []))
        XCTAssertEqual(r, ChiSoSprintCTW(cam: 7, xong: 0, con: 7))
        XCTAssertEqual(ChiSoSprintCTW(cam: 0, xong: 3, con: 0).tiLe, 0)
    }

    func testChuoiBurndownBurnup() {
        let c = TinhSprintCTW.chuoi(bd([10, 8, nil], tong: [10, 12, nil]))
        XCTAssertEqual(c.count, 3)
        XCTAssertEqual(c[1].xong, 4, "burnup: done = total − remaining")
        XCTAssertEqual(c[1].tong, 12, "burnup thấy phạm vi tăng")
        XCTAssertNil(c[2].conLai)
        XCTAssertEqual(c[2].lyTuong, 8, "ngày tương lai vẫn có đường lý tưởng")
        XCTAssertTrue(c[0].ngay < c[1].ngay)
    }

    func testDuBaoVaNgayConLai() throws {
        // Đốt 2 điểm/ngày trong 2 ngày, còn 6 ⇒ thêm 3 ngày sau ngày biết gần nhất.
        let b = bd([10, 8, 6], tong: [10, 10, 10])
        let du = try XCTUnwrap(TinhSprintCTW.duBaoXong(b))
        let cuoi = try XCTUnwrap(TinhSprintCTW.chuoi(b).last?.ngay)
        XCTAssertEqual(NgayCTW.soNgay(cuoi, du), 3)
        // Chưa đốt được gì ⇒ không đoán.
        XCTAssertNil(TinhSprintCTW.duBaoXong(bd([10, 10, 10], tong: [10, 10, 10])))
        // Phạm vi tăng cũng là việc đã làm: còn lại không đổi nhưng đã đốt 2 (thêm 2 vào phạm vi).
        XCTAssertNotNil(TinhSprintCTW.duBaoXong(bd([10, 10], tong: [10, 12])))

        let homNay = try XCTUnwrap(NgayCTW.ngay("2026-10-18"))
        XCTAssertEqual(TinhSprintCTW.ngayConLai(endAt: "2026-10-25T17:00:00.000Z", homNay: homNay), 8, "17:00Z = 00:00 hôm sau giờ VN")
        XCTAssertEqual(TinhSprintCTW.ngayConLai(endAt: "2026-10-16", homNay: homNay), -2)
        XCTAssertNil(TinhSprintCTW.ngayConLai(endAt: nil))
        XCTAssertEqual(TinhSprintCTW.thoiGianDaQua(startAt: "2026-10-11", endAt: "2026-10-25", homNay: homNay) ?? -1, 0.5, accuracy: 0.0001)
    }

    func testDemTheVaDiem() {
        func the(_ so: Int, _ st: Int, loai: Int = 2, sp: Double? = nil, xong: Bool = false) -> CTWIssueCard {
            CTWIssueCard(id: so, number: so, title: "T\(so)", typeId: loai, statusId: st, storyPoints: sp, resolvedAt: xong ? "2026-10-01" : nil)
        }
        let nhom: (Int) -> String? = { [1: "TODO", 2: "IN_PROGRESS", 3: "IN_PROGRESS", 4: "DONE"][$0] }
        let ds = [the(1, 1, sp: 3), the(2, 2, sp: 5), the(3, 3, sp: 2), the(4, 4, sp: 8), the(5, 4, loai: 5, sp: 1),
                  the(6, 99, sp: nil, xong: true)]
        let laCon: (Int) -> Bool = { $0 == 5 }
        let d = TinhSprintCTW.demThe(ds, nhom: nhom, laTheCon: laCon)
        XCTAssertEqual(d, DemTheSprintCTW(chuaLam: 1, dangLam: 2, xong: 2), "thẻ con không đếm; trạng thái lạ mà đã resolve ⇒ xong")
        XCTAssertEqual(d.tong, 5)
        XCTAssertEqual(d.tiLe, 0.4, accuracy: 0.0001)
        XCTAssertEqual(TinhSprintCTW.tongDiem(ds, laTheCon: laCon), 18)
        XCTAssertEqual(DemTheSprintCTW().tiLe, 0)
    }

    // MARK: Tính báo cáo

    func testPhanBo() {
        let g = (1...10).map { CTWNhomThongKe(key: "k\($0)", label: "G\($0)", count: $0, points: Double($0) * 2) }
        let p = TinhBaoCaoCTW.phanBo(g)
        XCTAssertEqual(p.count, 9, "8 nhóm + 'Other'")
        XCTAssertEqual(p.first?.nhan, "G10", "sắp giảm dần")
        XCTAssertEqual(p.last?.nhan, "Other (2)")
        XCTAssertEqual(p.last?.giaTri, 3, "1 + 2 gộp vào Other")
        XCTAssertEqual(p.map(\.tiLe).reduce(0, +), 1, accuracy: 0.0001, "phần trăm cộng đủ 100%")
        XCTAssertEqual(p.last?.viTriMau, 8)
        // Theo điểm + giữ thứ tự máy chủ (ưu tiên p1…p5).
        let u = TinhBaoCaoCTW.phanBo(Array(g.prefix(3)), theoDiem: true, giuThuTu: true)
        XCTAssertEqual(u.map(\.nhan), ["G1", "G2", "G3"])
        XCTAssertEqual(u.map(\.giaTri), [2, 4, 6])
        XCTAssertEqual(u[2].tiLe, 0.5, accuracy: 0.0001)
        // Nhóm 0 bị bỏ; toàn 0 ⇒ rỗng.
        XCTAssertTrue(TinhBaoCaoCTW.phanBo([CTWNhomThongKe(key: "a", count: 0)]).isEmpty)
    }

    func testCfdVaTaoXong() {
        let c = CTWCfd(bands: [CTWCfdDai(key: "s1", name: "To Do", category: "TODO"), CTWCfdDai(key: "s4", name: "Done", category: "DONE")],
                       points: [CTWCfdDiem(day: "2026-10-01", giaTri: ["s1": 3, "s4": 1]), CTWCfdDiem(day: "bad", giaTri: [:])])
        let d = TinhBaoCaoCTW.cfd(c)
        XCTAssertEqual(d.count, 2, "ngày hỏng bị bỏ")
        XCTAssertEqual(d.first?.dai, "s4", "DONE xếp dưới cùng")
        XCTAssertEqual(d.first?.thuTu, 0)
        XCTAssertEqual(d.last?.giaTri, 3)

        let t = TinhBaoCaoCTW.taoXong([CTWTaoXongNgay(day: "a", created: 3, resolved: 1), CTWTaoXongNgay(day: "b", created: nil, resolved: 4)])
        XCTAssertEqual(t.tao, 3)
        XCTAssertEqual(t.xong, 5)
        XCTAssertEqual(t.chenh, -2)
    }

    func testThoiGianTheoNgayVaKhoang() throws {
        let r = CTWBaoCaoThoiGian(from: "2026-10-12", to: "2026-10-14", people: [
            CTWThoiGianNguoi(totalMin: 90, byDay: ["2026-10-12": 60, "2026-10-14": 30]),
            CTWThoiGianNguoi(totalMin: 45, byDay: ["2026-10-12": 45])])
        let d = TinhBaoCaoCTW.phutTheoNgay(r)
        XCTAssertEqual(d.map(\.ymd), ["2026-10-12", "2026-10-13", "2026-10-14"])
        XCTAssertEqual(d.map(\.phut), [105, 0, 30])
        XCTAssertEqual(d.map(\.phut).reduce(0, +), 135, "tổng theo ngày = tổng theo người")

        let homNay = try XCTUnwrap(NgayCTW.ngay("2026-10-18")) // Chủ nhật
        XCTAssertEqual(TinhBaoCaoCTW.khoang(14, homNay: homNay).tu, "2026-10-05")
        XCTAssertEqual(TinhBaoCaoCTW.tuanNay(homNay: homNay).tu, "2026-10-12", "tuần bắt đầu Thứ Hai")
        XCTAssertEqual(TinhBaoCaoCTW.xuHuong(CTWKpiSo(value: 24, previous: 30)) ?? 0, -0.2, accuracy: 0.0001)
        XCTAssertNil(TinhBaoCaoCTW.xuHuong(CTWKpiSo(value: 3, previous: 0)))
    }

    // MARK: Đăng ký

    func testDangKyMoDunB1() {
        for id in ["sprints", "reports", "dashboards"] {
            XCTAssertNotNil(CTWDangKyMoDun.moDun(id), "đã đăng ký \(id)")
        }
        XCTAssertEqual(CTWDangKyMoDun.moDun(choDoan: "reports")?.id, "reports")
        XCTAssertEqual(CTWDangKyMoDun.moDun(choDoan: "dashboards")?.id, "dashboards")
        XCTAssertEqual(TabBaoCaoCTW.tuWeb("health"), .tongQuan)
        XCTAssertEqual(TabBaoCaoCTW.tuWeb("agents"), .agents)
        XCTAssertNil(TabBaoCaoCTW.tuWeb("steering"))
    }
}
