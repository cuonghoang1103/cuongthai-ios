import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Kingfisher

// MARK: - Chat 1-1 kiểu Messenger (Messenger chung — `messages.routes.ts`)
//
// Bong bóng theo nhóm người gửi, avatar người kia ở tin cuối nhóm, mốc giờ khi cách > 15 phút, ảnh (máy ảnh + thư
// viện), tệp (Xem nhanh), cảm xúc, trả lời, thu hồi (≤ 5 phút — luật máy chủ), "Đã xem", "đang gõ…".
// 1.2: menu "…" có Báo cáo hội thoại + Chặn/Bỏ chặn; người đã chặn ⇒ khoá ô soạn.
// Realtime: `RealtimeCTW.tinNhan*` (máy chủ tự cho socket vào phòng mọi hội thoại lúc bắt tay).

@MainActor
final class ChatRiengVM: ObservableObject {
    let threadId: Int
    @Published var hoiThoai: MessageThread?
    @Published var tin: [Message] = []
    @Published var dangTai = true
    @Published var conCu = false
    @Published var loi: String?
    @Published var dangGui = false
    @Published var tienDoTai: String?
    /// Mốc người kia đã đọc tới — vẽ "Đã xem".
    @Published var hoDocLuc: Date?

    private var huy: [Any] = []
    private var lanGoCuoi = Date.distantPast

    init(threadId: Int) {
        self.threadId = threadId
        hoiThoai = KhoTinNhanCTW.shared.hoiThoai(threadId)
        let r = RealtimeCTW.shared
        huy.append(r.tinNhanMoi.sink { [weak self] e in
            guard let self, e.threadId == threadId else { return }
            them(e.tin)
            if e.tin.senderId != toi { KhoTinNhanCTW.shared.danhDauDaDoc(threadId) }
        })
        huy.append(r.tinNhanDoi.sink { [weak self] e in
            guard let self, e.threadId == threadId, let i = tin.firstIndex(where: { $0.id == e.messageId }) else { return }
            tin[i] = tin[i].doi(camXuc: e.camXuc, thuHoi: e.thuHoi, daXoa: e.daXoa)
        })
        huy.append(r.tinNhanDaDoc.sink { [weak self] e in
            guard let self, e.threadId == threadId, e.readerId != toi else { return }
            hoDocLuc = max(hoDocLuc ?? .distantPast, e.readAt)
        })
    }

    var toi: Int? { AppState.shared.currentUser?.id }
    var nguoiKia: ThreadPeer? { hoiThoai?.peer }

    func tai() async {
        if hoiThoai == nil { hoiThoai = try? await APIClient.shared.request(.layHoiThoai(threadId: threadId)) }
        do {
            let ds: [Message] = try await APIClient.shared.request(.getMessages(threadId: threadId, cursor: nil, limit: 40))
            tin = ds
            conCu = ds.count >= 40
            loi = nil
        } catch { if tin.isEmpty { loi = CTW.loi(error) } }
        dangTai = false
        if let r: [MocDoc] = try? await APIClient.shared.request(.getThreadReads(threadId: threadId)),
           let cua = r.first(where: { $0.userId != toi }) { hoDocLuc = cua.moc }
        KhoTinNhanCTW.shared.danhDauDaDoc(threadId)
    }

    func taiCuHon() async {
        guard conCu, let dau = tin.first?.id else { return }
        if let ds: [Message] = try? await APIClient.shared.request(.getMessages(threadId: threadId, cursor: dau, limit: 40)) {
            tin.insert(contentsOf: ds.filter { m in !tin.contains { $0.id == m.id } }, at: 0)
            conCu = ds.count >= 40
        }
    }

    func them(_ m: Message) {
        if let i = tin.firstIndex(where: { $0.id == m.id }) { tin[i] = m } else { tin.append(m) }
        KhoTinNhanCTW.shared.capNhatTinCuoi(threadId, m)
    }

