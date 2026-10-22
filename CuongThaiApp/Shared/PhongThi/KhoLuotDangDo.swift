import Foundation

// ════════════════════════════════════════════════════════════════
// "ĐANG LÀM DỞ" — nhớ những lượt thi đã mở trên máy này
//
// ⚠️ Máy chủ KHÔNG có đường liệt kê lượt đang dở của mọi đề:
// `GET /attempts/mine` chỉ trả `SUBMITTED | GRADED | EXPIRED`, còn
// `inProgressId` chỉ có theo TỪNG đề (`/take`) hoặc từng môn
// (`/course/:slug`). Hỏi 1.300 đề để tìm vài lượt dở là không được.
//
// Nên app tự ghi lại lượt nó mở. Đây là GỢI Ý để quay lại nhanh, không phải
// nguồn sự thật: bấm vào thì `POST /:examId/attempts` của máy chủ quyết định
// nối lại hay tạo mới (lượt hết giờ máy chủ tự đóng). Lượt mở từ WEB thì danh
// sách này không thấy — ghi rõ trong báo cáo cho backend.
// ════════════════════════════════════════════════════════════════

struct LuotDangDo: Codable, Identifiable, Hashable {
    let examId: Int
    let attemptId: Int
    let tieuDe: String
    let maDe: String?
    let coAI: Bool
    /// ISO 8601 — `nil` với lượt CuongMini (không tính giờ).
    let hetHan: String?
    let moLuc: Double
    /// Đề đầy đủ (để mở lại màn chi tiết không phải tải danh sách).
    let de: DeThi?

    var id: String { "\(examId)-\(coAI ? 1 : 0)" }

    var hetGioRoi: Bool {
        guard let h = hetHan, let d = Date.tuChuoiISO(h) else { return false }
        return d.timeIntervalSinceNow <= 0
    }
    var conLaiGiay: Int? {
        guard let h = hetHan, let d = Date.tuChuoiISO(h) else { return nil }
        return max(0, Int(d.timeIntervalSinceNow))
    }
}

@MainActor
final class KhoLuotDangDo: ObservableObject {
    static let chung = KhoLuotDangDo()
    private static let khoa = "phongThi.luotDangDo.v1"

    @Published private(set) var ds: [LuotDangDo] = []

    private init() { nap() }

    /// Lượt còn dùng được: bỏ lượt thi THẬT đã hết giờ (máy chủ sẽ tự đóng
    /// nó ở lần mở kế tiếp, giữ lại chỉ làm người dùng bấm vào một lượt chết).
    var conHieuLuc: [LuotDangDo] {
        ds.filter { $0.coAI || !$0.hetGioRoi }.sorted { $0.moLuc > $1.moLuc }
    }

    func ghi(_ l: LuotDangDo) {
        ds.removeAll { $0.id == l.id }
        ds.append(l)
        if ds.count > 30 { ds = Array(ds.sorted { $0.moLuc > $1.moLuc }.prefix(30)) }
        luu()
    }

    func xoa(examId: Int, coAI: Bool) {
        ds.removeAll { $0.examId == examId && $0.coAI == coAI }
        luu()
    }

    func xoa(attemptId: Int) {
        ds.removeAll { $0.attemptId == attemptId }
        luu()
    }

    private func nap() {
        guard let d = UserDefaults.standard.data(forKey: Self.khoa),
              let x = try? JSONDecoder().decode([LuotDangDo].self, from: d) else { return }
        ds = x
    }

    private func luu() {
        if let d = try? JSONEncoder().encode(ds) { UserDefaults.standard.set(d, forKey: Self.khoa) }
    }
}
