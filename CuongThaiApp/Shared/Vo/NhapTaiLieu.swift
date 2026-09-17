#if os(iOS)
import SwiftUI
import UIKit
import VisionKit

/// Máy quét tài liệu của hệ thống — chụp trang sách, tự nắn phối cảnh và cắt
/// mép. Đây là thứ biến "chụp ảnh trang sách nghiêng nghiêng" thành một
/// trang phẳng đọc được.
struct MayQuetTaiLieu: UIViewControllerRepresentable {
    let xong: ([Data]) -> Void
    @Environment(\.dismiss) private var dong

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Dieu { Dieu(xong: xong, dong: { dong() }) }

    final class Dieu: NSObject, VNDocumentCameraViewControllerDelegate {
        let xong: ([Data]) -> Void
        let dong: () -> Void
        init(xong: @escaping ([Data]) -> Void, dong: @escaping () -> Void) {
            self.xong = xong; self.dong = dong
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var ds: [Data] = []
            for i in 0..<scan.pageCount {
                // JPEG 0.8: một trang sách quét ở chất lượng 1.0 nặng ~4MB,
                // ở 0.8 còn ~900KB mà mắt không phân biệt được — và nó nhân
                // lên theo từng trang trong vở.
                if let d = scan.imageOfPage(at: i).jpegData(compressionQuality: 0.8) {
                    ds.append(d)
                }
            }
            xong(ds)
            dong()
        }

        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { dong() }
        func documentCameraViewController(_ c: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            NhatKy.vo.error("quét tài liệu hỏng: \(error.localizedDescription)")
            dong()
        }
    }
}

/// Hỏi nhập bao nhiêu trang PDF.
struct HoiNhapPdfView: View {
    let tenTep: String
    let soTrang: Int
    let nhap: (Int, Int) -> Void          // từ trang, đến trang (đếm từ 1)

    @Environment(\.dismiss) private var dong
    @State private var tu = 1
    @State private var den: Int

    init(tenTep: String, soTrang: Int, nhap: @escaping (Int, Int) -> Void) {
        self.tenTep = tenTep
        self.soTrang = soTrang
        self.nhap = nhap
        _den = State(initialValue: min(soTrang, 50))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(T("Tệp")); Spacer()
                        Text(tenTep).foregroundStyle(AppColors.textTertiary).lineLimit(1)
                    }
                    HStack {
                        Text(T("Số trang")); Spacer()
                        Text("\(soTrang)").foregroundStyle(AppColors.textTertiary)
                    }
                }
                Section {
                    Stepper("\(T("Từ trang")) \(tu)", value: $tu, in: 1...soTrang)
                        .onChange(of: tu) { _, m in if den < m { den = m } }
                    Stepper("\(T("Đến trang")) \(den)", value: $den, in: 1...soTrang)
                        .onChange(of: den) { _, m in if tu > m { tu = m } }
                } header: {
                    Text(T("Nhập những trang nào"))
                } footer: {
                    Text(T("Mỗi trang PDF thành một trang vở, viết đè lên được. Nét viết nằm ở lớp riêng — xoá nét không đụng tới tài liệu gốc."))
                }
                if den - tu + 1 > 60 {
                    Section {
                        Label(T("Nhập \(den - tu + 1) trang một lúc sẽ hơi lâu. Cân nhắc chia nhỏ."),
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(AppColors.warning)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(T("Nhập PDF"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("\(T("Nhập")) \(den - tu + 1) \(T("trang"))") {
                        nhap(tu, den)
                        dong()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
#endif
