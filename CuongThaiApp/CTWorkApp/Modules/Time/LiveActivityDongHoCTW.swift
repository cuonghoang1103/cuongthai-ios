import Foundation
import ActivityKit
import WidgetKit

// MARK: - Điều phối Live Activity + widget của đồng hồ bấm giờ (mảng D)
//
// Một nguồn sự thật: `DongHoCTW` (đồng hồ ở MÁY CHỦ). Mỗi lần nó đổi (`khiDoi`) ta:
//   1. ghi ảnh chụp `AnhDongHoCTW` vào App Group + bảo widget vẽ lại;
//   2. Live Activity: không có đồng hồ ⇒ kết thúc; đồng hồ ở thẻ KHÁC ⇒ kết thúc cái cũ, mở cái mới;
//      cùng thẻ ⇒ cập nhật. Người dùng tắt Live Activities trong Cài đặt ⇒ chỉ còn widget.
// Live Activity chạy cục bộ (không push `liveactivity`): đồng hồ đổi ở web khi app đang TẮT thì Live
// Activity chỉ khớp lại lần tới app mở (hoặc khi người dùng bấm nút trên nó). Ghi rõ ở ghi chú duyệt.

@MainActor
enum LiveActivityDongHoCTW {
    /// Gọi MỘT lần lúc khởi động.
    static func khoiDong() {
        DongHoCTW.shared.khiDoi = { trangThai in
            Task { @MainActor in await capNhat(trangThai) }
        }
        NutDongHoLiveIntent.thucThi = { hanhDong in try await LiveActivityDongHoCTW.lamNut(hanhDong) }
    }

    /// Nút trên Live Activity (chạy trong tiến trình app, có thể đang nền).
    static func lamNut(_ hanhDong: String) async throws {
        if DongHoCTW.shared.dongHo == nil { await DongHoCTW.shared.taiLai() }
        switch hanhDong {
        case "pause": try await DongHoCTW.shared.tamDung()
        case "resume": try await DongHoCTW.shared.tiepTuc()
        case "stop": _ = try await DongHoCTW.shared.dung()
        default: break
        }
    }

    static func capNhat(_ trangThai: CTWDongHoAttributes.ContentState?) async {
        let d = DongHoCTW.shared.dongHo
        // 1. Widget
        if let t = trangThai, let d {
            NhomCTW.ghi(AnhDongHoCTW(issueKey: t.issueKey, issueTitle: t.issueTitle, projectKey: t.projectKey,
                                     running: t.running, runningSince: t.runningSince, elapsedSec: t.elapsedSec,
                                     duongDan: d.url, capNhat: Date()),
                        ten: AnhDongHoCTW.tep)
        } else {
            NhomCTW.xoa(ten: AnhDongHoCTW.tep)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "CTWDongHoWidget")

        // 2. Live Activity
        let dangCo = Activity<CTWDongHoAttributes>.activities
        guard let t = trangThai, let thuocTinh = d?.thuocTinhLiveActivity else {
            for a in dangCo { await a.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let noiDung = ActivityContent(state: t, staleDate: nil)
        var conLai: Activity<CTWDongHoAttributes>?
        for a in dangCo {
            if a.attributes.projectId == thuocTinh.projectId && a.attributes.issueNumber == thuocTinh.issueNumber && conLai == nil {
                conLai = a
            } else {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
        if let conLai {
            await conLai.update(noiDung)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: thuocTinh, content: noiDung, pushType: nil)
        }
    }

    /// Đăng xuất: dọn Live Activity + ảnh chụp.
    static func donHet() async {
        for a in Activity<CTWDongHoAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
