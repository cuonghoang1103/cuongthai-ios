import SwiftUI

// MARK: - List (danh sách thẻ theo JQL) — 21/10/2026, ngang web `table/DataTable.tsx` + `search/JqlInput.tsx` + `SavedFilters.tsx`
//
//   · Ô JQL phông đơn cách, Return để chạy, GỢI Ý trường/toán tử/giá trị khi gõ (`CTWJql.goiY`, port web `jql.ts`).
//     Con trỏ coi như ở CUỐI ô (TextField iOS 17 không cho đọc vị trí con trỏ) — đúng với cách gõ trên điện thoại.
//   · Bộ lọc cơ bản (bảng `BoLocCTW`) ⇒ dựng JQL như web `basicToJql` — luôn gửi TÊN GỐC (không bản dịch).
//   · Bộ lọc đã lưu: liệt kê / áp / lưu / xoá (`GET/POST/DELETE /projects/:pid/filters`).
//   · Sắp xếp: viết lại `ORDER BY` (web `withOrder`). Cột: điện thoại chọn trường phụ nào hiện dưới tiêu đề (nhớ máy).
//   · Đổi trạng thái tại chỗ (menu trên chip trạng thái — chỉ bước quy trình cho phép). Xuất CSV (`GET /export?format=csv`).
//   · Chọn nhiều + thanh sửa hàng loạt (chung Board/Backlog).

@MainActor
final class DanhSachVM: ObservableObject {
    let pid: Int
    @Published var cauHinh: CTWProjectConfig?
    @Published var ds: [CTWIssueCard] = []
    @Published var tong = 0
    @Published var loi: String?
    @Published var loiJql: String?
    @Published var dangTai = false
    @Published var dangGui = false
    @Published var bao: String?
    @Published var boLoc: [CTWBoLocLuu] = []
    /// Câu JQL vừa chạy (để biết lỗi đang nói về câu nào, và để xuất CSV đúng tập đang xem).
    @Published var daChay = ""

    init(pid: Int) { self.pid = pid }

    func taiCauHinh() async {
        guard cauHinh == nil else { return }
        do { cauHinh = try await APIClient.shared.request(.workDuAn(pid: pid)) } catch { loi = CTW.loi(error) }
    }

    func chay(_ jql: String) async {
        await taiCauHinh()
        dangTai = true
        defer { dangTai = false }
        daChay = jql
        do {
            let r: CTWKetQuaJql = try await APIClient.shared.request(CTWAPI.timTheoJql(pid: pid, jql: jql, limit: 100))
            ds = r.items ?? []
            tong = r.total ?? ds.count
            loiJql = nil
            loi = nil
        } catch {
            if case APIError.coMa(let ma, let m) = error, ma == "WORK_JQL_ERROR" { loiJql = m } else { loi = CTW.loi(error) }
        }
    }

    var conTiep: Bool { ds.count < tong }

    func taiThem() async {
        guard conTiep, !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        if let r: CTWKetQuaJql = try? await APIClient.shared.request(CTWAPI.timTheoJql(pid: pid, jql: daChay, limit: 100, offset: ds.count)) {
            let co = Set(ds.map(\.id))
            ds += (r.items ?? []).filter { !co.contains($0.id) }
        }
    }

    func taiBoLoc() async {
        if let d: [CTWBoLocLuu] = try? await APIClient.shared.request(CTWAPI.boLocDaLuu(pid: pid)) { boLoc = d }
    }

    func luuBoLoc(ten: String, chiaSe: Bool, jql: String) async -> Bool {
        do {
            let f: CTWBoLocLuu = try await APIClient.shared.request(CTWAPI.luuBoLoc(pid: pid, ten: ten, jql: jql, chiaSe: chiaSe))
            bao = String(localized: "Saved filter “\(f.name)”")
            await taiBoLoc()
            return true
        } catch {
            if case APIError.coMa(let ma, let m) = error, ma == "WORK_JQL_ERROR" { loiJql = m } else { loi = CTW.loi(error) }
            return false
        }
    }

