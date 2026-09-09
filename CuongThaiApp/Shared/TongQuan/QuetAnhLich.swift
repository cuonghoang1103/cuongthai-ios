import Foundation
import UIKit

// ════════════════════════════════════════════════════════════════
// QUÉT THỜI KHOÁ BIỂU TỪ ẢNH
//
// Gửi ảnh chụp bảng lịch của trường lên, nhận về các buổi đã bóc tách.
//
// ⚠️ KẾT QUẢ KHÔNG TỰ LƯU. Nó đổ vào ĐÚNG ô chữ mà người dùng vẫn tự gõ ở
// `NhapNhanhLichView`, nên bản xem trước, phần bắt lỗi từng dòng và nút lưu
// vẫn y nguyên. AI chỉ tiết kiệm cho họ việc gõ — nó không được quyền quyết
// định lịch học thay họ.
// ════════════════════════════════════════════════════════════════

struct BuoiQuetDuoc: Decodable {
    let thu: Int
    let slot: Int
    let monHoc: String
    let phong: String?
    let giaoVien: String?
}

struct KetQuaQuetLich: Decodable {
    let buoi: [BuoiQuetDuoc]
    let canhBao: [String]

    /// Đổi sang đúng khuôn "thứ | slot | môn | phòng" của ô nhập nhanh.
    var thanhChu: String {
        buoi.map { b in
            let p = (b.phong ?? "").trimmingCharacters(in: .whitespaces)
            return p.isEmpty ? "\(b.thu) | \(b.slot) | \(b.monHoc)"
                             : "\(b.thu) | \(b.slot) | \(b.monHoc) | \(p)"
        }.joined(separator: "\n")
    }
}

enum QuetAnhLich {
    /// Nén trước khi gửi. Ảnh chụp màn hình iPhone 16 Pro Max là ~2-4 MB PNG;
    /// gửi nguyên thì tốn sóng của người dùng mà model không đọc tốt hơn.
    static func nen(_ anh: UIImage, canhToiDa: CGFloat = 2000) -> Data? {
        let w = anh.size.width, h = anh.size.height
        let canh = max(w, h)
        guard canh > 0 else { return nil }
        let ti = canh > canhToiDa ? canhToiDa / canh : 1
        if ti == 1 { return anh.jpegData(compressionQuality: 0.88) }
        let kichThuoc = CGSize(width: w * ti, height: h * ti)
        let ve = UIGraphicsImageRenderer(size: kichThuoc)
        return ve.image { _ in anh.draw(in: CGRect(origin: .zero, size: kichThuoc)) }
            .jpegData(compressionQuality: 0.88)
    }

    static func quet(_ anh: UIImage) async throws -> KetQuaQuetLich {
        guard let data = nen(anh) else {
            throw APIError.serverError("Không đọc được ảnh vừa chọn.")
        }
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/class-schedule/doc-anh") else {
            throw APIError.invalidURL
        }
        let ranh = "Ranh-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(ranh)", forHTTPHeaderField: "Content-Type")
        if let token = StorageManager.shared.getAuthToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var than = Data()
        func chu(_ s: String) { than.append(Data(s.utf8)) }
        chu("--\(ranh)\r\n")
        // Tên trường PHẢI là `anh` — `nhanAnh.single('anh')` ở backend.
        chu("Content-Disposition: form-data; name=\"anh\"; filename=\"lich.jpg\"\r\n")
        chu("Content-Type: image/jpeg\r\n\r\n")
        than.append(data)
        chu("\r\n--\(ranh)--\r\n")
        req.httpBody = than
        // Model nhìn ảnh mất hàng chục giây — trần mặc định 60s là quá ngắn.
        req.timeoutInterval = 180

        let (d, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.serverError("Không kết nối được máy chủ.")
        }
        guard (200..<300).contains(http.statusCode) else {
            struct Vo: Decodable { let message: String? }
            let m = (try? JSONDecoder().decode(Vo.self, from: d))?.message
            throw APIError.serverError(m ?? "Đọc ảnh không thành công (\(http.statusCode)).")
        }
        struct Vo: Decodable { let data: KetQuaQuetLich }
        return try JSONDecoder().decode(Vo.self, from: d).data
    }
}
