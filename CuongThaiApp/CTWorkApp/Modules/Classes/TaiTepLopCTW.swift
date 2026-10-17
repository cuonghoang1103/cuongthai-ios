import Foundation
import UniformTypeIdentifiers

// MARK: - Lớp học — tải tệp bài nộp (multipart, trường `file`)
//
// `POST /classes/:id/assignments/:aid/my/files` nhận multipart (KHÔNG phải presign như
// đính kèm thẻ). Trần 25 MB/tệp, tối đa 10 tệp; máy chủ chặn đuôi chạy được/html/svg.

enum CTWTaiTepLop {
    static let tranByte = 25 * 1024 * 1024

    enum Loi: LocalizedError {
        case quaLon, hong(String)
        var errorDescription: String? {
            switch self {
            case .quaLon: return "Files must be 25 MB or smaller."
            case .hong(let m): return m
            }
        }
    }

    static func taiLen(lop: Int, bai: Int, du: Data, ten: String) async throws -> CTWTepLop {
        guard du.count <= tranByte else { throw Loi.quaLon }
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/work/classes/\(lop)/assignments/\(bai)/my/files") else {
            throw Loi.hong("Upload failed. Please try again.")
        }
        let ranh = "CTWBoundary-\(UUID().uuidString)"
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("multipart/form-data; boundary=\(ranh)", forHTTPHeaderField: "Content-Type")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        if let t = StorageManager.shared.getAuthToken() { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let kieu = UTType(filenameExtension: (ten as NSString).pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        // Tên tệp trong header không được chứa dấu nháy/xuống dòng.
        let tenAnToan = ten.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " ")
        var than = Data()
        than.append(Data("--\(ranh)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(tenAnToan)\"\r\nContent-Type: \(kieu)\r\n\r\n".utf8))
        than.append(du)
        than.append(Data("\r\n--\(ranh)--\r\n".utf8))
        let (data, res) = try await URLSession.shared.upload(for: r, from: than)
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        struct Bao: Decodable { var success: Bool?; var data: CTWTepLop?; var message: String? }
        let bao = try? JSONDecoder().decode(Bao.self, from: data)
        guard (200..<300).contains(ma), let tep = bao?.data else {
            throw Loi.hong(bao?.message ?? "Upload failed (\(ma)). Please try again.")
        }
        return tep
    }
}
