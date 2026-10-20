#if DEBUG
import Foundation

// MARK: - Máy chủ giả: "Create with CuongMini" + tạo dự án (hình dạng `banNhap.service.ts → present()`)
//
// Màn thử: `CT_XEM_MAN=chonduan` + `CT_XEM_TAO=duan` (hộp New project) · `cm` (màn đầu) · `cm/dien` · `cm/dangdoc` ·
// `cm/hieu` · `cm/kehoach` · `cm/xong`. Job giả: bấm Đọc/Chấp nhận/Tạo ⇒ `busy` ~3 s rồi sang pha sau (hỏi lại mỗi 1,5 s).
// ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

enum DuLieuGiaTaoCM {
    typealias G = DuLieuGia
    static var xem: String? { ProcessInfo.processInfo.environment["CT_XEM_TAO"] }
    static var idXem: Int? {
        switch xem {
        case "cm/dien"?: return 501
        case "cm/dangdoc"?: return 505
        case "cm/hieu"?: return 502
        case "cm/kehoach"?: return 503
        case "cm/xong"?: return 504
        default: return nil
        }
    }

    nonisolated(unsafe) private static var ds: [Int: [String: Any]] = mau()
    nonisolated(unsafe) private static var batDau: [Int: Date] = [:]
    nonisolated(unsafe) private static var idKe = 600

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        switch (m, p) {
        case ("GET", "/work/workspaces/1/setup-drafts"):
            return ds.values.sorted { ($0["id"] as? Int ?? 0) > ($1["id"] as? Int ?? 0) }.prefix(4).map {
                ["id": $0["id"]!, "mode": $0["mode"]!, "status": $0["status"]!, "title": $0["title"]!, "updatedAt": $0["updatedAt"]!, "result": $0["result"] ?? NSNull()]
            }
        case ("POST", "/work/workspaces/1/setup-drafts"):
            idKe += 1
            var d = nhap(idKe, "DRAFT", ten: ((b["input"] as? [String: Any])?["overview"] as? [String: Any])?["name"] as? String ?? "")
            d["mode"] = b["mode"] ?? "PROJECT"
            if let i = b["input"] { d["input"] = i }
            ds[idKe] = d
            return d
        case ("POST", "/work/workspaces/1/setup/roster"):
            let dong = (b["text"] as? String ?? "").split(separator: "\n").dropFirst()
            return ["rows": dong.map { l -> [String: Any] in
                let c = l.split(separator: "\t").map(String.init)
                return ["name": c.first ?? "", "studentId": c.count > 1 ? c[1] : "", "email": c.count > 2 ? c[2] : "", "role": c.count > 3 ? c[3] : "", "level": 3, "hoursPerWeek": 8]
            }, "headerFound": true, "warnings": [Any]()]
        case ("POST", "/work/workspaces/1/projects"):
            return ["id": 9, "key": b["key"] ?? "NEW", "name": b["name"] ?? "New project", "kind": b["kind"] ?? "SCHOOL"]
        case ("POST", "/work/projects/9/sample-data"):
            return ["issues": 12, "labels": 4, "sprintId": 3, "plans": 0]
        default: break
        }
        guard p.hasPrefix("/work/setup-drafts/") else { return nil }
        let phan = p.split(separator: "/").map(String.init)   // work, setup-drafts, :id, …
        guard phan.count >= 3, let id = Int(phan[2]), var d = ds[id] else { return LoiGiaCTW(trangThai: 404, ma: "NOT_FOUND", thongDiep: "Draft not found") }
        let viec = phan.count > 3 ? phan[3] : ""
        switch (m, viec) {
        case ("GET", ""):
            d = tienLen(d)
        case ("PATCH", ""):
            for k in ["input", "understanding", "plan", "model"] where b[k] != nil { d[k] = b[k] }
            if let t = ((b["input"] as? [String: Any])?["overview"] as? [String: Any])?["name"] as? String, !t.isEmpty { d["title"] = t }
        case ("DELETE", ""):
            ds[id] = nil
            return ["deleted": true]
        case ("POST", "links"):
            let s: [String: Any] = ["id": "s\(Int.random(in: 100...999))", "kind": "LINK", "category": b["category"] ?? "BRIEF", "name": "Đề bài SWP391 — Nhà trọ SV (Google Docs)",
                                    "note": "", "url": b["url"] ?? "", "status": "OK", "chars": 18_400, "addedAt": G.iso(0)]
            d["sources"] = (d["sources"] as? [[String: Any]] ?? []) + [s]
            ds[id] = d
            return ["draft": d, "source": s]
        case ("POST", "files"):
            let s: [String: Any] = ["id": "s\(Int.random(in: 100...999))", "kind": "FILE", "category": "BRIEF", "name": "De-bai-SWP391.pdf", "note": "", "mime": "application/pdf",
                                    "size": 412_000, "status": "OK", "chars": 23_100, "addedAt": G.iso(0)]
            d["sources"] = (d["sources"] as? [[String: Any]] ?? []) + [s]
            ds[id] = d
            return ["draft": d, "source": s, "roster": NSNull()]
        case ("DELETE", "sources"):
            let sid = phan.count > 4 ? phan[4] : ""
            d["sources"] = (d["sources"] as? [[String: Any]] ?? []).filter { ($0["id"] as? String) != sid }
        case ("POST", "understand"): d = chay(d, "READING", ["read", "understand"])
        case ("POST", "accept"):
            if let u = b["understanding"] { d["understanding"] = u }
            d = chay(d, "PLANNING", ["prepare", "outline", "epics:e1:Tìm phòng", "epics:e2:Đặt cọc", "tests", "pages", "assemble"])
        case ("POST", "revise"): d = chay(d, "PLANNING", ["revise", "assemble"])
        case ("POST", "rebalance"): break
        case ("POST", "apply"): d = chay(d, "APPLYING", ["create", "project:NTS", "invites"])
        case ("POST", "cancel"):
            d["status"] = d["understanding"] is NSNull ? "DRAFT" : "UNDERSTOOD"; d["busy"] = false
        default: return LoiGiaCTW(trangThai: 404, ma: "NOT_FOUND", thongDiep: "Route not found")
        }
        d["updatedAt"] = G.iso(0)
        ds[id] = d
        return d
    }

    private static func chay(_ d0: [String: Any], _ st: String, _ buoc: [String]) -> [String: Any] {
        var d = d0
        d["status"] = st; d["busy"] = true; d["error"] = NSNull(); d["failedPhase"] = NSNull()
        d["progress"] = buoc.enumerated().map { i, k in ["key": k, "status": i == 0 ? "running" : "pending"] as [String: Any] }
        batDau[d["id"] as? Int ?? 0] = Date()
        return d
    }

    /// Job giả: mỗi 0,8 s một bước xong; hết bước ⇒ sang pha sau.
    private static func tienLen(_ d0: [String: Any]) -> [String: Any] {
        guard d0["busy"] as? Bool == true, let id = d0["id"] as? Int else { return d0 }
        // Bản nháp "đang đọc" để chụp màn: đứng yên.
        if id == 505 { return d0 }
        var d = d0
        let t = Date().timeIntervalSince(batDau[id] ?? Date())
        var buoc = d["progress"] as? [[String: Any]] ?? []
        let xong = Int(t / 0.8)
        for i in buoc.indices { buoc[i]["status"] = i < xong ? "done" : (i == xong ? "running" : "pending") }
        d["progress"] = buoc
        d["usage"] = ["calls": min(xong + 1, buoc.count), "usd": 0.0, "fallback": 0]
        guard xong >= buoc.count else { return d }
        d["busy"] = false
        switch d["status"] as? String {
        case "READING": d["status"] = "UNDERSTOOD"; d["understanding"] = hieu
        case "PLANNING":
            d["status"] = "READY"
            if d["plan"] == nil || d["plan"] is NSNull { d["plan"] = keHoach }
        case "APPLYING": d["status"] = "APPLIED"; d["result"] = ketQua; d["appliedAt"] = G.iso(0)
        default: break
        }
        return d
    }

    // MARK: Dữ liệu mẫu (đề tài "Nhà trọ sinh viên" — nội dung người dùng, tiếng Việt)

    private static let dauVao: [String: Any] = [
        "overview": ["name": "Nhà trọ sinh viên", "key": "NTS", "template": "SWP391", "type": "SCRUM", "kind": "SCHOOL", "courseCode": "SWP391", "className": "SE1801",
                     "semester": "Fall 2026", "stakeholders": "", "language": "vi", "goal": "Website giúp sinh viên tìm phòng trọ gần trường, xem ảnh thật, đặt lịch xem phòng và đặt cọc online."],
        "brief": ["text": "Hệ thống có 3 vai: sinh viên, chủ trọ, quản trị. Sinh viên tìm phòng theo giá/khoảng cách, đặt lịch xem, đặt cọc qua VNPay. Chủ trọ đăng phòng, duyệt lịch hẹn. Báo cáo theo mẫu FPT: Report 1–3.",
                  "functional": "", "nonFunctional": "", "rubric": "", "deliverables": ["SRS", "SDD", "Báo cáo cuối"]],
        "team": ["members": [
            ["name": "Nguyễn Văn An", "studentId": "SE183456", "email": "an@fpt.edu.vn", "role": "Leader", "skills": "", "level": 4, "hoursPerWeek": 10, "prefs": "", "group": ""],
            ["name": "Trần Thị Bình", "studentId": "SE183457", "email": "binh@fpt.edu.vn", "role": "BA", "skills": "", "level": 3, "hoursPerWeek": 8, "prefs": "", "group": ""],
            ["name": "Lê Minh Khoa", "studentId": "SE183458", "email": "", "role": "Dev", "skills": "", "level": 2, "hoursPerWeek": 8, "prefs": "", "group": ""],
        ], "rules": ["BY_LEVEL", "LEADER_REVIEWS"], "rulesText": "", "sendInvites": false],
        "timeline": ["startDate": "2026-09-07", "endDate": "2026-12-15", "milestones": [Any](), "sprintWeeks": 2, "workingDays": [1, 2, 3, 4, 5], "avoid": [Any](), "meeting": NSNull()],
        "code": ["repoUrl": "", "branch": "", "stack": "", "conventions": ""],
        "split": ["prompt": "Chia theo mô-đun; mỗi story ≤ 3 ngày.", "detail": "SUBTASKS", "criteria": true, "points": true, "tests": true, "risks": true, "meetings": true,
                  "pages": true, "assign": true, "onboarding": true],
        "groups": [Any](), "reviewFirst": true,
    ]

    private static let hieu: [String: Any] = [
        "goal": "Website giúp sinh viên tìm phòng trọ gần trường, xem ảnh thật, đặt lịch xem phòng và đặt cọc online; chủ trọ quản lý phòng và lịch hẹn.",
        "scopeIn": ["Tìm phòng theo giá, khoảng cách, tiện ích", "Đặt lịch xem phòng, chủ trọ duyệt", "Đặt cọc qua VNPay (môi trường thử)", "Trang quản trị duyệt tin đăng"],
        "scopeOut": ["Ứng dụng di động", "Hợp đồng điện tử"],
        "deliverables": [["name": "Report 1 — SRS", "due": "2026-10-05", "criteria": "15% · đủ use case + mockup"],
                         ["name": "Report 3 — Báo cáo cuối", "due": "2026-12-10", "criteria": "25%"]],
        "grading": ["Report 1 15%", "Demo 40%", "Báo cáo cuối 25%", "Làm việc nhóm 20%"],
        "tech": ["stack": ["Java Servlet/JSP", "SQL Server"], "repoFindings": [Any]()],
        "team": [["name": "Nguyễn Văn An", "studentId": "SE183456", "group": "", "proposedRole": "Leader + Backend", "why": "Trình độ 4, 10 giờ/tuần — gánh phần đặt cọc và review."],
                 ["name": "Trần Thị Bình", "studentId": "SE183457", "group": "", "proposedRole": "BA + Tester", "why": "Viết SRS, test case; ghép cặp với Khoa."],
                 ["name": "Lê Minh Khoa", "studentId": "SE183458", "group": "", "proposedRole": "Frontend", "why": "Mới bắt đầu — làm cặp với An ở việc khó."]],
        "timeline": ["5 sprint × 2 tuần, 07/09 → 15/12", "Report 1 ngày 05/10, Report 3 ngày 10/12"],
        "strategy": ["Chia theo mô-đun: Tìm phòng · Lịch hẹn · Đặt cọc · Quản trị", "Mỗi story có tiêu chí nghiệm thu và một việc kiểm thử"],
        "assumptions": ["Thanh toán dùng VNPay sandbox"],
        "risks": ["Khoa mới học JSP — dễ trễ phần giao diện"],
        "questions": [["q": "Chủ trọ có cần xác minh giấy tờ trước khi đăng phòng không?", "answer": ""],
                      ["q": "Đặt cọc có hoàn tiền khi sinh viên huỷ không?", "answer": "Có, trước 24 giờ."]],
        "notes": "",
    ]

    private static func viec(_ ref: String, _ kind: String, _ cha: String?, _ title: String, diem: Int? = nil, nguoi: String? = nil, sprint: String? = nil, khoa: Bool = false) -> [String: Any] {
        let khong: Any = NSNull()
        var v: [String: Any] = ["ref": ref, "kind": kind, "title": title, "description": "", "priority": 3, "difficulty": 2, "labels": [Any](), "component": "", "area": "",
                                "pairRef": khong, "milestoneRef": khong, "due": khong, "blockedBy": [Any](), "locked": khoa]
        v["parentRef"] = cha.map { $0 as Any } ?? khong
        v["criteria"] = kind == "STORY" ? ["Cho sinh viên đã đăng nhập, khi … thì …"] : [String]()
        v["points"] = diem.map { $0 as Any } ?? khong
        v["assigneeRef"] = nguoi.map { $0 as Any } ?? khong
        v["sprintRef"] = sprint.map { $0 as Any } ?? khong
        return v
    }

    private static let sprintMau: [[String: Any]] = [
        ["ref": "s1", "name": "Sprint 1", "goal": "SRS + khung dự án chạy được", "start": "2026-09-07", "end": "2026-09-20"],
        ["ref": "s2", "name": "Sprint 2", "goal": "Tìm phòng + đăng phòng", "start": "2026-09-21", "end": "2026-10-04"],
        ["ref": "s3", "name": "Sprint 3", "goal": "Lịch hẹn + đặt cọc", "start": "2026-10-05", "end": "2026-10-18"],
    ]
    private static let moDunMau: [[String: Any]] = [
        ["name": "Tìm phòng", "description": "Lọc theo giá, khoảng cách, tiện ích", "ownerRef": "m2"],
        ["name": "Lịch hẹn", "description": "Sinh viên đặt lịch, chủ trọ duyệt", "ownerRef": "m3"],
        ["name": "Đặt cọc", "description": "VNPay sandbox, hoàn cọc trước 24 giờ", "ownerRef": "m1"],
    ]
    private static let viecMau: [[String: Any]] = [
        viec("e1", "EPIC", nil, "Tìm phòng"),
        viec("st1", "STORY", "e1", "Sinh viên lọc phòng theo giá và khoảng cách", diem: 5, nguoi: "m2", sprint: "s2"),
        viec("st2", "STORY", "e1", "Xem chi tiết phòng với ảnh thật và bản đồ", diem: 3, nguoi: "m3", sprint: "s2", khoa: true),
        viec("e2", "EPIC", nil, "Đặt cọc"),
        viec("st3", "STORY", "e2", "Đặt cọc qua VNPay và nhận biên nhận", diem: 8, nguoi: "m1", sprint: "s3"),
        viec("sb1", "SUBTASK", "st3", "Tích hợp VNPay sandbox", diem: 3, nguoi: "m1", sprint: "s3"),
        viec("st4", "STORY", "e2", "Hoàn cọc khi huỷ trước 24 giờ", diem: 5, nguoi: "m1", sprint: "s3"),
    ]
    private static var duAnMau: [String: Any] {
        var p: [String: Any] = ["ref": "p1", "name": "Nhà trọ sinh viên", "key": "NTS", "template": "SWP391", "type": "SCRUM", "kind": "SCHOOL", "description": ""]
        p["sprints"] = sprintMau
        p["milestones"] = [["ref": "m1", "name": "Report 1", "date": "2026-10-05", "description": ""]] as [[String: Any]]
        p["labels"] = [Any]()
        p["components"] = moDunMau
        p["items"] = viecMau
        p["pages"] = [["ref": "pg1", "kind": "CHARTER", "title": "Hiến chương dự án", "markdown": "# Hiến chương"]] as [[String: Any]]
        p["tests"] = [["ref": "t1", "title": "Lọc phòng theo giá", "preconditions": "", "steps": [Any](), "storyRef": "st1"]] as [[String: Any]]
        p["risks"] = [["ref": "r1", "title": "Khoa trễ phần giao diện", "description": "", "category": "Con người", "probability": 3, "impact": 3,
                       "mitigation": "Làm cặp với An", "ownerRef": "m1"]] as [[String: Any]]
        p["meetings"] = [Any](); p["resources"] = [Any](); p["dod"] = ["Có test", "Đã review"]
        return p
    }
    private static func nguoi(_ ref: String, _ ten: String, _ ma: String, _ email: String, _ vai: String, _ muc: Int, truong: Bool, ghep: String) -> [String: Any] {
        ["ref": ref, "name": ten, "studentId": ma, "email": email, "role": vai, "skills": "", "level": muc, "hoursPerWeek": 8, "prefs": "",
         "projectRef": "p1", "leader": truong, "mapping": ghep, "userId": NSNull(), "why": ""]
    }
    private static var keHoach: [String: Any] {
        var k: [String: Any] = ["portfolio": NSNull()]
        k["projects"] = [duAnMau]
        k["members"] = [nguoi("m1", "Nguyễn Văn An", "SE183456", "an@fpt.edu.vn", "Leader", 4, truong: true, ghep: "INVITE"),
                        nguoi("m2", "Trần Thị Bình", "SE183457", "binh@fpt.edu.vn", "BA", 3, truong: false, ghep: "INVITE"),
                        nguoi("m3", "Lê Minh Khoa", "SE183458", "", "Dev", 2, truong: false, ghep: "PLACEHOLDER")]
        k["warnings"] = [["kind": "NO_EMAIL", "projectRef": "p1", "ref": "m3", "message": "Lê Minh Khoa chưa có email — việc giữ tên “Planned owner” tới khi vào nhóm."],
                         ["kind": "OVERLOAD", "projectRef": "p1", "ref": "m1", "message": "An nhận 19 điểm ở Sprint 3 (sức 15)."]] as [[String: Any]]
        return k
    }

    private static let ketQua: [String: Any] = [
        "projects": [["id": 9, "key": "NTS", "name": "Nhà trọ sinh viên", "url": "/work/northwind/NTS/board", "issues": 42, "pages": 13, "sprints": 5, "tests": 18,
                      "risks": 6, "meetings": 2, "resources": 4, "files": 1, "invited": 2, "added": 0, "planned": 1]],
        "invites": ["sent": 2, "added": 0, "skipped": 1],
    ]

    private static func nhap(_ id: Int, _ st: String, ten: String = "Nhà trọ sinh viên") -> [String: Any] {
        ["id": id, "workspaceId": 1, "mode": "PROJECT", "status": st, "title": ten, "model": "cm-sonic", "input": dauVao, "understanding": NSNull(), "plan": NSNull(),
         "progress": [Any](), "result": NSNull(), "error": NSNull(), "failedPhase": NSNull(), "busy": false,
         "sources": [["id": "s1", "kind": "FILE", "category": "BRIEF", "name": "De-bai-SWP391.pdf", "note": "", "mime": "application/pdf", "size": 412_000, "status": "OK",
                      "chars": 23_100, "addedAt": G.iso(-0.1)]],
         "usage": ["calls": 0, "usd": 0, "fallback": 0], "createdAt": G.iso(-0.2), "updatedAt": G.iso(-0.05), "appliedAt": NSNull()]
    }

    private static func mau() -> [Int: [String: Any]] {
        var dien = nhap(501, "DRAFT")
        dien["updatedAt"] = G.iso(-0.02)
        var hieuD = nhap(502, "UNDERSTOOD"); hieuD["understanding"] = hieu; hieuD["usage"] = ["calls": 2, "usd": 0.04, "fallback": 0]
        var kh = nhap(503, "READY"); kh["understanding"] = hieu; kh["plan"] = keHoach; kh["usage"] = ["calls": 9, "usd": 0.31, "fallback": 0]
        var x = nhap(504, "APPLIED"); x["understanding"] = hieu; x["plan"] = keHoach; x["result"] = ketQua; x["title"] = "Nhà trọ sinh viên (đã tạo)"
        var doc = nhap(505, "READING"); doc["busy"] = true
        doc["progress"] = [["key": "read", "status": "done", "detail": "2 nguồn, 41k ký tự"], ["key": "understand", "status": "running"]] as [[String: Any]]
        doc["usage"] = ["calls": 1, "usd": 0.0, "fallback": 0]
        return [501: dien, 502: hieuD, 503: kh, 504: x, 505: doc]
    }
}
#endif
