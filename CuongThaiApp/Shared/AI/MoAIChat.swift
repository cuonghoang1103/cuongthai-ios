import SwiftUI

// ════════════════════════════════════════════════════════════════
// MỞ AI CHAT — toàn màn hình hoặc cửa sổ nổi
//
// Trước 22/09/2026 cả ba lối vào (trang chủ, bảng việc, vở) mở AI Chat bằng
// `.sheet`. Trên iPad đó là một ô ~540×620 điểm giữa màn hình; trên iPhone là
// tấm thẻ mà vuốt xuống là đóng — đang cuộn đọc câu trả lời dài rất dễ lỡ tay
// đóng mất. Người dùng muốn "full trang để dễ chat, giống app Claude/GPT".
//
// Mặc định nay là TOÀN MÀN HÌNH, có nút thu về cửa sổ nổi, và nhớ lựa chọn.
//
// ⚠️ Đổi kiểu trình bày = ĐÓNG kiểu cũ rồi MỞ kiểu mới. Nên:
//  • VM phải sống Ở ĐÂY, ngoài màn chat — không thì cuộc trò chuyện mất theo
//    cái màn vừa đóng.
//  • Phải đợi kiểu cũ đóng HẲN (`onDismiss`) rồi mới mở kiểu mới. Mở chồng
//    lúc cái kia còn đang trượt xuống thì UIKit bỏ qua lệnh mở, không báo gì.
// ════════════════════════════════════════════════════════════════

struct MoAIChat: ViewModifier {
    @Binding var dangMo: Bool
    var cauMoDau: String?
    var bacBanDau: BacAI?

    /// Một lượt trình bày, MANG THEO chính cái VM của nó.
    ///
    /// ⛔ ĐỪNG giữ VM trong một `@State` riêng rồi bật `isPresented` cùng lúc.
    /// Bản đầu làm vậy: `vm = AIChatViewModel(); moToanMan = true` trong cùng
    /// một nhịp — và SwiftUI dựng nội dung khung bằng giá trị CŨ của `vm`
    /// (còn `nil`), nên `if let vm` rơi vào nhánh rỗng: màn hình ĐEN TRƠN, không
    /// lỗi, không log. Chụp máy mô phỏng mới thấy. Dùng `item:` thì VM đi CÙNG
    /// lệnh mở, khung nhận thẳng nó chứ không đọc lại từ state.
    struct Luot: Identifiable {
        let id = UUID()
        let vm: AIChatViewModel
    }

    @AppStorage("aichat.toanManHinh") private var thichToanMan = true
    @State private var cuaSo: Luot?
    @State private var toanMan: Luot?
    /// Đang đổi kiểu: VM phải đi sang khung mới + hướng đổi. `nil` = lần đóng
    /// này là người dùng đóng hẳn.
    @State private var doiSang: (vm: AIChatViewModel, sangToanMan: Bool)?
    /// Chỉ để DỌN khi đóng hẳn (dừng câu trả lời đang chảy). Đọc trong
    /// callback `onDismiss` thì không vướng bẫy giá-trị-cũ ở trên — bẫy đó chỉ
    /// cắn nội dung của khung trình bày.
    @State private var vmHienTai: AIChatViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: dangMo) { _, mo in
                if mo { mo_() } else { cuaSo = nil; toanMan = nil }
            }
            .onAppear { if dangMo && cuaSo == nil && toanMan == nil { mo_() } }
            // ⚠️ Mỗi kiểu trình bày neo vào MỘT view nền RIÊNG, không gắn
            // thẳng lên `content`. Đã dính thật trong app này: hai `.sheet`
            // trên cùng một view thì cái sau nuốt cái trước, nút kia bấm im
            // lặng. Nơi gọi (vd `HomeView`) thường đã có sẵn `.sheet(item:)`
            // của riêng nó — neo tách ra thì không ai giành chỗ của ai.
            .background(Color.clear.sheet(item: $cuaSo, onDismiss: daDong) { l in
                khung(l.vm, laToanMan: false)
            })
            .background(Color.clear.fullScreenCover(item: $toanMan, onDismiss: daDong) { l in
                khung(l.vm, laToanMan: true)
            })
    }

    private func mo_() {
        // Mỗi lần mở là một cuộc MỚI, đúng như trước (mỗi sheet một VM). Chỉ
        // lượt ĐỔI KIỂU mới giữ VM cũ.
        doiSang = nil
        let l = Luot(vm: AIChatViewModel())
        vmHienTai = l.vm
        if thichToanMan { toanMan = l } else { cuaSo = l }
    }

    private func khung(_ vm: AIChatViewModel, laToanMan: Bool) -> some View {
        AIChatView(cauMoDau: cauMoDau, bacBanDau: bacBanDau, vmNgoai: vm,
                   toanMan: laToanMan, doiCheDo: { doi(vm, tuToanMan: laToanMan) })
    }

    private func doi(_ vm: AIChatViewModel, tuToanMan: Bool) {
        thichToanMan = !tuToanMan
        doiSang = (vm, !tuToanMan)
        if tuToanMan { toanMan = nil } else { cuaSo = nil }
    }

    private func daDong() {
        guard let d = doiSang else {
            // Đóng hẳn — nút "Đóng" hoặc vuốt xuống. DỪNG câu trả lời đang
            // chảy: luồng giữ VM sống, không dừng thì nó chạy ngầm tới hết câu
            // và vẫn tính lượt AI.
            vmHienTai?.dung()
            vmHienTai = nil
            dangMo = false
            return
        }
        doiSang = nil
        // ĐỔI KIỂU thì KHÔNG dừng: người dùng hay bấm phóng to đúng lúc AI
        // đang trả lời dài. Luồng sống trong VM, khung mới nhận tiếp.
        // Một nhịp cho UIKit dọn xong màn vừa đóng: mở chồng lúc cái kia còn
        // đang trượt xuống thì UIKit bỏ qua lệnh mở, không báo gì.
        DispatchQueue.main.async {
            let l = Luot(vm: d.vm)
            if d.sangToanMan { toanMan = l } else { cuaSo = l }
        }
    }
}

extension View {
    /// Mở AI Chat theo kiểu người dùng đã chọn (mặc định toàn màn hình).
    func moAIChat(dangMo: Binding<Bool>, cauMoDau: String? = nil, bacBanDau: BacAI? = nil) -> some View {
        modifier(MoAIChat(dangMo: dangMo, cauMoDau: cauMoDau, bacBanDau: bacBanDau))
    }
}
