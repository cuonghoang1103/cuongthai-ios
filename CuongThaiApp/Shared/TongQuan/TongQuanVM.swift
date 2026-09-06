import Foundation
import SwiftUI

/// Vỏ giải mã cho `GET /api/v1/dashboard`.
///
/// Máy chủ trả phẳng chứ không lồng: `{ level, exp, totalExp, tasks, … }`.
/// Chỉ khai những trường app dùng — thêm trường mới ở máy chủ không làm hỏng
/// giải mã, còn khai thừa một trường không tồn tại thì có.
struct DapAnTongQuan: Codable {
    var level: Int?
    var exp: Int?
    var totalExp: Int?
    var celebratedToday: Bool?
    var tasks: [ViecTongQuan]
}

struct DapAnLichHoc: Codable { var items: [BuoiHoc] }
struct DapAnMotBuoi: Codable { var item: BuoiHoc }
struct DapAnMotViec: Codable { var task: ViecTongQuan? }

@MainActor
final class TongQuanVM: ObservableObject {
    @Published var viec: [ViecTongQuan] = []
    @Published var trangThai = TrangThaiTongQuan(level: 1, exp: 0, totalExp: 0)
    @Published var buoiHoc: [BuoiHoc] = []
    @Published var pham: PhamViViec = .today
    @Published var dangTai = false
    @Published var dangTaiLich = false
    @Published var loi: String?
    /// Hôm nay đã kết thúc ngày chưa. EXP chỉ cộng MỘT lần mỗi ngày.
    @Published var daKetThucNgay = false
    @Published var vuaCong: Int?

    /// Việc của phạm vi đang chọn, ĐÚNG mốc ngày theo giờ máy.
    ///
    /// Lọc cả `date` chứ không chỉ `scope`: máy chủ giữ lại việc của tuần
    /// trước cho tới khi hết hạn lưu, nên lọc mỗi `scope` sẽ trộn tuần này
    /// với tuần trước vào một danh sách.
    var viecHienTai: [ViecTongQuan] {
        let moc = pham.moc()
        return viec
            .filter { $0.scope == pham.rawValue && $0.date == moc && $0.parentId == nil }
            .sorted { a, b in
                if a.done != b.done { return !a.done }          // việc chưa xong lên trước
                if a.priority != b.priority { return a.priority > b.priority }
                return (a.sortOrder ?? 0, a.id) < (b.sortOrder ?? 0, b.id)
            }
    }

    func viecCon(_ cha: Int) -> [ViecTongQuan] {
        viec.filter { $0.parentId == cha }.sorted { ($0.sortOrder ?? 0, $0.id) < ($1.sortOrder ?? 0, $1.id) }
    }

    var soXong: Int { viecHienTai.filter(\.done).count }
    var soTong: Int { viecHienTai.count }

    // MARK: Nạp

    func nap() async {
        dangTai = true
        defer { dangTai = false }
        loi = nil
        do {
            // GỬI KÈM ngày theo giờ máy — máy chủ cần nó để sinh việc lặp
            // đúng kỳ. Xem ghi chú ở `PhamViViec.moc`.
            let d: DapAnTongQuan = try await APIClient.shared.request(.tongQuan(homNay: PhamViViec.today.moc()))
            viec = d.tasks
            trangThai = TrangThaiTongQuan(level: d.level ?? 1, exp: d.exp ?? 0, totalExp: d.totalExp ?? 0)
            daKetThucNgay = d.celebratedToday ?? false
        } catch {
            loi = error.localizedDescription
        }
    }

    func napLich() async {
        dangTaiLich = true
        defer { dangTaiLich = false }
        do {
            // Lọc theo NGÀY HÔM NAY: lịch kỳ trước không hiện chồng lên kỳ này.
            let d: DapAnLichHoc = try await APIClient.shared.request(.lichHoc(ngay: PhamViViec.today.moc()))
            buoiHoc = d.items
            await NhacHoc.datLai(d.items)
        } catch {
            loi = error.localizedDescription
        }
    }

    // MARK: Việc

