import AppIntents
import Foundation

// MARK: - App Intents / Siri / Shortcuts (mảng D)
//
// Chạy TRONG tiến trình app (intent khai ở target app) ⇒ dùng thẳng `APIClient` + `DongHoCTW`, không cần
// chia token cho extension. Ba việc:
//   · "Start a CT Work timer on <thẻ>"   — `BatDauBamGioYD` (thẻ chọn từ thẻ đã xem gần đây hoặc tìm theo mã)
//   · "Stop my CT Work timer"            — `DungBamGioYD`
//   · "What's on my plate in CT Work"    — `ViecHomNayYD` (đọc to danh sách hôm nay)
// Chưa đăng nhập ⇒ báo câu rõ ràng, không ném lỗi lạ.

// MARK: Thực thể "thẻ"

struct TheCTWEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Issue"
    static var defaultQuery = TheCTWQuery()

    /// "NW-12"
    var id: String
    var pid: Int
    var so: Int
    var tieuDe: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)", subtitle: "\(tieuDe)")
    }
}

struct TheCTWQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TheCTWEntity] {
        let gan = TheGanDayCTW.ds()
        return identifiers.compactMap { id in
            gan.first { $0.ma.caseInsensitiveCompare(id) == .orderedSame }
                .map { TheCTWEntity(id: $0.ma, pid: $0.pid, so: $0.so, tieuDe: $0.tieuDe) }
        }
    }

    /// Gợi ý = thẻ đã mở gần đây trên máy này (không gọi mạng).
    func suggestedEntities() async throws -> [TheCTWEntity] {
        TheGanDayCTW.ds().prefix(10).map { TheCTWEntity(id: $0.ma, pid: $0.pid, so: $0.so, tieuDe: $0.tieuDe) }
    }

    /// Gõ/nói "NW-12" hoặc một phần tiêu đề ⇒ thẻ gần đây khớp, rồi tìm trên máy chủ.
    func entities(matching string: String) async throws -> [TheCTWEntity] {
        let q = string.trimmingCharacters(in: .whitespaces)
        let gan = TheGanDayCTW.ds().filter {
            $0.ma.localizedCaseInsensitiveContains(q) || $0.tieuDe.localizedCaseInsensitiveContains(q)
        }.map { TheCTWEntity(id: $0.ma, pid: $0.pid, so: $0.so, tieuDe: $0.tieuDe) }
        if !gan.isEmpty || q.count < 2 { return gan }
        let kq: CTWSearchResult? = try? await APIClient.shared.request(CTWAPI.timToanCuc(q: q))
        var ds: [TheCTWEntity] = []
        for i in kq?.items ?? [] {
            guard let ma = i.project?.key, let slug = i.workspace?.slug else { continue }
            if let pid = try? await pidCua(slug: slug, ma: ma) {
                ds.append(TheCTWEntity(id: i.key ?? "\(ma)-\(i.number)", pid: pid, so: i.number, tieuDe: i.title))
            }
            if ds.count >= 8 { break }
        }
        return ds
    }

    private func pidCua(slug: String, ma: String) async throws -> Int {
        let r: CTWResolve = try await APIClient.shared.request(.workTimDuAn(slug: slug, ma: ma))
        return r.projectId
    }
}

enum LoiYDinhCTW: Error, CustomLocalizedStringResourceConvertible {
    case chuaDangNhap, khongThay
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .chuaDangNhap: return "Open CT Work and sign in first."
        case .khongThay: return "I couldn't find that issue. Open it once in CT Work, then try again."
        }
    }
}

@MainActor
private func canDangNhap() throws {
    guard AppState.shared.isAuthenticated, StorageManager.shared.getAuthToken() != nil else { throw LoiYDinhCTW.chuaDangNhap }
}

// MARK: Bắt đầu bấm giờ

