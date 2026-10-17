import SwiftUI
import Combine

// MARK: - Chat nhóm của dự án
//
// Backend: `work.ctwk3.routes.ts` + `services/work/chat.service.ts`.
//   · danh sách kênh `GET /projects/:pid/chat/channels` ⇒ `{channels, total, me}`
//   · tin `GET …/messages?before&limit` ⇒ `{messages (cũ→mới), hasMoreBefore}`
//   · gửi `POST …/messages {body, clientKey}` — `clientKey` để gửi lại khi mất
//     mạng không thành hai tin
//   · sửa (chỉ tác giả) / xoá (tác giả hoặc ADMIN dự án)
//   · realtime: `work:chat:event` trong phòng kênh (`RealtimeCTW`)
// Nội dung người dùng (1.2): báo cáo + ẩn tin + chặn người gửi; tin của
// người đã chặn bị ẩn. Tin của AI agent gắn nhãn "AI agent".

/// Route con của mô-đun Chat (đăng ký ở `MoDunChat.swift`).
struct RouteKenhCTW: Hashable {
    var pid: Int
    var kenh: CTWChannel
    var tenDuAn: String
}

/// Danh sách kênh của dự án đang chọn. CHỈ nội dung — khung bọc NavigationStack.
struct ChatCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var dsKenh: CTWChannelList?
    @State private var loi: String?
    @State private var moChon = false

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if let ds = dsKenh?.channels {
                let kenh = ds.filter { $0.archived != true }
                if kenh.isEmpty {
                    CTWOTrong(bieuTuong: "number", tieuDe: "No channels yet",
                              moTa: "Channels your team creates on the web appear here.")
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(kenh) { k in
                        NavigationLink(value: RouteKenhCTW(pid: nguCanh.pid, kenh: k, tenDuAn: nguCanh.tenDuAn)) { hang(k) }
                    }
                } header: {
                    if !kenh.isEmpty { Text("\(nguCanh.maDuAn) · \(nguCanh.tenDuAn)") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if dsKenh == nil && loi == nil { CTWKhungTai(soHang: 4) } }
        .refreshable { await tai() }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { moChon = true } label: {
                    HStack(spacing: 4) {
                        Text(nguCanh.maDuAn).font(.system(size: 15, weight: .bold).monospaced())
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                }
                .accessibilityLabel("Switch project, current \(nguCanh.tenDuAn)")
            }
        }
        .sheet(isPresented: $moChon) { ChonDuAnCTW() }
        .onReceive(RealtimeCTW.shared.suKienChat.filter { [pid = nguCanh.pid] in $0.projectId == pid && $0.type != "reaction" }) { _ in
            Task { await tai() }
        }
        .task { if dsKenh == nil { await tai() } }
        .task(id: app.dichCho) { await moDich() }
    }

    private func hang(_ k: CTWChannel) -> some View {
        let dam = (k.badge ?? 0) > 0
        return HStack(spacing: 12) {
            Image(systemName: k.kind == "PRIVATE" ? "lock.fill" : (k.kind == "CLIENT" ? "person.2.fill" : "number"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(k.name).font(.system(size: 15, weight: dam ? .bold : .medium)).foregroundColor(AppColors.textPrimary)
                    if k.muted == true { Image(systemName: "bell.slash.fill").font(.system(size: 10)).foregroundColor(AppColors.textTertiary) }
                }
                if let t = k.topic, !t.isEmpty {
                    Text(t).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            Spacer()
            if let m = k.mentions, m > 0 {
                Text("@").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .frame(width: 20, height: 20).background(Circle().fill(AppColors.error))
                    .accessibilityLabel("\(m) mentions")
            }
            if dam {
                Text("\(k.badge ?? 0)").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(AppColors.primary))
                    .accessibilityLabel("\(k.badge ?? 0) unread")
            }
        }
        .padding(.vertical, 3)
    }

    private func tai() async {
        do {
            dsKenh = try await APIClient.shared.request(CTWAPI.dsKenh(pid: nguCanh.pid))
            loi = nil
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" {
                loi = "Chat is turned off for this project."
            } else {
                loi = CTW.loi(error)
            }
        }
    }

    /// Đích `/work/<ws>/<KEY>/chat?c=<cid>` (khung đã chọn đúng dự án trước).
    private func moDich() async {
        guard let d = app.dichCho, d.moDun == "chat", d.pid == nil || d.pid == nguCanh.pid else { return }
        // ⚠️ Xoá cờ ở CUỐI: đổi `dichCho` làm `.task(id:)` HUỶ chính tác vụ này
        // ⇒ mọi `await` sau đó ném CancellationError (đã dính 17/10/2026).
        defer { app.dichCho = nil }
        if dsKenh == nil { await tai() }
        guard let cid = d.duongDan.tham["c"].flatMap(Int.init),
              let k = dsKenh?.channels?.first(where: { $0.id == cid }) else { return }
        var p = NavigationPath()
        p.append(RouteKenhCTW(pid: nguCanh.pid, kenh: k, tenDuAn: nguCanh.tenDuAn))
        nganXep.duong = p
    }
}

