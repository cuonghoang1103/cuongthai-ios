import SwiftUI
import Combine

// MARK: - Chuỗi trả lời (luồng MỘT cấp — trả lời một trả lời ⇒ gắn vào gốc)
//
// `GET …/messages/:mid/thread` ⇒ `{root, replies}`; realtime: sự kiện `message`
// có `parentId == gốc` ⇒ nạp lại; "đang gõ" theo `threadId`. Gửi chữ qua hàng chờ
// ngoại tuyến như kênh. Báo cáo / chặn / ẩn như mọi tin (1.2).

@MainActor
final class ChuoiTraLoiVM: ObservableObject {
    let pid: Int
    let cid: Int
    let gocId: Int
    @Published var goc: CTWChatMessage
    @Published var traLoi: [CTWChatMessage] = []
    @Published var loi: String?
    @Published var daTai = false
    @Published var dangGo: [Int: (nguoi: CTWUser, luc: Date)] = [:]
    private var huy = Set<AnyCancellable>()
    private var lanBaoGo = Date.distantPast

    init(pid: Int, cid: Int, goc: CTWChatMessage) {
        self.pid = pid
        self.cid = cid
        self.gocId = goc.id
        self.goc = goc
        RealtimeCTW.shared.suKienChat
            .filter { [pid, cid, gocId = goc.id] in $0.projectId == pid && $0.channelId == cid && ($0.parentId == gocId || $0.messageId == gocId || $0.message?.parentId == gocId) }
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in Task { await self?.tai() } }
            .store(in: &huy)
        RealtimeCTW.shared.suKienGo
            .filter { [pid, cid, gocId = goc.id] in $0.projectId == pid && $0.channelId == cid && $0.threadId == gocId }
            .sink { [weak self] sk in
                guard let self, let u = sk.user, u.id != AppState.shared.currentUser?.id else { return }
                if sk.dangGo { self.dangGo[u.id] = (u, Date()) } else { self.dangGo[u.id] = nil }
            }
            .store(in: &huy)
        HangChoGuiCTW.shared.daGui
            .filter { [pid, cid, gocId = goc.id] in $0.0.pid == pid && $0.0.cid == cid && $0.0.parentId == gocId }
            .sink { [weak self] cap in self?.chen(cap.1) }
            .store(in: &huy)
    }

    func tai() async {
        do {
            let t: CTWChatThread = try await APIClient.shared.request(CTWAPI.chuoiTraLoi(pid: pid, cid: cid, mid: gocId))
            if let r = t.root { goc = r }
            traLoi = t.replies ?? []
            loi = nil
        } catch { loi = CTW.loi(error) }
        daTai = true
    }

    func chen(_ m: CTWChatMessage) {
        if let i = traLoi.firstIndex(where: { $0.id == m.id }) { traLoi[i] = m } else { traLoi.append(m); traLoi.sort { $0.id < $1.id } }
    }

    func gui(_ chu: String, tep: [CTWChatFile]) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty || !tep.isEmpty else { return false }
        RealtimeCTW.shared.baoDangGo(pid: pid, cid: cid, chuoi: gocId, dangGo: false)
        if tep.isEmpty {
            switch await HangChoGuiCTW.shared.themKQ(pid: pid, cid: cid, parentId: gocId, body: s) {
            case .daGui(let m):
                if let m { chen(m) }
                return true
            case .biChan(let l):
                loi = l          // bộ lọc nội dung — ô soạn giữ chữ
                return false
            }
        }
        do {
            let m: CTWChatMessage = try await APIClient.shared.request(
                CTWAPI.guiTin(pid: pid, cid: cid, chu: s, traLoi: gocId, khoa: "ios-\(UUID().uuidString.prefix(23))", tep: tep.map(\.id)))
            chen(m)
            return true
        } catch {
            loi = CTW.loi(error)
            return false
        }
    }

    func camXuc(_ m: CTWChatMessage, _ e: String) async {
        let bat = !(m.reactions ?? []).contains { $0.emoji == e && $0.mine == true }
        if let kq: CTWReactionKQ = try? await APIClient.shared.request(CTWAPI.camXuc(pid: pid, cid: cid, mid: m.id, emoji: e, bat: bat)) {
            if m.id == gocId { goc.reactions = kq.reactions } else if let i = traLoi.firstIndex(where: { $0.id == m.id }) { traLoi[i].reactions = kq.reactions }
        }
    }

    func xoa(_ m: CTWChatMessage) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaTin(pid: pid, cid: cid, mid: m.id))
            traLoi.removeAll { $0.id == m.id }
        } catch { loi = CTW.loi(error) }
    }

    func chuDoi(_ s: String) {
        guard !s.isEmpty, Date().timeIntervalSince(lanBaoGo) > 3 else { return }
        lanBaoGo = Date()
        RealtimeCTW.shared.baoDangGo(pid: pid, cid: cid, chuoi: gocId, dangGo: true)
    }
}

