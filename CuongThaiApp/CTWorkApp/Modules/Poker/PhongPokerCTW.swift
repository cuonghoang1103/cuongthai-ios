import SwiftUI
import Charts
import Combine

// MARK: - Phòng Planning Poker
//
// Bài ÚP cho tới khi lật: máy chủ chỉ trả `voted` (ai đã chọn) + `myVote` (lá của mình);
// `votes`/`distribution` = nil khi PENDING/VOTING. Hẹn giờ hết ⇒ máy chủ tự lật "lười"
// (ở lượt GET kế tiếp) ⇒ app đếm ngược theo `serverNow` rồi tải lại khi về 0.

@MainActor
final class PhongPokerVM: ObservableObject {
    let pid: Int
    let sid: Int
    @Published var phong: TaiCTW<CTWPokerPhong> = .dangTai
    @Published var taiLuc = Date()
    @Published var loi: String?
    @Published var dangLam = false

    init(pid: Int, sid: Int) { self.pid = pid; self.sid = sid }

    func tai() async {
        do {
            let p: CTWPokerPhong = try await APIClient.shared.request(CTWAPI.phongPoker(pid: pid, sid: sid))
            phong = .xong(p)
            taiLuc = Date()
        } catch { if phong.giaTri == nil { phong = .loi(CTW.loi(error)) } else { loi = CTW.loi(error) } }
    }

    func lam(_ ep: APIEndpoint) async {
        dangLam = true
        defer { dangLam = false }
        do {
            try await APIClient.shared.send(ep)
            loi = nil
            await tai()
        } catch { loi = CTW.loi(error); CTWRung.loi(); await tai() }
    }
}

struct PhongPokerCTW: View {
    let pid: Int
    let sid: Int
    let ten: String
    @EnvironmentObject private var app: AppState
    @StateObject private var vm: PhongPokerVM
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var huyNghe: AnyCancellable?
    @State private var chotGiaTri: String?
    @State private var hoiDong = false

    init(pid: Int, sid: Int, ten: String) {
        self.pid = pid; self.sid = sid; self.ten = ten
        _vm = StateObject(wrappedValue: PhongPokerVM(pid: pid, sid: sid))
    }

