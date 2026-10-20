import SwiftUI

// MARK: - CT Work — phần THÊM của chi tiết thẻ (20/10/2026): nhật ký giờ · tài liệu liên kết · liên kết web ·
// chia sẻ vào kênh chat · chuyển sang dự án khác
//
// Đối chiếu web: `IssueActivity` (tab Work log), `docs/LinkedDocs.tsx`, `resources/IssueWebLinks.tsx`,
// `chat/ShareToChannel.tsx`, `studio/IssueStudio.tsx → MoveIssueDialog`.

// MARK: Nhật ký giờ

struct CTWIssueNhatKyGioView: View {
    @ObservedObject var vm: CTWIssueVM
    let cfg: CTWProjectConfig
    @EnvironmentObject private var appState: AppState
    @State private var hoiXoa: CTWWorklogThe?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ds = vm.nhatKyGio {
                if ds.isEmpty {
                    Text("No time logged yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                } else {
                    HStack {
                        Text("Total").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(verbatim: CTWThoiLuong.chu(ds.reduce(0) { $0 + ($1.minutes ?? 0) }))
                            .font(.ctw(size: 13, weight: .semibold).monospacedDigit())
                    }
                    VStack(spacing: 0) {
                        ForEach(ds) { w in
                            CTWHangNhatKyGio(w: w)
                                .contextMenu {
                                    if coTheXoa(w) {
                                        Button(role: .destructive) { hoiXoa = w } label: { Label("Delete worklog", systemImage: "trash") }
                                    }
                                }
                            if w.id != ds.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 14)
                    .ctwThe(12)
                    Text("Touch and hold your own entry to delete it.")
                        .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
        .task { if vm.nhatKyGio == nil { await vm.taiNhatKyGio() } }
        .confirmationDialog("Delete this worklog?", isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }),
                            titleVisibility: .visible) {
            Button("Delete worklog", role: .destructive) {
                guard let w = hoiXoa else { return }
                Task { await xoa(w) }
            }
        } message: {
            Text("The time is removed from this issue's time spent.")
        }
    }

    private func coTheXoa(_ w: CTWWorklogThe) -> Bool {
        cfg.coTheSua && ((w.userId ?? w.user?.id) == appState.currentUser?.id || cfg.role == "ADMIN")
    }

    private func xoa(_ w: CTWWorklogThe) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaNhatKyGio(pid: vm.pid, so: vm.so, id: w.id))
            vm.nhatKyGio?.removeAll { $0.id == w.id }
            await vm.napLaiThe()
            vm.lichSu = nil
            CTWRung.thanhCong()
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "WORK_TIMESHEET_LOCKED" {
                vm.loi = String(localized: "That week's timesheet is locked.")
            } else {
                vm.loi = CTW.loi(error)
            }
        }
    }
}

