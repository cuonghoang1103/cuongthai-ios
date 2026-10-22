import Foundation

// MARK: - Tìm mọi thứ (⌘K) — phần THUẦN: bỏ dấu, chấm điểm, nhận mã thẻ, từ khoá theo mô-đun (21/10/2026)
//
// Phản hồi người dùng: "app nhiều chức năng quá — cho tìm chức năng, thẻ, gì cũng được, gõ là mở thẳng". Tệp này
// không đụng giao diện/mạng ⇒ kiểm thử đơn vị được (`CTWorkTests/TimKiemCTWTests.swift`). Màn: `TimKiemCTW.swift`.

/// Chuẩn hoá chữ để so khớp: bỏ dấu tiếng Việt (kể cả đ/Đ), chữ thường, mọi dấu câu thành MỘT khoảng trắng.
/// "Báo cáo" ⇒ "bao cao" · "Docs & knowledge" ⇒ "docs knowledge" · "ai-usage" ⇒ "ai usage".
enum CTWBoDau {
    static func chuan(_ s: String) -> String {
        let bo = s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "d")
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var kq = String.UnicodeScalarView()
        var vuaCach = true
        for ch in bo.unicodeScalars {
            if CharacterSet.alphanumerics.contains(ch) {
                kq.append(ch); vuaCach = false
            } else if !vuaCach {
                kq.append(" "); vuaCach = true
            }
        }
        return String(kq).trimmingCharacters(in: .whitespaces)
    }
}

/// Chấm điểm một chuỗi ứng viên với chữ đang gõ. Thứ tự: trùng hẳn > đầu chuỗi > đầu một từ > chứa > khớp từng từ.
/// nil = không khớp. Cả hai vế đã qua `CTWBoDau.chuan`.
enum CTWKhopTim {
    static let trung = 100, dauChuoi = 90, dauTu = 70, chua = 50, moiTuDauTu = 40, moiTuChua = 30

    static func diem(_ q: String, _ c: String) -> Int? {
        guard !q.isEmpty, !c.isEmpty else { return nil }
        if c == q { return trung }
        if c.hasPrefix(q) { return dauChuoi }
        if c.contains(" " + q) { return dauTu }
        if c.contains(q) { return chua }
        let tuQ = q.split(separator: " ")
        guard tuQ.count > 1 else { return nil }
        let tuC = c.split(separator: " ")
        if tuQ.allSatisfy({ t in tuC.contains { $0.hasPrefix(t) } }) { return moiTuDauTu }
        if tuQ.allSatisfy({ c.contains($0) }) { return moiTuChua }
        return nil
    }

    /// Điểm cao nhất trên nhiều ứng viên, mỗi nhóm ứng viên có mức trừ riêng (tên 0, từ khoá −5, mô tả −30).
    static func diem(_ q: String, ten: [String], tuKhoa: [String] = [], moTa: [String] = []) -> Int? {
        var tot: Int?
        func xet(_ ds: [String], _ tru: Int) {
            for c in ds { if let d = diem(q, c) { tot = max(tot ?? Int.min, d - tru) } }
        }
        xet(ten, 0); xet(tuKhoa, 5); xet(moTa, 30)
        return tot
    }
}

/// Chữ gõ trông như mã thẻ: `ABC-12` (mã dự án + số) hoặc `12` / `#12` (số trong dự án đang chọn).
struct CTWMaTheGo: Equatable {
    var maDuAn: String?
    var so: Int

    static func tach(_ s: String) -> CTWMaTheGo? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = t.range(of: #"^([A-Za-z][A-Za-z0-9]*)-(\d{1,9})$"#, options: .regularExpression), r == t.startIndex..<t.endIndex,
           let gach = t.lastIndex(of: "-"), let n = Int(t[t.index(after: gach)...]), n > 0 {
            return CTWMaTheGo(maDuAn: String(t[..<gach]).uppercased(), so: n)
        }
        let so = t.hasPrefix("#") ? String(t.dropFirst()) : t
        if !so.isEmpty, so.count <= 9, so.allSatisfy(\.isASCII), so.allSatisfy(\.isNumber), let n = Int(so), n > 0 {
            return CTWMaTheGo(maDuAn: nil, so: n)
        }
        return nil
    }

    /// "NW-12" khi đã biết mã dự án.
    func ma(_ duAnHienTai: String?) -> String? {
        guard let m = maDuAn ?? duAnHienTai else { return nil }
        return "\(m)-\(so)"
    }
}

