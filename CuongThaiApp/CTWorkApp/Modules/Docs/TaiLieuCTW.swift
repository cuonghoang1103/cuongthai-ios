import SwiftUI

// MARK: - Tài liệu (Docs) — cây trang, tìm, TẠO / ĐỔI TÊN / CHUYỂN / XOÁ
//
// `GET /projects/:pid/pages` trả danh sách PHẲNG (`parentId` = id trang cha,
// `position`) ⇒ app tự dựng cây. Tìm bằng `/pages/search?q=` (≥ 2 ký tự).
// Mô-đun Docs tắt ở dự án ⇒ máy chủ trả 403 MODULE_DISABLED — nói rõ, không
// hiện màn trống. Đọc/sửa một trang: `TrangTaiLieuCTW.swift`, `SuaTrangCTW.swift`.

@MainActor
final class TaiLieuVM: ObservableObject {
    let pid: Int
    @Published var ds: [CTWPageSummary]?
    @Published var ketQuaTim: [CTWPageHit]?
    @Published var loi: String?
    @Published var tatMoDun = false
    @Published var coTheSua = false
    @Published var coTheQuanLy = false

    init(pid: Int) { self.pid = pid }

    func tai() async {
        do {
            let r: CTWPagesList = try await APIClient.shared.request(CTWAPI.dsTrang(pid: pid))
            ds = r.pages ?? []
            coTheSua = r.canEdit == true
            coTheQuanLy = r.canManage == true
            loi = nil
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" { tatMoDun = true; return }
            loi = CTW.loi(error)
        }
    }

