#if os(iOS)
import PencilKit
import UIKit
import Vision

/// Đọc chữ viết tay trên một trang vở thành văn bản, để TÌM KIẾM được.
///
/// Văn bản đọc ra KHÔNG thay thế nét viết — nét vẫn là thứ người dùng thấy.
/// Nó chỉ nằm trong `TrangVo.chuNhanDang` làm chỉ mục tìm kiếm: gõ "đạo hàm"
/// là ra đúng trang đã viết chữ đó, thay vì lật tay qua 200 trang.
///
/// ✅ Vision đọc được **30 thứ tiếng, CÓ tiếng Việt** — mã `vi-VT` (không
/// phải `vi-VN` như chuẩn ngôn ngữ thường dùng; đo thật 17/09/2026 bằng
/// `supportedRecognitionLanguages`). Cùng với `ja-JP`, `zh-Hans/Hant`,
/// `en-US`, `ko-KR`, đủ cho mọi thứ người dùng này viết.
///
/// Toàn bộ chạy NGAY TRÊN MÁY: không cần mạng, không gửi trang vở đi đâu.
enum DocChuViet {

    /// Các thứ tiếng máy đọc được ngay trên máy, không cần mạng.
    static var tiengTrenMay: [String] {
        (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
            for: .accurate, revision: VNRecognizeTextRequestRevision3)) ?? []
    }

    static var coTiengViet: Bool {
        tiengTrenMay.contains { $0.hasPrefix("vi") }
    }

    /// Đọc chữ trong một trang, NGAY TRÊN MÁY.
    ///
    /// Trả về chuỗi rỗng khi trang không có nét hoặc không đọc ra chữ nào —
    /// vở toàn hình vẽ là chuyện bình thường, không phải lỗi.
    /// Đọc một trang, CHẠY HAI LƯỢT rồi gộp.
    ///
    /// ⚠️⚠️ THỨ TỰ trong `recognitionLanguages` quyết định kết quả, không
    /// phải "đưa hết vào rồi Vision tự chọn". Đo thật 17/09/2026 với 微分と積分:
    ///   `["ja-JP"]`                  → 微分と積分  ✅
    ///   `["ja-JP","vi-VT","en-US"]`  → 微分と積分  ✅
    ///   `["vi-VT","en-US","ja-JP"]`  → **RỖNG**  ❌ (có chữ còn đọc bậy ra "05 tita")
    /// Ngôn ngữ đứng ĐẦU áp đảo phần còn lại. Nên một danh sách duy nhất thì
    /// luôn hy sinh một hệ chữ.
    ///
    /// Cách làm: chạy lượt chữ Latin (Việt/Anh) và lượt chữ Nhật riêng, gộp
    /// cả hai vào chỉ mục. Lượt sai hệ chữ sinh ra ít rác, nhưng rác trong
    /// chỉ mục TÌM KIẾM là vô hại — người dùng gõ "đạo hàm" thì mấy chữ rác
    /// không chen vào được. Bỏ một lượt mới là mất hẳn khả năng tìm.
    /// - Parameters:
    ///   - nenPdfTen/nenPdfTrang/nenAnhTen: NỀN tài liệu của trang.
    ///
    /// ⚠️ Phải đọc cả nền, không chỉ nét bút. Vở nhập từ PDF giáo trình gần
    /// như KHÔNG có chữ viết tay — chỉ vài nét gạch chân — nên đọc mỗi mực
    /// thì "Hỏi AI về cả vở" luôn báo không có gì để gửi. Đó đúng là thứ
    /// người dùng gặp 18/09/2026 với 13 tệp JPD123.
    static func doc(net: PKDrawing, khoTrang: CGSize,
                    ngonNgu: [String]? = nil,
                    nenPdfTen: String? = nil, nenPdfTrang: Int = 0,
                    nenAnhTen: String? = nil) async -> String {
        if let ngonNgu {
            return await docMotLuot(net: net, khoTrang: khoTrang, ngonNgu: ngonNgu,
                                    nenPdfTen: nenPdfTen, nenPdfTrang: nenPdfTrang,
                                    nenAnhTen: nenAnhTen)
        }
        async let latin = docMotLuot(net: net, khoTrang: khoTrang,
                                     ngonNgu: ["vi-VT", "en-US"],
                                     nenPdfTen: nenPdfTen, nenPdfTrang: nenPdfTrang,
                                     nenAnhTen: nenAnhTen)
        async let nhat = docMotLuot(net: net, khoTrang: khoTrang,
                                    ngonNgu: ["ja-JP", "zh-Hans"],
                                    nenPdfTen: nenPdfTen, nenPdfTrang: nenPdfTrang,
                                    nenAnhTen: nenAnhTen)
        let (a, b) = await (latin, nhat)
        // Bỏ lượt rỗng, và bỏ lượt trùng hệt lượt kia.
        if a.isEmpty { return b }
        if b.isEmpty || a == b { return a }
        return a + "\n" + b
    }

    private static func docMotLuot(net: PKDrawing, khoTrang: CGSize,
                                   ngonNgu: [String],
                                   nenPdfTen: String? = nil, nenPdfTrang: Int = 0,
                                   nenAnhTen: String? = nil) async -> String {
        let coNen = nenPdfTen != nil || nenAnhTen != nil
        guard !net.strokes.isEmpty || coNen else { return "" }

        // Vẽ nền + nét lên nền TRẮNG ở 2×: Vision đọc ảnh, và nét mảnh trên
        // nền trong suốt thì nó gần như không thấy gì.
        let ty: CGFloat = 2
        let kho = CGSize(width: khoTrang.width * ty, height: khoTrang.height * ty)
        let anh = UIGraphicsImageRenderer(size: kho).image { ctx in
            UIColor.white.setFill()
            let o = CGRect(origin: .zero, size: kho)
            ctx.fill(o)
            if let ten = nenPdfTen,
               let nen = NenTrangView.veTrangPdf(ten: ten, trang: nenPdfTrang, kho: kho) {
                nen.draw(in: o)
            } else if let ten = nenAnhTen,
                      let d = try? Data(contentsOf: KhoVo.duongDanNen(ten)),
                      let nen = UIImage(data: d) {
                nen.draw(in: o)
            }
            if !net.strokes.isEmpty {
                net.image(from: CGRect(origin: .zero, size: khoTrang), scale: ty)
                    .draw(in: o)
            }
        }
        guard let cg = anh.cgImage else { return "" }

        return await withCheckedContinuation { tra in
            let yc = VNRecognizeTextRequest { req, loi in
                if let loi {
                    NhatKy.vo.error("đọc chữ viết hỏng: \(loi.localizedDescription)")
                    tra.resume(returning: "")
                    return
                }
                let dong = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                tra.resume(returning: dong.joined(separator: "\n"))
            }
            yc.recognitionLevel = .accurate
            // Chữ viết tay rời rạc hơn chữ in nhiều; bật sửa theo ngôn ngữ
            // giúp đoán đúng từ khi vài nét bị nhoè.
            yc.usesLanguageCorrection = true
            // Lọc theo mã ĐẦY ĐỦ trước, rồi mới theo tiền tố: `vi` khớp
            // `vi-VT` nhờ tiền tố, nhưng đưa thẳng mã sai cho Vision thì nó
            // bỏ qua ngôn ngữ đó mà không báo gì.
            yc.recognitionLanguages = ngonNgu.compactMap { ma in
                tiengTrenMay.first { $0 == ma }
                    ?? tiengTrenMay.first { $0.hasPrefix(String(ma.prefix(2))) }
            }
            if yc.recognitionLanguages.isEmpty { yc.recognitionLanguages = ["en-US"] }

            do {
                try VNImageRequestHandler(cgImage: cg, options: [:]).perform([yc])
            } catch {
                NhatKy.vo.error("dựng yêu cầu đọc chữ hỏng: \(error.localizedDescription)")
                tra.resume(returning: "")
            }
        }
    }

    /// Đọc CẢ CUỐN, chạy nền, bỏ qua trang đã đọc rồi và chưa sửa gì thêm.
    ///
    /// ⚠️ Đọc tuần tự chứ không song song: mỗi lượt Vision dựng một ảnh A4 ở
    /// 2× (~1.400×2.000 điểm ảnh) và ăn kha khá bộ nhớ. Bắn 200 trang cùng
    /// lúc là app bị hệ thống thu hồi giữa buổi học.
    @MainActor
    static func docCaCuon(_ trangs: [TrangVo], tienDo: @escaping (Int, Int) -> Void) async {
        let canDoc = trangs.filter { t in
            // ⚠️ Trang CHỈ có nền (PDF giáo trình, chưa viết gì) vẫn phải
            // đọc: nội dung học nằm ở nền, không ở mực.
            guard t.coNet || t.nenPdfTen != nil || t.nenAnhTen != nil else { return false }
            guard let luc = t.nhanDangLuc else { return true }
            return t.suaLuc > luc
        }
        guard !canDoc.isEmpty else { tienDo(0, 0); return }

        for (i, t) in canDoc.enumerated() {
            tienDo(i, canDoc.count)
            let net = KhoVo.nap(t.id)
            let chu = await doc(net: net, khoTrang: t.khoTrang,
                                nenPdfTen: t.nenPdfTen, nenPdfTrang: t.nenPdfTrang,
                                nenAnhTen: t.nenAnhTen)
            t.chuNhanDang = chu.isEmpty ? nil : chu
            t.nhanDangLuc = Date()
        }
        tienDo(canDoc.count, canDoc.count)
    }
}
#endif