// MARK: - Từ khoá / từ đồng nghĩa theo MÔ-ĐUN (khoá = `CTWModule.id`)
//
// Viết KHÔNG DẤU, cả tiếng Việt lẫn tiếng Anh (tên vi/en của mô-đun đã tự khớp — đây là phần NGƯỜI DÙNG hay gõ mà
// tên không có: "kanban" ⇒ Board, "hop" ⇒ Meetings). Mô-đun mới: thêm một dòng theo id. Khoá của mô-đun CHƯA đăng ký
// bị bỏ qua (`TimKiemCTWTests` bắt khoá không khớp mô-đun nào).
enum CTWTuKhoaMoDun {
    static let bang: [String: [String]] = [
        "board": ["kanban", "bang", "bang keo tha", "cot", "columns", "drag", "keo tha", "sprint board", "bang cong viec"],
        "backlog": ["backlog", "danh sach", "list", "issues", "the", "tat ca the", "jql", "loc", "filter", "ke hoach sprint", "tim nang cao"],
        "sprints": ["sprint", "burndown", "bat dau sprint", "ket thuc sprint", "iteration", "chu ky"],
        "calendar": ["lich", "calendar", "ngay", "han", "deadline", "due", "su kien", "event", "schedule"],
        "meetings": ["hop", "cuoc hop", "meeting", "bien ban", "minutes", "standup", "lich hop", "meet"],
        "docs": ["tai lieu", "docs", "trang", "page", "wiki", "spec", "ghi chu", "notes", "van ban"],
        "kb": ["kien thuc", "knowledge", "help center", "bai viet", "faq", "huong dan"],
        // Kênh nhóm. "tin nhắn"/"nhắn tin" thuộc Tin nhắn riêng (`tin-nhan`) — đừng khai lại ở đây (ngang điểm thì Chat thắng).
        "chat": ["chat", "kenh", "channel", "tro chuyen", "group chat", "chat nhom", "kenh chat"],
        // Bảng tin dự án (Modules/BangTin). Bảng tin GỘP của My Work là màn cấp app `app:feed`.
        "feed": ["bang tin", "feed", "bai viet", "dang bai", "news feed", "newsfeed", "team feed", "tin nhom", "post", "posts",
                 "cap nhat", "thong bao nhom", "anh nhom", "binh chon", "poll"],
        "ai": ["ai", "cuongmini", "cuong mini", "tro ly", "assistant", "hoi ai", "ask ai", "hoi cuongmini", "ask cuongmini", "gpt",
               "chatbot", "hom nay lam gi", "hom nay toi nen lam gi", "nen lam gi", "what should i do today", "today plan"],
        "ai-usage": ["ai", "cuongmini", "chi phi ai", "token", "usage", "su dung ai"],
        "agents": ["ai agent", "agent", "bot", "cuongmini", "tac tu"],
        "reports": ["bao cao", "report", "burndown", "velocity", "thong ke", "chart", "bieu do", "workload"],
        "dashboards": ["dashboard", "bang dieu khien", "widget", "bao cao", "tong quan"],
        "time": ["thoi gian", "time", "gio", "cham cong", "timesheet", "log time", "ghi gio", "bam gio", "timer", "dong ho"],
        "team": ["thanh vien", "members", "nhom", "team", "nguoi", "moi", "invite", "vai tro", "role", "khoi luong"],
        "timeline": ["lo trinh", "roadmap", "timeline", "gantt", "epic"],
        "releases": ["phien ban", "release", "version", "phat hanh"],
        "stages": ["giai doan", "stage", "gate", "phase"],
        "poker": ["uoc luong", "estimate", "planning poker", "story point", "diem"],
        "retros": ["retro", "nhin lai", "retrospective", "rut kinh nghiem"],
        "okrs": ["okr", "muc tieu", "objective", "key result"],
        "workspace": ["khong gian", "workspace", "portfolio", "danh muc", "workload", "tat ca du an"],
        "code": ["code", "git", "github", "gitlab", "pull request", "pr", "branch", "nhanh", "commit", "ma nguon", "source"],
        "tests": ["kiem thu", "test", "test case", "qa", "chay test", "bao cao kiem thu", "unit test"],
        "requirements": ["yeu cau", "requirement", "use case", "srs", "business rule", "man hinh", "truy vet", "rtm"],
        "wiegers": ["wiegers", "yeu cau", "stakeholder", "glossary", "thuat ngu", "tinh nang"],
        "diagrams": ["so do", "diagram", "erd", "uml", "flowchart", "ve"],
        "resources": ["tai nguyen", "link", "lien ket", "repo", "figma", "drive", "thu vien"],
        "assets": ["tai san", "license", "ban quyen", "font", "phan mem"],
        "finance": ["tai chinh", "ngan sach", "budget", "chi phi", "tien", "milestone"],
        "approvals": ["phe duyet", "duyet", "approve", "ky duyet", "sign off"],
        "changes": ["thay doi", "change request", "cr", "pham vi"],
        "raid": ["rui ro", "risk", "raid", "gia dinh", "phu thuoc", "van de"],
        "reviews": ["review", "danh gia", "kiem tra", "inspection", "checklist"],
        "desk": ["ho tro", "service desk", "ticket", "sla", "khach hang", "support"],
        "intake": ["tiep nhan", "intake", "email", "zalo", "discord", "slack", "yeu cau den"],
        "forms": ["bieu mau", "form", "khao sat", "survey"],
        "portal": ["cong khach hang", "portal", "khach", "client"],
        "classes": ["lop hoc", "class", "bai tap", "assignment", "giang day", "hoc"],
        "submit": ["nop bai", "san pham ban giao", "deliverable", "nop", "submission"],
        // Mô-đun CẤP ỨNG DỤNG (Modules/ThanhVien): iPhone = phân đoạn Tin nhắn / Thành viên của tab Chat, iPad = mục thanh bên.
        "tin-nhan": ["tin nhan", "nhan tin", "tin nhan rieng", "message", "messages", "messenger", "chat rieng", "dm",
                     "direct message", "inbox chat", "hoi thoai"],
        "thanh-vien": ["thanh vien", "members", "dong nghiep", "nguoi", "danh ba", "people", "contacts", "online",
                       "dang hoat dong", "active now", "ho so", "profile", "ai dang online"],
    ]

