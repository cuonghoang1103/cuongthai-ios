import Foundation
import Combine

// MARK: - Đồng hồ bấm giờ (lõi) — MỘT đồng hồ mỗi người, lưu ở MÁY CHỦ
//
// Đồng hồ sống ở máy chủ (`timer.service.ts`) nên bấm ở web/desktop/iPhone đều là cùng một cái.
// App chỉ giữ bản đọc gần nhất + mốc tải để tự đếm giây (không gọi mạng mỗi giây).
// Đổi ở thiết bị khác ⇒ máy chủ phát `work:timer` vào phòng `user:<id>` ⇒ tải lại.
// Dừng ⇒ máy chủ TỰ ghi worklog (dưới 30 giây ⇒ không ghi). Lỗi khi ghi (423 tuần đã khoá)
// ⇒ máy chủ GIỮ đồng hồ để không mất giờ.

@MainActor
final class DongHoCTW: ObservableObject {
    static let shared = DongHoCTW()

    @Published private(set) var dongHo: CTWDongHoChay?
    /// Lúc nhận bản `dongHo` hiện tại (đồng hồ máy) — gốc để đếm giây.
    @Published private(set) var taiLuc = Date()
    @Published private(set) var daTai = false

    /// Điểm móc cho Live Activity (mảng D): gọi MỖI lần đồng hồ đổi; `nil` = không còn đồng hồ.
    var khiDoi: ((CTWDongHoAttributes.ContentState?) -> Void)?

    private var huyNghe: AnyCancellable?
    private var soNguoiNghe = 0

    private init() {}

    /// Bật nghe realtime (gọi ở `.onAppear` màn có đồng hồ; cặp với `boNghe`).
    func nghe() {
        soNguoiNghe += 1
        guard soNguoiNghe == 1 else { return }
        RealtimeKeHoachCTW.shared.nghe(pid: 0)
        huyNghe = RealtimeKeHoachCTW.shared.suKienDongHo.sink { [weak self] in
            Task { await self?.taiLai() }
        }
    }

    func boNghe() {
        soNguoiNghe = max(soNguoiNghe - 1, 0)
        guard soNguoiNghe == 0 else { return }
        huyNghe = nil
        RealtimeKeHoachCTW.shared.boNghe(pid: 0)
    }

    /// Giây đã trôi lúc `bayGio`.
    func giay(_ bayGio: Date = Date()) -> Int {
        guard let d = dongHo else { return 0 }
        return TinhGioCTW.giayTroi(d, taiLuc: taiLuc, bayGio: bayGio)
    }

    func laThe(pid: Int, so: Int) -> Bool { dongHo?.projectId == pid && dongHo?.issueNumber == so }

    func taiLai() async {
        do {
            let r: CTWDongHoGoi = try await APIClient.shared.request(CTWAPI.dongHo())
            datDongHo(r.timer)
        } catch {
            // Mất mạng: giữ bản cũ (vẫn đếm tiếp) — không xoá đồng hồ người dùng đang thấy.
        }
        daTai = true
    }

    /// Lỗi `WORK_TIMER_RUNNING` (đang chạy ở thẻ khác) ném ra cho màn hỏi người dùng có chuyển không.
    @discardableResult
    func batDau(pid: Int, so: Int, activity: String? = nil, note: String? = nil, chuyen: Bool = false) async throws -> CTWKetQuaDung? {
        let r: CTWDongHoGoi = try await APIClient.shared.request(
            CTWAPI.batDauDongHo(pid: pid, so: so, activity: activity, note: note, chuyen: chuyen))
        datDongHo(r.timer)
        CTWRung.thanhCong()
        return r.switched
    }

    func tamDung() async throws {
        let r: CTWDongHoGoi = try await APIClient.shared.request(CTWAPI.tamDungDongHo())
        datDongHo(r.timer)
    }

    func tiepTuc() async throws {
        let r: CTWDongHoGoi = try await APIClient.shared.request(CTWAPI.tiepTucDongHo())
        datDongHo(r.timer)
    }

    func sua(activity: String?, note: String?) async throws {
        let r: CTWDongHoGoi = try await APIClient.shared.request(CTWAPI.suaDongHo(activity: activity, note: note))
        datDongHo(r.timer)
    }

    /// Dừng + ghi giờ. Trả kết quả để màn báo "Logged 1h 05m" hoặc "Under 30 seconds — nothing logged".
    func dung(phut: Int? = nil, note: String? = nil, activity: String? = nil) async throws -> CTWKetQuaDung {
        let r: CTWKetQuaDung = try await APIClient.shared.request(CTWAPI.dungDongHo(phut: phut, note: note, activity: activity))
        datDongHo(nil)
        CTWRung.thanhCong()
        return r
    }

    /// Bỏ đồng hồ, KHÔNG ghi gì (màn phải hỏi xác nhận trước).
    func huy() async throws {
        try await APIClient.shared.send(CTWAPI.huyDongHo())
        datDongHo(nil)
    }

    private func datDongHo(_ d: CTWDongHoChay?) {
        let truoc = dongHo
        dongHo = d
        taiLuc = Date()
        daTai = true
        if truoc != d || d?.dangChay == true {
            khiDoi?(d?.trangThaiLiveActivity(taiLuc: taiLuc))
        }
    }

    #if DEBUG
    /// Kiểm thử đơn vị: đặt đồng hồ không qua mạng.
    func _datThu(_ d: CTWDongHoChay?, taiLuc t: Date) { dongHo = d; taiLuc = t; daTai = true }
    #endif
}

extension DongHoCTW {
    /// Mã lỗi máy chủ (vd `WORK_TIMER_RUNNING`, `WORK_TIMESHEET_LOCKED`) nếu có.
    nonisolated static func maLoi(_ e: Error) -> String? {
        if case APIError.coMa(let ma, _) = e { return ma }
        return nil
    }
}
