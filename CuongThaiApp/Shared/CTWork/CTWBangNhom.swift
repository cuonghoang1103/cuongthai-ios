import Foundation

// MARK: - Board — logic thuần: bộ lọc + chia làn (swimlane) — port `frontend/src/components/work/board/grouping.ts` (21/10/2026)
//
// Không SwiftUI ⇒ kiểm thử đơn vị được (CTWorkTests/DotBTests.swift).
// Luật lồng như web: việc con (level -1) mà thẻ cha CŨNG đang trên board thì đi theo cha (chế độ Sub-tasks: thành thẻ
// trong làn của cha). Làn "Unassigned" / "No epic" / "No priority" luôn ở cuối.

enum CTWNhomBang: String, CaseIterable, Identifiable, Codable {
    case none, assignee, epic, priority, subtasks
    var id: String { rawValue }
}

/// Bộ lọc board — cùng bộ với web (lọc nhanh + nhãn + bộ phận của Board.tsx, loại thẻ + người của trang board) + epic,
/// ưu tiên (app thêm theo yêu cầu chủ app 21/10).
struct CTWBoLocBang: Equatable, Codable {
    var chiCuaToi = false
    var ganDay = false
    var tuanNay = false
    var chuaGiao = false
    var nhan: Set<Int> = []
    var loai: Set<Int> = []
    /// Người thực hiện (id). 0 = chưa giao.
    var nguoi: Set<Int> = []
    /// Bộ phận (0 = chưa có bộ phận).
    var boPhan: Set<Int> = []
    /// Epic (id thẻ epic). 0 = không thuộc epic nào.
    var epic: Set<Int> = []
    /// Ưu tiên 1…5.
    var uuTien: Set<Int> = []

    var soBat: Int {
        [chiCuaToi, ganDay, tuanNay, chuaGiao].filter { $0 }.count + nhan.count + loai.count + nguoi.count + boPhan.count + epic.count + uuTien.count
    }

    /// Thẻ có qua bộ lọc không. `toi` = id người đang dùng; `epicCua` = epic (id) của thẻ, nil = không thuộc epic.
    func khop(_ t: CTWIssueCard, cfg: CTWProjectConfig?, toi: Int?, epicCua: Int?, bayGio: Date = Date(), cuoiTuan: String) -> Bool {
        if chiCuaToi && (toi == nil || t.assigneeId != toi) { return false }
        if chuaGiao && t.assigneeId != nil { return false }
        if ganDay {
            guard let d = CTWBangNhom.thoiDiem(t.updatedAt), bayGio.timeIntervalSince(d) <= 2 * 86_400 else { return false }
        }
        if tuanNay {
            // Như web: còn mở, có hạn, hạn ≤ hết Chủ nhật tuần này (gồm cả thẻ đã quá hạn).
            guard t.resolvedAt == nil, cfg?.trangThai(t.statusId)?.category != "DONE", let han = CTW.ngay(t.dueDate) else { return false }
            if han > cuoiTuan { return false }
        }
        if !nhan.isEmpty && Set(t.labelIds ?? []).isDisjoint(with: nhan) { return false }
        if !loai.isEmpty && !loai.contains(t.typeId) { return false }
        if !nguoi.isEmpty && !nguoi.contains(t.assigneeId ?? 0) { return false }
        if !boPhan.isEmpty && !boPhan.contains(t.teamId ?? 0) { return false }
        if !epic.isEmpty && !epic.contains(epicCua ?? 0) { return false }
        if !uuTien.isEmpty && !uuTien.contains(t.priority ?? 3) { return false }
        return true
    }
}

struct CTWLanBang: Identifiable, Equatable {
    var key: String
    /// Tiêu đề do máy chủ đặt (tên người/epic/thẻ cha) — hiển thị verbatim. nil ⇒ dùng `tieuDeMacDinh`.
    var tieuDe: String?
    var tieuDeMacDinh: MacDinh?
    var userId: Int?
    var epic: Int?
    var uuTien: Int?
    var cha: CTWIssueCard?
    var the: [CTWIssueCard]
    var id: String { key }

    /// Tiêu đề cần DỊCH (làn rỗng) — chuỗi nằm ở view (`Text(LocalizedStringKey)`), không ở đây.
    enum MacDinh: Equatable { case tatCa, chuaGiao, thanhVienCu, khongEpic, khac }
}