// MARK: - Một kênh

@MainActor
final class KenhChatVM: ObservableObject {
    let pid: Int
    let kenh: CTWChannel
    @Published var tin: [CTWChatMessage] = []
    @Published var conCu = false
    @Published var loi: String?
    @Published var dangTai = false
    @Published var dangGui = false
    private var huy = Set<AnyCancellable>()

    init(pid: Int, kenh: CTWChannel) {
        self.pid = pid
        self.kenh = kenh
        RealtimeCTW.shared.suKienChat
            .filter { [pid, cid = kenh.id] in $0.projectId == pid && $0.channelId == cid }
            .sink { [weak self] sk in Task { await self?.nhan(sk) } }
            .store(in: &huy)
    }

    func batDau() async {
        RealtimeCTW.shared.vaoKenh(pid: pid, cid: kenh.id)
        await tai()
    }

    func ketThuc() { RealtimeCTW.shared.roiKenh(pid: pid, cid: kenh.id) }

    func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            let p: CTWChatPage = try await APIClient.shared.request(CTWAPI.dsTin(pid: pid, cid: kenh.id))
            tin = p.messages ?? []
            conCu = p.hasMoreBefore == true
            loi = nil
            _ = try? await APIClient.shared.send(CTWAPI.daDocKenh(pid: pid, cid: kenh.id))
            await AppState.shared.taiSoChuaDoc()
        } catch { loi = CTW.loi(error) }
    }

    func taiCu() async {
        guard conCu, !dangTai, let dau = tin.first?.id else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            let p: CTWChatPage = try await APIClient.shared.request(CTWAPI.dsTin(pid: pid, cid: kenh.id, truoc: dau))
            let co = Set(tin.map(\.id))
            tin = (p.messages ?? []).filter { !co.contains($0.id) } + tin
            conCu = p.hasMoreBefore == true
        } catch { loi = CTW.loi(error) }
    }

    func gui(_ chu: String) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        dangGui = true
        defer { dangGui = false }
        do {
            let m: CTWChatMessage = try await APIClient.shared.request(
                CTWAPI.guiTin(pid: pid, cid: kenh.id, chu: s, traLoi: nil, khoa: UUID().uuidString))
            chen(m)
            loi = nil
            CTWRung.chon()
            return true
        } catch {
            loi = CTW.loi(error)
            return false
        }
    }

    func sua(_ m: CTWChatMessage, chu: String) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        do {
            let moi: CTWChatMessage = try await APIClient.shared.request(CTWAPI.suaTin(pid: pid, cid: kenh.id, mid: m.id, chu: s))
            chen(moi)
            return true
        } catch {
            loi = CTW.loi(error)
            return false
        }
    }

    func xoa(_ m: CTWChatMessage) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaTin(pid: pid, cid: kenh.id, mid: m.id))
            tin.removeAll { $0.id == m.id }
        } catch { loi = CTW.loi(error) }
    }

    private func chen(_ m: CTWChatMessage) {
        guard m.parentId == nil else { return }
        if let i = tin.firstIndex(where: { $0.id == m.id }) { tin[i] = m } else {
            tin.append(m)
            tin.sort { $0.id < $1.id }
        }
    }

    private func nhan(_ sk: SuKienChatCTW) async {
        switch sk.type {
        case "message":
            if let m = sk.message, m.parentId == nil {
                chen(m)
            } else if let id = sk.messageId, sk.parentId == nil,
                      let m: CTWChatMessage = try? await APIClient.shared.request(CTWAPI.motTin(pid: pid, cid: kenh.id, mid: id)) {
                chen(m)
            } else if let p = sk.parentId, let i = tin.firstIndex(where: { $0.id == p }) {
                tin[i].replyCount = (tin[i].replyCount ?? 0) + 1
            }
            _ = try? await APIClient.shared.send(CTWAPI.daDocKenh(pid: pid, cid: kenh.id))
        case "update", "reaction", "pin":
            guard let id = sk.messageId, sk.parentId == nil,
                  let m: CTWChatMessage = try? await APIClient.shared.request(CTWAPI.motTin(pid: pid, cid: kenh.id, mid: id)) else { return }
            chen(m)
        case "delete":
            if let id = sk.messageId { tin.removeAll { $0.id == id } }
        default:
            break
        }
    }
}

