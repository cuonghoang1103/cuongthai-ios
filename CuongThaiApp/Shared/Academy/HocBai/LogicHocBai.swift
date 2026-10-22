import Foundation

// ════════════════════════════════════════════════════════════════
// LOGIC THUẦN CỦA MÀN HỌC ACADEMY (22/10/2026)
//
// Tách khỏi View để KIỂM được bằng XCTest (`CuongThaiAppTests`): chọn luồng
// video, rút slide khỏi HTML, tách tiêu đề song ngữ, nhịp lưu tiến độ. Mỗi thứ
// ở đây đều là chỗ đã từng (hoặc dễ) hỏng câm trên màn hình:
//   · trình phát chỉ giữ track YouTube ⇒ bài chỉ có video R2 báo "chưa có video";
//   · đọc track từ MỤC LỤC (URL bị giấu) thay vì từ bài ĐẦY ĐỦ (URL đã ký);
//   · tiêu đề "EN|||VI" theo ngôn ngữ MÁY thay vì ngôn ngữ APP.
// ════════════════════════════════════════════════════════════════

// MARK: - Tiêu đề song ngữ "EN|||VI"

enum SongNgu {
    /// App đang chạy tiếng Việt? Đọc đúng khoá của `QuanLyNgonNguApp` (mặc định Việt).
    static var appTiengViet: Bool {
        (UserDefaults.standard.string(forKey: "app.ngonNgu") ?? "vi") != "en"
    }

