import Foundation

// Tách khỏi `NetChu.swift` có chủ đích: file kia phải THUẦN HÌNH HỌC, không
// mạng, không `APIClient` — có vậy mới biên dịch và kiểm được độc lập bằng
// `swiftc`, không cần dựng cả app. Bộ chấm nét mà sai thì người học viết
// đúng vẫn bị báo sai, và đó là loại lỗi không nhìn ảnh chụp mà thấy được.

@MainActor
final class KhoNetChu {
    static let shared = KhoNetChu()
    private var nho: [String: NetChu] = [:]
    private init() {}

    func lay(_ chu: String, lang: String) async -> NetChu? {
        let khoa = "\(lang):\(chu)"
        if let c = nho[khoa] { return c }
        guard let ma = chu.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let u = URL(string: "\(APIClient.diaChiGoc)/api/v1/my-language/hanzi-stroke/\(ma)?lang=\(lang)")
        else { return nil }
        do {
            let (d, _) = try await URLSession.shared.data(from: u)
            // Không bọc envelope — giải mã thẳng. Xem ghi chú đầu file.
            let n = try JSONDecoder().decode(NetChu.self, from: d)
            nho[khoa] = n
            return n
        } catch {
            return nil
        }
    }
}