    static func cua(_ id: String) -> [String] { bang[id] ?? [] }
}

// MARK: - Tên hai ngôn ngữ của một chuỗi catalog

/// Tên của một `LocalizedStringResource` ở CẢ tiếng Anh lẫn tiếng Việt — để gõ "Báo cáo" khi app đang tiếng Anh vẫn
/// thấy "Reports" (và ngược lại). Tiếng Anh = khoá (ngôn ngữ nguồn); tiếng Việt tra thẳng `vi.lproj` — KHÔNG qua
/// `Bundle.main` (lớp đã bị tráo để theo ngôn ngữ đang chọn, xem NgonNguCTW). Không phụ thuộc ngôn ngữ đang chọn
/// ⇒ đệm được.
enum CTWHaiNgu {
    private static let goiVi: Bundle? = Bundle.main.path(forResource: "vi", ofType: "lproj").flatMap(Bundle.init(path:))
    private static var dem: [String: [String]] = [:]
    private static let khoaDem = NSLock()

    static func cacTen(_ r: LocalizedStringResource) -> [String] { cacTen(khoa: r.key) }

    static func cacTen(khoa: String) -> [String] {
        khoaDem.lock(); defer { khoaDem.unlock() }
        if let d = dem[khoa] { return d }
        var ds = [khoa]
        if let vi = goiVi?.localizedString(forKey: khoa, value: "\u{0}", table: "Localizable"), vi != "\u{0}", vi != khoa { ds.append(vi) }
        dem[khoa] = ds
        return ds
    }
}

// MARK: - Mục kết quả "Chức năng" / "Lệnh"

/// Đích của một mục chức năng/lệnh (thẻ, dự án, trang tài liệu… có kiểu riêng trong `TimKiemCTW.swift`).
enum DichTimCTW: Hashable {
    /// Mô-đun cấp dự án theo id (`CTWDangKyMoDun`).
    case moDun(String)
    case viecCuaToi, agenda, hopThu, taiKhoan, congCuKhac, caiDatThongBao
    /// My Work › Bảng tin (gộp) · mở ô soạn bài.
    case bangTin, dangBai
    case taoThe, taoCuongMini, duAnMoi, doiDuAn
    case ngonNgu(NgonNguCTW.CheDo)
}

