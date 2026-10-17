import XCTest
@testable import CTWork

/// Mảng Yêu cầu: giải mã dữ liệu mẫu (hình dạng backend) bằng model thật + logic thuần
/// (tách luồng UC thành bước, ma trận phân quyền màn, vòng đời yêu cầu Wiegers).
final class RequirementsCTWTests: XCTestCase {
    private func giai<T: Decodable>(_ kieu: T.Type, _ path: String, method: String = "GET",
                                    file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let d = DuLieuGia.traLoi(method: method, path: "/api/v1" + path, body: [:])
        let r = try JSONDecoder().decode(APIResponse<T>.self, from: d)
        XCTAssertTrue(r.success, file: file, line: line)
        return try XCTUnwrap(r.data, file: file, line: line)
    }

    func testGiaiMaSrs() throws {
        let d = try giai(CTWSrsData.self, "/work/projects/7/srs")
        XCTAssertEqual(d.useCases?.count, 4)
        let uc1 = try XCTUnwrap(d.useCases?.first { $0.number == 1 })
        XCTAssertEqual(uc1.ma, "UC-01")
        XCTAssertEqual(uc1.issue?.number, 12)
        XCTAssertEqual(d.actor(uc1.primaryActorId)?.name, "Team member")
        XCTAssertEqual(d.rule(2)?.ma, "BR-02")
        XCTAssertNotNil(d.useCases?.first { $0.number == 6 }?.aiModel, "UC do AI soạn phải mang aiModel để gắn nhãn")
        XCTAssertEqual(d.ucTheoTinhNang.map(\.tinhNang), ["Accounts", "Issues", "Notifications", "Reports"])
    }

    func testMaTranPhanQuyenVaLienKetMan() throws {
        let d = try giai(CTWSrsData.self, "/work/projects/7/srs")
        XCTAssertEqual(d.actorsCho(screen: 4).map(\.id), [2], "chỉ trưởng nhóm vào màn báo cáo")
        XCTAssertTrue(d.duocVao(screen: 1, actor: 1))
        XCTAssertFalse(d.duocVao(screen: 4, actor: 1))
        XCTAssertEqual(d.diToi(tu: 2).map(\.screen.id).sorted(), [3, 4])
        XCTAssertEqual(d.diToi(tu: 1).first?.nhan, "signed in")
        XCTAssertEqual(d.diTu(den: 2).map(\.id), [1])
        // Ô hỏng (không đủ 2 số) không làm sập tra cứu.
        var hong = d
        hong.auth = [[1], [4, 1, 9]]
        XCTAssertTrue(hong.actorsCho(screen: 4).isEmpty)
    }

    func testTachLuongUC() {
        let b = CTWLuongUC.tach("1. Open the app.\n2. Choose sign in\n\n   continued line\n2A. Forgot password\n2A.1. Send link\n3) Verify\n- 4. Show My Work")
        XCTAssertEqual(b.map(\.nhan), ["1", "2", nil, "2A", "2A.1", "3", "4"])
        XCTAssertEqual(b[0].chu, "Open the app.")
        XCTAssertFalse(b[1].laNhanh)
        XCTAssertTrue(b[3].laNhanh)
        XCTAssertTrue(b[4].laNhanh)
        XCTAssertEqual(b[5].chu, "Verify")
        XCTAssertEqual(b[6].chu, "Show My Work")
        // Không đánh số / số nằm trong chữ ⇒ dòng thường.
        XCTAssertNil(CTWLuongUC.tach("10am stand-up happens daily").first?.nhan)
        XCTAssertNil(CTWLuongUC.tach("The user signs in").first?.nhan)
        XCTAssertTrue(CTWLuongUC.tach(nil).isEmpty)
    }

    func testRtm() throws {
        let r = try giai(CTWRtmData.self, "/work/projects/7/rtm")
        XCTAssertEqual(r.rows?.count, 3)
        XCTAssertEqual(r.summary?.withGaps, 2)
        XCTAssertEqual(r.rows?.first?.soCaKiem, 7, "6 ca unit + 1 Xray")
        XCTAssertEqual(r.gapLabels?["NO_TEST"], "No tests")
    }

