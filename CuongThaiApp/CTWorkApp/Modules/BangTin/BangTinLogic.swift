import Foundation

// MARK: - Bảng tin — logic THUẦN (không giao diện, không mạng) — có kiểm thử ở `CTWorkTests/BangTinCTWTests.swift`
//
//   · `CamXucLogic`   — thả/đổi/bỏ cảm xúc lạc quan (một người một cảm xúc; thả loại khác ⇒ đổi)
//   · `TrangBangTin`  — gộp trang theo con trỏ (chống trùng), chèn/thay bài TẠM khi đăng (clientKey)
//   · `BoCucAnh`      — chọn bố cục lưới ảnh 1 / 2 / 3 / 4+ ("+N")
//   · `DichBangTin`   — tách đường dẫn sâu `/work/<ws>/feed?post=<id>&comment=<cid>`
//   · `ChuBangTin`    — tìm @nhắc (chỉ người có trong `mentions`), #hashtag, link, `/work/…`, mã thẻ trần
//   · `NhacDangGo`    — chữ @… đang gõ ở cuối ô soạn ⇒ gợi ý ⇒ chèn

// MARK: Cảm xúc

struct TrangThaiCamXuc: Equatable {
    var tong: Int
    var ds: [CTWFeedDemCamXuc]
    var cuaToi: String?

    init(tong: Int, ds: [CTWFeedDemCamXuc], cuaToi: String?) {
        self.tong = tong; self.ds = ds; self.cuaToi = cuaToi
    }
    init(_ p: CTWFeedPost) { self.init(tong: p.reactionCount ?? 0, ds: p.reactions ?? [], cuaToi: p.myReaction) }
    init(_ c: CTWFeedComment) { self.init(tong: c.reactionCount ?? 0, ds: c.reactions ?? [], cuaToi: c.myReaction) }
}

enum CamXucLogic {
    /// Chạm nút Thích: chưa thả gì ⇒ `like`; đã thả (bất kỳ loại nào) ⇒ bỏ (nil) — như Facebook/LinkedIn.
    static func khiCham(_ s: TrangThaiCamXuc) -> CamXucBangTin? {
        s.cuaToi == nil ? .like : nil
    }

    /// Áp lạc quan việc chọn `k` (nil = bỏ). Chọn đúng loại đang có ⇒ bỏ. Danh sách xếp GIẢM DẦN theo số (như máy chủ),
    /// loại về 0 thì rơi khỏi danh sách.
    static func ap(_ s: TrangThaiCamXuc, chon k: CamXucBangTin?) -> TrangThaiCamXuc {
        var ds = s.ds
        var tong = s.tong
        let cu = s.cuaToi
        let moi: String? = (k?.rawValue == cu) ? nil : k?.rawValue
        if let cu, let i = ds.firstIndex(where: { $0.kind == cu }) {
            let n = (ds[i].count ?? 1) - 1
            if n <= 0 { ds.remove(at: i) } else { ds[i].count = n }
            tong -= 1
        }
        if let moi {
            if let i = ds.firstIndex(where: { $0.kind == moi }) { ds[i].count = (ds[i].count ?? 0) + 1 }
            else { ds.append(CTWFeedDemCamXuc(kind: moi, count: 1)) }
            tong += 1
        }
        let thuTu = CamXucBangTin.allCases.map(\.rawValue)
        ds.sort { a, b in
            let (x, y) = (a.count ?? 0, b.count ?? 0)
            if x != y { return x > y }
            return (thuTu.firstIndex(of: a.kind) ?? 9) < (thuTu.firstIndex(of: b.kind) ?? 9)
        }
        return TrangThaiCamXuc(tong: max(0, tong), ds: ds, cuaToi: moi)
    }

    /// Ba emoji đứng đầu (dải tóm tắt "👍❤️🎉 12").
    static func baDau(_ s: TrangThaiCamXuc) -> [CamXucBangTin] {
        s.ds.filter { ($0.count ?? 0) > 0 }.compactMap { CamXucBangTin(rawValue: $0.kind) }.prefix(3).map { $0 }
    }
}

extension CTWFeedPost {
    func voi(_ s: TrangThaiCamXuc) -> CTWFeedPost {
        var p = self
        p.reactionCount = s.tong; p.reactions = s.ds; p.myReaction = s.cuaToi
        return p
    }
}

extension CTWFeedComment {
    func voi(_ s: TrangThaiCamXuc) -> CTWFeedComment {
        var c = self
        c.reactionCount = s.tong; c.reactions = s.ds; c.myReaction = s.cuaToi
        return c
    }
}

// MARK: Trang + chèn lạc quan

