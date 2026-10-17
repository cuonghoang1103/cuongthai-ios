import SwiftUI
import EventKit
import EventKitUI

// MARK: - "Add to Calendar" — EKEventEditViewController điền sẵn
//
// App Store 5.1.1 (quyền đúng mục đích, chỉ khi người dùng bấm): từ iOS 17,
// `EKEventEditViewController` chạy NGOÀI tiến trình app — app KHÔNG đọc được lịch của người dùng và
// KHÔNG cần xin quyền ⇒ không gọi `requestAccess`, không khai chuỗi `NSCalendars…UsageDescription`.
// Người dùng thấy bảng thêm sự kiện của hệ thống, tự chọn lịch và bấm Add (hoặc Cancel).
// Chỉ mở khi người dùng bấm nút "Add to Calendar" trên một sự kiện.

struct ThemSuKienLichB2: UIViewControllerRepresentable {
    let suKien: SuKienLichCTW
    var lienKet: URL?
    @Environment(\.dismiss) private var dong

    func makeCoordinator() -> DieuPhoi { DieuPhoi(dong: { dong() }) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let kho = EKEventStore()
        let vc = EKEventEditViewController()
        vc.eventStore = kho
        let e = EKEvent(eventStore: kho)
        e.title = suKien.tieuDe
        if suKien.caNgay {
            // Ngày cả-ngày tính theo lịch VN (khớp máy chủ) ⇒ đổi sang CÙNG ngày-tháng-năm ở lịch máy.
            let c = NgayCTW.lichVN.dateComponents([.year, .month, .day], from: suKien.batDau)
            let d = Calendar.current.date(from: c) ?? suKien.batDau
            e.isAllDay = true
            e.startDate = d
            e.endDate = d
        } else {
            e.startDate = suKien.batDau
            e.endDate = suKien.ketThuc ?? suKien.batDau.addingTimeInterval(1800)
            if let tz = suKien.hop?.timezone.flatMap(TimeZone.init(identifier:)) { e.timeZone = tz }
        }
        if let l = suKien.hop?.location, !l.isEmpty { e.location = l }
        e.url = lienKet
        var ghiChu: [String] = []
        if let p = suKien.phu, !p.isEmpty { ghiChu.append(p) }
        if let u = lienKet { ghiChu.append(u.absoluteString) }
        if !ghiChu.isEmpty { e.notes = ghiChu.joined(separator: "\n") }
        vc.event = e
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}

    final class DieuPhoi: NSObject, EKEventEditViewDelegate {
        let dong: () -> Void
        init(dong: @escaping () -> Void) { self.dong = dong }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            if action == .saved { CTWRung.thanhCong() }
            dong()
        }
    }
}