struct MucTimCTW: Identifiable, Hashable {
    enum Nhom: Hashable { case chucNang, lenh }

    /// "mod:board" · "app:mywork" · "act:create" … — cũng là khoá đếm "hay dùng".
    let id: String
    let nhom: Nhom
    let tenNguon: LocalizedStringResource
    var moTaNguon: LocalizedStringResource?
    /// Phụ đề không dịch (vd tên ngôn ngữ viết bằng chính nó).
    var phuCoDinh: String?
    let bieuTuong: String
    var tuKhoa: [String] = []
    let dich: DichTimCTW

    var ten: String { CTWModule.dich(tenNguon) }
    var moTa: String? { phuCoDinh ?? moTaNguon.map(CTWModule.dich).flatMap { $0.isEmpty ? nil : $0 } }

    /// Chuỗi đã chuẩn hoá để so khớp: tên en + vi (+ tên hiển thị nếu khác), từ khoá, mô tả en + vi.
    var tenKhop: [String] {
        var ds = CTWHaiNgu.cacTen(tenNguon)
        if let p = phuCoDinh { ds.append(p) }
        return ds.map(CTWBoDau.chuan)
    }
    var tuKhoaKhop: [String] { tuKhoa.map(CTWBoDau.chuan) }
    var moTaKhop: [String] { moTaNguon.map { CTWHaiNgu.cacTen($0).map(CTWBoDau.chuan) } ?? [] }

    static func == (a: MucTimCTW, b: MucTimCTW) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum CTWXepHangTim {
    /// Lọc + xếp mục theo chữ gõ. `dem` = số lần đã mở qua tìm kiếm/thanh điều hướng (cộng tối đa +4, chỉ để phân
    /// định khi điểm khớp ngang nhau — không đè được thứ bậc đầu chuỗi > đầu từ > chứa).
    static func xep(_ q: String, _ ds: [MucTimCTW], dem: [String: Int] = [:]) -> [MucTimCTW] {
        let fq = CTWBoDau.chuan(q)
        guard !fq.isEmpty else { return ds }
        var kq: [(MucTimCTW, Int, Int)] = []
        for (i, m) in ds.enumerated() {
            guard let d = CTWKhopTim.diem(fq, ten: m.tenKhop, tuKhoa: m.tuKhoaKhop, moTa: m.moTaKhop) else { continue }
            kq.append((m, d + min(dem[m.id] ?? 0, 4), i))
        }
        return kq.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }.map(\.0)
    }

    /// Một mục mô-đun (tên/mô tả/biểu tượng của bảng đăng ký + từ khoá theo id).
    static func muc(_ m: CTWModule) -> MucTimCTW {
        MucTimCTW(id: "mod:\(m.id)", nhom: .chucNang, tenNguon: m.tenNguon, moTaNguon: m.moTaNguon, bieuTuong: m.bieuTuong,
                  tuKhoa: CTWTuKhoaMoDun.cua(m.id), dich: .moDun(m.id))
    }

