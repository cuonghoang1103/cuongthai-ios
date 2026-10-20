import Foundation
import CoreGraphics

// MARK: - Hình học Gantt (thuần, kiểm thử được)
//
// Quy tắc thanh — giống web `components/work/Timeline.tsx:122-197`:
//   · có start + due  ⇒ thanh đầy đủ (hai đầu tính cả ngày)
//   · chỉ due          ⇒ thanh 1 ngày
//   · chỉ start        ⇒ thanh "mở đuôi" (vẽ 5 ngày, đầu phải mờ dần)
//   · không ngày       ⇒ thanh NÉT ĐỨT theo khoảng sprint, không có thì theo khoảng version
//   · epic không ngày  ⇒ phủ min…max các thanh con
// Mọi ngày tính theo lịch giờ VN (khớp cách máy chủ chia ngày).

enum TLZoomCTW: String, CaseIterable, Identifiable {
    case tuan = "Week", thang = "Month", quy = "Quarter"
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .tuan: return String(localized: "Week")
        case .thang: return String(localized: "Month")
        case .quy: return String(localized: "Quarter")
        }
    }
    /// Độ rộng một ngày (pt) — theo web: weeks 32, months 10, quarters 3.5.
    var rongNgay: CGFloat {
        switch self {
        case .tuan: return 32
        case .thang: return 10
        case .quy: return 3.5
        }
    }
}

enum TLKieuThanhCTW: Equatable {
    case day, motNgay, moDuoi, suyRa
}

struct TLThanhCTW: Equatable {
    var batDau: Date
    /// Ngày cuối (tính cả ngày đó).
    var ketThuc: Date
    var kieu: TLKieuThanhCTW
}

/// Một hàng của Gantt / danh sách.
enum TLHangCTW: Identifiable, Hashable {
    case nhom(String)
    case muc(TLMucCTW, thutLe: Bool)

    var id: String {
        switch self {
        case .nhom(let t): return "nhom-\(t)"
        case .muc(let m, _): return "muc-\(m.id)"
        }
    }
    var muc: TLMucCTW? { if case .muc(let m, _) = self { return m }; return nil }
}

struct TLHinhHocCTW: Equatable {
    /// Ngày đầu của trục (nửa đêm VN).
    var goc: Date
    var soNgay: Int
    var rongNgay: CGFloat

    var rongTong: CGFloat { CGFloat(soNgay) * rongNgay }

    func x(_ d: Date) -> CGFloat { CGFloat(NgayCTW.soNgay(goc, d)) * rongNgay }

    /// Vị trí + độ rộng (tối thiểu bằng một ngày).
    func khung(_ t: TLThanhCTW) -> (x: CGFloat, rong: CGFloat) {
        let n = max(NgayCTW.soNgay(t.batDau, t.ketThuc) + 1, 1)
        return (x(t.batDau), CGFloat(n) * rongNgay)
    }

    func ngay(_ i: Int) -> Date { NgayCTW.cong(goc, ngay: i) }
}

enum TLBoDungCTW {
    /// Khoảng ngày (đầu, cuối) theo id — sprint / version.
    typealias Khoang = [Int: (Date, Date)]

    /// Thanh của một thẻ KHÔNG phải epic suy ra (hoặc epic có ngày riêng).
    static func thanhRieng(_ m: TLMucCTW, sprint: Khoang, version: Khoang) -> TLThanhCTW? {
        let s = NgayCTW.ngay(m.start), d = NgayCTW.ngay(m.due)
        switch (s, d) {
        case let (s?, d?): return TLThanhCTW(batDau: min(s, d), ketThuc: max(s, d), kieu: .day)
        case let (nil, d?): return TLThanhCTW(batDau: d, ketThuc: d, kieu: .motNgay)
        case let (s?, nil): return TLThanhCTW(batDau: s, ketThuc: NgayCTW.cong(s, ngay: 4), kieu: .moDuoi)
        case (nil, nil):
            if let id = m.sprintId, let k = sprint[id] { return TLThanhCTW(batDau: k.0, ketThuc: k.1, kieu: .suyRa) }
            if let id = m.fixVersionId, let k = version[id] { return TLThanhCTW(batDau: k.0, ketThuc: k.1, kieu: .suyRa) }
            return nil
        }
    }

