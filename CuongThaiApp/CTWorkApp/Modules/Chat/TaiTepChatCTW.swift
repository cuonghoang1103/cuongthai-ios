import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - Tải tệp / voice note lên kênh chat
//
// Khác đính kèm THẺ (presign → PUT R2 → complete): chat nhận MULTIPART thẳng
// (`POST …/channels/:cid/files` trường `file` ≤ 25 MB; `…/voice` trường `audio`
// ≤ 8 MB + `durationMs` ≤ 3 phút). Máy chủ trả tệp NHÁP (chưa gắn tin) ⇒ gửi tin
// kèm `fileIds`. Bỏ nháp: `DELETE /projects/:pid/chat/files/:fid`.
//
// Ảnh HEIC đổi sang JPEG trước khi gửi: trình duyệt của đồng đội (Chrome,
// Firefox) không hiện HEIC, và mime HEIC rỗng trên Chrome làm máy chủ coi là tệp.

enum TaiTepChatCTW {
    static let tranTep = 25 * 1024 * 1024
    static let tranGiongNoi = 8 * 1024 * 1024

    enum Loi: LocalizedError {
        case quaLon(Int), hong(Int, String?)
        var errorDescription: String? {
            switch self {
            case .quaLon(let mb): return String(localized: "Files must be \(mb) MB or smaller.")
            case .hong(let ma, let s): return s ?? String(localized: "Upload failed (\(ma)). Please try again.")
            }
        }
    }

    static func kieu(cho ten: String) -> String {
        UTType(filenameExtension: (ten as NSString).pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }

    /// Ảnh từ thư viện/máy ảnh ⇒ JPEG (HEIC/PNG lớn đều về JPEG ≤ ~2.5k px).
    static func chuanHoaAnh(_ du: Data) -> Data {
        guard let anh = UIImage(data: du) else { return du }
        let canh = max(anh.size.width, anh.size.height)
        var ve = anh
        if canh > 2560 {
            let tl = 2560 / canh
            let moi = CGSize(width: anh.size.width * tl, height: anh.size.height * tl)
            ve = UIGraphicsImageRenderer(size: moi).image { _ in anh.draw(in: CGRect(origin: .zero, size: moi)) }
        }
        return ve.jpegData(compressionQuality: 0.82) ?? du
    }

    static func taiTep(pid: Int, cid: Int, du: Data, ten: String, kieu: String? = nil) async throws -> CTWChatFile {
        guard du.count <= tranTep else { throw Loi.quaLon(25) }
        return try await gui(duong: CTWAPI.duongTaiTepChat(pid: pid, cid: cid, giongNoi: false),
                             truong: "file", du: du, ten: ten, kieu: kieu ?? Self.kieu(cho: ten), them: [:])
    }

    static func taiGiongNoi(pid: Int, cid: Int, du: Data, thoiLuongMs: Int) async throws -> CTWChatFile {
        guard du.count <= tranGiongNoi else { throw Loi.quaLon(8) }
        return try await gui(duong: CTWAPI.duongTaiTepChat(pid: pid, cid: cid, giongNoi: true),
                             truong: "audio", du: du, ten: "voice-note.m4a", kieu: "audio/mp4",
                             them: ["durationMs": "\(thoiLuongMs)"])
    }

    private static func gui(duong: String, truong: String, du: Data, ten: String, kieu: String,
                            them: [String: String]) async throws -> CTWChatFile {
        guard let url = URL(string: APIClient.diaChiGoc + duong) else { throw Loi.hong(0, nil) }
        let ranh = "CTWBoundary-\(UUID().uuidString)"
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.timeoutInterval = 120
        r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        r.setValue("multipart/form-data; boundary=\(ranh)", forHTTPHeaderField: "Content-Type")
        if let t = StorageManager.shared.getAuthToken() { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        var than = Data()
        func noi(_ s: String) { than.append(Data(s.utf8)) }
        for (k, v) in them {
            noi("--\(ranh)\r\nContent-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n")
        }
        // Tên tệp có dấu/ngoặc kép: thay ngoặc kép để không vỡ header (máy chủ đọc latin1→utf8).
        let tenAnToan = ten.replacingOccurrences(of: "\"", with: "'")
        noi("--\(ranh)\r\nContent-Disposition: form-data; name=\"\(truong)\"; filename=\"\(tenAnToan)\"\r\n")
        noi("Content-Type: \(kieu)\r\n\r\n")
        than.append(du)
        noi("\r\n--\(ranh)--\r\n")
        let (d, res) = try await URLSession.shared.upload(for: r, from: than)
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        let goi = try? JSONDecoder().decode(APIResponse<CTWChatFile>.self, from: d)
        guard (200..<300).contains(ma), let f = goi?.data else {
            if ma == 413 { throw Loi.quaLon(truong == "audio" ? 8 : 25) }
            throw Loi.hong(ma, goi?.message)
        }
        return f
    }
}
