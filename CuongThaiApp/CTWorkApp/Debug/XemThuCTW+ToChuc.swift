#if DEBUG
import Foundation

// MARK: - Dữ liệu mẫu: Team · AI agents · Assets · Resources · Diagrams · Finance
// Hình dạng theo service thật (đọc 18/10/2026): projects.service.ts members, teams.service.ts,
// workspaces.service.ts (invite-links), uxc.service.ts (team-overview), agents.service.ts,
// agentUi.service.ts, assets.service.ts, resources.service.ts, diagrams.service.ts, finance.service.ts.
// ⚠️ Cả tệp trong `#if DEBUG`.

enum DuLieuGiaToChuc {
    typealias G = DuLieuGia
    static let pr = "/work/projects/7"
    static let ws = "/work/workspaces/1"
    /// `nil` ⇒ JSON `null` (toán tử `??` với NSNull không suy được kiểu trong từ điển lồng).
    static func nul(_ x: Any?) -> Any { x ?? NSNull() }

    static func route(_ m: String, _ p: String, _ b: [String: Any]) -> Any? {
        switch (m, p) {
        case ("GET", pr + "/team-overview"): return tongQuan
        case ("GET", ws + "/teams"): return nhom
        case ("POST", ws + "/invite-links"):
            return ["id": 31, "expiresAt": G.iso(Double(b["expiresInDays"] as? Int ?? 7)), "maxUses": b["maxUses"] ?? 30,
                    "url": "https://cuongthai.com/work/invite/ctwi_8f3a2c91d4e74b0f9a6e"]
        case ("GET", ws + "/agents"): return [agent(chiTiet: false)]
        case ("GET", ws + "/agents/4"): return agent(chiTiet: true)
        case ("GET", ws + "/agents/4/leases"): return leaseLichSu
        case ("POST", ws + "/agents/4/pause"): var a = agent(chiTiet: true); a["status"] = "PAUSED"; return a
        case ("POST", ws + "/agents/4/resume"): return agent(chiTiet: true)
        case ("GET", pr + "/agent-leases"):
            return [["issueId": 116, "leaseId": 31, "status": "ACTIVE", "progress": "Drafting release notes from merged PRs",
                     "progressPct": 72, "heartbeatAt": G.iso(0, gio: -0.1), "expiresAt": G.iso(0, gio: 0.4), "agentUserId": 9]]
        case ("GET", pr + "/assets"): return taiSan
        case ("GET", pr + "/resources"): return nguonLuc
        case ("GET", pr + "/diagrams"): return ["canEdit": true, "canApprove": true, "canComment": true, "items": soDo]
        case ("GET", pr + "/diagrams/2"): return soDoChiTiet
        case ("POST", pr + "/diagrams/2/comments"):
            return ["id": 77, "body": b["body"] ?? "", "createdAt": G.iso(0), "resolved": false, "mine": true]
        case ("GET", pr + "/finance/settings"):
            return ["currency": "VND", "contractValue": 500_000_000, "budgetTotal": 400_000_000, "alertLevel": 80,
                    "access": ["manage": true, "ownTimesheet": true, "review": "ALL"],
                    "notice": "Estimates for project tracking only — not an invoice or accounting record."]
        case ("GET", pr + "/finance/summary"): return taiChinh
        case ("GET", pr + "/finance/payments"): return mocTT
        case ("GET", pr + "/finance/expenses"): return chiPhi
        case ("GET", pr + "/finance/timesheets"): return ["items": bangCong, "access": ["manage": true]]
        default: break
        }
        if p.hasPrefix(pr + "/members/") { return m == "DELETE" ? ["removed": true] : ["updated": true] }
        if p.hasPrefix(pr + "/assets/"), let so = Int(p.split(separator: "/").last ?? "") {
            return (taiSan["items"] as? [[String: Any]])?.first { $0["number"] as? Int == so } ?? [String: Any]()
        }
        if p.hasPrefix(pr + "/resources/"), p.hasSuffix("/open") { return ["id": 1, "url": "https://github.com/northwind/mobile-app"] }
        return nil
    }

    // MARK: Team

