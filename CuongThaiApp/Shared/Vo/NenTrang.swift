#if os(iOS)
import PDFKit
import UIKit

/// Nền trang là một trang PDF hoặc một ảnh quét, nằm DƯỚI lớp mực.
///
/// ⚠️ Vẽ ra `UIImage` một lần rồi dùng lại, không render PDF mỗi khi phóng
/// to: `PDFPage.thumbnail` dựng lại cả trang, và gọi nó trong
/// `scrollViewDidZoom` là mỗi ngón tay nhích một chút lại dựng một trang A4.
final class NenTrangView: UIView {

    private let anhView = UIImageView()
    private var khoaHienTai: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        anhView.contentMode = .scaleAspectFit
        anhView.backgroundColor = .clear
        addSubview(anhView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) chưa dùng tới") }

    override func layoutSubviews() {
        super.layoutSubviews()
        anhView.frame = bounds
    }

    /// Đặt nền. `khoa` gộp tên tệp + số trang + bề rộng, để biết khi nào cần
    /// vẽ lại và khi nào dùng lại ảnh cũ.
    func dat(pdfTen: String?, trang: Int, anhTen: String?, khoTrang: CGSize) {
        let khoa = "\(pdfTen ?? anhTen ?? "-")#\(trang)@\(Int(khoTrang.width))"
        guard khoa != khoaHienTai else { return }
        khoaHienTai = khoa

        if let anhTen {
            anhView.image = UIImage(contentsOfFile: KhoVo.duongDanNen(anhTen).path)
            return
        }
        guard let pdfTen else { anhView.image = nil; return }
        // Vẽ ở 2× khổ trang: đủ nét khi phóng to vừa phải mà không tốn bộ nhớ
        // như vẽ ở 5× (một trang A4 ở 5× là ~18 triệu điểm ảnh).
        anhView.image = Self.veTrangPdf(ten: pdfTen, trang: trang,
                                        kho: CGSize(width: khoTrang.width * 2,
                                                    height: khoTrang.height * 2))
    }

    static func veTrangPdf(ten: String, trang: Int, kho: CGSize) -> UIImage? {
        guard let tl = PDFDocument(url: KhoVo.duongDanNen(ten)),
              trang >= 0, trang < tl.pageCount,
              let p = tl.page(at: trang) else { return nil }
        return p.thumbnail(of: kho, for: .mediaBox)
    }

    /// Số trang của một tệp PDF trong kho.
    static func soTrangPdf(ten: String) -> Int {
        PDFDocument(url: KhoVo.duongDanNen(ten))?.pageCount ?? 0
    }

    /// Khổ trang PDF theo point, để trang vở khớp đúng tỉ lệ giấy gốc thay
    /// vì ép mọi thứ về A4 — slide 16:9 mà nhét vào A4 dọc thì chữ bé tí và
    /// thừa hai mảng trắng.
    static func khoTrangPdf(ten: String, trang: Int = 0) -> CGSize? {
        guard let tl = PDFDocument(url: KhoVo.duongDanNen(ten)),
              trang < tl.pageCount, let p = tl.page(at: trang) else { return nil }
        let r = p.bounds(for: .mediaBox)
        guard r.width > 0, r.height > 0 else { return nil }
        return CGSize(width: r.width, height: r.height)
    }
}
#endif