private enum TamPhuChat: Identifiable {
    case sua(CTWChatMessage)
    case chuoi(CTWChatMessage)
    var id: String {
        switch self {
        case .sua(let m): return "s\(m.id)"
        case .chuoi(let m): return "c\(m.id)"
        }
    }
}

struct KenhChatCTW: View {
    let pid: Int
    let kenh: CTWChannel
    let tenDuAn: String
    @StateObject private var vm: KenhChatVM
    @EnvironmentObject private var app: AppState
    @ObservedObject private var kd = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungCTW.shared
    @State private var nhap = ""
    @State private var baoCao: CTWChatMessage?
    @State private var hoiChan: CTWUser?
    @State private var hoiXoa: CTWChatMessage?
    @State private var thongBao: String?
    @State private var tamPhu: TamPhuChat?
    @FocusState private var dangGo: Bool
    @Environment(\.horizontalSizeClass) private var beRong

    init(pid: Int, kenh: CTWChannel, tenDuAn: String) {
        self.pid = pid
        self.kenh = kenh
        self.tenDuAn = tenDuAn
        _vm = StateObject(wrappedValue: KenhChatVM(pid: pid, kenh: kenh))
    }

    private var tinHien: [CTWChatMessage] {
        vm.tin.filter { m in
            if an.tinAn.contains(m.id) { return false }
            if let a = m.author?.id, kd.blockedUserIds.contains(a) { return false }
            return !(m.daXoa && (m.replyCount ?? 0) == 0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.padding(.horizontal, Spacing.md).padding(.top, 6)
            }
            ScrollViewReader { cuon in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if vm.conCu {
                            Button("Load earlier messages") { Task { await vm.taiCu() } }
                                .font(.system(size: 13)).frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        if !vm.dangTai && tinHien.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 28)).foregroundColor(AppColors.primary)
                                Text("No messages yet").font(.headline).foregroundColor(AppColors.textPrimary)
                                Text("Say hello to your team.").font(.subheadline).foregroundColor(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity).padding(.top, 60)
                        }
                        ForEach(Array(tinHien.enumerated()), id: \.element.id) { i, m in
                            let truoc = i > 0 ? tinHien[i - 1] : nil
                            let gop = truoc != nil && truoc?.author?.id == m.author?.id && !m.laHeThong && truoc?.laHeThong == false
                                && khoangPhut(truoc?.createdAt, m.createdAt) < 5
                            TinChatCTW(tin: m, gop: gop, laCuaToi: m.author?.id == app.currentUser?.id)
                                .id(m.id)
                                .contextMenu { menu(m) }
                                .onTapGesture { if (m.replyCount ?? 0) > 0 { tamPhu = .chuoi(m) } }
                        }
                        Color.clear.frame(height: 4).id("day")
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, 8)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.bottom)
                .onChange(of: vm.tin.last?.id) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { cuon.scrollTo("day", anchor: .bottom) }
                }
            }
            oNhap
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("#\(kenh.name)")
        .navigationBarTitleDisplayMode(.inline)
        // Tiêu đề hai dòng (tên + chủ đề) — đặt tường minh ở `.principal`: trên iPad
        // (cột chi tiết của NavigationSplitView) tiêu đề trơn của kênh không hiện.
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("#\(kenh.name)").font(.system(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    if let t = kenh.topic, !t.isEmpty {
                        Text(t).font(.system(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
        }
        // Kênh chat cần chỗ cho ô nhập + bàn phím ⇒ ẩn thanh tab (CHỈ iPhone —
        // trong NavigationSplitView của iPad, ẩn tabBar làm mất luôn tiêu đề kênh).
        .toolbar(beRong == .compact ? .hidden : .automatic, for: .tabBar)
        .task { await vm.batDau() }
        .onDisappear { vm.ketThuc() }
        .confirmationDialog("Report this message", isPresented: Binding(get: { baoCao != nil }, set: { if !$0 { baoCao = nil } }),
                            titleVisibility: .visible) {
            ForEach(CTWBaoCao.lyDo, id: \.ma) { l in
                Button(l.nhan, role: .destructive) {
                    guard let m = baoCao else { return }
                    Task {
                        do {
                            try await CTWBaoCao.baoCaoTin(m, duAn: tenDuAn, kenh: kenh.name, lyDoMa: l.ma)
                            thongBao = "Thanks — our moderators will review it within 24 hours. The message is hidden for you."
                        } catch { vm.loi = CTW.loi(error) }
                    }
                }
            }
        } message: { Text("Reported messages are hidden for you right away.") }
        .confirmationDialog("Block \(hoiChan?.ten ?? "this user")?", isPresented: Binding(get: { hoiChan != nil }, set: { if !$0 { hoiChan = nil } }),
                            titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                guard let u = hoiChan else { return }
                Task { do { try await kd.block(userId: u.id) } catch { vm.loi = CTW.loi(error) } }
            }
        } message: { Text("You won't see their messages or comments anymore.") }
        .confirmationDialog("Delete this message?", isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let m = hoiXoa { Task { await vm.xoa(m) } } }
        }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .sua(let m):
                CTWSuaBinhLuanView(chuBanDau: m.body ?? "") { chu in await vm.sua(m, chu: chu) }
            case .chuoi(let m):
                ChuoiTraLoiCTW(pid: pid, kenh: kenh, goc: m, tenDuAn: tenDuAn)
            }
        }
    }

    @ViewBuilder
    private func menu(_ m: CTWChatMessage) -> some View {
        let laCuaToi = m.author?.id == app.currentUser?.id
        if !m.daXoa {
            Button { CTW.chepVaoBoNho(m.body ?? "") } label: { Label("Copy", systemImage: "doc.on.doc") }
            if (m.replyCount ?? 0) > 0 || kenh.canPost == true {
                Button { tamPhu = .chuoi(m) } label: { Label((m.replyCount ?? 0) > 0 ? "View thread" : "Reply in thread", systemImage: "arrowshape.turn.up.left") }
            }
        }
        if laCuaToi && !m.laHeThong && !m.daXoa && kenh.canPost == true {
            Button { tamPhu = .sua(m) } label: { Label("Edit", systemImage: "pencil") }
        }
        if (laCuaToi || kenh.canManage == true) && !m.daXoa {
            Button(role: .destructive) { hoiXoa = m } label: { Label("Delete", systemImage: "trash") }
        }
        if !laCuaToi && !m.laHeThong && !m.daXoa {
            Button(role: .destructive) { baoCao = m } label: { Label("Report message", systemImage: "flag") }
            if let a = m.author {
                Button(role: .destructive) { hoiChan = a } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
            }
        }
    }

    private var oNhap: some View {
        VStack(spacing: 0) {
            Divider()
            if kenh.canPost == false || kenh.archived == true {
                Text(kenh.archived == true ? "This channel is archived." : "You can read this channel but not post in it.")
                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity).padding(12)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Message #\(kenh.name)", text: $nhap, axis: .vertical)
                        .lineLimit(1...6)
                        .focused($dangGo)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppColors.backgroundCard))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                    let trong = nhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button {
                        let s = nhap
                        nhap = ""
                        Task { if !(await vm.gui(s)) { nhap = s } }
                    } label: {
                        Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(trong ? AppColors.textTertiary : AppColors.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(trong || vm.dangGui)
                    .accessibilityLabel("Send message")
                }
                .padding(.horizontal, Spacing.md).padding(.vertical, 8)
            }
        }
        .background(AppColors.backgroundSecondary)
    }

    private func khoangPhut(_ a: String?, _ b: String?) -> Double {
        guard let x = CTWChatThoiGian.date(a), let y = CTWChatThoiGian.date(b) else { return 99 }
        return abs(y.timeIntervalSince(x)) / 60
    }
}