    static let tongQuan: [String: Any] = [
        "asOf": G.iso(0), "unit": "POINTS",
        "totals": ["members": 6, "open": 24, "inProgress": 5, "overdue": 1, "stuck": 1, "reviews": 2, "unassigned": 3],
        "stuckRule": ["reviewDays": 3, "inProgressDays": 5, "p85": NSNull(), "samples": 0],
        "people": [
            ["user": G.toi, "name": "Alex Morgan", "role": "ADMIN", "todo": 2, "inProgress": 2, "overdue": 0, "blocked": 0, "estimate": 13, "total": 4, "stuck": 0, "reviews": 0, "doing": [Any](), "signals": [Any](), "contribStatus": NSNull()],
            ["user": G.linh, "name": "Linh Tran", "role": "ADMIN", "todo": 1, "inProgress": 0, "overdue": 0, "blocked": 0, "estimate": 2, "total": 1, "stuck": 0, "reviews": 1, "doing": [Any](), "signals": [Any](), "contribStatus": NSNull()],
            ["user": G.minh, "name": "Minh Pham", "role": "MEMBER", "todo": 1, "inProgress": 0, "overdue": 1, "blocked": 0, "estimate": 3, "total": 1, "stuck": 0, "reviews": 0, "doing": [Any](), "signals": [Any](), "contribStatus": NSNull()],
            ["user": G.an, "name": "An Nguyen", "role": "MEMBER", "todo": 0, "inProgress": 0, "overdue": 0, "blocked": 0, "estimate": 2, "total": 1, "stuck": 1, "reviews": 1, "doing": [Any](), "signals": [Any](), "contribStatus": NSNull()],
            ["user": G.scout, "name": "Scout", "role": "MEMBER", "todo": 0, "inProgress": 1, "overdue": 0, "blocked": 0, "estimate": 1, "total": 1, "stuck": 0, "reviews": 0, "doing": [Any](), "signals": [Any](), "contribStatus": NSNull()],
        ],
        "unassigned": ["todo": 3, "inProgress": 0, "overdue": 0, "total": 3],
        "overdue": [Any](), "stuck": [Any](), "reviews": [Any](), "meetings": NSNull(), "docs": NSNull(), "contrib": NSNull(),
        "sprint": ["name": "Sprint 6 — Beta polish", "status": "ACTIVE", "done": 2, "total": 8, "daysLeft": 8, "atRisk": false],
        "risks": ["open": 3, "high": 1], "health": NSNull(), "qna": NSNull(), "tookMs": 41,
    ]

    static func tv(_ u: [String: Any], _ r: String) -> [String: Any] { u.merging(["teamRole": r]) { $1 } }

    static let nhom: [[String: Any]] = [
        ["id": 2, "workspaceId": 1, "key": "MOB", "name": "Mobile", "color": "#7c3aed", "description": NSNull(), "archivedAt": NSNull(),
         "createdAt": G.iso(-60), "members": [tv(G.toi, "LEAD"), tv(G.minh, "MEMBER"), tv(G.scout, "MEMBER")], "leadIds": [1], "openIssues": 11],
        ["id": 3, "workspaceId": 1, "key": "QA", "name": "Quality", "color": "#0891b2", "description": NSNull(), "archivedAt": NSNull(),
         "createdAt": G.iso(-40), "members": [tv(G.an, "LEAD"), tv(G.sara, "MEMBER")], "leadIds": [4], "openIssues": 4],
    ]

    // MARK: Agents

    static func agent(chiTiet: Bool) -> [String: Any] {
        var a: [String: Any] = [
            "id": 4, "userId": 9, "workspaceId": 1, "ownerId": 1, "model": "claude-sonnet-5", "roleText": "Release notes & docs writer",
            "capabilities": ["docs": true], "runtime": "EXTERNAL", "status": "ACTIVE", "parallelSlots": 2, "dailyCostCapUsd": 5.0,
            "lastSeenAt": G.iso(0, gio: -0.1), "createdAt": G.iso(-21), "updatedAt": G.iso(-1), "retiredAt": NSNull(),
            "user": G.scout, "owner": G.toi,
            "activeLeases": [["id": 31, "issueId": 116, "projectId": 7, "expiresAt": G.iso(0, gio: 0.4), "progressPct": 72]],
        ]
        if chiTiet {
            a["canManage"] = true
            a["projects"] = [["id": 7, "key": "NW", "name": "Mobile App Launch", "role": "MEMBER"],
                             ["id": 8, "key": "WEB", "name": "Marketing Website", "role": "VIEWER"]]
        }
        return a
    }

