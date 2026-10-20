import Foundation
import WidgetKit
import CoreSpotlight
import UniformTypeIdentifiers

// MARK: - App GHI vùng chung cho widget / Share Extension / Spotlight (mảng D)
//
// Kiểu ảnh chụp + đường App Group: `CTWorkShared/NhomCTW.swift`. Ở đây chỉ là phần của APP:
// gọi API, chuyển thành ảnh chụp, ghi, bảo widget vẽ lại, đánh chỉ mục Spotlight.
// Không bao giờ ghi khi đang chạy máy chủ GIẢ (`CT_XEM_MAN`) — trừ khi đang chụp màn widget.

@MainActor
enum CTWChiaSeNhom {
    /// Khoá Spotlight: "ctw-issue-NW-12" (miền "ctw-issues").
    static let mienSpotlight = "ctw-issues"

    // MARK: Việc hôm nay

    /// Dựng ảnh chụp "hôm nay" từ agenda (+ thẻ quá hạn của My Work).
    static func dungViecHomNay(agenda: [CTWAgendaItem], quaHan: [CTWMyWorkItem], homNay: String = NgayNhomCTW.ymd()) -> AnhViecHomNayCTW {
        var viec: [AnhViecHomNayCTW.Viec] = []
        for i in CTWAgendaKhoang.homNay(agenda, homNay: homNay) {
            switch i.type {
            case "due":
                viec.append(.init(loai: "due", id: "due-\(i.id)", tieuDe: i.title ?? String(localized: "Issue"), ma: i.key, duAn: i.project?.key,
                                  gio: nil, quaHan: false, duongDan: i.url))
            case "meeting":
                guard i.statusText != "CANCELLED" else { continue }
                viec.append(.init(loai: "meeting", id: "hop-\(i.id)", tieuDe: i.title ?? String(localized: "Meeting"), ma: i.number.map { "M-\($0)" },
                                  duAn: i.project?.key, gio: NgayCTW.thoiDiem(i.startsAt), quaHan: false, duongDan: i.url))
            case "sprint":
                let ket = i.end == homNay && i.date != homNay
                let tenSprint = i.title ?? String(localized: "Sprint")
                viec.append(.init(loai: "sprint", id: "sp-\(i.id)", tieuDe: ket ? String(localized: "\(tenSprint) ends") : String(localized: "\(tenSprint) starts"), ma: nil,
                                  duAn: i.project?.key, gio: nil, quaHan: false, duongDan: i.url))
            case "release":
                viec.append(.init(loai: "release", id: "pb-\(i.id)", tieuDe: String(localized: "Release \(i.title ?? "")"), ma: nil,
                                  duAn: i.project?.key, gio: nil, quaHan: false, duongDan: i.url))
            case "stage":
                viec.append(.init(loai: "stage", id: "gd-\(i.id)", tieuDe: String(localized: "Stage \(i.n ?? 0) \(i.event ?? "") · \(i.title ?? "")"), ma: nil,
                                  duAn: i.project?.key, gio: nil, quaHan: false, duongDan: i.url))
            default: continue
            }
        }
        let daCo = Set(viec.compactMap(\.ma))
        for q in quaHan where !daCo.contains(q.key) {
            viec.append(.init(loai: "overdue", id: "qh-\(q.key)", tieuDe: q.title, ma: q.key, duAn: q.project?.key,
                              gio: nil, quaHan: true, duongDan: q.url))
        }
        // Họp theo giờ trước, rồi quá hạn, rồi hạn hôm nay, rồi mốc kế hoạch.
        let thuTu = ["meeting": 0, "overdue": 1, "due": 2, "sprint": 3, "release": 4, "stage": 5]
        viec.sort { a, b in
            let x = thuTu[a.loai] ?? 9, y = thuTu[b.loai] ?? 9
            if x != y { return x < y }
            if let g1 = a.gio, let g2 = b.gio { return g1 < g2 }
            return a.tieuDe < b.tieuDe
        }
        return AnhViecHomNayCTW(ngay: homNay, capNhat: Date(), viec: viec, daDangNhap: true)
    }

    static func ghiViecHomNay(agenda: [CTWAgendaItem], quaHan: [CTWMyWorkItem] = []) {
        guard choGhi else { return }
        dungViecHomNay(agenda: agenda, quaHan: quaHan).ghi()
        WidgetCenter.shared.reloadTimelines(ofKind: "CTWViecHomNayWidget")
    }

    /// Tải lại "hôm nay" từ máy chủ (app ra tiền cảnh, Siri hỏi). Trả ảnh chụp mới (nil nếu lỗi mạng).
    @discardableResult
    static func lamMoiViecHomNay() async -> AnhViecHomNayCTW? {
        let hn = NgayNhomCTW.ymd()
        guard let a: CTWAgenda = try? await APIClient.shared.request(CTWAPI.lichCuaToi(tu: hn, den: hn)) else {
            return AnhViecHomNayCTW.doc()
        }
        let v: CTWMyWork? = try? await APIClient.shared.request(.workViecCuaToi)
        let quaHan = (v?.items ?? []).filter { $0.bucket == "overdue" }
        let anh = dungViecHomNay(agenda: a.items ?? [], quaHan: quaHan, homNay: hn)
        if choGhi {
            anh.ghi()
            WidgetCenter.shared.reloadTimelines(ofKind: "CTWViecHomNayWidget")
        }
        return anh
    }