    /// Gửi: tải tệp lên trước (`POST /messages/upload` ⇒ fileId), rồi MỘT tin mang chữ + tệp + trả lời.
    func gui(chu: String, anh: [Data], tep: [(Data, String, String)], traLoi: Message?) async -> Bool {
        let noiDung = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !noiDung.isEmpty || !anh.isEmpty || !tep.isEmpty else { return false }
        dangGui = true; loi = nil
        defer { dangGui = false; tienDoTai = nil }
        baoGo(false)
        do {
            var ids: [Int] = []
            let tong = anh.count + tep.count
            for (i, a) in anh.enumerated() {
                tienDoTai = String(localized: "Uploading \(i + 1)/\(tong)…")
                ids.append(try await APIClient.shared.taiLenChat(data: a, fileName: "photo-\(i + 1).jpg", mimeType: "image/jpeg").fileId)
            }
            for (i, t) in tep.enumerated() {
                tienDoTai = String(localized: "Uploading \(anh.count + i + 1)/\(tong)…")
                ids.append(try await APIClient.shared.taiLenChat(data: t.0, fileName: t.1, mimeType: t.2).fileId)
            }
            let m: Message = try await APIClient.shared.request(TinNhanAPI.gui(threadId: threadId, noiDung: noiDung, tepIds: ids, traLoi: traLoi?.id))
            them(m)
            CTWRung.chon()
            return true
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
            return false
        }
    }

    func thaCamXuc(_ m: Message, _ e: String) {
        // Lạc quan: đảo ngay, socket `message:updated` sẽ chốt số thật.
        if let i = tin.firstIndex(where: { $0.id == m.id }), let toi {
            var ds = tin[i].reactions ?? []
            if let j = ds.firstIndex(where: { $0.emoji == e }) {
                let c = ds[j]
                let co = c.userIds.contains(toi)
                let ids = co ? c.userIds.filter { $0 != toi } : c.userIds + [toi]
                if ids.isEmpty { ds.remove(at: j) } else { ds[j] = MessageReaction(emoji: e, count: ids.count, userIds: ids) }
            } else {
                ds.append(MessageReaction(emoji: e, count: 1, userIds: [toi]))
            }
            tin[i] = tin[i].doi(camXuc: ds, thuHoi: nil, daXoa: nil)
        }
        Task { _ = try? await APIClient.shared.send(.toggleMessageReaction(messageId: m.id, emoji: e)) }
    }

    func thuHoi(_ m: Message) async {
        do {
            try await APIClient.shared.send(.recallMessage(messageId: m.id))
            if let i = tin.firstIndex(where: { $0.id == m.id }) { tin[i] = tin[i].doi(camXuc: nil, thuHoi: true, daXoa: nil) }
        } catch { loi = CTW.loi(error) }
    }

    /// "Đang gõ" — báo tối đa 3 giây một lần khi đang gõ, báo dừng khi gửi/xoá hết.
    func baoGo(_ go: Bool) {
        if go {
            guard Date().timeIntervalSince(lanGoCuoi) > 3 else { return }
            lanGoCuoi = Date()
        } else { lanGoCuoi = .distantPast }
        RealtimeCTW.shared.baoDangGoTinNhan(threadId: threadId, dangGo: go)
    }

    /// Tin của tôi được thu hồi trong 5 phút sau khi gửi (`RECALL_WINDOW_MS` của máy chủ).
    static func thuHoiDuoc(_ m: Message, toi: Int?, bayGio: Date = Date()) -> Bool {
        guard m.senderId == toi, !m.daXoaHoacThuHoi, let d = m.ngayGio else { return false }
        return bayGio.timeIntervalSince(d) < 5 * 60
    }

    /// Tin CUỐI của tôi mà người kia đã đọc tới — nơi đặt "Đã xem".
    static func tinDaXem(_ tin: [Message], toi: Int?, hoDocLuc: Date?) -> Int? {
        guard let hoDocLuc else { return nil }
        return tin.last(where: { $0.senderId == toi && ($0.ngayGio ?? .distantFuture) <= hoDocLuc })?.id
    }
}