    func tim(_ q: String) async {
        let t = q.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { ketQuaTim = nil; return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        do { ketQuaTim = try await APIClient.shared.request(CTWAPI.timTrang(pid: pid, q: t)) } catch {
            if !Task.isCancelled { loi = CTW.loi(error) }
        }
    }

    /// Cây phẳng hoá: (trang, độ sâu), theo thứ tự `position`.
    var cay: [(trang: CTWPageSummary, sau: Int)] { Self.dungCay(ds ?? []) }

    nonisolated static func dungCay(_ ds: [CTWPageSummary]) -> [(trang: CTWPageSummary, sau: Int)] {
        let tatCa = ds.filter { $0.status != "ARCHIVED" }
        let ids = Set(tatCa.map(\.id))
        var con: [Int: [CTWPageSummary]] = [:]
        for p in tatCa {
            let cha = p.parentId.flatMap { ids.contains($0) ? $0 : nil } ?? 0
            con[cha, default: []].append(p)
        }
        var out: [(CTWPageSummary, Int)] = []
        func di(_ cha: Int, _ sau: Int) {
            for p in (con[cha] ?? []).sorted(by: { ($0.position ?? 0, $0.id) < ($1.position ?? 0, $1.id) }) {
                out.append((p, sau))
                if sau < 10 { di(p.id, sau + 1) }
            }
        }
        di(0, 0)
        return out.map { (trang: $0.0, sau: $0.1) }
    }

    /// Trang `id` và mọi hậu duệ — không được chuyển một trang vào chính cây con của nó.
    nonisolated static func hauDue(_ id: Int, trong ds: [CTWPageSummary]) -> Set<Int> {
        var out: Set<Int> = [id]
        var doi = [id]
        while let x = doi.popLast() {
            for p in ds where p.parentId == x && !out.contains(p.id) { out.insert(p.id); doi.append(p.id) }
        }
        return out
    }

    var trangLuuTru: [CTWPageSummary] { (ds ?? []).filter { $0.status == "ARCHIVED" } }

    // MARK: Ghi

    func tao(tieuDe: String, trangCha: Int?) async -> CTWPageDetail? {
        do {
            let t: CTWPageDetail = try await APIClient.shared.request(CTWAPI.taoTrang(pid: pid, tieuDe: tieuDe, trangCha: trangCha, markdown: nil))
            CTWRung.thanhCong()
            await tai()
            return t
        } catch { loi = CTW.loi(error); CTWRung.loi(); return nil }
    }

    /// Đổi tên: chốt collab rồi PATCH kèm `version` mới nhất — tránh ghi đè một lần
    /// đổi tên khác vừa xảy ra.
    func doiTen(so: Int, ten: String) async -> Bool {
        let t = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        do {
            _ = try? await APIClient.shared.send(CTWAPI.xaCollab(pid: pid, so: so))
            let ct: CTWPageDetail = try await APIClient.shared.request(CTWAPI.trang(pid: pid, so: so))
            let _: CTWPageDetail = try await APIClient.shared.request(CTWAPI.suaTrang(pid: pid, so: so, phienBan: ct.version, tieuDe: t))
            CTWRung.thanhCong()
            await tai()
            return true
        } catch { loi = CTW.loi(error); CTWRung.loi(); return false }
    }

    func chuyen(so: Int, trangCha: Int?) async {
        do {
            let r: CTWPagesList = try await APIClient.shared.request(CTWAPI.chuyenTrang(pid: pid, so: so, trangCha: trangCha))
            ds = r.pages ?? ds
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }

    func xoa(so: Int) async -> Bool {
        do {
            try await APIClient.shared.send(CTWAPI.xoaTrang(pid: pid, so: so))
            CTWRung.thanhCong()
            await tai()
            return true
        } catch { loi = CTW.loi(error); CTWRung.loi(); return false }
    }
}

/// Route con của mô-đun Docs (đăng ký ở `MoDunDocs.swift`).
struct RouteTaiLieuCTW: Hashable {
    var pid: Int
    var so: Int
    var ten: String
}
struct RouteLichSuTrangCTW: Hashable { var pid: Int; var so: Int; var ten: String; var quanLy: Bool }
struct RoutePhienBanTrangCTW: Hashable { var pid: Int; var so: Int; var n: Int; var quanLy: Bool }
struct RouteThungRacCTW: Hashable { var pid: Int }

struct TaiLieuCTW: View {
    let pid: Int
    @StateObject private var vm: TaiLieuVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""
    @State private var tamPhu: TamPhu?
    @State private var doiTen: CTWPageSummary?
    @State private var tenMoi = ""
    @State private var hoiXoa: CTWPageSummary?

    private enum TamPhu: Identifiable {
        case taoMoi(trangCha: CTWPageSummary?)
        case chuyen(CTWPageSummary)
        var id: String {
            switch self {
            case .taoMoi(let c): return "tao-\(c?.id ?? 0)"
            case .chuyen(let p): return "chuyen-\(p.id)"
            }
        }
    }

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: TaiLieuVM(pid: pid))
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if vm.tatMoDun {
                CTWOTrong(bieuTuong: "doc.text.magnifyingglass", tieuDe: "Docs are turned off",
                          moTa: "A project admin can turn Docs on in project settings.")
                    .listRowBackground(Color.clear)
            } else if let kq = vm.ketQuaTim {
                Section("Results") {
                    if kq.isEmpty { Text("No pages match “\(tim)”.").foregroundColor(AppColors.textSecondary) }
                    ForEach(kq) { h in
                        NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: h.number, ten: h.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(h.title).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                                if let s = h.snippet, !s.isEmpty {
                                    Text(s.replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else if vm.ds != nil {
                let cay = vm.cay
                if cay.isEmpty {
                    CTWOTrong(bieuTuong: "doc.text", tieuDe: "No pages yet",
                              moTa: vm.coTheSua ? "Write meeting notes, specs or a how-to — right from your phone."
                                                : "Pages your team writes show up here.",
                              nut: vm.coTheSua ? "New page" : nil,
                              hanhDong: vm.coTheSua ? { tamPhu = .taoMoi(trangCha: nil) } : nil)
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(cay, id: \.trang.id) { m in
                            NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: m.trang.number, ten: m.trang.title)) {
                                hang(m.trang, sau: m.sau)
                            }
                            .contextMenu { menuHang(m.trang) }
                        }
                    } header: {
                        Text("Pages · \(cay.count)")
                    }
                }
                if !vm.trangLuuTru.isEmpty {
                    Section("Archived") {
                        ForEach(vm.trangLuuTru) { p in
                            NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: p.number, ten: p.title)) { hang(p, sau: 0) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.ds == nil && vm.loi == nil && !vm.tatMoDun { CTWKhungTai(soHang: 5, coAvatar: false) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search pages")
        .task(id: tim) { await vm.tim(tim) }
        .navigationTitle("Docs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button { nganXep.duong.append(RouteThungRacCTW(pid: pid)) } label: { Label("Trash", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More")
                if vm.coTheSua {
                    Button { tamPhu = .taoMoi(trangCha: nil) } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("New page")
                }
            }
        }
        .refreshable { await vm.tai() }
        .task { if vm.ds == nil { await vm.tai() } }
        .onAppear { if vm.ds != nil { Task { await vm.tai() } } }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .taoMoi(let cha):
                TaoTrangCTW(dsTrang: vm.ds ?? [], chaMacDinh: cha) { tieuDe, so in
                    if let moi = await vm.tao(tieuDe: tieuDe, trangCha: so) {
                        nganXep.duong.append(RouteTaiLieuCTW(pid: pid, so: moi.number, ten: moi.title))
                        return true
                    }
                    return false
                }
            case .chuyen(let p):
                ChuyenTrangCTW(trang: p, dsTrang: vm.ds ?? []) { cha in await vm.chuyen(so: p.number, trangCha: cha) }
            }
        }
        .alert("Rename page", isPresented: Binding(get: { doiTen != nil }, set: { if !$0 { doiTen = nil } })) {
            TextField("Title", text: $tenMoi)
            Button("Rename") { if let p = doiTen { Task { _ = await vm.doiTen(so: p.number, ten: tenMoi) } } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete “\(hoiXoa?.title ?? "")”?", isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }),
                            titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { if let p = hoiXoa { Task { _ = await vm.xoa(so: p.number) } } }
        } message: { Text("The page and its subpages go to Trash. You can restore them from Docs › Trash.") }
        // Đích `/work/<ws>/<KEY>/docs/<số trang>` ⇒ mở trang.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "docs" else { return }
            defer { app.dichCho = nil }
            if let so = d.duongDan.phanCon.first.flatMap(Int.init) {
                nganXep.duong.append(RouteTaiLieuCTW(pid: pid, so: so, ten: "Page"))
            }
        }
        #if DEBUG
        .onAppear {
            let man = XemThuCTW.man?.lowercased()
            let con = XemThuCTW.conCua("docs")
            if (man == "trang" || con == "page" || con == "history" || con == "edit"), nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteTaiLieuCTW(pid: pid, so: 3, ten: "Release plan — v1.0"))
                if con == "history" { nganXep.duong.append(RouteLichSuTrangCTW(pid: pid, so: 3, ten: "Release plan — v1.0", quanLy: true)) }
            }
            if con == "new" { tamPhu = .taoMoi(trangCha: nil) }
        }
        #endif
    }

