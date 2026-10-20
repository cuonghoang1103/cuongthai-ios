import SwiftUI

// MARK: - CT Work — Bảng (board)
//
// Cột = `config.boardColumns` (mỗi cột gom nhiều trạng thái). Thẻ vào cột có
// `statusIds` chứa `statusId` của nó. Đổi cột bằng menu "Move to…" (giữ thẻ)
// hoặc kéo thả (iPhone lẫn iPad: cột đích sáng lên + rung nhẹ khi thẻ lơ lửng trên nó). Quy trình có thể CẤM một số bước chuyển — menu
// chỉ liệt kê bước hợp lệ, và câu từ chối của máy chủ vẫn hiện nguyên văn.
//
// Đợt B (21/10/2026) — ngang web:
//   · Bộ lọc (MỘT nút "Filters" như web đợt 8D): lọc nhanh (của tôi · cập nhật gần đây · hạn tuần này · chưa giao) + loại thẻ ·
//     người thực hiện · ưu tiên · nhãn · epic · bộ phận (mô-đun teams) · sprint. Logic thuần ở `CTWBangNhom.swift`.
//   · Nhóm theo (swimlane, web `grouping.ts`): người · epic · ưu tiên · việc con; gập từng làn / tất cả (nhớ theo dự án).
//   · Gập một cột (nhớ theo dự án) — cột gập thành dải hẹp, chạm để mở.
//   · Chọn nhiều + thanh sửa hàng loạt (`CTWThanhHangLoat`): trạng thái · sprint · giao · ưu tiên · nhãn · epic · xoá (hỏi lại).
// Tệp nằm ở Shared ⇒ app chính cũng biên dịch: chỉ dùng thứ của Shared (không `batMoDun`, không route của app CT Work).

@MainActor
final class CTWBoardVM: ObservableObject {
    let pid: Int
    @Published var cauHinh: CTWProjectConfig?
    @Published var bang: CTWBoardData?
    @Published var loi: String?
    @Published var dangTai = false
    /// Sprint đang xem; nil = sprint đang chạy (mặc định của máy chủ).
    @Published var sprintId: Int?
    /// Epic của dự án (id ⇒ số, tiêu đề) — epic thường KHÔNG nằm trên board, tải riêng (như web `board-epics`).
    @Published var epics: [Int: (so: Int, ten: String)] = [:]
    /// Bộ phận của không gian (chỉ khi dự án bật mô-đun teams).
    @Published var boPhan: [CTWBoPhan] = []
    @Published var dangGui = false
    @Published var bao: String?

    init(pid: Int) { self.pid = pid }

