import SwiftUI

// MARK: - Luyện tập (kiểu Duolingo)
//
// Toàn bộ trạng thái chơi do MÁY CHỦ giữ và tính — XP, cấp, chuỗi ngày, tim,
// mục tiêu ngày/tuần, vương miện. App chỉ hiển thị và gửi kết quả một bài.
// Đừng tự cộng XP ở client rồi hiển thị: hai bên lệch nhau là người dùng thấy
// số nhảy lung tung sau khi tải lại.
//
// ⚠️ Mọi route `/practice*` đều ĐÒI ĐĂNG NHẬP, kể cả bảng xếp hạng.

struct TongQuanLuyenTap: Codable {
    let language: NgonNgu
    let state: TrangThaiChoi
    let units: [NhomBai]
}

struct TrangThaiChoi: Codable, Hashable {
    let xp: Int
    let level: Int
    let xpIntoLevel: Int
    let xpForLevel: Int
    let streak: Int
    let longestStreak: Int
    let dailyGoalXp: Int
    let dailyXp: Int
    let weeklyXp: Int
    let hearts: Int
    let maxHearts: Int
    /// Số phút nữa thì tim đầy lại. Máy chủ hồi 1 tim mỗi 12 phút.
    let heartsFullInMin: Int
    let reminderEnabled: Bool
    let reminderHour: Int

    var tiLeMucTieu: Double {
        guard dailyGoalXp > 0 else { return 0 }
        return min(1, Double(dailyXp) / Double(dailyGoalXp))
    }
    var tiLeCap: Double {
        guard xpForLevel > 0 else { return 0 }
        return min(1, Double(xpIntoLevel) / Double(xpForLevel))
    }
    var datMucTieu: Bool { dailyGoalXp > 0 && dailyXp >= dailyGoalXp }
}

struct NhomBai: Codable, Identifiable, Hashable {
    let key: String
    let label: String
    let lessons: [BaiLuyen]

    var id: String { key }
    var soXong: Int { lessons.filter { $0.crown > 0 }.count }
    /// Nhóm mà mọi bài đều khoá thì gập lại — hiện ra chỉ là một dãy xám dài.
    var khoaHet: Bool { !lessons.isEmpty && lessons.allSatisfy { $0.locked } }
}

struct BaiLuyen: Codable, Identifiable, Hashable {
    /// Dạng `vocab:<mã chủ đề>`. Máy chủ TỪ CHỐI mọi dạng khác.
    let lessonKey: String
    let categoryId: Int
    let name: String
    let icon: String?
    let wordCount: Int
    /// 0-5. Đạt từ 60% thì thêm một vương miện.
    let crown: Int
    let bestScore: Int
    /// Mở khoá TUYẾN TÍNH: bài trước phải có ít nhất 1 vương miện.
    let locked: Bool

    var id: String { lessonKey }
    var xong: Bool { crown >= 5 }
}

struct KetQuaBai: Codable {
    let xpGained: Int
    let crown: Int
    /// ⚠️ Tên dễ hiểu nhầm: đây là VƯƠNG MIỆN vừa tăng, KHÔNG phải lên cấp XP.
    /// Máy chủ đặt `leveledUp = crown > prevCrown`.
    let leveledUp: Bool
    let state: TrangThaiChoi
}

// MARK: - Bảng xếp hạng

struct BangXepHang: Codable {
    let week: String
    let entries: [HangNguoiChoi]
    let me: HangNguoiChoi?
}

struct HangNguoiChoi: Codable, Identifiable, Hashable {
    let rank: Int
    let userId: Int
    let name: String
    let avatarUrl: String?
    let weeklyXp: Int
    let isMe: Bool

    var id: Int { userId }
}

// MARK: - Thành tích

struct ThanhTich: Codable {
    let level: CapDoXp
    let totals: TongKet
    let badges: [HuyHieu]
    let earnedCount: Int
}

