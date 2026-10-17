import Foundation

// MARK: - Báo cáo tin chat (App Store 1.2)
//
// Backend CHƯA có route báo cáo tin chat (`work.ctwk3.routes.ts`) ⇒ đi đường
// chung `ModerationStore.baoCaoNoiDung` (`/academy/advisor/report-answer` →
// hàng chờ BAO_CAO của quản trị). Có route riêng thì đổi MỘT chỗ này.

extension CTWBaoCao {
    /// Báo cáo một tin chat. Ẩn tin NGAY cho người báo cáo.
    @MainActor
    static func baoCaoTin(_ m: CTWChatMessage, duAn: String, kenh: String, lyDoMa: String) async throws {
        let l = lyDo.first { $0.ma == lyDoMa } ?? lyDo[5]
        let tacGia = m.author.map { "user #\($0.id)\($0.laAgent ? " (AI agent)" : "")" } ?? "unknown"
        try await ModerationStore.shared.baoCaoNoiDung(
            nhan: "CT WORK CHAT #\(m.id) · \(tacGia)",
            noiDung: m.body ?? "",
            ngucanh: "\(duAn) · #\(kenh)",
            lyDo: l.chung,
            chiTiet: l.nhan)
        AnNoiDungCTW.shared.anTin(m.id)
    }
}
