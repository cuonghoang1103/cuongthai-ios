import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - API cho Live Activity của đồng hồ bấm giờ (MẢNG D nối vào sau)
//
// Mảng B chỉ cung cấp MÔ HÌNH DỮ LIỆU + điểm móc; KHÔNG gọi `Activity.request` vì:
//   · Live Activity cần một widget extension (giao diện Lock Screen / Dynamic Island) — mảng D làm;
//   · Info.plist của app phải khai `NSSupportsLiveActivities = YES` (mảng D thêm cùng extension).
//
// Cách mảng D nối (gợi ý):
//   1. Chuyển `CTWDongHoAttributes` sang một tệp được CẢ app lẫn widget extension biên dịch.
//   2. Ở app: `DongHoCTW.shared.khiDoi = { trangThai in … }`:
//        - `trangThai == nil`  ⇒ `activity.end(nil, dismissalPolicy: .immediate)`
//        - có trạng thái, chưa có activity ⇒ `Activity.request(attributes: .init(...), content: .init(state: trangThai, staleDate: nil))`
//        - đã có ⇒ `await activity.update(.init(state: trangThai, staleDate: nil))`
//   3. Trên widget: đang chạy ⇒ `Text(timerInterval: runningSince!...Date.distantFuture, countsDown: false)`
//      (`runningSince` đã được LÙI sẵn theo số giây chạy trước đó — xem `trangThaiLiveActivity`);
//      tạm dừng ⇒ hiện số tĩnh `elapsedSec`.
//   4. Nút trong Live Activity (iOS 17 App Intents) gọi `DongHoCTW.shared.tamDung()/tiepTuc()/dung(...)`.
//   Đồng hồ đổi ở web/desktop ⇒ `DongHoCTW` tự nghe `work:timer` và gọi lại `khiDoi`.

#if canImport(ActivityKit)
struct CTWDongHoAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var issueKey: String
        var issueTitle: String
        var projectKey: String
        var running: Bool
        /// Mốc bắt đầu của LƯỢT CHẠY hiện tại (nil khi tạm dừng).
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
#else
/// Nền tảng không có ActivityKit (macOS…) — giữ cùng tên để mã gọi không phải `#if`.
struct CTWDongHoAttributes {
    struct ContentState: Codable, Hashable {
        var issueKey: String
        var issueTitle: String
        var projectKey: String
        var running: Bool
        var runningSince: Date?
        var elapsedSec: Int
        var activity: String?
    }
    var projectId: Int
    var issueNumber: Int
    var workspaceSlug: String
}
#endif

extension CTWDongHoChay {
    /// Trạng thái Live Activity từ đồng hồ máy chủ. `taiLuc` = lúc app nhận bản này.
    /// Đang chạy: `runningSince` = lúc tải − (giây đã chạy) ⇒ widget đếm tiếp chính xác mà không cần
    /// tin `runningSince` của máy chủ (lệch đồng hồ máy) — `elapsedSec` khi đó = 0.
    func trangThaiLiveActivity(taiLuc: Date) -> CTWDongHoAttributes.ContentState {
        let giay = max(elapsedSec ?? 0, 0)
        return CTWDongHoAttributes.ContentState(
            issueKey: issueKey ?? "",
            issueTitle: issueTitle ?? "",
            projectKey: projectKey ?? "",
            running: dangChay,
            runningSince: dangChay ? taiLuc.addingTimeInterval(-Double(giay)) : nil,
            elapsedSec: dangChay ? 0 : giay,
            activity: activity)
    }

    /// Thuộc tính cố định cho `Activity.request`.
    var thuocTinhLiveActivity: CTWDongHoAttributes? {
        guard let pid = projectId, let so = issueNumber else { return nil }
        return CTWDongHoAttributes(projectId: pid, issueNumber: so, workspaceSlug: workspaceSlug ?? "")
    }
}
