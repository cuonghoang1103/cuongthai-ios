import SwiftUI
import Combine

// MARK: - Bảng retro
//
// iPhone: chip chọn cột (một cột một lúc, thẻ to dễ đọc). iPad: mọi cột cạnh nhau, cuộn ngang.
// Thẻ sắp theo số phiếu giảm dần; thẻ đã gộp (`groupId`) nằm thụt dưới thẻ đầu nhóm.

@MainActor
final class BangRetroVM: ObservableObject {
    let pid: Int
    let rid: Int
    @Published var retro: TaiCTW<CTWRetro> = .dangTai
    @Published var loi: String?

    init(pid: Int, rid: Int) { self.pid = pid; self.rid = rid }

    func tai() async {
        do { retro = .xong(try await APIClient.shared.request(CTWAPI.retro(pid: pid, rid: rid))) }
        catch { if retro.giaTri == nil { retro = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) } }
    }

    func lam(_ ep: APIEndpoint) async {
        do {
            try await APIClient.shared.send(ep)
            loi = nil
        } catch {
            loi = DongHoCTW.maLoi(error) == "WORK_RETRO_NO_VOTES" ? "You've used all your votes. Remove a vote to vote on another card."
                : (DongHoCTW.maLoi(error) == "WORK_RETRO_LOCKED" ? "This retro is locked." : CTW.loi(error))
            CTWRung.loi()
        }
        await tai()
    }

    /// Bỏ phiếu: cập nhật ngay trên màn (lạc quan) rồi đồng bộ với máy chủ.
    func phieu(_ the: CTWRetroThe, them: Bool) async {
        if case .xong(var r) = retro, var ds = r.cards, let i = ds.firstIndex(where: { $0.id == the.id }) {
            let d = them ? 1 : -1
            ds[i].votes = max((ds[i].votes ?? 0) + d, 0)
            ds[i].myVotes = max((ds[i].myVotes ?? 0) + d, 0)
            r.cards = ds
            if var toi = r.me { toi.votesLeft = max((toi.votesLeft ?? 0) - d, 0); r.me = toi }
            retro = .xong(r)
        }
        CTWRung.chon()
        await lam(CTWAPI.phieuRetro(pid: pid, rid: rid, cid: the.id, them: them))
    }
}

/// Phép sắp/lọc thẻ retro — thuần, kiểm thử được.
enum RetroTinh {
    /// Thẻ của một cột: bỏ thẻ đã ẩn/của người đã chặn; đầu nhóm sắp theo phiếu giảm dần,
    /// con của nhóm đi ngay sau đầu nhóm. Trả (thẻ, là con?).
    static func theCua(cot: String, the: [CTWRetroThe], an: Set<Int>, chan: Set<Int>) -> [(the: CTWRetroThe, con: Bool)] {
        let ds = the.filter { $0.column == cot && !an.contains($0.id) && !($0.author.map { chan.contains($0.id) } ?? false) }
        let ids = Set(ds.map(\.id))
        let dau = ds.filter { t in t.groupId.map { !ids.contains($0) } ?? true }
            .sorted { ($0.votes ?? 0, -($0.position ?? 0), -$0.id) > ($1.votes ?? 0, -($1.position ?? 0), -$1.id) }
        var kq: [(CTWRetroThe, Bool)] = []
        for d in dau {
            kq.append((d, false))
            for c in ds where c.groupId == d.id { kq.append((c, true)) }
        }
        return kq
    }
}

struct BangRetroCTW: View {
    let pid: Int
    let rid: Int
    let ten: String
    @EnvironmentObject private var app: AppState
    @StateObject private var vm: BangRetroVM
    @ObservedObject private var anRetro = RetroAnCTW.shared
    @ObservedObject private var kiemDuyet = ModerationStore.shared
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var cotChon = ""
    @State private var tamPhu: TamPhuRetro?
    @State private var baoCao: CTWRetroThe?
    @State private var hoiChan: CTWUser?
    @State private var huyNghe: AnyCancellable?

    enum TamPhuRetro: Identifiable {
        case themThe(String)
        case suaThe(CTWRetroThe)
        case themViec(CTWRetroThe?)
        var id: String {
            switch self {
            case .themThe(let c): return "them-\(c)"
            case .suaThe(let t): return "sua-\(t.id)"
            case .themViec(let t): return "viec-\(t?.id ?? 0)"
            }
        }
    }

    init(pid: Int, rid: Int, ten: String) {
        self.pid = pid; self.rid = rid; self.ten = ten
        _vm = StateObject(wrappedValue: BangRetroVM(pid: pid, rid: rid))
    }