    func testWiegersGiaiMa() throws {
        let y = try giai(CTWSwrRequirementList.self, "/work/projects/7/swr/requirements")
        XCTAssertEqual(y.requirements?.count, 5)
        XCTAssertEqual(y.counts?.byLifecycle?["PROPOSED"], 2)
        XCTAssertNil(y.requirements?.last?.reqType, "chưa phân loại ⇒ null")
        _ = try giai([CTWSwrHistoryRow].self, "/work/projects/7/swr/requirements/31/history")
        let f = try giai(CTWSwrFeatureList.self, "/work/projects/7/swr/features")
        XCTAssertEqual(f.features?.filter { $0.scope == "OUT" }.count, 1)
        let s = try giai(CTWSwrStakeholderList.self, "/work/projects/7/swr/stakeholders")
        XCTAssertEqual(s.stakeholders?.first?.quadrant, "MANAGE_CLOSELY")
        let g = try giai(CTWSwrGlossary.self, "/work/projects/7/swr/glossary")
        XCTAssertEqual(g.terms?.first?.aliases, ["Card", "Ticket"])
        let ss = try giai(CTWSwrSessions.self, "/work/projects/7/swr/elicitation")
        XCTAssertEqual(ss.sessions?.count, 2)
        let sd = try giai(CTWSwrSessionDetail.self, "/work/projects/7/swr/elicitation/2")
        XCTAssertEqual(sd.proposals?.count, 2)
        XCTAssertNil(sd.questions?.last?.answer)
        let n = try giai(CTWSwrNfr.self, "/work/projects/7/swr/nfr")
        XCTAssertEqual(n.requirements?.first?.spec?.planValue, 2)
        let m = try giai(CTWSwrMockups.self, "/work/projects/7/swr/mockups")
        XCTAssertEqual(m.counts?.withPrototype, 2)
    }

    func testVongDoiYeuCau() throws {
        XCTAssertTrue(CTWVongDoiYeuCau.diDuoc("PROPOSED", "APPROVED"))
        XCTAssertFalse(CTWVongDoiYeuCau.diDuoc("PROPOSED", "VERIFIED"))
        XCTAssertTrue(CTWVongDoiYeuCau.diDuoc("IMPLEMENTED", "APPROVED"), "thực thi bị trả lại")
        XCTAssertTrue(CTWVongDoiYeuCau.diDuoc("REJECTED", "PROPOSED"))
        XCTAssertTrue(CTWVongDoiYeuCau.diDuoc(nil, "REJECTED"), "chưa có hồ sơ ⇒ coi là PROPOSED")
        let y = try giai(CTWSwrRequirementList.self, "/work/projects/7/swr/requirements")
        let r = try XCTUnwrap(y.requirements?.first { $0.number == 34 }) // IMPLEMENTED
        // Người chỉ sửa được (không duyệt được) — chỉ thấy đường không cần duyệt.
        XCTAssertEqual(CTWVongDoiYeuCau.nutHien(r, canEdit: true, canApprove: false), [])
        XCTAssertEqual(CTWVongDoiYeuCau.nutHien(r, canEdit: true, canApprove: true), ["VERIFIED", "APPROVED", "DELETED"])
        var mo = r
        mo.lifecycle = "REJECTED"; mo.next = nil
        XCTAssertEqual(CTWVongDoiYeuCau.nutHien(mo, canEdit: true, canApprove: false), ["PROPOSED"], "mở lại = người sửa được")
        XCTAssertEqual(CTWVongDoiYeuCau.nutHien(mo, canEdit: false, canApprove: true), [])
    }

    func testDeXuatTraVeDungHinh() throws {
        _ = try giai(CTWSrsUseCase.self, "/work/projects/7/srs/use-cases", method: "POST")
        _ = try giai(CTWSrsTaoKetQua.self, "/work/projects/7/swr/elicitation/2/proposals", method: "POST")
    }

    func testDangKyMoDunYeuCau() throws {
        XCTAssertNotNil(CTWDangKyMoDun.moDun("requirements"))
        XCTAssertNotNil(CTWDangKyMoDun.moDun(choDoan: "wiegers"))
    }

    @MainActor
    func testAnVoiKhach() throws {
        let khach = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(#"{"id":1,"key":"A","name":"A","role":"CLIENT"}"#.utf8))
        let thanhVien = try JSONDecoder().decode(CTWProjectConfig.self, from: Data(#"{"id":1,"key":"A","name":"A","role":"MEMBER"}"#.utf8))
        XCTAssertFalse(CTWModule.requirements.hien(khach))
        XCTAssertFalse(CTWModule.wiegers.hien(khach))
        XCTAssertTrue(CTWModule.requirements.hien(thanhVien))
    }
}