enum CTWBangNhom {
    static func thoiDiem(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// Chủ nhật cuối tuần này theo lịch máy (`YYYY-MM-DD`).
    static func cuoiTuan(_ hn: Date = Date()) -> String {
        var lich = Calendar(identifier: .gregorian)
        lich.timeZone = .current
        let thu = lich.component(.weekday, from: hn) // 1 = CN
        return CTW.chuoiNgay(lich.date(byAdding: .day, value: thu == 1 ? 0 : 8 - thu, to: hn) ?? hn)
    }

    static func laViecCon(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> Bool { cfg.loai(t.typeId)?.level == -1 }

    /// Việc con theo id thẻ cha — chỉ những cha đang có trên board.
    static func viecConTheoCha(_ ds: [CTWIssueCard], _ cfg: CTWProjectConfig) -> [Int: [CTWIssueCard]] {
        let tren = Set(ds.map(\.id))
        var m: [Int: [CTWIssueCard]] = [:]
        for t in ds where t.parentId.map(tren.contains) == true && laViecCon(t, cfg) {
            m[t.parentId!, default: []].append(t)
        }
        return m
    }

    /// Epic của một thẻ: cha của thẻ là epic (trong `epics`) ⇒ id cha; việc con mà cha nằm trên board ⇒ epic của cha.
    static func epicCua(_ t: CTWIssueCard, epics: Set<Int>, theoId: [Int: CTWIssueCard]) -> Int? {
        guard let p = t.parentId else { return nil }
        if epics.contains(p) { return p }
        if let cha = theoId[p], let pp = cha.parentId, epics.contains(pp) { return pp }
        return nil
    }

    /// Chia thẻ (đã lọc) thành làn. `none` ⇒ một làn. `tenNguoi` đọc tên thành viên; `epicTen` = (số, tiêu đề) của epic.
    static func chiaLan(_ che: CTWNhomBang, _ ds: [CTWIssueCard], cfg: CTWProjectConfig,
                        epicTen: [Int: (so: Int, ten: String)]) -> [CTWLanBang] {
        let con = viecConTheoCha(ds, cfg)
        let longVao = Set(con.values.flatMap { $0.map(\.id) })

        if che == .subtasks {
            let theoId = Dictionary(ds.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            var lan: [CTWLanBang] = con.compactMap { pid, kids in
                guard let cha = theoId[pid] else { return nil }
                return CTWLanBang(key: "p:\(pid)", tieuDe: cha.title, cha: cha, the: kids)
            }
            lan.sort { ($0.cha?.rank ?? "") < ($1.cha?.rank ?? "") }
            let khac = ds.filter { !longVao.contains($0.id) && con[$0.id] == nil }
            lan.append(CTWLanBang(key: "other", tieuDeMacDinh: .khac, the: khac))
            return lan
        }

        let tren = ds.filter { !longVao.contains($0.id) }
        if che == .none { return [CTWLanBang(key: "all", tieuDeMacDinh: .tatCa, the: tren)] }

        var thuTu: [String] = []
        var m: [String: CTWLanBang] = [:]
        func vao(_ k: String, _ tao: () -> CTWLanBang, _ t: CTWIssueCard) {
            if m[k] == nil { m[k] = tao(); thuTu.append(k) }
            m[k]!.the.append(t)
        }
        let theoId = Dictionary(ds.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for t in tren {
            switch che {
            case .assignee:
                let uid = t.assigneeId
                vao("u:\(uid ?? 0)", {
                    if let uid {
                        if let u = cfg.thanhVien(uid) { return CTWLanBang(key: "u:\(uid)", tieuDe: u.ten, userId: uid, the: []) }
                        return CTWLanBang(key: "u:\(uid)", tieuDeMacDinh: .thanhVienCu, userId: uid, the: [])
                    }
                    return CTWLanBang(key: "u:0", tieuDeMacDinh: .chuaGiao, the: [])
                }, t)
            case .epic:
                let e = epicCua(t, epics: Set(epicTen.keys), theoId: theoId)
                vao("e:\(e ?? 0)", {
                    if let e, let x = epicTen[e] { return CTWLanBang(key: "e:\(e)", tieuDe: x.ten, epic: e, the: []) }
                    return CTWLanBang(key: "e:0", tieuDeMacDinh: .khongEpic, the: [])
                }, t)
            case .priority:
                let p = t.priority ?? 3
                vao("p:\(p)", { CTWLanBang(key: "p:\(p)", uuTien: p, the: []) }, t)
            case .none, .subtasks: break
            }
        }
        var lan = thuTu.compactMap { m[$0] }
        lan.sort { a, b in
            let ea = a.key.hasSuffix(":0") ? 1 : 0, eb = b.key.hasSuffix(":0") ? 1 : 0
            if ea != eb { return ea < eb }
            switch che {
            case .epic: return (epicTen[a.epic ?? 0]?.so ?? 0) < (epicTen[b.epic ?? 0]?.so ?? 0)
            case .priority: return (a.uuTien ?? 3) < (b.uuTien ?? 3)
            // Làn không tên (thành viên cũ) sau các làn có tên.
            default: return (a.tieuDe ?? "\u{FFFF}").localizedCaseInsensitiveCompare(b.tieuDe ?? "\u{FFFF}") == .orderedAscending
            }
        }
        return lan
    }
}
