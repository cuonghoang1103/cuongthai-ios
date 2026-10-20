import SwiftUI

// MARK: - Code › Mã nguồn: cây thư mục · xem tệp (tô màu + số dòng) · lịch sử · diff một commit
//
// Proxy GitHub/GitLab qua máy chủ (`gitSource.ts`): tệp > 1 MB ⇒ `tooLarge`, nhị phân ⇒ `binary` (cả hai không có
// `content`); diff cắt 200 KB/tệp, 800 KB tổng ⇒ `patch = null` + `truncated`. Hết hạn mức của nhà cung cấp ⇒ 429
// với câu giải thích (hiện nguyên văn). Repo riêng tư không có token ⇒ lỗi 404/403 của nhà cung cấp (hiện câu máy chủ).

struct RouteCodeCTW: Hashable {
    enum Loai: Hashable {
        case thuMuc(String)
        case tep(String)
        case lichSu(String?)
        case commit(String)
    }
    var pid: Int
    var ref: String?
    var loai: Loai

    @MainActor @ViewBuilder var man: some View {
        switch loai {
        case .thuMuc(let p): CayThuMucCTW(pid: pid, ref: ref, path: p)
        case .tep(let p): XemTepCodeCTW(pid: pid, ref: ref, path: p)
        case .lichSu(let p): LichSuCommitCTW(pid: pid, ref: ref, path: p)
        case .commit(let sha): ChiTietCommitCTW(pid: pid, sha: sha)
        }
    }
}

// MARK: - Cây thư mục

@MainActor
final class CayVM: ObservableObject {
    let pid: Int
    @Published var ref: String?
    let path: String
    @Published var cay: TaiCTW<CTWCodeCay> = .dangTai
    @Published var refs: [CTWCodeRef] = []
    @Published var repo: CTWCodeRepo?

    init(pid: Int, ref: String?, path: String) { self.pid = pid; self.ref = ref; self.path = path }

    func tai() async {
        cay = cay.giaTri == nil ? .dangTai : cay
        do {
            let c: CTWCodeCay = try await APIClient.shared.request(CTWAPI.codeCay(pid: pid, ref: ref, path: path))
            if ref == nil { ref = c.ref }
            cay = .xong(c)
        } catch {
            cay = .loi(CTW.loi(error))
        }
    }

    func taiRefs() async {
        if repo == nil { repo = try? await APIClient.shared.request(CTWAPI.codeRepo(pid: pid)) }
        if refs.isEmpty, let r: [CTWCodeRef] = try? await APIClient.shared.request(CTWAPI.codeRefs(pid: pid)) { refs = r }
    }
}

struct CayThuMucCTW: View {
    let pid: Int
    let path: String
    @StateObject private var vm: CayVM
    var nhung = false

    init(pid: Int, ref: String?, path: String, nhung: Bool = false) {
        self.pid = pid
        self.path = path
        self.nhung = nhung
        _vm = StateObject(wrappedValue: CayVM(pid: pid, ref: ref, path: path))
    }

    /// Tab "Source" ngay trong màn Code: thư mục gốc, nhánh mặc định.
    @MainActor @ViewBuilder
    static func phanGoc(pid: Int, repo: CTWCodeTongQuan.NhaCungCap?) -> some View {
        CayThuMucCTW(pid: pid, ref: nil, path: "", nhung: true)
    }

