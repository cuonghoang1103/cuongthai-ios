import Foundation
import CoreGraphics

// MARK: - Logic THUẦN của Tin nhắn kiểu Messenger + Hồ sơ (22/10/2026 — bản 1.1)
//
// Mọi luật "trông như Messenger" nằm ở đây để kiểm thử được (`MessengerHoSoTests`), màn chỉ đọc kết quả:
//   · gom nhóm tin liên tiếp của cùng người + mốc thời gian chỉ khi cách xa (thay "mốc giờ trên gần như mọi tin" —
//     ảnh chủ app gửi 22/10),
//   · giờ ngắn kiểu Messenger cho danh sách hội thoại ("2 phút", "Thứ 4", "12/10"),
//   · cảm xúc (đảo lạc quan), trích dẫn trả lời, emoji lớn, link trong chữ,
//   · trang GIF (`/gifs?offset=` — máy chủ cũ bỏ qua offset ⇒ lọc trùng rồi dừng),
//   · thân yêu cầu đổi ảnh đại diện/bìa/hồ sơ, chuyển tiếp, khung cắt ảnh vuông.

// MARK: Gom nhóm + mốc thời gian

/// Vị trí một tin trong nhóm tin liên tiếp của cùng người gửi.
enum ViTriNhomCTW: Equatable {
    case don, dau, giua, cuoi
    var laDau: Bool { self == .don || self == .dau }
    var laCuoi: Bool { self == .don || self == .cuoi }
}

/// Cách vẽ MỘT tin: vị trí trong nhóm + có vẽ mốc thời gian phía trên không.
struct BoCucTinCTW: Equatable {
    var viTri: ViTriNhomCTW
    /// Vẽ mốc thời gian phía trên tin này (tin đầu hội thoại, sang ngày khác, hoặc cách tin trước > 1 giờ).
    var mocThoiGian: Bool
}

enum NhomTinCTW {
    /// Hai tin cùng người cách nhau ≤ 3 phút ⇒ cùng nhóm (bo góc liền, avatar một lần).
    static let khoangNhom: TimeInterval = 3 * 60
    /// Mốc thời gian giữa hai tin chỉ khi cách > 1 giờ (hoặc khác ngày) — Messenger không vẽ mốc trên mỗi tin.
    static let khoangMoc: TimeInterval = 60 * 60

    struct Muc: Equatable {
        var nguoi: Int
        var luc: Date?
        /// Tin "đứng riêng" (đã thu hồi, nhãn dán, emoji lớn) — vẫn chung người nhưng không ghép bo góc.
        var dungRieng = false
    }

    static func canMoc(truoc: Date?, nay: Date?, lich: Calendar = .current) -> Bool {
        guard let nay else { return false }
        guard let truoc else { return true }
        if !lich.isDate(truoc, inSameDayAs: nay) { return true }
        return nay.timeIntervalSince(truoc) > khoangMoc
    }

    /// Bố cục cho cả dãy tin (cũ ⇒ mới).
    static func boCuc(_ ds: [Muc], lich: Calendar = .current) -> [BoCucTinCTW] {
        guard !ds.isEmpty else { return [] }
        var moc = [Bool](repeating: false, count: ds.count)
        for i in ds.indices { moc[i] = canMoc(truoc: i > 0 ? ds[i - 1].luc : nil, nay: ds[i].luc, lich: lich) }
        func noi(_ a: Int, _ b: Int) -> Bool {   // a liền trước b
            let x = ds[a], y = ds[b]
            guard x.nguoi == y.nguoi, !moc[b], !x.dungRieng, !y.dungRieng else { return false }
            guard let p = x.luc, let q = y.luc else { return false }
            return q.timeIntervalSince(p) <= khoangNhom
        }
        return ds.indices.map { i in
            let truoc = i > 0 && noi(i - 1, i)
            let sau = i + 1 < ds.count && noi(i, i + 1)
            let v: ViTriNhomCTW = truoc ? (sau ? .giua : .cuoi) : (sau ? .dau : .don)
            return BoCucTinCTW(viTri: v, mocThoiGian: moc[i])
        }
    }

