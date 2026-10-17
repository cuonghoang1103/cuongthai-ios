import XCTest
@testable import CTWork

/// Mảng Governance: giải mã dữ liệu mẫu (hình dạng backend) bằng model thật +
/// luật thuần (bước chuyển CR, điểm/mức RAID, bước review, "tới lượt ai").
final class GovernanceCTWTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET", body: [String: Any] = [:],
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: body)
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    // MARK: Giải mã

    func testPheDuyet() throws {
        let cho = try giai([CTWDuyet].self, "/work/me/approvals")
        XCTAssertEqual(cho.first?.project?.id, 7)
        XCTAssertEqual(cho.first?.canDecide, true)

        let ds = try giai([CTWDuyet].self, "/work/projects/7/approvals")
        XCTAssertEqual(ds.count, 3)
        let cr = try XCTUnwrap(ds.first { $0.id == 41 })
        XCTAssertEqual(cr.nhanDoiTuong, "CR-5")
        XCTAssertEqual(cr.soDaDuyet, 1)
        XCTAssertEqual(cr.dsBuoc.map(\.position), [0, 1, 2])
        XCTAssertTrue(cr.tuanTu)

        let cong = try giai(CTWDuyet.self, "/work/projects/7/approvals/35")
        XCTAssertEqual(cong.targetType, "STAGE_GATE")
        XCTAssertEqual(cong.evidence?.issueTotal, 14)
        XCTAssertEqual(cong.evidence?.issues?.first?.status?.category, "DONE")
        XCTAssertEqual(cong.evidence?.files?.first?.size, 182_000)
        XCTAssertTrue(cong.nhanDoiTuong.hasPrefix("Gate 2"))

        let tl = try giai(CTWDuyet.self, "/work/projects/7/approvals/38")
        XCTAssertEqual(tl.contentChanged, true)
        XCTAssertFalse(tl.tuanTu)

        let xong = try giai(CTWDuyet.self, "/work/projects/7/approvals/41/decide", method: "POST", body: ["decision": "APPROVE"])
        XCTAssertEqual(xong.status, "APPROVED")
        // Dữ liệu mẫu mảng A (XemThuCTW+GiaoTiep, hỏi TRƯỚC) trả bản rút gọn cho `/decide` ⇒ chỉ chắc `status`.
        XCTAssertNotEqual(xong.canDecide, true)
    }

    func testTheoLuotKhiThieuWaitingOn() throws {
        // Máy chủ cũ không gửi `waitingOn` ⇒ tự suy: tuần tự chỉ bước PENDING đầu tiên.
        let json = #"""
        {"id":1,"mode":"SEQUENTIAL","status":"PENDING","steps":[
          {"id":3,"approverId":30,"position":2,"decision":"PENDING"},
          {"id":1,"approverId":10,"position":0,"decision":"APPROVED"},
          {"id":2,"approverId":20,"position":1,"decision":"PENDING"}]}
        """#
        var a = try JSONDecoder().decode(CTWDuyet.self, from: Data(json.utf8))
        XCTAssertEqual(a.dangChoAi, [20])
        a.mode = "PARALLEL"
        XCTAssertEqual(a.dangChoAi, [20, 30])
        a.status = "APPROVED"
        XCTAssertEqual(a.dangChoAi, [])
        XCTAssertEqual(CTWDuyet.bamNgan("9f2c41aa7d0e33b2c6f1"), "9f2c41aa…c6f1")
    }

    func testChangeRequest() throws {
        let ds = try giai(CTWCrDanhSach.self, "/work/projects/7/changes")
        XCTAssertEqual(ds.items?.count, 3)
        XCTAssertEqual(ds.totals?.byStatus?["APPROVED"], 1)
        XCTAssertEqual(ds.totals?.approvedCost?.first?.amount, 25_000_000)
        let c = try giai(CTWCr.self, "/work/projects/7/changes/5")
        XCTAssertEqual(c.pendingApprovalId, 41)
        XCTAssertEqual(c.links?.count, 2)
        XCTAssertEqual(c.links?.last?.version?.name, "v1.0")
        XCTAssertEqual(c.risks?.first?.impact, 5)
        XCTAssertEqual(c.nhanLich, "+3 days")
        XCTAssertEqual(c.nhanChiPhi, "18,000,000 VND")
        XCTAssertFalse(c.descriptionJson?.chuTron.isEmpty ?? true)
        let c6 = try giai(CTWCr.self, "/work/projects/7/changes/6")
        XCTAssertEqual(c6.nhanLich, "−2 days")
        XCTAssertNil(c6.nhanChiPhi)
    }

    func testLuatChuyenTayCr() {
        XCTAssertEqual(CTWCrLuat.buocTay(tu: "DRAFT"), ["SUBMITTED"])
        XCTAssertEqual(CTWCrLuat.buocTay(tu: "SUBMITTED"), ["DRAFT"])
        XCTAssertEqual(CTWCrLuat.buocTay(tu: "REJECTED"), ["DRAFT"])
        XCTAssertEqual(CTWCrLuat.buocTay(tu: "APPROVED"), ["IMPLEMENTED"])
        // Chỉ phê duyệt mới đưa vào/ra UNDER_REVIEW — đặt tay máy chủ trả 409.
        XCTAssertEqual(CTWCrLuat.buocTay(tu: "UNDER_REVIEW"), [])
        XCTAssertEqual(CTWCrLuat.buocTay(tu: "IMPLEMENTED"), [])
        XCTAssertTrue(CTWCrLuat.xinDuyetDuoc("DRAFT"))
        XCTAssertFalse(CTWCrLuat.xinDuyetDuoc("UNDER_REVIEW"))
    }

    func testRaid() throws {
        let ds = try giai(CTWRaidDanhSach.self, "/work/projects/7/raid")
        XCTAssertEqual(ds.matrix?.count, 5)
        XCTAssertEqual(ds.matrix?[2][4], 1, "R-3: xác suất 3, tác động 5")
        XCTAssertEqual(ds.matrix?.flatMap { $0 }.reduce(0, +), 4, "rủi ro đã đóng không vào ma trận")
        XCTAssertEqual(ds.counts?["RISK"]?.open, 4)
        XCTAssertEqual(ds.items?.first { $0.number == 3 }?.level, "HIGH")
        let r = try giai(CTWRaid.self, "/work/projects/7/raid/3")
        XCTAssertEqual(r.history?.first?.actor?.laAgent, true)
        XCTAssertEqual(r.links?.last?.changeRequest?.number, 5)
        XCTAssertEqual(r.statuses?.count, 4)
        XCTAssertEqual(r.nhanKhoa, "R-3")
    }

    func testLuatRaid() {
        XCTAssertEqual(CTWRaidLuat.diem(3, 5), 15)
        XCTAssertNil(CTWRaidLuat.diem(nil, 5))
        XCTAssertNil(CTWRaidLuat.diem(6, 1))
        XCTAssertEqual(CTWRaidLuat.muc(15), "HIGH")
        XCTAssertEqual(CTWRaidLuat.muc(14), "MEDIUM")
        XCTAssertEqual(CTWRaidLuat.muc(8), "MEDIUM")
        XCTAssertEqual(CTWRaidLuat.muc(7), "LOW")
        XCTAssertEqual(CTWRaidLuat.trangThai(cho: "ASSUMPTION"), ["UNVALIDATED", "VALIDATED", "INVALID"])
        XCTAssertEqual(CTWRaidLuat.trangThai(cho: "QUESTION"), ["OPEN", "ANSWERED", "CANCELLED"])
        XCTAssertEqual(CTWRaidLuat.trangThai(cho: "DEPENDENCY"), ["OPEN", "MONITORING", "MITIGATED", "CLOSED"])
        XCTAssertEqual(CTWRaidLuat.macDinh(cho: "ASSUMPTION"), "UNVALIDATED")
        XCTAssertEqual(CTWRaidLuat.khoa("DEPENDENCY", 4), "D-4")
    }

    func testReview() throws {
        let ds = try giai([CTWReviewHang].self, "/work/projects/7/reviews")
        XCTAssertEqual(ds.count, 2)
        XCTAssertEqual(ds.first?.participants, 4, "danh sách: participants là SỐ")
        let r = try giai(CTWReview.self, "/work/projects/7/reviews/2")
        XCTAssertEqual(r.participants?.count, 4, "chi tiết: participants là MẢNG")
        XCTAssertEqual(r.participants?.last?.user?.laAgent, true)
        XCTAssertEqual(r.theoPhan.map(\.phan), ["Completeness", "Consistency", "Verifiability"])
        XCTAssertEqual(r.items?.first { $0.id == 2 }?.defect?.key, "NW-15")
        XCTAssertTrue(r.suaDuoc)
        XCTAssertEqual(r.next, ["REWORK", "CLOSED"])
        // `line` chữ hoặc số đều giải mã được.
        let m = try JSONDecoder().decode(CTWReviewMuc.self, from: Data(#"{"id":1,"line":42}"#.utf8))
        XCTAssertEqual(m.line?.chu, "42")
    }

    func testLuatReview() {
        XCTAssertEqual(CTWReviewLuat.ke(tu: "PLANNING"), ["PREPARATION"])
        XCTAssertEqual(CTWReviewLuat.ke(tu: "MEETING"), ["REWORK", "CLOSED"])
        XCTAssertEqual(CTWReviewLuat.ke(tu: "FOLLOW_UP"), ["CLOSED", "REWORK"])
        XCTAssertEqual(CTWReviewLuat.ke(tu: "CLOSED"), [])
    }

    func testDangKyMoDunGovernance() {
        for id in ["approvals", "changes", "raid", "reviews"] {
            let m = CTWDangKyMoDun.moDun(id)
            XCTAssertNotNil(m, id)
            XCTAssertEqual(m?.nhom, .quanLy, id)
            XCTAssertEqual(m?.doanWeb, id)
        }
    }
}
