#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mô-đun Kiểm thử — hình dạng theo `tests.service.ts` (list/getTest/
// listCycles/getCycle/getRun) và `fptTests.service.ts` (listFunctions/getFunction/
// listModules/getModule). Dự án NW (pid 7). Bấm Pass/Fail trong lượt 555 được GHI NHỚ
// (và trạng thái lượt tính lại cùng luật máy chủ) để kiểm giao diện thấy kết quả.
// ⚠️ Cả tệp trong `#if DEBUG`.

enum DuLieuGiaTests {
    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        let pr = "/work/projects/7"
        guard p.hasPrefix(pr + "/") else { return nil }
        let r = String(p.dropFirst(pr.count))
        switch (m, r) {
        case ("GET", "/tests"): return dsCa
        case ("GET", "/test-cycles"): return [chuKy(chiTiet: false), chuKyCu]
        case ("GET", "/fpt-tests/unit"): return fptUnit
        case ("GET", "/fpt-tests/unit/1"): return hamLogin
        case ("GET", "/fpt-tests/integration"): return fptInt
        case ("GET", "/fpt-tests/integration/1"): return moduleLogin
        case ("GET", "/fpt-tests/system"): return ["modules": [Any](), "summary": ["passed": 0, "failed": 0, "pending": 0, "na": 0, "total": 0, "coverage": 0, "successCoverage": 0]]
        case ("POST", "/issues/42/attachments/presign"):
            return ["uploadUrl": "https://cuongthai.com/api/v1/work/__xem-thu/r2-upload", "key": "work/7/evidence.jpg",
                    "headers": ["Content-Type": b["contentType"] as? String ?? "image/jpeg"]]
        case ("POST", "/issues/42/attachments/complete"):
            let a: [String: Any] = ["id": 80, "fileName": b["fileName"] ?? "Evidence.jpg", "mime": "image/jpeg", "size": 182_400,
                                    "createdAt": DuLieuGia.iso(0), "clientVisible": false, "deliverable": false, "uploader": DuLieuGia.toi]
            khoa.lock(); bangChungThem.append(a); khoa.unlock()
            return a
        default: break
        }
        if m == "GET", r.hasPrefix("/tests/") { return chiTietCa }
        if r.hasPrefix("/test-cycles/") {
            return m == "GET" ? chuKy(chiTiet: true) : ["updated": true]
        }
        if r.hasPrefix("/test-runs/") {
            let phan = r.split(separator: "/").map(String.init)   // ["test-runs", "555", "steps", "9002"]
            if m == "POST", phan.count >= 3, phan[2] == "defects" { return ["number": 41] }
            if m == "PATCH", phan.count == 4, phan[2] == "steps", let sid = Int(phan[3]) {
                khoa.lock()
                if let s = b["status"] as? String { buocDoi[sid] = s }
                if let a = b["actual"] as? String { thucTeDoi[sid] = a }
                if b["actual"] is NSNull { thucTeDoi[sid] = "" }
                khoa.unlock()
            }
            if m == "PATCH", phan.count == 2, b["reset"] as? Bool == true {
                khoa.lock(); for (i, _) in buocGoc.enumerated() { buocDoi[9001 + i] = "TODO"; thucTeDoi[9001 + i] = "" }; khoa.unlock()
            }
            if m == "PATCH", phan.count == 2, let c = b["comment"] as? String {
                khoa.lock(); ghiChu = c; khoa.unlock()
            }
            return luot
        }
        if r.hasPrefix("/attachments/"), r.hasSuffix("/url") {
            return ["url": "https://cuongthai.com/api/v1/work/__xem-thu/evidence.jpg"]
        }
        return nil
    }

    /// `nil` ⇒ `NSNull()` (giữ khoá với giá trị null như JSON thật); gọn kiểu cho trình biên dịch.
    static func n(_ v: Any?) -> Any { v ?? NSNull() }
    static let defectMau: [[String: Any]] = [["number": 14, "title": "Crash when attaching a HEIC photo on iOS 17", "statusId": 1, "deletedAt": NSNull()]]

    private static let khoa = NSLock()
    nonisolated(unsafe) private static var buocDoi: [Int: String] = [:]
    nonisolated(unsafe) private static var thucTeDoi: [Int: String] = [:]
    nonisolated(unsafe) private static var bangChungThem: [[String: Any]] = []
    nonisolated(unsafe) private static var ghiChu = "iPhone 15 · iOS 18.1 · TestFlight build 1.4.2 (88)"

    // MARK: Ca kiểm thử

    static func caKT(_ so: Int, _ t: String, pr: Int, buoc: Int, lr: String?, ck: String? = "Sprint 6 — iOS regression", req: [[String: Any]] = []) -> [String: Any] {
        ["id": 800 + so, "number": so, "title": t, "priority": pr, "statusId": 4, "assigneeId": 4, "updatedAt": DuLieuGia.iso(-2),
         "labelIds": [1], "kind": "MANUAL", "stepCount": buoc, "requirements": req,
         "lastRun": n(lr.map { ["status": $0, "executedAt": DuLieuGia.iso(-0.4), "cycleName": n(ck)] as [String: Any] })]
    }

    static let dsCa: [[String: Any]] = [
        caKT(42, "Sign in with Apple creates a session", pr: 1, buoc: 5, lr: "FAIL", req: [["number": 12, "title": "UC-01 Sign in"]]),
        caKT(43, "Push notification opens the right issue", pr: 2, buoc: 4, lr: "PASS", req: [["number": 12, "title": "UC-01 Sign in"]]),
        caKT(44, "Attach a HEIC photo to an issue", pr: 2, buoc: 3, lr: "BLOCKED"),
        caKT(45, "Drag a card to Done on the board", pr: 3, buoc: 4, lr: "PASS"),
        caKT(46, "Offline: My Work shows cached issues", pr: 3, buoc: 3, lr: nil),
        caKT(47, "Delete account flow (72-hour grace)", pr: 2, buoc: 6, lr: "IN_PROGRESS"),
    ]

    static let chiTietCa: [String: Any] = [
        "number": 42, "title": "Sign in with Apple creates a session", "testCaseId": 77, "kind": "MANUAL",
        "preconditions": "Fresh install. The Apple ID is not linked to any CT Work account yet.",
        "gherkin": NSNull(), "updatedAt": DuLieuGia.iso(-2),
        "steps": buocGoc.enumerated().map { i, s in
            ["id": 301 + i, "position": i, "action": s.0, "data": n(s.1), "expected": s.2] as [String: Any]
        },
        "runs": [
            ["id": 555, "status": "FAIL", "executedAt": DuLieuGia.iso(-0.4), "comment": NSNull(), "executedBy": DuLieuGia.an,
             "cycle": ["id": 9, "name": "Sprint 6 — iOS regression", "environment": "iPhone 15 · iOS 18"],
             "defects": [["number": 14, "title": "Crash when attaching a HEIC photo on iOS 17", "statusId": 1, "deletedAt": NSNull()]]],
            ["id": 512, "status": "PASS", "executedAt": DuLieuGia.iso(-12), "comment": NSNull(), "executedBy": DuLieuGia.scout,
             "cycle": ["id": 7, "name": "Sprint 5 — Beta", "environment": "iPad Air · iPadOS 18"], "defects": [Any]()],
        ],
        "plans": [["id": 2, "name": "Regression v1.0"]],
    ]

    static let buocGoc: [(String, String?, String)] = [
        ("Open CT Work and tap “Sign in with Apple”", nil, "The Apple sheet appears with the app name"),
        ("Confirm with Face ID and choose “Hide My Email”", "Apple ID: tester+ctw@icloud.com", "The sheet closes and My Work opens"),
        ("Force-quit the app and open it again", nil, "Still signed in — no login screen"),
        ("Go to Account and check the email shown", nil, "The relay address (…@privaterelay.appleid.com) is shown"),
        ("Sign out, then sign in with Apple again", nil, "The SAME account opens (no duplicate account created)"),
    ]

    // MARK: Lượt chạy

    static var luot: [String: Any] {
        khoa.lock(); defer { khoa.unlock() }
        let goc = ["PASS", "PASS", "FAIL", "TODO", "TODO"]
        let thucTeGoc = ["", "", "Login screen shown again after relaunch — session token lost", "", ""]
        let buoc: [[String: Any]] = buocGoc.enumerated().map { i, s in
            let sid = 9001 + i
            let st = buocDoi[sid] ?? goc[i]
            let a = thucTeDoi[sid] ?? thucTeGoc[i]
            return ["id": sid, "position": i, "action": s.0, "data": n(s.1), "expected": s.2,
                    "status": st, "actual": n(a.isEmpty ? nil : a)]
        }
        let trangThai = tinhLuot(buoc.map { $0["status"] as? String ?? "TODO" })
        return [
            "id": 555, "status": trangThai, "comment": n(ghiChu.isEmpty ? nil : ghiChu), "gherkin": NSNull(),
            "executedAt": DuLieuGia.iso(-0.4), "assigneeId": 4, "testCaseVersion": 3, "executedBy": DuLieuGia.an,
            "cycle": ["id": 9, "name": "Sprint 6 — iOS regression", "environment": "iPhone 15 · iOS 18", "build": "1.4.2 (88)", "state": "IN_PROGRESS"],
            "testCase": ["preconditions": "Fresh install. The Apple ID is not linked to any CT Work account yet.", "kind": "MANUAL", "version": 4,
                         "issue": ["number": 42, "title": "Sign in with Apple creates a session", "priority": 1]],
            "steps": buoc,
            "defects": [["number": 14, "title": "Crash when attaching a HEIC photo on iOS 17", "statusId": 1, "deletedAt": NSNull()]],
            "evidence": [
                ["id": 71, "fileName": "relaunch-login-screen.png", "mime": "image/png", "size": 412_330, "createdAt": DuLieuGia.iso(-0.4), "uploader": DuLieuGia.an],
                ["id": 72, "fileName": "console.log", "mime": "text/plain", "size": 8_210, "createdAt": DuLieuGia.iso(-0.3), "uploader": DuLieuGia.an],
            ] + bangChungThem,
        ]
    }

    /// Bản sao luật máy chủ cho máy chủ giả (không gọi model của app — tệp dữ liệu phải độc lập).
    static func tinhLuot(_ s: [String]) -> String {
        if s.isEmpty { return "TODO" }
        if s.contains("FAIL") { return "FAIL" }
        if s.contains("BLOCKED") { return "BLOCKED" }
        if s.allSatisfy({ $0 == "PASS" || $0 == "SKIP" }) { return s.contains("PASS") ? "PASS" : "SKIP" }
        return s.contains { $0 != "TODO" } ? "IN_PROGRESS" : "TODO"
    }

    // MARK: Chu kỳ

    static func luotCK(_ id: Int, _ so: Int, _ t: String, _ st: String, pr: Int, buoc: Int, ai: [String: Any]?, outdated: Bool = false, loi: Int = 0) -> [String: Any] {
        ["id": id, "status": st, "executedAt": n(st == "TODO" ? nil : DuLieuGia.iso(-0.5)), "comment": NSNull(), "assigneeId": 4,
         "executedBy": n(ai), "stepCount": buoc, "testVersion": outdated ? 3 as Int : 4 as Int, "currentVersion": 4, "outdated": outdated,
         "test": ["number": so, "title": t, "priority": pr],
         "defects": loi > 0 ? defectMau : [[String: Any]]()]
    }

    static func chuKy(chiTiet: Bool) -> [String: Any] {
        var c: [String: Any] = [
            "id": 9, "name": "Sprint 6 — iOS regression", "environment": "iPhone 15 · iOS 18", "build": "1.4.2 (88)", "state": "IN_PROGRESS",
            "startAt": DuLieuGia.iso(-3), "endAt": NSNull(), "createdAt": DuLieuGia.iso(-4),
            "autoCloseMinutes": NSNull(), "expectedJobs": NSNull(), "importCount": 0, "lastImportAt": NSNull(), "closedReason": NSNull(),
            "plan": ["id": 2, "name": "Regression v1.0"],
            "counts": ["TODO": 2, "IN_PROGRESS": 1, "PASS": 4, "FAIL": 1, "BLOCKED": 1, "SKIP": 0, "RETEST": 1],
            "total": 10, "executed": 6, "passRate": 67, "progress": 60,
        ]
        if chiTiet {
            c["runs"] = [
                luotCK(555, 42, "Sign in with Apple creates a session", "FAIL", pr: 1, buoc: 5, ai: DuLieuGia.an, outdated: true, loi: 1),
                luotCK(556, 43, "Push notification opens the right issue", "PASS", pr: 2, buoc: 4, ai: DuLieuGia.an),
                luotCK(557, 44, "Attach a HEIC photo to an issue", "BLOCKED", pr: 2, buoc: 3, ai: DuLieuGia.minh),
                luotCK(558, 45, "Drag a card to Done on the board", "PASS", pr: 3, buoc: 4, ai: DuLieuGia.scout),
                luotCK(559, 47, "Delete account flow (72-hour grace)", "IN_PROGRESS", pr: 2, buoc: 6, ai: DuLieuGia.toi),
                luotCK(560, 46, "Offline: My Work shows cached issues", "TODO", pr: 3, buoc: 3, ai: nil),
                luotCK(561, 48, "Dynamic Type XXL on issue detail", "TODO", pr: 3, buoc: 2, ai: nil),
                luotCK(562, 49, "iPad split view keeps selection", "PASS", pr: 3, buoc: 3, ai: DuLieuGia.minh),
                luotCK(563, 50, "Chat: report a message hides it", "PASS", pr: 2, buoc: 3, ai: DuLieuGia.an),
                luotCK(564, 51, "Retest: HEIC upload after fix", "RETEST", pr: 2, buoc: 3, ai: DuLieuGia.an),
            ]
        }
        return c
    }

    static let chuKyCu: [String: Any] = [
        "id": 7, "name": "Sprint 5 — Beta", "environment": "iPad Air · iPadOS 18", "build": "1.3.0 (71)", "state": "DONE",
        "startAt": DuLieuGia.iso(-20), "endAt": DuLieuGia.iso(-12), "createdAt": DuLieuGia.iso(-21),
        "autoCloseMinutes": NSNull(), "expectedJobs": NSNull(), "importCount": 0, "lastImportAt": NSNull(), "closedReason": "MANUAL",
        "plan": NSNull(),
        "counts": ["TODO": 0, "IN_PROGRESS": 0, "PASS": 11, "FAIL": 1, "BLOCKED": 0, "SKIP": 1, "RETEST": 0],
        "total": 13, "executed": 13, "passRate": 85, "progress": 100,
    ]

    // MARK: FPT

    static func thongKe(_ p: Int, _ f: Int, _ u: Int, _ n: Int, _ a: Int, _ bb: Int) -> [String: Any] {
        ["passed": p, "failed": f, "untested": u, "n": n, "a": a, "b": bb, "total": p + f + u]
    }

    static let fptUnit: [String: Any] = [
        "tcPerKloc": 100,
        "summary": ["passed": 9, "failed": 2, "untested": 1, "n": 6, "a": 4, "b": 2, "total": 12, "functions": 2,
                    "coverage": 91.7, "successCoverage": 75, "normalPct": 50, "abnormalPct": 33.3, "boundaryPct": 16.7,
                    "totalLoc": 140, "kloc": 0.14, "requiredCases": 14, "casesWithLoc": 12, "functionsWithoutLoc": 0,
                    "belowNorm": 1, "meetsNorm": false],
        "functions": [
            ["id": 1, "moduleName": "AuthService", "methodName": "login", "sheetName": "login", "description": "Validate credentials and create a session",
             "preCondition": "Connected to the server", "testRequirement": "UC-01 Sign in", "codeRef": "src/services/auth.ts#L40", "loc": 60,
             "createdBy": "An Nguyen", "executedBy": "An Nguyen", "position": 0, "updatedAt": DuLieuGia.iso(-1), "rowCount": 7,
             "stats": thongKe(5, 1, 0, 3, 2, 1), "requiredCases": 6, "belowNorm": false],
            ["id": 2, "moduleName": "IssueService", "methodName": "move", "sheetName": "move", "description": "Move an issue to another status",
             "preCondition": NSNull(), "testRequirement": NSNull(), "codeRef": NSNull(), "loc": 80,
             "createdBy": "Minh Pham", "executedBy": "Minh Pham", "position": 1, "updatedAt": DuLieuGia.iso(-2), "rowCount": 6,
             "stats": thongKe(4, 1, 1, 3, 2, 1), "requiredCases": 8, "belowNorm": true],
        ],
    ]

    static let hamLogin: [String: Any] = [
        "id": 1, "moduleName": "AuthService", "methodName": "login", "sheetName": "login", "description": "Validate credentials and create a session",
        "preCondition": "Connected to the server", "testRequirement": "UC-01 Sign in", "codeRef": "src/services/auth.ts#L40", "loc": 60,
        "createdBy": "An Nguyen", "executedBy": "An Nguyen", "position": 0, "updatedAt": DuLieuGia.iso(-1),
        "rows": [
            ["id": 1, "section": "COND", "groupName": "Precondition", "label": NSNull(), "value": "Connected to the server"],
            ["id": 2, "section": "COND", "groupName": "username", "label": NSNull(), "value": "\"alex\" (exists)"],
            ["id": 3, "section": "COND", "groupName": "username", "label": NSNull(), "value": "\"\" (empty)"],
            ["id": 4, "section": "COND", "groupName": "password", "label": NSNull(), "value": "correct"],
            ["id": 5, "section": "COND", "groupName": "password", "label": NSNull(), "value": "wrong 5 times"],
            ["id": 6, "section": "CONFIRM", "groupName": "Return", "label": NSNull(), "value": "Session token"],
            ["id": 7, "section": "CONFIRM", "groupName": "Exception", "label": NSNull(), "value": "InvalidCredentials"],
            ["id": 8, "section": "CONFIRM", "groupName": "Log message", "label": NSNull(), "value": "\"Account locked\""],
        ],
        "cases": [
            ["id": 10, "type": "N", "result": "P", "executedAt": "2026-10-15", "defectId": NSNull(), "note": NSNull(), "rowIds": [1, 2, 4, 6]],
            ["id": 11, "type": "A", "result": "P", "executedAt": "2026-10-15", "defectId": NSNull(), "note": NSNull(), "rowIds": [1, 3, 4, 7]],
            ["id": 12, "type": "A", "result": "F", "executedAt": "2026-10-16", "defectId": "NW-14", "note": NSNull(), "rowIds": [1, 2, 5, 7, 8]],
            ["id": 13, "type": "B", "result": "P", "executedAt": "2026-10-16", "defectId": NSNull(), "note": NSNull(), "rowIds": [1, 2, 4, 6]],
            ["id": 14, "type": "N", "result": "P", "executedAt": "2026-10-16", "defectId": NSNull(), "note": NSNull(), "rowIds": [1, 2, 4, 6]],
            ["id": 15, "type": "N", "result": "P", "executedAt": "2026-10-17", "defectId": NSNull(), "note": NSNull(), "rowIds": [1, 2, 4, 6]],
        ],
        "stats": thongKe(5, 1, 0, 3, 2, 1), "tcPerKloc": 100, "requiredCases": 6, "belowNorm": false,
    ]

    static func vong(_ ds: [String?]) -> [[String: Any]] {
        ds.enumerated().map { i, s in
            ["status": n(s), "date": n(s == nil ? nil : "2026-10-1\(i + 2)"), "tester": n(s == nil ? nil : "An")] as [String: Any]
        }
    }

    static func itStats(_ p: Int, _ f: Int, _ pe: Int, _ na: Int, lan: Int) -> [String: Any] {
        ["passed": p, "failed": f, "pending": pe, "na": na, "total": p + f + pe + na, "lastRound": lan,
         "rounds": (0..<4).map { i in ["passed": i < lan ? p : 0, "failed": i < lan ? f : 0, "pending": 0, "na": 0] }]
    }

    static let fptInt: [String: Any] = [
        "modules": [
            ["id": 1, "name": "Login & session", "sheetName": "Login", "idPrefix": "LS", "description": "Sign-in, token refresh and sign-out across app + API",
             "preCondition": "Backend staging is up", "testRequirement": "UC-01, UC-02", "position": 0, "updatedAt": DuLieuGia.iso(-1),
             "stats": itStats(3, 1, 0, 0, lan: 2)],
            ["id": 2, "name": "Issue board", "sheetName": "Board", "idPrefix": "BD", "description": NSNull(),
             "preCondition": NSNull(), "testRequirement": NSNull(), "position": 1, "updatedAt": DuLieuGia.iso(-3),
             "stats": itStats(2, 0, 2, 1, lan: 1)],
        ],
        "summary": ["passed": 5, "failed": 1, "pending": 2, "na": 1, "total": 9, "coverage": 75, "successCoverage": 62.5],
    ]

    static let moduleLogin: [String: Any] = [
        "id": 1, "name": "Login & session", "sheetName": "Login", "idPrefix": "LS", "kind": "INT",
        "description": "Sign-in, token refresh and sign-out across app + API",
        "preCondition": "Backend staging is up", "testRequirement": "UC-01, UC-02", "position": 0, "updatedAt": DuLieuGia.iso(-1),
        "cases": [
            ["id": 5, "section": "Login", "description": "Sign in with a valid account", "procedure": "1. Open the app\n2. Enter credentials\n3. Tap Sign in",
             "testData": "alex / P@ss1", "expected": "My Work opens", "actual": "As expected", "preConditions": NSNull(), "evidence": NSNull(), "note": NSNull(),
             "rounds": vong(["Passed", "Passed", nil, nil])],
            ["id": 6, "section": "Login", "description": "Wrong password five times locks the account", "procedure": "Enter a wrong password 5 times",
             "testData": "alex / wrong", "expected": "“Account locked” message, login disabled for 15 min", "actual": "Message missing on iOS",
             "preConditions": NSNull(), "evidence": NSNull(), "note": NSNull(), "rounds": vong(["Failed", "Failed", nil, nil])],
            ["id": 7, "section": "Session", "description": "Expired token refreshes silently", "procedure": "Wait 24 h (or set a short TTL), then open an issue",
             "testData": NSNull(), "expected": "Issue opens without a login screen", "actual": NSNull(),
             "preConditions": "JWT_EXPIRES_IN=1m on staging", "evidence": NSNull(), "note": NSNull(), "rounds": vong(["Passed", "Passed", nil, nil])],
            ["id": 8, "section": "Session", "description": "Sign out clears the push token", "procedure": "Sign out, send a test push",
             "testData": NSNull(), "expected": "No notification arrives", "actual": NSNull(), "preConditions": NSNull(), "evidence": NSNull(), "note": NSNull(),
             "rounds": vong(["Passed", nil, nil, nil])],
        ],
        "stats": itStats(3, 1, 0, 0, lan: 2),
    ]
}
#endif
