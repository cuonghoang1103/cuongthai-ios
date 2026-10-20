import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Docs — logic SỬA TRANG an toàn (thuần, có kiểm thử: `DocsCTWTests`)
//
// Giao thức (18/10/2026, `pages.service.ts → updatePage` nhận `baseVersion`):
//   1. Mở: nhớ `version` V0 + markdown chuẩn M0 của máy chủ.
//   2. Lưu: PATCH kèm `baseVersion: V0`. Máy chủ tự ghi phòng đồng soạn Yjs (nếu đang mở trên web)
//      xuống CSDL rồi so:
//      · khớp ⇒ ghi (gộp ba chiều đúng gốc), trả trang mới ⇒ V0 = version mới.
//      · lệch ⇒ 409 `WORK_PAGE_CONFLICT` — KHÔNG ghi gì. App hiện "This page changed — reload /
//        compare": xem bản mới, SO SÁNH với bản của mình (`soSanhDong`), lưu bản mình thành trang
//        con, hoặc bỏ bản mình và tải lại.
//   (Trước đây app phải tự `collab/flush` → GET → so tay, còn hở một khe giữa flush và PATCH.)
// Trang chứa thứ markdown không giữ được (nhắc tên @, chú thích gắn đoạn, ô bảng
// gộp…) ⇒ KHÔNG cho sửa trên máy (sửa sẽ làm mất chúng) — nói rõ lý do.

enum CTWSuaTrang {
    /// Kiểu nút/dấu mà vòng Markdown ⇄ TipTap của máy chủ (`docMarkdown.ts`) giữ nguyên.
    static let nutGiuDuoc: Set<String> = [
        "doc", "paragraph", "heading", "text", "bulletList", "orderedList", "listItem", "taskList", "taskItem",
        "codeBlock", "blockquote", "horizontalRule", "image", "hardBreak",
        "table", "tableRow", "tableHeader", "tableCell",
    ]
    static let dauGiuDuoc: Set<String> = ["bold", "italic", "strike", "code", "link"]

    /// `nil` = sửa trên máy an toàn; ngược lại là câu giải thích (tiếng Anh, hiện cho người dùng).
    static func lyDoKhongSuaDuoc(_ json: Any?) -> String? {
        guard let goc = json as? [String: Any] else { return nil }   // trang trống
        var lyDo: String?
        func di(_ n: [String: Any], trongBang: Bool) {
            guard lyDo == nil else { return }
            let kieu = n["type"] as? String ?? ""
            if kieu == "mention" { lyDo = String(localized: "This page @mentions people. Editing it here would turn mentions into plain text."); return }
            if !nutGiuDuoc.contains(kieu) { lyDo = String(localized: "This page contains content the mobile editor can't keep yet (\(kieu))."); return }
            for d in (n["marks"] as? [[String: Any]]) ?? [] {
                let t = d["type"] as? String ?? ""
                if t == "commentAnchor" { lyDo = String(localized: "This page has inline comment threads. Editing here would detach them."); return }
                if !dauGiuDuoc.contains(t) { lyDo = String(localized: "This page uses text formatting the mobile editor can't keep (\(t))."); return }
            }
            if kieu == "tableCell" || kieu == "tableHeader" {
                let a = n["attrs"] as? [String: Any] ?? [:]
                let gop = ((a["colspan"] as? Int) ?? 1) > 1 || ((a["rowspan"] as? Int) ?? 1) > 1
                let con = (n["content"] as? [[String: Any]]) ?? []
                let phucTap = con.count > 1 || con.contains { ($0["type"] as? String) != "paragraph" }
                if gop || phucTap { lyDo = String(localized: "This page has a table with merged or multi-line cells, which would be flattened."); return }
            }
            for c in (n["content"] as? [[String: Any]]) ?? [] { di(c, trongBang: trongBang || kieu == "table") }
        }
        di(goc, trongBang: false)
        return lyDo
    }

