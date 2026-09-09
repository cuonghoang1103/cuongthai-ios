import SwiftUI

/// Một tin trong khung chat AI.
struct TinAI: Identifiable {
    let id = UUID()
    let cuaNguoi: Bool
    var noiDung: String
    var dangChay: Bool = false
    var model: String? = nil
    var messageId: Int? = nil
    /// Ảnh người dùng đính ở lượt này (base64). Giữ lại vì lịch sử gửi lên
    /// model là CHỮ THUẦN — xem `anhKemLai()`.
    var anh: [String] = []
    var tenTep: [String] = []
    /// Nguồn web model đã đọc cho lượt này.
    var nguon: [NguonWeb] = []
}

/// Ba bậc, khớp `CHAT_MODELS` trong `src/services/ai.service.ts`.
///
/// ⚠️ `maModel` phải là **mã BẬC CHAT** (`cuongmini-*`), KHÔNG phải tên model
/// của cổng (`gpt-5.6-sol`, `claude-sonnet-5`). `resolveChatModel()` tra đúng
/// ba khoá này; gửi thứ khác thì nó rơi về mặc định **im lặng** — bảng chọn
/// trông vẫn chạy còn cả ba bậc đều ra Groq.
enum BacAI: String, CaseIterable, Identifiable {
    case mini, pro, max
    var id: String { rawValue }

    var maModel: String {
        switch self {
        case .mini: return "cuongmini-3.11"
        case .pro:  return "cuongmini-pro"
        case .max:  return "cuongmini-max"
        }
    }

    var ten: String {
        switch self {
        case .mini: return "CuongMini3.11"
        case .pro:  return "CuongMini Pro"
        case .max:  return "CuongMini Max"
        }
    }

    var bieuTuong: String {
        switch self {
        case .mini: return "hare"
        case .pro:  return "bolt"
        case .max:  return "sparkles"
        }
    }

    var moTa: String {
        switch self {
        case .mini: return "Nhanh nhất · câu ngắn, hỏi hằng ngày"
        case .pro:  return "Nhanh + chính xác · dùng hằng ngày"
        case .max:  return "Mạnh nhất · toán, mã, đọc file"
        }
    }

    /// Ảnh và tệp CHỈ đi được ở bậc Claude. Backend nói rõ: "Images + PDFs are
    /// a perk of the Pro/Max (Claude) tiers only" — nhánh Groq nhận `message`
    /// dạng chuỗi thuần, đính kèm vào đó là rơi vào hư không.
    var nhanTep: Bool { self != .mini }

    /// Bậc nhanh tắt tìm web: mỗi lượt tìm mất mấy giây, mà câu hỏi thường
    /// ngày thì không cần.
    var timWeb: Bool { self != .mini }
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var tin: [TinAI] = []
    @Published var dangTraLoi = false
    @Published var buocHienTai: String?
    @Published var loi: String?
    @Published var bac: BacAI = .mini

    /// `sessionId` để trống nghĩa là cuộc MỚI — backend tự tạo ở lượt đầu và
    /// trả lại qua khung `connected`.
    @Published private(set) var sessionId: String?
    @Published var dangNapLichSu = false
    private var viec: Task<Void, Never>?

    var bacHienTai: BacAI { bac }

    /// Mở lại một cuộc đã lưu: nạp toàn bộ tin từ `GET /ai/chat/history/:id`.
    ///
    /// Phải đặt `sessionId` để lượt hỏi tiếp GHI VÀO ĐÚNG cuộc đó, không đẻ ra
    /// một cuộc mới song song — nhìn ngoài thì giống nhau, tới khi mở lại lịch
    /// sử mới thấy một cuộc cụt và một cuộc lạ.
    func moCuoc(_ p: PhienChat) async {
        dung()
        dangNapLichSu = true
        defer { dangNapLichSu = false }
        do {
            let ds: [TinLichSu] = try await APIClient.shared.request(.lichSuPhienChat(id: p.id))
            tin = ds.map { TinAI(cuaNguoi: $0.cuaNguoi, noiDung: $0.content, messageId: $0.id) }
            sessionId = p.id
            buocHienTai = nil
        } catch {
            loi = "Không mở được cuộc này: \(error.localizedDescription)"
        }
    }

