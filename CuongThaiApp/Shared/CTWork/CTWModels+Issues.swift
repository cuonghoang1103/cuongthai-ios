import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - CT Work — model THẺ (đính kèm, danh sách, backlog, lịch sử, tìm kiếm) — 17/10/2026
//
// Hình dạng đối chiếu TỪNG TRƯỜNG với backend (đọc service, không đoán):
//   · thẻ / danh sách / backlog / lịch sử / đính kèm → `services/work/issues.service.ts`,
//     `sprints.service.ts`
//   · tìm kiếm toàn cục → `services/work/globalSearch.service.ts`
// Model của từng mô-đun riêng nằm cạnh mô-đun đó trong app CT Work:
// `CTWorkApp/Modules/<MoDun>/CTWModels+<MoDun>.swift`.
// Luật chung của kho (CLAUDE.md C3/C4): mọi trường `var` + optional, ngày là
// CHUỖI. Trường JSON tự do (`meta`) giải mã khoan dung bằng `try?`.

// MARK: Đính kèm

struct CTWAttachment: Codable, Hashable, Identifiable {
    var id: Int
    var fileName: String?
    var mime: String?
    var size: Int?
    var createdAt: String?
    var clientVisible: Bool?
    var deliverable: Bool?
    var uploader: CTWUser?

    var laAnh: Bool { (mime ?? "").hasPrefix("image/") }

    var bieuTuong: String {
        let m = (mime ?? "").lowercased()
        if m.hasPrefix("image/") { return "photo" }
        if m.hasPrefix("video/") { return "film" }
        if m.hasPrefix("audio/") { return "waveform" }
        if m.contains("pdf") { return "doc.richtext" }
        if m.contains("zip") || m.contains("compressed") { return "doc.zipper" }
        if m.contains("sheet") || m.contains("excel") || m.contains("csv") { return "tablecells" }
        if m.contains("presentation") || m.contains("powerpoint") { return "rectangle.on.rectangle" }
        return "doc"
    }

    var coChu: String {
        guard let size else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

struct CTWPresign: Codable {
    var uploadUrl: String
    var key: String
    var headers: [String: String]?
}

struct CTWUrl: Codable { var url: String }

// MARK: Danh sách thẻ · backlog

struct CTWIssueList: Codable {
    var items: [CTWIssueCard]?
    var total: Int?
    var nextCursor: String?
}

struct CTWBacklog: Codable {
    var unit: String?
    var sprints: [CTWSprint]?
    var truncated: Bool?
    var total: Int?
    var issues: [CTWIssueCard]?
}

// MARK: Lịch sử thẻ

struct CTWHistory: Codable, Hashable, Identifiable {
    var id: Int
    var field: String?
    var fromValue: String?
    var toValue: String?
    /// USER | AI | AUTOMATION | SYSTEM | AGENT
    var actorKind: String?
    var createdAt: String?
    var actor: CTWUser?
}

// MARK: Tìm kiếm toàn cục

struct CTWSearchItem: Codable, Hashable, Identifiable {
    struct DuAn: Codable, Hashable { var id: Int?; var key: String?; var name: String? }
    struct KhongGian: Codable, Hashable { var slug: String?; var name: String? }
    struct TrangThai: Codable, Hashable { var name: String?; var category: String? }
    struct Loai: Codable, Hashable { var key: String?; var name: String?; var color: String? }
    var id: Int
    var key: String?
    var number: Int
    var title: String
    var priority: Int?
    var dueDate: String?
    var status: TrangThai?
    var type: Loai?
    var assignee: CTWUser?
    var project: DuAn?
    var workspace: KhongGian?
}

struct CTWSearchResult: Codable {
    var items: [CTWSearchItem]?
    var total: Int?
    var hasMore: Bool?
}

// MARK: - Tiện ích nhỏ dùng chung


extension CTW {
    static func chepVaoBoNho(_ s: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = s
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
    }

    /// "20261017-1405" — tên tệp ảnh chụp/chọn không trùng nhau.
    static func tenTepTheoGio() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    /// Đường dẫn web của thẻ (chia sẻ / mở trên web). Cần slug không gian.
    static func urlWeb(cfg: CTWProjectConfig, so: Int? = nil) -> URL? {
        guard let slug = cfg.workspace?.slug else { return nil }
        var s = "\(APIClient.diaChiGoc)/work/\(APIEndpoint.maHoaDoan(slug))/\(APIEndpoint.maHoaDoan(cfg.key))"
        if let so { s += "/issue/\(so)" }
        return URL(string: s)
    }
}
