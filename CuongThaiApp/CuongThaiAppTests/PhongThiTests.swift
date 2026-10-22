import XCTest
@testable import CuongThaiApp

/// Phòng thi — giải mã khoan dung, đầu đề PE, bộ ghi .zip, thân multipart.
///
/// Mẫu JSON: danh sách đề và đầu đề PE là bản THẬT lấy từ production
/// (`curl https://cuongthai.com/api/v1/exams`, `/exams/course/programming-fundamentals`,
/// 22/10/2026, cắt bớt); bản xem lại dựng tay đúng hình `buildReview` của
/// `exam.service.ts` (cần đăng nhập nên không lấy thật được).
final class PhongThiTests: XCTestCase {

    private func giai<T: Decodable>(_ kieu: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: Danh sách đề (thật)

    func testDanhSachDeThat() throws {
        let json = #"""
        {"success": true, "data": [{"id": 384, "courseId": 1, "kind": "FE", "peType": null, "title": "Đề 13 — Final Exam (SP25-RE)|||Đề 13 — Thi cuối kỳ (SP25-RE)", "code": "D13", "durationMinutes": 60, "totalPoints": 10, "passMark": 5, "questionCount": 50, "course": {"title": "Programming Fundamentals", "slug": "programming-fundamentals", "courseCode": "PRF192"}, "semester": {"name": "Kỳ 1", "ordinal": 1, "code": "KY1"}}, {"id": 399, "courseId": 1, "kind": "FE", "peType": null, "title": "Đề 28 — Final Exam (REB5-FA23)|||Đề 28 — Thi cuối kỳ (REB5-FA23)", "code": "D28", "durationMinutes": 60, "totalPoints": 10, "passMark": 5, "questionCount": 25, "course": {"title": "Programming Fundamentals", "slug": "programming-fundamentals", "courseCode": "PRF192"}, "semester": {"name": "Kỳ 1", "ordinal": 1, "code": "KY1"}}]}
        """#
        let r = try giai(APIResponse<[DeThi]>.self, json)
        let ds = try XCTUnwrap(r.data)
        XCTAssertEqual(ds.count, 2)
        XCTAssertEqual(ds[0].maMon, "PRF192")
        XCTAssertEqual(ds[0].ten(.viet), "Đề 13 — Thi cuối kỳ (SP25-RE)")
        XCTAssertFalse(ds[0].laPE)
        XCTAssertNil(ds[0].source, "GET /exams không trả source — trường phải optional")
        XCTAssertEqual(ds[0].kyThi?.ten, "Spring 2025")
    }

    // MARK: Đầu đề PE (/take, /course/:slug)

    static let dauDePE = #"""
    {"id": 2, "courseId": 1, "kind": "PE", "peType": "CODE", "title": "Practical Exam — C Programming (FA25, Paper 3)|||Thi thực hành — Lập trình C (FA25, Đề 3)", "description": "Real PE paper.|||Đề PE thật.", "code": "PE-FA25-P3", "durationMinutes": 90, "totalPoints": 10, "passMark": 4, "source": "REAL", "instructions": "<div class=\"ml-en\"><p><b>How to take this exam:</b></p></div><div class=\"ml-vi\"><p>Cách làm bài</p></div>", "attachmentUrl": "/exam-assets/PRF192-given.zip", "attachmentName": "Given — starter files (Q1.c … Q8.c)|||Given — file cho sẵn (Q1.c … Q8.c)", "isPublished": true, "sortOrder": 0, "questionCount": 8, "my": %MY%, "questions": %Q%}
    """#

    func testDauDePE_take() throws {
        let q = #"""
        [{"id": 11, "kind": "CODE", "sortOrder": 1, "points": 2.5, "prompt": "Q1", "imageUrl": null, "options": null, "selectCount": 1, "multiSelect": false, "language": "c", "starterCode": "int main(){}", "expectedOutput": "ODD", "speakingPrompts": null},
         {"id": 12, "kind": "CODE", "sortOrder": 2, "points": 2.5, "prompt": "Q2", "imageUrl": null, "options": null, "selectCount": 1, "multiSelect": false, "language": null, "starterCode": null, "expectedOutput": null, "speakingPrompts": null}]
        """#
        let my = #"{"attempts": 2, "bestScore": 7.5, "lastScore": 6, "passed": true, "lastAttemptId": 90, "inProgressId": null, "aiInProgressId": 91}"#
        let json = Self.dauDePE.replacingOccurrences(of: "%Q%", with: q).replacingOccurrences(of: "%MY%", with: my)
        let de = try giai(DeDangLam.self, json)
        XCTAssertTrue(de.laPE)
        XCTAssertEqual(de.loaiPE, "CODE")
        XCTAssertTrue(de.laDeThat)
        XCTAssertEqual(de.attachmentUrl, "/exam-assets/PRF192-given.zip")
        XCTAssertTrue(de.instructions?.contains("ml-en") ?? false)
        XCTAssertEqual(de.my?.soLan, 2)
        XCTAssertEqual(de.my?.aiInProgressId, 91)
        XCTAssertTrue(de.toanCode)
        XCTAssertEqual(de.questions[0].expectedOutput, "ODD")
        XCTAssertEqual(DuongDanThi.day(de.attachmentUrl)?.absoluteString, APIClient.diaChiGoc + "/exam-assets/PRF192-given.zip")
    }

    func testDauDeCuThieuTruongMoi() throws {
        // Đề cũ / máy chủ cũ: chỉ 6 trường như bản đầu — vẫn phải giải mã được.
        let json = #"{"id": 5, "title": "Old", "durationMinutes": 60, "totalPoints": 10, "passMark": 5, "questions": [{"id": 1, "kind": "MCQ", "prompt": "x", "options": [{"text": "a"}, {"text": "b"}]}]}"#
        let de = try giai(DeDangLam.self, json)
        XCTAssertFalse(de.laPE)
        XCTAssertNil(de.instructions)
        XCTAssertNil(de.my)
        XCTAssertEqual(de.questions[0].options?.map(\.text), ["a", "b"])
    }

    func testCauNoiPhuNhanCaChuoiLanDoiTuong() throws {
        let json = #"{"id": 7, "kind": "SPEAK", "prompt": "Talk", "speakingPrompts": [{"text": "Q1", "imageUrl": "/a.png"}, "Q2", {"x": 1}]}"#
        let c = try giai(CauHoiThi.self, json)
        XCTAssertTrue(c.laNoi)
        XCTAssertEqual(c.speakingPrompts?.map(\.text), ["Q1", "Q2", ""])
        XCTAssertEqual(c.speakingPrompts?.first?.imageUrl, "/a.png")
    }

    // MARK: Bản xem lại — phương án THÔ (chuỗi lẫn đối tượng)

    static let xemLaiJSON = #"""
    {"attempt": {"id": 77, "examId": 384, "status": "GRADED", "startedAt": "2026-10-22T08:00:00.000Z", "submittedAt": "2026-10-22T08:41:12.000Z", "timeSpentSeconds": 2472, "score": 6.5, "maxScore": 10, "passed": true, "gradingMode": "AUTO",
      "feedback": {"correctCount": 1, "total": 2, "perQuestion": [
        {"questionId": 1, "points": 1, "correct": true, "selected": [1]},
        {"questionId": 2, "points": 1, "correct": false, "selected": [0]},
        {"points": 5, "note": "dòng hỏng — thiếu questionId"},
        {"questionId": 3, "points": 2, "kind": "CODE", "grade": {"score": "1.5", "maxScore": 2, "percent": 75, "verdict": "good", "summary": "OK|||Ổn", "criteria": [{"id": 1, "name": "Correctness", "score": 1.2, "maxScore": "1.4", "comment": "fine"}, "rác"], "suggestions": ["A|||B", 42]}},
        {"questionId": 4, "points": 2, "kind": "CODE", "ungraded": true}
      ]}},
     "exam": {"id": 384, "courseId": 1, "kind": "FE", "peType": null, "title": "T", "description": null, "code": "D13", "durationMinutes": 60, "totalPoints": 10, "passMark": 5, "source": "REAL", "instructions": null, "attachmentUrl": null, "attachmentName": null, "isPublished": true, "sortOrder": 0},
     "examBookmarked": true,
     "questions": [
      {"id": 1, "kind": "MCQ", "sortOrder": 1, "points": 1, "prompt": "p1", "imageUrl": null, "options": ["<stdlib.h>", "<stdio.h>", 3], "correctIndexes": [1], "explanation": "e", "myAnswer": [1], "bookmarked": true, "bookmarkNote": "n"},
      {"id": 2, "kind": "MCQ", "sortOrder": 2, "points": 1, "prompt": "p2", "imageUrl": null, "options": [{"text": "2"}, {"text": "1"}], "correctIndexes": [1], "explanation": null, "myAnswer": [0], "bookmarked": false},
      {"id": 3, "kind": "CODE", "sortOrder": 3, "points": 2, "prompt": "p3", "imageUrl": null, "options": null, "correctIndexes": [], "language": "c", "starterCode": null, "sampleSolution": "int main(){}", "expectedOutput": "9", "rubric": [{"criterion": "x"}], "speakingPrompts": null, "myAnswer": "int main(){ }", "bookmarked": false},
      {"id": 4, "kind": "WRITE", "sortOrder": 4, "points": 2, "prompt": "p4", "imageUrl": null, "options": null, "correctIndexes": [], "myAnswer": {"essays": {"4": "x"}}, "bookmarked": false}
     ]}
    """#

    func testXemLaiPhuongAnChuoiTranVaDoiTuong() throws {
        let x = try giai(XemLaiBaiThi.self, Self.xemLaiJSON)
        XCTAssertEqual(x.questions.count, 4)
        XCTAssertEqual(x.questions[0].options?.map(\.text), ["<stdlib.h>", "<stdio.h>", "3"])
        XCTAssertEqual(x.questions[1].options?.map(\.text), ["2", "1"])
        XCTAssertTrue(x.questions[0].lamDung)
        XCTAssertFalse(x.questions[1].lamDung)
        XCTAssertEqual(x.questions[2].myAnswer?.chu, "int main(){ }")
        XCTAssertTrue(x.questions[3].boTrong, "myAnswer là đối tượng lạ ⇒ coi như trống, KHÔNG ném lỗi")
        XCTAssertFalse(x.laPE)
        XCTAssertEqual(x.soDung, 1)
    }

    func testChamTungCauKhoanDung() throws {
        let x = try giai(XemLaiBaiThi.self, Self.xemLaiJSON)
        let pq = try XCTUnwrap(x.attempt.feedback?.perQuestion)
        XCTAssertEqual(pq.count, 4, "dòng thiếu questionId bị bỏ, phần còn lại giữ nguyên")
        let g = try XCTUnwrap(x.cham(3)?.grade)
        XCTAssertEqual(g.score, 1.5, accuracy: 0.001, "điểm dạng chuỗi vẫn đọc được")
        XCTAssertEqual(g.criteria.count, 1, "tiêu chí rác bị bỏ")
        XCTAssertEqual(g.criteria[0].maxScore, 1.4, accuracy: 0.001)
        XCTAssertEqual(g.criteria[0].id, "1")
        XCTAssertEqual(g.suggestions, ["A|||B"])
        XCTAssertEqual(g.nhanKetLuan, "Tốt")
        XCTAssertEqual(x.cham(4)?.khongCham, true)
        XCTAssertNil(x.cham(4)?.grade)
    }

    func testCauDaLuuPhuongAnChuoi() throws {
        let json = #"""
        [{"id": 1, "note": null, "createdAt": "2026-10-01T00:00:00.000Z", "questionId": 9, "examId": 2,
          "question": {"id": 9, "kind": "MCQ", "points": 1, "prompt": "q", "imageUrl": null, "options": ["A", "B"], "correctIndexes": [0], "explanation": null, "language": null, "sampleSolution": null, "expectedOutput": null},
          "exam": {"id": 2, "kind": "FE", "peType": null, "title": "T", "code": "C", "courseId": 1},
          "course": {"title": "PF", "slug": "pf", "courseCode": "PRF192"},
          "semester": {"name": "Kỳ 1", "ordinal": 1, "code": "KY1"}}]
        """#
        let ds = try giai([CauHoiDaLuu].self, json)
        XCTAssertEqual(ds.first?.question.options?.map(\.text), ["A", "B"])
        XCTAssertEqual(ds.first?.maMon, "PRF192")
    }

    func testMangKhoanBoPhanTuHong() throws {
        let m = try giai(MangKhoan<Int>.self, #"[1, "x", 2, null, {"a":1}, 3]"#)
        XCTAssertEqual(m.phanTu, [1, 2, 3])
    }

    // MARK: ZIP

    func testCRC32() {
        XCTAssertEqual(CRC32.tinh(Data("hello".utf8)), 0x3610A686)
        XCTAssertEqual(CRC32.tinh(Data()), 0)
    }

    func testZipCauTruc() throws {
        let a = Data("#include <stdio.h>\nint main(){}\n".utf8)
        let b = Data("print('xin chào')\n".utf8)
        let zip = ZipDon.dongGoi([.init(ten: "Q1.c", duLieu: a), .init(ten: "Q2.py", duLieu: b),
                                  .init(ten: "Q1.c", duLieu: b)], luc: Date(timeIntervalSince1970: 1_761_120_000))
        let u = [UInt8](zip)
        func u16(_ i: Int) -> Int { Int(u[i]) | Int(u[i + 1]) << 8 }
        func u32(_ i: Int) -> UInt32 { UInt32(u[i]) | UInt32(u[i + 1]) << 8 | UInt32(u[i + 2]) << 16 | UInt32(u[i + 3]) << 24 }
        XCTAssertEqual(u32(0), 0x04034B50, "bắt đầu bằng local file header")
        // EOCD ở 22 byte cuối (không có chú thích).
        let e = u.count - 22
        XCTAssertEqual(u32(e), 0x06054B50)
        XCTAssertEqual(u16(e + 10), 3, "3 mục")
        let cdOffset = Int(u32(e + 16)), cdSize = Int(u32(e + 12))
        XCTAssertEqual(cdOffset + cdSize, e)
        // Đọc lại thư mục trung tâm: tên + CRC + vị trí phải khớp dữ liệu thật.
        var p = cdOffset
        var ten: [String] = []
        for _ in 0..<3 {
            XCTAssertEqual(u32(p), 0x02014B50)
            XCTAssertEqual(u16(p + 10), 0, "STORED")
            let crc = u32(p + 16), co = Int(u32(p + 20)), dt = u16(p + 28), lh = Int(u32(p + 42))
            let n = String(decoding: u[(p + 46)..<(p + 46 + dt)], as: UTF8.self)
            ten.append(n)
            let tl = u16(lh + 26), ex = u16(lh + 28)
            let duLieu = Data(u[(lh + 30 + tl + ex)..<(lh + 30 + tl + ex + co)])
            XCTAssertEqual(CRC32.tinh(duLieu), crc, "CRC của \(n)")
            p += 46 + dt
        }
        XCTAssertEqual(ten, ["Q1.c", "Q2.py", "Q1-2.c"], "tên trùng được đổi, không ghi đè")
    }

    func testDongGoiBoCauTrong() throws {
        let c1 = try giai(CauHoiThi.self, #"{"id": 1, "kind": "CODE", "prompt": "a", "language": "java"}"#)
        let c2 = try giai(CauHoiThi.self, #"{"id": 2, "kind": "CODE", "prompt": "b", "language": "c"}"#)
        XCTAssertNil(TepMaNguon.dongGoi(cau: [c1, c2], ma: [1: "  \n", 2: ""]))
        let z = try XCTUnwrap(TepMaNguon.dongGoi(cau: [c1, c2], ma: [2: "int main(){}"]))
        XCTAssertTrue(String(decoding: z, as: UTF8.self).contains("Q2.c"), "đánh số theo thứ tự câu, câu 1 bỏ trống không có tệp")
        XCTAssertEqual(TepMaNguon.ten(thuTu: 3, ngonNgu: "Python"), "Q3.py")
        XCTAssertEqual(TepMaNguon.ten(thuTu: 1, ngonNgu: "lisp"), "Q1.txt")
    }

    // MARK: Multipart

    func testThanNhieuPhan() {
        var t = ThanNhieuPhan(ranhGioi: "B")
        t.them(truong: "essays", giaTri: #"{"4":"hi"}"#)
        t.them(tep: "image_4", tenTep: "so\"do.jpg", kieu: "image/jpeg", duLieu: Data([0xFF, 0xD8]))
        t.them(truong: "timeSpentSeconds", giaTri: "61")
        t.dong()
        let mong = Data(("--B\r\nContent-Disposition: form-data; name=\"essays\"\r\n\r\n{\"4\":\"hi\"}\r\n"
            + "--B\r\nContent-Disposition: form-data; name=\"image_4\"; filename=\"so%22do.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n").utf8)
            + Data([0xFF, 0xD8])
            + Data("\r\n--B\r\nContent-Disposition: form-data; name=\"timeSpentSeconds\"\r\n\r\n61\r\n--B--\r\n".utf8)
        XCTAssertEqual(t.duLieu, mong)
        XCTAssertEqual(t.kieuNoiDung, "multipart/form-data; boundary=B")
    }

    // MARK: Endpoint mới

    func testEndpointPhongThi() {
        XCTAssertEqual(APIEndpoint.dsDeThiTheoMon(khoaHoc: "programming-fundamentals").path, "/api/v1/exams/course/programming-fundamentals")
        XCTAssertEqual(APIEndpoint.xoaLuotThi(attemptId: 5).method, "DELETE")
        XCTAssertEqual(APIEndpoint.hoiCuongMiniLuyen(questionId: 9, than: [:]).path, "/api/v1/exams/practice/questions/9/ai/ask")
        XCTAssertEqual(APIEndpoint.luyenChuongThucHanh(sectionId: 3).queryParams?["limit"] as? Int, 50)
        let b = APIEndpoint.nopBaiThiFE(attemptId: 1, dapAn: ["1": [0]], maCode: ["2": "x"], giay: 9,
                                        tinHieu: ["blurCount": 2, "auto": false]).body
        XCTAssertNotNil(b?["codeAnswers"])
        XCTAssertEqual((b?["integritySignals"] as? [String: Any])?["blurCount"] as? Int, 2)
        // Đường LUYỆN có `/ai/` ⇒ chốt đồng ý AI bắt được.
        XCTAssertTrue(DongYChiaSeAI.laDuongAI(method: "POST", path: "/api/v1/exams/practice/questions/9/ai/ask"))
    }

    func testTheHTMLThatVaGia() {
        XCTAssertFalse("<stdio.h>".coTheHTMLThat)
        XCTAssertFalse("#include <iostream>".coTheHTMLThat)
        XCTAssertFalse("List<String> a = new ArrayList<>();".canDungGiau)
        XCTAssertTrue("<p>x</p>".coTheHTMLThat)
        XCTAssertTrue("a<br/>b".coTheHTMLThat)
        XCTAssertTrue("<code class=\"language-c\">x</code>".canDungGiau)
    }

    func testCauVeSoDo() {
        XCTAssertTrue(CauVeSoDo.la("Draw a Use Case Diagram for the system"))
        XCTAssertTrue(CauVeSoDo.la("Conceptual ERD"))
        XCTAssertFalse(CauVeSoDo.la("Describe the diagrammatic approach"))
    }
}
