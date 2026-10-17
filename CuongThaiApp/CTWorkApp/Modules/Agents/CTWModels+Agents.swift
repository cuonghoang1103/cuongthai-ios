import SwiftUI

// MARK: - CT Work — model mô-đun AI Agents (`agents.service.ts`, `agentUi.service.ts`)
// Luật: mọi trường `var` + optional, ngày là chuỗi (CLAUDE.md C3/C4).

struct CTWAgentLease: Codable, Hashable, Identifiable {
    var id: Int
    var issueId: Int?
    var projectId: Int?
    var claimedAt: String?
    var expiresAt: String?
    var progress: String?
    var progressPct: Double?
}

struct CTWAgentDuAn: Codable, Hashable, Identifiable {
    var id: Int
    var key: String?
    var name: String?
    var role: String?
}

/// Một agent — `GET /workspaces/:wsId/agents` (danh sách) và `/agents/:id` (chi tiết thêm
/// `canManage`, `projects`).
struct CTWAgentHoSo: Codable, Hashable, Identifiable {
    var id: Int
    var userId: Int?
    var ownerId: Int?
    var model: String?
    var roleText: String?
    /// EXTERNAL | BUILTIN
    var runtime: String?
    /// ACTIVE | PAUSED | RETIRED
    var status: String?
    var parallelSlots: Int?
    var dailyCostCapUsd: Double?
    var lastSeenAt: String?
    var createdAt: String?
    var retiredAt: String?
    var user: CTWUser?
    var owner: CTWUser?
    var activeLeases: [CTWAgentLease]?
    var canManage: Bool?
    var projects: [CTWAgentDuAn]?

    var ten: String { user?.ten ?? "Agent #\(id)" }
    var tenRuntime: String { runtime == "BUILTIN" ? "Built-in (runs on CT Work)" : "External (MCP token)" }
}

/// Lịch sử nhận việc — `GET /workspaces/:wsId/agents/:id/leases`.
struct CTWAgentLeaseLichSu: Codable, Hashable, Identifiable {
    struct The: Codable, Hashable { var key: String?; var title: String?; var url: String? }
    var id: Int
    var status: String?
    var claimedAt: String?
    var heartbeatAt: String?
    var expiresAt: String?
    var releasedAt: String?
    var progress: String?
    var progressPct: Double?
    var issueId: Int?
    var issue: The?
}

/// Chip "đang làm" trên thẻ — `GET /projects/:pid/agent-leases` (một chip mỗi thẻ).
struct CTWAgentChip: Codable, Hashable {
    var issueId: Int
    var leaseId: Int?
    var status: String?
    var progress: String?
    var progressPct: Double?
    var heartbeatAt: String?
    var expiresAt: String?
    var agentUserId: Int?
}

enum CTWAgentHienThi {
    /// Cùng luật với web (`components/work/agents/leases.tsx:54-57`):
    /// ACTIVE còn hạn + có % ⇒ "working · 72%"; EXPIRED hoặc ACTIVE quá hạn ⇒ "stalled".
    static func chip(status: String?, expiresAt: String?, pct: Double?, bayGio: Date = Date()) -> (chu: String, ket: Bool) {
        let het = thoiDiem(expiresAt).map { $0 < bayGio } ?? false
        if status == "EXPIRED" || (status == "ACTIVE" && het) { return ("stalled", true) }
        if status == "ACTIVE" {
            if let pct { return ("working · \(Int(pct.rounded()))%", false) }
            return ("working", false)
        }
        return ((status ?? "done").lowercased(), false)
    }

    static func thoiDiem(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// "5 min ago", "2 h ago", "Sep 25".
    static func truoc(_ s: String?, bayGio: Date = Date()) -> String? {
        guard let d = thoiDiem(s) else { return nil }
        let giay = bayGio.timeIntervalSince(d)
        if giay < 60 { return "just now" }
        if giay < 3600 { return "\(Int(giay / 60)) min ago" }
        if giay < 86400 { return "\(Int(giay / 3600)) h ago" }
        return CTW.ngayNgan(s)
    }

    static func mauTrangThai(_ s: String?) -> Color {
        switch s {
        case "ACTIVE": return AppColors.success
        case "PAUSED": return AppColors.warning
        default: return AppColors.textTertiary
        }
    }
}
