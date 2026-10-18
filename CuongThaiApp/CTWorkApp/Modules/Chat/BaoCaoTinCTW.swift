import Foundation

// MARK: - Báo cáo tin chat (App Store 1.2)
//
// `POST /work/report {kind:"chat_message", id, reason}` (18/10/2026, `contentReport.service.ts` —
// cùng chỗ với lối tắt `POST /projects/:pid/chat/channels/:cid/messages/:mid/report`). Máy chủ ghi hàng
// chờ BAO_CAO + audit + WORK_ALERT cho ADMIN dự án, rồi trả tin đó kèm `reportedByMe/hiddenForMe: true`
// cho riêng người báo. Báo trùng ⇒ `duplicate: true` (không lỗi). App vẫn ẩn tại chỗ NGAY (không chờ tải lại).

extension CTWBaoCao {
    /// Báo cáo một tin chat. Ẩn tin NGAY cho người báo cáo.
    @MainActor
    static func baoCaoTin(_ m: CTWChatMessage, duAn: String, kenh: String, lyDoMa: String) async throws {
        let l = lyDo.first { $0.ma == lyDoMa } ?? lyDo[5]
        let _: CTWKetQuaBaoCao = try await APIClient.shared.request(
            CTWAPI.baoCaoNoiDung(CTWDichBaoCao("chat_message", m.id), lyDo: l.ma))
        AnNoiDungCTW.shared.anTin(m.id)
    }
}
