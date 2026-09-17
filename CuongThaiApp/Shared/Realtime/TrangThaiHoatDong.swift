#if os(iOS)
import Foundation
import SwiftUI
#endif

// ════════════════════════════════════════════════════════════════
// TRẠNG THÁI HOẠT ĐỘNG
//
// Trước 17/09/2026 phần này hỏng ở BỐN chỗ xếp chồng, nên sửa một chỗ không
// cứu được gì:
//
//   1. App KHÔNG BAO GIỜ gọi `POST /users/status`. Máy chủ có sẵn endpoint đó
//      và web vẫn gọi, nhưng app thì không — nên `lastActiveAt` của người
//      dùng app đứng yên vĩnh viễn và với MỌI người khác họ luôn ngoại tuyến.
//   2. `ThreadRow.isOnline` là `@State` chết: khai, đọc một lần, không chỗ
//      nào gán ⇒ chấm xanh ở danh sách chat chưa từng hiện.
//   3. `peer` từ API không có `lastActiveAt` ⇒ không có dữ liệu để nói
//      "hoạt động N phút trước".
//   4. Chỉ dựa vào socket `presence:update`. Sự kiện đó chỉ phát khi người
//      kia ĐỔI trạng thái, nên vừa mở app là `truyenTuyen` rỗng và ai cũng
//      hiện "Ngoại tuyến" — kể cả người đang online thật.
//
// Cách chữa: socket lo phần REALTIME (đang mở app cùng lúc), `lastActiveAt`
// lo phần LÚC MỚI MỞ (chưa có sự kiện nào bay tới). Hai nguồn bù cho nhau.
// ════════════════════════════════════════════════════════════════

enum TrangThaiHoatDong {

    /// Ngưỡng coi là "đang hoạt động", tính bằng giây.
    ///
    /// ⚠️ PHẢI khớp `ONLINE_THRESHOLD_SECONDS` ở `src/services/follow.service.ts`.
    /// Lệch nhau thì app và web nói hai chuyện khác nhau về cùng một người.
    static let nguongTrucTuyen: TimeInterval = 60

    /// Kết quả đã tính xong, sẵn để vẽ.
    struct KetQua: Equatable {
        /// Chuỗi hiện dưới tên. Rỗng = không biết gì, ĐỪNG vẽ dòng nào.
        let chu: String
        /// Có vẽ chấm xanh không.
        let trucTuyen: Bool
    }

    /// - Parameters:
    ///   - mocHoatDong: `lastActiveAt` từ máy chủ. `nil` khi người kia đã TẮT
    ///     công tắc hiện trạng thái, hoặc chưa từng hoạt động.
    ///   - socketBaoOnline: `presence:update` đang nói người này online.
    static func tinh(mocHoatDong: Date?, socketBaoOnline: Bool,
                     bayGio: Date = Date()) -> KetQua {
        if socketBaoOnline { return KetQua(chu: "Đang hoạt động", trucTuyen: true) }

        // Không có mốc ⇒ KHÔNG đoán. Viết "Ngoại tuyến" cho người đã tắt công
        // tắc là nói một điều mình không biết, và đúng là điều họ vừa từ chối
        // cho biết.
        guard let moc = mocHoatDong else { return KetQua(chu: "", trucTuyen: false) }

        let giay = bayGio.timeIntervalSince(moc)

        // Mốc ở TƯƠNG LAI: đồng hồ máy lệch, hoặc máy chủ vừa ghi xong. Coi
        // như vừa hoạt động thay vì in ra "hoạt động -3 phút trước".
        if giay < nguongTrucTuyen {
            return KetQua(chu: "Đang hoạt động", trucTuyen: true)
        }

        let phut = Int(giay / 60)
        if phut < 60 { return moTa("%d phút") { phut } }

        let gio = phut / 60
        if gio < 24 { return moTa("%d giờ") { gio } }

        let ngay = gio / 24
        if ngay < 7 { return moTa("%d ngày") { ngay } }

        // ⚠️ Mốc THÁNG phải hỏi LỊCH, không được chia cho 30 hay chặn tuần
        // bằng phép chia số học.
        //
        // Bản đầu viết `if tuan < 5` rồi mới xét tháng: đúng một tháng trước
        // (17/8 → 17/9, 31 ngày) rơi vào `tuan == 4` và in ra "4 tuần trước".
        // Phép kiểm bắt được. Ngược lại, chặn ở `tuan < 4` thì khoảng cách 28
        // ngày lại thành "1 tháng trước" — nói QUÁ.
        //
        // Hỏi lịch thì cả hai ca đều đúng: 17/8→17/9 ra 1 tháng; 20/8→17/9 ra
        // 0 tháng nên vẫn là 4 tuần. Và tháng 2 không bị coi bằng tháng 7.
        let l = Calendar.current
        let thang = l.dateComponents([.month], from: moc, to: bayGio).month ?? 0
        if thang >= 12 {
            let nam = l.dateComponents([.year], from: moc, to: bayGio).year ?? 1
            return moTa("%d năm") { max(1, nam) }
        }
        if thang >= 1 { return moTa("%d tháng") { thang } }

        return moTa("%d tuần") { max(1, ngay / 7) }
    }