    var body: some View {
        if nhung { cacMuc } else {
            List { cacMuc }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(AppColors.backgroundPrimary)
                .navigationTitle(path.isEmpty ? String(localized: "Source") : (path.split(separator: "/").last.map(String.init) ?? path))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .primaryAction) { menuNhanh } }
                .refreshable { await vm.tai() }
        }
    }

    private var menuNhanh: some View {
        Menu {
            if vm.refs.isEmpty { Text("Loading branches…") }
            ForEach(vm.refs, id: \.name) { r in
                Button {
                    vm.ref = r.name
                    Task { await vm.tai() }
                } label: {
                    if r.name == vm.ref { Label(r.name, systemImage: "checkmark") } else { Text(r.name) }
                }
            }
        } label: {
            Label(vm.ref ?? String(localized: "Branch"), systemImage: "arrow.triangle.branch").labelStyle(.titleAndIcon)
                .font(.ctw(size: 13, weight: .semibold)).lineLimit(1)
        }
        .accessibilityLabel("Branch: \(vm.ref ?? String(localized: "default"))")
        .task { await vm.taiRefs() }
    }

    @ViewBuilder private var cacMuc: some View {
        if nhung {
            Section {
                HStack {
                    menuNhanh
                    Spacer()
                    NavigationLink(value: RouteCodeCTW(pid: pid, ref: vm.ref, loai: .lichSu(nil))) {
                        Label("History", systemImage: "clock.arrow.circlepath").font(.ctw(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                }
                if let m = vm.repo?.description, !m.isEmpty {
                    Text(m).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
        }
        switch vm.cay {
        case .dangTai:
            Section { ProgressView().frame(maxWidth: .infinity).padding() }.listRowBackground(Color.clear)
                .task { await vm.tai() }
        case .loi(let l):
            Section { CTWOLoi(loi: l) { Task { await vm.tai() } } }.listRowBackground(Color.clear)
        case .xong(let c):
            if c.entries.isEmpty {
                Section { CTWOTrong(bieuTuong: "folder", tieuDe: String(localized: "This folder is empty")) }.listRowBackground(Color.clear)
            } else {
                Section {
                    // NavigationLink(value:) — KHÔNG đọc `NganXepCTW` ở đây: màn này cũng được ĐẨY, và trên iPad màn được
                    // đẩy không thấy environmentObject của cột ⇒ SIGTRAP (đo 19/10).
                    ForEach(c.entries.sorted { ($0.laThuMuc ? 0 : 1, $0.name.lowercased()) < ($1.laThuMuc ? 0 : 1, $1.name.lowercased()) }) { m in
                        if m.type == "submodule" {
                            hang(m).foregroundColor(AppColors.textTertiary)
                        } else {
                            NavigationLink(value: RouteCodeCTW(pid: pid, ref: vm.ref, loai: m.laThuMuc ? .thuMuc(m.path) : .tep(m.path))) { hang(m) }
                        }
                    }
                } header: {
                    if !path.isEmpty { Text(path).textCase(nil).lineLimit(1).truncationMode(.head) }
                }
            }
        }
    }

    private func hang(_ m: CTWCodeMucCay) -> some View {
        HStack(spacing: 10) {
            Image(systemName: m.laThuMuc ? "folder.fill" : (m.type == "submodule" ? "shippingbox" : BieuTuongTepCTW.cho(m.name)))
                .font(.ctw(size: 15)).foregroundColor(m.laThuMuc ? AppColors.info : AppColors.textSecondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(m.name).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if !m.laThuMuc, let s = m.size { Text(CTWCodeChu.coTep(s)).font(.ctw(size: 11.5).monospacedDigit()).foregroundColor(AppColors.textTertiary) }
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(m.laThuMuc ? "Folder \(m.name)" : "File \(m.name)")
    }
}

enum BieuTuongTepCTW {
    static func cho(_ ten: String) -> String {
        let e = (ten as NSString).pathExtension.lowercased()
        switch e {
        case "md", "txt", "rst": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico": return "photo"
        case "json", "yml", "yaml", "toml", "xml", "plist": return "curlybraces"
        case "lock": return "lock"
        default: return "doc.plaintext"
        }
    }
}

// MARK: - Xem một tệp

struct XemTepCodeCTW: View {
    let pid: Int
    let ref: String?
    let path: String
    @State private var tt: TaiCTW<CTWCodeTep> = .dangTai
    @State private var xuongDong = true
    @State private var moLichSu = false
    @Environment(\.openURL) private var moUrl

    private var ten: String { path.split(separator: "/").last.map(String.init) ?? path }

    var body: some View {
        KhungTaiCTW(trangThai: tt, thuLai: { Task { await tai() } }) { t in
            if t.tooLarge == true {
                CTWOTrong(bieuTuong: "doc.badge.ellipsis", tieuDe: String(localized: "This file is too large to show"),
                          moTa: String(localized: "Files over 1 MB aren't shown in CT Work (this one is \(CTWCodeChu.coTep(t.size)))."),
                          nut: t.webUrl != nil ? String(localized: "Open in Safari") : nil, hanhDong: t.webUrl.flatMap(URL.init(string:)).map { u in { moUrl(u) } })
                    .frame(maxHeight: .infinity)
            } else if t.binary == true || t.content == nil {
                CTWOTrong(bieuTuong: "doc.zipper", tieuDe: String(localized: "Binary file"),
                          moTa: String(localized: "\(ten) (\(CTWCodeChu.coTep(t.size))) isn't a text file, so it can't be shown here."),
                          nut: t.webUrl != nil ? String(localized: "Open in Safari") : nil, hanhDong: t.webUrl.flatMap(URL.init(string:)).map { u in { moUrl(u) } })
                    .frame(maxHeight: .infinity)
            } else {
                KhungMaCTW(noiDung: t.content ?? "", tenTep: ten, xuongDong: xuongDong)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle(isOn: $xuongDong) { Label("Wrap lines", systemImage: "text.word.spacing") }
                    if let c = tt.giaTri?.content { Button { CTW.chepVaoBoNho(c) } label: { Label("Copy file", systemImage: "doc.on.doc") } }
                    Button { CTW.chepVaoBoNho(path) } label: { Label("Copy path", systemImage: "link") }
                    Button { moLichSu = true } label: {
                        Label("File history", systemImage: "clock.arrow.circlepath")
                    }
                    if let s = tt.giaTri?.webUrl, let u = URL(string: s) {
                        Button { moUrl(u) } label: { Label("Open in Safari", systemImage: "safari") }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("File options")
            }
        }
        .navigationDestination(isPresented: $moLichSu) { LichSuCommitCTW(pid: pid, ref: ref, path: path) }
        .task { await tai() }
    }

    private func tai() async {
        do {
            let t: CTWCodeTep = try await APIClient.shared.request(CTWAPI.codeTep(pid: pid, ref: ref, path: path))
            tt = .xong(t)
        } catch {
            tt = .loi(CTW.loi(error))
        }
    }
}

/// Khung mã: số dòng + tô màu đơn giản. `LazyVStack` ⇒ tệp 1 MB (hàng chục nghìn dòng) vẫn cuộn mượt.
struct KhungMaCTW: View {
    let dong: [Substring]
    let ngonNgu: ToMauMaCTW.NgonNgu
    let xuongDong: Bool

    init(noiDung: String, tenTep: String, xuongDong: Bool) {
        var d = noiDung.split(separator: "\n", omittingEmptySubsequences: false)
        if d.last == "" { d.removeLast() }
        self.dong = d
        self.ngonNgu = ToMauMaCTW.ngonNgu(tenTep)
        self.xuongDong = xuongDong
    }

    var body: some View {
        let rongSo = CGFloat(String(max(dong.count, 1)).count) * 9 + 12
        let cuon = ScrollView(xuongDong ? .vertical : [.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(dong.enumerated()), id: \.offset) { i, d in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(i + 1)").font(.ctw(size: 12).monospacedDigit().monospaced())
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: rongSo, alignment: .trailing)
                            .accessibilityHidden(true)
                        Text(ToMauMaCTW.dong(String(d.replacingOccurrences(of: "\t", with: "    ")), ngonNgu))
                            .font(.ctw(size: 12.5).monospaced())
                            .fixedSize(horizontal: !xuongDong, vertical: true)
                            .frame(maxWidth: xuongDong ? .infinity : nil, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Line \(i + 1): \(d)")
                }
            }
            .padding(.vertical, 10)
            .padding(.trailing, 12)
        }
        cuon.background(AppColors.backgroundCard)
    }
}

// MARK: - Tô màu đơn giản (theo dòng)
//
// Không phải bộ phân tích cú pháp: chú thích dòng, chuỗi, số, từ khoá phổ biến. Đủ để đọc mã trên điện thoại.
// Mỗi dòng tô độc lập (dòng nào cũng tô được khi `LazyVStack` dựng lười) — chú thích khối nhiều dòng chỉ nhận
// được dòng bắt đầu bằng `/*`, `*`, `*/`.

enum ToMauMaCTW {
    struct NgonNgu {
        var chuThich: [String]
        var tuKhoa: Set<String>
        /// SQL: từ khoá không phân biệt hoa thường.
        var khongPhanBietHoa = false
    }

    static let mauTuKhoa = Color.theoCheDo(sang: Color(hex: 0x8250DF), toi: Color(hex: 0xD2A8FF))
    static let mauChuoi = Color.theoCheDo(sang: Color(hex: 0x0A6E31), toi: Color(hex: 0x7EE787))
    static let mauChuThich = Color.theoCheDo(sang: Color(hex: 0x5F6670), toi: Color(hex: 0x8B949E))
    static let mauSo = Color.theoCheDo(sang: Color(hex: 0x0550AE), toi: Color(hex: 0x79C0FF))

    private static let chung: Set<String> = [
        "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "try", "catch",
        "finally", "throw", "throws", "new", "class", "struct", "enum", "interface", "extends", "implements", "import",
        "export", "from", "package", "public", "private", "protected", "static", "final", "const", "let", "var", "func",
        "function", "async", "await", "this", "self", "super", "null", "nil", "true", "false", "void", "int", "string",
        "bool", "boolean", "type", "typeof", "instanceof", "in", "of", "as", "is", "extension", "protocol", "guard",
        "override", "abstract", "def", "lambda", "yield", "with", "pass", "None", "True", "False", "elif", "not", "and",
        "or", "fn", "mut", "impl", "pub", "use", "mod", "go", "defer", "chan", "select", "namespace", "using", "readonly",
    ]
    private static let sql: Set<String> = [
        "select", "from", "where", "insert", "into", "values", "update", "set", "delete", "create", "table", "alter", "drop",
        "primary", "key", "foreign", "references", "join", "left", "right", "inner", "outer", "on", "group", "by", "order",
        "having", "limit", "and", "or", "not", "null", "as", "distinct", "index", "unique", "default", "int", "varchar",
        "text", "boolean", "timestamp", "begin", "commit", "rollback", "case", "when", "then", "else", "end", "union",
    ]

    static func ngonNgu(_ ten: String) -> NgonNgu {
        let e = (ten as NSString).pathExtension.lowercased()
        switch e {
        case "py", "rb", "sh", "bash", "zsh", "yml", "yaml", "toml", "r", "pl", "conf", "dockerfile", "mk":
            return NgonNgu(chuThich: ["#"], tuKhoa: chung)
        case "sql": return NgonNgu(chuThich: ["--"], tuKhoa: sql, khongPhanBietHoa: true)
        case "lua", "hs": return NgonNgu(chuThich: ["--"], tuKhoa: chung)
        case "md", "txt", "json", "csv", "lock", "": return NgonNgu(chuThich: [], tuKhoa: [])
        case "html", "xml", "svg", "plist", "vue": return NgonNgu(chuThich: [], tuKhoa: [])
        case "css", "scss", "less": return NgonNgu(chuThich: ["//"], tuKhoa: [])
        default: return NgonNgu(chuThich: ["//"], tuKhoa: chung)
        }
    }

    static func dong(_ s: String, _ nn: NgonNgu) -> AttributedString {
        var a = AttributedString(s)
        a.foregroundColor = AppColors.textPrimary
        // Dòng rất dài (mã nén) ⇒ không tô, đỡ tốn CPU.
        guard s.count <= 600 else { return a }
        let gon = s.trimmingCharacters(in: .whitespaces)
        if nn.chuThich.contains("//"), gon.hasPrefix("/*") || gon.hasPrefix("*") || gon.hasPrefix("*/") {
            a.foregroundColor = mauChuThich
            return a
        }
        let ky = Array(s)
        var i = 0
        var vung: [(Int, Int, Color)] = []
        while i < ky.count {
            let c = ky[i]
            // Chú thích tới hết dòng.
            if nn.chuThich.contains(where: { batDau(ky, i, $0) }) {
                vung.append((i, ky.count, mauChuThich))
                break
            }
            if c == "\"" || c == "'" || c == "`" {
                var j = i + 1
                while j < ky.count, ky[j] != c { j += ky[j] == "\\" ? 2 : 1 }
                let het = min(j + 1, ky.count)
                vung.append((i, het, mauChuoi))
                i = het
                continue
            }
            if c.isNumber, i == 0 || !(ky[i - 1].isLetter || ky[i - 1] == "_") {
                var j = i
                while j < ky.count, ky[j].isNumber || ky[j] == "." || ky[j] == "_" || ky[j] == "x" || ky[j].isHexDigit { j += 1 }
                vung.append((i, j, mauSo))
                i = j
                continue
            }
            if c.isLetter || c == "_" {
                var j = i
                while j < ky.count, ky[j].isLetter || ky[j].isNumber || ky[j] == "_" { j += 1 }
                let tu = String(ky[i..<j])
                if nn.tuKhoa.contains(nn.khongPhanBietHoa ? tu.lowercased() : tu) {
                    vung.append((i, j, mauTuKhoa))
                }
                i = j
                continue
            }
            i += 1
        }
        for (dau, cuoi, mau) in vung {
            let lo = a.index(a.startIndex, offsetByCharacters: dau)
            let hi = a.index(a.startIndex, offsetByCharacters: cuoi)
            a[lo..<hi].foregroundColor = mau
        }
        return a
    }

    private static func batDau(_ ky: [Character], _ i: Int, _ tien: String) -> Bool {
        let t = Array(tien)
        guard i + t.count <= ky.count else { return false }
        for k in 0..<t.count where ky[i + k] != t[k] { return false }
        // `#` của Python/Shell; nhưng trong `//` loại `://` (URL trong chuỗi đã bị bắt ở nhánh chuỗi).
        if tien == "//", i > 0, ky[i - 1] == ":" { return false }
        return true
    }
}

// MARK: - Lịch sử commit (nhánh / một tệp)

struct LichSuCommitCTW: View {
    let pid: Int
    let ref: String?
    let path: String?
    @State private var tt: TaiCTW<CTWCodeDSCommit> = .dangTai

    var body: some View {
        KhungTaiCTW(trangThai: tt, thuLai: { Task { await tai() } }) { r in
            if r.items.isEmpty {
                CTWOTrong(bieuTuong: "clock.arrow.circlepath", tieuDe: String(localized: "No commits found")).frame(maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(r.items) { c in
                            NavigationLink(value: RouteCodeCTW(pid: pid, ref: ref, loai: .commit(c.sha))) {
                                HStack(alignment: .top, spacing: 10) {
                                    CTWAvatar(user: c.author?.user, size: 26)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(c.dongDau).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        HStack(spacing: 6) {
                                            Text(String(c.sha.prefix(7))).font(.ctw(size: 11.5, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                                            Text("\(c.author?.ten ?? c.authorName ?? String(localized: "unknown")) · \(CTW.thoiDiem(c.at))")
                                                .font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    } header: { Text(path ?? (r.ref ?? ref ?? "")).textCase(nil).lineLimit(1).truncationMode(.head) }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(path == nil ? "History" : "File history")
        .navigationBarTitleDisplayMode(.inline)
        .task { await tai() }
        .refreshable { await tai() }
    }

    private func tai() async {
        do {
            let r: CTWCodeDSCommit = try await APIClient.shared.request(CTWAPI.codeLichSu(pid: pid, ref: ref, path: path))
            tt = .xong(r)
        } catch {
            if tt.giaTri == nil { tt = .loi(CTW.loi(error)) }
        }
    }
}

// MARK: - Một commit: thông điệp + số liệu + diff từng tệp

struct ChiTietCommitCTW: View {
    let pid: Int
    let sha: String
    @State private var tt: TaiCTW<CTWCodeChiTietCommit> = .dangTai
    @State private var moTep: Set<String> = []
    @Environment(\.openURL) private var moUrl

    var body: some View {
        KhungTaiCTW(trangThai: tt, thuLai: { Task { await tai() } }) { c in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(c.message ?? "").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        HStack(spacing: 6) {
                            CTWAvatar(user: c.author?.user, size: 20)
                            Text("\(c.author?.ten ?? c.authorName ?? String(localized: "unknown")) · \(CTW.thoiDiem(c.at))")
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        HStack(spacing: 12) {
                            Text(String(c.sha.prefix(10))).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                            Text("+\(c.stats?.additions ?? 0)").foregroundColor(AppColors.success)
                            Text("−\(c.stats?.deletions ?? 0)").foregroundColor(AppColors.error)
                            Text("\(c.stats?.files ?? c.files?.count ?? 0) files").foregroundColor(AppColors.textTertiary)
                        }
                        .font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                        let so = (c.issues ?? [:]).values.map(\.number).sorted()
                        HangChipTheCodeCTW(pid: pid, so: so, the: c.issues ?? [:], dungLink: true)
                    }
                    .padding(.vertical, 4)
                }
                if c.truncated == true {
                    Section {
                        Label("This commit is large — some changes are not shown here.", systemImage: "exclamationmark.triangle")
                            .font(.ctw(size: 13)).foregroundColor(AppColors.warning)
                    }
                }
                Section {
                    ForEach(c.files ?? []) { f in
                        DisclosureGroup(isExpanded: Binding(get: { moTep.contains(f.filename) }, set: { v in
                            if v { moTep.insert(f.filename) } else { moTep.remove(f.filename) }
                        })) {
                            if let p = f.patch, !p.isEmpty {
                                KhungDiffCTW(patch: p)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            } else {
                                Text(f.truncated == true ? "This diff is too large to show." : "No text changes (binary file or rename).")
                                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: bieuTuong(f.status)).foregroundColor(mau(f.status)).font(.ctw(size: 13, weight: .semibold))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.filename).font(.ctw(size: 13, weight: .medium).monospaced()).foregroundColor(AppColors.textPrimary)
                                        .lineLimit(2).truncationMode(.head)
                                    if let p = f.previous { Text("renamed from \(p)").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1) }
                                }
                                Spacer(minLength: 0)
                                Text("+\(f.additions ?? 0) −\(f.deletions ?? 0)").font(.ctw(size: 11.5, weight: .semibold).monospacedDigit())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(f.filename), \(f.status ?? "modified"), \(f.additions ?? 0) additions, \(f.deletions ?? 0) deletions")
                        }
                    }
                } header: { Text("Changed files") }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Commit \(String(sha.prefix(7)))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let s = tt.giaTri?.url, let u = URL(string: s) {
                ToolbarItem(placement: .primaryAction) {
                    Button { moUrl(u) } label: { Image(systemName: "safari") }.accessibilityLabel("Open commit in Safari")
                }
            }
        }
        .task {
            await tai()
            // Mở sẵn tệp đầu (commit nhỏ thường chỉ một hai tệp).
            if let f = tt.giaTri?.files?.first, moTep.isEmpty { moTep.insert(f.filename) }
        }
    }

    private func tai() async {
        do {
            let c: CTWCodeChiTietCommit = try await APIClient.shared.request(CTWAPI.codeCommit(pid: pid, sha: sha))
            tt = .xong(c)
        } catch {
            if tt.giaTri == nil { tt = .loi(CTW.loi(error)) }
        }
    }

    private func bieuTuong(_ s: String?) -> String {
        switch s {
        case "added": return "plus.square.fill"
        case "removed", "deleted": return "minus.square.fill"
        case "renamed": return "arrow.right.square.fill"
        default: return "square.and.pencil"
        }
    }
    private func mau(_ s: String?) -> Color {
        switch s {
        case "added": return AppColors.success
        case "removed", "deleted": return AppColors.error
        default: return AppColors.warning
        }
    }
}

/// Diff hợp nhất: dòng `+` nền xanh, `-` nền đỏ, `@@` xanh dương. Cuộn ngang (diff không xuống dòng).
struct KhungDiffCTW: View {
    let patch: String

    var body: some View {
        let dong = patch.split(separator: "\n", omittingEmptySubsequences: false)
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(dong.prefix(3000).enumerated()), id: \.offset) { _, d in
                    Text(d.isEmpty ? " " : String(d))
                        .font(.ctw(size: 12).monospaced())
                        .foregroundColor(d.hasPrefix("@@") ? AppColors.info : AppColors.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10).padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(nen(d))
                        .accessibilityLabel(nhan(d))
                }
                if dong.count > 3000 {
                    Text("… \(dong.count - 3000) more lines").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).padding(10)
                }
            }
            .padding(.vertical, 6)
        }
        .background(AppColors.backgroundCard)
    }

    private func nen(_ d: Substring) -> Color {
        if d.hasPrefix("+") { return AppColors.success.opacity(0.14) }
        if d.hasPrefix("-") { return AppColors.error.opacity(0.13) }
        if d.hasPrefix("@@") { return AppColors.info.opacity(0.08) }
        return .clear
    }
    private func nhan(_ d: Substring) -> String {
        if d.hasPrefix("+") { return String(localized: "Added: \(String(d.dropFirst()))") }
        if d.hasPrefix("-") { return String(localized: "Removed: \(String(d.dropFirst()))") }
        return String(d)
    }
}
