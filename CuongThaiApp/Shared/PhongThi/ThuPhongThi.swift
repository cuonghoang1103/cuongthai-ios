#if DEBUG
import SwiftUI

// ════════════════════════════════════════════════════════════════
// BÀN THỬ PHÒNG THI — chỉ bản DEBUG (`CT_XEM_MAN=thi-<kiểu>`)
//
// `/take` và mọi đường nộp bài cần đăng nhập, mà Claude không gõ mật khẩu.
// Nên: phần ĐẦU ĐỀ (tên, hướng dẫn HTML, tệp "Given", loại đề) lấy THẬT từ
// `GET /exams/course/:slug` (công khai), còn câu hỏi là mẫu dựng tay đúng
// hình dạng `questionForTaking` của máy chủ. Không nộp gì lên máy chủ.
//
//   thi-fe       đề FE trắc nghiệm (PRF192) + một câu code kiểu đề tiến độ
//   thi-code     đề PE CODE thật (PRF192 FA25 P3) — hướng dẫn + Given + ô mã
//   thi-viet     đề PE WRITE thật (FER202) — bài viết + ảnh sơ đồ
//   thi-noi      đề PE SPEAK thật (JPD) — thu âm từng câu
//   thi-chitiet  màn trước khi thi của đề PE CODE
//   thi-xemlai   xem lại: FE (phương án dạng CHUỖI TRẦN) + PE có bài chấm AI
//   thi-ketqua   màn kết quả
//   thi-mon      đề theo môn (PRF192)
// ════════════════════════════════════════════════════════════════

struct ThuPhongThi: View {
    let kieu: String
    @State private var de: DeDangLam?
    @State private var goc: DeThi?
    @State private var loi: String?

    var body: some View {
        Group {
            switch kieu {
            case "thi-mon":
                DeThiTheoMonView(khoaHoc: "programming-fundamentals", ten: "Programming Fundamentals", maMon: "PRF192")
            case "thi-xemlai":
                XemLaiView(xemLai: MauThi.xemLai, tenDe: "Đề 13 — Final Exam (SP25-RE)|||Đề 13 — Thi cuối kỳ (SP25-RE)",
                           baiDaNop: [9002: "#include <stdio.h>\nint main(){\n    int n; scanf(\"%d\", &n);\n    printf(\"%d\", n*n);\n}"])
            case "thi-ketqua":
                KetQuaView(kq: MauThi.xemLai, de: DeThi.toiGian(id: 384, title: "Đề 13 — Final Exam (SP25-RE)|||Đề 13 — Thi cuối kỳ (SP25-RE)", code: "D13")) { }
            default:
                if let de, let goc {
                    if kieu == "thi-chitiet" {
                        ChiTietDeView(de: goc)
                    } else {
                        LamBaiView(xemThu: de, luot: LuotThi(attemptId: 1, startedAt: nil,
                                                             expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval((de.durationMinutes ?? 60) * 60 - 754))),
                                                             resumed: false, aiAssisted: false),
                                   deGoc: goc, viTri: kieu == "thi-fe" ? 2 : 0,
                                   chon: kieu == "thi-fe" ? [101: [1], 102: [0, 2]] : [:],
                                   co: kieu == "thi-fe" ? [103] : [],
                                   maCode: kieu == "thi-code" ? [201: MauThi.maQ1] : [:],
                                   baiViet: kieu == "thi-viet" ? [301: MauThi.baiViet] : [:])
                    }
                } else if let loi {
                    ErrorStateView(message: loi)
                } else {
                    ProgressView()
                }
            }
        }
        .task { await nap() }
    }

    private func nap() async {
        let (slug, examId, cau): (String, Int, [[String: Any]]) = {
            switch kieu {
            case "thi-code", "thi-chitiet": return ("programming-fundamentals", 2, MauThi.cauCode)
            case "thi-viet": return ("front-end-web-development-with-react", 314, MauThi.cauViet)
            case "thi-noi": return ("elementary-japanese-1-a11", 70, MauThi.cauNoi)
            default: return ("programming-fundamentals", 384, MauThi.cauFE)
            }
        }()
        guard kieu != "thi-mon", kieu != "thi-xemlai", kieu != "thi-ketqua" else { return }
        do {
            let raw = try await APIClient.shared.requestRaw(.dsDeThiTheoMon(khoaHoc: slug))
            guard let goc = (try JSONSerialization.jsonObject(with: raw) as? [String: Any])?["data"] as? [[String: Any]],
                  var dau = goc.first(where: { ($0["id"] as? Int) == examId }) ?? goc.first else {
                loi = "Không thấy đề mẫu"; return
            }
            dau["questions"] = cau
            dau["my"] = NSNull()
            let d = try JSONSerialization.data(withJSONObject: dau)
            de = try JSONDecoder().decode(DeDangLam.self, from: d)
            var dauGoc = dau
            dauGoc["questionCount"] = cau.count
            dauGoc["course"] = ["title": slug == "programming-fundamentals" ? "Programming Fundamentals" : slug,
                                "slug": slug,
                                "courseCode": slug == "programming-fundamentals" ? "PRF192" : (slug.contains("japanese") ? "JPD113" : "FER202")]
            dauGoc["semester"] = ["name": "Kỳ 1", "ordinal": 1, "code": "KY1"]
            self.goc = try JSONDecoder().decode(DeThi.self, from: JSONSerialization.data(withJSONObject: dauGoc))
        } catch { loi = error.localizedDescription }
    }
}

