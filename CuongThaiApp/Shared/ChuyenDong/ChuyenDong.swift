import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - LỚP CHUYỂN ĐỘNG DÙNG CHUNG (app CuongThai + app CT Work) — 21/10/2026
//
// Một bộ NHỎ, cố ý không nhiều: nút nhấn co + rung, xuất hiện lần lượt, ánh lướt (shimmer) cho khung tải,
// rung lắc khi lỗi, thanh tiến độ vô hạn, và lịch của màn khởi động. Mọi thứ:
//   · tôn trọng "Giảm chuyển động" (Reduce Motion) — rơi về mờ dần/đứng yên, không trượt, không phóng;
//   · không chặn gì: không `sleep` trên luồng chính, không đợi hoạt hình xong mới cho bấm.
// Tệp này biên dịch ở CẢ HAI app (project.yml: target CTWorkApp khai riêng đường `Shared/ChuyenDong`) và cả bản
// macOS của app chính ⇒ chỗ nào dùng UIKit phải bọc `#if os(iOS)`.

// MARK: Nút nhấn: co nhẹ + rung nhẹ

/// Kiểu nút: co lại khi nhấn (0.96) + rung nhẹ lúc chạm xuống. Giảm chuyển động ⇒ chỉ mờ nhẹ, không co.
struct KieuNutNhan: ButtonStyle {
    var co: CGFloat = 0.96
    var rung = true

    func makeBody(configuration: Configuration) -> some View {
        NhanNutNoiDung(configuration: configuration, co: co, rung: rung)
    }

    private struct NhanNutNoiDung: View {
        let configuration: ButtonStyleConfiguration
        let co: CGFloat
        let rung: Bool
        @Environment(\.accessibilityReduceMotion) private var giam
        @Environment(\.isEnabled) private var bat

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !giam ? co : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
                .onChange(of: configuration.isPressed) { _, nhan in
                    if nhan && rung && bat { RungNhe.cham() }
                }
        }
    }
}

extension ButtonStyle where Self == KieuNutNhan {
    /// `.buttonStyle(.nhan)` — co + rung nhẹ.
    static var nhan: KieuNutNhan { KieuNutNhan() }
}

/// Rung nhẹ dùng chung (UIKit chỉ có trên iOS — macOS là lệnh rỗng).
enum RungNhe {
    static func cham() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func mem() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        #endif
    }
    static func xong() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func loi() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

// MARK: Xuất hiện lần lượt (stagger) — CHỈ lần nạp đầu

/// Mờ + trượt lên 14pt, trễ theo thứ tự. `bat == false` ⇒ hiện ngay (không hiệu ứng) — cha bật cờ này đúng
/// lúc nạp lần đầu rồi tắt, nên cuộn đi cuộn lại trong danh sách lười KHÔNG làm hàng nhảy lại.
struct XuatHienLanLuot: ViewModifier {
    let thuTu: Int
    let bat: Bool
    var buoc: Double = 0.05
    var toiDa = 10
    @Environment(\.accessibilityReduceMotion) private var giam
    @ObservedObject private var khoiDong = KhoiDongChung.shared
    @State private var hien = false

    func body(content: Content) -> some View {
        let co = bat && thuTu < toiDa
        content
            .opacity(!co || hien ? 1 : 0)
            .offset(y: !co || hien || giam ? 0 : 14)
            .onAppear { if !khoiDong.dangChieu { batDau(co) } }
            // Màn khởi động còn che ⇒ đợi nó bắt đầu thoát rồi mới cho hàng hiện lần lượt.
            .onChange(of: khoiDong.dangChieu) { _, che in if !che { batDau(co) } }
    }

    private func batDau(_ co: Bool) {
        guard co, !hien else { return }
        let tre = giam ? 0 : Double(thuTu) * buoc
        withAnimation(giam ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86).delay(tre)) {
            hien = true
        }
    }
}

extension View {
    func xuatHienLanLuot(_ thuTu: Int, bat: Bool = true, buoc: Double = 0.05) -> some View {
        modifier(XuatHienLanLuot(thuTu: thuTu, bat: bat, buoc: buoc))
    }
}

// MARK: Ánh lướt (shimmer) cho khung tải

/// Dải sáng lướt chéo qua nội dung (cắt theo đúng hình nội dung). Giảm chuyển động ⇒ không lướt.
struct AnhLuot: ViewModifier {
    var bat = true
    @Environment(\.accessibilityReduceMotion) private var giam
    @Environment(\.colorScheme) private var cheDo
    @State private var pha: CGFloat = -1