    static let leaseLichSu: [[String: Any]] = [
        ["id": 31, "status": "ACTIVE", "claimedAt": G.iso(0, gio: -1.5), "heartbeatAt": G.iso(0, gio: -0.1), "expiresAt": G.iso(0, gio: 0.4),
         "releasedAt": NSNull(), "progress": "Drafting release notes from merged PRs", "progressPct": 72, "issueId": 116,
         "issue": ["key": "NW-16", "title": "Write release notes draft", "url": "/work/northwind/NW/issue/16"]],
        ["id": 27, "status": "RELEASED", "claimedAt": G.iso(-2), "heartbeatAt": G.iso(-2, gio: 1), "expiresAt": G.iso(-2, gio: 2),
         "releasedAt": G.iso(-2, gio: 1.2), "progress": "Done — sent to review", "progressPct": 100, "issueId": 115,
         "issue": ["key": "NW-15", "title": "Design empty states for Inbox and Chat", "url": "/work/northwind/NW/issue/15"]],
        ["id": 22, "status": "EXPIRED", "claimedAt": G.iso(-5), "heartbeatAt": G.iso(-5, gio: 0.5), "expiresAt": G.iso(-5, gio: 1),
         "releasedAt": G.iso(-5, gio: 1), "progress": "Waiting for API keys", "progressPct": 30, "issueId": 120,
         "issue": ["key": "NW-20", "title": "Accessibility audit (Dynamic Type)", "url": "/work/northwind/NW/issue/20"]],
    ]

    // MARK: Assets

    static func ts(_ so: Int, _ ten: String, cat: String, lic: String, nhanLic: String, han: Int?, trangThai: String = "ACTIVE",
                   cost: Double? = nil, cur: String? = nil, billing: String = "FREE", ghiCong: Bool = false, owner: [String: Any] = G.toi,
                   links: [[String: Any]] = []) -> [String: Any] {
        let state: String = han == nil ? "NONE" : (han! < 0 ? "EXPIRED" : (han! <= 30 ? "EXPIRING" : "OK"))
        return ["id": 10 + so, "number": so, "key": "AST-\(so)", "name": ten, "category": cat, "licenseType": lic, "licenseName": NSNull(),
                "licenseUrl": "https://opensource.org/licenses/\(lic)", "source": "Vendor", "sourceUrl": "https://example.com", "version": NSNull(),
                "ownerId": owner["id"] ?? 1, "owner": owner, "status": trangThai, "expiresAt": nul(han.map { G.ngay(Double($0)) }),
                "remindDays": 30, "expiry": ["state": state, "daysLeft": nul(han)], "cost": nul(cost), "currency": nul(cur),
                "billing": billing, "seats": NSNull(), "attributionRequired": ghiCong,
                "attribution": ghiCong ? "Icons by Phosphor (MIT) — phosphoricons.com" : NSNull(),
                "notes": NSNull(), "createdById": 1, "createdAt": G.iso(-50), "updatedAt": G.iso(-3), "licenseLabel": nhanLic, "links": links]
    }

    static let taiSan: [String: Any] = [
        "items": [
            ts(1, "Apple Developer Program", cat: "SERVICE", lic: "PROPRIETARY", nhanLic: "Proprietary", han: 21, cost: 99, cur: "USD", billing: "YEARLY",
               links: [["kind": "ISSUE", "number": 12, "key": "NW-12", "title": "Push notifications open the right issue"]]),
            ts(2, "Figma Professional", cat: "SOFTWARE", lic: "SUBSCRIPTION", nhanLic: "Subscription", han: 140, cost: 180, cur: "USD", billing: "YEARLY", owner: G.an),
            ts(3, "Inter typeface", cat: "FONT", lic: "OFL-1.1", nhanLic: "SIL Open Font License 1.1", han: nil),
            ts(4, "Phosphor icons", cat: "IMAGE", lic: "MIT", nhanLic: "MIT License", han: nil, ghiCong: true,
               links: [["kind": "PAGE", "number": 3, "key": NSNull(), "title": "Release plan — v1.0"]]),
            ts(5, "TestFlight test device (iPhone 13)", cat: "DEVICE", lic: "PROPRIETARY", nhanLic: "Owned device", han: -3, trangThai: "EXPIRED", owner: G.minh),
        ],
        "summary": ["total": 5, "active": 4, "expiring": 1, "expired": 1, "needsAttribution": 1, "unknownLicense": 0, "annualCost": ["USD": 279]],
        "canEdit": true,
        "options": ["categories": [Any](), "licenses": [Any](), "statuses": [Any](), "billing": [Any]()],
    ]

    // MARK: Resources

