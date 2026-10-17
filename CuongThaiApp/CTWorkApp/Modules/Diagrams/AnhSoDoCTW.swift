import SwiftUI
import UIKit

// MARK: - Ảnh sơ đồ: tải có xác thực + khung phóng to/kéo
//
// `GET …/diagrams/:n/image.png` trả byte PNG (không phải envelope) và CẦN token —
// `AsyncImage` không gắn được header ⇒ tự gọi URLSession. Máy chủ KHÔNG tự vẽ: ảnh
// có sẵn khi ai đó đã mở sơ đồ trên web (hoặc máy chủ có Kroki) ⇒ 404
// `WORK_DIAGRAM_NOT_RENDERED` là trường hợp bình thường, phải nói rõ, không phải lỗi.

enum CTWAnhSoDo {
    enum Loi: LocalizedError, Equatable {
        case chuaDung, khongPhaiMermaid, khac(String)
        var errorDescription: String? {
            switch self {
            case .chuaDung: return "This version hasn't been rendered yet. It gets an image the first time someone opens it in CT Work on the web."
            case .khongPhaiMermaid: return "This is a freehand whiteboard. Whiteboards are drawn live in the browser and have no image to show here."
            case .khac(let s): return s
            }
        }
    }

    private struct Phong: Decodable { var message: String?; var code: String? }

    static func tai(pid: Int, so: Int, ban: Int?) async throws -> UIImage {
        #if DEBUG
        if XemThuCTW.man != nil { return anhMau(so: so) }
        #endif
        guard let url = URL(string: APIClient.diaChiGoc + CTWAPI.duongAnhSoDo(pid: pid, so: so, ban: ban)) else {
            throw Loi.khac("Invalid address.")
        }
        var r = URLRequest(url: url)
        r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        if let t = StorageManager.shared.getAuthToken() { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (d, res) = try await URLSession.shared.data(for: r)
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(ma), let anh = UIImage(data: d) { return anh }
        let p = try? JSONDecoder().decode(Phong.self, from: d)
        switch p?.code {
        case "WORK_DIAGRAM_NOT_RENDERED": throw Loi.chuaDung
        case "WORK_DIAGRAM_NOT_MERMAID": throw Loi.khongPhaiMermaid
        default:
            if ma == 401 { throw Loi.khac("Your session has expired. Please sign in again.") }
            if ma == 403 || ma == 404 { throw Loi.khac(p?.message ?? "You don't have access to this diagram.") }
            throw Loi.khac(p?.message ?? "Couldn't load the image (\(ma)).")
        }
    }

    #if DEBUG
    /// Ảnh mẫu cho máy chủ giả (chụp màn hình) — một sơ đồ tuần tự đơn giản.
    static func anhMau(so: Int) -> UIImage {
        let co = CGSize(width: 1400, height: 900)
        return UIGraphicsImageRenderer(size: co).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: co))
            let ten = ["Mobile app", "API", "Auth", "Database"]
            let xs: [CGFloat] = [180, 530, 880, 1230]
            let font = UIFont.systemFont(ofSize: 30, weight: .semibold)
            for (i, t) in ten.enumerated() {
                let khung = CGRect(x: xs[i] - 130, y: 40, width: 260, height: 80)
                let p = UIBezierPath(roundedRect: khung, cornerRadius: 14)
                UIColor(red: 0.93, green: 0.90, blue: 1, alpha: 1).setFill(); p.fill()
                UIColor(red: 0.48, green: 0.27, blue: 0.91, alpha: 1).setStroke(); p.lineWidth = 3; p.stroke()
                let a = NSAttributedString(string: t, attributes: [.font: font, .foregroundColor: UIColor.black])
                let s = a.size()
                a.draw(at: CGPoint(x: xs[i] - s.width / 2, y: 80 - s.height / 2))
                let l = UIBezierPath()
                l.move(to: CGPoint(x: xs[i], y: 120)); l.addLine(to: CGPoint(x: xs[i], y: 860))
                UIColor.gray.setStroke(); l.lineWidth = 2
                l.setLineDash([10, 8], count: 2, phase: 0); l.stroke()
            }
            let buoc: [(Int, Int, String)] = [(0, 1, "POST /login"), (1, 2, "verify(password)"), (2, 3, "SELECT user"),
                                              (3, 2, "user row"), (2, 1, "JWT"), (1, 0, "200 { token }")]
            for (k, b) in buoc.enumerated() {
                let y = CGFloat(200 + k * 105)
                let x1 = xs[b.0], x2 = xs[b.1]
                let l = UIBezierPath(); l.move(to: CGPoint(x: x1, y: y)); l.addLine(to: CGPoint(x: x2, y: y))
                UIColor.black.setStroke(); l.lineWidth = 3
                if b.0 > b.1 { l.setLineDash([12, 8], count: 2, phase: 0) }
                l.stroke()
                let huong: CGFloat = x2 > x1 ? -1 : 1
                let m = UIBezierPath()
                m.move(to: CGPoint(x: x2, y: y)); m.addLine(to: CGPoint(x: x2 + huong * 22, y: y - 12))
                m.addLine(to: CGPoint(x: x2 + huong * 22, y: y + 12)); m.close()
                UIColor.black.setFill(); m.fill()
                let a = NSAttributedString(string: b.2, attributes: [.font: UIFont.systemFont(ofSize: 24), .foregroundColor: UIColor.darkGray])
                a.draw(at: CGPoint(x: min(x1, x2) + 24, y: y - 38))
            }
        }
    }
    #endif
}

