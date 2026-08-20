import Foundation

// ════════════════════════════════════════════════════════════════
// HÌNH DẠNG DỮ LIỆU CỦA PHIÊN CHAT
//
// Backend trả THẲNG hàng Prisma, không qua bộ nắn nào. Nên các trường dưới
// đây chép từ `prisma/schema.prisma`, không phải đoán từ tên đường API:
//
//   ChatSession  id String(cuid) · userId Int? · title String? · folderId
//                String? · pinned Bool · archivedAt DateTime? · createdAt ·
//                updatedAt          + _count.messages + folder{id,ten,mau}
//   ChatMessage  id Int · sessionId String · role String · content String ·
//                tokenCount Int? · createdAt
//   ChatFolder   id String · ten String · mau String? + _count.sessions
//
// ⚠️ `id` của PHIÊN là **String** (cuid), còn `id` của TIN NHẮN là **Int**.
// Khai nhầm một cái là cả danh sách hỏng giải mã — không phải một hàng.
//
// ⚠️ Tên cột tiếng Việt (`ten`, `mau`) là CỐ Ý ở backend. Đừng "sửa" thành
// name/color cho đẹp — sẽ không khớp gì cả.
//
// ⚠️⚠️ NGÀY GIỜ KHAI LÀ `String`, KHÔNG PHẢI `Date`.
// `APIClient` dùng `JSONDecoder()` trần, tức `dateDecodingStrategy` mặc định
// là `.deferredToDate` — nó chờ một CON SỐ, còn Prisma gửi chuỗi ISO. Khai
// `Date` là ném ngay `typeMismatch` và hỏng CẢ MẢNG, không phải một hàng.
// Cả `Models.swift` cũng theo đúng quy ước này: dây truyền String, đổi sang
// Date bằng `Date.tuChuoiISO(...)` ở thuộc tính tính toán.
// ════════════════════════════════════════════════════════════════

struct ThuMucChat: Decodable, Identifiable, Hashable {
    let id: String
    let ten: String
    let mau: String?
    let soCuoc: Int?

    private enum CodingKeys: String, CodingKey { case id, ten, mau, _count }
    private enum DemKeys: String, CodingKey { case sessions }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id  = try c.decode(String.self, forKey: .id)
        ten = try c.decode(String.self, forKey: .ten)
        mau = try c.decodeIfPresent(String.self, forKey: .mau)
        soCuoc = try c.nestedContainer(keyedBy: DemKeys.self, forKey: ._count)
            .decodeIfPresent(Int.self, forKey: .sessions)
    }
}

struct PhienChat: Decodable, Identifiable, Hashable {
    let id: String
    let title: String?
    let pinned: Bool
    let archivedAt: String?
    let updatedAt: String?
    let folder: ThuMucChat?
    let soTin: Int?

    /// Tên hiện trên danh sách. Phiên chưa đặt tên thì backend để `title` rỗng
    /// cho tới lượt hỏi đầu tiên.
    var ten: String {
        let t = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Cuộc trò chuyện mới" : t
    }

    var daLuuTru: Bool { archivedAt != nil }
    var mocCapNhat: Date? { Date.tuChuoiISO(updatedAt ?? "") }

    private enum CodingKeys: String, CodingKey {
        case id, title, pinned, archivedAt, updatedAt, folder, _count
    }
    private enum DemKeys: String, CodingKey { case messages }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id    = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        // `pinned` có `@default(false)` ở DB nên luôn có mặt — nhưng vẫn để
        // mặc định, vì một trường thiếu là hỏng CẢ mảng chứ không riêng hàng.
        pinned     = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        archivedAt = try c.decodeIfPresent(String.self, forKey: .archivedAt)
        updatedAt  = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        folder     = try c.decodeIfPresent(ThuMucChat.self, forKey: .folder)
        soTin = try? c.nestedContainer(keyedBy: DemKeys.self, forKey: ._count)
            .decodeIfPresent(Int.self, forKey: .messages)
    }
}

/// Một tin trong lịch sử đã lưu. `role` là chuỗi tự do ở DB (`VarChar(20)`),
/// không phải enum — nên so sánh chuỗi, đừng khai enum rồi vỡ vì một giá trị lạ.
struct TinLichSu: Decodable, Identifiable {
    let id: Int
    let role: String
    let content: String
    let createdAt: String?

    var cuaNguoi: Bool { role == "user" }
}