    static func nl(_ id: Int, _ nhom: Int?, _ tenNhom: String?, _ ten: String, _ url: String, kind: String, tags: [String] = [],
                   pinned: Bool = false, status: String = "OK", github: [String: Any]? = nil) -> [String: Any] {
        ["id": id, "groupId": nul(nhom), "groupName": nul(tenNhom), "title": ten, "url": url, "description": NSNull(),
         "tags": tags, "kind": kind, "faviconUrl": NSNull(), "pinned": pinned, "pinnedToSidebar": false, "visibility": "TEAM", "rank": id,
         "github": nul(github), "embeddable": false, "embedUrl": NSNull(), "embedAspect": "auto",
         "createdAt": G.iso(-30), "updatedAt": G.iso(-2), "createdById": 1, "createdByName": "Alex Morgan",
         "lastOpenedAt": G.iso(-1), "openCount": 12, "linkStatus": status, "checkedAt": G.iso(-1), "check": NSNull(), "canEdit": true]
    }

    static let nguonLuc: [String: Any] = [
        "groups": [["id": 1, "name": "Code", "icon": "💻", "color": NSNull(), "rank": 0, "isDefault": false, "count": 2],
                   ["id": 2, "name": "Design", "icon": "🎨", "color": NSNull(), "rank": 1, "isDefault": true, "count": 2]],
        "ungrouped": 1, "total": 5, "canEdit": true, "canManage": true, "broken": 1,
        "tags": [["tag": "ios", "count": 3], ["tag": "api", "count": 2], ["tag": "ui", "count": 2]],
        "kinds": [["kind": "github", "count": 1]],
        "items": [
            nl(1, 1, "Code", "northwind/mobile-app", "https://github.com/northwind/mobile-app", kind: "github", tags: ["ios"], pinned: true,
               github: ["fullName": "northwind/mobile-app", "stars": 48, "lastCommitAt": G.iso(-0.3), "description": "SwiftUI client for the Northwind app",
                        "defaultBranch": "main", "language": "Swift", "source": "api"]),
            nl(2, 1, "Code", "API reference (staging)", "https://api.staging.northwind.example/docs", kind: "swagger", tags: ["api"]),
            nl(3, 2, "Design", "App UI kit", "https://www.figma.com/file/abc/Northwind-UI", kind: "figma", tags: ["ui", "ios"]),
            nl(4, 2, "Design", "Brand assets (Drive)", "https://drive.google.com/drive/folders/xyz", kind: "gdrive", tags: ["ui"], status: "BROKEN"),
            nl(5, nil, nil, "App Store Connect", "https://appstoreconnect.apple.com", kind: "link", tags: ["ios", "api"]),
        ],
    ]

    // MARK: Diagrams

    static let nguoiLinh: [String: Any] = ["id": 2, "name": "Linh Tran", "username": "linh", "isAgent": false]
    static let nguoiScout: [String: Any] = ["id": 9, "name": "Scout", "username": "scout", "isAgent": true]

    static func sd(_ id: Int, _ so: Int, _ ten: String, type: String, label: String, status: String, ver: Int, appr: Int?,
                   uc: [String: Any]? = nil, issue: [String: Any]? = nil, ai: Bool = false, cmt: Int = 0) -> [String: Any] {
        ["id": id, "number": so, "key": "D-\(so)", "format": "MERMAID", "type": type, "typeLabel": label, "title": ten, "description": NSNull(),
         "feature": NSNull(), "status": status, "currentVersion": ver, "approvedVersion": nul(appr), "rev": ver + 2,
         "aiModel": ai ? "claude-sonnet-5" : NSNull(), "createdAt": G.iso(-20), "updatedAt": G.iso(-1),
         "issue": nul(issue), "useCase": nul(uc), "page": NSNull(), "updatedBy": ai ? nguoiScout : nguoiLinh,
         "openComments": cmt, "pendingProposals": 0, "assumptions": 0]
    }

    static let soDo: [[String: Any]] = [
        sd(3, 2, "Login flow", type: "SEQUENCE", label: "Sequence", status: "APPROVED", ver: 4, appr: 3,
           uc: ["number": 1, "key": "UC-01", "name": "Sign in", "feature": NSNull()], cmt: 2),
        sd(4, 3, "Booking domain model", type: "ERD", label: "ERD", status: "DRAFT", ver: 2, appr: nil,
           issue: ["number": 12, "key": "NW-12", "title": "Push notifications open the right issue"]),
        sd(5, 4, "Notification routing", type: "ACTIVITY", label: "Activity", status: "PROPOSED", ver: 1, appr: nil, ai: true),
        sd(6, 5, "Use cases — patient", type: "USE_CASE", label: "Use case", status: "APPROVED", ver: 1, appr: 1),
    ]