    /// Màn cấp app (không thuộc dự án) — luôn có.
    static var manApp: [MucTimCTW] {
        [
            MucTimCTW(id: "app:mywork", nhom: .chucNang, tenNguon: "My Work", moTaNguon: "Issues assigned to you across projects",
                      bieuTuong: "checklist", tuKhoa: ["viec cua toi", "my issues", "assigned", "giao cho toi", "cua toi", "trang chu", "home"],
                      dich: .viecCuaToi),
            MucTimCTW(id: "app:agenda", nhom: .chucNang, tenNguon: "Agenda", moTaNguon: "Today, this week and overdue — across projects",
                      bieuTuong: "calendar.day.timeline.left", tuKhoa: ["lich trinh", "hom nay", "today", "tuan nay", "qua han", "overdue"],
                      dich: .agenda),
            // Lọc khi máy chủ chưa có bảng tin: `TimKiemCTW.tatCaChucNang`.
            MucTimCTW(id: "app:feed", nhom: .chucNang, tenNguon: "Feed", moTaNguon: "Posts from every workspace and project you're in",
                      bieuTuong: "newspaper",
                      tuKhoa: ["bang tin", "feed", "bai viet", "news feed", "newsfeed", "team feed", "tin nhom", "posts", "dang bai",
                               "bai dang", "cap nhat nhom", "hashtag"],
                      dich: .bangTin),
            MucTimCTW(id: "app:inbox", nhom: .chucNang, tenNguon: "Inbox", moTaNguon: "Notifications and mentions",
                      bieuTuong: "bell", tuKhoa: ["thong bao", "notifications", "hop thu", "mention", "nhac ten", "nhac toi"],
                      dich: .hopThu),
            MucTimCTW(id: "app:notifSettings", nhom: .chucNang, tenNguon: "Notification settings", moTaNguon: "What to notify me about",
                      bieuTuong: "slider.horizontal.3", tuKhoa: ["cai dat thong bao", "tat thong bao", "email", "gio im lang", "quiet hours", "push"],
                      dich: .caiDatThongBao),
            MucTimCTW(id: "app:account", nhom: .chucNang, tenNguon: "Account", moTaNguon: "Settings, privacy, Face ID, sign out",
                      bieuTuong: "person.crop.circle",
                      tuKhoa: ["settings", "cai dat", "tai khoan", "profile", "ho so", "dang xuat", "logout", "sign out", "quyen rieng tu",
                               "privacy", "face id", "khoa app", "xoa tai khoan", "delete account", "chan", "blocked"],
                      dich: .taiKhoan),
            MucTimCTW(id: "app:more", nhom: .chucNang, tenNguon: "More tools", moTaNguon: "Every tool of this project — pin your favourites",
                      bieuTuong: "square.grid.2x2", tuKhoa: ["tat ca chuc nang", "all tools", "modules", "ghim", "pin", "them"],
                      dich: .congCuKhac),
        ]
    }

    /// Lệnh nhanh. `taoThe`/`taoDuAn` theo quyền; `ngonNguHienTai` ⇒ bỏ lựa chọn đang dùng.
    @MainActor
    static func lenh(taoThe: Bool, taoDuAn: Bool, coDuAn: Bool, ngonNguHienTai: NgonNguCTW.CheDo) -> [MucTimCTW] {
        var ds: [MucTimCTW] = []
        if taoThe {
            ds.append(MucTimCTW(id: "act:create", nhom: .lenh, tenNguon: "Create issue", moTaNguon: "New story, task or bug in this project",
                                bieuTuong: "plus.square", tuKhoa: ["tao the", "new issue", "tao viec", "them viec", "task moi", "bug moi", "add"],
                                dich: .taoThe))
        }
        if KhoBangTinCTW.shared.coTheDang {
            ds.append(MucTimCTW(id: "act:post", nhom: .lenh, tenNguon: "New post", moTaNguon: "Share an update in the team feed",
                                bieuTuong: "square.and.pencil",
                                tuKhoa: ["dang bai", "bai viet moi", "viet bai", "new post", "post", "share", "chia se", "bang tin", "feed",
                                         "dang anh", "dang video"],
                                dich: .dangBai))
        }
        ds.append(MucTimCTW(id: "act:switch", nhom: .lenh, tenNguon: "Switch project", moTaNguon: coDuAn ? "All projects…" : "Choose a project",
                            bieuTuong: "arrow.left.arrow.right", tuKhoa: ["doi du an", "chon du an", "all projects", "tat ca du an", "projects"],
                            dich: .doiDuAn))
        if taoDuAn {
            ds.append(MucTimCTW(id: "act:cuongmini", nhom: .lenh, tenNguon: "Create with CuongMini",
                                moTaNguon: "Describe your project — CuongMini drafts the plan", bieuTuong: "sparkles",
                                tuKhoa: ["cuongmini", "cuong mini", "ai", "tao du an bang ai", "generate", "ke hoach"], dich: .taoCuongMini))
            ds.append(MucTimCTW(id: "act:newProject", nhom: .lenh, tenNguon: "New project", moTaNguon: "Start an empty project",
                                bieuTuong: "folder.badge.plus", tuKhoa: ["tao du an", "create project", "du an moi"], dich: .duAnMoi))
        }
        for c in NgonNguCTW.CheDo.allCases where c != ngonNguHienTai {
            ds.append(MucTimCTW(id: "act:lang-\(c.rawValue)", nhom: .lenh, tenNguon: "Change language",
                                phuCoDinh: NgonNguApCTW.ten(c), bieuTuong: "globe",
                                tuKhoa: ["doi ngon ngu", "ngon ngu", "language", "tieng viet", "english", "tieng anh", "vietnamese"],
                                dich: .ngonNgu(c)))
        }
        return ds
    }
}