    /// Tin CUỐI nhóm của người kia ⇒ chỗ vẽ avatar (một lần mỗi nhóm, như Messenger).
    static func hienAvatar(_ b: BoCucTinCTW, cuaToi: Bool) -> Bool { !cuaToi && b.viTri.laCuoi }
}

/// Bán kính bốn góc bong bóng: góc phía người gửi bo NHỎ ở chỗ nối với tin cùng nhóm, còn lại bo lớn.
struct GocBongCTW: Equatable {
    var trenTrai: CGFloat, trenPhai: CGFloat, duoiTrai: CGFloat, duoiPhai: CGFloat
    static let lon: CGFloat = 19
    static let nho: CGFloat = 5

    static func cho(_ v: ViTriNhomCTW, cuaToi: Bool) -> GocBongCTW {
        let tren = v.laDau ? lon : nho
        let duoi = v.laCuoi ? lon : nho
        return cuaToi
            ? GocBongCTW(trenTrai: lon, trenPhai: tren, duoiTrai: lon, duoiPhai: duoi)
            : GocBongCTW(trenTrai: tren, trenPhai: lon, duoiTrai: duoi, duoiPhai: lon)
    }
}

// MARK: Giờ ngắn kiểu Messenger (danh sách hội thoại)

enum ThoiGianNganCTW: Equatable {
    case vuaXong
    case phut(Int)
    case gio(Int)
    /// Trong tuần: thứ theo `Calendar.weekday` (1 = Chủ nhật … 7 = Thứ bảy).
    case thu(Int)
    case ngay(Date)
    case ngayNam(Date)

    static func phanLoai(_ d: Date, bayGio: Date = Date(), lich: Calendar = .current) -> ThoiGianNganCTW {
        let giay = bayGio.timeIntervalSince(d)
        if giay < 60 { return .vuaXong }
        if giay < 3600 { return .phut(Int(giay / 60)) }
        if giay < 24 * 3600 { return .gio(Int(giay / 3600)) }
        let ngay = lich.dateComponents([.day], from: lich.startOfDay(for: d), to: lich.startOfDay(for: bayGio)).day ?? 99
        if ngay < 7 { return .thu(lich.component(.weekday, from: d)) }
        if lich.component(.year, from: d) == lich.component(.year, from: bayGio) { return .ngay(d) }
        return .ngayNam(d)
    }

    /// "Vừa xong"/"now" · "2 phút"/"2m" · "3 giờ"/"3h" · "Thứ 4"/"Wed" · "12/10"/"10/12" · "12/10/25".
    func chu(viet: Bool = CTWDinhDang.laTiengViet) -> String {
        switch self {
        case .vuaXong: return String(localized: "now")
        case .phut(let n): return String(localized: "\(n)m")
        case .gio(let n): return String(localized: "\(n)h")
        case .thu(let w):
            if viet { return w == 1 ? "CN" : "Thứ \(w)" }
            return Self.thuAnh[(w - 1) % 7]
        case .ngay(let d): return CTWDinhDang.mau(viet ? "dM" : "Md").string(from: d)
        case .ngayNam(let d): return CTWDinhDang.mau(viet ? "dMyy" : "Mdyy").string(from: d)
        }
    }

    private static let thuAnh = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func chuoi(_ d: Date, bayGio: Date = Date()) -> String { phanLoai(d, bayGio: bayGio).chu() }
}