    /// Hỏi lại lượt cuối.
    ///
    /// Bỏ câu trả lời cũ RỒI mới gửi, để nó không lọt vào lịch sử gửi lên —
    /// model đọc thấy câu nó vừa viết thì thường chỉ diễn đạt lại y hệt.
    func taoLai() {
        guard !dangTraLoi else { return }
        guard let iCuoi = tin.lastIndex(where: { $0.cuaNguoi }) else { return }
        let cauHoi = tin[iCuoi].noiDung
        let anh = tin[iCuoi].anh
        let tenTep = tin[iCuoi].tenTep
        tin.removeSubrange(iCuoi...)
        gui(cauHoi, anh: anh, tep: [], tenTep: tenTep)
    }

    /// Sửa một câu hỏi của mình rồi hỏi lại từ đó.
    ///
    /// Cắt luôn ở máy chủ (`POST /chat/sessions/:id/cat`) chứ không chỉ xoá
    /// trên màn hình: phiên là thứ mở lại được, để lại phần cũ thì lần sau mở
    /// ra thấy cả câu đã sửa lẫn câu chưa sửa.
    func suaVaHoiLai(_ tinCu: TinAI, thanh moi: String) async {
        guard !dangTraLoi, let i = tin.firstIndex(where: { $0.id == tinCu.id }) else { return }
        let c = moi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        if let sid = sessionId {
            try? await APIClient.shared.send(.catPhien(id: sid, tuChiSo: i))
        }
        let anh = tin[i].anh
        tin.removeSubrange(i...)
        gui(c, anh: anh)
    }

    /// Cả cuộc dưới dạng markdown, để chia sẻ hoặc lưu.
    func xuatMarkdown() -> String {
        tin.filter { !$0.noiDung.isEmpty }
           .map { ($0.cuaNguoi ? "## 🧑 Tôi\n\n" : "## 🤖 CuongMini\n\n") + $0.noiDung }
           .joined(separator: "\n\n---\n\n")
    }

    func hoiMoi() {
        dung()
        tin = []
        sessionId = nil
        buocHienTai = nil
    }

    func dung() {
        viec?.cancel()
        viec = nil
        dangTraLoi = false
        buocHienTai = nil
        // Đánh dấu tin đang chảy là đã dừng, không thì nó kẹt ở trạng thái
        // "đang chạy" và không hiện được nút Chép.
        if let i = tin.indices.last, tin[i].dangChay {
            tin[i].dangChay = false
            if tin[i].noiDung.isEmpty { tin.remove(at: i) }
        }
    }

    /// Số lượt gần nhất gửi lên làm ngữ cảnh. Bằng web (`page.tsx` cắt
    /// `.slice(-10)`), và backend còn cắt lần nữa ở `MAX_HISTORY_TURNS = 10`.
    private let SO_LUOT_NHO = 10
    /// Trong tầm này thì lượt sau vẫn coi là "đang làm bài có ảnh đó".
    private let TAM_NHO_ANH = 6

