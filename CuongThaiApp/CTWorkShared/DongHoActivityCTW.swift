import Foundation
import ActivityKit
import AppIntents

// MARK: - Live Activity đồng hồ bấm giờ — kiểu DÙNG CHUNG app ⇄ widget extension
//
// `ActivityAttributes` phải là CÙNG MỘT kiểu (cùng tên, cùng hình dạng) ở app (gọi `Activity.request`)
// và ở widget extension (vẽ Lock Screen / Dynamic Island) ⇒ tệp này nằm ở `CTWorkShared/`.
//
// Nút trên Live Activity (iOS 17+): `NutDongHoLiveIntent` là `LiveActivityIntent` ⇒ hệ thống chạy
// `perform()` TRONG TIẾN TRÌNH APP (kể cả khi app đang tắt — iOS dựng app chạy nền). Ở tiến trình widget
// `thucThi` là nil ⇒ không làm gì. App gắn `thucThi` lúc khởi động (`LiveActivityDongHoCTW.ganNut()`).

struct CTWDongHoAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var issueKey: String
        var issueTitle: String
        var projectKey: String
        var running: Bool
        /// Mốc bắt đầu của LƯỢT CHẠY hiện tại (nil khi tạm dừng) — đã lùi theo số giây chạy trước.
        var runningSince: Date?
        /// Tạm dừng: tổng giây đã chạy. Đang chạy: 0 (đã gộp vào `runningSince`).
        var elapsedSec: Int
        var activity: String?
    }
    /// Cố định suốt vòng đời một Live Activity.
    var projectId: Int
    var issueNumber: Int
    var workspaceSlug: String
}

/// Ba nút của Live Activity: tạm dừng · tiếp tục · dừng & ghi giờ.
struct NutDongHoLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Control CT Work timer"
    static var description = IntentDescription("Pause, resume or stop the running CT Work timer.")
    static var isDiscoverable: Bool = false

    /// "pause" | "resume" | "stop"
    @Parameter(title: "Action") var hanhDong: String

    init() {}
    init(_ hanhDong: String) { self.hanhDong = hanhDong }

    /// App gắn lúc khởi động. Tiến trình widget: nil.
    nonisolated(unsafe) static var thucThi: ((String) async throws -> Void)?

    func perform() async throws -> some IntentResult {
        try await Self.thucThi?(hanhDong)
        return .result()
    }
}