    private static func moTa(_ mau: String, _ so: () -> Int) -> KetQua {
        KetQua(chu: String(format: "Hoạt động " + mau + " trước", so()), trucTuyen: false)
    }

    /// Đọc mốc ISO-8601 từ máy chủ.
    ///
    /// ⚠️ `lastActiveAt` khai `String?` trong model chứ KHÔNG phải `Date?`:
    /// `APIClient` dựng `JSONDecoder()` trần (chiến lược ngày `deferredToDate`),
    /// khai `Date` là cả lượt giải mã hỏng — và lỗi giải mã ở app này bị nuốt
    /// im lặng, hiện ra dạng "danh sách trống" chứ không phải dạng lỗi.
    static func docMoc(_ iso: String?) -> Date? {
        guard let s = iso else { return nil }
        return NhacViec.moc(s)
    }
}

#if os(iOS)
// ════════════════════════════════════════════════════════════════
// BÁO TRẠNG THÁI CỦA CHÍNH MÌNH LÊN MÁY CHỦ
//
// Không có phần này thì mọi thứ trên chỉ chạy MỘT CHIỀU: mình thấy người
// khác online, còn họ không bao giờ thấy mình.
// ════════════════════════════════════════════════════════════════

@MainActor
final class BaoHoatDong {
    static let shared = BaoHoatDong()

    /// Nhịp báo. Phải NHỎ HƠN ngưỡng 60 giây của máy chủ, không thì có lúc
    /// mốc đã quá hạn mà nhịp kế chưa tới — người dùng đang mở app mà người
    /// khác thấy họ vừa offline rồi lại online, nhấp nháy.
    private static let nhip: TimeInterval = 45

    private var dong: Timer?
    private var dangGui = false

    private init() {}

    /// Gọi khi app vào tiền cảnh và sau khi đăng nhập.
    func batDau() {
        guard dong == nil else { return }
        Task { await gui() }
        let t = Timer.scheduledTimer(withTimeInterval: Self.nhip, repeats: true) { _ in
            Task { @MainActor in await BaoHoatDong.shared.gui() }
        }
        // Không có `.common` thì hẹn giờ ĐỨNG IM trong lúc người dùng đang
        // cuộn — mà cuộn danh sách chat là đúng lúc cần nó chạy nhất.
        RunLoop.main.add(t, forMode: .common)
        dong = t
    }

    /// Gọi khi app xuống nền hoặc đăng xuất. Ngừng báo là đủ — sau 60 giây
    /// máy chủ tự coi là ngoại tuyến, không cần gửi thêm gì.
    func dungLai() {
        dong?.invalidate()
        dong = nil
    }

    private func gui() async {
        guard !dangGui, AppState.shared.isAuthenticated else { return }
        dangGui = true
        defer { dangGui = false }
        // Hỏng thì im: đây là việc nền, một nhịp trượt không ảnh hưởng gì và
        // nhịp sau sẽ bù. Báo lỗi ra màn hình cho việc này là quấy rầy.
        _ = try? await APIClient.shared.requestRaw(.baoHoatDong)
    }
}
#endif