enum TrangBangTin {
    /// Nối trang sau (con trỏ) vào danh sách: bài đã có ⇒ cập nhật TẠI CHỖ (giữ vị trí), bài mới ⇒ thêm cuối.
    /// Máy chủ xếp `createdAt desc, id desc` nhưng bài mới chen vào giữa hai lần tải làm trang sau lặp bài cuối trang trước.
    static func noi(_ cu: [CTWFeedPost], _ moi: [CTWFeedPost]) -> [CTWFeedPost] {
        var kq = cu
        var viTri: [Int: Int] = [:]
        for (i, p) in kq.enumerated() where !p.laTam { viTri[p.id] = i }
        for p in moi {
            if let i = viTri[p.id] { kq[i] = p } else { viTri[p.id] = kq.count; kq.append(p) }
        }
        return kq
    }

    /// Tải lại trang đầu: giữ bài TẠM (đang đăng / đăng hỏng) ở đầu, bỏ bài thật đã có trong trang mới; bài tạm mà
    /// trang mới đã chứa bài thật cùng nội dung KHÔNG đoán được ⇒ giữ tạm (VM thay khi `POST` trả về).
    static func lamMoi(_ cu: [CTWFeedPost], dau moi: [CTWFeedPost]) -> [CTWFeedPost] {
        let tam = cu.filter(\.laTam)
        return tam + noi([], moi)
    }

    /// Chèn bài tạm lên đầu (đăng lạc quan).
    static func chenTam(_ ds: [CTWFeedPost], _ tam: CTWFeedPost) -> [CTWFeedPost] {
        [tam] + ds.filter { $0.khoaTam != tam.khoaTam }
    }

    /// `POST` trả bài thật ⇒ thay bài tạm cùng `khoa` ĐÚNG CHỖ; nếu bài thật đã lọt vào danh sách trước (socket ⇒ tải lại)
    /// thì bỏ bản trùng. Không còn bài tạm (người dùng đã kéo làm mới…) ⇒ chèn bài thật lên đầu nếu chưa có.
    static func thayTam(_ ds: [CTWFeedPost], khoa: String, bang that: CTWFeedPost) -> [CTWFeedPost] {
        var kq = ds.filter { $0.laTam || $0.id != that.id }
        if let i = kq.firstIndex(where: { $0.khoaTam == khoa }) { kq[i] = that } else { kq.insert(that, at: 0) }
        return kq
    }

    static func danhDauHong(_ ds: [CTWFeedPost], khoa: String, hong: Bool = true) -> [CTWFeedPost] {
        ds.map { p in
            guard p.khoaTam == khoa else { return p }
            var q = p; q.dangHong = hong; return q
        }
    }

    static func boTam(_ ds: [CTWFeedPost], khoa: String) -> [CTWFeedPost] { ds.filter { $0.khoaTam != khoa } }

    /// `clientKey` ≤ 40 ký tự (hợp đồng §4).
    static func khoaMoi() -> String { "ios-" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(32) }

    /// Bài tạm hiện ngay khi bấm Đăng (id âm để không đụng id thật).
    static func baiTam(khoa: String, toi: CTWUser?, chu: String, ws: CTWFeedWorkspace?, duAn: CTWFeedProject?,
                       dinhKem: [CTWFeedAttachment], bayGio: Date = Date()) -> CTWFeedPost {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var p = CTWFeedPost(id: -abs(khoa.hashValue % 1_000_000_000) - 1)
        p.workspace = ws; p.project = duAn; p.author = toi; p.body = chu; p.attachments = dinhKem
        p.createdAt = f.string(from: bayGio); p.reactionCount = 0; p.commentCount = 0
        p.can = CTWFeedQuyen(edit: false, delete: false, pin: false, moderate: false, comment: false, react: false, report: false)
        p.khoaTam = khoa
        return p
    }

    /// Ẩn ở máy những bài không được hiện cho người xem: tác giả đã bị chặn (chặn vừa bấm — máy chủ lọc ở lần tải sau).
    static func loc(_ ds: [CTWFeedPost], daChan: Set<Int>, daAn: Set<Int>) -> [CTWFeedPost] {
        ds.filter { p in !daAn.contains(p.id) && !(p.author.map { daChan.contains($0.id) } ?? false) }
    }
}

// MARK: Bố cục lưới ảnh

enum BoCucAnh: Equatable {
    /// Một ảnh/video: khung theo tỉ lệ thật, kẹp 4:5 (dọc) … 1,91:1 (ngang) như Instagram/LinkedIn.
    case mot(tiLe: Double)
    case hai
    /// Một lớn bên trái + hai nhỏ xếp dọc bên phải.
    case ba
    /// Lưới 2×2; ô thứ tư phủ "+N" khi còn `thua` ảnh.
    case bon(thua: Int)