    func xoaBoLoc(_ f: CTWBoLocLuu) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaBoLoc(pid: pid, id: f.id))
            boLoc.removeAll { $0.id == f.id }
            bao = String(localized: "Deleted filter “\(f.name)”")
        } catch { loi = CTW.loi(error) }
    }

    /// Đổi trạng thái tại chỗ — đổi trên máy trước, hỏng thì trả lại.
    func chuyen(_ t: CTWIssueCard, sang st: Int) async {
        guard let i = ds.firstIndex(where: { $0.id == t.id }) else { return }
        let cu = ds[i]
        ds[i].statusId = st
        var than: [String: Any] = ["statusId": st]
        if let v = t.version { than["version"] = v }
        do {
            try await APIClient.shared.send(.workChuyenThe(pid: pid, so: t.number, than: than))
            CTWRung.thanhCong()
            if let j = ds.firstIndex(where: { $0.id == t.id }) { ds[j].version = (cu.version ?? 0) + 1 }
        } catch {
            if let j = ds.firstIndex(where: { $0.id == t.id }) { ds[j] = cu }
            loi = CTW.loi(error)
            CTWRung.loi()
        }
    }

    func xuatCsv() async -> URL? {
        dangGui = true
        defer { dangGui = false }
        do {
            let d = try await APIClient.shared.requestRaw(CTWAPI.xuatCsv(pid: pid, jql: daChay))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(cauHinh?.key ?? "issues")-issues-\(CTW.tenTepTheoGio()).csv")
            try d.write(to: url)
            return url
        } catch {
            loi = CTW.loi(error)
            return nil
        }
    }

    func hangLoat(_ chon: [CTWIssueCard], patch: [String: Any]?, tenTrangThai: String?, nhan: String) async -> Set<Int> {
        guard let cfg = cauHinh, !chon.isEmpty else { return [] }
        dangGui = true
        defer { dangGui = false }
        do {
            let kq = try await CTWHangLoat.apDung(pid: pid, cfg: cfg, the: chon, patch: patch, tenTrangThai: tenTrangThai)
            let cau = CTWBaoHangLoat.cau(kq, nhan: nhan, ma: cfg.key)
            bao = cau.thanhCong
            loi = cau.loi
            await chay(daChay)
            let hong = Set((kq.failed ?? []).map(\.number))
            return Set(chon.filter { hong.contains($0.number) }.map(\.id))
        } catch {
            loi = CTW.loi(error)
            return Set(chon.map(\.id))
        }
    }
}

/// Trường phụ hiện dưới tiêu đề (điện thoại không đủ chỗ cho bảng nhiều cột như web).
enum CotDanhSachCTW: String, CaseIterable, Identifiable {
    case assignee, priority, due, points, sprint, labels, updated
    var id: String { rawValue }
    var ten: LocalizedStringKey {
        switch self {
        case .assignee: return "Assignee"
        case .priority: return "Priority"
        case .due: return "Due date"
        case .points: return "Story points"
        case .sprint: return "Sprint"
        case .labels: return "Labels"
        case .updated: return "Updated"
        }
    }
    static let macDinh = "assignee,priority,due,points"
}

struct DanhSachCTW: View {
    let pid: Int
    @StateObject private var vm: DanhSachVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @AppStorage("ctw.list.cot") private var cotLuu = CotDanhSachCTW.macDinh
    @State private var jql = DanhSachCTW.jqlMacDinh
    @FocusState private var dangGo: Bool
    @State private var tamPhu: TamPhu?
    @State private var dangChon = false
    @State private var chon: Set<Int> = []
    @State private var hoiXoa = false
    @State private var xoaBoLoc: CTWBoLocLuu?
    @State private var tepXuat: URL?
    /// Bộ lọc cơ bản đang dựng câu JQL (mở lại bảng lọc giữ lựa chọn).
    @State private var coBan = CTWAPI.BoLoc()
    @State private var uuTien: Set<Int> = []

    enum TamPhu: String, Identifiable { case loc, luu, tao; var id: String { rawValue } }