/// Nhãn mốc thời gian giữa các tin: "14:05" · "Hôm qua 14:05" · "Thứ Tư 14:05" · "5 thg 10, 14:05".
enum NhanMocCTW {
    static func chuoi(_ d: Date, bayGio: Date = Date(), lich: Calendar = .current) -> String {
        let gio = CTWDinhDang.gio(d)
        if lich.isDate(d, inSameDayAs: bayGio) { return gio }
        if let hq = lich.date(byAdding: .day, value: -1, to: bayGio), lich.isDate(d, inSameDayAs: hq) {
            return String(localized: "Yesterday \(gio)")
        }
        let ngay = lich.dateComponents([.day], from: lich.startOfDay(for: d), to: lich.startOfDay(for: bayGio)).day ?? 99
        if ngay < 7 { return CTWDinhDang.mau("EEEE").string(from: d) + " " + gio }
        let cungNam = lich.component(.year, from: d) == lich.component(.year, from: bayGio)
        return CTWDinhDang.mau(cungNam ? "MMMd" : "yMMMd").string(from: d) + ", " + gio
    }
}

// MARK: Cảm xúc

enum CamXucCTW {
    /// Thanh cảm xúc nhanh (nhấn giữ) — như Messenger.
    static let nhanh = ["❤️", "😂", "😮", "😢", "😡", "👍"]

    /// Đảo MỘT cảm xúc của tôi (máy chủ `POST /messages/:id/reactions` cũng tự đảo). Lạc quan; socket chốt số thật.
    static func dao(_ ds: [MessageReaction], emoji: String, toi: Int) -> [MessageReaction] {
        var kq = ds
        if let j = kq.firstIndex(where: { $0.emoji == emoji }) {
            let c = kq[j]
            let ids = c.userIds.contains(toi) ? c.userIds.filter { $0 != toi } : c.userIds + [toi]
            if ids.isEmpty { kq.remove(at: j) } else { kq[j] = MessageReaction(emoji: emoji, count: ids.count, userIds: ids) }
        } else {
            kq.append(MessageReaction(emoji: emoji, count: 1, userIds: [toi]))
        }
        return kq
    }

    static func cuaToi(_ ds: [MessageReaction], toi: Int?) -> Set<String> {
        guard let toi else { return [] }
        return Set(ds.filter { $0.userIds.contains(toi) }.map(\.emoji))
    }

    static func tong(_ ds: [MessageReaction]) -> Int { ds.reduce(0) { $0 + max($1.count, $1.userIds.count) } }

    /// Viên cảm xúc dưới bong bóng: tối đa 3 emoji nhiều nhất + tổng ("❤️😂 3").
    static func vien(_ ds: [MessageReaction]) -> (emoji: [String], tong: Int) {
        let top = ds.sorted { $0.count > $1.count }.prefix(3).map(\.emoji)
        return (top, tong(ds))
    }
}

// MARK: Trả lời (trích dẫn)

struct TrichDanCTW: Equatable {
    /// "Bạn" / tên người kia.
    var ten: String
    var chu: String
    var cuaToi: Bool

    /// Trích dẫn hiện TRÊN bong bóng trả lời (máy chủ gửi `parentMessage`).
    static func tu(_ p: MessageParent, toi: Int?, tenKia: String) -> TrichDanCTW {
        let cua = p.senderId != nil && p.senderId == toi
        let c = (p.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return TrichDanCTW(ten: cua ? String(localized: "You") : (p.senderName ?? tenKia),
                           chu: c.isEmpty ? String(localized: "Attachment") : c, cuaToi: cua)
    }

    /// Trích dẫn trên ô soạn khi đang trả lời một tin.
    static func tuTin(_ m: Message, toi: Int?, tenKia: String) -> TrichDanCTW {
        let cua = m.senderId == toi
        return TrichDanCTW(ten: cua ? String(localized: "You") : tenKia, chu: TomTatTinCTW.chu(m), cuaToi: cua)
    }

    /// Dòng tiêu đề trích dẫn: "Bạn đã trả lời Linh" / "Linh đã trả lời bạn"… (gọn: "Trả lời Linh").
    func nhanTraLoi(nguoiTraLoiLaToi: Bool, tenKia: String) -> String {
        switch (nguoiTraLoiLaToi, cuaToi) {
        case (true, true): return String(localized: "You replied to yourself")
        case (true, false): return String(localized: "You replied to \(tenKia)")
        case (false, true): return String(localized: "\(tenKia) replied to you")
        case (false, false): return String(localized: "\(tenKia) replied")
        }
    }
}

// MARK: Tóm tắt / emoji lớn / link

enum TomTatTinCTW {
    static func laGif(_ m: Message) -> Bool { m.mediaKind == "gif" && !(m.mediaUrl ?? "").isEmpty }
    static func laNhanDan(_ m: Message) -> Bool { m.mediaKind == "sticker" && !(m.mediaUrl ?? "").isEmpty }
    static func anhTep(_ m: Message) -> [MessageAttachment] { (m.attachments ?? []).filter { ($0.mimeType ?? "").hasPrefix("image/") } }
    static func amThanh(_ m: Message) -> [MessageAttachment] { (m.attachments ?? []).filter { ($0.mimeType ?? "").hasPrefix("audio/") } }
    static func tepKhac(_ m: Message) -> [MessageAttachment] {
        (m.attachments ?? []).filter { a in let t = a.mimeType ?? ""; return !t.hasPrefix("image/") && !t.hasPrefix("audio/") }
    }