    var body: some View {
        KhungTaiCTW(trangThai: vm.retro, thuLai: { Task { await vm.tai() } }) { r in
            let cot = r.columns ?? RetroCot.cot(template: r.template)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil }.padding(.horizontal, Spacing.md) }
                    dau(r).padding(.horizontal, Spacing.md)
                    if beRong == .regular {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(cot, id: \.self) { c in cotThe(r, c).frame(width: 300) }
                            }
                            .padding(.horizontal, Spacing.md)
                        }
                    } else {
                        ThanhTabCTW(tab: cot.map { c in (id: c, ten: "\(RetroCot.ten(c)) \(soThe(r, c))", bieuTuong: RetroCot.bieuTuong(c)) },
                                    chon: $cotChon)
                        cotThe(r, cotChon.isEmpty ? (cot.first ?? "") : cotChon).padding(.horizontal, Spacing.md)
                    }
                    viec(r).padding(.horizontal, Spacing.md)
                    if let s = r.summary, !s.isEmpty { tomTatAI(s, r.summaryAt).padding(.horizontal, Spacing.md) }
                }
                .padding(.vertical, Spacing.md)
            }
            .onAppear { if cotChon.isEmpty { cotChon = cot.first ?? "" } }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.retro.giaTri?.title ?? ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let r = vm.retro.giaTri, r.me?.canFacilitate == true {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { Task { await vm.lam(CTWAPI.khoaRetro(pid: pid, rid: rid, khoa: r.locked != true)) } } label: {
                            Label(r.locked == true ? "Unlock retro" : "Lock retro", systemImage: r.locked == true ? "lock.open" : "lock")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Retro actions")
                }
            }
        }
        .refreshable { await vm.tai() }
        .task { await vm.tai() }
        .onAppear {
            RealtimeKeHoachCTW.shared.nghe(pid: pid)
            huyNghe = RealtimeKeHoachCTW.shared.suKienAgile
                .filter { [pid, rid] in $0.projectId == pid && $0.kind == "retro" && $0.id == rid }
                .sink { _ in Task { await vm.tai() } }
        }
        .onDisappear { huyNghe = nil; RealtimeKeHoachCTW.shared.boNghe(pid: pid) }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .themThe(let c):
                SoanRetroCTW(tieuDe: "Add to \(RetroCot.ten(c))", nut: "Add", goiY: "What's on your mind?", chu: "") { chu in
                    await vm.lam(CTWAPI.themTheRetro(pid: pid, rid: rid, cot: c, noiDung: chu))
                }
            case .suaThe(let the):
                SoanRetroCTW(tieuDe: "Edit card", nut: "Save", goiY: "", chu: the.body ?? "") { chu in
                    await vm.lam(CTWAPI.suaTheRetro(pid: pid, rid: rid, cid: the.id, noiDung: chu))
                }
            case .themViec(let the):
                ThemViecRetroCTW(goiY: the?.body ?? "") { ten, taoThe in
                    await vm.lam(CTWAPI.themViecRetro(pid: pid, rid: rid, ten: ten, cardId: the?.id, taoThe: taoThe))
                }
            }
        }
        .confirmationDialog("Report this card", isPresented: Binding(get: { baoCao != nil }, set: { if !$0 { baoCao = nil } }),
                            titleVisibility: .visible) {
            ForEach(CTWBaoCao.lyDo, id: \.ma) { l in
                Button(l.nhan) {
                    guard let t = baoCao else { return }
                    Task { await baoCaoThe(t, lyDo: l) }
                }
            }
        } message: { Text("The card is hidden for you right away. Our moderators review reports within 24 hours.") }
        .confirmationDialog("Block \(hoiChan?.ten ?? "")?", isPresented: Binding(get: { hoiChan != nil }, set: { if !$0 { hoiChan = nil } }),
                            titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                guard let u = hoiChan else { return }
                Task {
                    do { try await kiemDuyet.block(userId: u.id) } catch { vm.loi = CTW.loi(error) }
                }
            }
        } message: { Text("You won't see their cards, comments or messages anymore.") }
    }

    private func soThe(_ r: CTWRetro, _ c: String) -> String {
        let n = RetroTinh.theCua(cot: c, the: r.cards ?? [], an: anRetro.an, chan: kiemDuyet.blockedUserIds).count
        return n > 0 ? "\(n)" : ""
    }

    // MARK: Đầu

    private func dau(_ r: CTWRetro) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(RetroCot.tenTemplate(r.template)).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                if let s = r.sprint?.name { Text("· \(s)").font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }
                Spacer()
                if r.anonymous == true { nhan("Anonymous", "eye.slash", AppColors.textSecondary) }
                if r.locked == true { nhan("Locked", "lock.fill", AppColors.warning) }
            }
            if r.locked != true, let con = r.me?.votesLeft, let moi = r.votesPerPerson {
                HStack(spacing: 6) {
                    ForEach(0..<moi, id: \.self) { i in
                        Circle().fill(i < con ? AppColors.primary : AppColors.backgroundTertiary).frame(width: 9, height: 9)
                    }
                    Text("\(con) of \(moi) votes left").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(con) of \(moi) votes left")
            } else if r.locked == true {
                Text("This retro is read-only. Action items can still be added.").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private func nhan(_ chu: String, _ bt: String, _ mau: Color) -> some View {
        Label(chu, systemImage: bt).font(.system(size: 11, weight: .bold)).foregroundColor(mau)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(mau.opacity(0.12)))
    }

    // MARK: Cột

    private func cotThe(_ r: CTWRetro, _ c: String) -> some View {
        let ds = RetroTinh.theCua(cot: c, the: r.cards ?? [], an: anRetro.an, chan: kiemDuyet.blockedUserIds)
        let viet = r.me?.canWrite == true && r.locked != true
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: RetroCot.bieuTuong(c)).foregroundColor(AppColors.primary)
                Text(RetroCot.ten(c)).font(.system(size: 15, weight: .semibold))
                Text("\(ds.count)").font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textTertiary)
                Spacer()
                if viet {
                    Button { tamPhu = .themThe(c) } label: { Image(systemName: "plus").frame(width: 36, height: 36) }
                        .accessibilityLabel("Add card to \(RetroCot.ten(c))")
                }
            }
            if ds.isEmpty {
                Text(viet ? "No cards yet. Tap + to add one." : "No cards.")
                    .font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            ForEach(ds, id: \.the.id) { x in theRetro(r, x.the).padding(.leading, x.con ? 18 : 0) }
            if viet && !ds.isEmpty {
                Button { tamPhu = .themThe(c) } label: {
                    Label("Add card", systemImage: "plus").font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundTertiary.opacity(0.6)))
    }

    private func theRetro(_ r: CTWRetro, _ t: CTWRetroThe) -> some View {
        let viet = r.me?.canWrite == true && r.locked != true
        let cuaToi = t.mine == true
        return VStack(alignment: .leading, spacing: 8) {
            Text(t.body ?? "").font(.system(size: 15)).foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if let a = t.author {
                    CTWAvatar(user: a, size: 18)
                    Text(a.ten).font(.system(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    if a.laAgent { CTWNhanAI() }
                } else if r.anonymous == true {
                    Image(systemName: "person.fill.questionmark").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    Text(cuaToi ? "You (anonymous)" : "Anonymous").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                Button {
                    Task { await vm.phieu(t, them: true) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: (t.myVotes ?? 0) > 0 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("\(t.votes ?? 0)").monospacedDigit()
                        if (t.myVotes ?? 0) > 0 { Text("(\(t.myVotes ?? 0) mine)").font(.system(size: 10)) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor((t.myVotes ?? 0) > 0 ? AppColors.primary : AppColors.textSecondary)
                    .padding(.horizontal, 10).frame(minHeight: 32)
                    .background(Capsule().fill(((t.myVotes ?? 0) > 0 ? AppColors.primary : AppColors.textSecondary).opacity(0.10)))
                }
                .buttonStyle(.plain)
                .disabled(!viet || (r.me?.votesLeft ?? 0) == 0)
                .accessibilityLabel("\(t.votes ?? 0) votes. Vote for this card")
            }
        }
        .padding(12)
        .ctwThe(12)
        .contextMenu {
            Button { CTW.chepVaoBoNho(t.body ?? "") } label: { Label("Copy text", systemImage: "doc.on.doc") }
            if viet && (t.myVotes ?? 0) > 0 {
                Button { Task { await vm.phieu(t, them: false) } } label: { Label("Remove my vote", systemImage: "hand.thumbsdown") }
            }
            if r.me?.canWrite == true || r.locked == true {
                Button { tamPhu = .themViec(t) } label: { Label("Make action item", systemImage: "checklist") }
            }
            if viet && cuaToi {
                Button { tamPhu = .suaThe(t) } label: { Label("Edit", systemImage: "pencil") }
            }
            if viet && (cuaToi || r.me?.canFacilitate == true) {
                Button(role: .destructive) { Task { await vm.lam(CTWAPI.xoaTheRetro(pid: pid, rid: rid, cid: t.id)) } } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            if !cuaToi {
                Button(role: .destructive) { baoCao = t } label: { Label("Report card", systemImage: "flag") }
                if let a = t.author, a.id != app.currentUser?.id {
                    Button(role: .destructive) { hoiChan = a } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
                }
            }
        }
    }

    // MARK: Action items

    private func viec(_ r: CTWRetro) -> some View {
        let ds = r.actions ?? []
        return VStack(alignment: .leading, spacing: 0) {
            CTWSectionHeader("checklist", "Action items", count: "\(ds.count)",
                             trailing: r.me?.canFacilitate == true || r.me?.canWrite == true || r.locked == true
                                ? AnyView(Button { tamPhu = .themViec(nil) } label: { Image(systemName: "plus").frame(width: 36, height: 36) }
                                    .accessibilityLabel("Add action item"))
                                : nil)
                .padding(.bottom, 6)
            if ds.isEmpty {
                Text("Turn the top-voted cards into action items so they don't get lost.")
                    .font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(Array(ds.enumerated()), id: \.element.id) { i, a in
                HStack(spacing: 10) {
                    Image(systemName: a.issue?.status?.category == "DONE" ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(a.issue?.status?.category == "DONE" ? AppColors.success : AppColors.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.title ?? "").font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                        if let so = a.issue?.number {
                            Text("\(app.luaChon?.maDuAn ?? "")-\(so) · \(a.issue?.status?.name ?? "")")
                                .font(.system(size: 11, weight: .medium).monospaced()).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    Spacer()
                    if let u = a.assignee { CTWAvatar(user: u, size: 22) }
                    if let so = a.issue?.number {
                        NavigationLink(value: CTWRoute.the(pid: pid, so: so)) { Image(systemName: "chevron.right").foregroundColor(AppColors.textTertiary) }
                            .frame(width: 32, height: 44)
                    }
                }
                .frame(minHeight: 44)
                .contextMenu {
                    if r.me?.canWrite == true || r.me?.canFacilitate == true {
                        Button(role: .destructive) { Task { await vm.lam(CTWAPI.xoaViecRetro(pid: pid, rid: rid, aid: a.id)) } } label: {
                            Label("Remove action item", systemImage: "trash")
                        }
                    }
                }
                if i < ds.count - 1 { Divider() }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    private func tomTatAI(_ s: String, _ luc: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Summary").font(.system(size: 15, weight: .semibold))
                CTWNhanAI(chu: "AI summary")
                Spacer()
                if let luc { Text(CTW.thoiDiem(luc)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary) }
            }
            CTWMarkdownView(markdown: s)
            Text("Generated by AI on the web. It can be inaccurate — check it against the cards.")
                .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .padding(14)
        .ctwThe(14)
    }

    private func baoCaoThe(_ t: CTWRetroThe, lyDo l: (ma: String, nhan: String, chung: ReportReason)) async {
        let tacGia = t.author.map { "user #\($0.id)\($0.laAgent ? " (AI agent)" : "")" } ?? "anonymous"
        do {
            try await ModerationStore.shared.baoCaoNoiDung(
                nhan: "CT WORK RETRO CARD #\(t.id) · \(tacGia)", noiDung: t.body ?? "",
                ngucanh: "\(app.luaChon?.maDuAn ?? "") · retro #\(rid)", lyDo: l.chung, chiTiet: l.nhan)
            RetroAnCTW.shared.anThe(t.id)
            CTWRung.thanhCong()
        } catch { vm.loi = CTW.loi(error) }
    }
}

// MARK: - Soạn thẻ / action item

struct SoanRetroCTW: View {
    let tieuDe: String
    let nut: String
    let goiY: String
    @State var chu: String
    let gui: (String) async -> Void
    @Environment(\.dismiss) private var dong
    @State private var dangGui = false
    @FocusState private var tapTrung: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(goiY, text: $chu, axis: .vertical).lineLimit(3...10).focused($tapTrung)
                } footer: { Text("\(chu.count)/1000") }
            }
            .navigationTitle(tieuDe)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dangGui = true
                        Task { await gui(chu.trimmingCharacters(in: .whitespacesAndNewlines)); dangGui = false; dong() }
                    } label: { if dangGui { ProgressView() } else { Text(nut).bold() } }
                    .disabled(chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chu.count > 1000 || dangGui)
                }
            }
            .onAppear { tapTrung = true }
        }
        .presentationDetents([.medium, .large])
    }
}

struct ThemViecRetroCTW: View {
    let goiY: String
    let gui: (String, Bool) async -> Void
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var taoThe = true
    @State private var dangGui = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") { TextField("What will the team do?", text: $ten, axis: .vertical).lineLimit(1...4) }
                Section {
                    Toggle("Create an issue for it", isOn: $taoThe)
                } footer: { Text("Creates a task in the backlog so the action is tracked.") }
            }
            .navigationTitle("New action item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dangGui = true
                        Task { await gui(ten.trimmingCharacters(in: .whitespacesAndNewlines), taoThe); dangGui = false; dong() }
                    } label: { if dangGui { ProgressView() } else { Text("Add").bold() } }
                    .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangGui)
                }
            }
            .onAppear { if ten.isEmpty { ten = String(goiY.prefix(255)) } }
        }
        .presentationDetents([.medium])
    }
}