    func body(content: Content) -> some View {
        if !bat || giam {
            content
        } else {
            content
                .overlay {
                    GeometryReader { g in
                        let w = max(g.size.width, 1)
                        LinearGradient(colors: [.clear, Color.white.opacity(cheDo == .dark ? 0.10 : 0.55), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: w * 0.45)
                            .rotationEffect(.degrees(14))
                            .offset(x: pha * w * 1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
                .onAppear {
                    pha = -1
                    withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) { pha = 1 }
                }
        }
    }
}

extension View {
    /// Ánh lướt cho khung xương đang tải.
    func anhLuot(_ bat: Bool = true) -> some View { modifier(AnhLuot(bat: bat)) }
}

// MARK: Rung lắc (lỗi đăng nhập)

/// Lắc ngang — tăng `lan` (Int) mỗi lần có lỗi là lắc một lượt. Giảm chuyển động ⇒ người gọi không tăng.
struct RungLac: GeometryEffect {
    var lan: CGFloat
    var bienDo: CGFloat = 9
    var animatableData: CGFloat {
        get { lan }
        set { lan = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: bienDo * sin(lan * .pi * 4), y: 0))
    }
}

// MARK: Thanh tiến độ vô hạn

/// Thanh tiến độ không xác định — một đoạn màu thương hiệu chạy qua lại. Giảm chuyển động ⇒ cả thanh nhấp nháy nhẹ.
struct ThanhTienDoVoHan<Mau: ShapeStyle>: View {
    let mau: Mau
    var nen: Color = Color.gray.opacity(0.18)
    var cao: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var giam

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(nen)
                    if giam {
                        Capsule().fill(mau).opacity(0.55 + 0.35 * sin(t * 2.4))
                    } else {
                        // Đoạn dài 38% chạy 1,1 s một lượt, nhanh dần rồi chậm dần (ease in-out).
                        let p = (t.truncatingRemainder(dividingBy: 1.1)) / 1.1
                        let e = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
                        let dai = w * 0.38
                        Capsule().fill(mau)
                            .frame(width: dai)
                            .offset(x: -dai + (w + dai) * e)
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: cao)
        .accessibilityHidden(true)
    }
}

// MARK: - Lịch màn khởi động (trạng thái thuần — có kiểm thử đơn vị)
//
// Màn khởi động chạy SONG SONG với việc khôi phục phiên (đọc token + tải hồ sơ). Luật:
//   1. Chạm để bỏ qua ⇒ thoát NGAY.
//   2. Khôi phục xong TRƯỚC khi hoạt hình hết ⇒ không bắt đợi đoạn "đứng ngắm": thoát ngay khi logo đã hiện đủ
//      (`toiThieu`) — tức hoạt hình vẫn chạy trọn phần chính, chỉ là kết thúc nhanh.
//   3. Khôi phục xong SAU khi hoạt hình hết ⇒ đợi nó, nhưng không quá `tran` — màn khởi động không bao giờ
//      chặn đường vào app (hồ sơ tải chậm thì màn sau tự hiện trạng thái tải của nó).

struct LichKhoiDong: Equatable {
    /// Mốc logo + chữ đã hiện đủ — sớm nhất được phép thoát (trừ khi bỏ qua).
    var toiThieu: TimeInterval
    /// Mốc hoạt hình hết tự nhiên.
    var tuNhien: TimeInterval
    /// Đợi khôi phục phiên tối đa tới mốc này.
    var tran: TimeInterval
    /// Thời gian của chuyển cảnh thoát (phóng vào logo + mờ).
    var thoat: TimeInterval

    /// Mốc BẮT ĐẦU thoát, nếu đã quyết được ở thời điểm `bayGio`; `nil` = còn chờ.
    /// - Parameters:
    ///   - khoiPhuc: mốc khôi phục phiên xong (giây kể từ lúc màn khởi động bắt đầu), `nil` = chưa xong.
    ///   - boQua: mốc người dùng chạm bỏ qua, `nil` = không bỏ qua.
    func batDauThoat(khoiPhuc: TimeInterval?, boQua: TimeInterval?, bayGio: TimeInterval) -> TimeInterval? {
        var ung: [TimeInterval] = []
        if let boQua { ung.append(boQua) }
        if let r = khoiPhuc {
            ung.append(r <= tuNhien ? max(toiThieu, r) : min(r, tran))
        } else if bayGio >= tran {
            ung.append(tran)
        }
        guard let moc = ung.min() else { return nil }
        // Chưa tới mốc đó thì vẫn "đã quyết" — người gọi đợi tới mốc; mốc không bao giờ lùi về quá khứ của nó.
        return moc
    }

    /// Tiến độ chuyển cảnh thoát 0…1 ở thời điểm `t` (0 khi chưa bắt đầu).
    func tienDoThoat(batDau: TimeInterval?, t: TimeInterval) -> Double {
        guard let b = batDau, t > b else { return 0 }
        return min(1, (t - b) / max(thoat, 0.01))
    }

