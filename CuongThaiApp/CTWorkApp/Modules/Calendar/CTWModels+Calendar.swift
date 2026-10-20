import Foundation
import SwiftUI

// MARK: - Model Lịch (Calendar)
//
// NGUỒN CHÍNH (18/10/2026): `GET /me/agenda?from&to` — hạn thẻ của tôi, sprint, phát hành, giai đoạn, họp
// của MỌI dự án tôi tham gia trong MỘT lời gọi (`meAgenda.service.ts`, ngày đã cắt theo giờ VN). Xem
// `GopLichCTW.tuAgenda`. Máy chủ cũ / lỗi ⇒ lùi về cách gộp tay cũ:
//   · `GET /me/work`                         — hạn thẻ của tôi ở MỌI dự án (YMD)
//   · `GET /projects/:pid/timeline/markers`  — sprint · version · stage (YMD, sprint có thể lệch UTC)
//   · `GET /projects/:pid/meetings?scope=upcoming` — họp (ISO thật; `meetings.service.ts:44-84`)
//   · `GET/POST /me/calendar-link`           — link .ics đăng ký (POST tạo mới ⇒ THU HỒI link cũ)
// Tên kiểu riêng (`HopLichCTW`…) để không đụng mô-đun Meetings của mảng khác.

struct HopLichCTW: Codable, Hashable, Identifiable {
    var id: Int
    var number: Int?
    var title: String?
    var type: String?
    /// SCHEDULED | DONE | CANCELLED
    var status: String?
    var startsAt: String?
    var endsAt: String?
    var timezone: String?
    var location: String?
    var meetingUrl: String?
    var organizer: CTWUser?
    var key: String?
    var typeLabel: String?
    /// MEET | ZOOM | TEAMS | JITSI | OTHER
    var provider: String?
    var attendees: [CTWUser]?
}

struct DsHopLichCTW: Codable {
    var items: [HopLichCTW]?
    var canEdit: Bool?
    var now: String?
}

struct LinkLichCTW: Codable {
    var active: Bool?
    var createdAt: String?
    var lastUsedAt: String?
    var prefix: String?
}

struct LinkLichMoiCTW: Codable {
    /// Hiện MỘT lần.
    var token: String?
    /// "/work/calendar/<token>.ics" (tương đối với `/api/v1`).
    var path: String?
}

/// Loại sự kiện trên lịch — mỗi loại một màu + biểu tượng + chữ (không chỉ dựa vào màu).
enum LoaiSuKienLichCTW: String, CaseIterable, Identifiable, Hashable {
    case han, sprint, phatHanh, hop, giaiDoan
    var id: String { rawValue }
    var ten: String {
        switch self {
        case .han: return String(localized: "My due dates")
        case .sprint: return String(localized: "Sprints")
        case .phatHanh: return String(localized: "Releases")
        case .hop: return String(localized: "Meetings")
        case .giaiDoan: return String(localized: "Stages")
        }
    }
    var bieuTuong: String {
        switch self {
        case .han: return "checklist"
        case .sprint: return "flag.fill"
        case .phatHanh: return "shippingbox.fill"
        case .hop: return "person.2.fill"
        case .giaiDoan: return "flag.checkered"
        }
    }
    var mau: Color {
        switch self {
        case .han: return CTWMauChuoi.mau(0)
        case .sprint: return CTWMauChuoi.mau(6)
        case .phatHanh: return CTWMauChuoi.mau(1)
        case .hop: return CTWMauChuoi.mau(2)
        case .giaiDoan: return CTWMauChuoi.mau(4)
        }
    }
}

/// Một sự kiện đã gộp, sẵn để vẽ.
struct SuKienLichCTW: Identifiable, Hashable {
    var id: String
    var loai: LoaiSuKienLichCTW
    var tieuDe: String
    var phu: String?
    /// Ngày (nửa đêm VN) với sự kiện cả ngày; thời điểm thật với họp.
    var batDau: Date
    var ketThuc: Date?
    var caNgay: Bool
    /// Thẻ để mở (hạn thẻ): slug + mã dự án + số.
    var slug: String?
    var maDuAn: String?
    var so: Int?
    var quaHan = false
    var hop: HopLichCTW?
    /// Phiên bản (mở chi tiết release).
    var idPhienBan: Int?
}

