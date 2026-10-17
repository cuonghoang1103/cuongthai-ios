#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng "dịch vụ": Service desk · Intake · Forms · Cổng khách · Lớp học · Nộp sản phẩm
//
// Hình dạng theo `serviceDesk.service.ts`, `intake.service.ts`, `forms.service.ts`,
// `portal.service.ts`, `classwork/classStream/teaching.service.ts`, `submitGate.ts`
// (kiểu TS ở `frontend/src/lib/work-s5a-api.ts`, `work-ctw7b-api.ts`, `components/work/teaching|classroom`).
// Nối vào `DuLieuGiaMoDun.boXuLy`. ⚠️ Cả tệp trong `#if DEBUG` (CLAUDE.md A6).

enum DuLieuGiaDichVu {
    typealias D = DuLieuGia
    static let khach: [String: Any] = D.nguoi(31, "an.client", "An Client")
    static let khach2: [String: Any] = D.nguoi(32, "binh.client", "Binh Le")

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        let pr = "/work/projects/7"
        switch (m, p) {
        // ── Service desk
        case ("GET", pr + "/desk/queue"): return hangCho
        case ("GET", pr + "/issues/52/desk"), ("PATCH", pr + "/issues/52/desk"), ("POST", pr + "/issues/52/desk/waiting"):
            return ticket(b)
        case ("GET", pr + "/issues/52"), ("POST", pr + "/issues/52/move"), ("PATCH", pr + "/issues/52"):
            var c = D.chiTiet(so: 52, tieuDe: "Login fails on iOS after the 2.3 update")
            c["typeId"] = 4; c["statusId"] = (b["statusId"] as? Int) ?? 2; c["assigneeId"] = 2; c["assignee"] = D.linh
            c["reporter"] = khach; c["children"] = [Any](); c["links"] = [Any](); c["attachments"] = [Any]()
            c["descriptionJson"] = D.doc(["Since this morning, signing in on iPhone shows “Something went wrong”. Android and web are fine.",
                                          "Steps: open the app → Sign in → enter email + password → tap Continue."])
            return c
        case ("GET", pr + "/issues/52/comments"): return binhLuanTicket
        case ("POST", pr + "/issues/52/comments"):
            return ["id": 990, "bodyJson": b["bodyJson"] ?? NSNull(), "isAi": false, "visibility": b["visibility"] ?? "PUBLIC",
                    "createdAt": D.iso(0), "author": D.toi]
        // ── Intake
        case ("GET", pr + "/intake/proposals"): return deXuat
        // ── Forms
        case ("GET", pr + "/forms"): return dsForm
        case ("GET", pr + "/forms/3/responses"): return traLoiForm
        // ── Cổng khách
        case ("GET", pr + "/portal/overview"): return portalTongQuan
        case ("GET", pr + "/portal/requests"): return ["viewer": nguoiXem, "items": portalYeuCau]
        case ("GET", pr + "/portal/approvals"): return ["viewer": nguoiXem, "items": portalDuyet]
        case ("GET", pr + "/portal/documents"): return portalTaiLieu
        // ── Lớp học
        case ("GET", "/work/classes"): return dsLop
        case ("GET", "/work/classes/4"): return lop
        case ("GET", "/work/teaching/access"): return ["teaching": true, "projects": 3, "classes": 1]
        case ("GET", "/work/teaching/overview"): return giangDay
        case ("GET", "/work/classes/4/assignments"): return baiTap
        case ("GET", "/work/classes/4/assignments/12"): return baiTapCT
        case ("GET", "/work/classes/4/stream"): return bangTin
        // ── Nộp sản phẩm
        case ("GET", pr + "/submissions"): return nopSanPham
        default: break
        }
        if m == "POST", p.hasPrefix(pr + "/intake/proposals/"), p.hasSuffix("/decide") {
            var d = (deXuat["proposals"] as? [[String: Any]])?.first ?? [:]
            let nhan = (b["decision"] as? String) == "ACCEPT"
            d["status"] = nhan ? "ACCEPTED" : "REJECTED"
            d["decidedBy"] = "Alex Morgan"; d["decidedAt"] = D.iso(0)
            if nhan { d["issue"] = ["number": 44, "key": "NW-44"] }
            return d
        }
        if m == "GET", p.hasPrefix(pr + "/portal/requests/") {
            return portalYeuCauCT
        }
        if m == "GET", p.hasPrefix(pr + "/portal/documents/") {
            return ["number": 5, "title": "Store listing checklist", "status": "APPROVED", "visibility": "CLIENT",
                    "contentJson": D.doc(["Everything we need from you before submitting to the App Store.",
                                          "1. Final app name and subtitle", "2. Privacy policy URL", "3. Five screenshots per device size"]),
                    "updatedAt": D.iso(-2)]
        }
        if m == "GET", p.hasPrefix("/work/classes/4/files/") {
            return ["url": "https://example.com/file.pdf", "fileName": "lab3-template.pdf"]
        }
        return nil
    }

    // MARK: Service desk

    static func sla(_ status: String, _ label: String, due: Double?, paused: Bool = false, stopped: Bool = false) -> [String: Any] {
        ["goalMin": 480, "calendar": "BUSINESS", "elapsedMin": 300, "remainingMin": status == "BREACHED" ? -35 : 180,
         "status": status, "stopped": stopped, "paused": paused,
         "dueAt": due.map { D.iso(0, gio: $0) } ?? NSNull(), "atRiskAt": NSNull(), "breachedAt": status == "BREACHED" ? D.iso(0, gio: -0.6) : NSNull(),
         "stoppedAt": stopped ? D.iso(-1) : NSNull(), "label": label]
    }

    static func muc(_ so: Int, _ t: String, loai: String, ten: String, p: String, st: (Int, String, String), ai: [String: Any]?,
                    fr: [String: Any], res: [String: Any], waiting: Bool = false, kenh: String = "PORTAL") -> [String: Any] {
        ["number": so, "key": "NW-\(so)", "title": t, "requestType": loai, "requestTypeName": ten, "priority": p,
         "waiting": waiting, "paused": waiting, "channel": kenh, "shared": true,
         "status": ["id": st.0, "name": st.1, "category": st.2, "color": NSNull()], "team": NSNull(),
         "assignee": ai ?? NSNull(), "requester": khach, "createdAt": D.iso(-1), "updatedAt": D.iso(0, gio: -1), "resolvedAt": NSNull(),
         "firstResponse": fr, "resolution": res, "problemId": NSNull(), "csat": NSNull()]
    }

    static let hangCho: [String: Any] = [
        "view": "open", "counts": ["open": 6, "unassigned": 1, "mine": 2, "at_risk": 2, "breached": 1, "waiting": 1, "team": 0, "resolved": 14],
        "canWork": true, "now": D.iso(0), "teams": [Any](), "truncated": false,
        "items": [
            muc(52, "Login fails on iOS after the 2.3 update", loai: "INCIDENT", ten: "Incident", p: "P2", st: (2, "In Progress", "IN_PROGRESS"),
                ai: D.linh, fr: sla("MET", "Met", due: nil, stopped: true), res: sla("AT_RISK", "2h 10m left", due: 2.2)),
            muc(45, "Invoice PDF shows the wrong VAT rate", loai: "INCIDENT", ten: "Incident", p: "P1", st: (1, "To Do", "TODO"),
                ai: nil, fr: sla("BREACHED", "35m over", due: -0.6), res: sla("ON_TRACK", "6h left", due: 6)),
            muc(47, "Add two more admin seats for the finance team", loai: "SERVICE_REQUEST", ten: "Service request", p: "P3",
                st: (2, "In Progress", "IN_PROGRESS"), ai: D.toi, fr: sla("MET", "Met", due: nil, stopped: true),
                res: sla("ON_TRACK", "Paused", due: nil, paused: true), waiting: true),
            muc(48, "How do we export last month's report?", loai: "QUESTION", ten: "Question", p: "P4", st: (1, "To Do", "TODO"),
                ai: D.scout, fr: sla("ON_TRACK", "3h 20m left", due: 3.3), res: sla("ON_TRACK", "1d 6h left", due: 30), kenh: "STAFF"),
        ],
    ]

    static func ticket(_ b: [String: Any]) -> [String: Any] {
        ["enabled": true, "canWork": true,
         "requestTypes": [["key": "INCIDENT", "name": "Incident", "enabled": true], ["key": "QUESTION", "name": "Question", "enabled": true]],
         "matrix": ["HIGH": ["HIGH": "P1", "MEDIUM": "P2", "LOW": "P3"]],
         "targets": ["P2": ["respond": "2h", "resolve": "8h"]],
         "ticket": [
            "requestType": "INCIDENT", "requestTypeName": "Incident", "impact": "HIGH", "urgency": b["urgency"] ?? "MEDIUM",
            "priority": b["priority"] ?? "P2", "channel": "PORTAL", "requester": khach,
            "fields": [["key": "device", "label": "Device", "value": "iPhone 15 · iOS 17.6"], ["key": "users", "label": "Users affected", "value": 120]],
            "waiting": b["waiting"] ?? false, "waitingSince": NSNull(), "firstResponseAt": D.iso(-0.9), "firstResponseBy": "Linh Tran",
            "paused": false, "firstResponse": sla("MET", "Met", due: nil, stopped: true), "resolution": sla("AT_RISK", "2h 10m left", due: 2.2),
            "problem": NSNull(), "changeRequest": NSNull(), "csat": ["requestedAt": NSNull(), "rating": NSNull(), "comment": NSNull(), "at": NSNull()],
            "events": [["id": 1, "kind": "START", "at": D.iso(-1), "value": NSNull(), "note": NSNull(), "actor": "An Client"],
                       ["id": 2, "kind": "FIRST_RESPONSE", "at": D.iso(-0.9), "value": NSNull(), "note": NSNull(), "actor": "Linh Tran"],
                       ["id": 3, "kind": "PRIORITY", "at": D.iso(-0.8), "value": "P2", "note": "Impact raised to High", "actor": "Linh Tran"]],
            "createdAt": D.iso(-1),
         ]]
    }

    static let binhLuanTicket: [[String: Any]] = [
        ["id": 701, "bodyJson": D.doc(["Hi team — none of our iPhone users can sign in since this morning. Please help!"]), "isAi": false,
         "visibility": "PUBLIC", "createdAt": D.iso(-1), "author": khach],
        ["id": 702, "bodyJson": D.doc(["Thanks An, we're on it. Could you tell us which app version you see under Settings → About?"]), "isAi": false,
         "visibility": "PUBLIC", "createdAt": D.iso(-0.9), "author": D.linh],
        ["id": 703, "bodyJson": D.doc(["Looks like the token refresh fails on iOS only — the 2.3 build ships the old auth host. Checking with backend."]),
         "isAi": false, "visibility": "INTERNAL", "createdAt": D.iso(-0.5), "author": D.minh],
        ["id": 704, "bodyJson": D.doc(["Found 3 matching crash reports in the last 12h; all on 2.3.0 (build 214)."]), "isAi": true,
         "visibility": "INTERNAL", "createdAt": D.iso(-0.3), "author": D.scout],
    ]

    // MARK: Intake

    static let deXuat: [String: Any] = [
        "canDecide": true, "counts": ["PENDING": 3, "ACCEPTED": 12, "REJECTED": 2],
        "proposals": [
            ["id": 88, "source": "EMAIL", "channelId": 3, "title": "Invoice page returns 500", "body": "Hi,\nSince this morning the invoice page shows an error 500 when we open last month's invoices.\nThanks, Minh",
             "senderName": "Minh Vo", "senderHandle": "minh@acme.example", "sender": NSNull(), "status": "PENDING", "simulated": false,
             "createdAt": D.iso(0, gio: -2), "issue": NSNull(), "decidedBy": NSNull(), "decidedAt": NSNull(), "decisionNote": NSNull(), "meta": NSNull()],
            ["id": 89, "source": "DISCORD", "channelId": 4, "title": "Dark mode toggle missing on iPad", "body": "The toggle is gone after the last update on my iPad Air.",
             "senderName": "kai#2231", "senderHandle": "kai#2231", "sender": NSNull(), "status": "PENDING", "simulated": false,
             "createdAt": D.iso(0, gio: -5), "issue": NSNull(), "decidedBy": NSNull(), "decidedAt": NSNull(), "decisionNote": NSNull(), "meta": NSNull()],
            ["id": 90, "source": "ZALO", "channelId": 5, "title": "Cần thêm báo cáo theo tuần", "body": "Anh ơi bên em cần xuất báo cáo theo tuần chứ không chỉ theo tháng.",
             "senderName": "Lan", "senderHandle": NSNull(), "sender": NSNull(), "status": "PENDING", "simulated": true,
             "createdAt": D.iso(-1), "issue": NSNull(), "decidedBy": NSNull(), "decidedAt": NSNull(), "decisionNote": NSNull(), "meta": NSNull()],
        ],
    ]

    // MARK: Forms

    static let truongForm: [[String: Any]] = [
        ["id": "f1", "kind": "select", "label": "Which area?", "help": NSNull(), "required": true, "options": ["Mobile app", "Website", "Billing"],
         "min": NSNull(), "max": NSNull(), "showIf": NSNull()],
        ["id": "f2", "kind": "longtext", "label": "What happened?", "help": "Steps and what you expected", "required": true, "options": [String](),
         "min": NSNull(), "max": NSNull(), "showIf": NSNull()],
        ["id": "f3", "kind": "number", "label": "How urgent (1–5)?", "help": NSNull(), "required": false, "options": [String](),
         "min": 1, "max": 5, "showIf": NSNull()],
    ]

    static let dsForm: [String: Any] = [
        "canEdit": true, "canPublish": true,
        "forms": [
            ["id": 3, "number": 3, "key": "F-3", "title": "Bug report", "description": "Tell us what went wrong — every response becomes an issue.",
             "fields": truongForm, "mapping": ["typeKey": "BUG", "titleTemplate": NSNull(), "labelIds": [Int](), "assigneeId": NSNull(), "priority": NSNull(), "customFields": [String: Any]()],
             "access": "PUBLIC", "status": "OPEN", "confirmMessage": NSNull(), "collectEmail": true, "maxResponses": NSNull(), "closesAt": NSNull(),
             "link": "https://cuongthai.com/work/form/abc123", "closed": NSNull(), "responses": 3, "rev": 4, "createdAt": D.iso(-20), "updatedAt": D.iso(-2)],
            ["id": 4, "number": 4, "key": "F-4", "title": "Beta tester sign-up", "description": NSNull(), "fields": [Any](),
             "mapping": ["typeKey": NSNull(), "titleTemplate": NSNull(), "labelIds": [Int](), "assigneeId": NSNull(), "priority": NSNull(), "customFields": [String: Any]()],
             "access": "INTERNAL", "status": "CLOSED", "confirmMessage": NSNull(), "collectEmail": false, "maxResponses": 50, "closesAt": NSNull(),
             "link": NSNull(), "closed": "FULL", "responses": 50, "rev": 2, "createdAt": D.iso(-40), "updatedAt": D.iso(-9)],
        ],
    ]

    static let traLoiForm: [String: Any] = [
        "form": ["key": "F-3", "title": "Bug report", "fields": truongForm], "total": 3,
        "summary": [
            ["id": "f1", "label": "Which area?", "kind": "select", "answered": 3, "counts": [["option": "Mobile app", "n": 2], ["option": "Website", "n": 1], ["option": "Billing", "n": 0]]],
            ["id": "f2", "label": "What happened?", "kind": "longtext", "answered": 3, "samples": ["The login button does nothing on iPad.", "Charts are blank in Safari."]],
            ["id": "f3", "label": "How urgent (1–5)?", "kind": "number", "answered": 2, "average": 3.5, "min": 2, "max": 5],
        ],
        "responses": [
            ["id": 31, "createdAt": D.iso(0, gio: -3), "issue": ["number": 41, "key": "NW-41"], "respondent": NSNull(), "email": "kai@example.com",
             "answers": ["f1": "Mobile app", "f2": "The login button does nothing on iPad.", "f3": 5]],
            ["id": 30, "createdAt": D.iso(-1), "issue": ["number": 39, "key": "NW-39"], "respondent": "Sara Kim", "email": NSNull(),
             "answers": ["f1": "Website", "f2": "Charts are blank in Safari.", "f3": 2]],
        ],
    ]

    // MARK: Cổng khách

    static let nguoiXem: [String: Any] = ["clientView": true, "preview": true, "isClient": false, "canManage": true, "canInvite": true,
                                          "canRequestUat": true, "canSubmitRequest": false]

    static let portalTongQuan: [String: Any] = [
        "project": ["key": "NW", "name": "Mobile App Launch", "description": "iOS + Android app for Northwind customers.",
                    "workspaceName": "Northwind Studio", "organization": "Acme Retail"],
        "viewer": nguoiXem, "overallPercent": 62,
        "stages": [["id": 1, "n": 1, "name": "Discovery", "status": "DONE", "percent": 100, "startedAt": D.iso(-60), "completedAt": D.iso(-40)],
                   ["id": 2, "n": 2, "name": "Design", "status": "DONE", "percent": 100, "startedAt": D.iso(-40), "completedAt": D.iso(-20)],
                   ["id": 3, "n": 3, "name": "Build & beta", "status": "ACTIVE", "percent": 58, "startedAt": D.iso(-20), "completedAt": NSNull()],
                   ["id": 4, "n": 4, "name": "Launch", "status": "NOT_STARTED", "percent": 0, "startedAt": NSNull(), "completedAt": NSNull()]],
        "milestones": [["id": 9, "name": "Public beta", "status": "UNRELEASED", "releaseDate": D.iso(8), "releasedAt": NSNull(), "items": 14, "done": 9]],
        "waitingOnClient": [["id": 41, "title": "Approve beta build 2.3 (UAT)", "kind": "UAT", "dueAt": D.iso(2), "createdAt": D.iso(-1)],
                            ["id": 40, "title": "Sign off the store listing copy", "kind": "APPROVAL", "dueAt": D.iso(-1), "createdAt": D.iso(-4)]],
        "counts": ["sharedOpen": 8, "sharedDone": 23, "requestsOpen": 3],
    ]

    static let portalYeuCau: [[String: Any]] = [
        ["number": 52, "key": "NW-52", "title": "Login fails on iOS after the 2.3 update", "priority": 2,
         "type": ["key": "BUG", "name": "Bug", "icon": "bug", "color": "#dc2626"], "status": ["name": "In Progress", "category": "IN_PROGRESS", "color": NSNull()],
         "stage": "Build & beta", "fromClient": true, "mine": true, "replies": 2, "files": 1, "createdAt": D.iso(-1), "updatedAt": D.iso(0, gio: -1),
         "resolvedAt": NSNull(), "sharedAt": D.iso(-1)],
        ["number": 19, "key": "NW-19", "title": "iPad split view layout", "priority": 2,
         "type": ["key": "STORY", "name": "Story", "icon": "story", "color": "#16a34a"], "status": ["name": "Done", "category": "DONE", "color": NSNull()],
         "stage": "Build & beta", "fromClient": false, "mine": false, "replies": 0, "files": 2, "createdAt": D.iso(-12), "updatedAt": D.iso(-2),
         "resolvedAt": D.iso(-2), "sharedAt": D.iso(-10)],
    ]

    static let portalYeuCauCT: [String: Any] = [
        "id": 142, "number": 52, "key": "NW-52", "title": "Login fails on iOS after the 2.3 update",
        "descriptionJson": D.doc(["Since this morning, signing in on iPhone shows “Something went wrong”."]),
        "priority": 2, "createdAt": D.iso(-1), "updatedAt": D.iso(0, gio: -1), "resolvedAt": NSNull(), "clientSharedAt": D.iso(-1), "dueDate": NSNull(),
        "type": ["key": "BUG", "name": "Bug", "icon": "bug", "color": "#dc2626"], "status": ["name": "In Progress", "category": "IN_PROGRESS", "color": NSNull()],
        "stage": ["n": 3, "name": "Build & beta", "status": "ACTIVE"], "parent": NSNull(), "fixVersion": ["name": "2.3.1", "releaseDate": NSNull(), "status": "UNRELEASED"],
        "reporter": khach, "fromClient": true,
        "attachments": [["id": 61, "fileName": "screenshot-login.png", "mime": "image/png", "size": 220_331, "createdAt": D.iso(-1), "deliverable": false, "uploader": khach]],
        "comments": Array(binhLuanTicket.prefix(2)), "viewer": nguoiXem, "clientIds": [31],
    ]

    static let portalDuyet: [[String: Any]] = [
        ["id": 41, "targetType": "UAT", "title": "Approve beta build 2.3 (UAT)", "description": "Please test the five scenarios in the UAT checklist on your devices.",
         "mode": "SEQUENTIAL", "status": "PENDING", "dueAt": D.iso(2), "decidedAt": NSNull(), "createdAt": D.iso(-1), "createdBy": D.linh,
         "issue": NSNull(), "stage": NSNull(), "page": NSNull(),
         "steps": [["id": 1, "position": 0, "decision": "APPROVED", "decidedAt": D.iso(-0.5), "approver": D.linh, "isClient": false, "comment": "Internal QA passed."],
                   ["id": 2, "position": 1, "decision": "PENDING", "decidedAt": NSNull(), "approver": khach, "isClient": true, "comment": NSNull()]],
         "waitingOnClient": true, "canDecide": true, "contentChanged": false, "signedHash": NSNull(), "clientNote": "Build 214 is on TestFlight — invite sent to your email."],
        ["id": 33, "targetType": "DOC", "title": "Sign off: Release plan — v1.0", "description": NSNull(), "mode": "PARALLEL", "status": "APPROVED",
         "dueAt": NSNull(), "decidedAt": D.iso(-6), "createdAt": D.iso(-9), "createdBy": D.linh, "issue": NSNull(), "stage": NSNull(),
         "page": ["number": 3, "title": "Release plan — v1.0"],
         "steps": [["id": 3, "position": 0, "decision": "APPROVED", "decidedAt": D.iso(-6), "approver": khach2, "isClient": true, "comment": "Looks good."]],
         "waitingOnClient": false, "canDecide": false, "contentChanged": false, "signedHash": "9f2c", "clientNote": NSNull()],
    ]

    static let portalTaiLieu: [String: Any] = [
        "viewer": nguoiXem,
        "pages": [["number": 3, "title": "Release plan — v1.0", "status": "APPROVED", "updatedAt": D.iso(-6), "stage": NSNull()],
                  ["number": 5, "title": "Store listing checklist", "status": "APPROVED", "updatedAt": D.iso(-2), "stage": NSNull()]],
        "files": [["id": 70, "fileName": "beta-2.3-release-notes.pdf", "mime": "application/pdf", "size": 182_000, "createdAt": D.iso(-1),
                   "uploader": D.linh, "issue": ["number": 19, "title": "iPad split view layout", "key": "NW-19"]]],
    ]

    // MARK: Lớp học

    static let dsLop: [String: Any] = [
        "teaching": [["id": 4, "name": "SWP391 · SE1801", "subject": "SWP391", "classCode": "SE1801", "term": "FA26", "role": "TEACHER",
                      "archivedAt": NSNull(), "ownerId": 1, "teacherId": 1, "groups": 6, "students": 31]],
        "enrolled": [["id": 7, "name": "JPD113 · JS1802", "subject": "OTHER", "classCode": "JS1802", "term": "FA26", "role": "STUDENT",
                      "archivedAt": NSNull(), "ownerId": 5, "teacherId": 5, "group": ["id": 3, "name": "Team Sakura", "href": NSNull()]]],
    ]

    static let lop: [String: Any] = [
        "id": 4, "name": "SWP391 · SE1801", "subject": "SWP391", "classCode": "SE1801", "term": "FA26", "role": "TEACHER",
        "owner": D.toi, "teacher": D.toi, "maxGroupSize": 6, "week1Start": D.ngay(-30), "timezone": "Asia/Ho_Chi_Minh", "archivedAt": NSNull(),
        "joinState": "OK", "manage": true, "joinCodeDisplay": "SWP-7Q4K",
        "groups": [["id": 1, "number": 1, "name": "Clinic Booking", "leaderId": 2, "members": 5, "project": ["id": 11, "key": "SWP", "name": "Clinic Booking System", "href": "/work/swp391-g4/SWP"]],
                   ["id": 2, "number": 2, "name": "Campus Eats", "leaderId": 3, "members": 6, "project": ["id": 12, "key": "EAT", "name": "Campus Eats", "href": "/work/swp391-g4/EAT"]]],
        "me": NSNull(),
    ]

    static let giangDay: [String: Any] = [
        "generatedAt": D.iso(0), "filter": [String: Any](), "facets": ["subjects": ["SWP391"], "classes": ["SE1801"], "terms": ["FA26"]],
        "totals": ["groups": 2, "red": 1, "amber": 0, "green": 1, "students": 11, "overdue": 7, "qnaOpen": 2, "docsMissing": 3],
        "tookMs": 120,
        "groups": [
            nhomGD(11, "SWP", "Clinic Booking System", "red", overdue: 6, reasons: [["code": "OVERDUE", "level": "red", "n": 6], ["code": "DOCS_MISSING", "level": "amber", "n": 3]]),
            nhomGD(12, "EAT", "Campus Eats", "green", overdue: 1, reasons: []),
        ],
    ]

    static func nhomGD(_ id: Int, _ key: String, _ ten: String, _ sk: String, overdue: Int, reasons: [[String: Any]]) -> [String: Any] {
        ["projectId": id, "key": key, "name": ten, "href": "/work/swp391-g4/\(key)", "workspace": "SWP391 · Group 4", "archived": false,
         "subject": "SWP391", "classCode": "SE1801", "term": "FA26", "groupCode": NSNull(), "classId": 4, "className": "SWP391 · SE1801",
         "members": [["id": 2, "name": "Linh Tran", "username": "linh", "role": "ADMIN", "status": NSNull(), "signals": [String]()],
                     ["id": 3, "name": "Minh Pham", "username": "minh", "role": "MEMBER", "status": NSNull(), "signals": sk == "red" ? ["SILENT_7D"] : [String]()]],
         "issues": ["open": 18, "overdue": overdue, "done14": 9],
         "sprint": ["name": "Sprint 3", "status": "ACTIVE", "done": 11, "total": 20, "daysLeft": 4, "atRisk": sk == "red"],
         "stage": ["n": 2, "name": "Design", "total": 4, "completed": 1],
         "contrib": ["completed": 40, "actions": 210, "attention": 1, "lastActiveDay": D.ngay(-1), "silentDays": 1],
         "docs": ["R1": "SUBMITTED", "R2": "SUBMITTED", "R3": sk == "red" ? "MISSING" : "SUBMITTED", "R4": "DRAFT", "T51": "NA"],
         "docsExpected": 4, "docsSubmitted": sk == "red" ? 2 : 3, "docsMissing": sk == "red" ? 2 : 0,
         "qna": ["open": 1, "oldestDays": 2], "risks": ["open": 2, "high": sk == "red" ? 1 : 0],
         "grades": ["total": 3, "published": 1, "latestMilestone": "Iteration 1"],
         "health": ["status": sk, "reasons": reasons]]
    }

    static let baiTap: [String: Any] = [
        "manage": false,
        "assignments": [
            ["id": 12, "classId": 4, "authorId": 1, "title": "Lab 3 – ERD", "descriptionText": "Draw the ERD for your project.", "kind": "INDIVIDUAL",
             "category": "Lab", "topic": "Week 3", "maxPoints": 10, "rubricId": NSNull(), "dueAt": D.iso(2), "publishAt": D.iso(-5), "announcedAt": D.iso(-5),
             "allowLate": true, "latePenaltyPct": 10, "latePenaltyMaxPct": 50, "targetAll": true, "targetGroupIds": [Int](), "targetStudentIds": [Int](),
             "createdAt": D.iso(-6), "updatedAt": D.iso(-6), "state": "PUBLISHED", "files": 1,
             "my": ["state": "ASSIGNED", "late": false, "submittedAt": NSNull(), "grade": NSNull()]],
            ["id": 11, "classId": 4, "authorId": 1, "title": "Lab 2 – Use case diagram", "descriptionText": NSNull(), "kind": "GROUP",
             "category": "Lab", "topic": "Week 2", "maxPoints": 10, "rubricId": NSNull(), "dueAt": D.iso(-6), "publishAt": D.iso(-13), "announcedAt": D.iso(-13),
             "allowLate": false, "latePenaltyPct": 0, "latePenaltyMaxPct": 0, "targetAll": true, "targetGroupIds": [Int](), "targetStudentIds": [Int](),
             "createdAt": D.iso(-14), "updatedAt": D.iso(-14), "state": "PUBLISHED", "files": 0,
             "my": ["state": "RETURNED", "late": false, "submittedAt": D.iso(-7),
                    "grade": ["points": 8.5, "rawPoints": 8.5, "penaltyPct": 0, "scores": NSNull(), "returnedAt": D.iso(-3)]]],
        ],
    ]

    static let baiTapCT: [String: Any] = [
        "id": 12, "classId": 4, "authorId": 1, "title": "Lab 3 – ERD",
        "description": D.doc(["Draw the ERD for your project (at least 8 entities) and explain each relationship.",
                              "Submit a PDF or a link to your diagram."]),
        "descriptionText": "Draw the ERD for your project.", "kind": "INDIVIDUAL", "category": "Lab", "topic": "Week 3", "maxPoints": 10,
        "rubricId": NSNull(), "dueAt": D.iso(2), "publishAt": D.iso(-5), "announcedAt": D.iso(-5), "allowLate": true, "latePenaltyPct": 10,
        "latePenaltyMaxPct": 50, "targetAll": true, "targetGroupIds": [Int](), "targetStudentIds": [Int](), "createdAt": D.iso(-6), "updatedAt": D.iso(-6),
        "state": "PUBLISHED", "manage": false,
        "files": [["id": 201, "fileName": "lab3-template.pdf", "mime": "application/pdf", "size": 88_000, "uploaderId": 1, "createdAt": D.iso(-5)]],
        "rubric": NSNull(), "author": D.toi,
        "submission": [
            "needsGroup": false, "canTurnIn": true, "lateIfNow": false, "penaltyIfNow": 0, "id": 501, "state": "ASSIGNED", "status": "ASSIGNED",
            "text": "Draft: 9 entities so far — still checking the N:M between Doctor and Clinic.",
            "links": [["url": "https://drawsql.app/teams/g4/diagrams/clinic", "label": "DrawSQL diagram"]],
            "files": [["id": 301, "fileName": "erd-v1.pdf", "mime": "application/pdf", "size": 412_000, "uploaderId": 2, "createdAt": D.iso(-1)]],
            "late": false, "submittedAt": NSNull(), "version": 1, "versions": [Any](),
            "comments": [["id": 61, "body": "Remember to show cardinality on every relationship.", "createdAt": D.iso(-1), "author": D.toi, "mine": false]],
            "grade": NSNull(),
        ],
    ]

    static let bangTin: [String: Any] = [
        "manage": true, "settings": ["streamComments": true], "groups": [Any](), "myGroupId": NSNull(), "nextBefore": NSNull(),
        "posts": [
            ["id": 81, "kind": "ANNOUNCEMENT", "title": "Mentor meeting moved to Thursday", "bodyJson": D.doc(["This week's mentor meeting is on Thursday 14:00 in room 304."]),
             "links": [Any](), "refType": NSNull(), "refId": NSNull(), "url": NSNull(), "author": D.toi, "files": [Any](), "pinned": true, "commentsOff": false,
             "publishAt": D.iso(-1), "publishedAt": D.iso(-1), "scheduled": false, "editedAt": NSNull(), "createdAt": D.iso(-1), "forGroup": false, "canComment": true,
             "comments": [["id": 91, "postId": 81, "body": "Noted, thanks!", "hidden": false, "hiddenAt": NSNull(), "createdAt": D.iso(-0.8), "author": D.linh, "mine": false, "canDelete": true]],
             "commentCount": 1],
            ["id": 80, "kind": "ASSIGNMENT", "title": "New assignment: Lab 3 – ERD", "bodyJson": NSNull(), "links": [Any](), "refType": "ASSIGNMENT", "refId": 12,
             "url": NSNull(), "author": D.toi, "files": [Any](), "pinned": false, "commentsOff": false, "publishAt": D.iso(-5), "publishedAt": D.iso(-5),
             "scheduled": false, "editedAt": NSNull(), "createdAt": D.iso(-5), "forGroup": false, "canComment": true, "comments": [Any](), "commentCount": 0],
        ],
    ]

    // MARK: Nộp sản phẩm

    static let nopSanPham: [String: Any] = [
        "project": ["key": "NW", "name": "Mobile App Launch"],
        "gate": ["enabled": true, "mode": "hard", "minAttachments": 1, "typeKeys": ["STORY", "TASK"]],
        "canConfig": true,
        "totals": ["members": 3, "issues": 9, "submitted": 6, "files": 11, "overdue": 1],
        "members": [
            ["username": "alex", "name": "Alex Morgan", "kind": "HUMAN", "total": 4, "submitted": 3, "doneCount": 3, "onTime": 3, "onTimeOf": 3, "overdue": 0, "files": 5,
             "items": [["key": "NW-19", "number": 19, "title": "iPad split view layout", "type": "Story", "status": "Done", "statusCategory": "DONE", "done": true,
                        "dueDate": D.iso(-3), "resolvedAt": D.iso(-4), "onTime": true, "overdue": false, "attachmentCount": 2, "submitted": true,
                        "attachments": [["id": 1, "fileName": "split.png", "mime": "image/png", "size": 1000]]],
                       ["key": "NW-17", "number": 17, "title": "Offline cache for My Work", "type": "Story", "status": "To Do", "statusCategory": "TODO", "done": false,
                        "dueDate": D.iso(9), "resolvedAt": NSNull(), "onTime": NSNull(), "overdue": false, "attachmentCount": 0, "submitted": false, "attachments": [Any]()]]],
            ["username": "minh", "name": "Minh Pham", "kind": "HUMAN", "total": 3, "submitted": 2, "doneCount": 2, "onTime": 1, "onTimeOf": 2, "overdue": 1, "files": 4,
             "items": [["key": "NW-14", "number": 14, "title": "Crash when attaching a HEIC photo on iOS 17", "type": "Bug", "status": "To Do", "statusCategory": "TODO",
                        "done": false, "dueDate": D.iso(-1), "resolvedAt": NSNull(), "onTime": NSNull(), "overdue": true, "attachmentCount": 0, "submitted": false,
                        "attachments": [Any]()]]],
            ["username": "scout", "name": "Scout", "kind": "AGENT", "total": 2, "submitted": 1, "doneCount": 1, "onTime": 1, "onTimeOf": 1, "overdue": 0, "files": 2,
             "items": [Any]()],
        ],
    ]
}
#endif