extension Message {
    /// Bản sao đã đổi cảm xúc / thu hồi / xoá (mọi trường của `Message` là `let`). nil = giữ nguyên.
    func doi(camXuc: [MessageReaction]?, thuHoi: Bool?, daXoa: Bool?) -> Message {
        let mat = (thuHoi ?? false) || (daXoa ?? false)
        return Message(id: id, threadId: threadId, senderId: senderId, sender: sender,
                       content: mat ? "" : content, mediaUrl: mat ? nil : mediaUrl, mediaKind: mat ? nil : mediaKind,
                       deleted: daXoa ?? deleted, recalled: thuHoi ?? recalled, createdAt: createdAt,
                       attachments: mat ? [] : attachments, parentMessageId: parentMessageId, parentMessage: parentMessage,
                       hasAttachment: hasAttachment, reactions: camXuc ?? reactions)
    }
}

struct ChatRiengCTW: View {
    let threadId: Int
    @StateObject private var vm: ChatRiengVM
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @ObservedObject private var kd = ModerationStore.shared
    @State private var chu = ""
    @State private var traLoi: Message?
    @State private var anhChon: [PhotosPickerItem] = []
    @State private var anhCho: [Data] = []
    @State private var tepCho: [(Data, String, String)] = []
    @State private var moThuVien = false
    @State private var moMayAnh = false
    @State private var moTep = false
    @State private var hoiChan = false
    @State private var tamPhu: TamPhu?
    @State private var xemTep: URL?

    /// MỘT `.sheet(item:)` cho cả ba tấm phủ (CLAUDE.md C5 — nhiều `.sheet` trên một view chỉ cái cuối chạy).
    enum TamPhu: Identifiable {
        case baoCao, hoSo(Int), anh(URL)
        var id: String {
            switch self { case .baoCao: return "bc"; case .hoSo(let i): return "hs\(i)"; case .anh(let u): return u.absoluteString }
        }
    }
    @FocusState private var dangSoan: Bool

    init(threadId: Int) {
        self.threadId = threadId
        _vm = StateObject(wrappedValue: ChatRiengVM(threadId: threadId))
    }