    static func chon(_ ds: [CTWFeedAttachment]) -> BoCucAnh? {
        switch ds.count {
        case 0: return nil
        case 1: return .mot(tiLe: kep(ds[0].tiLe ?? (ds[0].laVideo ? 16.0 / 9 : 4.0 / 3)))
        case 2: return .hai
        case 3: return .ba
        default: return .bon(thua: ds.count - 4)
        }
    }

    static func kep(_ r: Double) -> Double { min(1.91, max(0.8, r)) }

    /// Số ô hiện (≤ 4).
    var soO: Int {
        switch self {
        case .mot: return 1
        case .hai: return 2
        case .ba: return 3
        case .bon: return 4
        }
    }
}

// MARK: Đường dẫn sâu

/// `/work/<wsSlug>/feed?post=<id>` (+ `&comment=<cid>`) — dùng cho MỌI bài, cả bài dự án (hợp đồng §9).
struct DichBangTin: Equatable, Hashable {
    var slug: String
    var post: Int
    var comment: Int?

    static func tach(_ s: String) -> DichBangTin? {
        var chu = s
        if let r = chu.range(of: "://") {
            let sau = chu[r.upperBound...]
            if let gach = sau.firstIndex(of: "/") { chu = String(sau[gach...]) } else { return nil }
        }
        if let h = chu.firstIndex(of: "#") { chu = String(chu[..<h]) }
        let hai = chu.split(separator: "?", maxSplits: 1).map(String.init)
        guard hai.count == 2 else { return nil }
        let p = hai[0].split(separator: "/").map(String.init)
        guard p.count == 3, p[0] == "work", p[2] == "feed", !p[1].isEmpty else { return nil }
        var tham: [String: String] = [:]
        for cap in hai[1].split(separator: "&") {
            let kv = cap.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { tham[kv[0]] = kv[1] }
        }
        guard let post = tham["post"].flatMap(Int.init), post > 0 else { return nil }
        return DichBangTin(slug: p[1].removingPercentEncoding ?? p[1], post: post, comment: tham["comment"].flatMap(Int.init))
    }

    /// Đường web đầy đủ (Sao chép liên kết / Chia sẻ).
    static func urlWeb(_ duong: String?) -> URL? {
        guard let duong, !duong.isEmpty else { return nil }
        if duong.hasPrefix("http") { return URL(string: duong) }
        return URL(string: "https://cuongthai.com" + (duong.hasPrefix("/") ? duong : "/" + duong))
    }
}

// MARK: Chữ trong bài: @nhắc · #hashtag · link · /work/… · mã thẻ

enum ManhChuBangTin: Equatable {
    case nhac(id: Int, username: String)
    case hashtag(String)
    case url(URL)
    /// Mã thẻ trần (`NW-12`) trong bài của dự án có mã đó.
    case maThe(key: String, so: Int)
}

enum ChuBangTin {
    static let luocDo = "ctwfeed"

