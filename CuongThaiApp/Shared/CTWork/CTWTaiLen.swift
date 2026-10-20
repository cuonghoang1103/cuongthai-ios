import Foundation
import UniformTypeIdentifiers

// MARK: - CT Work — tải tệp đính kèm lên thẻ
//
// Ba bước (issues.service.ts ~871–976):
//   1. `presign` ⇒ `{uploadUrl, key, headers}` (url sống 900 giây)
//   2. PUT thẳng byte lên R2 — KHÔNG gắn token của mình (url đã ký sẵn), và
//      `Content-Type` PHẢI trùng đúng chuỗi đã khai ở bước 1 vì nó nằm trong
//      chữ ký (sai một ký tự ⇒ R2 trả 403 SignatureDoesNotMatch).
//   3. `complete` ⇒ máy chủ HEAD lại tệp, tự đọc mime/cỡ, tạo hàng đính kèm.
// Trần 25 MB/tệp, 50 tệp/thẻ — máy chủ kiểm, app kiểm trước cho đỡ tốn mạng.

enum CTWTaiLen {
    static let tranByte = 25 * 1024 * 1024

    enum Loi: LocalizedError {
        case quaLon, hong(Int)
        var errorDescription: String? {
            switch self {
            case .quaLon: return String(localized: "Files must be 25 MB or smaller.")
            case .hong(let ma): return String(localized: "Upload failed (\(ma)). Please try again.")
            }
        }
    }

    static func kieu(cho ten: String) -> String {
        let duoi = (ten as NSString).pathExtension
        return UTType(filenameExtension: duoi)?.preferredMIMEType ?? "application/octet-stream"
    }

    static func taiLen(pid: Int, so: Int, du: Data, ten: String, kieu: String? = nil) async throws -> CTWAttachment {
        guard du.count <= tranByte else { throw Loi.quaLon }
        let ct = kieu ?? Self.kieu(cho: ten)
        let ps: CTWPresign = try await APIClient.shared.request(
            CTWAPI.xinDuongTaiLen(pid: pid, so: so, ten: ten, kieu: ct, coByte: du.count))
        guard let url = URL(string: ps.uploadUrl) else { throw Loi.hong(0) }
        var r = URLRequest(url: url)
        r.httpMethod = "PUT"
        let dau = ps.headers ?? ["Content-Type": ct]
        for (k, v) in dau { r.setValue(v, forHTTPHeaderField: k) }
        if dau["Content-Type"] == nil { r.setValue(ct, forHTTPHeaderField: "Content-Type") }
        let (_, res) = try await URLSession.shared.upload(for: r, from: du)
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(ma) else { throw Loi.hong(ma) }
        return try await APIClient.shared.request(CTWAPI.xongTaiLen(pid: pid, so: so, key: ps.key, ten: ten))
    }
}