enum MauThi {
    static let maQ1 = "#include <stdio.h>\n\nint main() {\n    int n;\n    scanf(\"%d\", &n);\n    if (n % 2 == 0) {\n        printf(\"EVEN\");\n    } else {\n        printf(\"ODD\");\n    }\n    return 0;\n}\n"

    static let baiViet = "The Product List page fetches /products with axios inside useEffect, stores the array in state and renders a Bootstrap Card per item. Clicking Detail navigates to /products/:id using React Router."

    static let cauFE: [[String: Any]] = [
        ["id": 101, "kind": "MCQ", "sortOrder": 1, "points": 1,
         "prompt": "What is the output of the following code?<pre><code class=\"language-c\">int x = 5;\nprintf(\"%d\", x++ + ++x);</code></pre>|||Đoạn mã sau in ra gì?<pre><code class=\"language-c\">int x = 5;\nprintf(\"%d\", x++ + ++x);</code></pre>",
         "options": [["text": "10"], ["text": "12"], ["text": "11"], ["text": "Undefined behavior|||Hành vi không xác định"]],
         "selectCount": 1, "multiSelect": false],
        ["id": 102, "kind": "MCQ", "sortOrder": 2, "points": 1,
         "prompt": "Which of the following are valid C storage classes? (Choose 2)|||Những lớp lưu trữ nào hợp lệ trong C? (Chọn 2)",
         "options": [["text": "auto"], ["text": "dynamic"], ["text": "register"], ["text": "global"]],
         "selectCount": 2, "multiSelect": true],
        ["id": 103, "kind": "MCQ", "sortOrder": 3, "points": 1,
         "prompt": "Which loop is guaranteed to execute its body at least once?|||Vòng lặp nào chắc chắn chạy thân ít nhất một lần?",
         "options": [["text": "for"], ["text": "while"], ["text": "do … while"], ["text": "None of the above|||Không có cái nào"]],
         "selectCount": 1, "multiSelect": false],
        ["id": 104, "kind": "CODE", "sortOrder": 4, "points": 2, "language": "c",
         "prompt": "Write a program that reads n and prints the sum 1 + 2 + … + n.|||Viết chương trình đọc n và in tổng 1 + 2 + … + n.",
         "starterCode": "#include <stdio.h>\n\nint main() {\n    \n    return 0;\n}\n",
         "expectedOutput": "Input: 4\nOutput: 10", "selectCount": 1, "multiSelect": false],
    ] + (5...30).map { i in
        ["id": 100 + i, "kind": "MCQ", "sortOrder": i, "points": 1,
         "prompt": "Sample question \(i)|||Câu mẫu \(i)",
         "options": [["text": "A"], ["text": "B"], ["text": "C"], ["text": "D"]],
         "selectCount": 1, "multiSelect": false] as [String: Any]
    }

    static let cauCode: [[String: Any]] = [
        ["id": 201, "kind": "CODE", "sortOrder": 1, "points": 2.5, "language": "c",
         "prompt": "<p><b>Q1.</b> Write a program that reads an integer <code>n</code> and prints <code>EVEN</code> if it is even, otherwise <code>ODD</code>.</p>|||<p><b>Câu 1.</b> Viết chương trình đọc số nguyên <code>n</code>, in <code>EVEN</code> nếu chẵn, ngược lại in <code>ODD</code>.</p>",
         "starterCode": "#include <stdio.h>\n\nint main() {\n    // TODO\n    return 0;\n}\n",
         "expectedOutput": "Input: 7\nOutput: ODD", "selectCount": 1, "multiSelect": false],
        ["id": 202, "kind": "CODE", "sortOrder": 2, "points": 2.5, "language": "c",
         "prompt": "<p><b>Q2.</b> Read an array of n integers and print the largest value.</p>|||<p><b>Câu 2.</b> Đọc mảng n số nguyên và in giá trị lớn nhất.</p>",
         "starterCode": "#include <stdio.h>\n\nint main() {\n    return 0;\n}\n", "selectCount": 1, "multiSelect": false],
    ]

    static let cauViet: [[String: Any]] = [
        ["id": 301, "kind": "WRITE", "sortOrder": 1, "points": 4,
         "prompt": "<p><b>Question 1.</b> Describe how the Product List page loads and renders data from the REST API.</p>",
         "selectCount": 1, "multiSelect": false],
        ["id": 302, "kind": "WRITE", "sortOrder": 2, "points": 6,
         "prompt": "<p><b>Question 2.</b> Draw a <b>Use Case Diagram</b> for the shop system (Customer, Admin).</p>",
         "selectCount": 1, "multiSelect": false],
    ]