    /// Dòng tóm tắt một tin (danh sách hội thoại, trích dẫn, chuyển tiếp).
    static func chu(_ m: Message) -> String {
        if m.daXoaHoacThuHoi { return String(localized: "Message unsent") }
        if let c = m.content?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { return c }
        if laGif(m) { return String(localized: "🎬 GIF") }
        if laNhanDan(m) { return String(localized: "🪄 Sticker") }
        if !amThanh(m).isEmpty { return String(localized: "🎤 Voice message") }
        if !anhTep(m).isEmpty || (m.hasAttachment ?? false) && tepKhac(m).isEmpty { return String(localized: "📷 Photo") }
        if !tepKhac(m).isEmpty { return String(localized: "📎 File") }
        return ""
    }
}

enum EmojiLonCTW {
    /// Chữ chỉ gồm 1–3 emoji (bỏ khoảng trắng) ⇒ vẽ to, không bong bóng (như Messenger).
    static func la(_ s: String?) -> Bool {
        guard let s else { return false }
        let ky = s.filter { !$0.isWhitespace }
        guard (1...3).contains(ky.count) else { return false }
        return ky.allSatisfy(laEmoji)
    }

    static func laEmoji(_ c: Character) -> Bool {
        guard let dau = c.unicodeScalars.first else { return false }
        // Chữ số / # / * có thuộc tính isEmoji nhưng KHÔNG phải emoji khi đứng một mình.
        if dau.properties.isEmojiPresentation { return true }
        return dau.properties.isEmoji && c.unicodeScalars.count > 1 && !("0"..."9").contains(String(dau)) && dau != "#" && dau != "*"
    }
}

enum LienKetCTW {
    private static let boDo = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// Link http(s) trong chữ (theo thứ tự xuất hiện).
    static func urls(_ s: String) -> [URL] {
        guard let boDo else { return [] }
        return boDo.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { m in
            guard let u = m.url, ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { return nil }
            return u
        }
    }

    /// Chữ có link bấm được (gạch chân) — giữ nguyên mọi ký tự, KHÔNG đọc markdown (tin nhắn là chữ thô).
    static func coLink(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        guard let boDo else { return a }
        for m in boDo.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let u = m.url, ["http", "https", "mailto"].contains(u.scheme?.lowercased() ?? ""),
                  let r = Range(m.range, in: s), let ar = Range(r, in: a) else { continue }
            a[ar].link = u
            a[ar].underlineStyle = .single
        }
        return a
    }
}

// MARK: GIF

/// Một GIF của proxy `GET /api/v1/gifs` (gifs.routes.ts › mapGif).
struct CTWGif: Codable, Hashable, Identifiable {
    var id: String
    var url: String
    var previewUrl: String
}

/// Nhãn dán: `GET /api/v1/stickers/packs` + `/packs/:id/stickers` (sticker.service.ts).
struct CTWGoiNhanDan: Codable, Hashable, Identifiable {
    var id: Int
    var slug: String?
    var name: String?
    var coverUrl: String?
    var stickerCount: Int?
}

