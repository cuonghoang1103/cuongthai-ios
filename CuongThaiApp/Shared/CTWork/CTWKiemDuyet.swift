import Foundation
import SwiftUI

// MARK: - CT Work — kiểm duyệt nội dung người dùng (App Store 1.2 / 4.7)
//
// Đủ BỐN thứ Apple đòi cho nội dung người dùng:
//   1. lọc  — ẩn ngay nội dung mình báo cáo (`AnNoiDungCTW`) + ẩn mọi nội dung
//            của người đã chặn (`ModerationStore.blockedUserIds`)
//   2. báo cáo — bình luận thẻ: `POST …/comments/:cid/report` (máy chủ ghi audit +
//            báo admin dự án); tin chat: backend CHƯA có route riêng ⇒ đi đường
//            chung `ModerationStore.baoCaoNoiDung` (vào hàng chờ kiểm duyệt của
//            quản trị, như các nội dung không có route riêng trong app chính)
//   3. chặn người dùng — `ModerationStore.block` (máy chủ, theo tài khoản)
//   4. liên hệ — Account → Help & contact
// Nội dung của AI agent (`kind == AGENT`) được gắn nhãn và báo cáo được như mọi nội dung.

@MainActor
final class AnNoiDungCTW: ObservableObject {
    static let shared = AnNoiDungCTW()

    @Published private(set) var tinAn: Set<Int> = []
    @Published private(set) var binhLuanAn: Set<Int> = []

    private let d = UserDefaults.standard
    private let kTin = "com.cuongthai.ctwork.tinAn"
    private let kBL = "com.cuongthai.ctwork.binhLuanAn"

    private init() {
        tinAn = Set(d.array(forKey: kTin) as? [Int] ?? [])
        binhLuanAn = Set(d.array(forKey: kBL) as? [Int] ?? [])
    }

    func anTin(_ id: Int) { tinAn.insert(id); d.set(Array(tinAn), forKey: kTin) }
    func anBinhLuan(_ id: Int) { binhLuanAn.insert(id); d.set(Array(binhLuanAn), forKey: kBL) }
    func boAnHet() { tinAn = []; binhLuanAn = []; d.removeObject(forKey: kTin); d.removeObject(forKey: kBL) }
    func xoaHet() { boAnHet() }
}

enum CTWBaoCao {
    /// Lý do báo cáo hiện cho người dùng (tiếng Anh) → `ReportReason` của
    /// đường báo cáo chung.
    static let lyDo: [(ma: String, nhan: String, chung: ReportReason)] = [
        ("spam", "Spam or advertising", .spam),
        ("harassment", "Harassment or bullying", .harassment),
        ("hate", "Hate speech", .harassment),
        ("sexual", "Sexual content", .other),
        ("violence", "Violence or threats", .violence),
        ("other", "Something else", .other),
    ]

    // Báo cáo tin chat: `CTWorkApp/Modules/Chat/BaoCaoTinCTW.swift` (model chat chỉ có ở app CT Work).
}