    /// Markdown của `/pages/:n/markdown` mở đầu bằng "# <tiêu đề>" — bỏ dòng đó
    /// (tiêu đề sửa ở ô riêng). Máy chủ cũng chỉ bỏ H1 đầu khi nó TRÙNG `title`.
    static func boTieuDe(_ md: String, tieuDe: String) -> String {
        var s = md
        let dau = "# " + tieuDe
        if s.hasPrefix(dau) {
            s = String(s.dropFirst(dau.count))
            while s.hasPrefix("\n") { s.removeFirst() }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// So hai bản markdown bỏ qua khác biệt khoảng trắng cuối dòng/cuối tệp.
    static func giongNhau(_ a: String, _ b: String) -> Bool {
        func gon(_ s: String) -> String {
            s.replacingOccurrences(of: "\r", with: "")
                .components(separatedBy: "\n").map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
                .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return gon(a) == gon(b)
    }

    /// Lỗi 409 của PATCH trang (`WORK_PAGE_CONFLICT`; `CONFLICT` là mã chung cũ).
    static func laXungDotTrang(_ e: Error) -> Bool {
        if case APIError.coMa(let ma, _) = e { return ma == "WORK_PAGE_CONFLICT" || ma == "CONFLICT" }
        return false
    }

    /// Một dòng của phép so sánh hai bản (diff theo DÒNG, thuật toán LCS — trang tài liệu ngắn).
    enum DongSoSanh: Hashable {
        case giong(String), chiCuaToi(String), chiBanMoi(String)
    }

    /// So "bản của tôi" với "bản mới trên máy chủ" theo dòng. Trần 600×600 dòng (vượt ⇒ coi mọi dòng
    /// là khác — đủ để người dùng thấy, không treo máy).
    static func soSanhDong(cuaToi: String, banMoi: String) -> [DongSoSanh] {
        let a = cuaToi.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        let b = banMoi.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        guard a.count <= 600, b.count <= 600 else { return a.map { .chiCuaToi($0) } + b.map { .chiBanMoi($0) } }
        let n = a.count, m = b.count
        var l = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                l[i][j] = a[i] == b[j] ? l[i + 1][j + 1] + 1 : max(l[i + 1][j], l[i][j + 1])
            }
        }
        var kq: [DongSoSanh] = []
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] { kq.append(.giong(a[i])); i += 1; j += 1 }
            else if l[i + 1][j] >= l[i][j + 1] { kq.append(.chiCuaToi(a[i])); i += 1 }
            else { kq.append(.chiBanMoi(b[j])); j += 1 }
        }
        while i < n { kq.append(.chiCuaToi(a[i])); i += 1 }
        while j < m { kq.append(.chiBanMoi(b[j])); j += 1 }
        return kq
    }

    enum KetQuaKiem: Equatable { case ghiDuoc, xungDot }

    /// Giao thức cũ (trước `baseVersion`) — giữ cho kiểm thử/so sánh; app không còn gọi.
    static func kiemTruocKhiGhi(v0: Int?, vNay: Int?, md0: String, mdNay: () async throws -> String) async rethrows -> KetQuaKiem {
        if v0 == vNay { return .ghiDuoc }
        return giongNhau(try await mdNay(), md0) ? .ghiDuoc : .xungDot
    }

    /// Liên kết thẻ chèn vào thân trang — cùng dạng web chèn (`DocView.tsx`):
    /// mark `link` với đường tương đối `/work/<ws>/<KEY>/issue/<n>`.
    static func lienKetThe(slug: String, maDuAn: String, so: Int, tieuDe: String) -> String {
        let t = tieuDe.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
        return "[\(maDuAn)-\(so) \(t)](/work/\(slug)/\(maDuAn)/issue/\(so))"
    }
}

// MARK: - Tải ảnh vào trang — `POST /projects/:pid/images?name=` THÂN LÀ BYTE ẢNH
// (không multipart, không presign — `work.docs3a.routes.ts` 42–47). Trần 10 MB, máy
// chủ tự kiểm định dạng thật (SVG bị từ chối). Trả `{id, url}` ⇒ chèn `![alt](url)`.

enum CTWTaiAnhTaiLieu {
    static let tranByte = 10 * 1024 * 1024

    enum Loi: LocalizedError {
        case quaLon, hong(String)
        var errorDescription: String? {
            switch self {
            case .quaLon: return String(localized: "Images must be 10 MB or smaller.")
            case .hong(let m): return m
            }
        }
    }

    #if canImport(UIKit)
    /// Ảnh bất kỳ (HEIC, PNG…) → JPEG cạnh dài ≤ 2400 px: ảnh 48MP gốc vừa nặng vừa vô ích trong một trang tài liệu.
    static func chuanBi(_ du: Data) -> Data? {
        guard let anh = UIImage(data: du) else { return nil }
        let canh = max(anh.size.width, anh.size.height)
        let tile = canh > 2400 ? 2400 / canh : 1
        let co = CGSize(width: floor(anh.size.width * tile), height: floor(anh.size.height * tile))
        let ve = UIGraphicsImageRenderer(size: co, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let nho = ve.image { _ in anh.draw(in: CGRect(origin: .zero, size: co)) }
        return nho.jpegData(compressionQuality: 0.82)
    }
    #endif

    static func taiLen(pid: Int, du: Data, ten: String) async throws -> CTWAnhTaiLieu {
        guard du.count <= tranByte else { throw Loi.quaLon }
        var c = URLComponents(string: APIClient.diaChiGoc + "/api/v1/work/projects/\(pid)/images")
        c?.queryItems = [URLQueryItem(name: "name", value: ten)]
        guard let url = c?.url else { throw Loi.hong(String(localized: "Upload failed. Please try again.")) }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        if let t = StorageManager.shared.getAuthToken() { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await URLSession.shared.upload(for: r, from: du)
        let ma = (res as? HTTPURLResponse)?.statusCode ?? 0
        struct Bao: Decodable { var success: Bool?; var data: CTWAnhTaiLieu?; var message: String? }
        let bao = try? JSONDecoder().decode(Bao.self, from: data)
        guard (200..<300).contains(ma), let anh = bao?.data else {
            throw Loi.hong(bao?.message ?? String(localized: "Upload failed (\(ma)). Please try again."))
        }
        return anh
    }
}
