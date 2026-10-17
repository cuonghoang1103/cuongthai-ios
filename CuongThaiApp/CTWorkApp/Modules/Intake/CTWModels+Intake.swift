import Foundation

// MARK: - CT Work — model Intake (`services/work/intake.service.ts`; kiểu ở
// `frontend/src/lib/work-ctw7b-api.ts`). Tin từ email/Discord/Zalo/Slack thành
// ĐỀ XUẤT; nhận ⇒ máy chủ tạo thẻ. `var` + optional, ngày là chuỗi.

struct CTWDeXuat: Codable, Hashable, Identifiable {
    struct The: Codable, Hashable { var number: Int?; var key: String? }
    var id: Int
    /// EMAIL | DISCORD | ZALO | SLACK
    var source: String?
    var channelId: Int?
    var title: String
    var body: String?
    var senderName: String?
    var senderHandle: String?
    /// Tên thành viên (khi người gửi khớp một thành viên).
    var sender: String?
    /// PENDING | ACCEPTED | REJECTED
    var status: String?
    var simulated: Bool?
    var createdAt: String?
    var issue: The?
    var decidedBy: String?
    var decidedAt: String?
    var decisionNote: String?

    var nguoiGui: String { sender ?? senderName ?? senderHandle ?? "Unknown sender" }
}

struct CTWDsDeXuat: Codable {
    var proposals: [CTWDeXuat]?
    var counts: [String: Int]?
    var canDecide: Bool?
}

enum CTWIntake {
    static let trangThai: [(ma: String, nhan: String)] = [("PENDING", "Pending"), ("ACCEPTED", "Accepted"), ("REJECTED", "Rejected")]

    static func bieuTuongNguon(_ s: String?) -> String {
        switch s {
        case "EMAIL": return "envelope.fill"
        case "DISCORD": return "bubble.left.and.bubble.right.fill"
        case "ZALO": return "message.fill"
        case "SLACK": return "number.square.fill"
        default: return "tray.and.arrow.down.fill"
        }
    }

    static func tenNguon(_ s: String?) -> String {
        switch s {
        case "EMAIL": return "Email"
        case "DISCORD": return "Discord"
        case "ZALO": return "Zalo"
        case "SLACK": return "Slack"
        default: return "Channel"
        }
    }
}