struct BatDauBamGioYD: AppIntent {
    static var title: LocalizedStringResource = "Start Timer on Issue"
    static var description = IntentDescription("Starts your CT Work timer on an issue. A timer running on another issue is stopped and logged first.")

    @Parameter(title: "Issue") var the: TheCTWEntity

    static var parameterSummary: some ParameterSummary { Summary("Start timer on \(\.$the)") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try canDangNhap()
        try await DongHoCTW.shared.batDau(pid: the.pid, so: the.so, chuyen: true)
        return .result(dialog: "Timer started on \(the.id).")
    }
}

// MARK: Dừng bấm giờ

struct DungBamGioYD: AppIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description = IntentDescription("Stops your running CT Work timer and logs the time.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try canDangNhap()
        await DongHoCTW.shared.taiLai()
        guard let d = DongHoCTW.shared.dongHo else { return .result(dialog: "No timer is running.") }
        let r = try await DongHoCTW.shared.dung()
        let phut = r.minutes ?? 0
        if phut == 0 { return .result(dialog: "Stopped. Under 30 seconds, so nothing was logged.") }
        return .result(dialog: "Logged \(TinhGioCTW.chuPhut(phut)) on \(r.issueKey ?? d.issueKey ?? "the issue").")
    }
}

// MARK: Việc hôm nay

struct ViecHomNayYD: AppIntent {
    static var title: LocalizedStringResource = "My Work Today"
    static var description = IntentDescription("Reads out today's meetings, due issues and overdue work from CT Work.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try canDangNhap()
        let anh = await CTWChiaSeNhom.lamMoiViecHomNay()
        return .result(dialog: IntentDialog(stringLiteral: Self.cau(anh?.viec ?? [])))
    }

    /// Câu đọc to — thuần, có kiểm thử.
    static func cau(_ ds: [AnhViecHomNayCTW.Viec]) -> String {
        if ds.isEmpty { return "Nothing is due today and you have no meetings. Enjoy." }
        let hop = ds.filter { $0.loai == "meeting" }
        let han = ds.filter { $0.loai == "due" }
        let tre = ds.filter { $0.loai == "overdue" }
        var cau: [String] = []
        if !hop.isEmpty {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            let dau = hop.prefix(3).map { h in h.gio.map { "\(h.tieuDe) at \(f.string(from: $0))" } ?? h.tieuDe }
            cau.append("\(hop.count) meeting\(hop.count == 1 ? "" : "s"): \(dau.joined(separator: ", "))")
        }
        if !han.isEmpty {
            cau.append("\(han.count) issue\(han.count == 1 ? "" : "s") due today: \(han.prefix(3).map { $0.ma ?? $0.tieuDe }.joined(separator: ", "))")
        }
        if !tre.isEmpty { cau.append("\(tre.count) overdue") }
        let khac = ds.count - hop.count - han.count - tre.count
        if khac > 0 { cau.append("\(khac) sprint or release date\(khac == 1 ? "" : "s")") }
        return cau.joined(separator: ". ") + "."
    }
}

// MARK: Câu Siri sẵn (không cần người dùng tự tạo phím tắt)

struct PhimTatCTW: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ViecHomNayYD(), phrases: [
            "What's on my plate in \(.applicationName)",
            "My work today in \(.applicationName)",
            "What do I have today in \(.applicationName)",
        ], shortTitle: "My Work Today", systemImageName: "checklist")
        AppShortcut(intent: BatDauBamGioYD(), phrases: [
            "Start a \(.applicationName) timer on \(\.$the)",
            "Start timer on \(\.$the) in \(.applicationName)",
            "Start a \(.applicationName) timer",
        ], shortTitle: "Start Timer", systemImageName: "play.circle")
        AppShortcut(intent: DungBamGioYD(), phrases: [
            "Stop my \(.applicationName) timer",
            "Stop timer in \(.applicationName)",
        ], shortTitle: "Stop Timer", systemImageName: "stop.circle")
    }
}