    /// Bản chép `pickLang` của web (`lib/utils.ts`): vế TRƯỚC `|||` là tiếng
    /// Anh, vế SAU là tiếng Việt; vế cần dùng rỗng thì lùi về vế kia.
    /// Trả kèm vế còn lại (để hiện mờ bên dưới) — `nil` khi không song ngữ
    /// hoặc hai vế trùng nhau.
    static func tach(_ s: String, tiengViet: Bool = SongNgu.appTiengViet) -> (chinh: String, phu: String?) {
        guard let r = s.range(of: "|||") else {
            return (s.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let en = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let vi = String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let chinh = tiengViet ? (vi.isEmpty ? en : vi) : (en.isEmpty ? vi : en)
        let phu = tiengViet ? en : vi
        return (chinh, (phu.isEmpty || phu == chinh) ? nil : phu)
    }
}

extension String {
    /// Vế theo ngôn ngữ APP (không theo ngôn ngữ máy như `songNguTheoMay`).
    var theoApp: String { SongNgu.tach(self).chinh }
    /// Vế còn lại, hoặc `nil`.
    var veKiaTheoApp: String? { SongNgu.tach(self).phu }
}

// MARK: - Loại chương / loại bài

enum LoaiChuong: Equatable {
    case thuong
    /// "⭐ Chuyên sâu — Ngoài giáo trình…" / "⭐ Advanced — …" — phần tự soạn vượt slide trường.
    case chuyenSau
    /// "Final Exam", "Progress Test", "Thi cuối kỳ", "Bài kiểm tra tiến độ".
    case thi
    /// "📝 Ôn thi PE — làm đề thật từng câu".
    case onThi

    static func cua(_ tieuDe: String) -> LoaiChuong {
        let t = tieuDe.trimmingCharacters(in: .whitespaces)
        let thuong = t.lowercased()
        if t.hasPrefix("⭐") || t.contains("|||⭐") || thuong.contains("chuyên sâu") { return .chuyenSau }
        if t.hasPrefix("📝") || thuong.contains("ôn thi") || thuong.contains("pe review") { return .onThi }
        if thuong.hasPrefix("final exam") || thuong.hasPrefix("progress test")
            || thuong.contains("thi cuối kỳ") || thuong.contains("kiểm tra tiến độ") { return .thi }
        return .thuong
    }
}

/// Bốn loại bài backend đang dùng (`lessonType`) + mọi loại mới về sau (rơi về VIDEO-ish).
enum LoaiBai: String {
    case video = "VIDEO", quiz = "QUIZ", baiTap = "EXERCISE", dapAn = "SOLUTION", taiLieu = "DOCUMENT", khac

    init(_ raw: String?) { self = LoaiBai(rawValue: (raw ?? "VIDEO").uppercased()) ?? .khac }

    var nhan: String {
        switch self {
        case .video: return "Video"
        case .quiz: return "Kiểm tra"
        case .baiTap: return "Bài tập"
        case .dapAn: return "Đáp án"
        case .taiLieu: return "Tài liệu"
        case .khac: return "Bài học"
        }
    }

    var bieuTuong: String {
        switch self {
        case .video: return "play.circle.fill"
        case .quiz: return "checklist"
        case .baiTap: return "pencil.and.list.clipboard"
        case .dapAn: return "checkmark.seal"
        case .taiLieu: return "doc.richtext"
        case .khac: return "book"
        }
    }
}

extension CourseLesson {
    var loai: LoaiBai { LoaiBai(lessonType) }
}

// MARK: - Luồng video VI / EN / YT

/// Một ô trong bộ chọn luồng — LUÔN đủ ba ô theo thứ tự web (`VIDEO_TRACK_ORDER`),
/// ô nào chưa thu thì hiện "Sắp có" thay vì biến mất.
struct OLuongVideo: Equatable, Identifiable {
    enum TrangThai: Equatable {
        /// Có URL phát được ngay (R2 đã ký, hoặc YouTube).
        case phatDuoc
        /// Có video nhưng URL đang bị giấu (mục lục) — chờ bài đầy đủ trả URL ký.
        case dangTai
        /// Bài không có luồng này.
        case khongCo
    }

    let track: String
    let url: String?
    /// DIRECT | EMBED
    let platform: String?
    let credit: String?
    let trangThai: TrangThai

    var id: String { track }
    var coVideo: Bool { trangThai != .khongCo }
    var laYouTube: Bool { trangThai == .phatDuoc && maVideoYouTube(url) != nil }
    /// File riêng (R2/mp4) phát bằng AVPlayer.
    var laFileRieng: Bool {
        guard trangThai == .phatDuoc, let url, !laYouTube else { return false }
        return (platform ?? "").uppercased() == "DIRECT"
            || url.range(of: #"\.(mp4|m4v|mov|webm|m3u8)(\?|$)"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    var nhanNgan: String {
        switch track {
        case "VI": return "VN"
        case "EN": return "EN"
        case "YT": return "YT"
        default: return track
        }
    }

    var nhanDai: String {
        switch track {
        case "VI": return "Tiếng Việt"
        case "EN": return "English"
        case "YT": return "YouTube"
        default: return track
        }
    }
}

enum ChonLuong {
    static let thuTu = ["VI", "EN", "YT"]
    /// Lựa chọn "dính" của người học (web: `localStorage` `TRACK_PREF_KEY`).
    static let khoaUaThich = "academy.luongVideo"

    /// Dựng ba ô từ track của bài ĐẦY ĐỦ (ưu tiên — URL đã ký) hoặc của mục lục.
    ///
    /// - `dayDu`: `videoTracks` của `GET /courses/:id/lessons/:id`. `nil` = chưa tải xong / hỏng.
    /// - `mucLuc`: `videoTracks` của gói khoá (R2 bị giấu: `url: null, locked: true`).
    /// - `videoUrlCu`: bài cũ chỉ có cột `videoUrl` (chưa tách track).
    static func dsO(dayDu: [VideoTrack]?, mucLuc: [VideoTrack]?, videoUrlCu: String? = nil,
                    nenTangCu: String? = nil) -> [OLuongVideo] {
        var nguon = (dayDu?.isEmpty == false ? dayDu : nil) ?? mucLuc ?? []
        if nguon.isEmpty, let u = videoUrlCu, !u.isEmpty {
            let yt = maVideoYouTube(u) != nil
            nguon = [VideoTrack(track: yt ? "YT" : "VI", url: u,
                                platform: yt ? "EMBED" : (nenTangCu ?? "DIRECT"), credit: nil, locked: nil)]
        }
        return thuTu.map { k in
            guard let t = nguon.first(where: { $0.track.uppercased() == k }) else {
                return OLuongVideo(track: k, url: nil, platform: nil, credit: nil, trangThai: .khongCo)
            }
            let url = t.url?.trimmingCharacters(in: .whitespacesAndNewlines)
            let co = (url?.isEmpty == false)
            return OLuongVideo(track: k, url: co ? url : nil, platform: t.platform, credit: t.credit,
                               trangThai: co ? .phatDuoc : .dangTai)
        }
    }

    /// Luồng mở ra: chọn tay → ưa thích dính → `defaultVideoTrack` → luồng đầu có video.
    /// Đúng thứ tự `activeTrack` của `LearnPageClient.tsx`. Chỉ chọn trong những ô CÓ video.
    static func chon(_ ds: [OLuongVideo], dangChon: String?, uaThich: String?, macDinh: String?) -> OLuongVideo? {
        let co = ds.filter(\.coVideo)
        for k in [dangChon, uaThich, macDinh] {
            if let k, let o = co.first(where: { $0.track == k.uppercased() }) { return o }
        }
        return co.first(where: { $0.trangThai == .phatDuoc }) ?? co.first
    }
}

// MARK: - Slide trong nội dung bài

/// Một slide nằm sẵn trong HTML bài học:
///
///     <div class="anh-slide"><img src="…/DBI202/v1/cs1/001.webp" alt="⭐ CS1 slide 1: …" …/>
///       <p class="chu-thich">📑 <strong>⭐ CS1</strong> · slide 1/25 — Lịch sử và hệ sinh thái CSDL</p></div>
struct SlideBai: Equatable, Identifiable, Hashable {
    /// Thứ tự trong bài (0-based) — khớp thứ tự ảnh `.anh-slide img` trong DOM.
    let viTri: Int
    let anh: String
    /// Tên bộ slide (`SWT0`, `⭐ CS1`). Một bài có thể ghép nhiều bộ.
    let bo: String
    let so: Int
    let tong: Int
    let ten: String

    var id: String { "\(bo)#\(so)#\(viTri)" }

    /// "⭐ CS1 · 1/25"
    var nhanSo: String { tong > 0 ? "\(bo) · \(so)/\(tong)" : "\(bo) · \(so)" }

    /// Câu hỏi gửi gia sư — chép từng chữ `cauHoiSlide` của web để dùng CHUNG
    /// cache câu trả lời (`slide:<bộ>:<số>`) với người học trên web.
    var cauHoi: String {
        let t = ten.isEmpty ? "" : " (“\(ten)”)"
        let tg = tong > 0 ? "/\(tong)" : ""
        return "Giảng kỹ slide \(so)\(tg) của bộ \(bo)\(t) trong bài này: "
            + "ý chính là gì, vì sao nó quan trọng, và một ví dụ dễ hiểu."
    }

    /// Bản chép `khoaCacheSlide` — trần 40 ký tự (máy chủ cắt `cacheKey` ở 40).
    var khoaCache: String { String("slide:\(bo):\(so)".prefix(40)) }
}

enum DocSlide {
    private static let khoi = try! NSRegularExpression(
        pattern: #"<div[^>]*class="[^"]*\banh-slide\b[^"]*"[^>]*>\s*(<img[^>]*>)\s*(?:<p[^>]*class="[^"]*\bchu-thich\b[^"]*"[^>]*>([\s\S]*?)</p>)?"#,
        options: [.caseInsensitive])
    private static let src = try! NSRegularExpression(pattern: #"\bsrc="([^"]+)""#, options: [.caseInsensitive])
    private static let alt = try! NSRegularExpression(pattern: #"\balt="([^"]*)""#, options: [.caseInsensitive])
    private static let strong = try! NSRegularExpression(pattern: #"<strong>([^<]+)</strong>"#, options: [.caseInsensitive])
    private static let soTong = try! NSRegularExpression(
        pattern: #"slide\s+(\d+)\s*(?:/\s*(\d+))?\s*(?:—|–|-|:)?\s*(.*)$"#, options: [.caseInsensitive])

    /// Rút mọi slide theo đúng thứ tự xuất hiện. Bài không có slide ⇒ mảng rỗng
    /// (chỗ gọi dựa vào đó để ẩn hẳn khối trình chiếu + mục "hỏi theo slide").
    static func tu(_ html: String?) -> [SlideBai] {
        guard let html, html.contains("anh-slide") else { return [] }
        let ns = html as NSString
        var ra: [SlideBai] = []
        for m in khoi.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let the = ns.substring(with: m.range(at: 1))
            guard let anh = nhom(src, the).map(giaiMa), !anh.isEmpty else { continue }
            let chuThich = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : ""
            var bo = nhom(strong, chuThich).map(giaiMa) ?? ""
            var so = 0, tong = 0, ten = ""
            let tron = giaiMa(lotThe(chuThich))
            if let (s, t, n) = docSoTong(tron) { so = s; tong = t; ten = n }
            if so == 0, let a = nhom(alt, the).map(giaiMa) {
                // Đường lùi: alt="SWT0 slide 2: ISTQB"
                if let r = a.range(of: " slide ", options: .caseInsensitive) {
                    if bo.isEmpty { bo = String(a[..<r.lowerBound]).trimmingCharacters(in: .whitespaces) }
                    if let (s, t, n) = docSoTong(String(a[r.lowerBound...])) { so = s; tong = t; if ten.isEmpty { ten = n } }
                }
            }
            if so == 0 { so = ra.count + 1 }
            if bo.isEmpty { bo = "Slide" }
            ra.append(SlideBai(viTri: ra.count, anh: anh, bo: bo, so: so, tong: tong, ten: ten))
        }
        return ra
    }

    private static func docSoTong(_ s: String) -> (Int, Int, String)? {
        let ns = s as NSString
        guard let m = soTong.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let so = Int(ns.substring(with: m.range(at: 1))) ?? 0
        let tong = m.range(at: 2).location != NSNotFound ? (Int(ns.substring(with: m.range(at: 2))) ?? 0) : 0
        let ten = m.range(at: 3).location != NSNotFound
            ? ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return so > 0 ? (so, tong, ten) : nil
    }

    private static func nhom(_ re: NSRegularExpression, _ s: String) -> String? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func lotThe(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    static func giaiMa(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Nhịp lưu tiến độ xem video

/// Quyết định KHI NÀO gửi `POST /courses/:id/progress` trong lúc xem.
///
/// Web lưu mỗi 12 giây + khi dừng + khi rời bài. App: mỗi `chuKy` giây (15),
/// và BẮT BUỘC khi dừng/rời bài/vào nền (`ep`). Không gửi khi mốc chưa đổi đáng
/// kể (< 2 giây) — tua qua lại trên một chỗ không đáng một lượt mạng.
struct NhipLuuTienDo {
    var chuKy: TimeInterval = 15
    private(set) var lanCuoi: TimeInterval?
    private(set) var mocDaLuu: Int?

    init(chuKy: TimeInterval = 15) { self.chuKy = chuKy }

    /// - Returns: `true` nếu nên lưu NGAY mốc `giay` (và đã ghi nhận là đã lưu).
    mutating func nenLuu(giay: Double, bayGio: TimeInterval, ep: Bool = false) -> Bool {
        guard giay.isFinite, giay >= 1 else { return false }
        let moc = Int(giay.rounded())
        if let cu = mocDaLuu, abs(cu - moc) < 2 { return false }
        if !ep, let t = lanCuoi, bayGio - t < chuKy { return false }
        lanCuoi = bayGio
        mocDaLuu = moc
        return true
    }

    mutating func datLai() { lanCuoi = nil; mocDaLuu = nil }
}

enum TienDoXem {
    /// Đã xem tới ≥ 90% ⇒ coi như xong bài (web đánh dấu khi `ended`; app thêm
    /// mốc 90% vì người học hay tắt video ở đoạn chào cuối).
    static let nguongXong = 0.9

    static func duXong(giay: Double, thoiLuong: Double) -> Bool {
        guard thoiLuong > 30, giay.isFinite else { return false }
        return giay / thoiLuong >= nguongXong
    }

    /// Mở lại từ đâu: chỉ khi bài CHƯA xong, mốc > 5 giây và còn > 10 giây nữa mới hết
    /// (đúng như web: bài đã xong xem lại thì từ đầu).
    static func mocMoLai(_ p: LessonProgress?, thoiLuong: Double?) -> Double {
        guard let p, !p.isCompleted, let moc = p.lastPositionSeconds, moc > 5 else { return 0 }
        if let d = thoiLuong, d > 0, Double(moc) > d - 10 { return 0 }
        return Double(moc)
    }

    /// "1:02:05" / "12:05"
    static func dongHo(_ giay: Double) -> String {
        guard giay.isFinite, giay >= 0 else { return "0:00" }
        let s = Int(giay)
        let h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }
}

// MARK: - Cây bài của khoá

enum CayBai {
    /// Mọi bài theo đúng thứ tự học.
    static func phang(_ chuong: [CourseSection]) -> [CourseLesson] {
        chuong.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            .flatMap { ($0.lessons ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) } }
    }

    /// "Tiếp tục học": bài ĐẦU TIÊN chưa xong mà mở được, sau bài đã xong cuối cùng
    /// nếu có (người học bỏ qua vài bài đầu thì vẫn đưa về chỗ đang học dở).
    static func baiTiep(_ chuong: [CourseSection], daXong: Set<Int>, moDuoc: (CourseLesson) -> Bool) -> CourseLesson? {
        let ds = phang(chuong)
        guard !ds.isEmpty else { return nil }
        let sauCung = ds.lastIndex { daXong.contains($0.id) }
        if let i = sauCung, let b = ds[(i + 1)...].first(where: { !daXong.contains($0.id) && moDuoc($0) }) {
            return b
        }
        return ds.first { !daXong.contains($0.id) && moDuoc($0) } ?? ds.first(where: moDuoc)
    }
}