/// Khung PHÓNG TO / kéo bằng UIScrollView (pinch mượt hơn MagnifyGesture tự làm, và
/// nảy mép như Ảnh). Chạm hai lần: phóng 2.5× tại chỗ chạm / trở về vừa khung.
struct KhungPhongToCTW: UIViewRepresentable {
    let anh: UIImage
    var nenToi = false

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.delegate = context.coordinator
        sv.maximumZoomScale = 8
        sv.minimumZoomScale = 1
        sv.bouncesZoom = true
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .clear
        let iv = UIImageView(image: anh)
        iv.contentMode = .scaleAspectFit
        iv.isAccessibilityElement = true
        iv.accessibilityLabel = "Diagram image. Pinch to zoom."
        sv.addSubview(iv)
        context.coordinator.iv = iv
        let g = UITapGestureRecognizer(target: context.coordinator, action: #selector(DieuPhoi.chamHai(_:)))
        g.numberOfTapsRequired = 2
        sv.addGestureRecognizer(g)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        if context.coordinator.iv?.image !== anh { context.coordinator.iv?.image = anh; sv.zoomScale = 1 }
        DispatchQueue.main.async { context.coordinator.canKhung(sv) }
    }

    func makeCoordinator() -> DieuPhoi { DieuPhoi() }

    final class DieuPhoi: NSObject, UIScrollViewDelegate {
        weak var iv: UIImageView?
        private var coCu: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { iv }

        func canKhung(_ sv: UIScrollView) {
            guard let iv, let anh = iv.image, sv.bounds.width > 0 else { return }
            if sv.bounds.size != coCu || sv.zoomScale == 1 {
                coCu = sv.bounds.size
                let tl = min(sv.bounds.width / anh.size.width, sv.bounds.height / anh.size.height)
                iv.frame = CGRect(x: 0, y: 0, width: anh.size.width * tl, height: anh.size.height * tl)
                sv.contentSize = iv.frame.size
            }
            giuaGiua(sv)
        }

        func scrollViewDidZoom(_ sv: UIScrollView) { giuaGiua(sv) }

        private func giuaGiua(_ sv: UIScrollView) {
            guard let iv else { return }
            let dx = max(0, (sv.bounds.width - iv.frame.width) / 2)
            let dy = max(0, (sv.bounds.height - iv.frame.height) / 2)
            sv.contentInset = UIEdgeInsets(top: dy, left: dx, bottom: dy, right: dx)
        }

        @objc func chamHai(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? UIScrollView, let iv else { return }
            if sv.zoomScale > 1.05 { sv.setZoomScale(1, animated: true); return }
            let p = g.location(in: iv)
            let tl: CGFloat = 2.5
            let w = sv.bounds.width / tl, h = sv.bounds.height / tl
            sv.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
        }
    }
}