    static let cauNoi: [[String: Any]] = [
        ["id": 401, "kind": "SPEAK", "sortOrder": 1, "points": 10,
         "prompt": "Answer the examiner's questions about the person card and the object card.|||Trả lời các câu hỏi của giám khảo về thẻ người và thẻ đồ vật.",
         "speakingPrompts": [["text": "おなまえは なんですか。"], ["text": "おくには どちらですか。"], "これは なんですか。"] as [Any],
         "selectCount": 1, "multiSelect": false],
    ]

    /// Bản xem lại mẫu. ⚠️ Câu 9001 cố ý để `options` là MẢNG CHUỖI TRẦN (dạng
    /// thô có thật ở cột `options`) — bản cũ hỏng cả màn vì đúng một câu như vậy.
    static let xemLai: XemLaiBaiThi = {
        let json = """
        {"attempt":{"id":77,"examId":384,"status":"GRADED","startedAt":"2026-10-22T08:00:00.000Z","submittedAt":"2026-10-22T08:41:12.000Z","timeSpentSeconds":2472,"score":6.5,"maxScore":10,"passed":true,"gradingMode":"AUTO",
          "feedback":{"correctCount":2,"total":3,"perQuestion":[
            {"questionId":9001,"points":1,"correct":true,"selected":[1]},
            {"questionId":9003,"points":1,"correct":false,"selected":[0]},
            {"questionId":9002,"points":2,"kind":"CODE","grade":{"score":1.5,"maxScore":2,"percent":75,"verdict":"good","summary":"Correct logic; missing input validation.|||Đúng logic; thiếu kiểm tra dữ liệu vào.","criteria":[{"id":"c1","name":"Correctness|||Tính đúng","score":1.2,"maxScore":1.4,"comment":"Prints the right square.|||In đúng bình phương."},{"id":"c2","name":"Style|||Trình bày","score":"0.3","maxScore":0.6,"comment":"No comments.|||Thiếu chú thích."}],"suggestions":["Validate scanf's return value.|||Kiểm tra giá trị trả về của scanf."]}}
          ]}},
         "exam":{"id":384,"courseId":1,"kind":"FE","peType":null,"title":"Đề 13 — Final Exam (SP25-RE)|||Đề 13 — Thi cuối kỳ (SP25-RE)","description":null,"code":"D13","durationMinutes":60,"totalPoints":10,"passMark":5,"source":"REAL","instructions":null,"attachmentUrl":null,"attachmentName":null,"isPublished":true,"sortOrder":0},
         "examBookmarked":false,
         "questions":[
          {"id":9001,"kind":"MCQ","sortOrder":1,"points":1,"prompt":"Which header declares printf?|||printf được khai báo ở tệp tiêu đề nào?","imageUrl":null,"options":["<stdlib.h>","<stdio.h>","<string.h>","<math.h>"],"correctIndexes":[1],"explanation":"printf lives in stdio.h.|||printf nằm trong stdio.h.","myAnswer":[1],"bookmarked":true,"bookmarkNote":"hay nhầm với stdlib"},
          {"id":9003,"kind":"MCQ","sortOrder":2,"points":1,"prompt":"sizeof(char) is always…|||sizeof(char) luôn bằng…","imageUrl":null,"options":[{"text":"2"},{"text":"1"},{"text":"4"},{"text":"Depends on platform|||Tuỳ nền tảng"}],"correctIndexes":[1],"explanation":"The C standard defines sizeof(char) == 1.|||Chuẩn C quy định sizeof(char) == 1.","myAnswer":[0],"bookmarked":false},
          {"id":9004,"kind":"MCQ","sortOrder":3,"points":1,"prompt":"Which operator has the highest precedence?|||Toán tử nào có độ ưu tiên cao nhất?","imageUrl":null,"options":[{"text":"+"},{"text":"*"},{"text":"()"},{"text":"="}],"correctIndexes":[2],"explanation":null,"myAnswer":null,"bookmarked":false},
          {"id":9002,"kind":"CODE","sortOrder":4,"points":2,"prompt":"Read n and print n squared.|||Đọc n và in n bình phương.","imageUrl":null,"options":null,"correctIndexes":[],"explanation":null,"language":"c","starterCode":null,"sampleSolution":"#include <stdio.h>\\nint main(){int n;if(scanf(\\"%d\\",&n)!=1)return 1;printf(\\"%d\\",n*n);}","expectedOutput":"Input: 3\\nOutput: 9","rubric":[{"criterion":"Correct"}],"speakingPrompts":null,"myAnswer":"int main(){...}","bookmarked":false}
         ]}
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(XemLaiBaiThi.self, from: Data(json.utf8))
    }()
}
#endif
