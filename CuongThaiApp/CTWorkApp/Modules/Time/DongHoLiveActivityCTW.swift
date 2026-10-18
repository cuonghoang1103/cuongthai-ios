import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Live Activity của đồng hồ bấm giờ — phần CỦA APP
//
// Kiểu `CTWDongHoAttributes` + nút trên Live Activity (`NutDongHoLiveIntent`) nằm ở
// `CTWorkShared/DongHoActivityCTW.swift` (app + widget extension cùng biên dịch). Điều phối
// request/update/end: `Modules/Time/LiveActivityDongHoCTW.swift` (mảng D).

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
