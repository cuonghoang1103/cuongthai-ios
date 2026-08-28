import Foundation

@MainActor
final class MayCV: ObservableObject {
    @Published var hoSo: HoSoCV?
    @Published var doDay: DoDayCV?
    @Published var taiLieu: [TaiLieuCV] = []
    @Published var mau: [MauCV] = []
    @Published var viecLam: [ViecLamCV] = []
    @Published var dangTai = true
    @Published var loi: String?
    /// Cổng AI của từng tính năng — thiếu là bày nút bấm vào chỉ nhận lỗi.
    @Published var congCham: CongAI?
    @Published var congThu: CongAI?
    @Published var congVietLai: CongAI?

    func nap() async {
        dangTai = true; defer { dangTai = false }
        do {
            hoSo = try await APIClient.shared.request(.cvHoSo)
            loi = nil
        } catch {
            loi = error.localizedDescription.contains("401")
                ? T("Đăng nhập để dùng CV Builder.")
                : error.localizedDescription
            return
        }
        // Phần phụ hỏng thì KHÔNG chặn cả trang — hồ sơ mới là thứ chính.
        doDay = try? await APIClient.shared.request(.cvDoDay)
        taiLieu = (try? await APIClient.shared.request(.cvDsTaiLieu)) ?? []
        mau = (try? await APIClient.shared.request(.cvMauCV)) ?? []
        viecLam = (try? await APIClient.shared.request(.cvDsViecLam)) ?? []
        congCham = try? await APIClient.shared.request(.cvTrangThaiCham)
        congThu = try? await APIClient.shared.request(.cvTrangThaiThu)
        congVietLai = try? await APIClient.shared.request(.cvTrangThaiVietLai)
    }

    /// Tải lại hồ sơ + độ đầy sau mỗi lần sửa. Sửa cục bộ rồi tin là xong sẽ
    /// lệch với máy chủ ở đúng những trường máy chủ tự tính (`strength` của
    /// dòng thành tích được chấm lại mỗi lần soi lỗi).
    func napLaiHoSo() async {
        hoSo = (try? await APIClient.shared.request(.cvHoSo)) ?? hoSo
        doDay = (try? await APIClient.shared.request(.cvDoDay)) ?? doDay
    }

    func luuHoSo(_ than: [String: Any]) async -> Bool {
        do {
            let _: HoSoCV = try await APIClient.shared.request(.cvLuuHoSo(than: than))
            await napLaiHoSo()
            return true
        } catch { loi = error.localizedDescription; return false }
    }

    func gui(_ d: APIEndpoint) async -> Bool {
        do {
            let _: DapAnRongLoTrinh = try await APIClient.shared.request(d)
            await napLaiHoSo()
            return true
        } catch {
            // Nhiều endpoint trả về đối tượng vừa tạo chứ không phải rỗng —
            // giải mã hỏng KHÔNG có nghĩa là việc hỏng. Chỉ coi là lỗi khi
            // máy chủ thật sự trả mã lỗi.
            let m = error.localizedDescription
            if m.contains("40") || m.contains("50") { loi = m; return false }
            await napLaiHoSo()
            return true
        }
    }

    func soiLoi() async -> KetQuaSoiLoi? {
        try? await APIClient.shared.request(.cvSoiLoi)
    }
    func doPhu(_ id: Int) async -> DoPhuCV? {
        try? await APIClient.shared.request(.cvDoPhu(id: id))
    }
    func chamCV(_ tId: Int?) async throws -> ChamCV {
        var m: [String: Any] = [:]
        if let t = tId { m["documentId"] = t }
        return try await APIClient.shared.request(.cvChamCV(than: m))
    }
    func thuXinViec(_ id: Int, giong: String) async throws -> ThuXinViec {
        try await APIClient.shared.request(.cvThuXinViec(id: id, than: ["tone": giong]))
    }
    func napViecLam() async {
        viecLam = (try? await APIClient.shared.request(.cvDsViecLam)) ?? viecLam
    }
    func napTaiLieu() async {
        taiLieu = (try? await APIClient.shared.request(.cvDsTaiLieu)) ?? taiLieu
    }
}