    private var peer: ThreadPeer? { vm.nguoiKia }
    private var tenKia: String {
        if let p = peer, let n = kho.thanhVien(p.id), vm.hoiThoai?.bietDanh == nil { return n.ten }
        return peer?.displayName ?? peer?.username ?? String(localized: "Conversation")
    }
    private var mocKia: TrangThaiHoatDongCTW.Moc { peer.map { kho.moc($0.id, mocHoiThoai: $0.lastActiveAt) } ?? .an }
    private var daChan: Bool { peer.map { kd.blockedUserIds.contains($0.id) } ?? false }
    private var userKia: CTWUser { CTWUser(id: peer?.id ?? 0, username: peer?.username, displayName: tenKia, avatarUrl: peer?.avatarUrl) }

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if vm.conCu {
                        Button("Load earlier messages") { Task { await vm.taiCuHon() } }
                            .font(.ctw(size: 13)).padding(.vertical, 8)
                    }
                    dauHoiThoai
                    let daXem = ChatRiengVM.tinDaXem(vm.tin, toi: vm.toi, hoDocLuc: vm.hoDocLuc)
                    ForEach(Array(vm.tin.enumerated()), id: \.element.id) { i, m in
                        if canMocGio(i) { mocGio(m) }
                        BongTinCTW(m: m, cuaToi: m.senderId == vm.toi, nguoiKia: userKia,
                                   hienAvatar: cuoiNhom(i), toi: vm.toi,
                                   xemAnh: { tamPhu = .anh($0) }, moTep: moTepDinhKem)
                            .contextMenu { menuTin(m) }
                            .id(m.id)
                        if m.id == daXem && m.id == vm.tin.last(where: { $0.senderId == vm.toi })?.id {
                            HStack { Spacer(); Text("Seen").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
                                .padding(.trailing, 14).padding(.bottom, 2)
                                .accessibilityIdentifier("dm.seen")
                        }
                    }
                    if !(kho.dangGo[threadId] ?? []).isEmpty {
                        HStack(spacing: 8) {
                            CTWAvatar(user: userKia, size: 26)
                            Text("typing…").font(.ctw(size: 13).italic()).foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 18).fill(AppColors.backgroundSecondary))
                            Spacer()
                        }
                        .padding(.horizontal, 12).id("go")
                    }
                    Color.clear.frame(height: 4).id("cuoi")
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)   // mở hội thoại ở tin mới nhất
            .onChange(of: vm.tin.last?.id) { _, _ in withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) } }
            .onChange(of: vm.dangTai) { _, _ in cuon.scrollTo("cuoi", anchor: .bottom) }
        }
        .overlay {
            if vm.dangTai && vm.tin.isEmpty { ProgressView() }
            else if let l = vm.loi, vm.tin.isEmpty { CTWOLoi(loi: l) { Task { await vm.tai() } } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { oSoan }
        .background(AppColors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)   // như Messenger: khung chat chiếm trọn màn
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button { if let p = peer { tamPhu = .hoSo(p.id) } } label: {
                    HStack(spacing: 8) {
                        AvatarHoatDongCTW(user: userKia, size: 32, moc: mocKia)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tenKia).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            let c = TrangThaiHoatDongCTW.chu(mocKia)
                            if !c.isEmpty { Text(c).font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1) }
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(peer == nil || kho.thanhVien(peer!.id) == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if let p = peer, kho.thanhVien(p.id) != nil {
                        Button { tamPhu = .hoSo(p.id) } label: { Label("View profile", systemImage: "person.crop.circle") }
                    }
                    Button { tamPhu = .baoCao } label: { Label("Report conversation", systemImage: "exclamationmark.bubble") }
                    if peer != nil {
                        if daChan {
                            Button { Task { if let p = peer { try? await kd.unblock(userId: p.id) } } } label: {
                                Label("Unblock", systemImage: "hand.raised.slash")
                            }
                        } else {
                            Button(role: .destructive) { hoiChan = true } label: { Label("Block", systemImage: "hand.raised") }
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("More")
            }
        }
        .task { await vm.tai() }
        .onAppear { KhoTinNhanCTW.hoiThoaiDangMo = threadId }
        .onDisappear {
            if KhoTinNhanCTW.hoiThoaiDangMo == threadId { KhoTinNhanCTW.hoiThoaiDangMo = nil }
            vm.baoGo(false)
        }
        .photosPicker(isPresented: $moThuVien, selection: $anhChon, maxSelectionCount: 6, matching: .images)
        .onChange(of: anhChon) { _, ds in
            Task {
                var kq: [Data] = []
                for it in ds {
                    if let d = try? await it.loadTransferable(type: Data.self), let u = UIImage(data: d),
                       let j = u.jpegData(compressionQuality: 0.8) { kq.append(j) }
                }
                anhCho += kq
                anhChon = []
            }
        }
        .fullScreenCover(isPresented: $moMayAnh) { MayAnh { anhCho.append($0) }.ignoresSafeArea() }
        .fileImporter(isPresented: $moTep, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            guard case .success(let urls) = r else { return }
            for u in urls.prefix(5) {
                let truyCap = u.startAccessingSecurityScopedResource()
                defer { if truyCap { u.stopAccessingSecurityScopedResource() } }
                guard let d = try? Data(contentsOf: u) else { continue }
                let mime = UTType(filenameExtension: u.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                tepCho.append((d, u.lastPathComponent, mime))
            }
        }
        .ctwXemTep($xemTep)
        .sheet(item: $tamPhu) { t in
            switch t {
            case .baoCao: BaoCaoNguoiCTW(ten: tenKia, userId: peer?.id ?? 0, threadId: threadId)
            case .hoSo(let id): NavigationStack { HoSoThanhVienCTW(userId: id, laTamPhu: true) }
            case .anh(let u): XemAnhLonCTW(url: u)
            }
        }
        .confirmationDialog("Block \(tenKia)?", isPresented: $hoiChan, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task { if let p = peer { try? await kd.block(userId: p.id, reason: nil); await kho.taiDanhBa() } }
            }
        } message: { Text("They won't be able to message you, and you won't see their active status.") }
    }

    // MARK: Phần

    @ViewBuilder private var dauHoiThoai: some View {
        if !vm.conCu, !vm.dangTai {
            VStack(spacing: 6) {
                AvatarHoatDongCTW(user: userKia, size: 72, moc: mocKia)
                Text(tenKia).font(.ctw(size: 18, weight: .bold)).foregroundColor(AppColors.textPrimary)
                if let p = peer, let n = kho.thanhVien(p.id), !n.dongPhu.isEmpty {
                    Text(n.dongPhu).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.vertical, 18)
        }
    }

    @ViewBuilder private var oSoan: some View {
        VStack(spacing: 0) {
            Divider()
            if daChan {
                VStack(spacing: 6) {
                    Text("You blocked \(tenKia).").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Button("Unblock") { Task { if let p = peer { try? await kd.unblock(userId: p.id) } } }
                }
                .frame(maxWidth: .infinity).padding(12)
            } else {
                if let l = vm.loi, !vm.tin.isEmpty { CTWErrorBanner(text: l) { vm.loi = nil }.padding(.horizontal, 12).padding(.top, 6) }
                if let t = vm.tienDoTai {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text(t).font(.ctw(size: 12)) }
                        .foregroundColor(AppColors.textSecondary).padding(.top, 6)
                }
                if let r = traLoi {
                    HStack {
                        Rectangle().fill(AppColors.primary).frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.senderId == vm.toi ? String(localized: "Replying to yourself") : String(localized: "Replying to \(tenKia)"))
                                .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                            Text(Self.tomTat(r)).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        Button { traLoi = nil } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                            .accessibilityLabel("Cancel reply")
                    }
                    .frame(height: 36).padding(.horizontal, 12).padding(.top, 6)
                }
                if !anhCho.isEmpty || !tepCho.isEmpty { hangDinhKem }
                HStack(alignment: .bottom, spacing: 8) {
                    Menu {
                        if MayAnh.coMayAnh { Button { moMayAnh = true } label: { Label("Camera", systemImage: "camera") } }
                        Button { moThuVien = true } label: { Label("Photo library", systemImage: "photo.on.rectangle") }
                        Button { moTep = true } label: { Label("File", systemImage: "doc") }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.ctw(size: 26)).foregroundColor(AppColors.primary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Attach")
                    TextField("Message", text: $chu, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($dangSoan)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.backgroundPrimary))
                        .onChange(of: chu) { _, m in vm.baoGo(!m.isEmpty) }
                        .accessibilityIdentifier("dm.composer")
                    Button { Task { await gui() } } label: {
                        Group {
                            if vm.dangGui { ProgressView() }
                            else { Image(systemName: "paperplane.fill").font(.ctw(size: 20)) }
                        }
                        .foregroundColor(coGiDeGui ? AppColors.primary : AppColors.textTertiary)
                        .frame(width: 44, height: 44)
                    }
                    .disabled(!coGiDeGui || vm.dangGui)
                    .accessibilityLabel("Send")
                    .accessibilityIdentifier("dm.send")
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
            }
        }
        .background(AppColors.backgroundCard)
    }

    private var hangDinhKem: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(anhCho.enumerated()), id: \.offset) { i, d in
                    ZStack(alignment: .topTrailing) {
                        if let u = UIImage(data: d) {
                            Image(uiImage: u).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button { anhCho.remove(at: i) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.6)) }
                            .accessibilityLabel("Remove photo")
                    }
                }
                ForEach(Array(tepCho.enumerated()), id: \.offset) { i, t in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill").foregroundColor(AppColors.primary)
                        Text(t.1).font(.ctw(size: 12)).lineLimit(1).frame(maxWidth: 120).fixedSize(horizontal: false, vertical: true)
                        Button { tepCho.remove(at: i) } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary) }
                            .accessibilityLabel("Remove file")
                    }
                    .padding(8).background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundSecondary))
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)
        }
    }

    @ViewBuilder private func menuTin(_ m: Message) -> some View {
        if !m.daXoaHoacThuHoi {
            ControlGroup {
                ForEach(BongTinCTW.camXucNhanh, id: \.self) { e in Button(e) { vm.thaCamXuc(m, e) } }
            }
            Button { traLoi = m; dangSoan = true } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
            if let c = m.content, !c.isEmpty {
                Button { UIPasteboard.general.string = c } label: { Label("Copy", systemImage: "doc.on.doc") }
            }
            if ChatRiengVM.thuHoiDuoc(m, toi: vm.toi) {
                Button(role: .destructive) { Task { await vm.thuHoi(m) } } label: { Label("Unsend", systemImage: "arrow.uturn.backward") }
            }
            if m.senderId != vm.toi {
                Button(role: .destructive) { tamPhu = .baoCao } label: { Label("Report", systemImage: "exclamationmark.bubble") }
            }
        }
    }

    private var coGiDeGui: Bool { !chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !anhCho.isEmpty || !tepCho.isEmpty }

    private func gui() async {
        let (c, a, t, r) = (chu, anhCho, tepCho, traLoi)
        chu = ""; anhCho = []; tepCho = []; traLoi = nil
        if !(await vm.gui(chu: c, anh: a, tep: t, traLoi: r)) {
            // Hỏng ⇒ trả nháp lại cho người dùng, không mất chữ/ảnh.
            chu = c; anhCho = a; tepCho = t; traLoi = r
        }
    }

    private func moTepDinhKem(_ a: MessageAttachment) {
        guard let u = DuongDanAnh.url(a.url) else { return }
        Task { xemTep = try? await CTWXemTep.taiVe(url: u, ten: a.fileName ?? "file", khoa: "dm-\(a.id)") }
    }

    private func canMocGio(_ i: Int) -> Bool {
        guard let d = vm.tin[i].ngayGio else { return false }
        guard i > 0, let truoc = vm.tin[i - 1].ngayGio else { return true }
        return d.timeIntervalSince(truoc) > 15 * 60
    }

    private func cuoiNhom(_ i: Int) -> Bool {
        guard i + 1 < vm.tin.count else { return true }
        let a = vm.tin[i], b = vm.tin[i + 1]
        if a.senderId != b.senderId { return true }
        guard let x = a.ngayGio, let y = b.ngayGio else { return true }
        return y.timeIntervalSince(x) > 15 * 60
    }

    private func mocGio(_ m: Message) -> some View {
        Text(m.ngayGio.map(Self.gioDai) ?? "")
            .font(.ctw(size: 11, weight: .medium)).foregroundColor(AppColors.textTertiary)
            .padding(.vertical, 8)
    }

    // MARK: Định dạng (dùng chung danh sách hội thoại)

    /// "14:05" hôm nay · "Th 2" trong tuần · "5 thg 10" xa hơn.
    static func gioNgan(_ d: Date, bayGio: Date = Date()) -> String {
        let l = Calendar.current
        if l.isDate(d, inSameDayAs: bayGio) { return CTWDinhDang.gio(d) }
        if let n = l.dateComponents([.day], from: l.startOfDay(for: d), to: l.startOfDay(for: bayGio)).day, n < 7 {
            return CTWDinhDang.mau("EEE").string(from: d)
        }
        return CTWDinhDang.mau("MMMd").string(from: d)
    }

    static func gioDai(_ d: Date) -> String {
        let l = Calendar.current
        if l.isDateInToday(d) { return CTWDinhDang.gio(d) }
        if l.isDateInYesterday(d) { return String(localized: "Yesterday \(CTWDinhDang.gio(d))") }
        return CTWDinhDang.mau("EEEMMMd").string(from: d) + " " + CTWDinhDang.gio(d)
    }

    /// Dòng tóm tắt một tin (danh sách hội thoại, trích dẫn khi trả lời).
    static func tomTat(_ m: Message) -> String {
        if m.daXoaHoacThuHoi { return String(localized: "Message unsent") }
        if let c = m.content, !c.isEmpty { return c }
        if (m.hasAttachment ?? false) || !m.anh.isEmpty { return String(localized: "📷 Photo") }
        if !m.tepKhongPhaiAnh.isEmpty { return String(localized: "📎 File") }
        return ""
    }
}

