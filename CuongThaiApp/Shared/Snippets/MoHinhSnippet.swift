import Foundation

// MARK: - Mẩu mã (Snippets)
//
// Đo thật 22/08/2026: **51 mẩu**, phần lớn là hướng dẫn cài môi trường bằng
// TIẾNG VIỆT kèm lệnh chép được (48/51 thuộc "FPTU — Cài đặt môi trường học").
// Ngôn ngữ: bash 18 · text 16 · markdown 5 · java 5 · cpp 2 · python/html/sql.
//
// ⚠️ Tham số tìm là **`search`**, KHÔNG phải `q`. Đo thật: `search=zzzqqq`→0
// (lọc thật), còn `q=zzzqqq`→51 (bị bỏ qua hoàn toàn). Gõ nhầm tên tham số thì
// máy chủ trả về TOÀN BỘ danh sách chứ không báo lỗi gì.
//
// ⚠️ `pagination` nằm ở TẦNG NGOÀI, ngang hàng `data`, mà `APIResponse` của
// app chỉ lấy `data` ⇒ không đọc được `totalPages`. Suy "hết trang" bằng cách
// trang trả về ÍT hơn số yêu cầu.

struct Snippet: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String?
    let title: String
    let description: String?
    let explanation: String?
    let language: String?
    let code: String?
    let codeBlocks: [KhoiMa]?
    let category: DanhMucGon?
    let tagNames: [String]?
    let noteContent: String?
    let referenceUrl: String?
    let youtubeUrl: String?
    let repoUrl: String?
    let viewCount: Int?
    let copyCount: Int?
    let upvoteCount: Int?
    let commentCount: Int?

    struct KhoiMa: Codable, Hashable, Identifiable {
        let code: String?
        let name: String?
        let language: String?
        var id: String { (name ?? "") + "|" + (language ?? "") }
    }
    struct DanhMucGon: Codable, Hashable {
        let id: Int?
        let name: String?
        let slug: String?
    }

    /// Các khối mã để hiện. Mẩu cũ chỉ có `code` phẳng, mẩu mới có
    /// `codeBlocks` — gộp lại để giao diện chỉ phải xử lý một dạng.
    var cacKhoi: [KhoiMa] {
        if let ds = codeBlocks, !ds.isEmpty { return ds }
        if let c = code, !c.isEmpty { return [KhoiMa(code: c, name: nil, language: language)] }
        return []
    }
    var tenDanhMuc: String { category?.name ?? "Khác" }
}

struct DanhMucSnippet: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String?
    let icon: String?
    let color: String?
    let parentId: Int?
    let description: String?
    let _count: BoDem?

    struct BoDem: Codable, Hashable {
        let snippets: Int?
        let children: Int?
    }

    /// ⚠️ Lọc theo `parentId == nil` là SAI: đo thật 22/08 thì **cả 20 danh
    /// mục đều ở tầng gốc**, trong khi chỉ **4** có mẩu (FPTU 48 · Lab211 3 ·
    /// CuongThai 1 · Game 1). Lọc kiểu đó thì thanh danh mục dài 20 nút mà 16
    /// nút bấm vào ra danh sách trống.
    var soMau: Int { _count?.snippets ?? 0 }
}