    // MARK: Dự án (Share Extension)

    static func ghiDuAn(_ nhom: [(ws: CTWWorkspace, duAn: [CTWProjectSummary])], macDinh: Int?) {
        guard choGhi else { return }
        let ds = nhom.flatMap { g in g.duAn.map { AnhDuAnCTW.DuAn(id: $0.id, ma: $0.key, ten: $0.name, slug: g.ws.slug, tenKhongGian: g.ws.name) } }
        NhomCTW.ghi(AnhDuAnCTW(duAn: ds, macDinh: macDinh), ten: AnhDuAnCTW.tep)
    }

    /// Dự án đang chọn luôn có mặt trong danh sách của Share Extension (kể cả khi chưa mở bộ chọn).
    static func ghiDuAnDangChon(_ l: LuaChonCTW?) {
        guard choGhi, let l else { return }
        var anh = AnhDuAnCTW.doc() ?? AnhDuAnCTW(duAn: [], macDinh: nil)
        if !anh.duAn.contains(where: { $0.id == l.pid }) {
            anh.duAn.insert(.init(id: l.pid, ma: l.maDuAn, ten: l.tenDuAn, slug: l.slug, tenKhongGian: l.tenKhongGian), at: 0)
        }
        anh.macDinh = l.pid
        NhomCTW.ghi(anh, ten: AnhDuAnCTW.tep)
    }

    // MARK: Thẻ đã xem (Spotlight)

    /// Gọi khi mở chi tiết một thẻ. Ghi danh sách gần đây + đánh chỉ mục Spotlight (chỉ tiêu đề + mã —
    /// không đưa mô tả/bình luận vào chỉ mục của máy).
    static func daXemThe(pid: Int, slug: String, maDuAn: String, so: Int, tieuDe: String) {
        guard choGhi else { return }
        let t = TheGanDayCTW(pid: pid, slug: slug, maDuAn: maDuAn, so: so, tieuDe: tieuDe, xemLuc: Date())
        TheGanDayCTW.them(t)
        let a = CSSearchableItemAttributeSet(contentType: .text)
        a.title = "\(t.ma) \(tieuDe)"
        a.contentDescription = String(localized: "CT Work issue in \(maDuAn)")
        a.keywords = [t.ma, maDuAn, "CT Work"]
        let item = CSSearchableItem(uniqueIdentifier: "ctw-issue-\(t.ma)|\(t.duongDan)", domainIdentifier: mienSpotlight, attributeSet: a)
        // Hết hạn sau 30 ngày không xem lại.
        item.expirationDate = Date().addingTimeInterval(30 * 86400)
        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }

    /// Móc cho `CTWIssueView(khiMo:)`.
    static func khiMoThe(_ t: CTWIssueDetail, _ c: CTWProjectConfig) {
        guard let slug = c.workspace?.slug else { return }
        daXemThe(pid: c.id, slug: slug, maDuAn: c.key, so: t.number, tieuDe: t.title)
    }

    /// Spotlight trả `uniqueIdentifier` ⇒ đường dẫn mở.
    static func duongDanTuSpotlight(_ id: String) -> String? {
        guard id.hasPrefix("ctw-issue-"), let i = id.firstIndex(of: "|") else { return nil }
        let d = String(id[id.index(after: i)...])
        return d.hasPrefix("/work/") ? d : nil
    }

    // MARK: Token cho Share Extension

    static func dongBoToken() {
        guard choGhi else { return }
        TokenNhomCTW.luu(StorageManager.shared.getAuthToken())
    }

    /// Đăng xuất: xoá mọi thứ trong vùng chung + chỉ mục Spotlight + Live Activity.
    static func donKhiDangXuat() {
        NhomCTW.xoaHet()
        AnhViecHomNayCTW(ngay: NgayNhomCTW.ymd(), capNhat: Date(), viec: [], daDangNhap: false).ghi()
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [mienSpotlight]) { _ in }
        Task { await LiveActivityDongHoCTW.donHet() }
    }

    /// Bản DEBUG chạy dữ liệu mẫu: không ghi đè vùng chung (trừ khi bật cờ chụp màn widget).
    private static var choGhi: Bool {
        #if DEBUG
        // ⚠️ KHÔNG đọc `AppState.shared` ở đây: hàm này được gọi từ `didSet` của `AppState` lúc nó đang
        // khởi tạo ⇒ `dispatch_once` gọi lại chính nó ⇒ SIGTRAP lúc mở app (đã dính 18/10/2026).
        if let m = XemThuCTW.man, !m.isEmpty { return XemThuCTW.choGhiNhom }
        #endif
        return true
    }
}