struct CTWHangNhatKyGio: View {
    let w: CTWWorklogThe

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CTWAvatar(user: w.user, size: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: w.user?.ten ?? String(localized: "Someone")).font(.ctw(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if w.user?.laAgent == true { CTWNhanAI() }
                    Spacer(minLength: 0)
                    Text(verbatim: CTWThoiLuong.chu(w.minutes)).font(.ctw(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textPrimary)
                }
                Text("logged time · \(CTW.thoiDiem(w.startedAt))").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                if let n = w.note, !n.isEmpty {
                    Text(verbatim: n).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Tài liệu + liên kết web (tab Links)

struct CTWIssueLienKetKhacView: View {
    @ObservedObject var vm: CTWIssueVM
    let cfg: CTWProjectConfig
    var moRong: CTWIssueMoRong?
    @State private var trang: CTWTrangCuaThe?
    @State private var web: CTWDsLienKetWeb?
    @State private var tamPhu: TamPhu?

    private enum TamPhu: String, Identifiable { case themWeb, ganTrang; var id: String { rawValue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let trang, (!(trang.pages ?? []).isEmpty || trang.canEdit == true) { khoiTrang(trang) }
            if let web, (!(web.items ?? []).isEmpty || web.canEdit == true) { khoiWeb(web) }
        }
        .task(id: vm.the?.version) { await tai() }
        .sheet(item: $tamPhu) { tp in
            switch tp {
            case .themWeb:
                CTWThemLienKetWebView { url, ten in
                    do {
                        web = try await APIClient.shared.request(CTWAPI.themLienKetWeb(pid: vm.pid, so: vm.so, url: url, tieuDe: ten))
                        CTWRung.thanhCong()
                        return nil
                    } catch { return CTW.loi(error) }
                }
            case .ganTrang:
                CTWChonTrangView(pid: vm.pid, daGan: Set((trang?.pages ?? []).map(\.number))) { so in
                    do {
                        try await APIClient.shared.send(CTWAPI.ganTrang(pid: vm.pid, trang: so, so: vm.so))
                        await tai()
                        return true
                    } catch { vm.loi = CTW.loi(error); return false }
                }
            }
        }
    }

    private func tai() async {
        // Mô-đun tắt / không có quyền ⇒ máy chủ trả lỗi ⇒ ẩn khối (như web, không báo lỗi).
        if cfg.modules?["docs"] != false {
            trang = try? await APIClient.shared.request(CTWAPI.trangCuaThe(pid: vm.pid, so: vm.so))
        }
        web = try? await APIClient.shared.request(CTWAPI.lienKetWeb(pid: vm.pid, so: vm.so))
    }

    private func khoiTrang(_ tr: CTWTrangCuaThe) -> some View {
        let ds = tr.pages ?? []
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("doc.text", String(localized: "Linked docs"), count: ds.isEmpty ? nil : "\(ds.count)",
                             trailing: tr.canEdit == true ? AnyView(
                                Button { tamPhu = .ganTrang } label: {
                                    Label("Link a doc", systemImage: "plus").font(.ctw(size: 13, weight: .semibold)).frame(minHeight: 32)
                                }) : nil)
            if ds.isEmpty {
                Text("No docs linked yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ds) { p in
                        let nhan = HStack(spacing: 8) {
                            Image(systemName: "doc.text").foregroundColor(AppColors.textTertiary)
                            Text(verbatim: p.title).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer(minLength: 0)
                            if let s = p.status { CTWChipChu(chu: s) }
                        }
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        Group {
                            if let l = moRong?.lienKetTrang { l(vm.pid, p.number, p.title, AnyView(nhan)) } else { nhan }
                        }
                        .contextMenu {
                            if tr.canEdit == true {
                                Button(role: .destructive) {
                                    Task {
                                        do {
                                            try await APIClient.shared.send(CTWAPI.goTrang(pid: vm.pid, trang: p.number, so: vm.so))
                                            await tai()
                                        } catch { vm.loi = CTW.loi(error) }
                                    }
                                } label: { Label("Unlink doc", systemImage: "xmark.circle") }
                            }
                        }
                        if p.id != ds.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(12)
            }
        }
    }

    private func khoiWeb(_ w: CTWDsLienKetWeb) -> some View {
        let ds = w.items ?? []
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("globe", String(localized: "Web links"), count: ds.isEmpty ? nil : "\(ds.count)",
                             trailing: w.canEdit == true ? AnyView(
                                Button { tamPhu = .themWeb } label: {
                                    Label("Add link", systemImage: "plus").font(.ctw(size: 13, weight: .semibold)).frame(minHeight: 32)
                                }) : nil)
            if ds.isEmpty {
                Text("No web links yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ds) { l in
                        hangWeb(l)
                        if l.id != ds.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(12)
            }
        }
    }

    @ViewBuilder
    private func hangWeb(_ l: CTWLienKetWeb) -> some View {
        let nhan = HStack(spacing: 8) {
            Image(systemName: "link").foregroundColor(AppColors.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: (l.title?.isEmpty == false ? l.title : nil) ?? l.url).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                Text(verbatim: URL(string: l.url)?.host ?? l.url).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        Group {
            if let u = URL(string: l.url), ["http", "https"].contains(u.scheme?.lowercased() ?? "") {
                Link(destination: u) { nhan }.buttonStyle(.plain)
            } else {
                nhan
            }
        }
        .contextMenu {
            Button { CTW.chepVaoBoNho(l.url) } label: { Label("Copy link", systemImage: "doc.on.doc") }
            if l.canDelete == true {
                Button(role: .destructive) {
                    Task {
                        do { web = try await APIClient.shared.request(CTWAPI.xoaLienKetWeb(pid: vm.pid, so: vm.so, lid: l.id)) }
                        catch { vm.loi = CTW.loi(error) }
                    }
                } label: { Label("Remove link", systemImage: "xmark.circle") }
            }
        }
    }
}

struct CTWThemLienKetWebView: View {
    /// Trả `nil` khi xong; khác ⇒ câu lỗi.
    let luu: (String, String?) async -> String?
    @Environment(\.dismiss) private var dong
    @State private var url = ""
    @State private var ten = ""
    @State private var loi: String?
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://…", text: $url)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    TextField("Title (optional)", text: $ten)
                } footer: {
                    if let loi { Text(loi).foregroundColor(AppColors.error) }
                }
            }
            .navigationTitle("Add web link")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button("Add") {
                            var u = url.trimmingCharacters(in: .whitespaces)
                            if !u.isEmpty, !u.lowercased().hasPrefix("http") { u = "https://" + u }
                            guard URL(string: u)?.host != nil else { loi = String(localized: "Enter a full link starting with https://"); return }
                            Task {
                                dangLuu = true
                                if let l = await luu(u, ten.trimmingCharacters(in: .whitespaces)) { loi = l } else { dong() }
                                dangLuu = false
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.height(300), .medium])
    }
}

struct CTWChonTrangView: View {
    let pid: Int
    let daGan: Set<Int>
    let chon: (Int) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var ds: [CTWTrangNgan]?
    @State private var tim = ""

    var body: some View {
        NavigationStack {
            List {
                if let ds {
                    let loc = ds.filter { !daGan.contains($0.number) && (tim.isEmpty || $0.title.localizedCaseInsensitiveContains(tim)) }
                    if loc.isEmpty { Text("No docs to link.").foregroundColor(AppColors.textSecondary) }
                    ForEach(loc) { p in
                        Button { Task { if await chon(p.number) { dong() } } } label: {
                            Label { Text(verbatim: p.title).foregroundColor(AppColors.textPrimary) } icon: { Image(systemName: "doc.text") }
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $tim)
            .navigationTitle("Link a doc")
            .ctwTieuDeNho()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
            .task {
                let r: CTWDsTrang? = try? await APIClient.shared.request(CTWAPI.dsTrangNgan(pid: pid))
                ds = r?.pages ?? []
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Chia sẻ vào kênh chat

struct CTWChiaSeKenhView: View {
    let pid: Int
    /// Đường web tương đối `/work/<ws>/<KEY>/issue/<n>` — chat dựng thành thẻ xem trước.
    let duong: String
    let nhan: String
    @Environment(\.dismiss) private var dong
    @State private var ds: [CTWKenhNgan]?
    @State private var kenh: Int?
    @State private var loiNhan = ""
    @State private var loi: String?
    @State private var dangGui = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: nhan).font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    TextField("Add a message (optional)", text: $loiNhan, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    if let ds {
                        if ds.isEmpty { Text("No channels you can post in.").foregroundColor(AppColors.textSecondary) }
                        ForEach(ds) { k in
                            Button { kenh = k.id } label: {
                                HStack {
                                    Image(systemName: k.kind == "PRIVATE" ? "lock" : "number").foregroundColor(AppColors.textTertiary)
                                    Text(verbatim: k.name).foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if kenh == k.id { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                                }
                                .frame(minHeight: 36)
                                .contentShape(Rectangle())
                            }
                            .accessibilityAddTraits(kenh == k.id ? .isSelected : [])
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Channel")
                } footer: {
                    if let loi { Text(loi).foregroundColor(AppColors.error) }
                    else { Text("Everyone in the channel sees the issue link and your message.") }
                }
            }
            .navigationTitle("Share to channel")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangGui { ProgressView() } else {
                        Button("Share") { Task { await gui() } }.fontWeight(.semibold).disabled(kenh == nil)
                    }
                }
            }
            .task {
                do {
                    let r: CTWDsKenhNgan = try await APIClient.shared.request(CTWAPI.kenhChiaSe(pid: pid))
                    ds = (r.channels ?? []).filter { $0.archived != true && $0.canPost != false && $0.kind != "CLIENT" }
                } catch {
                    ds = []
                    loi = CTW.loi(error)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func gui() async {
        guard let kenh else { return }
        let ghi = loiNhan.trimmingCharacters(in: .whitespacesAndNewlines)
        let chu = (ghi.isEmpty ? "" : ghi + "\n\n") + "[\(nhan.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: ""))](\(duong))"
        dangGui = true
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(CTWAPI.chiaSeVaoKenh(pid: pid, cid: kenh, chu: chu))
            CTWRung.thanhCong()
            dong()
        } catch {
            loi = CTW.loi(error)
        }
    }
}

// MARK: Chuyển sang dự án khác

struct CTWChuyenDuAnView: View {
    let cfg: CTWProjectConfig
    let so: Int
    let version: Int?
    /// Chuyển xong ⇒ mã mới (vd "OPS-7").
    let xong: (CTWKetQuaChuyenDuAn) -> Void
    @Environment(\.dismiss) private var dong
    @State private var ds: [CTWDuAnDich]?
    @State private var dich: CTWDuAnDich?
    @State private var loi: String?
    @State private var dangGui = false
    @State private var hoi = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let ds {
                        if ds.isEmpty { Text("No other project you can move issues into.").foregroundColor(AppColors.textSecondary) }
                        ForEach(ds) { p in
                            Button { dich = p } label: {
                                HStack(spacing: 10) {
                                    CTWProjectMark(ma: p.key, co: 24)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(verbatim: p.name).foregroundColor(AppColors.textPrimary)
                                        Text(verbatim: p.key).font(.ctw(size: 12).monospaced()).foregroundColor(AppColors.textTertiary)
                                    }
                                    Spacer()
                                    if dich?.id == p.id { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                                }
                                .frame(minHeight: 40)
                                .contentShape(Rectangle())
                            }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Move \(cfg.key)-\(so) to")
                } footer: {
                    if let loi { Text(loi).foregroundColor(AppColors.error) }
                    else { Text("The issue gets a new key. Its sub-tasks move with it; labels, components and fields the other project doesn't have are dropped. The old key keeps redirecting.") }
                }
            }
            .navigationTitle("Move to project")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangGui { ProgressView() } else {
                        Button("Move") { hoi = true }.fontWeight(.semibold).disabled(dich == nil)
                    }
                }
            }
            .confirmationDialog(dich.map { String(localized: "Move \(cfg.key)-\(so) to \($0.name)?") } ?? "",
                                isPresented: $hoi, titleVisibility: .visible) {
                Button("Move issue", role: .destructive) { Task { await chuyen() } }
            }
            .task {
                do {
                    let ws: CTWKhongGianDuAn = try await APIClient.shared.request(CTWAPI.duAnTrongKhongGian(slug: cfg.workspace?.slug ?? ""))
                    ds = (ws.projects ?? []).filter { $0.id != cfg.id && $0.archivedAt == nil && ($0.role == "ADMIN" || $0.role == "MEMBER") }
                } catch {
                    ds = []
                    loi = CTW.loi(error)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func chuyen() async {
        guard let dich else { return }
        dangGui = true
        defer { dangGui = false }
        do {
            let r: CTWKetQuaChuyenDuAn = try await APIClient.shared.request(CTWAPI.chuyenDuAn(pid: cfg.id, so: so, dich: dich.id, version: version))
            CTWRung.thanhCong()
            xong(r)
            dong()
        } catch {
            loi = CTW.loi(error)
        }
    }
}