enum GopLichCTW {
    /// Khoá ngày "YYYY-MM-DD". Sự kiện cả ngày theo lịch VN (khớp máy chủ); họp theo giờ MÁY (người
    /// dùng đọc giờ họp theo múi của mình).
    static func khoa(_ s: SuKienLichCTW) -> String {
        if s.caNgay { return NgayCTW.ymd(s.batDau) }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: s.batDau)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// Gộp theo ngày, mỗi ngày sắp: cả ngày trước, rồi theo giờ.
    static func theoNgay(_ ds: [SuKienLichCTW]) -> [String: [SuKienLichCTW]] {
        var kq: [String: [SuKienLichCTW]] = [:]
        for s in ds { kq[khoa(s), default: []].append(s) }
        for (k, v) in kq {
            kq[k] = v.sorted { a, b in
                if a.caNgay != b.caNgay { return a.caNgay }
                if a.batDau != b.batDau { return a.batDau < b.batDau }
                return a.tieuDe < b.tieuDe
            }
        }
        return kq
    }

    /// Dựng danh sách sự kiện từ các nguồn. Sprint ⇒ HAI sự kiện (bắt đầu, kết thúc) để lưới tháng
    /// không bị chấm kín mọi ngày.
    static func dung(viec: [CTWMyWorkItem], moc: TLMocCTW, sprintCfg: [CTWSprint], hop: [HopLichCTW],
                     homNay: Date = Date()) -> [SuKienLichCTW] {
        var kq: [SuKienLichCTW] = []
        let hn = NgayCTW.ymd(homNay)
        for v in viec {
            guard let d = NgayCTW.ngay(v.dueDate) else { continue }
            kq.append(SuKienLichCTW(id: "han-\(v.key)", loai: .han, tieuDe: v.title,
                                    phu: [v.key, v.status?.name].compactMap { $0 }.joined(separator: " · "),
                                    batDau: d, caNgay: true, slug: v.workspace?.slug, maDuAn: v.project?.key, so: v.number,
                                    quaHan: (v.dueDate.map { String($0.prefix(10)) } ?? hn) < hn))
        }
        // Sprint: ưu tiên ngày thật (ISO) của cfg — markers cắt UTC có thể sớm một ngày.
        var daCo = Set<Int>()
        for s in sprintCfg {
            daCo.insert(s.id)
            if let a = NgayCTW.ngay(NgayCTW.ngayCua(s.startAt)) {
                kq.append(SuKienLichCTW(id: "sp-\(s.id)-a", loai: .sprint, tieuDe: String(localized: "\(s.name) starts"), phu: s.goal, batDau: a, caNgay: true))
            }
            if let b = NgayCTW.ngay(NgayCTW.ngayCua(s.endAt)) {
                kq.append(SuKienLichCTW(id: "sp-\(s.id)-b", loai: .sprint, tieuDe: String(localized: "\(s.name) ends"), phu: s.goal, batDau: b, caNgay: true))
            }
        }
        for s in moc.sprints ?? [] where !daCo.contains(s.id) {
            if let a = NgayCTW.ngay(s.start) {
                kq.append(SuKienLichCTW(id: "sp-\(s.id)-a", loai: .sprint, tieuDe: String(localized: "\(s.name ?? String(localized: "Sprint")) starts"), batDau: a, caNgay: true))
            }
            if let b = NgayCTW.ngay(s.end) {
                kq.append(SuKienLichCTW(id: "sp-\(s.id)-b", loai: .sprint, tieuDe: String(localized: "\(s.name ?? String(localized: "Sprint")) ends"), batDau: b, caNgay: true))
            }
        }
        for v in moc.versions ?? [] {
            guard let r = NgayCTW.ngay(v.release) else { continue }
            kq.append(SuKienLichCTW(id: "pb-\(v.id)", loai: .phatHanh, tieuDe: String(localized: "Release \(v.name ?? "")"),
                                    phu: v.status == "RELEASED" ? String(localized: "Released") : String(localized: "Planned release"),
                                    batDau: r, caNgay: true, idPhienBan: v.id))
        }
        for g in moc.stages ?? [] {
            if let a = NgayCTW.ngay(g.start) {
                kq.append(SuKienLichCTW(id: "gd-\(g.id)-a", loai: .giaiDoan, tieuDe: String(localized: "Stage \(g.n ?? 0) started · \(g.name ?? "")"), batDau: a, caNgay: true))
            }
            if let b = NgayCTW.ngay(g.end) {
                kq.append(SuKienLichCTW(id: "gd-\(g.id)-b", loai: .giaiDoan, tieuDe: String(localized: "Stage \(g.n ?? 0) completed · \(g.name ?? "")"), batDau: b, caNgay: true))
            }
        }
        for h in hop where h.status != "CANCELLED" {
            guard let a = NgayCTW.thoiDiem(h.startsAt) else { continue }
            let b = NgayCTW.thoiDiem(h.endsAt)
            let gio = b.map { "\(NgayCTW.gio(a)) – \(NgayCTW.gio($0))" } ?? NgayCTW.gio(a)
            kq.append(SuKienLichCTW(id: "hop-\(h.id)", loai: .hop, tieuDe: h.title ?? String(localized: "Meeting"),
                                    phu: [gio, h.location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                                    batDau: a, ketThuc: b, caNgay: false, hop: h))
        }
        return kq
    }

    /// Dựng sự kiện từ `/me/agenda`. Sprint ⇒ hai sự kiện (bắt đầu `date`, kết thúc `end`).
    static func tuAgenda(_ ds: [CTWAgendaItem], homNay: Date = Date()) -> [SuKienLichCTW] {
        let hn = NgayCTW.ymd(homNay)
        var kq: [SuKienLichCTW] = []
        for i in ds {
            let p = i.project
            switch i.type {
            case "due":
                guard let d = NgayCTW.ngay(i.date) else { continue }
                kq.append(SuKienLichCTW(id: "han-\(i.key ?? "\(i.id)")", loai: .han, tieuDe: i.title ?? String(localized: "Issue"),
                                        phu: [i.key, i.status?.name].compactMap { $0 }.joined(separator: " · "),
                                        batDau: d, caNgay: true, slug: p?.workspaceSlug, maDuAn: p?.key, so: i.number,
                                        quaHan: i.date < hn))
            case "sprint":
                if let a = NgayCTW.ngay(i.date) {
                    kq.append(SuKienLichCTW(id: "sp-\(i.id)-a", loai: .sprint, tieuDe: String(localized: "\(i.title ?? String(localized: "Sprint")) starts"),
                                            phu: [p?.key, i.goal].compactMap { $0 }.joined(separator: " · "), batDau: a, caNgay: true))
                }
                if let b = NgayCTW.ngay(i.end) {
                    kq.append(SuKienLichCTW(id: "sp-\(i.id)-b", loai: .sprint, tieuDe: String(localized: "\(i.title ?? String(localized: "Sprint")) ends"),
                                            phu: [p?.key, i.goal].compactMap { $0 }.joined(separator: " · "), batDau: b, caNgay: true))
                }
            case "release":
                guard let r = NgayCTW.ngay(i.date) else { continue }
                kq.append(SuKienLichCTW(id: "pb-\(i.id)", loai: .phatHanh, tieuDe: String(localized: "Release \(i.title ?? "")"),
                                        phu: [p?.key, i.statusText == "RELEASED" ? String(localized: "Released") : String(localized: "Planned release")].compactMap { $0 }.joined(separator: " · "),
                                        batDau: r, caNgay: true, idPhienBan: i.id))
            case "stage":
                guard let d = NgayCTW.ngay(i.date) else { continue }
                kq.append(SuKienLichCTW(id: "gd-\(i.id)-\(i.event ?? "")", loai: .giaiDoan,
                                        tieuDe: i.event == "completed" ? String(localized: "Stage \(i.n ?? 0) completed · \(i.title ?? "")") : String(localized: "Stage \(i.n ?? 0) started · \(i.title ?? "")"),
                                        phu: p?.key, batDau: d, caNgay: true))
            case "meeting":
                guard i.statusText != "CANCELLED", let a = NgayCTW.thoiDiem(i.startsAt) else { continue }
                let b = NgayCTW.thoiDiem(i.endsAt)
                let gio = b.map { "\(NgayCTW.gio(a)) – \(NgayCTW.gio($0))" } ?? NgayCTW.gio(a)
                let hop = HopLichCTW(id: i.id, number: i.number, title: i.title, type: i.meetingType, status: i.statusText,
                                     startsAt: i.startsAt, endsAt: i.endsAt, timezone: i.timezone, location: i.location,
                                     meetingUrl: i.meetingUrl, key: i.number.map { "M-\($0)" })
                kq.append(SuKienLichCTW(id: "hop-\(i.id)", loai: .hop, tieuDe: i.title ?? String(localized: "Meeting"),
                                        phu: [gio, p?.key, i.location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                                        batDau: a, ketThuc: b, caNgay: false, hop: hop))
            default:
                continue
            }
        }
        return kq
    }

    /// 42 ô (6 tuần, bắt đầu thứ Hai) của tháng chứa `thang` — theo lịch MÁY.
    static func oThang(_ thang: Date, lich: Calendar = .current) -> [Date] {
        var l = lich
        l.firstWeekday = 2
        let dau = l.date(from: l.dateComponents([.year, .month], from: thang)) ?? thang
        let thu = l.component(.weekday, from: dau)
        let lui = (thu - l.firstWeekday + 7) % 7
        let batDau = l.date(byAdding: .day, value: -lui, to: dau) ?? dau
        return (0..<42).compactMap { l.date(byAdding: .day, value: $0, to: batDau) }
    }
}