struct CTWNhanDan: Codable, Hashable, Identifiable {
    var id: Int
    var packId: Int?
    var url: String
    var label: String?
}

/// Trạng thái phân trang GIF (thuần). Máy chủ trả mảng ≤ 24 mục / trang.
struct TrangGifCTW: Equatable {
    static let kichTrang = 24
    var ds: [CTWGif] = []
    /// `offset` cho lượt gọi KẾ TIẾP.
    var offset = 0
    var het = false

    /// Ghép một trang vừa về. Máy chủ chưa có `offset` trả lại trang đầu ⇒ không có mục mới ⇒ dừng.
    mutating func ghep(_ trang: [CTWGif]) {
        let co = Set(ds.map(\.id))
        let moi = trang.filter { !co.contains($0.id) }
        ds += moi
        offset += Self.kichTrang
        het = trang.count < Self.kichTrang || moi.isEmpty
    }

    /// Đường của lượt gọi (q rỗng ⇒ thịnh hành). Query tự mã hoá (đi `.tuyChinh`).
    static func duong(q: String, offset: Int) -> String {
        var c = URLComponents()
        var muc: [URLQueryItem] = []
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { muc.append(URLQueryItem(name: "q", value: String(t.prefix(100)))) }
        if offset > 0 { muc.append(URLQueryItem(name: "offset", value: String(offset))) }
        c.queryItems = muc.isEmpty ? nil : muc
        return "/api/v1/gifs" + (c.percentEncodedQuery.map { "?" + $0 } ?? "")
    }
}

// MARK: Thân yêu cầu (hồ sơ, gửi, chuyển tiếp)

enum HoSoAPICTW {
    /// `PUT /profile` — CÙNG trường web (/settings/profile) và app chính (Chỉnh sửa hồ sơ) dùng ⇒ đổi ở đâu cũng đồng bộ.
    static func thanAnhDaiDien(_ url: String) -> [String: Any] { ["avatarUrl": url] }
    static func thanAnhBia(_ url: String?) -> [String: Any] { ["coverPhotoUrl": url as Any? ?? NSNull()] }

    /// Tên hiển thị + giới thiệu. Rỗng ⇒ `NSNull` (xoá) — máy chủ hiểu `null` là xoá, vắng khoá là giữ nguyên.
    static func thanSua(ten: String, gioiThieu: String) -> [String: Any] {
        func chu(_ s: String) -> Any { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? NSNull() : t }
        return ["displayName": chu(ten), "bio": chu(gioiThieu)]
    }

    /// Thư mục tải lên của `POST /files/upload` (upload.routes.ts › resolveCategory): avatars ⇒ images/avatar.
    static let thuMucAnhDaiDien = "avatars"
    static let thuMucAnhBia = "covers"

    /// Đường hồ sơ công khai trên web (cùng link "Xem trang cá nhân" của web Messenger).
    static func linkHoSo(_ id: Int) -> URL { URL(string: "https://cuongthai.com/profile/\(id)")! }
}

enum ChuyenTiepCTW {
    /// Gửi lại đúng nội dung (như `ChuyenTiepModal.tsx` của web): chữ, GIF/nhãn dán (`media`), tệp đã có (`fileIds`).
    static func than(_ m: Message) -> [String: Any] {
        var t: [String: Any] = ["content": m.content ?? ""]
        let ids = (m.attachments ?? []).compactMap(\.fileId)
        if !ids.isEmpty { t["fileIds"] = ids }
        if let u = m.mediaUrl, !u.isEmpty, let k = m.mediaKind, k == "gif" || k == "sticker" { t["media"] = ["url": u, "kind": k] }
        return t
    }

    static func duocChuyen(_ m: Message) -> Bool { !m.daXoaHoacThuHoi && m.id > 0 }
}

enum GuiMediaCTW {
    /// `POST /threads/:id/messages {content:"", media:{url,kind}, parentMessageId?}` — GIF/nhãn dán như web MessageInput.
    static func than(url: String, kieu: String, traLoi: Int?) -> [String: Any] {
        var t: [String: Any] = ["content": "", "media": ["url": url, "kind": kieu]]
        if let traLoi { t["parentMessageId"] = traLoi }
        return t
    }
}

