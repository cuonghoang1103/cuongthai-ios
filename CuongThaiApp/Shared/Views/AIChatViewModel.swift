import SwiftUI

/// Một tin trong khung chat AI.
struct TinAI: Identifiable {
    let id = UUID()
    let cuaNguoi: Bool
    var noiDung: String
    var dangChay: Bool = false
    var model: String? = nil
    var messageId: Int? = nil
}

/// Ba bậc, khớp với `PURPOSE_MODEL` của backend.
enum BacAI: String, CaseIterable, Identifiable {
    case pro, max
    var id: String { rawValue }

    var ten: String { self == .pro ? "CuongMini Pro" : "CuongMini Max" }
    var bieuTuong: String { self == .pro ? "bolt" : "sparkles" }
    var moTa: String {
        self == .pro
            ? "Nhanh và đủ dùng cho hầu hết câu hỏi."
            : "Chậm hơn nhưng khá hơn ở toán, mã và bài dài."
    }
    /// Mã model gửi lên. Backend tự lùi về model tương đương nếu bậc này
    /// không gọi được — nó ghi WARN chứ không chết.
    var maModel: String? { self == .pro ? nil : "gpt-5.6-sol" }
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var tin: [TinAI] = []
    @Published var dangTraLoi = false
    @Published var buocHienTai: String?
    @Published var loi: String?
    @Published var bac: BacAI = .pro

    private var sessionId: String?
    private var viec: Task<Void, Never>?

    var bacHienTai: BacAI { bac }

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

    func gui(_ cauHoi: String) {
        guard !dangTraLoi else { return }
        tin.append(TinAI(cuaNguoi: true, noiDung: cauHoi))
        tin.append(TinAI(cuaNguoi: false, noiDung: "", dangChay: true))
        dangTraLoi = true
        buocHienTai = nil

        viec = Task { [weak self] in
            guard let self else { return }
            let luong = LuongChat.gui(cauHoi: cauHoi, sessionId: sessionId,
                                      model: bac.maModel)
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
                case .nguon:
                    break
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