    /// Mọi mảnh có thể chạm trong `chu` (chuỗi THUẦN — sau khi bỏ markdown), xếp theo vị trí, không chồng nhau.
    /// - nhac: CHỈ tô người có trong `mentions` (hợp đồng §1) — `@ai_do` lạ để nguyên chữ.
    /// - maDuAn: mã dự án của bài (mã thẻ trần chỉ nhận trong bài dự án — như máy chủ dựng FeedRef).
    static func manh(_ chu: String, nhac: [CTWFeedNhac], maDuAn: String? = nil) -> [(Range<String.Index>, ManhChuBangTin)] {
        var kq: [(Range<String.Index>, ManhChuBangTin)] = []
        func trung(_ r: Range<String.Index>) -> Bool { kq.contains { $0.0.overlaps(r) } }

        // 1. Link web (NSDataDetector) — trước để #anchor / @ trong URL không bị bắt nhầm.
        if let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for m in d.matches(in: chu, range: NSRange(chu.startIndex..., in: chu)) {
                guard let r = Range(m.range, in: chu), let u = m.url, ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { continue }
                kq.append((r, .url(u)))
            }
        }
        // 2. Đường tương đối `/work/…` (link nội bộ dán từ web).
        for r in khop(#"(?<![\w/.:])/work/[^\s)\]>"']+"#, chu) where !trung(r) {
            let s = String(chu[r]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            if let u = URL(string: "https://cuongthai.com" + s) {
                kq.append((chu.index(r.lowerBound, offsetBy: 0)..<chu.index(r.lowerBound, offsetBy: s.count), .url(u)))
            }
        }
        // 3. @nhắc.
        let theoTen = Dictionary(nhac.compactMap { n in n.username.map { ($0.lowercased(), n) } }, uniquingKeysWith: { a, _ in a })
        for r in khop(#"(?<![\w@.])@([A-Za-z0-9_][A-Za-z0-9_.\-]{0,38}[A-Za-z0-9_]|[A-Za-z0-9_])"#, chu) where !trung(r) {
            let ten = String(chu[chu.index(after: r.lowerBound)..<r.upperBound])
            if let n = theoTen[ten.lowercased()] { kq.append((r, .nhac(id: n.id, username: n.username ?? ten))) }
        }
        // 4. #hashtag (chữ/số/_ có dấu tiếng Việt, 2–40 ký tự).
        for r in khop(#"(?<![\p{L}\p{N}_&#/])#([\p{L}\p{N}_]{2,40})(?![\p{L}\p{N}_])"#, chu) where !trung(r) {
            kq.append((r, .hashtag(String(chu[chu.index(after: r.lowerBound)..<r.upperBound]))))
        }
        // 5. Mã thẻ trần trong bài dự án.
        if let ma = maDuAn?.uppercased(), !ma.isEmpty {
            for r in khop(#"(?<![\w-])([A-Z][A-Z0-9]{0,9})-(\d{1,6})(?![\w-])"#, chu) where !trung(r) {
                let s = String(chu[r])
                let phan = s.split(separator: "-")
                if phan.count == 2, String(phan[0]) == ma, let so = Int(phan[1]) { kq.append((r, .maThe(key: ma, so: so))) }
            }
        }
        return kq.sorted { $0.0.lowerBound < $1.0.lowerBound }
    }

    private static func khop(_ mau: String, _ s: String) -> [Range<String.Index>] {
        guard let re = try? NSRegularExpression(pattern: mau) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { Range($0.range, in: s) }
    }

    /// URL nội bộ cho từng mảnh (`OpenURLAction` của thẻ bài nhận lại).
    static func urlCho(_ m: ManhChuBangTin, slug: String?) -> URL? {
        switch m {
        case .nhac(let id, _): return URL(string: "\(luocDo)://nguoi/\(id)")
        case .hashtag(let t): return URL(string: "\(luocDo)://tag/\(t.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? t)")
        case .url(let u): return u
        case .maThe(let k, let n):
            guard let slug else { return nil }
            return URL(string: "https://cuongthai.com/work/\(slug)/\(k)/issue/\(n)")
        }
    }

    /// Dựng chữ hiển thị: markdown nội dòng (đậm/nghiêng/`mã`/[link](…)) + gắn link cho @nhắc/#tag/link/mã thẻ.
    static func dung(_ body: String, nhac: [CTWFeedNhac], maDuAn: String?, slug: String?) -> AttributedString {
        var a = (try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                                                       failurePolicy: .returnPartiallyParsedIfPossible)))
            ?? AttributedString(body)
        let thuan = String(a.characters)
        for (r, m) in manh(thuan, nhac: nhac, maDuAn: maDuAn) {
            let dau = thuan.distance(from: thuan.startIndex, to: r.lowerBound)
            let dai = thuan.distance(from: r.lowerBound, to: r.upperBound)
            let ad = a.characters.index(a.startIndex, offsetBy: dau)
            let ac = a.characters.index(ad, offsetBy: dai)
            guard a[ad..<ac].link == nil, let u = urlCho(m, slug: slug) else { continue }   // [chữ](link) markdown giữ nguyên
            a[ad..<ac].link = u
            if case .nhac = m { a[ad..<ac].inlinePresentationIntent = .stronglyEmphasized }
        }
        return a
    }

    /// Chữ thuần (bỏ markdown) — để đếm/cắt "Xem thêm", báo cáo, VoiceOver.
    static func thuan(_ body: String) -> String {
        (try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                                               failurePolicy: .returnPartiallyParsedIfPossible)))
            .map { String($0.characters) } ?? body
    }

    /// Bài dài ⇒ thu gọn + "Xem thêm" (theo ký tự hoặc số dòng).
    static func canThuGon(_ body: String, kyTu: Int = 280, dong: Int = 6) -> Bool {
        body.count > kyTu || body.split(separator: "\n", omittingEmptySubsequences: false).count > dong
    }
}

// MARK: @nhắc đang gõ (ô soạn bài / bình luận)