    static var soDoChiTiet: [String: Any] {
        var d = soDo[0]
        d["description"] = "How the app signs a user in and stores the JWT. Approved for **v1.0**."
        d["isAgent"] = false
        d["createdBy"] = nguoiLinh
        d["source"] = "sequenceDiagram\n  App->>API: POST /login"
        d["canEdit"] = true; d["canApprove"] = true; d["canComment"] = true
        d["versions"] = [
            ["number": 4, "note": "Add refresh-token step", "state": "DRAFT", "author": nguoiScout, "aiModel": "claude-sonnet-5", "createdAt": G.iso(-1), "generator": NSNull(), "assumptions": 0],
            ["number": 3, "note": "Reviewed with the team", "state": "APPROVED", "author": nguoiLinh, "aiModel": NSNull(), "createdAt": G.iso(-4), "generator": NSNull(), "assumptions": 0],
            ["number": 2, "note": NSNull(), "state": "DRAFT", "author": nguoiLinh, "aiModel": NSNull(), "createdAt": G.iso(-8), "generator": NSNull(), "assumptions": 0],
            ["number": 1, "note": "First draft", "state": "DRAFT", "author": nguoiLinh, "aiModel": NSNull(), "createdAt": G.iso(-12), "generator": NSNull(), "assumptions": 0],
        ]
        d["proposals"] = [Any]()
        d["comments"] = [
            ["id": 41, "parentId": NSNull(), "versionNumber": 3, "anchor": NSNull(), "body": "Should the Auth service return the refresh token too?",
             "resolved": false, "createdAt": G.iso(-3), "author": ["id": 3, "name": "Minh Pham", "username": "minh", "isAgent": false], "mine": false],
            ["id": 42, "parentId": NSNull(), "versionNumber": 4, "anchor": NSNull(), "body": "Added the refresh-token step in v4 — please review.",
             "resolved": false, "createdAt": G.iso(-1), "author": nguoiScout, "mine": false],
        ]
        return d
    }

    // MARK: Finance

    static let taiChinh: [String: Any] = [
        "currency": "VND", "contractValue": 500_000_000, "budgetTotal": 400_000_000, "alertLevelSent": 80,
        "summary": ["bac": 400_000_000, "actual": 330_000_000, "laborCost": 300_000_000, "expenseCost": 30_000_000, "remaining": 70_000_000,
                    "percentUsed": 82.5, "burnRatePerWeek": 12_000_000, "percentComplete": 0.7, "ev": 280_000_000, "cpi": 0.848,
                    "eac": 471_698_113, "eacMethod": "CPI", "vac": -71_698_113, "alerts": ["WARN", "FORECAST_OVER"], "alertLevel": 80],
        "approvedMinutes": 36000, "unpricedMinutes": 0, "pendingMinutes": 2400, "pendingTimesheets": 3, "plannedEnd": G.ngay(60),
        "byStage": [["id": 3, "label": "1. Discovery", "status": "DONE", "budget": 50_000_000, "actual": 42_000_000],
                    ["id": 4, "label": "2. Build", "status": "ACTIVE", "budget": 300_000_000, "actual": 268_000_000],
                    ["id": 5, "label": "3. Launch", "status": "NOT_STARTED", "budget": 50_000_000, "actual": 20_000_000]],
        "byCategory": [["category": "LABOR", "budget": 300_000_000, "actual": 300_000_000],
                       ["category": "LICENSE", "budget": 40_000_000, "actual": 18_000_000],
                       ["category": "EQUIPMENT", "budget": 60_000_000, "actual": 12_000_000]],
        "byPerson": [["userId": 1, "name": "Alex Morgan", "minutes": 12000, "cost": 110_000_000],
                     ["userId": 2, "name": "Linh Tran", "minutes": 9600, "cost": 88_000_000],
                     ["userId": 3, "name": "Minh Pham", "minutes": 8400, "cost": 62_000_000]],
        "weekly": [Any](),
        "budgetLines": [Any](),
        "payments": ["planned": 200_000_000, "due": 100_000_000, "invoiced": 0, "paid": 200_000_000],
        "formula": "EAC = BAC / CPI", "notice": "Estimates for project tracking only — not an invoice or accounting record.",
    ]

