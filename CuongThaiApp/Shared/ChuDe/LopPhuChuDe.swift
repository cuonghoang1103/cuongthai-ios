import SwiftUI
import Observation
#if os(iOS)
import UIKit
#endif

// ════════════════════════════════════════════════════════════════
// Hai lớp PHỦ của chủ đề — vẽ TRÊN nội dung nên cả hai đều: không nhận chạm, ẩn với VoiceOver, thưa, mờ.
//   · `LopHatMoiTrang` — vài hạt ở MÉP màn con (màn chính đã có nền mùa riêng nên lớp này tự tắt ở đó).
//   · `LopHieuUngCham` — chạm đâu bung vài cánh hoa/bông tuyết ở đó (mặc định TẮT trong Cài đặt).
// Gắn bằng `.lopHatMoiTrang()` (vùng nội dung) và `.lopHieuUngCham()` (gốc cửa sổ).
// ════════════════════════════════════════════════════════════════

extension View {
    /// Hạt thưa ở mép — gắn vào VÙNG NỘI DUNG (cột chi tiết iPad / TabView iPhone), không phủ thanh bên.
    func lopHatMoiTrang() -> some View { overlay { LopHatMoiTrang() } }

    /// Hiệu ứng chạm — gắn ở GỐC CỬA SỔ (toạ độ chạm là toạ độ cửa sổ).
    func lopHieuUngCham() -> some View {
        overlay { LopHieuUngCham() }
            #if os(iOS)
            .background(GanChamCuaSo())
            #endif
    }
}

struct LopHatMoiTrang: View {
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    @Environment(\.scenePhase) private var pha

    var body: some View {
        let ql = QuanLyChuDe.shared
        // Chỉ hiện khi đang thật sự chạy: hạt đứng yên đè lên nội dung thì không có ích gì.
        if ql.hatMoiTrang, ql.mua != nil, ql.soManNen == 0, ql.dongDuoc, !giamChuyenDong, pha == .active {
            GeometryReader { g in
                NenMua(mua: ql.mua, kieu: .phuMoiTrang, matDo: ql.matDo, trangTri: false, chay: true,
                       vungAnToan: g.safeAreaInsets)
                    .ignoresSafeArea()
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

// MARK: - Hiệu ứng khi chạm

@MainActor
@Observable
final class KhoCham {
    static let shared = KhoCham()
    struct Cham: Identifiable { let id = UUID(); let diem: CGPoint; let luc: Date }
    private(set) var ds: [Cham] = []
    func them(_ p: CGPoint) {
        let bayGio = Date()
        ds.removeAll { bayGio.timeIntervalSince($0.luc) > 1.2 }
        if ds.count < 6 { ds.append(Cham(diem: p, luc: bayGio)) }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            let bay = Date()
            self.ds.removeAll { bay.timeIntervalSince($0.luc) > 1.2 }
        }
    }
}

struct LopHieuUngCham: View {
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    var body: some View {
        let ql = QuanLyChuDe.shared
        let kho = KhoCham.shared
        if ql.hieuUngCham, let mua = ql.mua, ql.dongDuoc, !giamChuyenDong, !kho.ds.isEmpty {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                Canvas { ctx, _ in
                    let but = ButVe(ctx: ctx)
                    let mauHat = BoMauTrangTri.cua(mua).hat
                    for c in kho.ds {
                        let tau = CGFloat(tl.date.timeIntervalSince(c.luc))
                        guard tau >= 0, tau < 1.1 else { continue }
                        let doMo = Double(1 - tau / 1.1)
                        for j in 0..<8 {
                            let g = CGFloat(j) / 8 * .pi * 2 + ngauNhien(j, 7)
                            let v = 70 + ngauNhien(j, 8) * 50
                            let p = CGPoint(x: c.diem.x + cos(g) * v * tau,
                                            y: c.diem.y + sin(g) * v * tau + 60 * tau * tau)
                            let m = mauHat[j % mauHat.count]
                            switch mua {
                            case .xuan: but.to(HinhMua.canhHoa, m, tam: p, co: 9, goc: g + tau * 4, doMo: doMo)
                            case .thu: but.to(HinhMua.laPhong, m, tam: p, co: 12, goc: g + tau * 3, doMo: doMo)
                            case .dong: but.net(HinhMua.bongTuyet, Color.h(0x7FA8D8), tam: p, co: 11, goc: tau * 2, day: 1.3, doMo: doMo)
                            case .ha: but.to(HinhMua.lapLanh, Color.h(0xF5B700), tam: p, co: 10, doMo: doMo)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

#if os(iOS)
/// Gắn một bộ nhận CHẠM vào cửa sổ — chạy SONG SONG với mọi nút (không nuốt chạm, không trễ chạm), chỉ để biết toạ độ.
private struct GanChamCuaSo: UIViewRepresentable {
    func makeUIView(context: Context) -> ViewNghe { ViewNghe() }
    func updateUIView(_ uiView: ViewNghe, context: Context) {}

    final class ViewNghe: UIView, UIGestureRecognizerDelegate {
        private var nhan: UITapGestureRecognizer?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            isUserInteractionEnabled = false
            if let nhan { nhan.view?.removeGestureRecognizer(nhan); self.nhan = nil }
            guard let w = window else { return }
            let g = UITapGestureRecognizer(target: self, action: #selector(cham(_:)))
            g.cancelsTouchesInView = false
            g.delaysTouchesBegan = false
            g.delaysTouchesEnded = false
            g.delegate = self
            w.addGestureRecognizer(g)
            nhan = g
        }
        @objc private func cham(_ g: UITapGestureRecognizer) {
            guard QuanLyChuDe.shared.hieuUngCham, QuanLyChuDe.shared.mua != nil else { return }
            KhoCham.shared.them(g.location(in: g.view))
        }
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
#endif
