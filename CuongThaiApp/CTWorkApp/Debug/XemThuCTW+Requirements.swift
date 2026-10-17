#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng Yêu cầu (SRS · RTM · Wiegers) — hình dạng theo `srs.service.ts`,
// `rtm.ts`, `swr.service.ts`, `swrElic.service.ts`, `srsDeep.service.ts`. Dự án mẫu pid 7 (NW).
// Dùng cho `CT_XEM_MAN=mod:requirements[/uc]`, `mod:wiegers[/req|/reqdetail|/sh|/elc|/nfr]` và kiểm thử giải mã.

enum DuLieuGiaRequirements {
    typealias G = DuLieuGia
    private static let pr = "/work/projects/7"
    static func v(_ x: Any?) -> Any { x ?? NSNull() }

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        guard p.hasPrefix(pr + "/srs") || p.hasPrefix(pr + "/swr") || p == pr + "/rtm" else { return nil }
        let r = String(p.dropFirst(pr.count))
        switch (m, r) {
        case ("GET", "/srs"): return srs
        case ("POST", "/srs/use-cases"):
            return uc(9, "\(b["name"] ?? "New use case")", feature: b["feature"] as? String, status: "PROPOSED", actor: b["primaryActorId"] as? Int)
        case ("POST", "/srs/rules"):
            return ["id": 20, "projectId": 7, "number": 9, "name": b["name"] ?? "Rule", "definition": b["definition"] ?? NSNull(),
                    "category": b["category"] ?? NSNull(), "status": "PROPOSED", "aiModel": NSNull(), "createdById": 1, "version": 1,
                    "createdAt": G.iso(0), "updatedAt": G.iso(0), "key": "BR-09"]
        case ("GET", "/rtm"): return rtm
        case ("GET", "/swr/requirements"): return yeuCau
        case ("GET", "/swr/features"): return tinhNang
        case ("GET", "/swr/stakeholders"): return benLQ
        case ("GET", "/swr/glossary"): return thuatNgu
        case ("GET", "/swr/elicitation"): return phien
        case ("GET", "/swr/nfr"): return nfr
        case ("GET", "/swr/mockups"): return mau
        default: break
        }
        if m == "POST", r.hasPrefix("/srs/use-cases/"), r.hasSuffix("/status") { return useCases[1] }
        if m == "PATCH", r.hasPrefix("/srs/rules/") { return rules[0] }
        if m == "GET", r.hasPrefix("/swr/requirements/"), r.hasSuffix("/history") { return lichSu }
        if m == "POST", r.hasPrefix("/swr/requirements/"), r.hasSuffix("/lifecycle") { return dsYeuCau[0] }
        if m == "GET", r.hasPrefix("/swr/elicitation/") { return phienChiTiet }
        if m == "POST", r.hasSuffix("/proposals") { return ["id": 77] }
        return nil
    }

    // MARK: SRS

    static func uc(_ n: Int, _ ten: String, feature: String?, status: String, actor: Int?, pri: String = "HIGH",
                   rules: [Int] = [], phu: [Int] = [], issue: [String: Any]? = nil, missing: [String] = [], ai: Bool = false,
                   mo: String? = nil, truoc: String? = nil, sau: String? = nil, luong: String? = nil, nhanh: String? = nil,
                   ngoaiLe: String? = nil, kichHoat: String? = nil) -> [String: Any] {
        let key = String(format: "UC-%02d", n)
        return ["id": 100 + n, "number": n, "key": key, "name": ten, "feature": v(feature), "description": v(mo),
                "trigger": v(kichHoat), "preconditions": v(truoc), "postconditions": v(sau),
                "normalFlow": v(luong), "alternativeFlows": v(nhanh), "exceptionFlows": v(ngoaiLe),
                "priority": pri, "status": status, "primaryActorId": v(actor), "secondaryActorIds": phu, "ruleNumbers": rules,
                "issueKey": v((issue?["key"] as? String)), "section": v(status == "PROPOSED" ? nil : "2.1.\(n)"),
                "missing": missing, "version": 3, "aiModel": v(ai ? "gpt-5.4-mini" : nil), "updatedAt": G.iso(-Double(n)),
                "issue": v(issue)]
    }

    static let useCases: [[String: Any]] = [
        uc(1, "Sign in with email or Apple", feature: "Accounts", status: "APPROVED", actor: 1, rules: [1], phu: [3],
           issue: ["number": 12, "key": "NW-12", "title": "Push notifications open the right issue", "type": ["key": "STORY"],
                   "status": ["name": "In Progress", "category": "IN_PROGRESS"]],
           mo: "A team member signs in to CT Work on their phone.", truoc: "The user has a CuongThai account.",
           sau: "The user lands on **My Work**.",
           luong: "1. The user opens the app.\n2. The user chooses Sign in with Apple or enters email and password.\n3. The system verifies the credentials.\n4. The system shows My Work.",
           nhanh: "2A. The user forgot the password.\n2A.1. The system sends a reset link.\n3A. Two-factor is on — the system asks for the code.",
           ngoaiLe: "3E. The account is locked — the system shows the support contact.", kichHoat: "The user taps Sign in."),
        uc(3, "Attach a photo to an issue", feature: "Issues", status: "DRAFT", actor: 1, pri: "MEDIUM", rules: [2, 3],
           issue: ["number": 14, "key": "NW-14", "title": "Crash when attaching a HEIC photo on iOS 17", "type": ["key": "BUG"],
                   "status": ["name": "To Do", "category": "TODO"]],
           mo: "A tester adds photo evidence to an issue from the camera or the photo library.",
           truoc: "The user can edit the issue.", sau: "The photo is listed under Attachments.",
           luong: "1. The user opens an issue.\n2. The user taps + next to Attachments.\n3. The user takes a photo or picks one.\n4. The system uploads the file and shows it in the list.",
           nhanh: "3A. The file is larger than 25 MB — the system rejects it before upload.",
           ngoaiLe: "4E. The upload fails — the system keeps the photo and offers Retry.", kichHoat: "The user taps +."),
        uc(4, "Receive a push notification for a mention", feature: "Notifications", status: "DRAFT", actor: 1, pri: "MEDIUM",
           missing: ["postconditions", "normal flow"], mo: "A member is mentioned in a comment and gets a push notification."),
        uc(6, "Export the sprint report as PDF", feature: "Reports", status: "PROPOSED", actor: 2, pri: "LOW",
           missing: ["preconditions"], ai: true, mo: "The lead exports the sprint report to share with the lecturer.",
           luong: "1. The lead opens Reports.\n2. The lead taps Export → PDF.\n3. The system generates the file."),
    ]

    static let rules: [[String: Any]] = [
        ["id": 11, "number": 1, "key": "BR-01", "name": "Accounts lock after 5 failed sign-ins",
         "definition": "After 5 consecutive failed attempts the account is locked for 15 minutes.", "category": "Security",
         "status": "APPROVED", "usedIn": ["UC-01"]],
        ["id": 12, "number": 2, "key": "BR-02", "name": "Attachments are limited to 25 MB",
         "definition": "Any single attachment larger than 25 MB is rejected.", "category": "Constraint", "status": "APPROVED", "usedIn": ["UC-03"]],
        ["id": 13, "number": 3, "key": "BR-03", "name": "Only editors can attach files",
         "definition": "Viewers and clients cannot add attachments.", "category": "Access", "status": "DRAFT", "usedIn": ["UC-03"]],
        ["id": 14, "number": 4, "key": "BR-04", "name": "Reports keep 12 months of history",
         "definition": NSNull(), "category": NSNull(), "status": "PROPOSED", "usedIn": [Any]()],
    ]

    static let srs: [String: Any] = [
        "key": "NW",
        "actors": [["id": 1, "name": "Team member", "description": "Works on issues day to day", "kind": "PERSON", "position": 0],
                   ["id": 2, "name": "Project lead", "description": "Plans sprints and reports to the client", "kind": "PERSON", "position": 1],
                   ["id": 3, "name": "Apple ID", "description": "Sign in with Apple identity provider", "kind": "SYSTEM", "position": 2]],
        "useCases": useCases,
        "rules": rules,
        "screens": [["id": 1, "name": "Sign in", "feature": "Accounts", "description": "Email, password and Sign in with Apple", "position": 0],
                    ["id": 2, "name": "My Work", "feature": "Issues", "description": "Issues assigned to me, grouped by due date", "position": 1],
                    ["id": 3, "name": "Issue detail", "feature": "Issues", "description": NSNull(), "position": 2],
                    ["id": 4, "name": "Sprint report", "feature": "Reports", "description": NSNull(), "position": 3]],
        "links": [["fromId": 1, "toId": 2, "label": "signed in"], ["fromId": 2, "toId": 3, "label": "open issue"],
                  ["fromId": 2, "toId": 4, "label": NSNull()]],
        "auth": [[1, 1], [1, 2], [2, 1], [2, 2], [3, 1], [3, 2], [4, 2]],
        "functions": [["id": 1, "feature": "Notifications", "name": "Daily digest email", "description": "Sends a summary of due issues at 08:00.", "position": 0],
                      ["id": 2, "feature": "Integrations", "name": "GitHub webhook", "description": "Moves issues when a PR mentioning the key is merged.", "position": 1]],
        "report3Page": ["number": 5, "title": "Report 3 — SRS"],
        "canEdit": true, "canApprove": true,
        "counts": ["useCases": 4, "proposed": 1, "approved": 1, "rules": 4, "screens": 4],
    ]

    // MARK: RTM

    static func dongRtm(_ id: String, kind: String, uc: Int?, issue: Int?, _ ten: String, status: String, gaps: [String], tests: Int, bugs: Int) -> [String: Any] {
        var d: [String: Any] = ["reqId": id, "kind": kind, "requirement": ten, "feature": "Accounts", "rules": ["BR-01"],
                                "srs": ["2.1.1"], "screens": ["Sign in"], "sds": [Any](), "classMethod": [Any](),
                                "integration": [Any](), "system": [Any](), "iteration": "Sprint 6", "issueDone": false,
                                "ucMissing": [Any](), "status": status, "gaps": gaps]
        d["ucNumber"] = uc.map { $0 as Any } ?? NSNull()
        d["issueNumber"] = issue.map { $0 as Any } ?? NSNull()
        d["issueKey"] = issue.map { "NW-\($0)" as Any } ?? NSNull()
        d["code"] = ["commits": 4, "prs": 1, "branches": 1, "latest": NSNull()] as [String: Any]
        let unit: [String: Any] = ["name": "AuthService", "cases": tests, "passed": max(0, tests - 1), "failed": tests > 0 ? 1 : 0, "notRun": 0]
        d["unit"] = [unit]
        d["xray"] = [["key": "NW-40", "title": "Login with valid credentials", "last": "PASS"]]
        let bug: [String: Any] = ["key": "NW-14", "title": "HEIC crash", "open": true, "severity": "MAJOR"]
        d["bugs"] = bugs > 0 ? [bug] : [Any]()
        return d
    }

    static let rtm: [String: Any] = [
        "rows": [dongRtm("UC-01", kind: "UC", uc: 1, issue: 12, "Sign in with email or Apple", status: "Tested", gaps: [], tests: 6, bugs: 0),
                 dongRtm("UC-03", kind: "UC", uc: 3, issue: 14, "Attach a photo to an issue", status: "Coded", gaps: ["FAILING", "OPEN_BUGS"], tests: 3, bugs: 1),
                 dongRtm("UC-04", kind: "UC", uc: 4, issue: nil, "Receive a push notification", status: "Analyzed", gaps: ["UC_INCOMPLETE", "NO_ISSUE", "NO_TEST"], tests: 0, bugs: 0)],
        "summary": ["rows": 3, "useCases": 3, "requirements": 0, "withTests": 2, "testedPct": 66.7, "passing": 1, "withGaps": 2,
                    "gaps": ["FAILING": 1, "OPEN_BUGS": 1, "UC_INCOMPLETE": 1, "NO_ISSUE": 1, "NO_TEST": 1]],
        "rules": [Any](), "orphans": [Any](),
        "gapLabels": ["UC_INCOMPLETE": "UC incomplete", "NO_ISSUE": "No issue", "NO_SRS": "Not in SRS", "NO_SDS": "No design",
                      "NO_CODE": "No code", "NO_TEST": "No tests", "NOT_RUN": "Not run", "FAILING": "Failing",
                      "OPEN_BUGS": "Open bugs", "NO_SEQUENCE": "No sequence"],
        "sixLinks": NSNull(),
    ]

    // MARK: Wiegers

    static func yc(_ n: Int, _ ten: String, _ text: String, type: String?, lc: String, pri: String?, next: [String], src: String? = nil) -> [String: Any] {
        ["issueId": 900 + n, "number": n, "key": "NW-\(n)", "title": ten, "text": text, "parentId": NSNull(),
         "status": ["name": lc == "IMPLEMENTED" ? "Done" : "To Do", "category": lc == "IMPLEMENTED" ? "DONE" : "TODO"],
         "classified": type != nil, "reqType": type ?? NSNull(), "subtype": type == "QUALITY" ? "PERFORMANCE" : NSNull() as Any,
         "priority": pri ?? NSNull(), "lifecycle": lc, "source": src ?? NSNull(), "ownerId": 2,
         "rationale": n == 31 ? "Lecturers check the PDF report every sprint review." : NSNull() as Any,
         "stability": "MEDIUM", "reqVersion": 2, "updatedAt": G.iso(-2), "next": next]
    }

    static let dsYeuCau: [[String: Any]] = [
        yc(31, "Export the sprint report as PDF", "The system shall let a project lead export the sprint report as a PDF in under 10 seconds.",
           type: "FUNCTIONAL", lc: "PROPOSED", pri: "HIGH", next: ["APPROVED", "REJECTED", "DELETED"], src: "Interview ELC-2 · Lecturer"),
        yc(32, "Sign-in under 2 seconds", "Sign-in shall complete within 2 seconds for 95% of attempts on 4G.",
           type: "QUALITY", lc: "APPROVED", pri: "MEDIUM", next: ["IMPLEMENTED", "DELETED"]),
        yc(33, "Reduce missed deadlines by 30%", "The product shall reduce missed issue deadlines by 30% within one semester.",
           type: "BUSINESS", lc: "APPROVED", pri: "HIGH", next: ["IMPLEMENTED", "DELETED"]),
        yc(34, "Attach photos from the camera", "A member shall be able to attach a photo taken with the camera to an issue.",
           type: "USER", lc: "IMPLEMENTED", pri: "MEDIUM", next: ["VERIFIED", "APPROVED", "DELETED"]),
        yc(35, "Offline reading of My Work", "My Work should be readable without a connection.", type: nil, lc: "PROPOSED", pri: nil,
           next: ["APPROVED", "REJECTED", "DELETED"]),
    ]

    static let yeuCau: [String: Any] = [
        "key": "NW", "canEdit": true, "canApprove": true, "requirements": dsYeuCau,
        "counts": ["total": 5, "unclassified": 1,
                   "byType": ["BUSINESS": 1, "USER": 1, "FUNCTIONAL": 1, "QUALITY": 1, "CONSTRAINT": 0, "EXTERNAL_INTERFACE": 0, "DATA": 0],
                   "byLifecycle": ["PROPOSED": 2, "APPROVED": 2, "IMPLEMENTED": 1, "VERIFIED": 0, "DELETED": 0, "REJECTED": 0]],
        "owners": [["id": 1, "name": "Alex Morgan"], ["id": 2, "name": "Linh Tran"]],
        "qualityAttrs": ["PERFORMANCE", "SECURITY"], "interfaceKinds": ["USER", "SOFTWARE"], "dataKinds": ["REPORT"],
    ]

    static let lichSu: [[String: Any]] = [
        ["id": 3, "field": "lifecycle", "from": NSNull(), "to": "PROPOSED", "at": G.iso(-6), "actor": "Scout", "actorKind": "AGENT"],
        ["id": 4, "field": "priority", "from": "MEDIUM", "to": "HIGH", "at": G.iso(-3), "actor": "Linh Tran", "actorKind": "HUMAN"],
        ["id": 5, "field": "source", "from": NSNull(), "to": "Interview ELC-2", "at": G.iso(-2), "actor": "Alex Morgan", "actorKind": "HUMAN"],
    ]

    static let tinhNang: [String: Any] = [
        "key": "NW", "canEdit": true,
        "releases": [["id": 1, "name": "v1.0", "releaseDate": G.iso(20), "status": "UNRELEASED", "position": 0]],
        "features": [
            ["id": 1, "number": 1, "key": "FE-1", "name": "Accounts & sign-in", "description": "Email and Sign in with Apple, account deletion.",
             "scope": "IN", "priority": "HIGH", "versionId": 1, "epicIssueId": NSNull(), "position": 0, "release": "v1.0",
             "epic": ["number": 10, "key": "NW-10", "title": "Accounts"],
             "useCases": [["number": 1, "key": "UC-01", "name": "Sign in with email or Apple", "status": "APPROVED", "manual": false, "linkId": NSNull()]],
             "issues": [Any](), "realized": true],
            ["id": 2, "number": 2, "key": "FE-2", "name": "Issue evidence", "description": "Photos and files attached to issues.",
             "scope": "IN", "priority": "MEDIUM", "versionId": 1, "epicIssueId": NSNull(), "position": 1, "release": "v1.0", "epic": NSNull(),
             "useCases": [["number": 3, "key": "UC-03", "name": "Attach a photo to an issue", "status": "DRAFT", "manual": false, "linkId": NSNull()]],
             "issues": [["linkId": 5, "number": 14, "key": "NW-14", "title": "Crash when attaching a HEIC photo", "type": "BUG"]], "realized": false],
            ["id": 3, "number": 3, "key": "FE-3", "name": "Offline editing", "description": "Deferred to v2.", "scope": "OUT", "priority": "LOW",
             "versionId": NSNull(), "epicIssueId": NSNull(), "position": 2, "release": NSNull(), "epic": NSNull(),
             "useCases": [Any](), "issues": [Any](), "realized": false],
        ],
    ]

    static func sh(_ id: Int, _ ten: String, role: String, org: String, inf: Int, intr: Int, q: String, att: String, champ: Bool = false) -> [String: Any] {
        ["id": id, "number": id, "key": "SH-\(id)", "name": ten, "role": role, "organization": org, "kind": "PERSON", "userClass": NSNull(),
         "influence": inf, "interest": intr, "attitude": att, "isChampion": champ, "decisionRights": champ ? "Approves the SRS baseline" : NSNull() as Any,
         "majorValue": NSNull(), "interests": "Clear progress every sprint", "constraints": NSNull(), "contact": NSNull(), "notes": NSNull(),
         "actorId": NSNull(), "userId": NSNull(), "position": id, "rev": 1, "quadrant": q, "sessions": ["ELC-2"], "requirements": 2]
    }

    static let benLQ: [String: Any] = [
        "stakeholders": [sh(1, "Dr. Hoang", role: "Lecturer", org: "FPT University", inf: 5, intr: 5, q: "MANAGE_CLOSELY", att: "CHAMPION", champ: true),
                         sh(2, "Northwind PM", role: "Client", org: "Northwind", inf: 5, intr: 2, q: "KEEP_SATISFIED", att: "SUPPORTER"),
                         sh(3, "Students", role: "End users", org: "Class SE1801", inf: 2, intr: 5, q: "KEEP_INFORMED", att: "NEUTRAL"),
                         sh(4, "IT office", role: "Operations", org: "FPT University", inf: 2, intr: 1, q: "MONITOR", att: "NEUTRAL")],
        "grid": ["MANAGE_CLOSELY": ["SH-1"], "KEEP_SATISFIED": ["SH-2"], "KEEP_INFORMED": ["SH-3"], "MONITOR": ["SH-4"]],
        "warnings": [Any](), "actors": [Any](), "members": [Any](), "canEdit": true, "canConfigure": true,
    ]

    static let thuatNgu: [String: Any] = [
        "terms": [["id": 1, "projectId": 7, "term": "Issue", "definition": "A unit of work tracked on the board (story, task or bug).",
                   "aliases": ["Card", "Ticket"], "source": "Team", "createdById": 1, "createdAt": G.iso(-20), "updatedAt": G.iso(-20)],
                  ["id": 2, "projectId": 7, "term": "Sprint", "definition": "A fixed two-week iteration with a goal.",
                   "aliases": [Any](), "source": "Scrum Guide 2020", "createdById": 1, "createdAt": G.iso(-20), "updatedAt": G.iso(-20)],
                  ["id": 3, "projectId": 7, "term": "Evidence", "definition": "A photo or file proving a test result.",
                   "aliases": [Any](), "source": NSNull(), "createdById": 2, "createdAt": G.iso(-5), "updatedAt": G.iso(-5)]],
        "clashes": [Any](), "canEdit": true,
    ]

    static let phien: [String: Any] = [
        "sessions": [["number": 2, "key": "ELC-2", "title": "Interview with the lecturer", "technique": "INTERVIEW", "status": "DONE",
                      "scheduledAt": G.iso(-4), "durationMin": 45, "aiSimulated": false, "meetingId": NSNull(), "surveyId": NSNull(),
                      "participants": [["key": "SH-1", "name": "Dr. Hoang", "role": "Lecturer", "rolePlayed": NSNull()]],
                      "questions": 4, "answered": 3, "requirements": 1, "pending": 1],
                     ["number": 3, "key": "ELC-3", "title": "Student workshop", "technique": "WORKSHOP", "status": "PLANNED",
                      "scheduledAt": G.iso(3), "durationMin": 60, "aiSimulated": false, "meetingId": NSNull(), "surveyId": NSNull(),
                      "participants": [Any](), "questions": 5, "answered": 0, "requirements": 0, "pending": 0]],
        "techniques": ["INTERVIEW", "WORKSHOP", "SURVEY", "OBSERVATION", "DOCUMENT_ANALYSIS", "PROTOTYPE"],
        "questionBank": [String: Any](), "canEdit": true, "canApprove": true,
    ]

    static let phienChiTiet: [String: Any] = [
        "number": 2, "key": "ELC-2", "title": "Interview with the lecturer", "technique": "INTERVIEW", "status": "DONE",
        "scheduledAt": G.iso(-4), "durationMin": 45, "location": "Room 304", "objective": "Learn what the lecturer checks at each sprint review.",
        "plan": "1. Current pain points\n2. Reports\n3. Grading", "rev": 2, "aiSimulated": false,
        "questions": [["id": "q1", "text": "What do you check in a sprint review?", "answer": "Burndown, finished stories and the demo video."],
                      ["id": "q2", "text": "Which format do you prefer for reports?", "answer": "PDF — I read them on my iPad."],
                      ["id": "q3", "text": "How often do teams miss deadlines?", "answer": "About a third of issues are late."],
                      ["id": "q4", "text": "Who approves the SRS?", "answer": NSNull()]],
        "notes": "The lecturer wants **one PDF per sprint**.", "outcome": NSNull(),
        "meeting": NSNull(), "survey": NSNull(), "sourceText": "",
        "participants": [["stakeholderId": 1, "key": "SH-1", "name": "Dr. Hoang", "role": "Lecturer", "rolePlayed": NSNull(), "userId": NSNull()]],
        "proposals": [["id": 5, "title": "Export the sprint report as PDF", "text": "The lead can export the sprint report as a PDF.",
                       "reqType": "FUNCTIONAL", "priority": "HIGH", "status": "ACCEPTED", "model": NSNull(),
                       "stakeholder": ["key": "SH-1", "name": "Dr. Hoang"], "evidence": [["line": 4, "quote": "PDF — I read them on my iPad."]], "issue": "NW-31"],
                      ["id": 6, "title": "Show late issues in red on the board", "text": NSNull(), "reqType": "USER", "priority": "MEDIUM",
                       "status": "PENDING", "model": "gpt-5.4-mini", "stakeholder": NSNull(), "evidence": [["line": 6, "quote": "About a third of issues are late."]],
                       "issue": NSNull()]],
        "requirements": [["originId": 1, "key": "NW-31", "number": 31, "title": "Export the sprint report as PDF", "lifecycle": "PROPOSED",
                          "stakeholder": ["key": "SH-1", "name": "Dr. Hoang"], "note": NSNull()]],
        "questionBank": [Any](), "canEdit": true, "canApprove": true,
    ]

    static let nfr: [String: Any] = [
        "requirements": [["number": 32, "key": "NW-32", "title": "Sign-in under 2 seconds", "text": "Sign-in shall complete within 2 seconds.",
                          "subtype": "PERFORMANCE", "priority": "MEDIUM", "lifecycle": "APPROVED",
                          "spec": ["characteristic": "PERFORMANCE_EFFICIENCY", "subCharacteristic": "Time behaviour", "scale": "Seconds from tap to My Work",
                                   "meter": "95th percentile in TestFlight analytics", "unit": "s", "comparator": "<=", "mustValue": 3, "planValue": 2,
                                   "wishValue": NSNull(), "conditions": "4G network", "verification": "TEST"],
                          "statement": "95% of sign-ins complete in ≤ 2 s (must ≤ 3 s) on 4G.", "suggestedCharacteristic": NSNull()],
                         ["number": 36, "key": "NW-36", "title": "Data is encrypted in transit", "text": "All traffic uses TLS 1.2+.",
                          "subtype": "SECURITY", "priority": "HIGH", "lifecycle": "PROPOSED", "spec": NSNull(), "statement": NSNull(),
                          "suggestedCharacteristic": "SECURITY"]],
        "characteristics": [["key": "PERFORMANCE_EFFICIENCY", "label": "Performance efficiency", "subs": ["Time behaviour"]],
                            ["key": "SECURITY", "label": "Security", "subs": ["Confidentiality"]]],
        "templates": [Any](), "comparators": ["<=", ">=", "="], "verifications": ["TEST", "ANALYSIS", "INSPECTION", "DEMONSTRATION"],
        "measured": 1, "canEdit": true,
    ]

    static let mau: [String: Any] = [
        "screens": [["id": 1, "name": "Sign in", "feature": "Accounts", "approved": true,
                     "mockups": [["id": 1, "screenId": 1, "screen": "Sign in", "kind": "LINK", "url": "https://www.figma.com/file/abc",
                                  "provider": "Figma", "title": "Sign in v3", "image": NSNull(), "status": "APPROVED", "reviewerName": "Dr. Hoang",
                                  "reviewerRole": "LECTURER", "reviewNote": "Clear and simple.", "reviewedAt": G.iso(-3), "shared": false,
                                  "reviewPath": NSNull(), "createdAt": G.iso(-8), "updatedAt": G.iso(-3)]]],
                    ["id": 2, "name": "My Work", "feature": "Issues", "approved": false,
                     "mockups": [["id": 2, "screenId": 2, "screen": "My Work", "kind": "LINK", "url": "https://www.figma.com/file/def",
                                  "provider": "Figma", "title": "My Work grouped by due date", "image": NSNull(), "status": "SUBMITTED",
                                  "reviewerName": NSNull(), "reviewerRole": NSNull(), "reviewNote": NSNull(), "reviewedAt": NSNull(),
                                  "shared": true, "reviewPath": NSNull(), "createdAt": G.iso(-2), "updatedAt": G.iso(-2)]]],
                    ["id": 3, "name": "Issue detail", "feature": "Issues", "approved": false, "mockups": [Any]()]],
        "counts": ["screens": 3, "withPrototype": 2, "approved": 1], "canEdit": true, "canReview": true, "canShare": true,
    ]
}
#endif
