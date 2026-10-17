#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu mảng Governance (Approvals · Change requests · RAID · Reviews)
// (Stages do mảng Kế hoạch giữ — dữ liệu mẫu của nó nằm ở tệp của mảng đó.)
//
// Hình dạng theo `approvals.service.ts` present(), `changeRequests.service.ts`,
// `raid.service.ts`, `stages.service.ts`, `quality.service.ts`. Dự án 7, người
// dùng = Alex (id 1). Nối vào `DuLieuGiaMoDun.boXuLy`.

enum DuLieuGiaGovernance {
    typealias G = DuLieuGia

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        let pr = "/work/projects/7"
        // Phê duyệt
        if p == "/work/me/approvals" { return [duyet41().merging(["project": ["id": 7, "key": "NW", "name": "Mobile App Launch", "workspaceSlug": "northwind"]]) { $1 }] }
        if p == pr + "/approvals", m == "GET" {
            let tatCa = [duyet41(), duyet38(), duyet35()]
            if let s = b["status"] as? String { return tatCa.filter { ($0["status"] as? String) == s } }
            return tatCa
        }
        if p.hasPrefix(pr + "/approvals/") {
            let id = Int(p.split(separator: "/")[4]) ?? 41
            if p.hasSuffix("/decide") {
                let dongY = (b["decision"] as? String) == "APPROVE"
                var a = duyet41()
                var steps = a["steps"] as? [[String: Any]] ?? []
                steps[1]["decision"] = dongY ? "APPROVED" : "REJECTED"
                steps[1]["comment"] = b["comment"] ?? NSNull()
                steps[1]["decidedAt"] = G.iso(0)
                steps[1]["contentHash"] = "9f2c41aa7d0e33b2c6f1"
                a["steps"] = steps
                a["status"] = dongY ? "APPROVED" : "REJECTED"
                a["decidedAt"] = G.iso(0)
                a["canDecide"] = false; a["canCancel"] = false; a["myStepId"] = NSNull(); a["waitingOn"] = [Int]()
                return a
            }
            if p.hasSuffix("/cancel") { return duyet41().merging(["status": "CANCELLED", "canDecide": false, "canCancel": false, "waitingOn": [Int]()]) { $1 } }
            return id == 35 ? duyet35() : (id == 38 ? duyet38() : duyet41())
        }
        // Change requests
        if p == pr + "/changes", m == "GET" { return dsCr }
        if p == pr + "/changes", m == "POST" { return cr5.merging(["number": 9, "key": "CR-9", "title": b["title"] ?? "New", "status": "DRAFT", "pendingApprovalId": NSNull()]) { $1 } }
        if p.hasPrefix(pr + "/changes/") {
            if p.hasSuffix("/status") { return cr5.merging(["status": b["status"] ?? "DRAFT"]) { $1 } }
            if p.hasSuffix("/approval") { return duyet41() }
            if m == "PATCH" { return cr5.merging(b.filter { $0.key != "version" }) { $1 }.merging(["version": 5]) { $1 } }
            let so = Int(p.split(separator: "/")[4]) ?? 5
            return so == 6 ? cr6 : cr5
        }
        // RAID
        if p == pr + "/raid", m == "GET" { return dsRaid }
        if p == pr + "/raid", m == "POST" { return raid3.merging(["number": 12, "key": "R-12", "title": b["title"] ?? "New", "history": [Any]()]) { $1 } }
        if p.hasPrefix(pr + "/raid/") {
            if m == "PATCH" {
                var r = raid3.merging(b.filter { $0.key != "version" }) { $1 }
                let pp = r["probability"] as? Int, ii = r["impact"] as? Int
                if let pp, let ii { r["score"] = pp * ii; r["level"] = pp * ii >= 15 ? "HIGH" : (pp * ii >= 8 ? "MEDIUM" : "LOW") }
                r["version"] = 4
                return r
            }
            return raid3
        }
        // Reviews
        if p == pr + "/reviews" { return dsReview }
        if p.hasPrefix(pr + "/reviews/") {
            if p.hasSuffix("/items"), m == "PUT" {
                for x in b["items"] as? [[String: Any]] ?? [] {
                    guard let id = x["id"] as? Int else { continue }
                    khoa.lock(); daGhi[id, default: [:]].merge(x) { $1 }; khoa.unlock()
                }
                return review2()
            }
            if p.contains("/items/"), p.hasSuffix("/defect") { return ["created": true, "number": 44, "key": "NW-44", "title": "Error states not covered"] }
            if p.hasSuffix("/transition") { return review2().merging(["status": b["to"] ?? "REWORK"]) { $1 } }
            if m == "PATCH" { return review2().merging(b) { $1 } }
            return review2()
        }
        return nil
    }

    // MARK: Phê duyệt

    static func buoc(_ id: Int, _ u: [String: Any], _ pos: Int, _ d: String, _ c: String?, _ ngay: Double?) -> [String: Any] {
        ["id": id, "approverId": u["id"] ?? 0, "position": pos, "decision": d, "comment": govNull(c),
         "decidedAt": govNull(ngay.map { G.iso($0) }), "contentHash": govNull(ngay == nil ? nil : "9f2c41aa7d0e33b2c6f1"), "approver": u]
    }

    static func khung(_ id: Int, _ loai: String, _ tieuDe: String, _ trangThai: String) -> [String: Any] {
        ["id": id, "projectId": 7, "targetType": loai, "issueId": NSNull(), "stageId": NSNull(), "pageId": NSNull(), "changeRequestId": NSNull(),
         "title": tieuDe, "description": NSNull(), "mode": "SEQUENTIAL", "status": trangThai, "dueAt": NSNull(),
         "contentHash": "9f2c41aa7d0e33b2c6f1", "decidedAt": NSNull(), "createdAt": G.iso(-2), "updatedAt": G.iso(-1), "clientNote": NSNull(),
         "createdBy": G.linh, "issue": NSNull(), "stage": NSNull(), "page": NSNull(), "changeRequest": NSNull(),
         "specReviewId": NSNull(), "specReview": NSNull(), "issueKey": NSNull(), "currentHash": "9f2c41aa7d0e33b2c6f1",
         "signedHash": "9f2c41aa7d0e33b2c6f1", "contentChanged": false, "changedSinceRequest": false,
         "myStepId": NSNull(), "canDecide": false, "canCancel": false, "waitingOn": [Int](), "evidence": NSNull()]
    }

    static func duyet41() -> [String: Any] {
        var a = khung(41, "CR", "Approve change request CR-5: Add Sign in with Apple", "PENDING")
        a["changeRequestId"] = 5
        a["changeRequest"] = ["id": 5, "number": 5, "title": "Add Sign in with Apple", "status": "UNDER_REVIEW", "clientVisible": false]
        a["description"] = "Apple requires **Sign in with Apple** when we offer Google sign-in. Adds ~3 days to Sprint 7."
        a["dueAt"] = G.iso(2)
        a["steps"] = [buoc(90, G.minh, 0, "APPROVED", "Scope is clear. Estimate looks right.", -1),
                      buoc(91, G.toi, 1, "PENDING", nil, nil),
                      buoc(92, G.linh, 2, "PENDING", nil, nil)]
        a["myStepId"] = 91; a["canDecide"] = true; a["waitingOn"] = [1]
        return a
    }

    static func duyet38() -> [String: Any] {
        var a = khung(38, "DOC", "Approve “Release plan — v1.0”", "APPROVED")
        a["pageId"] = 3
        a["page"] = ["id": 3, "number": 3, "title": "Release plan — v1.0", "status": "APPROVED", "visibility": "INTERNAL"]
        a["mode"] = "PARALLEL"
        a["decidedAt"] = G.iso(-3)
        a["contentChanged"] = true
        a["steps"] = [buoc(80, G.toi, 0, "APPROVED", "Ship it.", -3), buoc(81, G.an, 1, "APPROVED", nil, -3.2)]
        return a
    }

    static func duyet35() -> [String: Any] {
        var a = khung(35, "STAGE_GATE", "Gate review — Stage 2 · Build", "PENDING")
        a["stageId"] = 12
        a["stage"] = ["id": 12, "n": 2, "slug": "build", "name": "Build", "status": "GATE_REVIEW"]
        a["createdBy"] = G.toi
        a["canCancel"] = true
        a["steps"] = [buoc(70, G.linh, 0, "PENDING", nil, nil), buoc(71, G.sara, 1, "PENDING", nil, nil)]
        a["waitingOn"] = [2]
        a["evidence"] = [
            "criteria": ["number": 30, "key": "NW-30", "title": "Build exit criteria", "done": true, "text": "All P1 stories done, crash-free rate ≥ 99.5%"],
            "issues": [["number": 12, "key": "NW-12", "title": "Push notifications open the right issue", "done": true, "status": ["name": "Done", "category": "DONE"], "type": "STORY", "pinned": true],
                       ["number": 17, "key": "NW-17", "title": "Offline cache for My Work", "done": false, "status": ["name": "In Progress", "category": "IN_PROGRESS"], "type": "STORY", "pinned": false]],
            "issueTotal": 14, "issueDone": 13,
            "pages": [["number": 3, "title": "Release plan — v1.0", "status": "APPROVED", "visibility": "INTERNAL"]],
            "files": [["id": 501, "fileName": "beta-build-notes.pdf", "mime": "application/pdf", "size": 182_000, "deliverable": true, "issueKey": "NW-12", "clientVisible": false]],
            "openAtRequest": 1, "openReason": "Offline cache moves to Sprint 7",
        ]
        return a
    }

    // MARK: Change requests

    static let cr5: [String: Any] = [
        "id": 5, "number": 5, "key": "CR-5", "title": "Add Sign in with Apple", "status": "UNDER_REVIEW", "urgency": "HIGH",
        "scheduleDays": 3, "costAmount": 18_000_000, "costCurrency": "VND", "clientVisible": false,
        "submittedAt": G.iso(-3), "decidedAt": NSNull(), "implementedAt": NSNull(), "createdAt": G.iso(-4), "updatedAt": G.iso(-1),
        "owner": G.minh, "requester": G.linh, "pendingApprovalId": 41, "waitingDays": 2,
        "descriptionJson": ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "App Review guideline 4.8 requires an equivalent privacy-focused login when we offer Google sign-in."]]]]],
        "reason": "App Store review will reject the build without it.", "impactScope": "New login button, backend token exchange, account linking.",
        "impactRisk": "Apple identity token verification must be added on the server.", "alternatives": "Drop Google sign-in for launch.",
        "clientSharedAt": NSNull(), "version": 4, "createdById": 2, "createdBy": G.linh,
        "sourceIssue": ["number": 14, "title": "Crash when attaching a HEIC photo on iOS 17", "key": "NW-14"],
        "links": [["id": 1, "role": "AFFECTED", "createdAt": G.iso(-3),
                   "issue": ["number": 12, "key": "NW-12", "title": "Push notifications open the right issue", "done": false,
                             "status": ["name": "In Progress", "category": "IN_PROGRESS"], "type": ["key": "STORY", "name": "Story", "color": "#16a34a", "icon": "story"]],
                   "stage": NSNull(), "version": NSNull()],
                  ["id": 2, "role": "AFFECTED", "createdAt": G.iso(-3), "issue": NSNull(), "stage": NSNull(),
                   "version": ["id": 3, "name": "v1.0", "status": "UNRELEASED", "releaseDate": G.ngay(20)]]],
        "risks": [["number": 3, "type": "RISK", "title": "App Review rejects the launch build", "status": "OPEN", "probability": 3, "impact": 5]],
        "canEdit": true, "canDelete": false, "canRequestApproval": true, "portalOn": false, "approvalsOn": true, "suggestions": [Any](),
    ]

    static let cr6: [String: Any] = cr5.merging([
        "id": 6, "number": 6, "key": "CR-6", "title": "Move dark-mode polish to v1.1", "status": "DRAFT", "urgency": "LOW",
        "scheduleDays": -2, "costAmount": NSNull(), "costCurrency": NSNull(), "pendingApprovalId": NSNull(), "waitingDays": NSNull(),
        "owner": G.toi, "requester": G.toi, "createdBy": G.toi, "links": [Any](), "risks": [Any](), "sourceIssue": NSNull(),
    ]) { $1 }

    static var dsCr: [String: Any] {
        let row7: [String: Any] = cr5.merging(["id": 7, "number": 7, "key": "CR-7", "title": "Extra language: Vietnamese UI strings", "status": "APPROVED",
                                               "urgency": "MEDIUM", "scheduleDays": 5, "costAmount": 25_000_000, "pendingApprovalId": NSNull(),
                                               "waitingDays": NSNull(), "owner": G.an, "decidedAt": G.iso(-6)]) { $1 }
        return ["items": [cr5, cr6, row7],
                "totals": ["approvedCount": 1, "approvedDays": 5, "approvedCost": [["currency": "VND", "amount": 25_000_000]], "pending": 1,
                           "byStatus": ["DRAFT": 1, "UNDER_REVIEW": 1, "APPROVED": 1]],
                "canEdit": true, "canRequestApproval": true, "portalOn": false]
    }

    // MARK: RAID

    static func raidHang(_ so: Int, _ loai: String, _ t: String, _ st: String, p: Int?, i: Int?, ai: [String: Any]?, han: Double?, dong: Bool = false) -> [String: Any] {
        let diem: Any = govNull((p != nil && i != nil) ? p! * i! : nil)
        let muc: Any = govNull((p != nil && i != nil) ? (p! * i! >= 15 ? "HIGH" : (p! * i! >= 8 ? "MEDIUM" : "LOW")) : nil)
        let tienTo = ["RISK": "R", "ASSUMPTION": "A", "ISSUE": "I", "DEPENDENCY": "D"][loai] ?? "Q"
        return ["id": 200 + so, "number": so, "type": loai, "title": t, "description": NSNull(), "category": NSNull(), "status": st,
                "probability": govNull(p), "impact": govNull(i), "clientVisible": false, "response": NSNull(), "mitigation": NSNull(),
                "trigger": NSNull(), "reviewDate": govNull(han.map { G.ngay($0) }), "closedAt": govNull(dong ? G.iso(-2) : nil),
                "createdAt": G.iso(-10), "updatedAt": G.iso(-1), "version": 3, "createdById": 2, "owner": govNull(ai),
                "key": "\(tienTo)-\(so)", "score": diem, "level": muc, "closed": dong, "reviewDue": (han ?? 1) < 0, "linkCount": so == 3 ? 2 : 0]
    }

    static var raid3: [String: Any] {
        raidHang(3, "RISK", "App Review rejects the launch build", "OPEN", p: 3, i: 5, ai: G.linh, han: -1)
            .merging(["description": "Guideline 4.8 and 5.1.1(v) are the usual reasons for a first rejection.",
                      "category": "Compliance", "response": "MITIGATE",
                      "mitigation": "- Add Sign in with Apple (CR-5)\n- Run the pre-submission checklist\n- Prepare a demo account",
                      "trigger": "Review status changes to *Rejected*", "createdBy": G.linh,
                      "links": [["id": 1, "issue": ["number": 12, "key": "NW-12", "title": "Push notifications open the right issue", "done": false, "status": ["name": "In Progress", "category": "IN_PROGRESS"]], "stage": NSNull(), "changeRequest": NSNull()],
                                ["id": 2, "issue": NSNull(), "stage": NSNull(), "changeRequest": ["number": 5, "key": "CR-5", "title": "Add Sign in with Apple", "status": "UNDER_REVIEW"]]],
                      "history": [["id": 3, "field": "probability", "fromValue": "4", "toValue": "3", "createdAt": G.iso(-1), "actor": G.scout],
                                  ["id": 2, "field": "status", "fromValue": "MONITORING", "toValue": "OPEN", "createdAt": G.iso(-4), "actor": G.linh],
                                  ["id": 1, "field": "created", "fromValue": NSNull(), "toValue": NSNull(), "createdAt": G.iso(-10), "actor": G.linh]],
                      "statuses": ["OPEN", "MONITORING", "MITIGATED", "CLOSED"], "canEdit": true, "canDelete": true]) { $1 }
    }

    static var dsRaid: [String: Any] {
        let items: [[String: Any]] = [
            raidHang(3, "RISK", "App Review rejects the launch build", "OPEN", p: 3, i: 5, ai: G.linh, han: -1),
            raidHang(4, "RISK", "Push certificate expires during the beta", "MONITORING", p: 2, i: 4, ai: G.minh, han: 12),
            raidHang(5, "RISK", "Backend cold-start slows the first sync", "OPEN", p: 4, i: 4, ai: G.toi, han: 6),
            raidHang(6, "RISK", "Designer leaves before the launch", "OPEN", p: 1, i: 3, ai: G.an, han: 30),
            raidHang(7, "RISK", "Old Android build still in the store", "CLOSED", p: 2, i: 2, ai: G.an, han: nil, dong: true),
            raidHang(8, "ASSUMPTION", "Beta testers use iOS 17 or later", "VALIDATED", p: nil, i: nil, ai: G.sara, han: nil),
            raidHang(9, "ISSUE", "TestFlight builds stuck in processing", "OPEN", p: nil, i: nil, ai: G.minh, han: 2),
            raidHang(10, "DEPENDENCY", "Apple Developer account renewal (client)", "OPEN", p: nil, i: nil, ai: G.linh, han: 9),
        ]
        var mt = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        for r in items where (r["type"] as? String) == "RISK" && (r["closed"] as? Bool) != true {
            if let p = r["probability"] as? Int, let i = r["impact"] as? Int { mt[p - 1][i - 1] += 1 }
        }
        return ["today": G.ngay(0), "items": items, "matrix": mt,
                "counts": ["RISK": ["total": 5, "open": 4], "ASSUMPTION": ["total": 1, "open": 0], "ISSUE": ["total": 1, "open": 1],
                           "DEPENDENCY": ["total": 1, "open": 1], "QUESTION": ["total": 0, "open": 0]],
                "reviewDue": 1, "highRisks": 2, "thresholds": ["HIGH": 15, "MEDIUM": 8], "canEdit": true]
    }

    // MARK: Reviews

    static let dsReview: [[String: Any]] = [
        ["number": 2, "key": "REV-2", "projectKey": "NW", "title": "SRS v0.9 inspection", "kind": "DOC", "method": "INSPECTION", "checklistKey": "srs-ieee",
         "status": "MEETING", "decision": NSNull(), "workProduct": NSNull(), "meetingAt": G.iso(0, gio: 2), "createdAt": G.iso(-5), "closedAt": NSNull(),
         "participants": 4, "defects": 2, "progress": 50, "rate": 6.5, "density": 0.4, "efficiency": NSNull()],
        ["number": 1, "key": "REV-1", "projectKey": "NW", "title": "Login module code review", "kind": "CODE", "method": "WALKTHROUGH", "checklistKey": "code-basic",
         "status": "CLOSED", "decision": "ACCEPT", "workProduct": "PR #42", "meetingAt": G.iso(-12), "createdAt": G.iso(-14), "closedAt": G.iso(-11),
         "participants": 3, "defects": 3, "progress": 100, "rate": 180, "density": 7.5, "efficiency": 1.2],
    ]

    private static let khoa = NSLock()
    nonisolated(unsafe) private static var daGhi: [Int: [String: Any]] = [:]

    static func muc(_ id: Int, _ pos: Int, _ phan: String, _ q: String, _ kq: String?, note: String? = nil, sev: String? = nil, loi: [String: Any]? = nil) -> [String: Any] {
        var m: [String: Any] = ["id": id, "position": pos, "section": phan, "question": q, "result": govNull(kq), "line": NSNull(),
                                "note": govNull(note), "severity": govNull(sev), "defect": govNull(loi)]
        khoa.lock()
        if let d = daGhi[id] { m.merge(d.filter { $0.key != "id" }) { $1 } }
        khoa.unlock()
        return m
    }

    static func review2() -> [String: Any] {
        let items = [
            muc(1, 0, "Completeness", "Every functional requirement has an ID and an owner.", "OK"),
            muc(2, 1, "Completeness", "Error and empty states are described for each screen.", "NG",
                note: "Inbox and Chat empty states are missing.", sev: "MAJOR",
                loi: ["number": 15, "key": "NW-15", "title": "Design empty states for Inbox and Chat", "done": false]),
            muc(3, 2, "Consistency", "Terms match the glossary.", "NA"),
            muc(4, 3, "Consistency", "No two requirements contradict each other.", nil),
            muc(5, 4, "Verifiability", "Each requirement has a measurable acceptance criterion.", "NG", note: "Offline sync: no timing target.", sev: "MINOR"),
            muc(6, 5, "Verifiability", "Performance requirements state the device and network.", nil),
        ]
        let xong = items.filter { !($0["result"] is NSNull) }.count
        return ["number": 2, "key": "REV-2", "projectKey": "NW", "title": "SRS v0.9 inspection", "kind": "DOC", "method": "INSPECTION",
                "checklistKey": "srs-ieee", "checklistName": "SRS inspection (IEEE 830)", "checklistSource": "IEEE 830-1998",
                "page": ["number": 3, "title": "Release plan — v1.0"], "workProduct": NSNull(), "prUrl": NSNull(), "size": 12, "sizeUnit": "PAGE",
                "status": "MEETING", "decision": NSNull(), "meetingAt": G.iso(0, gio: 2), "meetingMinutes": 45, "reworkMinutes": NSNull(),
                "entryCriteria": "Author ran the spell check and the template checklist.", "exitCriteria": "All MAJOR defects fixed and verified.",
                "notes": NSNull(), "createdAt": G.iso(-5), "updatedAt": G.iso(-0.1), "closedAt": NSNull(),
                "participants": [["id": 1, "userId": 2, "role": "MODERATOR", "prepMinutes": 40, "user": G.linh],
                                 ["id": 2, "userId": 1, "role": "AUTHOR", "prepMinutes": NSNull(), "user": G.toi],
                                 ["id": 3, "userId": 3, "role": "REVIEWER", "prepMinutes": 55, "user": G.minh],
                                 ["id": 4, "userId": 9, "role": "REVIEWER", "prepMinutes": 5, "user": G.scout]],
                "items": items,
                "metrics": ["size": 12, "sizeUnit": "PAGE", "participants": 4, "prepHours": 1.7, "meetingHours": 3, "effortHours": 4.7,
                            "reworkHours": 0, "defects": 2, "majorDefects": 1, "checklistProgress": xong * 100 / items.count, "rate": 6.5,
                            "rateTooFast": false, "density": 0.17, "efficiency": NSNull()],
                "next": ["REWORK", "CLOSED"], "closeBlockers": xong == items.count ? ["NO_DECISION"] : ["CHECKLIST_INCOMPLETE", "NO_DECISION"],
                "canEdit": true]
    }
}
#endif
