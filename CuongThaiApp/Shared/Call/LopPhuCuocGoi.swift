import SwiftUI
import Combine

// ════════════════════════════════════════════════════════════════
// ĐIỀU PHỐI CUỘC GỌI Ở GỐC APP
//
// Đặt ở gốc chứ không trong ChatView, vì cuộc gọi tới có thể rơi vào lúc
// người dùng đang xem bảng tin, đang học, hay đang hỏi AI. Nếu bộ nghe nằm
// trong màn nhắn tin thì chuông chỉ reo khi màn đó đang mở — tức là gần như
// không bao giờ.
// ════════════════════════════════════════════════════════════════

/// Một cuộc gọi cho cả app. Hai đối tượng song song thì tín hiệu chia đôi
/// giữa chúng và không cái nào nhận đủ.
@MainActor
final class BoGoi: ObservableObject {
    static let shared = BoGoi()
    let goi = CuocGoi()
    @Published var anhBenKia: String?
    /// Bật màn gọi. Tách khỏi `goi.trangThai` vì màn phải hiện NGAY lúc bấm,
    /// trước cả khi micro trả lời và WebRTC dựng xong.
    @Published var hienMan = false

    private var huy: Set<AnyCancellable> = []

    private init() {
        let rt = RealtimeClient.shared

        rt.goiDoChuong
            .sink { [weak self] id in
                NhatKy.goi.info("← call:ringing callId=\(id)")
                self?.goi.datCallId(id)
            }
            .store(in: &huy)

        rt.goiToi
            .sink { [weak self] su in
                guard let self else { return }
                // Đang bận thì máy chủ đã tự trả `call:busy` cho người gọi;
                // ở đây chỉ cần không đè lên cuộc đang nói.
                NhatKy.goi.info("← call:incoming từ=\(su.tuUserId) ten=\(su.ten) "
                              + "trangThai hiện tại=\(self.goi.trangThai)")
                guard self.goi.trangThai == .roi else {
                    NhatKy.goi.error("BỎ QUA cuộc gọi tới vì đang bận")
                    return
                }
                self.anhBenKia = su.anh
                self.goi.chuanBiNhan(callId: su.callId, sdp: su.sdp, ten: su.ten)
                self.hienMan = true
                RungChuong.batDau()
            }
            .store(in: &huy)

        rt.goiDuocNhan
            .sink { [weak self] su in
                NhatKy.goi.info("← call:answered")
                RungChuong.dung()
                self?.goi.benKiaDaNhan(sdp: su.sdp)
            }
            .store(in: &huy)

        rt.goiIce
            .sink { [weak self] c in
                NhatKy.goi.info("← call:ice")
                self?.goi.themIce(c)
            }
            .store(in: &huy)

        rt.goiKetThuc
            .sink { [weak self] su in
                NhatKy.goi.info("← call:end lyDo=\(su.lyDo) giay=\(su.giay)")
                RungChuong.dung()
                guard let self else { return }
                switch su.lyDo {
                case "khong-tra-loi":
                    self.goi.loi = "Không có ai trả lời."
                case "khong-truc-tuyen":
                    // Chặng A chỉ reo khi app bên kia ĐANG MỞ. Nói thẳng ra,
                    // đừng để người dùng ngồi nhìn "Đang gọi…" 45 giây rồi
                    // tưởng app hỏng — đúng thứ đã xảy ra 21/08/2026.
                    self.goi.loi = "\(self.goi.tenBenKia) hiện không online. "
                                 + "Cuộc gọi chỉ reo khi app của họ đang mở."
                case "tu-choi":
                    self.goi.loi = "Cuộc gọi bị từ chối."
                default:
                    break
                }
                self.goi.don()
                self.dongMan()
            }
            .store(in: &huy)

        rt.goiBan
            .sink { [weak self] ai in
                guard let self else { return }
                self.goi.loi = ai == "ho"
                    ? "Người này đang bận một cuộc gọi khác."
                    : "Bạn đang có một cuộc gọi khác."
                self.goi.don()
                self.dongMan()
            }
            .store(in: &huy)
    }

    /// Nán lại một nhịp để người dùng kịp đọc "Đã kết thúc" hoặc dòng lỗi.
    /// Đóng phụt ngay thì cuộc gọi lỡ trông y hệt cuộc gọi chưa từng xảy ra.
    private func dongMan() {
        Task {
            // Câu báo dài thì phải để lâu hơn. 1,2 giây đủ cho "Đã kết
            // thúc", không đủ để đọc hết một dòng giải thích.
            try? await Task.sleep(for: .milliseconds(self.goi.loi == nil ? 1200 : 3200))
            self.hienMan = false
            self.goi.loi = nil
        }
    }

    func batDauGoi(threadId: Int, toUserId: Int, ten: String, anh: String?) {
        NhatKy.goi.info("→ BẤM GỌI thread=\(threadId) toi=\(toUserId) ten=\(ten)")
        anhBenKia = anh
        hienMan = true
        Task { await goi.goi(threadId: threadId, toUserId: toUserId, ten: ten) }
    }

    func dongTay() {
        RungChuong.dung()
        if goi.trangThai == .doChuong { goi.tuChoi() } else { goi.cupMay() }
        hienMan = false
    }
}

// ── Rung báo cuộc gọi tới ───────────────────────────────────────
//
// Không phát nhạc chuông: chặng này chưa có CallKit, mà tự phát một file
// nhạc nền sẽ đè lên nhạc/podcast người dùng đang nghe. Rung theo nhịp là
// đủ báo và không cướp âm thanh của ai.
@MainActor
enum RungChuong {
    private static var dongHo: Timer?

    static func batDau() {
        dung()
        rung()
        dongHo = Timer.scheduledTimer(withTimeInterval: 2.4, repeats: true) { _ in
            Task { @MainActor in rung() }
        }
    }

    static func dung() {
        dongHo?.invalidate()
        dongHo = nil
    }

    private static func rung() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// ── Bộ điều chỉnh gắn vào gốc app ───────────────────────────────
struct LopPhuCuocGoi: ViewModifier {
    @ObservedObject private var bo = BoGoi.shared
    @ObservedObject private var goi = BoGoi.shared.goi

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $bo.hienMan) {
                ManHinhGoi(goi: goi, anhBenKia: bo.anhBenKia)
                    // Người dùng KHÔNG được vuốt xuống bỏ qua khi đang gọi —
                    // vuốt nhầm là cuộc gọi biến mất mà micro vẫn bật.
                    .interactiveDismissDisabled()
            }
    }
}

extension View {
    func lopPhuCuocGoi() -> some View { modifier(LopPhuCuocGoi()) }
}