    static let mocTT: [String: Any] = [
        "currency": "VND", "contractValue": 500_000_000, "notice": "",
        "items": [
            ["id": 1, "number": 1, "name": "Kick-off deposit", "percent": 40, "amount": NSNull(), "trigger": "MANUAL", "versionId": NSNull(), "stageId": NSNull(),
             "dueDate": G.ngay(-40), "status": "PAID", "becameDueAt": G.iso(-40), "triggeredByApprovalId": NSNull(), "invoiceNumber": NSNull(),
             "invoicedAt": G.iso(-40), "paidAt": G.iso(-35), "clientVisible": true, "note": NSNull(), "position": 0, "createdAt": G.iso(-60),
             "version": NSNull(), "stage": NSNull(), "computedAmount": 200_000_000, "overdue": false],
            ["id": 2, "number": 2, "name": "Beta accepted", "percent": 20, "amount": NSNull(), "trigger": "STAGE_GATE", "versionId": NSNull(), "stageId": 4,
             "dueDate": G.ngay(-2), "status": "DUE", "becameDueAt": G.iso(-2), "triggeredByApprovalId": 41, "invoiceNumber": NSNull(),
             "invoicedAt": NSNull(), "paidAt": NSNull(), "clientVisible": true, "note": NSNull(), "position": 1, "createdAt": G.iso(-60),
             "version": NSNull(), "stage": ["id": 4, "n": 2, "name": "Build"], "computedAmount": 100_000_000, "overdue": true],
            ["id": 3, "number": 3, "name": "Launch on the App Store", "percent": 40, "amount": NSNull(), "trigger": "UAT", "versionId": 2, "stageId": NSNull(),
             "dueDate": G.ngay(60), "status": "PLANNED", "becameDueAt": NSNull(), "triggeredByApprovalId": NSNull(), "invoiceNumber": NSNull(),
             "invoicedAt": NSNull(), "paidAt": NSNull(), "clientVisible": true, "note": NSNull(), "position": 2, "createdAt": G.iso(-60),
             "version": ["id": 2, "name": "v1.0"], "stage": NSNull(), "computedAmount": 200_000_000, "overdue": false],
        ],
    ]

    static let chiPhi: [[String: Any]] = [
        ["id": 1, "spentOn": G.ngay(-30), "category": "LICENSE", "description": "Apple Developer Program", "vendor": "Apple", "amount": 2_500_000,
         "budgetLineId": NSNull(), "stageId": NSNull(), "createdById": 1, "createdAt": G.iso(-30), "budgetLine": NSNull(), "stage": NSNull()],
        ["id": 2, "spentOn": G.ngay(-12), "category": "EQUIPMENT", "description": "Test device (iPhone 13)", "vendor": "FPT Shop", "amount": 12_000_000,
         "budgetLineId": 2, "stageId": 4, "createdById": 1, "createdAt": G.iso(-12), "budgetLine": ["id": 2, "name": "Devices"], "stage": ["id": 4, "n": 2, "name": "Build"]],
    ]

    static let bangCong: [[String: Any]] = [
        ["id": 9, "userId": 2, "userName": "Linh Tran", "weekStart": G.ngay(-7), "weekEnd": G.ngay(-1), "status": "SUBMITTED", "totalMinutes": 2400,
         "note": NSNull(), "submittedAt": G.iso(-1), "decidedAt": NSNull(), "decidedById": NSNull(), "returnReason": NSNull(),
         "reopenedAt": NSNull(), "reopenReason": NSNull(), "version": 1, "approvedCost": NSNull()],
        ["id": 8, "userId": 1, "userName": "Alex Morgan", "weekStart": G.ngay(-14), "weekEnd": G.ngay(-8), "status": "APPROVED", "totalMinutes": 2280,
         "note": NSNull(), "submittedAt": G.iso(-8), "decidedAt": G.iso(-7), "decidedById": 1, "returnReason": NSNull(),
         "reopenedAt": NSNull(), "reopenReason": NSNull(), "version": 2, "approvedCost": 20_900_000],
        ["id": 7, "userId": 3, "userName": "Minh Pham", "weekStart": G.ngay(-14), "weekEnd": G.ngay(-8), "status": "RETURNED", "totalMinutes": 600,
         "note": NSNull(), "submittedAt": G.iso(-8), "decidedAt": G.iso(-7), "decidedById": 1, "returnReason": "Missing Thursday entries",
         "reopenedAt": NSNull(), "reopenReason": NSNull(), "version": 2, "approvedCost": NSNull()],
    ]
}
#endif