    func themViec(_ tieuDe: String, cha: Int? = nil) async {
        let t = tieuDe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var p: [String: Any] = ["scope": pham.rawValue, "date": pham.moc(), "title": t]
        if let cha { p["parentId"] = cha }
        do {
            try await APIClient.shared.send(.themViec(p))
            await nap()
            Haptics.cham()
        } catch { loi = error.localizedDescription }
    }

    func doiXong(_ v: ViecTongQuan) async {
        // Lật ngay tại chỗ để cảm giác tức thì, hỏng thì lật lại.
        guard let i = viec.firstIndex(where: { $0.id == v.id }) else { return }
        let cu = viec[i].done
        viec[i].done = !cu
        if !cu { Haptics.xong() } else { Haptics.cham() }
        do {
            try await APIClient.shared.send(.suaViec(id: v.id, ["done": !cu]))
            await nap()   // EXP và cấp độ do MÁY CHỦ tính, không đoán ở client
        } catch {
            viec[i].done = cu
            loi = error.localizedDescription
        }
    }

    func xoaViec(_ v: ViecTongQuan) async {
        let luu = viec
        viec.removeAll { $0.id == v.id || $0.parentId == v.id }
        do {
            try await APIClient.shared.send(.xoaViec(id: v.id))
        } catch {
            viec = luu
            loi = error.localizedDescription
        }
    }

    func doiViec(_ v: ViecTongQuan, _ p: [String: Any]) async {
        do {
            try await APIClient.shared.send(.suaViec(id: v.id, p))
            await nap()
        } catch { loi = error.localizedDescription }
    }

    /// Có gì để kết thúc ngày không: phải có ít nhất một việc HÔM NAY đã xong
    /// và chưa kết thúc ngày. Hiện nút khi chưa xong việc nào thì bấm vào chỉ
    /// được cộng 0 EXP, và người dùng mất luôn lượt của ngày hôm đó.
    var coTheKetThucNgay: Bool {
        guard !daKetThucNgay else { return false }
        let moc = PhamViViec.today.moc()
        return viec.contains { $0.scope == "today" && $0.date == moc && $0.done }
    }

    func ketThucNgay() async {
        do {
            try await APIClient.shared.send(.ketThucNgay(homNay: PhamViViec.today.moc()))
            let truoc = trangThai.totalExp
            await nap()
            vuaCong = max(0, trangThai.totalExp - truoc)
            Haptics.xong()
        } catch { loi = error.localizedDescription }
    }

    // MARK: Buổi học

    func luuBuoiHoc(_ b: BuoiHoc?, _ p: [String: Any]) async -> Bool {
        do {
            if let b {
                try await APIClient.shared.send(.suaBuoiHoc(id: b.id, p))
            } else {
                try await APIClient.shared.send(.themBuoiHoc(p))
            }
            await napLich()
            Haptics.xong()
            return true
        } catch {
            loi = error.localizedDescription
            return false
        }
    }

    func xoaBuoiHoc(_ b: BuoiHoc) async {
        let luu = buoiHoc
        buoiHoc.removeAll { $0.id == b.id }
        do {
            try await APIClient.shared.send(.xoaBuoiHoc(id: b.id))
            await NhacHoc.datLai(buoiHoc)
        } catch {
            buoiHoc = luu
            loi = error.localizedDescription
        }
    }

    // MARK: Buổi học HÔM NAY — thứ hiện lên trang chủ

    var hocHomNay: [BuoiHoc] {
        let thu = BuoiHoc.thuViet(tuLich: Calendar.current.component(.weekday, from: Date()))
        return buoiHoc.filter { $0.weekday == thu }.sorted { $0.phutBatDau < $1.phutBatDau }
    }

    /// Buổi học kế tiếp trong hôm nay, nếu còn.
    var buoiKeTiep: BuoiHoc? {
        let now = Calendar.current
        let phut = now.component(.hour, from: Date()) * 60 + now.component(.minute, from: Date())
        return hocHomNay.first { $0.phutBatDau >= phut }
    }
}