    /// Dựng ngữ cảnh gửi lên model.
    ///
    /// ⚠️ Backend KHÔNG nhớ hộ. `streamChat` chỉ GHI lượt vào phiên chứ không
    /// đọc lại theo `sessionId`; `sanitizeHistory(context.history)` đọc đúng
    /// mảng client gửi lên. Thiếu nó thì mỗi câu là một cuộc đời mới — đó là
    /// lý do app "quên" ngay câu vừa hỏi.
    private func lichSuGui() -> [[String: String]] {
        tin.filter { !$0.noiDung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .suffix(SO_LUOT_NHO)
            .map { ["role": $0.cuaNguoi ? "user" : "assistant", "content": $0.noiDung] }
    }

    /// Lượt này không đính ảnh thì kèm lại ảnh của lượt có ảnh GẦN NHẤT.
    ///
    /// Lịch sử lên model là chữ thuần, nên sau khi gửi ảnh đề toán mà hỏi tiếp
    /// "câu b thì sao" là model KHÔNG CÒN NHÌN THẤY ĐỀ và nó quay ra xin gửi
    /// lại ảnh. Chỉ kèm trong `TAM_NHO_ANH` lượt vì mỗi lần gửi lại là một lần
    /// trả tiền cho ảnh đó.
    private func anhKemLai() -> [String] {
        guard bac.nhanTep else { return [] }
        return tin.suffix(TAM_NHO_ANH).last(where: { $0.cuaNguoi && !$0.anh.isEmpty })?
            .anh.prefix(2).map { $0 } ?? []
    }

    /// `guiKem` được nối vào câu GỬI LÊN nhưng KHÔNG hiện trong bong bóng và
    /// KHÔNG vào lịch sử (lịch sử dựng từ `tin`, tức phần hiển thị). Dùng cho
    /// chế độ nói chuyện: câu trả lời đọc lên phải NGẮN, mà người dùng thì
    /// không nên thấy dòng chỉ dẫn đó lặp lại ở mọi lượt.
    func gui(_ cauHoi: String, anh: [String] = [], tep: [String] = [],
             tenTep: [String] = [], guiKem: String? = nil, voice: Bool = false) {
        guard !dangTraLoi else { return }
        // Ngữ cảnh phải chộp TRƯỚC khi thêm lượt mới, không thì câu vừa gõ
        // lọt vào lịch sử và model đọc nó hai lần.
        let lichSu = lichSuGui()
        let anhGui = anh.isEmpty ? anhKemLai() : anh

        tin.append(TinAI(cuaNguoi: true, noiDung: cauHoi, anh: anh, tenTep: tenTep))
        tin.append(TinAI(cuaNguoi: false, noiDung: "", dangChay: true))
        dangTraLoi = true
        buocHienTai = nil

        viec = Task { [weak self] in
            guard let self else { return }
            let luong = LuongChat.gui(cauHoi: cauHoi + (guiKem.map { "\n\n" + $0 } ?? ""),
                                      sessionId: sessionId,
                                      model: bac.maModel,
                                      lichSu: lichSu,
                                      anh: anhGui,
                                      taiLieu: bac.nhanTep ? tep : [],
                                      tenTaiLieu: bac.nhanTep ? tenTep : [],
                                      timWeb: bac.timWeb,
                                      voice: voice)
            for await su in luong {
                if Task.isCancelled { break }
                switch su {
                case .ketNoi(let sid):
                    sessionId = sid
                case .model(let ten, let haBac, let lyDo):
                    if let i = chiSoDangChay() { tin[i].model = ten }
                    // Bậc bị hạ thì NÓI RA. Người dùng chọn Max mà máy chủ
                    // chạy model khác thì họ có quyền biết.
                    if haBac { buocHienTai = "Đã chuyển model" + (lyDo.map { ": \($0)" } ?? "") }
                case .buoc(let b):
                    buocHienTai = b.isEmpty ? nil : b
                case .suyNghi(let s):
                    buocHienTai = s.isEmpty ? nil : String(s.prefix(80))
                case .nguon(let ns):
                    // Trước đây dòng này là `break` — model tìm web xong mà
                    // người dùng không có cách nào biết nó đọc ở đâu.
                    if let i = chiSoDangChay(), !ns.isEmpty { tin[i].nguon = ns }
                case .mau(let m):
                    buocHienTai = nil
                    if let i = chiSoDangChay() { tin[i].noiDung += m }
                case .xong(let mid, let model, _):
                    if let i = chiSoDangChay() {
                        tin[i].dangChay = false
                        tin[i].messageId = mid
                        if let model { tin[i].model = model }
                        if tin[i].noiDung.isEmpty {
                            tin[i].noiDung = "(AI không trả lời gì. Thử hỏi lại.)"
                        }
                    }
                    dangTraLoi = false
                    buocHienTai = nil
                case .hong(let e):
                    if let i = chiSoDangChay() {
                        tin[i].dangChay = false
                        if tin[i].noiDung.isEmpty { tin.remove(at: i) }
                    }
                    dangTraLoi = false
                    buocHienTai = nil
                    loi = e
                }
            }
            // Luồng đóng mà chưa thấy `done` — coi như xong, đừng để nút gửi
            // kẹt ở trạng thái tắt vĩnh viễn.
            if dangTraLoi {
                if let i = chiSoDangChay() { tin[i].dangChay = false }
                dangTraLoi = false
                buocHienTai = nil
            }
        }
    }

    private func chiSoDangChay() -> Int? {
        tin.indices.last.flatMap { tin[$0].dangChay ? $0 : nil }
    }
}