    static let jqlMacDinh = "statusCategory != Done ORDER BY rank ASC"

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: DanhSachVM(pid: pid))
    }

    private var cot: Set<CotDanhSachCTW> { Set(cotLuu.split(separator: ",").compactMap { CotDanhSachCTW(rawValue: String($0)) }) }

    var body: some View {
        List {
            Section {
                oJql
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                if dangGo, let cfg = vm.cauHinh {
                    goiY(cfg)
                }
                if let l = vm.loiJql, vm.daChay == jql {
                    Label { Text(verbatim: l) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        .font(.ctw(size: 13)).foregroundColor(AppColors.error)
                        .listRowBackground(Color.clear)
                }
                if let loi = vm.loi {
                    CTWErrorBanner(text: loi) { vm.loi = nil }
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                hangCongCu
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            if let cfg = vm.cauHinh {
                Section {
                    if !vm.dangTai && vm.ds.isEmpty && vm.loiJql == nil {
                        Text("No issues match this query.").foregroundColor(AppColors.textSecondary)
                    }
                    ForEach(vm.ds) { t in hang(t, cfg) }
                    if vm.conTiep {
                        Button("Load more") { Task { await vm.taiThem() } }.frame(maxWidth: .infinity)
                    }
                } header: {
                    HStack {
                        vm.tong == 1 ? Text("1 issue") : Text("\(vm.tong) issues")
                        Spacer()
                        if vm.dangTai { ProgressView().controlSize(.small) }
                    }
                    .font(.ctw(size: 13, weight: .semibold))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.dangTai && vm.cauHinh == nil { CTWKhungTai(soHang: 6) } }
        .overlay(alignment: .top) {
            if let b = vm.bao {
                CTWDaiBao(chu: b).padding(.top, 6)
                    .task(id: b) { try? await Task.sleep(nanoseconds: 2_800_000_000); vm.bao = nil }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if dangChon, let cfg = vm.cauHinh {
                CTWThanhHangLoat(cauHinh: cfg, soChon: chon.count, dangGui: vm.dangGui, epics: nil,
                                 doiTrangThai: { ten in gui(nil, ten, String(localized: "moved to \(CTWTen.trangThai(ten))")) },
                                 sua: { p, n in gui(p, nil, n) },
                                 xoa: { hoiXoa = true },
                                 boChon: { dangChon = false; chon = [] })
            }
        }
        .confirmationDialog(chon.count == 1 ? Text("Delete 1 issue?") : Text("Delete \(chon.count) issues?"), isPresented: $hoiXoa, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { gui(["delete": true], nil, String(localized: "deleted")) }
        } message: { Text("Deleted issues go to the project trash.") }
        .confirmationDialog(Text("Delete this saved filter?"), isPresented: Binding(get: { xoaBoLoc != nil }, set: { if !$0 { xoaBoLoc = nil } }),
                            titleVisibility: .visible, presenting: xoaBoLoc) { f in
            Button("Delete “\(f.name)”", role: .destructive) { Task { await vm.xoaBoLoc(f) } }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { tamPhu = .loc } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                    .accessibilityLabel("Filters")
                Menu {
                    if vm.cauHinh?.coTheSua == true || vm.cauHinh?.coTheChuyen == true {
                        Button { dangChon.toggle(); if !dangChon { chon = [] } } label: {
                            Label(dangChon ? "Done selecting" : "Select issues", systemImage: "checkmark.circle")
                        }
                    }
                    Button { Task { tepXuat = await vm.xuatCsv() } } label: { Label("Export CSV", systemImage: "square.and.arrow.up") }
                } label: { Image(systemName: dangChon ? "checkmark.circle.fill" : "ellipsis.circle") }
                .accessibilityLabel("List options")
                if vm.cauHinh?.coTheTao == true && !dangChon {
                    Button { tamPhu = .tao } label: { Image(systemName: "plus") }.accessibilityLabel("Create issue")
                }
            }
        }
        .sheet(item: $tamPhu) { t in
            if let cfg = vm.cauHinh {
                switch t {
                case .loc:
                    BoLocCTW(cauHinh: cfg, loc: coBan, uuTien: uuTien, toi: app.currentUser?.id) { l, u in
                        coBan = l
                        uuTien = u
                        let q = Self.tuCoBan(l, uuTien: u, cfg: cfg, toi: app.currentUser?.id)
                        let o = CTWJql.thuTu(jql)
                        jql = o.truong.map { CTWJql.voiThuTu(q, truong: $0, giam: o.giam) } ?? q
                        Task { await vm.chay(jql) }
                    }
                case .luu:
                    LuuBoLocCTW(jql: jql) { ten, chiaSe in await vm.luuBoLoc(ten: ten, chiaSe: chiaSe, jql: jql) }
                case .tao:
                    CTWCreateIssueView(cauHinh: cfg, sprintId: nil) { _ in Task { await vm.chay(jql) } }
                }
            }
        }
        .ctwXemTep($tepXuat)
        .refreshable { await vm.chay(jql); await vm.taiBoLoc() }
        .task {
            if vm.daChay.isEmpty {
                await vm.chay(jql)
                await vm.taiBoLoc()
            }
            #if DEBUG
            // Màn thử: `SIMCTL_CHILD_CT_XEM_JQL="assignee = "` ⇒ điền sẵn + mở bàn phím để thấy gợi ý.
            if let q = ProcessInfo.processInfo.environment["CT_XEM_JQL"] {
                jql = q
                if ProcessInfo.processInfo.environment["CT_XEM_GO"] != nil {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    dangGo = true
                } else {
                    await vm.chay(q)
                }
            }
            #endif
        }
    }

    private func gui(_ patch: [String: Any]?, _ ten: String?, _ nhan: String) {
        let ds = vm.ds.filter { chon.contains($0.id) }
        Task {
            let hong = await vm.hangLoat(ds, patch: patch, tenTrangThai: ten, nhan: nhan)
            chon = hong
            if hong.isEmpty && patch?["delete"] != nil { dangChon = false }
        }
    }

    private func chay() {
        dangGo = false
        Task { await vm.chay(jql.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: Ô JQL + gợi ý

    private var oJql: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(verbatim: "JQL").font(.ctw(size: 11, weight: .bold).monospaced()).foregroundColor(AppColors.textTertiary)
                TextField("e.g. assignee = currentUser() AND statusCategory != Done", text: $jql, axis: .vertical)
                    .font(.ctw(size: 14, design: .monospaced))
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($dangGo)
                    .submitLabel(.search)
                    .onSubmit { chay() }
                    .onChange(of: jql) { _, moi in
                        // TextField nhiều dòng: Return chèn "\n" thay vì gửi ⇒ coi Return là "chạy".
                        if moi.contains("\n") { jql = moi.replacingOccurrences(of: "\n", with: " "); chay() }
                    }
                    .accessibilityLabel("JQL query")
                    .accessibilityIdentifier("list.jql")
                if !jql.isEmpty {
                    Button { jql = ""; dangGo = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary).frame(width: 30, height: 30)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear query")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(vm.loiJql != nil && vm.daChay == jql ? AppColors.error : (dangGo ? AppColors.primary : AppColors.border), lineWidth: dangGo ? 1.2 : 0.5))
            Button { chay() } label: {
                Image(systemName: "return").font(.ctw(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary))
                    .foregroundColor(AppColors.onPrimary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Run query")
        }
    }

    @ViewBuilder
    private func goiY(_ cfg: CTWProjectConfig) -> some View {
        let g = CTWJql.goiY(jql, caret: jql.count, CTWJql.NguCanh(cfg: cfg))
        ForEach(g.ds) { s in
            Button {
                let (moi, _) = CTWJql.chapNhan(s, text: jql, tu: g.tu, caret: jql.count)
                jql = moi
            } label: {
                HStack {
                    Text(verbatim: s.nhan).font(.ctw(size: 14, design: .monospaced)).foregroundColor(AppColors.textPrimary)
                    Spacer(minLength: 8)
                    if let m = s.moTa { Text(verbatim: m).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1) }
                }
                .frame(minHeight: 32)
            }
            .accessibilityHint(Text("Inserts this into the query"))
        }
    }

    // MARK: Hàng công cụ: bộ lọc đã lưu · sắp xếp · cột

    private var hangCongCu: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                menuBoLocLuu
                menuSapXep
                menuCot
                if jql != Self.jqlMacDinh {
                    Button { jql = Self.jqlMacDinh; coBan = CTWAPI.BoLoc(); uuTien = []; chay() } label: {
                        Text("Reset").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.primary)
                            .fixedSize().padding(.horizontal, 6).frame(minHeight: 36)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ ten: LocalizedStringKey, _ bieuTuong: String, bat: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: bieuTuong).font(.ctw(size: 12, weight: .semibold))
            Text(ten).font(.ctw(size: 13, weight: .medium)).fixedSize()
            Image(systemName: "chevron.down").font(.ctw(size: 9, weight: .bold)).opacity(0.6)
        }
        .foregroundColor(bat ? AppColors.primary : AppColors.textPrimary)
        .padding(.horizontal, 11).frame(minHeight: 36)
        .background(Capsule().fill(bat ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard))
        .overlay(Capsule().strokeBorder(bat ? AppColors.primary.opacity(0.35) : AppColors.border, lineWidth: 0.5))
    }

    private var menuBoLocLuu: some View {
        let dangDung = vm.boLoc.first { $0.query == jql }
        let cuaToi = vm.boLoc.filter { $0.ownerId == app.currentUser?.id }
        return Menu {
            if vm.boLoc.isEmpty { Text("No saved filters yet") }
            ForEach(vm.boLoc) { f in
                Button { jql = f.query; chay() } label: {
                    Label {
                        if f.shared == true { Text("\(f.name) · shared by \(f.owner?.username ?? "")") } else { Text(verbatim: f.name) }
                    } icon: { Image(systemName: f.query == jql ? "checkmark" : (f.shared == true ? "person.2" : "line.3.horizontal.decrease")) }
                }
            }
            Divider()
            Button { tamPhu = .luu } label: { Label("Save current query…", systemImage: "square.and.arrow.down") }
                .disabled(jql.trimmingCharacters(in: .whitespaces).isEmpty)
            if !cuaToi.isEmpty {
                Menu {
                    ForEach(cuaToi) { f in Button(role: .destructive) { xoaBoLoc = f } label: { Text(verbatim: f.name) } }
                } label: { Label("Delete a filter", systemImage: "trash") }
            }
        } label: {
            if let d = dangDung {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease").font(.ctw(size: 12, weight: .semibold))
                    Text(verbatim: d.name).font(.ctw(size: 13, weight: .medium)).lineLimit(1).fixedSize()
                    Image(systemName: "chevron.down").font(.ctw(size: 9, weight: .bold)).opacity(0.6)
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 11).frame(minHeight: 36)
                .background(Capsule().fill(AppColors.primary.opacity(0.10)))
                .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 0.5))
            } else {
                chip("Saved filters", "line.3.horizontal.decrease")
            }
        }
        .accessibilityIdentifier("list.saved")
    }

    private static let truongSapXep: [(String, LocalizedStringKey)] = [
        ("rank", "Rank"), ("key", "Key"), ("priority", "Priority"), ("updated", "Updated"), ("created", "Created"),
        ("due", "Due date"), ("status", "Status"), ("assignee", "Assignee"), ("summary", "Title"), ("points", "Story points"),
    ]

    private var menuSapXep: some View {
        let o = CTWJql.thuTu(jql)
        return Menu {
            Picker(selection: Binding(get: { o.truong ?? "" }, set: { t in jql = CTWJql.voiThuTu(jql, truong: t, giam: t == "updated" || t == "created" ? true : o.giam); chay() })) {
                ForEach(Self.truongSapXep, id: \.0) { f in Text(f.1).tag(f.0) }
            } label: { Text("Sort by") }
            if let t = o.truong {
                Divider()
                Picker(selection: Binding(get: { o.giam }, set: { g in jql = CTWJql.voiThuTu(jql, truong: t, giam: g); chay() })) {
                    Label("Ascending", systemImage: "arrow.up").tag(false)
                    Label("Descending", systemImage: "arrow.down").tag(true)
                } label: { Text("Order") }
            }
        } label: { chip("Sort", o.giam ? "arrow.down" : "arrow.up.arrow.down", bat: o.truong != nil) }
        .accessibilityIdentifier("list.sort")
    }

    private var menuCot: some View {
        Menu {
            ForEach(CotDanhSachCTW.allCases) { c in
                Toggle(isOn: Binding(get: { cot.contains(c) }, set: { b in
                    var s = cot
                    if b { s.insert(c) } else { s.remove(c) }
                    cotLuu = CotDanhSachCTW.allCases.filter { s.contains($0) }.map(\.rawValue).joined(separator: ",")
                })) { Text(c.ten) }
            }
        } label: { chip("Fields", "rectangle.split.3x1") }
        .accessibilityIdentifier("list.fields")
    }

    // MARK: Hàng

    @ViewBuilder
    private func hang(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        let da = chon.contains(t.id)
        HStack(alignment: .top, spacing: 10) {
            if dangChon {
                Image(systemName: da ? "checkmark.circle.fill" : "circle")
                    .font(.ctw(size: 20)).foregroundColor(da ? AppColors.primary : AppColors.textTertiary)
                    .padding(.top, 2)
            }
            Button {
                if dangChon {
                    CTWRung.chon()
                    if da { chon.remove(t.id) } else { chon.insert(t.id) }
                } else {
                    nganXep.duong.append(CTWRoute.the(pid: pid, so: t.number))
                }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        CTWTypeIcon(type: cfg.loai(t.typeId), size: 13)
                        Text(verbatim: "\(cfg.key)-\(t.number)").font(.ctw(size: 12, weight: .medium).monospaced())
                            .foregroundColor(AppColors.textSecondary).fixedSize()
                    }
                    Text(t.title).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading).lineLimit(3)
                    phu(t, cfg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            trangThaiTaiCho(t, cfg)
        }
        .padding(.vertical, 2)
        .accessibilityAddTraits(dangChon && da ? .isSelected : [])
    }

    /// Chip trạng thái là MENU đổi trạng thái tại chỗ (chỉ bước quy trình cho phép).
    @ViewBuilder
    private func trangThaiTaiCho(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        let hienTai = cfg.trangThai(t.statusId)
        if cfg.coTheChuyen && !dangChon {
            let dich = cfg.trangThaiDich(loai: t.typeId, tu: t.statusId).filter { $0.id != t.statusId }
            Menu {
                Section("Move to…") {
                    ForEach(dich) { s in
                        Button { Task { await vm.chuyen(t, sang: s.id) } } label: {
                            Label { Text(verbatim: CTWTen.trangThaiCau(s.name)) } icon: { Image(systemName: CTWBoardView.bieuTuongNhom(s.category)) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    CTWStatusChip(status: hienTai).fixedSize()
                    Image(systemName: "chevron.down").font(.ctw(size: 8, weight: .bold)).foregroundColor(AppColors.textTertiary)
                }
                .frame(minHeight: 44, alignment: .top)
            }
            .buttonStyle(.borderless)
            .disabled(dich.isEmpty)
            .accessibilityLabel(Text("Status: \(hienTai.map { CTWTen.trangThai($0.name) } ?? ""). Change status"))
        } else {
            CTWStatusChip(status: hienTai).fixedSize()
        }
    }

    @ViewBuilder
    private func phu(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        let c = cot
        let nhan = (cfg.labels ?? []).filter { (t.labelIds ?? []).contains($0.id) }
        let sprint = (cfg.sprints ?? []).first { $0.id == t.sprintId }
        if !c.isEmpty {
            FlowNgangCTW(spacing: 6) {
                if c.contains(.priority) { CTWPriorityIcon(priority: t.priority) }
                if c.contains(.assignee) {
                    if t.assigneeId != nil {
                        let u = cfg.thanhVien(t.assigneeId) ?? CTWUser(id: t.assigneeId ?? 0)
                        HStack(spacing: 4) {
                            CTWAvatar(user: u, size: 18)
                            Text(verbatim: u.ten).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                        }
                    } else {
                        Text("Unassigned").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
                if c.contains(.due) { CTWDueChip(dueDate: t.dueDate, xong: t.resolvedAt != nil) }
                if c.contains(.points), let sp = t.storyPoints { CTWPointsBadge(diem: sp) }
                if c.contains(.sprint), let s = sprint {
                    Label { Text(verbatim: s.name).lineLimit(1) } icon: { Image(systemName: "flag") }
                        .font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary)
                }
                if c.contains(.labels) { ForEach(nhan.prefix(3)) { CTWLabelChip(label: $0) } }
                if c.contains(.updated), let d = CTWBangNhom.thoiDiem(t.updatedAt) {
                    Text("Updated \(CTWDinhDang.tuongDoi(d))").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    // MARK: Bộ lọc cơ bản ⇒ JQL (web `basicToJql`) — TÊN GỐC, bọc nháy khi cần.

    static func tuCoBan(_ l: CTWAPI.BoLoc, uuTien: Set<Int>, cfg: CTWProjectConfig, toi: Int?) -> String {
        var p: [String] = []
        func ds(_ truong: String, _ xs: [String]) {
            guard !xs.isEmpty else { return }
            p.append(xs.count == 1 ? "\(truong) = \(xs[0])" : "\(truong) IN (\(xs.joined(separator: ", ")))")
        }
        ds("type", l.type.compactMap { cfg.loai($0)?.name }.map(CTWJql.boc))
        let ten = l.status.compactMap { cfg.trangThai($0)?.name }
        var thay = Set<String>()
        ds("status", ten.filter { thay.insert($0).inserted }.map(CTWJql.boc))
        if ten.isEmpty && !l.includeDone { p.append("statusCategory != Done") }
        ds("assignee", l.assignee.compactMap { id -> String? in
            if id == 0 { return "EMPTY" }
            if id == toi { return "currentUser()" }
            return cfg.thanhVien(id)?.username.map(CTWJql.boc)
        })
        ds("labels", l.label.compactMap { id in cfg.labels?.first { $0.id == id }?.name }.map(CTWJql.boc))
        let tenUT = ["Highest", "High", "Medium", "Low", "Lowest"]
        ds("priority", uuTien.sorted().compactMap { $0 >= 1 && $0 <= 5 ? tenUT[$0 - 1] : nil })
        if let s = l.sprint {
            if s == "backlog" { p.append("sprint IS EMPTY") }
            else if let id = Int(s), let sp = cfg.sprints?.first(where: { $0.id == id }) { p.append("sprint = \(CTWJql.boc(sp.name))") }
        }
        let q = l.q.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty { p.append("summary ~ \"\(q.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\"") }
        return p.joined(separator: " AND ")
    }
}

/// Bảng lưu bộ lọc: tên + chia sẻ với dự án.
private struct LuuBoLocCTW: View {
    let jql: String
    let luu: (String, Bool) async -> Bool
    @State private var ten = ""
    @State private var chiaSe = false
    @State private var dangLuu = false
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Filter name", text: $ten)
                    Toggle("Share with the project", isOn: $chiaSe)
                } footer: {
                    Text(verbatim: jql).font(.ctw(size: 12, design: .monospaced))
                }
            }
            .navigationTitle("Save filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dangLuu = true
                        Task {
                            if await luu(ten.trimmingCharacters(in: .whitespaces), chiaSe) { dong() }
                            dangLuu = false
                        }
                    }
                    .bold()
                    .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangLuu)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Xếp con theo hàng ngang, tràn thì xuống dòng (trường phụ của hàng thẻ).
struct FlowNgangCTW: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rong = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, cao: CGFloat = 0, max: CGFloat = 0
        for s in subviews {
            let k = s.sizeThatFits(.unspecified)
            if x > 0 && x + k.width > rong { x = 0; y += cao + spacing; cao = 0 }
            x += k.width + spacing
            cao = Swift.max(cao, k.height)
            max = Swift.max(max, x - spacing)
        }
        return CGSize(width: Swift.min(max, rong), height: y + cao)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, cao: CGFloat = 0
        for s in subviews {
            let k = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + k.width > bounds.maxX { x = bounds.minX; y += cao + spacing; cao = 0 }
            s.place(at: CGPoint(x: x, y: y + (cao > 0 ? 0 : 0)), proposal: ProposedViewSize(k))
            x += k.width + spacing
            cao = Swift.max(cao, k.height)
        }
    }
}
