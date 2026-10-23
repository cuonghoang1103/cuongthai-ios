#if DEBUG && os(iOS)
import SwiftUI
import UIKit
import QuartzCore

// ════════════════════════════════════════════════════════════════
// ĐO ĐỘ MƯỢT KHI CUỘN BÀI (màn soi, chỉ DEBUG) — phép đo lặp lại được cho
// lỗi "bài Chữ Hán cuộn giật" (iPad Pro 11", 23/10/2026).
//
//     SIMCTL_CHILD_CT_XEM_MAN=sachhoc-bai:b5-kanji SIMCTL_CHILD_CT_SACHHOC_DO=2500 …
//
// Bài nạp xong ⇒ chờ 2 s ⇒ tự cuộn ĐỀU (pt/giây) từ đầu tới đáy (lượt 1, lần
// đầu dựng — cái người học cảm thấy), rồi ngược lên (lượt 2), rồi xuống lần nữa
// (lượt 3). Mỗi khung hình đọc khoảng cách CADisplayLink: khung trễ hơn 1,5×
// nhịp chuẩn là một "hitch"; thời gian trễ cộng dồn chia cho thời gian cuộn ⇒
// tỉ lệ hitch (ms/giây, như XCTOSSignpostMetric của Apple: < 5 tốt, > 10 khó chịu).
// Kết quả ghi `Documents/do-cuon.txt` + NSLog `[DO-CUON]`.
// ════════════════════════════════════════════════════════════════

/// Đếm số lần `body` chạy (màn soi đo) — in kèm kết quả mỗi lượt.
@MainActor enum DemBodySH {
    static var dem: [String: Int] = [:]
    static func tang(_ k: String) { dem[k, default: 0] += 1 }
    static func chuoi() -> String { dem.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ") }
}

struct MocDoCuonSH: UIViewRepresentable {
    let ten: String
    let tocDo: CGFloat

    func makeUIView(context: Context) -> DoCuonUI {
        let v = DoCuonUI()
        v.ten = ten; v.tocDo = tocDo
        v.isUserInteractionEnabled = false
        return v
    }
    func updateUIView(_ v: DoCuonUI, context: Context) {}
}

final class DoCuonUI: UIView {
    var ten = ""
    var tocDo: CGFloat = 2500
    private weak var cuon: UIScrollView?
    private var link: CADisplayLink?
    private var daBatDau = false

    private var luot = 0          // 1 xuống · 2 lên · 3 xuống
    private var y: CGFloat = 0
    private var truoc: CFTimeInterval = 0
    private var batDauLuot: CFTimeInterval = 0
    private var khung = 0
    private var hitch: Double = 0
    private var soHitch = 0
    private var toiDa: Double = 0
    private var ketQua: [String] = []
    /// Khung > 50 ms của lượt 1 kèm vị trí cuộn — để biết khối nào gây giật.
    private var khungDai: [String] = []

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !daBatDau else { return }
        daBatDau = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.batDau() }
    }

    private func batDau() {
        var v: UIView? = superview
        while let x = v, !(x is UIScrollView && (x as! UIScrollView).bounds.height > 300) { v = x.superview }
        guard let sv = v as? UIScrollView else { NSLog("[DO-CUON] không thấy UIScrollView"); return }
        cuon = sv
        DemBodySH.dem = [:]
        NSLog("[DO-CUON] focusSystem=%@", UIFocusSystem.focusSystem(for: self) == nil ? "nil" : "CÓ")
        ketQua.append("focusSystem=\(UIFocusSystem.focusSystem(for: self) == nil ? "nil" : "CÓ")")
        sv.setContentOffset(.zero, animated: false)
        let l = CADisplayLink(target: self, selector: #selector(buoc(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
        moLuot(1)
    }

    private func moLuot(_ n: Int) {
        luot = n; khung = 0; hitch = 0; soHitch = 0; toiDa = 0; truoc = 0; batDauLuot = 0
    }

    @objc private func buoc(_ l: CADisplayLink) {
        guard let sv = cuon else { l.invalidate(); return }
        let nhip = l.targetTimestamp - l.timestamp
        if truoc > 0 {
            let dt = l.timestamp - truoc
            khung += 1
            toiDa = max(toiDa, dt)
            if dt > nhip * 1.5 { hitch += dt - nhip; soHitch += 1 }
            if dt > 0.05, luot == 1 { khungDai.append(String(format: "%.0fms@y%.0f", dt * 1000, y)) }
            y += tocDo * CGFloat(min(dt, 0.1)) * (luot == 2 ? -1 : 1)
        } else {
            batDauLuot = l.timestamp
        }
        truoc = l.timestamp
        let day = max(0, sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom)
        let dinh = -sv.adjustedContentInset.top
        y = min(max(y, dinh), day)
        sv.contentOffset = CGPoint(x: sv.contentOffset.x, y: y)
        let xong = luot == 2 ? y <= dinh + 0.5 : (y >= day - 0.5 && l.timestamp - batDauLuot > 0.5)
        guard xong else { return }
        let tg = l.timestamp - batDauLuot
        let dong = String(format: "%@ lượt %d (%@): %.1f s · %d khung · hitch %d lần · %.0f ms ⇒ %.1f ms/s · khung tệ nhất %.0f ms · cao nội dung %.0f",
                          ten, luot, luot == 2 ? "lên" : "xuống", tg, khung, soHitch, hitch * 1000, hitch * 1000 / max(tg, 0.001), toiDa * 1000, sv.contentSize.height)
        NSLog("[DO-CUON] %@", dong)
        ketQua.append(dong + " · body: " + DemBodySH.chuoi())
        DemBodySH.dem = [:]
        if luot == 1, !khungDai.isEmpty { ketQua.append("  khung dài: " + khungDai.joined(separator: " ")) }
        if luot < 3 { moLuot(luot + 1) } else { l.invalidate(); ghi() }
    }

    private func ghi() {
        guard let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let u = d.appendingPathComponent("do-cuon.txt")
        let cu = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
        try? (cu + ketQua.joined(separator: "\n") + "\nXONG\n").write(to: u, atomically: true, encoding: .utf8)
    }
}
#endif