    /// Thanh của mọi thẻ (epic không ngày phủ min…max con).
    static func tatCaThanh(_ ds: [TLMucCTW], sprint: Khoang, version: Khoang) -> [Int: TLThanhCTW] {
        var kq: [Int: TLThanhCTW] = [:]
        for m in ds { if let t = thanhRieng(m, sprint: sprint, version: version) { kq[m.id] = t } }
        for e in ds where e.laEpic && !e.coLich {
            let con = ds.filter { $0.parentId == e.id }.compactMap { kq[$0.id] }
            guard let dau = con.map(\.batDau).min(), let cuoi = con.map(\.ketThuc).max() else { continue }
            kq[e.id] = TLThanhCTW(batDau: dau, ketThuc: cuoi, kieu: .suyRa)
        }
        return kq
    }

    /// Phạm vi trục: từ thanh sớm nhất − 7 ngày tới thanh muộn nhất + 14 ngày, luôn chứa hôm nay;
    /// tối thiểu 8 tuần để trục không cụt khi ít dữ liệu.
    static func phamVi(_ thanh: [TLThanhCTW], them: [Date] = [], homNay: Date) -> (goc: Date, soNgay: Int) {
        let hn = NgayCTW.lichVN.startOfDay(for: homNay)
        let dau = ([hn] + thanh.map(\.batDau) + them).min() ?? hn
        let cuoi = ([hn] + thanh.map(\.ketThuc) + them).max() ?? hn
        let goc = NgayCTW.dauTuan(NgayCTW.cong(dau, ngay: -7))
        let n = max(NgayCTW.soNgay(goc, cuoi) + 15, 56)
        return (goc, n)
    }

    /// Hàng theo cây: mỗi epic rồi các con của nó; còn lại vào nhóm "No epic".
    static func hang(_ ds: [TLMucCTW], anKhongLich: Bool, coThanh: Set<Int>) -> [TLHangCTW] {
        let epic = ds.filter(\.laEpic)
        let idEpic = Set(epic.map(\.id))
        var kq: [TLHangCTW] = []
        func hien(_ m: TLMucCTW) -> Bool { !anKhongLich || coThanh.contains(m.id) }
        for e in epic {
            let con = ds.filter { !$0.laEpic && $0.parentId == e.id && hien($0) }
            if !hien(e) && con.isEmpty { continue }
            kq.append(.muc(e, thutLe: false))
            kq += con.map { .muc($0, thutLe: true) }
        }
        let le = ds.filter { !$0.laEpic && !($0.parentId.map(idEpic.contains) ?? false) && hien($0) }
        if !le.isEmpty {
            if !epic.isEmpty { kq.append(.nhom(String(localized: "No epic"))) }
            kq += le.map { .muc($0, thutLe: false) }
        }
        return kq
    }

    /// Chế độ danh sách: nhóm theo THÁNG của ngày đại diện (due, không có thì start, không có thì
    /// đầu thanh suy ra). Thẻ không lịch vào nhóm cuối (`thang == nil`).
    static func theoThang(_ ds: [TLMucCTW], thanh: [Int: TLThanhCTW]) -> [(thang: Date?, ds: [TLMucCTW])] {
        var nhom: [Date: [TLMucCTW]] = [:]
        var khong: [TLMucCTW] = []
        let l = NgayCTW.lichVN
        for m in ds {
            guard let d = NgayCTW.ngay(m.due) ?? NgayCTW.ngay(m.start) ?? thanh[m.id]?.ketThuc else { khong.append(m); continue }
            let c = l.dateComponents([.year, .month], from: d)
            let dau = l.date(from: c) ?? d
            nhom[dau, default: []].append(m)
        }
        func ngayDaiDien(_ m: TLMucCTW) -> Date {
            NgayCTW.ngay(m.due) ?? NgayCTW.ngay(m.start) ?? thanh[m.id]?.ketThuc ?? .distantFuture
        }
        var kq: [(thang: Date?, ds: [TLMucCTW])] = nhom.keys.sorted().map { k in
            (k, nhom[k]!.sorted { (ngayDaiDien($0), $0.number) < (ngayDaiDien($1), $1.number) })
        }
        if !khong.isEmpty { kq.append((nil, khong)) }
        return kq
    }
}