/// Tắt thông báo hội thoại — đúng các mức `POST /threads/:id/mute-for` nhận (messages.routes.ts).
enum TatThongBaoCTW: CaseIterable, Identifiable {
    case m15, h1, h8, h24, maiMai
    var id: String { "\(self)" }
    var phut: Int? {
        switch self { case .m15: return 15; case .h1: return 60; case .h8: return 480; case .h24: return 1440; case .maiMai: return nil }
    }
    var nhan: String {
        switch self {
        case .m15: return String(localized: "For 15 minutes")
        case .h1: return String(localized: "For 1 hour")
        case .h8: return String(localized: "For 8 hours")
        case .h24: return String(localized: "For 24 hours")
        case .maiMai: return String(localized: "Until I turn it back on")
        }
    }
    static func than(_ phut: Int?) -> [String: Any] { ["durationMinutes": phut as Any? ?? NSNull()] }
}

/// Sắp danh sách hội thoại: GHIM lên đầu (ghim mới nhất trước), rồi theo tin mới nhất.
enum SapHoiThoaiCTW {
    static func sap(_ ds: [MessageThread]) -> [MessageThread] {
        ds.sorted { a, b in
            let (ga, gb) = (a.preferences?.pinnedAt, b.preferences?.pinnedAt)
            if (ga != nil) != (gb != nil) { return ga != nil }
            if let ga, let gb, ga != gb { return ga > gb }
            return (a.lastMessage?.createdAt ?? a.updatedAt ?? "") > (b.lastMessage?.createdAt ?? b.updatedAt ?? "")
        }
    }
}

// MARK: Cắt ảnh (ảnh đại diện vuông, ảnh bìa ngang)

enum CatAnhCTW {
    /// Tỉ lệ nhỏ nhất để ảnh PHỦ kín khung.
    static func tiLePhu(anh: CGSize, khung: CGSize) -> CGFloat {
        guard anh.width > 0, anh.height > 0 else { return 1 }
        return max(khung.width / anh.width, khung.height / anh.height)
    }

    /// Kéo không được để lộ nền: giới hạn độ lệch theo cỡ ảnh đã phóng.
    static func gioiHan(lech: CGSize, anh: CGSize, tiLe: CGFloat, khung: CGSize) -> CGSize {
        let w = anh.width * tiLe, h = anh.height * tiLe
        let mx = max(0, (w - khung.width) / 2), my = max(0, (h - khung.height) / 2)
        return CGSize(width: min(mx, max(-mx, lech.width)), height: min(my, max(-my, lech.height)))
    }

    /// Vùng cắt trong TOẠ ĐỘ ẢNH GỐC (điểm ảnh) cho khung giữa màn: ảnh vẽ phóng `tiLe`, tâm lệch `lech` so với tâm khung.
    static func vungCat(anh: CGSize, tiLe: CGFloat, lech: CGSize, khung: CGSize) -> CGRect {
        let w = khung.width / tiLe, h = khung.height / tiLe
        let tamX = anh.width / 2 - lech.width / tiLe
        let tamY = anh.height / 2 - lech.height / tiLe
        var r = CGRect(x: tamX - w / 2, y: tamY - h / 2, width: w, height: h)
        r.origin.x = min(max(0, r.origin.x), max(0, anh.width - w))
        r.origin.y = min(max(0, r.origin.y), max(0, anh.height - h))
        return r.integral
    }

    /// Cạnh dài ảnh xuất (điểm ảnh): đại diện 1024 vuông, bìa 1600 ngang — đủ nét, nhẹ cho `POST /files/upload`.
    static func coXuat(tiLeKhung: CGFloat) -> CGSize {
        tiLeKhung >= 1.01 ? CGSize(width: 1600, height: (1600 / tiLeKhung).rounded()) : CGSize(width: 1024, height: 1024)
    }
}