    private func hang(_ p: CTWPageSummary, sau: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: p.status == "ARCHIVED" ? "archivebox" : (sau == 0 ? "doc.text.fill" : "doc.text"))
                .foregroundColor(p.status == "ARCHIVED" ? AppColors.textTertiary : AppColors.primary).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.title).font(.system(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(CTWDocStatus.ten(p.status)).font(.system(size: 11, weight: .semibold))
                        .foregroundColor(p.status == "APPROVED" ? AppColors.success : AppColors.textSecondary)
                    if p.visibility == "CLIENT" {
                        Image(systemName: "person.2.wave.2").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                            .accessibilityLabel("Shared with client")
                    }
                    if p.aiAssisted == true { CTWNhanAI(chu: "AI-assisted") }
                    if let d = CTW.ngayNgan(p.updatedAt) {
                        Text("Updated \(d)").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(.leading, CGFloat(min(sau, 4)) * 14)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func menuHang(_ p: CTWPageSummary) -> some View {
        if vm.coTheSua {
            Button { tamPhu = .taoMoi(trangCha: p) } label: { Label("New subpage", systemImage: "doc.badge.plus") }
            Button { tenMoi = p.title; doiTen = p } label: { Label("Rename", systemImage: "pencil") }
            Button { tamPhu = .chuyen(p) } label: { Label("Move…", systemImage: "arrow.up.and.down.and.arrow.left.and.right") }
        }
        if vm.coTheQuanLy || (p.ownerId != nil && p.ownerId == app.currentUser?.id) {
            Button(role: .destructive) { hoiXoa = p } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

// MARK: - Tạo trang

struct TaoTrangCTW: View {
    let dsTrang: [CTWPageSummary]
    var chaMacDinh: CTWPageSummary?
    let tao: (String, Int?) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var tieuDe = ""
    @State private var cha: Int?
    @State private var dangTao = false
    @FocusState private var dangGo: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Page title", text: $tieuDe).focused($dangGo).font(.system(size: 17, weight: .semibold))
                }
                Section("Location") {
                    Picker("Parent page", selection: $cha) {
                        Text("Top level").tag(Int?.none)
                        ForEach(TaiLieuVM.dungCay(dsTrang), id: \.trang.id) { m in
                            Text(String(repeating: "   ", count: min(m.sau, 4)) + m.trang.title).tag(Int?.some(m.trang.number))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section {
                    Text("The page starts as a Draft. You can write it right after it's created.")
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            .navigationTitle("New page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dangTao = true
                        Task {
                            if await tao(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines), cha) { dong() }
                            dangTao = false
                        }
                    } label: { if dangTao { ProgressView() } else { Text("Create").bold() } }
                    .disabled(tieuDe.trimmingCharacters(in: .whitespaces).isEmpty || dangTao)
                }
            }
            .onAppear { cha = chaMacDinh?.number; dangGo = true }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Chuyển trang sang trang cha khác

struct ChuyenTrangCTW: View {
    let trang: CTWPageSummary
    let dsTrang: [CTWPageSummary]
    let chuyen: (Int?) async -> Void
    @Environment(\.dismiss) private var dong

    var body: some View {
        let cam = TaiLieuVM.hauDue(trang.id, trong: dsTrang)
        NavigationStack {
            List {
                Button { Task { await chuyen(nil); dong() } } label: {
                    Label("Top level", systemImage: "square.stack.3d.up")
                }
                Section("Inside another page") {
                    ForEach(TaiLieuVM.dungCay(dsTrang).filter { !cam.contains($0.trang.id) }, id: \.trang.id) { m in
                        Button { Task { await chuyen(m.trang.number); dong() } } label: {
                            HStack {
                                Image(systemName: "doc.text").foregroundColor(AppColors.primary)
                                Text(m.trang.title).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Spacer()
                                if m.trang.id == trang.parentId { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                            }
                            .padding(.leading, CGFloat(min(m.sau, 4)) * 14)
                        }
                    }
                }
            }
            .navigationTitle("Move “\(trang.title)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
        }
    }
}

// MARK: - Thùng rác trang

struct ThungRacTrangCTW: View {
    let pid: Int
    @State private var du: CTWTrashPages?
    @State private var loi: String?
    @State private var thongBao: String?

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi) { self.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if let ds = du?.items {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "trash", tieuDe: "Trash is empty", moTa: "Deleted pages stay here until an admin empties the trash.")
                        .listRowBackground(Color.clear)
                }
                ForEach(ds) { m in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text").foregroundColor(AppColors.textTertiary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(m.title).foregroundColor(AppColors.textPrimary).lineLimit(2)
                            Text(moTa(m)).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        if m.canRestore == true {
                            Button("Restore") { Task { await khoiPhuc(m) } }
                                .buttonStyle(.bordered).font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if du == nil && loi == nil { CTWKhungTai(soHang: 3, coAvatar: false) } }
        .navigationTitle("Trash")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if du == nil { await tai() } }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func moTa(_ m: CTWTrashPages.Muc) -> String {
        var p: [String] = []
        if let d = CTW.ngayNgan(m.deletedAt) { p.append("Deleted \(d)") }
        if let n = m.deletedBy?.name { p.append("by \(n)") }
        if let c = m.childCount, c > 0 { p.append("+\(c) subpage\(c == 1 ? "" : "s")") }
        return p.joined(separator: " ")
    }

    private func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.thungRacTrang(pid: pid)); loi = nil } catch { loi = CTW.loi(error) }
    }

    private func khoiPhuc(_ m: CTWTrashPages.Muc) async {
        do {
            let r: CTWTrashRestore = try await APIClient.shared.request(CTWAPI.khoiPhucTrang(pid: pid, so: m.number))
            CTWRung.thanhCong()
            thongBao = r.toTopLevel == true ? "Restored to the top level (its old parent is gone)." : "Page restored."
            await tai()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}