    /// Màn khởi động đã xong hẳn (gỡ khỏi cây view).
    func daXong(batDau: TimeInterval?, t: TimeInterval) -> Bool {
        guard let b = batDau else { return false }
        return t >= b + thoat
    }
}

/// Bộ điều phối: giữ mốc bắt đầu, nhận "khôi phục xong"/"bỏ qua", báo khi xong. View đọc `t` qua TimelineView.
@MainActor
final class DieuPhoiKhoiDong: ObservableObject {
    let lich: LichKhoiDong
    /// Mốc 0 = khung hình ĐẦU TIÊN của màn (đặt lại trong `chay`), không phải lúc tạo đối tượng: lần mở nguội đầu
    /// tiên luồng chính có thể bận gần 1 giây trước khi vẽ được gì — tính từ lúc tạo thì nửa hoạt hình đã "trôi" mất.
    private(set) var batDau = Date()
    private var daBaoThoat = false
    @Published private(set) var mocKhoiPhuc: TimeInterval?
    @Published private(set) var mocBoQua: TimeInterval?
    @Published private(set) var mocThoat: TimeInterval?
    @Published private(set) var xong = false
    private var vongLap: Task<Void, Never>?

    init(lich: LichKhoiDong) { self.lich = lich }

    /// Đồng hồ ẢO của màn khởi động: cộng dồn từng nhịp nhưng mỗi nhịp tối đa 50 ms. Lần mở nguội luồng chính hay
    /// nghẽn vài trăm ms (nạp phông, Keychain, dựng cây view) — đồng hồ tường sẽ nhảy cóc qua cả đoạn vẽ nét; đồng hồ
    /// ảo chỉ chậm lại chứ không bỏ khung. View đọc `t` mỗi khung hình (TimelineView) — vòng `chay` cập nhật nó.
    private(set) var t: TimeInterval = 0
    private var nhipCuoi = Date()

    private func tienDongHo() {
        let bay = Date()
        t += min(0.05, max(0, bay.timeIntervalSince(nhipCuoi)))
        nhipCuoi = bay
    }

    func baoKhoiPhucXong() {
        guard mocKhoiPhuc == nil else { return }
        mocKhoiPhuc = t
        tinhLai()
    }

    func boQua() {
        guard mocBoQua == nil, !xong else { return }
        mocBoQua = t
        tinhLai()
    }

    /// Chạy vòng nhẹ (~120 lần/giây trong ~2 giây — chỉ cộng số) để tiến đồng hồ ảo, chốt mốc thoát, báo xong.
    func chay(khiBatDauThoat: @escaping () -> Void = {}, khiXong: @escaping () -> Void) {
        guard vongLap == nil else { return }
        batDau = Date()
        nhipCuoi = batDau
        t = 0
        vongLap = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.tienDongHo()
                self.tinhLai()
                if !self.daBaoThoat, let m = self.mocThoat, self.t >= m {
                    self.daBaoThoat = true
                    KhoiDongChung.shared.dangChieu = false
                    khiBatDauThoat()
                }
                if self.lich.daXong(batDau: self.mocThoat, t: self.t) {
                    self.xong = true
                    khiXong()
                    return
                }
                try? await Task.sleep(nanoseconds: 8_000_000)
            }
        }
    }

    func dung() { vongLap?.cancel() }

    private func tinhLai() {
        let moi = lich.batDauThoat(khoiPhuc: mocKhoiPhuc, boQua: mocBoQua, bayGio: t)
        if let moi, moi != mocThoat {
            // Mốc chỉ được SỚM lên (bỏ qua giữa chừng), không lùi lại sau khi đã bắt đầu thoát.
            if let cu = mocThoat, cu <= t { return }
            mocThoat = moi
        }
    }
}

/// Màn khởi động còn đang CHE màn bên dưới không. Màn đăng nhập (tấm trượt lên) và hàng "xuất hiện lần lượt" đợi cờ
/// này tắt — chạy hoạt hình sau lớp che là phí, người dùng không thấy gì. Tắt ngay khi màn khởi động bắt đầu thoát.
@MainActor
final class KhoiDongChung: ObservableObject {
    static let shared = KhoiDongChung()
    @Published var dangChieu = false
}

// MARK: Hàm thời gian dùng cho hoạt hình theo khung hình

enum DuongCong {
    /// Kẹp 0…1 của đoạn [a, b].
    static func doan(_ t: Double, _ a: Double, _ b: Double) -> Double {
        guard b > a else { return t >= b ? 1 : 0 }
        return min(1, max(0, (t - a) / (b - a)))
    }
    static func ra(_ x: Double) -> Double { 1 - pow(1 - x, 3) }               // ease-out bậc 3
    static func vao(_ x: Double) -> Double { x * x * x }                        // ease-in bậc 3
    static func vaoRa(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    /// Lò xo vọt quá rồi về 1 (x = giây kể từ lúc bắt đầu). 0 khi x <= 0.
    static func loXo(_ x: Double, tanSo: Double = 13, giam: Double = 7) -> Double {
        guard x > 0 else { return 0 }
        return 1 - exp(-giam * x) * cos(tanSo * x)
    }
}