// MARK: - Bong bóng

struct BongTinCTW: View {
    let m: Message
    let cuaToi: Bool
    let nguoiKia: CTWUser
    let hienAvatar: Bool
    let toi: Int?
    var xemAnh: (URL) -> Void = { _ in }
    var moTep: (MessageAttachment) -> Void = { _ in }

    static let camXucNhanh = ["❤️", "😆", "😮", "😢", "😡", "👍"]

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if cuaToi { Spacer(minLength: 56) } else {
                Group { if hienAvatar { CTWAvatar(user: nguoiKia, size: 28) } else { Color.clear } }.frame(width: 28, height: 28)
            }
            VStack(alignment: cuaToi ? .trailing : .leading, spacing: 3) {
                if let p = m.parentMessage, !m.daXoaHoacThuHoi {
                    Text(p.content.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Attachment"))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.border, lineWidth: 1))
                }
                if m.daXoaHoacThuHoi {
                    Text(cuaToi ? String(localized: "You unsent a message") : String(localized: "Message unsent"))
                        .font(.ctw(size: 14).italic()).foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 18).strokeBorder(AppColors.border, lineWidth: 1))
                } else {
                    if !m.anh.isEmpty { luoiAnh }
                    ForEach(m.tepKhongPhaiAnh) { a in
                        Button { moTep(a) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill").font(.ctw(size: 20)).foregroundColor(cuaToi ? .white : AppColors.primary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.fileName ?? String(localized: "File")).font(.ctw(size: 14, weight: .semibold)).lineLimit(2)
                                    if let s = a.fileSize { Text(ByteCountFormatter.string(fromByteCount: Int64(s), countStyle: .file)).font(.ctw(size: 11)).opacity(0.8) }
                                }
                            }
                            .foregroundColor(cuaToi ? .white : AppColors.textPrimary)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 16).fill(cuaToi ? AppColors.primary : AppColors.backgroundSecondary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "File \(a.fileName ?? "")"))
                    }
                    if let c = m.content, !c.isEmpty {
                        Text(c)
                            .font(.ctw(size: 16))
                            .foregroundColor(cuaToi ? .white : AppColors.textPrimary)
                            .textSelection(.enabled)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(cuaToi ? AppColors.primary : AppColors.backgroundSecondary))
                    }
                }
                if let r = m.reactions, !r.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(r) { x in
                            Text(x.count > 1 ? "\(x.emoji)\(x.count)" : x.emoji).font(.ctw(size: 12))
                        }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.backgroundCard))
                    .overlay(Capsule().strokeBorder(r.contains { $0.coCua(toi) } ? AppColors.primary.opacity(0.6) : AppColors.border, lineWidth: 1))
                    .offset(y: -6)
                    .padding(.bottom, -6)
                }
            }
            if !cuaToi { Spacer(minLength: 56) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
    }

    private var luoiAnh: some View {
        let ds = m.anh.compactMap { DuongDanAnh.urlAnh($0) ?? URL(string: $0) }
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(ds.count == 1 ? 220 : 108), spacing: 4), count: min(2, max(1, ds.count))), spacing: 4) {
            ForEach(ds, id: \.self) { u in
                KFImage(u).placeholder { Rectangle().fill(AppColors.backgroundSecondary).overlay(ProgressView()) }
                    .resizable().scaledToFill()
                    .frame(width: ds.count == 1 ? 220 : 108, height: ds.count == 1 ? 220 : 108)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { xemAnh(u) }
                    .accessibilityLabel("Photo")
            }
        }
    }
}

// MARK: - Xem ảnh lớn

struct XemAnhLonCTW: View {
    let url: URL
    @Environment(\.dismiss) private var dong
    var body: some View {
        NavigationStack {
            KFImage(url).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