    func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            async let c: CTWProjectConfig = APIClient.shared.request(.workDuAn(pid: pid))
            async let b: CTWBoardData = APIClient.shared.request(.workBang(pid: pid, sprintId: sprintId))
            let (cc, bb) = try await (c, b)
            cauHinh = cc
            bang = bb
            loi = nil
        } catch {
            loi = CTW.loi(error)
            return
        }
        await taiPhu()
    }

    /// Epic + bộ phận — hỏng thì bỏ qua (chỉ thiếu bộ lọc/làn tương ứng, board vẫn chạy).
    func taiPhu() async {
        guard let cfg = cauHinh else { return }
        let loaiEpic = cfg.dsLoai.filter { $0.level == 1 }.map(\.id)
        if !loaiEpic.isEmpty {
            var l = CTWAPI.BoLoc()
            l.type = loaiEpic
            l.includeDone = true
            if let r: CTWIssueList = try? await APIClient.shared.request(CTWAPI.dsThe(pid: pid, loc: l, limit: 500)) {
                epics = Dictionary((r.items ?? []).map { ($0.id, (so: $0.number, ten: $0.title)) }, uniquingKeysWith: { a, _ in a })
            }
        }
        if cfg.modules?["teams"] == true, let ws = cfg.workspace?.id,
           let ds: [CTWBoPhan] = try? await APIClient.shared.request(CTWAPI.boPhanKhongGian(wsId: ws)) {
            boPhan = ds
        }
    }

    func napBang() async {
        do {
            bang = try await APIClient.shared.request(.workBang(pid: pid, sprintId: sprintId))
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    var cot: [CTWBoardColumn] { cauHinh?.boardColumns ?? [] }

    func the(trongCot c: CTWBoardColumn, tu ds: [CTWIssueCard]) -> [CTWIssueCard] {
        let ids = Set(c.statusIds ?? [])
        return ds.filter { ids.contains($0.statusId) }
    }

    /// Chuyển thẻ sang trạng thái mới — đổi trên máy TRƯỚC rồi gọi mạng,
    /// hỏng thì trả lại chỗ cũ.
    func chuyen(_ the: CTWIssueCard, sang statusId: Int) async {
        guard the.statusId != statusId, var ds = bang?.issues,
              let i = ds.firstIndex(where: { $0.id == the.id }) else { return }
        let cu = ds
        ds[i].statusId = statusId
        bang?.issues = ds
        var than: [String: Any] = ["statusId": statusId]
        if let v = the.version { than["version"] = v }
        do {
            try await APIClient.shared.send(.workChuyenThe(pid: pid, so: the.number, than: than))
            CTWRung.thanhCong()
            await napBang()   // lấy `version`/`rank` mới
        } catch {
            bang?.issues = cu
            loi = CTW.loi(error)
            CTWRung.loi()
            if CTW.laXungDot(error) { await napBang() }
        }
    }

    /// Kéo thả vào cột: chọn trạng thái hợp lệ ĐẦU TIÊN của cột đó. Làn là cách NHÌN — thả sang làn khác chỉ đổi
    /// trạng thái, thẻ ở lại làn của nó (như web).
    func tha(soThe: Int, vaoCot c: CTWBoardColumn) async -> Bool {
        guard let cfg = cauHinh, cfg.coTheChuyen,
              let the = bang?.issues?.first(where: { $0.number == soThe }) else { return false }
        if (c.statusIds ?? []).contains(the.statusId) { return false }
        guard let st = cfg.trangThaiTrongCot(c, loai: the.typeId, tu: the.statusId) else {
            loi = String(localized: "\(cfg.key)-\(the.number) can't move to \(CTWTen.trangThai(c.name)) — the workflow doesn't allow it.")
            return false
        }
        await chuyen(the, sang: st.id)
        return true
    }

    /// Sửa hàng loạt. Trả các thẻ HỎNG (giữ chọn để thử lại, như web).
    func hangLoat(_ ds: [CTWIssueCard], patch: [String: Any]?, tenTrangThai: String?, nhan: String) async -> Set<Int> {
        guard let cfg = cauHinh, !ds.isEmpty else { return [] }
        dangGui = true
        defer { dangGui = false }
        do {
            let kq = try await CTWHangLoat.apDung(pid: pid, cfg: cfg, the: ds, patch: patch, tenTrangThai: tenTrangThai)
            let cau = CTWBaoHangLoat.cau(kq, nhan: nhan, ma: cfg.key)
            bao = cau.thanhCong
            loi = cau.loi
            if cau.loi == nil { CTWRung.thanhCong() } else { CTWRung.loi() }
            await napBang()
            let hong = Set((kq.failed ?? []).map(\.number))
            return Set(ds.filter { hong.contains($0.number) }.map(\.id))
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
            return Set(ds.map(\.id))
        }
    }
}

struct CTWBoardView: View {
    let pid: Int
    let ten: String

    @StateObject private var vm: CTWBoardVM
    @EnvironmentObject private var appState: AppState
    @State private var moTao = false
    @State private var loc = CTWBoLocBang()
    @State private var timChu = ""
    /// Cột đang được kéo thẻ lơ lửng phía trên — tô sáng làm đích thả (khoá "<làn>|<cột>").
    @State private var cotDich: String?
    @State private var nhom: CTWNhomBang = .none
    @State private var cotGap: Set<String> = []
    @State private var lanGap: Set<String> = []
    @State private var dangChon = false
    @State private var chon: Set<Int> = []
    @State private var hoiXoa = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var beRong
    #endif

    init(pid: Int, ten: String) {
        self.pid = pid
        self.ten = ten
        _vm = StateObject(wrappedValue: CTWBoardVM(pid: pid))
    }

    private var rong: Bool {
        #if os(iOS)
        return beRong == .regular
        #else
        return true
        #endif
    }

    // MARK: Nhớ theo dự án (UserDefaults — đã khai CA92.1)

    private var khoa: String { "ctw.bang.\(pid)" }
    private func napNho() {
        let d = UserDefaults.standard
        nhom = d.string(forKey: khoa + ".nhom").flatMap(CTWNhomBang.init(rawValue:)) ?? .none
        cotGap = Set(d.stringArray(forKey: khoa + ".cotGap") ?? [])
        lanGap = Set(d.stringArray(forKey: khoa + ".lanGap") ?? [])
        #if DEBUG
        if let n = ProcessInfo.processInfo.environment["CT_XEM_NHOM"], let g = CTWNhomBang(rawValue: n) { nhom = g }
        if ProcessInfo.processInfo.environment["CT_XEM_CHON"] != nil { dangChon = true }
        #endif
    }
    private func luuNho() {
        let d = UserDefaults.standard
        d.set(nhom.rawValue, forKey: khoa + ".nhom")
        d.set(Array(cotGap), forKey: khoa + ".cotGap")
        d.set(Array(lanGap.prefix(200)), forKey: khoa + ".lanGap")
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
            }
            if let b = vm.bang, vm.cauHinh != nil {
                dauBang(b)
            }
            if vm.cauHinh != nil {
                if nhom == .none { cacCot } else { cacLan }
            } else if vm.loi == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .background(AppColors.backgroundPrimary)
        .overlay(alignment: .top) {
            if let b = vm.bao {
                CTWDaiBao(chu: b).padding(.top, 6).transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: b) { try? await Task.sleep(nanoseconds: 2_800_000_000); vm.bao = nil }
            }
        }
        .animation(.easeOut(duration: 0.2), value: vm.bao)
        .safeAreaInset(edge: .bottom) {
            if dangChon, let cfg = vm.cauHinh {
                CTWThanhHangLoat(cauHinh: cfg, soChon: chon.count, dangGui: vm.dangGui,
                                 epics: vm.epics.isEmpty ? nil : vm.epics.map { (id: $0.key, so: $0.value.so, ten: $0.value.ten) }.sorted { $0.so < $1.so },
                                 doiTrangThai: { ten in guiHangLoat(patch: nil, ten: ten, nhan: String(localized: "moved to \(CTWTen.trangThai(ten))")) },
                                 sua: { p, n in guiHangLoat(patch: p, ten: nil, nhan: n) },
                                 xoa: { hoiXoa = true },
                                 boChon: { dangChon = false; chon = [] })
            }
        }
        .confirmationDialog(chon.count == 1 ? Text("Delete 1 issue?") : Text("Delete \(chon.count) issues?"), isPresented: $hoiXoa, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { guiHangLoat(patch: ["delete": true], ten: nil, nhan: String(localized: "deleted")) }
        } message: {
            Text("Deleted issues go to the project trash.")
        }
        .searchable(text: $timChu, placement: .toolbar, prompt: "Filter issues")
        .navigationTitle(vm.cauHinh?.name ?? ten)
        .ctwTieuDeNho()
        .toolbar {
            // "Hiện dần" (19/10/2026): MỘT hành động chính nổi bật (+ tạo thẻ); bộ lọc trong MỘT menu "Filters" (như web
            // đợt 8D) — biểu tượng đặc khi đang lọc; cách xem (nhóm theo, chọn nhiều, gập) trong menu "View".
            ToolbarItemGroup(placement: .primaryAction) {
                menuLoc
                menuXem
                if vm.cauHinh?.coTheTao == true && !dangChon {
                    Button { moTao = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Create issue")
                }
            }
        }
        .sheet(isPresented: $moTao) {
            if let cfg = vm.cauHinh {
                CTWCreateIssueView(cauHinh: cfg, sprintId: vm.bang?.sprint?.id) { so in
                    Task { await vm.napBang() }
                    _ = so
                }
            }
        }
        .onAppear { if vm.cauHinh == nil { napNho() } }
        .onChange(of: nhom) { _, _ in luuNho() }
        .onChange(of: cotGap) { _, _ in luuNho() }
        .onChange(of: lanGap) { _, _ in luuNho() }
        .task { if vm.cauHinh == nil { await vm.tai() } }
    }

    private func guiHangLoat(patch: [String: Any]?, ten: String?, nhan: String) {
        let ds = (vm.bang?.issues ?? []).filter { chon.contains($0.id) }
        Task {
            let hong = await vm.hangLoat(ds, patch: patch, tenTrangThai: ten, nhan: nhan)
            chon = hong
            if hong.isEmpty && patch?["delete"] != nil { dangChon = false }
        }
    }

    // MARK: Lọc

    private var dangLoc: Bool { loc.soBat > 0 || vm.sprintId != nil }

    private var theoId: [Int: CTWIssueCard] {
        Dictionary((vm.bang?.issues ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func dsDaLoc() -> [CTWIssueCard] {
        let ds = vm.bang?.issues ?? []
        let tid = theoId
        let ep = Set(vm.epics.keys)
        let ct = CTWBangNhom.cuoiTuan()
        let q = timChu.trimmingCharacters(in: .whitespaces)
        let ma = vm.cauHinh?.key ?? ""
        return ds.filter { t in
            guard loc.khop(t, cfg: vm.cauHinh, toi: appState.currentUser?.id, epicCua: CTWBangNhom.epicCua(t, epics: ep, theoId: tid), cuoiTuan: ct) else { return false }
            return q.isEmpty || t.title.localizedCaseInsensitiveContains(q) || "\(ma)-\(t.number)".localizedCaseInsensitiveContains(q)
        }
    }

    private func bat(_ s: Binding<Set<Int>>, _ v: Int) -> Binding<Bool> {
        Binding(get: { s.wrappedValue.contains(v) }, set: { if $0 { s.wrappedValue.insert(v) } else { s.wrappedValue.remove(v) } })
    }

    private var menuLoc: some View {
        Menu {
            Section("Quick filters") {
                Toggle(isOn: $loc.chiCuaToi) { Label("Only my issues", systemImage: "person.crop.circle") }
                Toggle(isOn: $loc.ganDay) { Label("Recently updated", systemImage: "clock.arrow.circlepath") }
                Toggle(isOn: $loc.tuanNay) { Label("Due this week", systemImage: "calendar") }
                Toggle(isOn: $loc.chuaGiao) { Label("Unassigned", systemImage: "person.crop.circle.badge.questionmark") }
            }
            if let cfg = vm.cauHinh {
                Section {
                    menuLoaiThe(cfg)
                    menuNguoi(cfg)
                    Menu {
                        ForEach(CTW.doUuTien, id: \.so) { p in
                            Toggle(isOn: bat($loc.uuTien, p.so)) { Label(p.ten, systemImage: p.bieuTuong) }
                        }
                    } label: { Label("Priority", systemImage: "flag") }
                    if !(cfg.labels ?? []).isEmpty {
                        Menu {
                            ForEach(cfg.labels ?? []) { l in
                                Toggle(isOn: bat($loc.nhan, l.id)) { Text(verbatim: l.name) }
                            }
                        } label: { Label("Labels", systemImage: "tag") }
                    }
                    if !vm.epics.isEmpty {
                        Menu {
                            Toggle(isOn: bat($loc.epic, 0)) { Text("No epic") }
                            ForEach(vm.epics.sorted { $0.value.so < $1.value.so }, id: \.key) { e in
                                Toggle(isOn: bat($loc.epic, e.key)) { Text(verbatim: "\(cfg.key)-\(e.value.so) · \(e.value.ten)") }
                            }
                        } label: { Label("Epic", systemImage: "bolt") }
                    }
                    if !vm.boPhan.isEmpty {
                        Menu {
                            Toggle(isOn: bat($loc.boPhan, 0)) { Text("No team") }
                            ForEach(vm.boPhan) { b in Toggle(isOn: bat($loc.boPhan, b.id)) { Text(verbatim: b.name) } }
                        } label: { Label("Team", systemImage: "person.3") }
                    }
                    if cfg.type != "KANBAN" { menuSprint(cfg) }
                }
            }
            if dangLoc {
                Divider()
                Button(role: .destructive) { xoaLoc() } label: { Label("Clear all filters", systemImage: "xmark.circle") }
            }
        } label: {
            Image(systemName: dangLoc ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(dangLoc ? Text("Filters, \(loc.soBat + (vm.sprintId != nil ? 1 : 0)) active") : Text("Filters"))
        .accessibilityIdentifier("board.filters")
    }

    private func menuLoaiThe(_ cfg: CTWProjectConfig) -> some View {
        Menu {
            ForEach(cfg.dsLoai) { t in
                Toggle(isOn: bat($loc.loai, t.id)) { Label(CTWTen.loai(t.name), systemImage: CTW.bieuTuongLoai(t)) }
            }
        } label: { Label("Issue type", systemImage: "square.stack") }
    }

    private func menuNguoi(_ cfg: CTWProjectConfig) -> some View {
        Menu {
            Toggle(isOn: bat($loc.nguoi, 0)) { Text("Unassigned") }
            ForEach(cfg.dsThanhVien.sorted { $0.ten.localizedCaseInsensitiveCompare($1.ten) == .orderedAscending }) { u in
                Toggle(isOn: bat($loc.nguoi, u.id)) {
                    if u.id == appState.currentUser?.id { Text("\(u.ten) (me)") } else if u.laAgent { Text("\(u.ten) · AI agent") } else { Text(verbatim: u.ten) }
                }
            }
        } label: { Label("Assignee", systemImage: "person.2") }
    }

    private func xoaLoc() {
        loc = CTWBoLocBang()
        timChu = ""
        if vm.sprintId != nil {
            vm.sprintId = nil
            Task { await vm.napBang() }
        }
    }

    private func menuSprint(_ cfg: CTWProjectConfig) -> some View {
        let ds = (cfg.sprints ?? []).filter { $0.state != "CLOSED" }
        return Menu {
            Button {
                vm.sprintId = nil
                Task { await vm.napBang() }
            } label: {
                Label("Active sprint", systemImage: vm.sprintId == nil ? "checkmark" : "flag")
            }
            ForEach(ds) { s in
                Button {
                    vm.sprintId = s.id
                    Task { await vm.napBang() }
                } label: {
                    if s.state == "ACTIVE" {
                        Label { Text("\(s.name) (active)") } icon: { Image(systemName: vm.sprintId == s.id ? "checkmark" : "calendar") }
                    } else {
                        Label { Text(verbatim: s.name) } icon: { Image(systemName: vm.sprintId == s.id ? "checkmark" : "calendar") }
                    }
                }
            }
        } label: {
            Label("Sprint", systemImage: "flag")
        }
        .accessibilityLabel("Choose sprint")
        .disabled(ds.isEmpty)
    }

    // MARK: Menu "View": nhóm theo · chọn nhiều · gập

    private var menuXem: some View {
        Menu {
            Picker(selection: $nhom) {
                Text("No grouping").tag(CTWNhomBang.none)
                Text("Assignee").tag(CTWNhomBang.assignee)
                Text("Epic").tag(CTWNhomBang.epic)
                Text("Priority").tag(CTWNhomBang.priority)
                Text("Sub-tasks").tag(CTWNhomBang.subtasks)
            } label: {
                Label("Group by", systemImage: "rectangle.split.1x2")
            }
            .pickerStyle(.menu)
            if nhom != .none {
                Button { lanGap = Set(lanHienTai.map { "\(nhom.rawValue):\($0.lan.key)" }) } label: { Label("Collapse all lanes", systemImage: "rectangle.compress.vertical") }
                Button { lanGap = [] } label: { Label("Expand all lanes", systemImage: "rectangle.expand.vertical") }
            }
            if !cotGap.isEmpty {
                Button { cotGap = [] } label: { Label("Expand all columns", systemImage: "arrow.left.and.right") }
            }
            if vm.cauHinh?.coTheSua == true || vm.cauHinh?.coTheChuyen == true {
                Divider()
                Button {
                    dangChon.toggle()
                    if !dangChon { chon = [] }
                } label: {
                    Label(dangChon ? "Done selecting" : "Select issues", systemImage: dangChon ? "checkmark.circle.fill" : "checkmark.circle")
                }
            }
        } label: {
            Image(systemName: nhom == .none ? "rectangle.3.group" : "rectangle.3.group.fill")
        }
        .accessibilityLabel(Text("View options"))
        .accessibilityIdentifier("board.view")
    }

    // MARK: Đầu bảng: sprint · số thẻ · bộ lọc đang bật

    private func dauBang(_ b: CTWBoardData) -> some View {
        let tong = b.issues?.count ?? 0
        let hien = dsDaLoc().count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let s = b.sprint {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill").font(.ctw(size: 11)).foregroundColor(AppColors.primary)
                        Text(s.name).font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                    .layoutPriority(1)
                    if let e = CTWKieuWeb.ngay(s.endAt) {
                        Text("ends \(e)")
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    }
                } else if b.fallback == true {
                    Image(systemName: "info.circle").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    Text("No active sprint — showing all open issues")
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 4)
                Group {
                    if hien == tong { Text("\(tong) issues") } else { Text("\(hien) of \(tong)") }
                }
                .font(.ctw(size: 12).monospacedDigit())
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
                .fixedSize()
            }
            if dangChon {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle").foregroundColor(AppColors.primary)
                    Text("Tap issues to select them").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    Spacer(minLength: 0)
                    Button { chon = Set(dsDaLoc().map(\.id)) } label: {
                        Text("Select all").font(.ctw(size: 12, weight: .semibold)).frame(minHeight: 30)
                    }
                    .buttonStyle(.plain).foregroundColor(AppColors.primary)
                }
            }
            if loc.soBat > 0 || !timChu.trimmingCharacters(in: .whitespaces).isEmpty {
                hangChipLoc
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, 8)
    }

    private var hangChipLoc: some View {
        let cfg = vm.cauHinh
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if loc.chiCuaToi { chipLoc("Only my issues") { loc.chiCuaToi = false } }
                if loc.ganDay { chipLoc("Recently updated") { loc.ganDay = false } }
                if loc.tuanNay { chipLoc("Due this week") { loc.tuanNay = false } }
                if loc.chuaGiao { chipLoc("Unassigned") { loc.chuaGiao = false } }
                ForEach((cfg?.dsLoai ?? []).filter { loc.loai.contains($0.id) }) { t in
                    chipLoc(verbatim: CTWTen.loai(t.name)) { loc.loai.remove(t.id) }
                }
                ForEach(Array(loc.nguoi).sorted(), id: \.self) { id in
                    if id == 0 { chipLoc("Unassigned") { loc.nguoi.remove(0) } } else {
                        chipLoc(verbatim: cfg?.thanhVien(id)?.ten ?? "#\(id)") { loc.nguoi.remove(id) }
                    }
                }
                ForEach(Array(loc.uuTien).sorted(), id: \.self) { p in
                    chipLoc(verbatim: CTW.uuTien(p).ten) { loc.uuTien.remove(p) }
                }
                ForEach((cfg?.labels ?? []).filter { loc.nhan.contains($0.id) }) { l in
                    chipLoc(verbatim: l.name) { loc.nhan.remove(l.id) }
                }
                ForEach(Array(loc.epic).sorted(), id: \.self) { e in
                    if e == 0 { chipLoc("No epic") { loc.epic.remove(0) } } else {
                        chipLoc(verbatim: vm.epics[e]?.ten ?? "#\(e)") { loc.epic.remove(e) }
                    }
                }
                ForEach(Array(loc.boPhan).sorted(), id: \.self) { b in
                    if b == 0 { chipLoc("No team") { loc.boPhan.remove(0) } } else {
                        chipLoc(verbatim: vm.boPhan.first { $0.id == b }?.name ?? "#\(b)") { loc.boPhan.remove(b) }
                    }
                }
                Button { xoaLoc() } label: {
                    Text("Clear all").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.primary).fixedSize()
                        .padding(.horizontal, 8).frame(minHeight: 30)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chipLoc(_ ten: LocalizedStringKey, bo: @escaping () -> Void) -> some View {
        chipLocNoiDung(Text(ten), bo: bo)
    }

    private func chipLoc(verbatim ten: String, bo: @escaping () -> Void) -> some View {
        chipLocNoiDung(Text(verbatim: ten), bo: bo)
    }

    private func chipLocNoiDung(_ chu: Text, bo: @escaping () -> Void) -> some View {
        Button { CTWRung.chon(); bo() } label: {
            HStack(spacing: 4) {
                chu.font(.ctw(size: 12, weight: .medium)).fixedSize()
                Image(systemName: "xmark").font(.ctw(size: 9, weight: .bold))
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 9).frame(minHeight: 30)
            .background(Capsule().fill(AppColors.primary.opacity(0.10)))
            .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.35), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Removes this filter"))
    }

    // MARK: Cột (không nhóm)

    private var cacCot: some View {
        GeometryReader { geo in
            let ds = dsDaLoc()
            let mo = vm.cot.filter { !cotGap.contains($0.key) }.count
            let so = max(mo, 1)
            let le = Spacing.md
            let khoang: CGFloat = 10
            let gap = CGFloat(vm.cot.count - mo) * (Self.rongCotGap + khoang)
            // iPad/Mac: chia đều bề ngang khi đủ chỗ (≥ 240pt mỗi cột), không thì cuộn ngang. iPhone: cột gần bằng
            // màn (thấy mép cột sau) và cuộn BẬT TỪNG CỘT (viewAligned) — vuốt một cái là sang đúng cột kế.
            let deu = (geo.size.width - le * 2 - gap - khoang * CGFloat(so - 1)) / CGFloat(so)
            let rongCot: CGFloat = rong ? max(250, deu) : min(340, geo.size.width - le * 2 - 34)
            ScrollView(.horizontal, showsIndicators: rong) {
                HStack(alignment: .top, spacing: khoang) {
                    ForEach(vm.cot) { c in
                        if cotGap.contains(c.key) {
                            cotDaGap(c, so: vm.the(trongCot: c, tu: ds).count, cao: geo.size.height - 4)
                        } else {
                            cot(c, ds: vm.the(trongCot: c, tu: ds), rongCot: rongCot, cao: geo.size.height - 4)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.bottom, 4)
            }
            .contentMargins(.horizontal, le, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .overlay {
                if vm.cot.isEmpty {
                    Text("This project has no board columns.")
                        .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    static let rongCotGap: CGFloat = 48

    /// Cột đã gập: dải hẹp (tên dọc + số thẻ); chạm để mở. Vẫn nhận thẻ thả vào.
    private func cotDaGap(_ c: CTWBoardColumn, so: Int, cao: CGFloat) -> some View {
        let khoaDich = "-|\(c.key)"
        return Button {
            CTWRung.chon()
            cotGap.remove(c.key)
        } label: {
            VStack(spacing: 10) {
                CTWStatusGlyph(category: c.category, co: CTWCoChu.co(12))
                Text("\(so)").font(.ctw(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                Text(verbatim: CTWTen.trangThaiCau(c.name))
                    .font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(1).fixedSize()
                    .rotationEffect(.degrees(90))
                    .frame(width: 24, height: 160)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .frame(width: Self.rongCotGap)
            .frame(maxHeight: max(cao, 200), alignment: .top)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cotDich == khoaDich ? AppColors.primary.opacity(0.10) : AppColors.backgroundTertiary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(CTWTen.trangThai(c.name)), collapsed, \(so) issues"))
        .accessibilityHint(Text("Expands the column"))
        .dropDestination(for: String.self) { items, _ in thaVao(items, c) } isTargeted: { dichDoi($0, khoaDich) }
    }

    private func dichDoi(_ dang: Bool, _ k: String) {
        if dang {
            if cotDich != k { CTWRung.chon() }
            cotDich = k
        } else if cotDich == k {
            cotDich = nil
        }
    }

    private func thaVao(_ items: [String], _ c: CTWBoardColumn) -> Bool {
        cotDich = nil
        guard let s = items.first, let so = Int(s) else { return false }
        Task { _ = await vm.tha(soThe: so, vaoCot: c) }
        return true
    }

    private func dauCot(_ c: CTWBoardColumn, so: Int, coNutGap: Bool) -> some View {
        let vuot = c.wipLimit.map { so > $0 } ?? false
        return HStack(spacing: 7) {
            CTWStatusGlyph(category: c.category, co: CTWCoChu.co(12))
            Text(verbatim: CTWTen.trangThaiCau(c.name))
                .font(.ctw(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            Text(c.wipLimit.map { "\(so)/\($0)" } ?? "\(so)")
                .font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(vuot ? .white : AppColors.textSecondary)
                .padding(.horizontal, 7).padding(.vertical, 1.5)
                .background(Capsule().fill(vuot ? AppColors.error : AppColors.backgroundCard))
                .accessibilityLabel(vuot ? Text("\(so) issues, over the limit of \(c.wipLimit ?? 0)") : Text("\(so) issues"))
            Spacer(minLength: 0)
            if coNutGap {
                Button {
                    CTWRung.chon()
                    cotGap.insert(c.key)
                } label: {
                    Image(systemName: "arrow.right.and.line.vertical.and.arrow.left")
                        .font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Collapse column \(CTWTen.trangThai(c.name))"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private func cot(_ c: CTWBoardColumn, ds: [CTWIssueCard], rongCot: CGFloat, cao: CGFloat) -> some View {
        let khoaDich = "-|\(c.key)"
        let laDich = cotDich == khoaDich
        return VStack(alignment: .leading, spacing: 0) {
            dauCot(c, so: ds.count, coNutGap: true)
                .padding(.leading, 12).padding(.trailing, 4)
                .padding(.top, 7).padding(.bottom, 5)

            // Dải màu nhóm dưới tiêu đề — như web, nhận ra cột "đang làm"/"xong" ngay cả khi lướt nhanh.
            Capsule().fill(CTWKieuWeb.mauNhom(c.category).opacity(0.55)).frame(height: 2)
                .padding(.horizontal, 12).padding(.bottom, 8)
                .accessibilityHidden(true)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(ds) { t in
                        theBang(t, rong: rongCot - 16)
                    }
                    if ds.isEmpty { oTrong(laDich) }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .refreshable { await vm.tai() }
        }
        .frame(width: rongCot)
        .frame(maxHeight: max(cao, 200), alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(laDich ? AppColors.primary.opacity(0.10) : AppColors.backgroundTertiary))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(laDich ? AppColors.primary : Color.clear, lineWidth: 1.5))
        .animation(.easeOut(duration: 0.15), value: laDich)
        .dropDestination(for: String.self) { items, _ in thaVao(items, c) } isTargeted: { dichDoi($0, khoaDich) }
    }

    /// Ô trống: cột thường cao 64 + "No issues"; ô trong làn gọn (36, không chữ) để làn thưa không chiếm cả màn.
    private func oTrong(_ laDich: Bool, gon: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundColor(laDich ? AppColors.primary : AppColors.border)
            .frame(height: gon ? 36 : 64)
            .overlay {
                if laDich { Text("Drop here").font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.primary) }
                else if !gon { Text("No issues").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary) }
            }
            .accessibilityLabel(laDich ? Text("Drop here") : Text("No issues"))
    }

    // MARK: Làn (swimlane)

    private var lanHienTai: [CTWBoardLanView.Lan] {
        guard let cfg = vm.cauHinh else { return [] }
        return CTWBangNhom.chiaLan(nhom, dsDaLoc(), cfg: cfg, epicTen: vm.epics, longViecCon: nhom == .subtasks)
            .map { CTWBoardLanView.Lan(lan: $0) }
    }

    private var cacLan: some View {
        GeometryReader { geo in
            let rongCot: CGFloat = rong ? 270 : min(300, geo.size.width - Spacing.md * 2 - 40)
            let lan = lanHienTai
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(lan) { l in
                        let k = "\(nhom.rawValue):\(l.lan.key)"
                        let gap = lan.count > 1 && lanGap.contains(k)
                        VStack(alignment: .leading, spacing: 8) {
                            dauLan(l.lan, gap: gap, motLan: lan.count <= 1) {
                                CTWRung.chon()
                                if lanGap.contains(k) { lanGap.remove(k) } else { lanGap.insert(k) }
                            }
                            .padding(.horizontal, Spacing.md)
                            if !gap {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .top, spacing: 8) {
                                        ForEach(vm.cot) { c in
                                            oLan(c, lan: l.lan, rongCot: cotGap.contains(c.key) ? Self.rongCotGap : rongCot)
                                        }
                                    }
                                }
                                .contentMargins(.horizontal, Spacing.md, for: .scrollContent)
                            }
                        }
                    }
                    if lan.isEmpty || lan.allSatisfy({ $0.lan.the.isEmpty }) {
                        Text("No issues match these filters.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(.bottom, 16)
            }
            .refreshable { await vm.tai() }
        }
    }

    private func dauLan(_ l: CTWLanBang, gap: Bool, motLan: Bool, doi: @escaping () -> Void) -> some View {
        Button(action: doi) {
            HStack(spacing: 8) {
                if !motLan {
                    Image(systemName: gap ? "chevron.right" : "chevron.down")
                        .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary).frame(width: 14)
                }
                bieuTuongLan(l)
                tieuDeLan(l)
                    .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                Text("\(l.the.count)").font(.ctw(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 7).padding(.vertical, 1.5)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(motLan)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(gap ? Text("Collapsed") : Text("Expanded"))
    }

    @ViewBuilder private func bieuTuongLan(_ l: CTWLanBang) -> some View {
        if let cfg = vm.cauHinh {
            switch nhom {
            case .assignee:
                if let u = l.userId { CTWAvatar(user: cfg.thanhVien(u) ?? CTWUser(id: u), size: 22) } else { CTWAvatar(user: nil, size: 22) }
            case .epic:
                Image(systemName: "bolt.fill").font(.ctw(size: 10, weight: .bold)).foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(l.epic == nil ? AppColors.textTertiary : Color(hex: 0x7C3AED)))
            case .priority:
                CTWPriorityIcon(priority: l.uuTien)
            case .subtasks:
                if let p = l.cha {
                    CTWTypeIcon(type: cfg.loai(p.typeId), size: 14)
                    Text(verbatim: "\(cfg.key)-\(p.number)").font(.ctw(size: 12, weight: .medium).monospaced()).foregroundColor(AppColors.textSecondary)
                }
            case .none: EmptyView()
            }
        }
    }

    private func tieuDeLan(_ l: CTWLanBang) -> Text {
        if nhom == .priority, let p = l.uuTien { return Text(verbatim: CTW.uuTien(p).ten) }
        if let t = l.tieuDe { return Text(verbatim: t) }
        switch l.tieuDeMacDinh {
        case .chuaGiao: return Text("Unassigned")
        case .thanhVienCu: return Text("Former member")
        case .khongEpic: return Text("No epic")
        case .khac: return Text("Other issues")
        case .tatCa, .none: return Text("All issues")
        }
    }

    /// Một ô (làn × cột): tên cột nhỏ + thẻ; nhận thẻ thả vào (chỉ đổi trạng thái).
    private func oLan(_ c: CTWBoardColumn, lan: CTWLanBang, rongCot: CGFloat) -> some View {
        let ds = vm.the(trongCot: c, tu: lan.the)
        let khoaDich = "\(lan.key)|\(c.key)"
        let laDich = cotDich == khoaDich
        let gap = cotGap.contains(c.key)
        return VStack(alignment: .leading, spacing: 8) {
            if gap {
                Button { cotGap.remove(c.key) } label: {
                    VStack(spacing: 6) {
                        CTWStatusGlyph(category: c.category, co: CTWCoChu.co(12))
                        Text("\(ds.count)").font(.ctw(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(CTWTen.trangThai(c.name)), collapsed, \(ds.count) issues"))
            } else {
                dauCot(c, so: ds.count, coNutGap: false)
                ForEach(ds) { t in theBang(t, rong: rongCot - 16) }
                if ds.isEmpty { oTrong(laDich, gon: true) }
            }
        }
        .padding(8)
        .frame(width: rongCot, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(laDich ? AppColors.primary.opacity(0.10) : AppColors.backgroundTertiary))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(laDich ? AppColors.primary : Color.clear, lineWidth: 1.5))
        .dropDestination(for: String.self) { items, _ in thaVao(items, c) } isTargeted: { dichDoi($0, khoaDich) }
    }

    // MARK: Thẻ

    @ViewBuilder
    private func theBang(_ t: CTWIssueCard, rong: CGFloat) -> some View {
        if let cfg = vm.cauHinh {
            if dangChon {
                let daChon = chon.contains(t.id)
                Button {
                    CTWRung.chon()
                    if daChon { chon.remove(t.id) } else { chon.insert(t.id) }
                } label: {
                    CTWCardView(the: t, cauHinh: cfg)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: daChon ? "checkmark.circle.fill" : "circle")
                                .font(.ctw(size: 18, weight: .semibold))
                                .foregroundColor(daChon ? AppColors.primary : AppColors.textTertiary)
                                .background(Circle().fill(AppColors.backgroundCard))
                                .padding(6)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(daChon ? AppColors.primary : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(daChon ? .isSelected : [])
            } else {
                NavigationLink(value: CTWRoute.the(pid: pid, so: t.number)) {
                    CTWCardView(the: t, cauHinh: cfg)
                }
                .buttonStyle(.plain)
                .contextMenu { menuThe(t, cfg) }
                .modifier(KeoThe(so: t.number, bat: cfg.coTheChuyen) {
                    // Ảnh kéo: chính tấm thẻ, nghiêng nhẹ như web (`rotate-[1.5deg]`).
                    CTWCardView(the: t, cauHinh: cfg)
                        .frame(width: rong)
                        .rotationEffect(.degrees(1.5))
                })
            }
        }
    }

    @ViewBuilder
    private func menuThe(_ t: CTWIssueCard, _ cfg: CTWProjectConfig) -> some View {
        if cfg.coTheChuyen {
            let dich = cfg.trangThaiDich(loai: t.typeId, tu: t.statusId).filter { $0.id != t.statusId }
            if dich.isEmpty {
                Text("No transitions available")
            } else {
                // "Move to…" — đường thay cho kéo thả (VoiceOver, một tay). Chỉ bước quy trình cho phép.
                Section("Move to…") {
                    ForEach(dich) { s in
                        Button { Task { await vm.chuyen(t, sang: s.id) } } label: {
                            Label { Text(verbatim: CTWTen.trangThaiCau(s.name)) } icon: { Image(systemName: Self.bieuTuongNhom(s.category)) }
                        }
                    }
                }
            }
        } else {
            Text("You can view this project but not move issues")
        }
        if cfg.coTheSua || cfg.coTheChuyen {
            Button {
                dangChon = true
                chon = [t.id]
            } label: { Label("Select", systemImage: "checkmark.circle") }
        }
        Button { CTW.chepVaoBoNho("\(cfg.key)-\(t.number)") } label: { Label("Copy key", systemImage: "number") }
    }

    static func bieuTuongNhom(_ c: String?) -> String {
        switch c {
        case "DONE": return "checkmark.circle.fill"
        case "IN_PROGRESS": return "circle.lefthalf.filled"
        default: return "circle"
        }
    }
}

/// Bọc làn cho `ForEach` (id ổn định theo khoá làn).
enum CTWBoardLanView {
    struct Lan: Identifiable { var lan: CTWLanBang; var id: String { lan.key } }
}

/// Kéo thẻ — chỉ bật khi có quyền chuyển trạng thái.
private struct KeoThe<AnhKeo: View>: ViewModifier {
    let so: Int
    let bat: Bool
    @ViewBuilder let anhKeo: () -> AnhKeo

    func body(content: Content) -> some View {
        if bat {
            content.draggable(String(so)) { anhKeo() }
        } else {
            content
        }
    }
}

// MARK: - Thẻ (kiểu web `BoardCard`)
//
// Thứ bậc như web: tiêu đề (14, ≤ 3 dòng) → nhãn (≤ 3, +N) → hàng dưới: loại + mã · bình luận … hạn · điểm · ưu tiên · người.

struct CTWCardView: View {
    let the: CTWIssueCard
    let cauHinh: CTWProjectConfig

    var body: some View {
        let xong = the.resolvedAt != nil || cauHinh.trangThai(the.statusId)?.category == "DONE"
        VStack(alignment: .leading, spacing: 8) {
            Text(the.title)
                .font(.ctw(size: 14, weight: xong ? .regular : .medium))
                .foregroundColor(xong ? AppColors.textTertiary : AppColors.textPrimary)
                .strikethrough(xong, color: AppColors.textTertiary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let nhan = nhanCuaThe, !nhan.isEmpty {
                HStack(spacing: 4) {
                    ForEach(nhan.prefix(3)) { l in CTWLabelChip(label: l) }
                    if nhan.count > 3 {
                        Text("+\(nhan.count - 3)").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            HStack(spacing: 6) {
                CTWTypeIcon(type: cauHinh.loai(the.typeId), size: 12)
                Text(verbatim: "\(cauHinh.key)-\(the.number)")
                    .font(.ctw(size: 12, weight: .medium).monospaced())
                    .foregroundColor(xong ? AppColors.textTertiary : AppColors.textSecondary)
                    .strikethrough(xong)
                    .lineLimit(1)
                    .fixedSize()
                if let n = the.commentCount, n > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left").font(.ctw(size: 10))
                        Text("\(n)").font(.ctw(size: 11).monospacedDigit())
                    }
                    .foregroundColor(AppColors.textTertiary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(n) comments"))
                }
                Spacer(minLength: 0)
                CTWDueChip(dueDate: the.dueDate, xong: xong)
                if let sp = the.storyPoints { CTWPointsBadge(diem: sp) }
                CTWPriorityIcon(priority: the.priority)
                if the.assigneeId != nil {
                    CTWAvatar(user: cauHinh.thanhVien(the.assigneeId) ?? CTWUser(id: the.assigneeId ?? 0, username: "?"), size: 22)
                } else {
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2.5, 2]))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 20, height: 20)
                        .accessibilityLabel(Text("Unassigned"))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .ctwThe(10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var nhanCuaThe: [CTWLabel]? {
        guard let ids = the.labelIds, !ids.isEmpty else { return nil }
        return (cauHinh.labels ?? []).filter { ids.contains($0.id) }
    }
}
