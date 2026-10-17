import Foundation

// MARK: - Tính toán THUẦN của Sprint (không UI, không mạng) — kiểm ở `KeHoachB1Tests`.
//
// Cùng luật với web `components/work/reports/BurndownTab.tsx`:
//   committed = sprint.committedPoints ?? điểm đầu.total
//   completed = sprint CLOSED && completedPoints != nil ? completedPoints : điểm biết gần nhất.done
//   remaining = điểm biết gần nhất.remaining ?? committed

struct ChiSoSprintCTW: Equatable {
    var cam: Double      // committed
    var xong: Double     // completed
    var con: Double      // remaining
    /// Tỉ lệ xong theo điểm (0…1). Không có cam kết ⇒ 0.
    var tiLe: Double { cam > 0 ? min(max(xong / cam, 0), 1) : 0 }
}

/// Một điểm vẽ trên biểu đồ burndown/burnup.
struct DiemSprintCTW: Identifiable, Equatable {
    var id: String { ymd }
    var ymd: String
    var ngay: Date
    var conLai: Double?
    var lyTuong: Double?
    var tong: Double?
    var xong: Double?
}

/// Đếm thẻ theo nhóm trạng thái.
struct DemTheSprintCTW: Equatable {
    var chuaLam = 0
    var dangLam = 0
    var xong = 0
    var tong: Int { chuaLam + dangLam + xong }
    var tiLe: Double { tong > 0 ? Double(xong) / Double(tong) : 0 }
}

enum TinhSprintCTW {
    static func chiSo(_ bd: CTWBurndown) -> ChiSoSprintCTW {
        let ds = bd.points ?? []
        let biet = ds.filter { $0.remaining != nil }
        let cuoi = biet.last
        let cam = bd.sprint?.committedPoints ?? ds.first?.total ?? 0
        let xong: Double
        if bd.sprint?.state == "CLOSED", let c = bd.sprint?.completedPoints { xong = c } else { xong = cuoi?.done ?? 0 }
        return ChiSoSprintCTW(cam: cam, xong: xong, con: cuoi?.remaining ?? cam)
    }

    /// Chuỗi điểm vẽ được (bỏ ngày hỏng). Ngày tương lai giữ `lyTuong`, các giá trị khác nil.
    static func chuoi(_ bd: CTWBurndown) -> [DiemSprintCTW] {
        (bd.points ?? []).compactMap { p in
            guard let d = NgayCTW.ngay(p.day) else { return nil }
            return DiemSprintCTW(ymd: p.day, ngay: d, conLai: p.remaining, lyTuong: p.ideal, tong: p.total, xong: p.done)
        }
    }

    /// Ngày còn lại tới `endAt` (âm = trễ). nil nếu không có ngày kết thúc.
    static func ngayConLai(endAt: String?, homNay: Date = Date()) -> Int? {
        guard let e = NgayCTW.thoiDiem(endAt) else { return nil }
        return NgayCTW.soNgay(homNay, e)
    }

    /// Tổng số ngày của sprint (≥ 1).
    static func doDai(startAt: String?, endAt: String?) -> Int? {
        guard let a = NgayCTW.thoiDiem(startAt), let b = NgayCTW.thoiDiem(endAt) else { return nil }
        return max(NgayCTW.soNgay(a, b), 1)
    }

    /// Tỉ lệ thời gian đã trôi (0…1).
    static func thoiGianDaQua(startAt: String?, endAt: String?, homNay: Date = Date()) -> Double? {
        guard let a = NgayCTW.thoiDiem(startAt), let n = doDai(startAt: startAt, endAt: endAt) else { return nil }
        return min(max(Double(NgayCTW.soNgay(a, homNay)) / Double(n), 0), 1)
    }

    /// Dự báo ngày xong theo nhịp đốt TRUNG BÌNH từ đầu sprint tới điểm biết gần nhất.
    /// nil khi chưa đốt được gì (không đoán bừa) hoặc đã xong.
    static func duBaoXong(_ bd: CTWBurndown) -> Date? {
        let ds = chuoi(bd).filter { $0.conLai != nil }
        guard let dau = ds.first, let cuoi = ds.last, ds.count >= 2,
              let c0 = dau.conLai, let c1 = cuoi.conLai, c1 > 0 else { return nil }
        let soNgay = Double(NgayCTW.soNgay(dau.ngay, cuoi.ngay))
        let dot = c0 - c1 + max((cuoi.tong ?? 0) - (dau.tong ?? 0), 0)  // đốt thật = giảm còn lại + phần phạm vi thêm vào
        guard soNgay > 0, dot > 0 else { return nil }
        let nhip = dot / soNgay
        return NgayCTW.cong(cuoi.ngay, ngay: Int((c1 / nhip).rounded(.up)))
    }

    /// Đếm thẻ theo nhóm trạng thái; `nhom(statusId)` trả category (TODO/IN_PROGRESS/DONE).
    /// Thẻ con (cấp -1) KHÔNG đếm — giống báo cáo sprint của web (chỉ thẻ cấp cao nhất).
    static func demThe(_ the: [CTWIssueCard], nhom: (Int) -> String?, laTheCon: (Int) -> Bool = { _ in false }) -> DemTheSprintCTW {
        var d = DemTheSprintCTW()
        for t in the where !laTheCon(t.typeId) {
            switch nhom(t.statusId) {
            case "DONE": d.xong += 1
            case "IN_PROGRESS": d.dangLam += 1
            default:
                if t.resolvedAt != nil { d.xong += 1 } else { d.chuaLam += 1 }
            }
        }
        return d
    }

    /// Tổng điểm của danh sách thẻ (bỏ thẻ con).
    static func tongDiem(_ the: [CTWIssueCard], laTheCon: (Int) -> Bool = { _ in false }) -> Double {
        the.filter { !laTheCon($0.typeId) }.compactMap(\.storyPoints).reduce(0, +)
    }

    /// Sắp sprint: ACTIVE → PLANNED (theo position) → CLOSED (mới đóng trước).
    static func sap(_ ds: [CTWSprintDu]) -> [CTWSprintDu] {
        func hang(_ s: CTWSprintDu) -> Int { s.dangChay ? 0 : (s.chuaBatDau ? 1 : 2) }
        return ds.sorted { a, b in
            if hang(a) != hang(b) { return hang(a) < hang(b) }
            if a.daDong { return (a.completedAt ?? "") > (b.completedAt ?? "") }
            return (a.position ?? a.id, a.id) < (b.position ?? b.id, b.id)
        }
    }
}
