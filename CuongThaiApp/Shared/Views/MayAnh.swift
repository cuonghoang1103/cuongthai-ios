import SwiftUI
#if os(iOS)
import UIKit

/// Máy ảnh trong app. Dùng `UIImagePickerController` chứ không phải
/// `PhotosPicker`: `PhotosPicker` chỉ mở THƯ VIỆN, không mở được ống kính.
///
/// ⚠️ Máy ảnh KHÔNG chạy trên máy mô phỏng — `isSourceTypeAvailable(.camera)`
/// trả `false` ở đó. Nút gọi tới đây phải tự ẩn khi không có máy ảnh, không thì
/// bấm vào là màn hình đen.
struct MayAnh: UIViewControllerRepresentable {
    let xong: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var coMayAnh: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Dieu { Dieu(self) }

    final class Dieu: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let cha: MayAnh
        init(_ cha: MayAnh) { self.cha = cha }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            defer { cha.dismiss() }
            guard let anh = info[.originalImage] as? UIImage else { return }
            // Nén xuống 0.8: ảnh gốc 12MP của iPhone ra ~4-6MB, mà trần của
            // `/messages/upload` là 10MB. 0.8 giữ nét mắt thường không phân
            // biệt được nhưng cắt còn khoảng một phần ba.
            guard let data = anh.jpegData(compressionQuality: 0.8) else { return }
            cha.xong(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            cha.dismiss()
        }
    }
}
#endif