    var body: some View {
        KhungTaiCTW(trangThai: vm.phong, thuLai: { Task { await vm.tai() } }) { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let l = vm.loi { CTWErrorBanner(text: l) { vm.loi = nil } }
                    dau(p)
                    if let m = p.mucHienTai {
                        theDangUocLuong(p, m)
                        nguoiBau(p, m)
                        if beRong == .regular {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 14) { if !m.daLat { boBai(p, m) } ; dieuPhoi(p, m) }
                                if m.daLat { ketQua(p, m) }
                            }
                        } else {
                            if m.daLat { ketQua(p, m) } else { boBai(p, m) }
                            dieuPhoi(p, m)
                        }
                    } else if !p.daDong {
                        CTWOTrong(bieuTuong: "hand.raised", tieuDe: String(localized: "Waiting for the facilitator"),
                                  moTa: p.me?.canFacilitate == true ? String(localized: "Pick an issue below to start voting.") : String(localized: "Voting starts when the facilitator picks an issue."))
                            .ctwThe(14)
                    }
                    dsMuc(p)
                }
                .padding(Spacing.md)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.phong.giaTri?.title ?? ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let p = vm.phong.giaTri, p.me?.canFacilitate == true, !p.daDong {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Menu("Timer") {
                            ForEach([30, 60, 90, 120, 180, 300], id: \.self) { g in
                                Button(g < 60 ? String(localized: "\(g) seconds") : (g % 60 == 30 ? String(localized: "\(g / 60) min 30 s") : String(localized: "\(g / 60) min"))) {
                                    Task { await vm.lam(CTWAPI.henGioPoker(pid: pid, sid: sid, giay: g)) }
                                }
                            }
                            Button("Clear timer") { Task { await vm.lam(CTWAPI.henGioPoker(pid: pid, sid: sid, giay: 0)) } }
                        }
                        .disabled(p.mucHienTai?.state != "VOTING")
                        Button(role: .destructive) { hoiDong = true } label: { Label("Close session", systemImage: "lock") }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Session actions")
                }
            }
        }
        .refreshable { await vm.tai() }
        .task { await vm.tai() }
        // Lưới an toàn khi socket rớt: 30 giây tải lại một lần (như web).
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await vm.tai()
            }
        }
        .onAppear {
            RealtimeKeHoachCTW.shared.nghe(pid: pid)
            huyNghe = RealtimeKeHoachCTW.shared.suKienAgile
                .filter { [pid, sid] in $0.projectId == pid && $0.kind == "poker" && $0.id == sid }
                .sink { _ in Task { await vm.tai() } }
        }
        .onDisappear { huyNghe = nil; RealtimeKeHoachCTW.shared.boNghe(pid: pid) }
        .confirmationDialog("Close this session?", isPresented: $hoiDong, titleVisibility: .visible) {
            Button("Close session", role: .destructive) { Task { await vm.lam(CTWAPI.dongPoker(pid: pid, sid: sid)) } }
        } message: { Text("No more votes can be cast. Final estimates stay on the issues.") }
    }

    // MARK: Đầu phòng

    private func dau(_ p: CTWPokerPhong) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(p.deck == "TSHIRT" ? "T-shirt sizes" : "Fibonacci").font(.ctw(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    if let s = p.sprint?.name { Text("· \(s)").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                }
                if let f = p.facilitator {
                    HStack(spacing: 5) {
                        CTWAvatar(user: f, size: 18)
                        Text("Facilitator: \(f.ten)").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            Spacer()
            if p.daDong {
                Label("Closed", systemImage: "lock.fill").font(.ctw(size: 12, weight: .bold)).foregroundColor(AppColors.textSecondary)
            } else if p.mucHienTai?.state == "VOTING", p.timerEndsAt != nil {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let con = PokerTinh.giayConLai(ketThuc: p.timerEndsAt, serverNow: p.serverNow, taiLuc: vm.taiLuc, bayGio: ctx.date) ?? 0
                    Label(CTWSo.dongHo(giay: con), systemImage: "timer")
                        .font(.ctw(size: 15, weight: .bold).monospacedDigit())
                        .foregroundColor(con <= 10 ? AppColors.error : AppColors.primary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill((con <= 10 ? AppColors.error : AppColors.primary).opacity(0.12)))
                        .onChange(of: con == 0) { _, het in if het { Task { await vm.tai() } } }
                        .accessibilityLabel("\(con) seconds left")
                }
            }
        }
    }

    // MARK: Thẻ đang ước lượng

    private func theDangUocLuong(_ p: CTWPokerPhong, _ m: CTWPokerMuc) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let t = m.issue?.type {
                    Image(systemName: CTW.bieuTuongLoai(key: t.key)).font(.ctw(size: 10, weight: .bold)).foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(CTW.mau(t.color, macDinh: AppColors.info)))
                }
                Text("\(app.luaChon?.maDuAn ?? "")-\(m.issue?.number ?? 0)").font(.ctw(size: 12, weight: .semibold).monospaced())
                    .foregroundColor(AppColors.textSecondary)
                nhanTrangThai(m)
                Spacer()
                if (m.round ?? 1) > 1 { Text("Round \(m.round ?? 1)").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
            }
            Text(m.issue?.title ?? "").font(.ctw(size: 19, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let d = m.issue?.description, !d.isEmpty {
                Text(d).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).lineLimit(5)
            }
            if let sp = m.previousPoints ?? m.issue?.storyPoints {
                Text("Current estimate: \(CTWSo.gon(sp)) pts").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            }
            if let issue = m.issue {
                NavigationLink(value: CTWRoute.the(pid: pid, so: issue.number)) {
                    Label("Open issue", systemImage: "arrow.up.forward.square").font(.ctw(size: 13, weight: .semibold))
                }
            }
        }
        .padding(16)
        .ctwThe(16)
    }

    private func nhanTrangThai(_ m: CTWPokerMuc) -> some View {
        let (chu, mau): (String, Color) = {
            switch m.state {
            case "VOTING": return (String(localized: "VOTING"), AppColors.primary)
            case "REVEALED": return (String(localized: "REVEALED"), CTWMauChuoi.mau(1))
            case "ESTIMATED": return (String(localized: "ESTIMATED"), AppColors.success)
            case "SKIPPED": return (String(localized: "SKIPPED"), AppColors.textTertiary)
            default: return (String(localized: "PENDING"), AppColors.textTertiary)
            }
        }()
        return Text(chu).font(.ctw(size: 10, weight: .bold)).foregroundColor(mau)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(mau.opacity(0.12)))
    }

    // MARK: Ai đã bầu

    private func nguoiBau(_ p: CTWPokerPhong, _ m: CTWPokerMuc) -> some View {
        let daBau = Set(m.voted ?? [])
        let ds = p.voters ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(daBau.count) of \(ds.count) voted").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ds) { u in
                        VStack(spacing: 4) {
                            CTWAvatar(user: u, size: 34)
                                .overlay(alignment: .topTrailing) {
                                    if daBau.contains(u.id) {
                                        Image(systemName: "checkmark.circle.fill").font(.ctw(size: 14))
                                            .foregroundStyle(.white, AppColors.success).offset(x: 5, y: -4)
                                    }
                                }
                                .opacity(daBau.contains(u.id) ? 1 : 0.45)
                            Text(u.ten.split(separator: " ").first.map(String.init) ?? u.ten)
                                .font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary).fixedSize()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(daBau.contains(u.id) ? "\(u.ten), voted" : "\(u.ten), not voted yet")
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: Bộ bài

    private func boBai(_ p: CTWPokerPhong, _ m: CTWPokerMuc) -> some View {
        let duocBau = p.me?.canVote == true && m.state == "VOTING" && !p.daDong
        return VStack(alignment: .leading, spacing: 10) {
            Text(duocBau ? "Pick your card" : (m.state == "VOTING" ? "Voting in progress" : "Voting hasn't started"))
                .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
                ForEach(PokerTinh.boBai(p), id: \.self) { la in
                    let chon = m.myVote == la
                    Button {
                        CTWRung.chon()
                        Task { await vm.lam(CTWAPI.boPhieuPoker(pid: pid, sid: sid, iid: m.id, giaTri: chon ? nil : la)) }
                    } label: {
                        Text(la).font(.ctw(size: 24, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .foregroundColor(chon ? AppColors.onPrimary : AppColors.textPrimary)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(chon ? AppColors.primary : AppColors.backgroundCard))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(chon ? Color.clear : AppColors.border, lineWidth: 1))
                            .shadow(color: .black.opacity(chon ? 0.15 : 0.04), radius: chon ? 6 : 2, y: chon ? 3 : 1)
                            .scaleEffect(chon ? 1.04 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(!duocBau || vm.dangLam)
                    .opacity(duocBau ? 1 : 0.5)
                    .accessibilityLabel(la == "☕" ? "Coffee break" : (la == "?" ? "Not sure" : "\(la) points"))
                    .accessibilityAddTraits(chon ? .isSelected : [])
                }
            }
            if duocBau && m.myVote != nil {
                Text("Tap your card again to withdraw it. Cards stay hidden until the facilitator reveals them.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    // MARK: Kết quả sau khi lật

    private func ketQua(_ p: CTWPokerPhong, _ m: CTWPokerMuc) -> some View {
        let d = m.distribution
        let dem = d?.counts ?? []
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Results").font(.ctw(size: 15, weight: .semibold))
                Spacer()
                if d?.consensus == true {
                    Label("Consensus", systemImage: "checkmark.seal.fill").font(.ctw(size: 12, weight: .bold)).foregroundColor(AppColors.success)
                } else {
                    Label("No consensus", systemImage: "arrow.left.and.right").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.warning)
                }
            }
            CTWLuoiChiSo {
                CTWTheChiSo(nhan: String(localized: "Average"), giaTri: d?.average.map(CTWSo.gon) ?? "—", bieuTuong: "sum")
                CTWTheChiSo(nhan: String(localized: "Median"), giaTri: d?.median.map(CTWSo.gon) ?? "—", bieuTuong: "line.3.horizontal.decrease")
                CTWTheChiSo(nhan: String(localized: "Suggested"), giaTri: d?.suggested ?? "—", phu: [d?.low, d?.high].compactMap { $0 }.count == 2 ? String(localized: "Range \(d?.low ?? "") – \(d?.high ?? "")") : nil,
                            bieuTuong: "wand.and.stars", mau: AppColors.success)
                if let f = m.finalValue {
                    CTWTheChiSo(nhan: String(localized: "Final"), giaTri: f, phu: m.finalPoints.map { String(localized: "\(CTWSo.gon($0)) pts") }, bieuTuong: "flag.checkered", mau: AppColors.success)
                }
            }
            if !dem.isEmpty {
                Chart(dem, id: \.value) { c in
                    BarMark(x: .value("Card", c.value), y: .value("Votes", c.count), width: .ratio(0.6))
                        .foregroundStyle(c.value == d?.mode ? AppColors.primary : CTWMauChuoi.mau(0))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                        .annotation(position: .top) {
                            Text("\(c.count)").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        }
                }
                .chartYAxis(.hidden)
                .frame(height: 150)
                .accessibilityLabel(dem.map { "\($0.value): \($0.count)" }.joined(separator: ", "))
            }
            if let v = m.votes, !v.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(Array(v.enumerated()), id: \.offset) { _, x in
                        HStack(spacing: 6) {
                            CTWAvatar(user: x.user, size: 22)
                            Text(x.user?.ten ?? "—").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                            Spacer(minLength: 2)
                            Text(x.value).font(.ctw(size: 14, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.backgroundTertiary))
                    }
                }
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    // MARK: Điều phối

    @ViewBuilder
    private func dieuPhoi(_ p: CTWPokerPhong, _ m: CTWPokerMuc) -> some View {
        if p.me?.canFacilitate == true && !p.daDong {
            VStack(alignment: .leading, spacing: 10) {
                Text("Facilitator").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                if m.state == "VOTING" {
                    HStack(spacing: 8) {
                        nut(String(localized: "Reveal cards"), "eye.fill", chinh: true) { await vm.lam(CTWAPI.lenhMucPoker(pid: pid, sid: sid, iid: m.id, lenh: "reveal")) }
                        nut(String(localized: "Skip"), "forward.fill") { await vm.lam(CTWAPI.lenhMucPoker(pid: pid, sid: sid, iid: m.id, lenh: "skip")) }
                    }
                } else if m.daLat {
                    Menu {
                        ForEach(PokerTinh.laChotDuoc(p), id: \.self) { la in
                            Button(la == m.distribution?.suggested ? String(localized: "\(la) (suggested)") : la) {
                                Task { await vm.lam(CTWAPI.chotPoker(pid: pid, sid: sid, iid: m.id, giaTri: la)) ; CTWRung.thanhCong() }
                            }
                        }
                    } label: {
                        Label(m.state == "ESTIMATED" ? "Change final estimate" : "Save estimate…", systemImage: "checkmark.circle.fill")
                            .font(.ctw(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundColor(AppColors.onPrimary)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary))
                    }
                    HStack(spacing: 8) {
                        nut(String(localized: "Vote again"), "arrow.counterclockwise") { await vm.lam(CTWAPI.lenhMucPoker(pid: pid, sid: sid, iid: m.id, lenh: "revote")) }
                        if let tiep = mucKeTiep(p, sau: m) {
                            nut(String(localized: "Next issue"), "arrow.right") { await vm.lam(CTWAPI.lenhMucPoker(pid: pid, sid: sid, iid: tiep.id, lenh: "start")) }
                        }
                    }
                } else {
                    nut(String(localized: "Start voting"), "play.fill", chinh: true) { await vm.lam(CTWAPI.lenhMucPoker(pid: pid, sid: sid, iid: m.id, lenh: "start")) }
                }
            }
            .padding(14)
            .ctwThe(14)
            .disabled(vm.dangLam)
        }
    }

    private func mucKeTiep(_ p: CTWPokerPhong, sau m: CTWPokerMuc) -> CTWPokerMuc? {
        let ds = (p.items ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }
        let i = ds.firstIndex { $0.id == m.id } ?? -1
        return ds.dropFirst(i + 1).first { $0.state == "PENDING" } ?? ds.first { $0.state == "PENDING" && $0.id != m.id }
    }

    private func nut(_ chu: String, _ bieuTuong: String, chinh: Bool = false, _ f: @escaping () async -> Void) -> some View {
        Button { Task { await f() } } label: {
            Label(chu, systemImage: bieuTuong).font(.ctw(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(chinh ? AppColors.primary : AppColors.textSecondary)
    }

    // MARK: Danh sách thẻ trong phiên

    private func dsMuc(_ p: CTWPokerPhong) -> some View {
        let ds = (p.items ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }
        let xong = ds.filter { $0.state == "ESTIMATED" }.count
        return VStack(alignment: .leading, spacing: 0) {
            CTWSectionHeader("list.number", String(localized: "Issues"), count: "\(xong)/\(ds.count)")
                .padding(.bottom, 8)
            ForEach(Array(ds.enumerated()), id: \.element.id) { i, m in
                Button {
                    guard p.me?.canFacilitate == true, !p.daDong, m.id != p.currentItemId else { return }
                    Task { await vm.lam(CTWAPI.lenhMucPoker(pid: pid, sid: sid, iid: m.id, lenh: "start")) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: m.id == p.currentItemId ? "arrowtriangle.right.fill" : (m.state == "ESTIMATED" ? "checkmark.circle.fill" : (m.state == "SKIPPED" ? "forward.circle" : "circle")))
                            .font(.ctw(size: 13))
                            .foregroundColor(m.state == "ESTIMATED" ? AppColors.success : (m.id == p.currentItemId ? AppColors.primary : AppColors.textTertiary))
                            .frame(width: 18)
                        Text("\(app.luaChon?.maDuAn ?? "")-\(m.issue?.number ?? 0)").font(.ctw(size: 12, weight: .medium).monospaced())
                            .foregroundColor(AppColors.textSecondary)
                        Text(m.issue?.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Spacer(minLength: 6)
                        if let f = m.finalValue {
                            Text(f).font(.ctw(size: 13, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.success.opacity(0.14)))
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(p.me?.canFacilitate == true ? "Starts voting on this issue" : "")
                if i < ds.count - 1 { Divider() }
            }
        }
        .padding(14)
        .ctwThe(14)
    }
}
