#if os(iOS)
import PencilKit
import SwiftUI
import UIKit

// MARK: - Xuất trang / cuốn vở ra PDF
//
// Mỗi trang vở = một trang PDF đúng khổ THẬT của trang (khổ cuốn + phần nối
// dài — không mặc định A4), ba lớp như trên màn:
// giấy kẻ → nền tài liệu (PDF/ảnh quét) → nét bút.
//
// ⚠️ Vẽ trong chế độ SÁNG, bất kể máy đang tối. `PKDrawing.image(...)` và
// màu giấy (`UIColor { traits in … }`) đều đọc trait HIỆN HÀNH: xuất lúc máy
// đang tối là ra tệp nền đen chữ trắng — in ra giấy hay gửi cho bạn đọc trên
// máy tính đều sai. Bọc mọi thứ trong `performAsCurrent` của trait sáng.

enum XuatPdfVo {

    /// Dựng tệp PDF vào thư mục tạm, trả về đường dẫn.
    @MainActor
    static func taoPdf(trangs: [TrangVo], tenTep: String) -> URL? {
        guard !trangs.isEmpty else { return nil }
        let an = tenTep.replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent((an.isEmpty ? "Vo" : an) + ".pdf")
        try? FileManager.default.removeItem(at: url)

        // Chụp dữ liệu trên luồng chính (model SwiftData) trước khi vẽ.
        struct Tho { let id: UUID; let kho: CGSize; let khoGoc: CGSize; let giay: LoaiGiay
                     let pdf: String?; let pdfTrang: Int; let anh: String? }
        let ds = trangs.map { Tho(id: $0.id, kho: $0.khoTrang, khoGoc: $0.khoGoc, giay: $0.giay,
                                  pdf: $0.nenPdfTen, pdfTrang: $0.nenPdfTrang, anh: $0.nenAnhTen) }

        let dau = ds[0].kho
        let r = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: dau))
        var loi: Error?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            do {
                try r.writePDF(to: url) { ctx in
                    for t in ds {
                        let khung = CGRect(origin: .zero, size: t.kho)
                        ctx.beginPage(withBounds: khung, pageInfo: [:])
                        // 1. Giấy kẻ — dùng lại đúng bộ vẽ của màn viết.
                        let giay = GiayNenView(frame: khung)
                        giay.overrideUserInterfaceStyle = .light
                        giay.giay = t.giay
                        giay.khoTrang = t.kho
                        giay.caoGoc = t.khoGoc.height
                        giay.tyLe = 1
                        giay.draw(khung)
                        // 2. Nền tài liệu — phủ khổ GỐC, phần nối dài để trắng.
                        let khungNen = CGRect(origin: .zero, size: t.khoGoc)
                        if let p = t.pdf,
                           let anh = NenTrangView.veTrangPdf(ten: p, trang: t.pdfTrang,
                                                             kho: CGSize(width: t.khoGoc.width * 2,
                                                                         height: t.khoGoc.height * 2)) {
                            anh.draw(in: vuaKhung(anh.size, trong: khungNen))
                        } else if let a = t.anh,
                                  let anh = UIImage(contentsOfFile: KhoVo.duongDanNen(a).path) {
                            anh.draw(in: vuaKhung(anh.size, trong: khungNen))
                        }
                        // 3. Nét bút, 2× cho in ấn nét (trang rất to thì hạ tỉ lệ
                        // để một ảnh không vượt ~6000px cạnh dài).
                        let net = KhoVo.nap(t.id)
                        if !net.bounds.isEmpty {
                            let ty = min(2, 6000 / max(t.kho.width, t.kho.height, 1))
                            net.image(from: khung, scale: ty).draw(in: khung)
                        }
                    }
                }
            } catch { loi = error }
        }
        if let loi {
            NhatKy.vo.error("xuất PDF hỏng: \(loi.localizedDescription)")
            return nil
        }
        return url
    }

    /// Một trang ra ẢNH (giấy + nền + nét), chế độ sáng, cạnh dài tối đa `canhMax`.
    /// Dùng cho 📤 Nộp bài: AI chấm đọc ảnh, không đọc PDF.
    @MainActor
    static func anhTrang(_ t: TrangVo, canhMax: CGFloat = 2000) -> UIImage? {
        let kho = t.khoTrang, khoGoc = t.khoGoc
        guard kho.width > 0, kho.height > 0 else { return nil }
        let ty = min(2, canhMax / max(kho.width, kho.height))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = ty
        fmt.opaque = true
        var ra: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ra = UIGraphicsImageRenderer(size: kho, format: fmt).image { _ in
                let khung = CGRect(origin: .zero, size: kho)
                UIColor.white.setFill(); UIRectFill(khung)
                let giay = GiayNenView(frame: khung)
                giay.overrideUserInterfaceStyle = .light
                giay.giay = t.giay
                giay.khoTrang = kho
                giay.caoGoc = khoGoc.height
                giay.tyLe = 1
                giay.draw(khung)
                let khungNen = CGRect(origin: .zero, size: khoGoc)
                if let p = t.nenPdfTen,
                   let anh = NenTrangView.veTrangPdf(ten: p, trang: t.nenPdfTrang,
                                                     kho: CGSize(width: khoGoc.width * 2, height: khoGoc.height * 2)) {
                    anh.draw(in: vuaKhung(anh.size, trong: khungNen))
                } else if let a = t.nenAnhTen, let anh = UIImage(contentsOfFile: KhoVo.duongDanNen(a).path) {
                    anh.draw(in: vuaKhung(anh.size, trong: khungNen))
                }
                let net = KhoVo.nap(t.id)
                if !net.bounds.isEmpty { net.image(from: khung, scale: ty).draw(in: khung) }
            }
        }
        return ra
    }

    /// Đặt ảnh vừa khung, giữ tỉ lệ — khớp `scaleAspectFit` của màn viết.
    private static func vuaKhung(_ kt: CGSize, trong k: CGRect) -> CGRect {
        guard kt.width > 0, kt.height > 0 else { return k }
        let s = min(k.width / kt.width, k.height / kt.height)
        let w = kt.width * s, h = kt.height * s
        return CGRect(x: k.midX - w / 2, y: k.midY - h / 2, width: w, height: h)
    }
}

/// Cửa sổ xuất: dựng xong mới hiện nút chia sẻ (Lưu vào Tệp, AirDrop, in…).
struct XuatPdfView: View {
    let trangs: [TrangVo]
    let tenTep: String
    @Environment(\.dismiss) private var dong
    @State private var url: URL?
    @State private var loi = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.primary)
                Text(tenTep + ".pdf")
                    .font(Font.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(trangs.count) " + T("trang"))
                    .font(Font.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                if let url {
                    ShareLink(item: url) {
                        Label(T("Chia sẻ / Lưu vào Tệp"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent)
                } else if loi {
                    Text(T("Chưa xuất được tệp PDF — thử lại sau"))
                        .foregroundStyle(AppColors.error)
                } else {
                    ProgressView(T("Đang dựng PDF…"))
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(T("Xuất PDF"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Xong")) { dong() }.fontWeight(.semibold)
                }
            }
            .task {
                // Nhường một nhịp để vòng quay kịp hiện ra trước khi dựng.
                try? await Task.sleep(for: .milliseconds(80))
                url = XuatPdfVo.taoPdf(trangs: trangs, tenTep: tenTep)
                loi = url == nil
            }
        }
    }
}
#endif