enum CTWChatThoiGian {
    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    static func gio(_ s: String?) -> String {
        guard let d = date(s) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = Calendar.current.isDateInToday(d) ? "HH:mm" : "MMM d, HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Một tin

struct TinChatCTW: View {
    let tin: CTWChatMessage
    var gop = false
    var laCuaToi = false

    var body: some View {
        if tin.laHeThong {
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 11))
                Text("\(tin.author?.ten ?? "CT Work") \(tin.body ?? "")").font(.system(size: 12))
                Text(CTWChatThoiGian.gio(tin.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            HStack(alignment: .top, spacing: 10) {
                if gop { Color.clear.frame(width: 34, height: 1) } else { CTWAvatar(user: tin.author, size: 34) }
                VStack(alignment: .leading, spacing: 3) {
                    if !gop {
                        HStack(spacing: 6) {
                            Text(tin.author?.ten ?? "Deleted user").font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary).lineLimit(1)
                            if tin.author?.laAgent == true { CTWNhanAI() }
                            Text(CTWChatThoiGian.gio(tin.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    if tin.daXoa {
                        Text("This message was deleted.").font(.system(size: 14).italic()).foregroundColor(AppColors.textTertiary)
                    } else {
                        if let b = tin.body, !b.isEmpty {
                            Text(CTWKhoiView.dong(b)).font(.system(size: 15)).foregroundColor(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        ForEach(tin.files ?? []) { f in
                            Label(f.fileName ?? "File", systemImage: (f.mime ?? "").hasPrefix("image/") ? "photo" : "doc")
                                .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.backgroundTertiary))
                        }
                        ForEach(Array((tin.previews ?? []).prefix(3).enumerated()), id: \.offset) { _, p in
                            HStack(spacing: 6) {
                                Image(systemName: p.t == "doc" ? "doc.text" : "checkmark.square").foregroundColor(AppColors.primary)
                                Text("\(p.key ?? "") \(p.title ?? "")").font(.system(size: 12)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppColors.border))
                        }
                        if let r = tin.reactions, !r.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(r, id: \.emoji) { x in
                                    Text("\(x.emoji) \(x.count ?? 0)").font(.system(size: 12))
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Capsule().fill(x.mine == true ? AppColors.primary.opacity(0.15) : AppColors.backgroundTertiary))
                                }
                            }
                        }
                        if tin.editedAt != nil {
                            Text("(edited)").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    if let n = tin.replyCount, n > 0 {
                        Label(n == 1 ? "1 reply" : "\(n) replies", systemImage: "arrowshape.turn.up.left.2")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, gop ? 0 : 8)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Chuỗi trả lời

struct ChuoiTraLoiCTW: View {
    let pid: Int
    let kenh: CTWChannel
    let goc: CTWChatMessage
    let tenDuAn: String
    @Environment(\.dismiss) private var dong
    @EnvironmentObject private var app: AppState
    @ObservedObject private var kd = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungCTW.shared
    @State private var traLoi: [CTWChatMessage] = []
    @State private var nhap = ""
    @State private var loi: String?
    @State private var baoCao: CTWChatMessage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if let loi { CTWErrorBanner(text: loi) }
                    TinChatCTW(tin: goc)
                    Divider().padding(.vertical, 6)
                    ForEach(traLoi.filter { !an.tinAn.contains($0.id) && !kd.blockedUserIds.contains($0.author?.id ?? -1) }) { m in
                        TinChatCTW(tin: m)
                            .contextMenu {
                                Button { CTW.chepVaoBoNho(m.body ?? "") } label: { Label("Copy", systemImage: "doc.on.doc") }
                                if m.author?.id != app.currentUser?.id {
                                    Button(role: .destructive) { baoCao = m } label: { Label("Report message", systemImage: "flag") }
                                }
                            }
                    }
                }
                .padding(Spacing.md)
            }
            .safeAreaInset(edge: .bottom) {
                if kenh.canPost != false && kenh.archived != true {
                    HStack(spacing: 8) {
                        TextField("Reply…", text: $nhap, axis: .vertical).lineLimit(1...5)
                            .textFieldStyle(.roundedBorder)
                        Button("Send") { Task { await gui() } }
                            .disabled(nhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(Spacing.md)
                    .background(.bar)
                }
            }
            .navigationTitle("Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
            .confirmationDialog("Report this message", isPresented: Binding(get: { baoCao != nil }, set: { if !$0 { baoCao = nil } }),
                                titleVisibility: .visible) {
                ForEach(CTWBaoCao.lyDo, id: \.ma) { l in
                    Button(l.nhan, role: .destructive) {
                        guard let m = baoCao else { return }
                        Task {
                            do { try await CTWBaoCao.baoCaoTin(m, duAn: tenDuAn, kenh: kenh.name, lyDoMa: l.ma) }
                            catch { loi = CTW.loi(error) }
                        }
                    }
                }
            }
            .task { await tai() }
        }
    }

    private func tai() async {
        do {
            let t: CTWChatThread = try await APIClient.shared.request(CTWAPI.chuoiTraLoi(pid: pid, cid: kenh.id, mid: goc.id))
            traLoi = t.replies ?? []
        } catch { loi = CTW.loi(error) }
    }

    private func gui() async {
        let s = nhap.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        do {
            let m: CTWChatMessage = try await APIClient.shared.request(
                CTWAPI.guiTin(pid: pid, cid: kenh.id, chu: s, traLoi: goc.id, khoa: UUID().uuidString))
            traLoi.append(m)
            nhap = ""
        } catch { loi = CTW.loi(error) }
    }
}