enum NhacDangGo {
    /// Chữ sau `@` ở CUỐI ô soạn (chưa có khoảng trắng) — nil nếu không đang gõ một @nhắc.
    /// "Cảm ơn @mi" ⇒ "mi" · "@" ⇒ "" · "email a@b" ⇒ nil (dính chữ trước) · "@an " ⇒ nil (đã xong).
    static func dangGo(_ s: String) -> String? {
        guard let at = s.lastIndex(of: "@") else { return nil }
        let sau = s[s.index(after: at)...]
        guard !sau.contains(where: { $0.isWhitespace || $0.isNewline }), sau.count <= 39 else { return nil }
        guard sau.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-" }) else { return nil }
        if at > s.startIndex {
            let truoc = s[s.index(before: at)]
            guard truoc.isWhitespace || truoc.isNewline || "([{\"'".contains(truoc) else { return nil }
        }
        return String(sau)
    }

    /// Thay chữ @… đang gõ ở cuối bằng `@username ` (giữ phần trước).
    static func chen(_ s: String, username: String) -> String {
        guard dangGo(s) != nil, let at = s.lastIndex(of: "@") else { return s + "@\(username) " }
        return String(s[..<at]) + "@\(username) "
    }
}

// MARK: Thời gian hiển thị

enum ThoiGianBangTin {
    /// "Vừa xong" (< 1 phút) · "5 phút trước" · "3 giờ trước" · "Hôm qua"… (≤ 7 ngày) · "5 thg 10" · "5 thg 10, 2025".
    static func nhan(_ iso: String?, bayGio: Date = Date()) -> String {
        guard let iso, let d = Date.tuChuoiISO(iso) else { return "" }
        let giay = bayGio.timeIntervalSince(d)
        if giay < 60 { return String(localized: "Just now") }
        if giay < 7 * 86400 { return CTWDinhDang.tuongDoi(d, so: bayGio, kieu: .short) }
        let cungNam = Calendar.current.component(.year, from: d) == Calendar.current.component(.year, from: bayGio)
        return CTWDinhDang.mau(cungNam ? "MMMd" : "yMMMd").string(from: d)
    }

    static func day(_ iso: String?) -> String {
        guard let iso, let d = Date.tuChuoiISO(iso) else { return "" }
        return CTWDinhDang.mau("yMMMMdEEEE").string(from: d) + " " + CTWDinhDang.gio(d)
    }
}

// MARK: Bình luận — gộp trang + trả lời

enum BinhLuanLogic {
    /// Nối trang bình luận (chống trùng theo id, giữ thứ tự cũ → mới).
    static func noi(_ cu: [CTWFeedComment], _ moi: [CTWFeedComment]) -> [CTWFeedComment] {
        var kq = cu
        for c in moi {
            if let i = kq.firstIndex(where: { $0.id == c.id }) { kq[i] = c } else { kq.append(c) }
        }
        return kq
    }

    /// Gắn trả lời mới vào đúng bình luận gốc (máy chủ gắn trả-lời-của-trả-lời vào gốc).
    static func themTraLoi(_ ds: [CTWFeedComment], _ r: CTWFeedComment) -> [CTWFeedComment] {
        guard let cha = r.parentId, let i = ds.firstIndex(where: { $0.id == cha }) else { return noi(ds, [r]) }
        var kq = ds
        var g = kq[i]
        g.replies = noi(g.replies ?? [], [r])
        g.replyCount = max(g.replyCount ?? 0, (g.replies ?? []).count)
        kq[i] = g
        return kq
    }

    /// Thay một bình luận (gốc hoặc trả lời) theo id.
    static func thay(_ ds: [CTWFeedComment], _ c: CTWFeedComment) -> [CTWFeedComment] {
        ds.map { g in
            if g.id == c.id { var m = c; if m.replies == nil { m.replies = g.replies }; return m }
            guard var r = g.replies, let j = r.firstIndex(where: { $0.id == c.id }) else { return g }
            r[j] = c
            var m = g; m.replies = r; return m
        }
    }

    /// Xoá một bình luận: gốc ⇒ mất cả trả lời. Trả (danh sách mới, số bình luận đã bớt).
    static func xoa(_ ds: [CTWFeedComment], id: Int) -> ([CTWFeedComment], Int) {
        if let g = ds.first(where: { $0.id == id }) {
            return (ds.filter { $0.id != id }, 1 + max(g.replyCount ?? 0, (g.replies ?? []).count))
        }
        var bot = 0
        let kq = ds.map { g -> CTWFeedComment in
            guard let r = g.replies, r.contains(where: { $0.id == id }) else { return g }
            var m = g
            m.replies = r.filter { $0.id != id }
            m.replyCount = max(0, (g.replyCount ?? r.count) - 1)
            bot = 1
            return m
        }
        return (kq, bot)
    }
}