struct CapDoXp: Codable {
    let level: Int
    let xpIntoLevel: Int
    let xpForLevel: Int
    let xp: Int
}

struct TongKet: Codable {
    let lessonsPlayed: Int
    let lessonsPassed: Int
    let goldCrowns: Int
    let longestStreak: Int
    let xp: Int
}

struct HuyHieu: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let description: String
    /// ⚠️ Tên icon của **Lucide** (bộ icon của web). Backend ghi thẳng trong mã
    /// là "frontend maps it". Đưa vào `Image(systemName:)` là ra ô trống,
    /// không lỗi, không cảnh báo — đúng cái bẫy đã dính ở Lộ trình.
    let icon: String
    let earned: Bool
    /// 0..1
    let progress: Double
    let goal: Int
    let current: Int

    /// Đo thật 22/08/2026: 10 huy hiệu, 5 tên icon — Sparkles · BookOpenCheck
    /// · Flame · Zap · Crown.
    var bieuTuong: String {
        switch icon {
        case "Sparkles": return "sparkles"
        case "BookOpenCheck": return "book.closed.fill"
        case "Flame": return "flame.fill"
        case "Zap": return "bolt.fill"
        case "Crown": return "crown.fill"
        default: return "rosette"
        }
    }

    var mau: UInt32 {
        switch icon {
        case "Flame": return 0xE5484D
        case "Zap": return 0xF59E0B
        case "Crown": return 0xD97706
        case "BookOpenCheck": return 0x2BA84A
        default: return 0x8C5AF0
        }
    }
}

// MARK: - Một câu hỏi trong bài

/// Câu hỏi dựng NGAY TRÊN MÁY từ danh sách từ của chủ đề — backend không có
/// route sinh đề. Nhờ vậy chơi được cả khi mạng chập chờn giữa chừng, và chỉ
/// cần một lời gọi mạng cho cả bài.
struct CauHoi: Identifiable {
    enum Chieu { case tuSangNghia, nghiaSangTu }

    let id: Int
    let tu: TuNgoaiNgu
    let chieu: Chieu
    let luaChon: [String]
    let dapAn: String

    var deBai: String { chieu == .tuSangNghia ? tu.word : tu.nghia }
    var nhac: String { chieu == .tuSangNghia ? "Từ này nghĩa là gì?" : "Từ nào mang nghĩa này?" }

    /// Dựng bộ câu hỏi từ một chủ đề.
    ///
    /// Bỏ từ không có nghĩa tiếng Việt (không dựng được đáp án), và chỉ dựng
    /// khi còn đủ 4 nghĩa KHÁC NHAU để làm phương án nhiễu — thiếu thì hai
    /// phương án trùng chữ, người học chọn kiểu gì cũng thấy vô lý.
    static func dung(tu tatCa: [TuNgoaiNgu], soCau: Int) -> [CauHoi] {
        let dungDuoc = tatCa.filter { !$0.nghia.trimmingCharacters(in: .whitespaces).isEmpty }
        guard dungDuoc.count >= 4 else { return [] }

        return dungDuoc.shuffled().prefix(soCau).enumerated().compactMap { i, t in
            let chieu: Chieu = i.isMultiple(of: 2) ? .tuSangNghia : .nghiaSangTu
            let dapAn = chieu == .tuSangNghia ? t.nghia : t.word
            var nhieu = Set<String>()
            for k in dungDuoc.shuffled() where k.id != t.id {
                let v = chieu == .tuSangNghia ? k.nghia : k.word
                if !v.isEmpty && v != dapAn { nhieu.insert(v) }
                if nhieu.count == 3 { break }
            }
            guard nhieu.count == 3 else { return nil }
            return CauHoi(id: t.id, tu: t, chieu: chieu,
                          luaChon: (Array(nhieu) + [dapAn]).shuffled(), dapAn: dapAn)
        }
    }
}
