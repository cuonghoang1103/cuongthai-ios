import Foundation
import CoreLocation

/// Đo vị trí MỘT LẦN cho tính năng chia sẻ vị trí trong chat.
///
/// Cố ý không theo dõi liên tục: chia sẻ vị trí là một hành động rời rạc, bật
/// `startUpdatingLocation` rồi quên tắt là ăn pin suốt phiên. `requestLocation()`
/// tự dừng sau một kết quả.
@MainActor
final class DoViTri: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var dangDo = false
    @Published var loi: String?

    private let quanLy = CLLocationManager()
    private var tiepTuc: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        quanLy.delegate = self
        quanLy.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func doMotLan() async -> CLLocationCoordinate2D? {
        // Chưa hỏi quyền thì hỏi rồi ĐỢI trả lời trong `didChangeAuthorization`
        // — gọi `requestLocation()` ngay lúc trạng thái còn `.notDetermined`
        // thì iOS im lặng bỏ qua, và màn hình treo ở "đang đo" mãi mãi.
        let trangThai = quanLy.authorizationStatus
        if trangThai == .denied || trangThai == .restricted {
            loi = "Bạn đã tắt quyền vị trí cho ứng dụng. Bật lại trong Cài đặt → Quyền riêng tư → Dịch vụ định vị."
            return nil
        }

        dangDo = true
        defer { dangDo = false }

        return await withCheckedContinuation { (cont: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
            tiepTuc = cont
            if trangThai == .notDetermined {
                quanLy.requestWhenInUseAuthorization()
            } else {
                quanLy.requestLocation()
            }
        }
    }

    private func tra(_ toado: CLLocationCoordinate2D?) {
        // Chỉ được gọi `resume` MỘT lần; delegate có thể bắn nhiều lượt.
        guard let c = tiepTuc else { return }
        tiepTuc = nil
        c.resume(returning: toado)
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations ds: [CLLocation]) {
        let toado = ds.last?.coordinate
        Task { @MainActor in self.tra(toado) }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.loi = "Không lấy được vị trí: \(error.localizedDescription)"
            self.tra(nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let tt = m.authorizationStatus
        Task { @MainActor in
            switch tt {
            case .authorizedWhenInUse, .authorizedAlways:
                // Vừa được cấp quyền — giờ mới đo được.
                if self.tiepTuc != nil { m.requestLocation() }
            case .denied, .restricted:
                self.loi = "Bạn đã từ chối quyền vị trí."
                self.tra(nil)
            default:
                break
            }
        }
    }
}