struct ChuoiTraLoiCTW: View {
    let pid: Int
    let kenh: CTWChannel
    let tenDuAn: String
    @StateObject private var vm: ChuoiTraLoiVM
    @Environment(\.dismiss) private var dong
    @EnvironmentObject private var app: AppState
    @ObservedObject private var kd = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungCTW.shared
    @ObservedObject private var hangCho = HangChoGuiCTW.shared
    @State private var baoCao: CTWChatMessage?
    @State private var hoiChan: CTWUser?
    @State private var xemNhanh: URL?
    @State private var thongBao: String?
    @State private var thanhVien: [CTWChannelMember] = []

    init(pid: Int, kenh: CTWChannel, goc: CTWChatMessage, tenDuAn: String) {
        self.pid = pid
        self.kenh = kenh
        self.tenDuAn = tenDuAn
        _vm = StateObject(wrappedValue: ChuoiTraLoiVM(pid: pid, cid: kenh.id, goc: goc))
    }

    private var duocGui: Bool { kenh.canPost != false && kenh.archived != true }

    private var hanhDong: HanhDongTinCTW {
        HanhDongTinCTW(camXuc: { m, e in Task { await vm.camXuc(m, e) } },
                       xemTep: { f in Task {
                           if let u = try? await UrlTepChatCTW.lay(pid: pid, fid: f.id) {
                               xemNhanh = try? await CTWXemTep.taiVe(url: u, ten: f.fileName ?? "file", khoa: "chat-\(f.id)")
                           }
                       } })
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { cuon in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                        TinChatCTW(tin: vm.goc, pid: pid, hanhDong: hanhDong)
                        HStack(spacing: 8) {
                            Text(vm.traLoi.count == 1 ? "1 reply" : "\(vm.traLoi.count) replies")
                                .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            Rectangle().fill(AppColors.divider).frame(height: 0.5)
                        }
                        .padding(.vertical, 8)
                        ForEach(Array(hien.enumerated()), id: \.element.id) { i, m in
                            let truoc = i > 0 ? hien[i - 1] : nil
                            let gop = truoc?.author?.id == m.author?.id && CTWChatThoiGian.phut(truoc?.createdAt, m.createdAt) < 5
                            TinChatCTW(tin: m, pid: pid, gop: gop, laCuaToi: m.author?.id == app.currentUser?.id, hanhDong: hanhDong)
                                .id(m.id)
                                .contextMenu { menu(m) }
                        }
                        ForEach(hangCho.cua(pid: pid, cid: kenh.id, chuoi: vm.gocId)) { t in TinChoCTW(tin: t) }
                        if let g = chuGo {
                            HStack(spacing: 6) { DauGoCTW(); Text(g).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                                .padding(.top, 4)
                        }
                        Color.clear.frame(height: 2).id("day")
                    }
                    .padding(Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.traLoi.count) { _, _ in withAnimation { cuon.scrollTo("day", anchor: .bottom) } }
            }
            .safeAreaInset(edge: .bottom) {
                if duocGui {
                    SoanTinCTW(pid: pid, cid: kenh.id, goiY: String(localized: "Reply…"), thanhVien: thanhVien,
                               gui: { chu, tep in await vm.gui(chu, tep: tep) },
                               chuDoi: { vm.chuDoi($0) },
                               guiGiongNoi: { f in await vm.gui("", tep: [f]) })
                }
            }
            .navigationTitle("Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Thread").font(.ctw(size: 16, weight: .semibold))
                        Text(kenh.laRieng ? kenh.name : "#\(kenh.name)").font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } }
            }
            .ctwXemTep($xemNhanh)
            .confirmationDialog("Report this message", isPresented: Binding(get: { baoCao != nil }, set: { if !$0 { baoCao = nil } }),
                                titleVisibility: .visible) {
                ForEach(CTWBaoCao.lyDo, id: \.ma) { l in
                    Button(l.nhan, role: .destructive) {
                        guard let m = baoCao else { return }
                        Task {
                            do {
                                try await CTWBaoCao.baoCaoTin(m, duAn: tenDuAn, kenh: kenh.name, lyDoMa: l.ma)
                                thongBao = String(localized: "Thanks — our moderators will review it within 24 hours. The message is hidden for you.")
                            } catch { vm.loi = CTW.loi(error) }
                        }
                    }
                }
            } message: { Text("Reported messages are hidden for you right away.") }
            .confirmationDialog("Block \(hoiChan?.ten ?? String(localized: "this user"))?", isPresented: Binding(get: { hoiChan != nil }, set: { if !$0 { hoiChan = nil } }),
                                titleVisibility: .visible) {
                Button("Block", role: .destructive) {
                    guard let u = hoiChan else { return }
                    Task { do { try await kd.block(userId: u.id) } catch { vm.loi = CTW.loi(error) } }
                }
            } message: { Text("You won't see their messages or comments anymore.") }
            .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .task {
                await vm.tai()
                if let ds: [CTWChannelMember] = try? await APIClient.shared.request(CTWAPI.thanhVienKenh(pid: pid, cid: kenh.id)) { thanhVien = ds }
            }
        }
    }

    private var hien: [CTWChatMessage] {
        vm.traLoi.filter { !an.tinAn.contains($0.id) && !kd.blockedUserIds.contains($0.author?.id ?? -1) && !$0.daXoa }
    }

    private var chuGo: String? {
        let ten = vm.dangGo.values.filter { Date().timeIntervalSince($0.luc) < 6 }.map(\.nguoi.ten)
        guard !ten.isEmpty else { return nil }
        return ten.count == 1 ? String(localized: "\(ten[0]) is typing…") : String(localized: "\(ten.count) people are typing…")
    }

    @ViewBuilder
    private func menu(_ m: CTWChatMessage) -> some View {
        let laCuaToi = m.author?.id == app.currentUser?.id
        if duocGui {
            ControlGroup {
                ForEach(["👍", "❤️", "😂", "🎉", "👀", "✅"], id: \.self) { e in Button(e) { Task { await vm.camXuc(m, e) } } }
            }
            .controlGroupStyle(.compactMenu)
        }
        if !(m.body ?? "").isEmpty {
            Button { CTW.chepVaoBoNho(m.body ?? "") } label: { Label("Copy text", systemImage: "doc.on.doc") }
        }
        if laCuaToi || kenh.canManage == true {
            Button(role: .destructive) { Task { await vm.xoa(m) } } label: { Label("Delete", systemImage: "trash") }
        }
        if !laCuaToi {
            Button(role: .destructive) { baoCao = m } label: { Label("Report message", systemImage: "flag") }
            if let a = m.author {
                Button(role: .destructive) { hoiChan = a } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
            }
        }
    }
}
