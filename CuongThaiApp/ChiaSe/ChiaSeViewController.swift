import UIKit
import UniformTypeIdentifiers
import Social

// ════════════════════════════════════════════════════════════════
// SHARE EXTENSION — "Chia sẻ → CuongThai" từ app YouTube/TikTok
//
// Extension KHÔNG tự gọi API: nó không có token đăng nhập (token nằm trong
// Keychain của app chính, không chia sẻ), và một extension bị hệ thống cấp
// rất ít bộ nhớ/thời gian. Nó chỉ làm đúng một việc: ghi link vào NHÓM ỨNG
// DỤNG rồi đánh thức app chính.
//
// ⚠️ Ghi vào nhóm TRƯỚC khi mở app. Nếu mở trước thì app có thể đọc trúng
// lúc chưa ghi xong và không thấy gì — hỏng câm, không có lỗi nào.
// ════════════════════════════════════════════════════════════════

final class ChiaSeViewController: UIViewController {

    static let nhom = "group.com.cuongthai.app"
    static let khoa = "videoChoThem"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await xuLy() }
    }

    private func xuLy() async {
        guard let lien = await layLien() else {
            baoVaDong(loi: "Không tìm thấy link video trong nội dung chia sẻ.")
            return
        }

        let d = UserDefaults(suiteName: Self.nhom)
        d?.set(lien, forKey: Self.khoa)
        d?.set(Date().timeIntervalSince1970, forKey: Self.khoa + ".luc")
        d?.synchronize()

        baoVaDong(loi: nil)

        // Mở app chính. `NSExtensionContext.open` chạy được trong share
        // extension, nhưng KHÔNG đảm bảo — nếu hệ thống từ chối thì link vẫn
        // nằm trong nhóm và app sẽ nhặt ở lần mở kế tiếp.
        if let u = URL(string: "cuongthai://them-video") {
            _ = await moApp(u)
        }
    }

    /// Lấy link từ mọi kiểu đính kèm mà app chia sẻ có thể gửi sang: URL
    /// thật, hoặc chuỗi chữ có chứa link (YouTube gửi kiểu này khi chia sẻ
    /// kèm tiêu đề).
    private func layLien() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            for dinh in item.attachments ?? [] {
                if dinh.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let u = try? await dinh.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    return u.absoluteString
                }
                if dinh.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let s = try? await dinh.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                   let u = doLink(trong: s) {
                    return u
                }
            }
            if let s = item.attributedContentText?.string, let u = doLink(trong: s) { return u }
        }
        return nil
    }

    private func doLink(trong s: String) -> String? {
        guard let dd = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let r = NSRange(s.startIndex..<s.endIndex, in: s)
        for m in dd.matches(in: s, range: r) {
            if let u = m.url?.absoluteString { return u }
        }
        return nil
    }

    private func moApp(_ u: URL) async -> Bool {
        await withCheckedContinuation { tiep in
            extensionContext?.open(u) { xong in tiep.resume(returning: xong) }
        }
    }

    private func baoVaDong(loi: String?) {
        let hop = UIAlertController(
            title: loi == nil ? "Đã nhận video" : "Chưa nhận được",
            message: loi ?? "Mở CuongThai để thêm video này vào phần Học bằng video.",
            preferredStyle: .alert)
        hop.addAction(UIAlertAction(title: "Xong", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        present(hop, animated: true)
    }
}
