import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Kingfisher

// MARK: - Chat 1-1 kiểu Messenger (Messenger chung — `messages.routes.ts`) — bản 1.1 (22/10/2026)
//
// Ảnh chủ app gửi 22/10: bong bóng phẳng, mốc ngày trên GẦN NHƯ MỌI tin, ô soạn chỉ có "+" và ô chữ. Bản này:
//   · gom nhóm như Messenger (`NhomTinCTW`: cùng người, ≤ 3 phút ⇒ bo góc liền, avatar MỘT lần ở cuối nhóm), mốc thời gian
//     CHỈ khi cách > 1 giờ / khác ngày; chạm tin ⇒ giờ gửi;
//   · nhấn giữ ⇒ `MenuGiuTinRiengCTW` (thanh cảm xúc ❤️😂😮😢😡👍 + bảng emoji, Trả lời, Sao chép, Chuyển tiếp, Lưu ảnh,
//     Thu hồi ≤ 5 phút, Báo cáo);
//   · ô soạn `OSoanTinRiengCTW` (máy ảnh, ảnh, tệp, nhãn dán, GIF, emoji, GIỮ micro để ghi tin thoại, 👍 khi trống);
//   · gửi LẠC QUAN: tin hiện ngay (mờ, "Đang gửi…"), hỏng ⇒ "Chưa gửi được · Chạm để thử lại" — không mất chữ;
//   · "Đã xem" = avatar nhỏ dưới tin cuối người kia đã đọc, "Đang nhập…" = bong bóng ba chấm, nút xuống cuối + số tin mới;
//   · ⓘ = Thông tin hội thoại (hồ sơ, biệt danh, tắt thông báo, chặn, báo cáo, xoá phía tôi). 1.2: báo cáo/chặn có ở menu
//     nhấn giữ, ⓘ và hồ sơ; người đã chặn ⇒ khoá ô soạn.
// Realtime: `RealtimeCTW.tinNhan*` (máy chủ tự cho socket vào phòng mọi hội thoại lúc bắt tay).

/// Một tin đang gửi (chưa có id máy chủ).
struct TinChoRiengCTW: Identifiable {
    enum NoiDung {
        case chu(String)
        case tep(String, [TepChoGuiCTW])
        case media(String, String)
        case thoai(Data, Int)
    }
    let id = UUID()
    var noiDung: NoiDung
    var traLoi: Int?
    var hong: String?

    var xemTruoc: String {
        switch noiDung {
        case .chu(let c): return c
        case .tep(let c, let ds):
            let anh = ds.filter(\.laAnh).count
            let tom = anh == ds.count ? (anh == 1 ? String(localized: "📷 Photo") : String(localized: "📷 \(anh) photos"))
                : String(localized: "📎 \(ds.count) files")
            return c.isEmpty ? tom : c
        case .media(_, let k): return k == "gif" ? String(localized: "🎬 GIF") : String(localized: "🪄 Sticker")
        case .thoai(_, let ms): return String(localized: "🎤 Voice message \(ThoaiCTW.dongHo(Double(ms) / 1000))")
        }
    }
}

@MainActor
final class ChatRiengVM: ObservableObject {
    let threadId: Int
    @Published var hoiThoai: MessageThread?
    @Published var tin: [Message] = []
    @Published var dangTai = true
    @Published var conCu = false
    @Published var loi: String?
    @Published var tienDoTai: String?
    /// Mốc người kia đã đọc tới — vẽ "Đã xem".
    @Published var hoDocLuc: Date?
    @Published var dangCho: [TinChoRiengCTW] = []
    /// Tin mới của người kia về khi đang cuộn ở trên — số trên nút "xuống cuối".
    @Published var moiChuaXem = 0
    var oDay = true

    private var huy: [Any] = []
    private var lanGoCuoi = Date.distantPast

    init(threadId: Int) {
        self.threadId = threadId
        hoiThoai = KhoTinNhanCTW.shared.hoiThoai(threadId)
        let r = RealtimeCTW.shared
        huy.append(r.tinNhanMoi.sink { [weak self] e in
            guard let self, e.threadId == threadId else { return }
            let moi = !tin.contains { $0.id == e.tin.id }
            them(e.tin)
            if e.tin.senderId != toi {
                KhoTinNhanCTW.shared.danhDauDaDoc(threadId)
                if moi && !oDay { moiChuaXem += 1 }
            }
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
    var nguoiKia: ThreadPeer? { hoiThoai?.peer ?? KhoTinNhanCTW.shared.hoiThoai(threadId)?.peer }

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

    // MARK: Gửi (lạc quan)

    func gui(_ nd: TinChoRiengCTW.NoiDung, traLoi: Int?) {
        baoGo(false)
        let c = TinChoRiengCTW(noiDung: nd, traLoi: traLoi)
        dangCho.append(c)
        Task { await chay(c.id) }
    }

    func thuLai(_ id: UUID) {
        guard let i = dangCho.firstIndex(where: { $0.id == id }) else { return }
        dangCho[i].hong = nil
        Task { await chay(id) }
    }

    func bo(_ id: UUID) { dangCho.removeAll { $0.id == id } }

    private func chay(_ id: UUID) async {
        guard let c = dangCho.first(where: { $0.id == id }) else { return }
        do {
            let m: Message
            switch c.noiDung {
            case .chu(let s):
                m = try await APIClient.shared.request(TinNhanAPI.gui(threadId: threadId, noiDung: s, tepIds: [], traLoi: c.traLoi))
            case .tep(let s, let ds):
                var ids: [Int] = []
                for (i, t) in ds.enumerated() {
                    tienDoTai = String(localized: "Uploading \(i + 1)/\(ds.count)…")
                    ids.append(try await APIClient.shared.taiLenChat(data: t.data, fileName: t.ten, mimeType: t.mime).fileId)
                }
                tienDoTai = nil
                m = try await APIClient.shared.request(TinNhanAPI.gui(threadId: threadId, noiDung: s, tepIds: ids, traLoi: c.traLoi))
            case .media(let u, let k):
                m = try await APIClient.shared.request(TinNhanAPI.guiMedia(threadId: threadId, url: u, kieu: k, traLoi: c.traLoi))
            case .thoai(let d, _):
                let ten = "voice-\(Int(Date().timeIntervalSince1970)).m4a"
                let f = try await APIClient.shared.taiLenChat(data: d, fileName: ten, mimeType: "audio/mp4").fileId
                m = try await APIClient.shared.request(TinNhanAPI.gui(threadId: threadId, noiDung: "", tepIds: [f], traLoi: c.traLoi))
            }
            dangCho.removeAll { $0.id == id }
            them(m)
            CTWRung.chon()
        } catch {
            tienDoTai = nil
            if let i = dangCho.firstIndex(where: { $0.id == id }) { dangCho[i].hong = CTW.loi(error) }
            CTWRung.loi()
        }
    }

    // MARK: Cảm xúc / thu hồi

    func thaCamXuc(_ m: Message, _ e: String) {
        // Lạc quan: đảo ngay, socket `message:updated` sẽ chốt số thật.
        if let i = tin.firstIndex(where: { $0.id == m.id }), let toi {
            tin[i] = tin[i].doi(camXuc: CamXucCTW.dao(tin[i].reactions ?? [], emoji: e, toi: toi), thuHoi: nil, daXoa: nil)
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
        guard m.senderId == toi, !m.daXoaHoacThuHoi, m.id > 0, let d = m.ngayGio else { return false }
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
    @EnvironmentObject private var nganXep: NganXepCTW
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var chu = ""
    @State private var ghimDay = GhimDayChatCTW()
    @State private var traLoi: Message?
    @State private var cho: [TepChoGuiCTW] = []
    @State private var anhChon: [PhotosPickerItem] = []
    @State private var moThuVien = false
    @State private var moMayAnh = false
    @State private var moTep = false
    @State private var tamPhu: TamPhu?
    @State private var xemTep: URL?
    @State private var giu: Message?
    @State private var hienGio: Int?
    @State private var nhapNhay: Int?
    @State private var oDay = true
    @State private var thongBao: String?
    @FocusState private var dangSoan: Bool

    /// MỘT `.sheet(item:)` cho mọi tấm phủ (CLAUDE.md C5 — nhiều `.sheet` trên một view chỉ cái cuối chạy).
    enum TamPhu: Identifiable {
        case baoCao, hoSo(Int), anh(URL), gif(Int), emoji, camXuc(Message), aiCamXuc(Message), chuyenTiep(Message), thongTin
        var id: String {
            switch self {
            case .baoCao: return "bc"
            case .hoSo(let i): return "hs\(i)"
            case .anh(let u): return u.absoluteString
            case .gif(let p): return "gif\(p)"
            case .emoji: return "emoji"
            case .camXuc(let m): return "cx\(m.id)"
            case .aiCamXuc(let m): return "ai\(m.id)"
            case .chuyenTiep(let m): return "ct\(m.id)"
            case .thongTin: return "tt"
            }
        }
    }

    init(threadId: Int) {
        self.threadId = threadId
        _vm = StateObject(wrappedValue: ChatRiengVM(threadId: threadId))
    }

    private var peer: ThreadPeer? { vm.nguoiKia }
    private var tenKia: String {
        let t = kho.hoiThoai(threadId) ?? vm.hoiThoai
        if let p = peer, let n = kho.thanhVien(p.id), t?.bietDanh == nil { return n.ten }
        return t?.peer?.displayName ?? peer?.username ?? String(localized: "Conversation")
    }
    private var mocKia: TrangThaiHoatDongCTW.Moc { peer.map { kho.moc($0.id, mocHoiThoai: $0.lastActiveAt) } ?? .an }
    private var daChan: Bool { peer.map { kd.blockedUserIds.contains($0.id) } ?? false }
    private var userKia: CTWUser {
        CTWUser(id: peer?.id ?? 0, username: peer?.username, displayName: tenKia,
                avatarUrl: peer?.avatarUrl ?? peer.flatMap { kho.thanhVien($0.id)?.avatarUrl })
    }

    var body: some View {
        ScrollViewReader { cuon in
            danhSach(cuon)
                .overlay(alignment: .bottomTrailing) { nutXuongCuoi(cuon) }
                .onChange(of: vm.tin.last?.id) { _, _ in
                    if vm.tin.last?.senderId == vm.toi || oDay { withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) } }
                }
                .onChange(of: vm.dangCho.count) { _, _ in withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) } }
                .onChange(of: nhapNhay) { _, id in
                    guard let id else { return }
                    withAnimation { cuon.scrollTo(id, anchor: .center) }
                    Task { try? await Task.sleep(for: .seconds(1.2)); withAnimation { nhapNhay = nil } }
                }
        }
        .overlay {
            if vm.dangTai && vm.tin.isEmpty { ProgressView() }
            else if let l = vm.loi, vm.tin.isEmpty { CTWOLoi(loi: l) { Task { await vm.tai() } } }
        }
        .overlay(alignment: .top) {
            if let thongBao {
                Text(thongBao).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.88)))
                    .padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { oSoan }
        .overlay { if let g = giu { menuGiu(g) } }
        .modifier(BoFocusKhiAnBanPhimCTW(dangGo: $dangSoan))
        .background(AppColors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(beRong == .compact ? .hidden : .automatic, for: .tabBar)   // như Messenger: khung chat chiếm trọn màn (iPhone)
        .toolbar {
            ToolbarItem(placement: .principal) { dauKhung }
            ToolbarItem(placement: .primaryAction) {
                Button { tamPhu = .thongTin } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("Conversation details")
                    .accessibilityIdentifier("dm.info")
            }
        }
        .task { await vm.tai(); moManThu() }
        .onAppear { KhoTinNhanCTW.hoiThoaiDangMo = threadId }
        .onDisappear {
            if KhoTinNhanCTW.hoiThoaiDangMo == threadId { KhoTinNhanCTW.hoiThoaiDangMo = nil }
            vm.baoGo(false)
            TrinhPhatThoaiCTW.shared.dung()
        }
        .photosPicker(isPresented: $moThuVien, selection: $anhChon, maxSelectionCount: 6, matching: .images)
        .onChange(of: anhChon) { _, ds in
            guard !ds.isEmpty else { return }
            Task {
                for (i, it) in ds.enumerated() {
                    if let d = try? await it.loadTransferable(type: Data.self), let u = UIImage(data: d), let j = Self.nen(u) {
                        cho.append(TepChoGuiCTW(data: j, ten: "photo-\(i + 1).jpg", mime: "image/jpeg"))
                    }
                }
                anhChon = []
            }
        }
        .fullScreenCover(isPresented: $moMayAnh) {
            MayAnh { d in cho.append(TepChoGuiCTW(data: d, ten: "camera.jpg", mime: "image/jpeg")) }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $moTep, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            guard case .success(let urls) = r else { return }
            for u in urls.prefix(5) {
                let truyCap = u.startAccessingSecurityScopedResource()
                defer { if truyCap { u.stopAccessingSecurityScopedResource() } }
                guard let d = try? Data(contentsOf: u) else { continue }
                guard d.count <= 10 * 1024 * 1024 else { hien(String(localized: "Files must be 10 MB or smaller")); continue }
                let mime = UTType(filenameExtension: u.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                cho.append(TepChoGuiCTW(data: d, ten: u.lastPathComponent, mime: mime))
            }
        }
        .ctwXemTep($xemTep)
        .sheet(item: $tamPhu) { t in tamPhuView(t) }
    }

    // MARK: Danh sách tin

    private func danhSach(_ cuon: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if vm.conCu {
                    ProgressView().padding(.vertical, 12)
                        .onAppear {
                            let dau = vm.tin.first?.id
                            Task { await vm.taiCuHon(); if let dau { cuon.scrollTo(dau, anchor: .top) } }
                        }
                }
                dauHoiThoai
                let bc = NhomTinCTW.boCuc(vm.tin.map(Self.muc))
                let daXem = ChatRiengVM.tinDaXem(vm.tin, toi: vm.toi, hoDocLuc: vm.hoDocLuc)
                let cuoiCuaToi = vm.tin.last(where: { $0.senderId == vm.toi })?.id
                ForEach(Array(vm.tin.enumerated()), id: \.element.id) { i, m in
                    let b = i < bc.count ? bc[i] : BoCucTinCTW(viTri: .don, mocThoiGian: false)
                    VStack(spacing: 0) {
                        if b.mocThoiGian, let d = m.ngayGio { MocThoiGianTinCTW(d: d) }
                        bong(m, b.viTri)
                            .padding(.top, b.viTri.laDau && !b.mocThoiGian ? 7 : 1)
                            .background(nhapNhay == m.id ? AppColors.primary.opacity(0.12) : .clear)
                        if m.id == daXem && vm.dangCho.isEmpty {
                            HStack { Spacer(); CTWAvatar(user: userKia, size: 15) }
                                .padding(.trailing, 12).padding(.top, 3)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(String(localized: "Seen by \(tenKia)"))
                                .accessibilityIdentifier("dm.seen")
                        } else if m.id == cuoiCuaToi && vm.dangCho.isEmpty && !m.daXoaHoacThuHoi {
                            HStack(spacing: 3) {
                                Spacer()
                                Image(systemName: "checkmark.circle").font(.ctw(size: 11))
                                Text("Sent").font(.ctw(size: 11))
                            }
                            .foregroundColor(AppColors.textTertiary).padding(.trailing, 12).padding(.top, 3)
                            .accessibilityIdentifier("dm.sent")
                        }
                    }
                    .id(m.id)
                }
                ForEach(vm.dangCho) { c in tinCho(c) }
                if !(kho.dangGo[threadId] ?? []).isEmpty { BongDangGoCTW(nguoi: userKia).id("go") }
                Color.clear.frame(height: 6).id("cuoi")
                    .onAppear { oDay = true; vm.oDay = true; vm.moiChuaXem = 0 }
                    .onDisappear { oDay = false; vm.oDay = false }
            }
            .padding(.top, 8)
            // Ảnh tải xong (khung theo tỉ lệ thật) làm nội dung cao thêm ⇒ giữ dính đáy (cùng luật kênh chat — §21).
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("dm.cuon")) } action: { khung in
                if ghimDay.doNoiDung(khung) { cuon.scrollTo("cuoi", anchor: .bottom) }
            }
        }
        .coordinateSpace(.named("dm.cuon"))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cao in
            if ghimDay.doKhung(cao) { cuon.scrollTo("cuoi", anchor: .bottom) }
        }
        .modifier(PhaCuonChatCTW(ghim: ghimDay))
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(.bottom)
        .onChange(of: vm.dangTai) { _, dang in
            if !dang { ghimDay.batDauNap() }
            cuon.scrollTo("cuoi", anchor: .bottom)
        }
    }

    static func muc(_ m: Message) -> NhomTinCTW.Muc {
        NhomTinCTW.Muc(nguoi: m.senderId, luc: m.ngayGio,
                       dungRieng: m.daXoaHoacThuHoi || TomTatTinCTW.laNhanDan(m) || EmojiLonCTW.la(m.content))
    }

    private func bong(_ m: Message, _ v: ViTriNhomCTW) -> some View {
        BongTinRiengCTW(
            m: m, cuaToi: m.senderId == vm.toi, viTri: v, nguoiKia: userKia, tenKia: tenKia, toi: vm.toi,
            hienGio: hienGio == m.id,
            cham: { withAnimation(.easeOut(duration: 0.15)) { hienGio = hienGio == m.id ? nil : m.id } },
            giu: { dangSoan = false; withAnimation(.easeOut(duration: 0.12)) { giu = m } },
            xemAnh: { tamPhu = .anh($0) },
            moTep: moTepDinhKem,
            moHoSo: { if let p = peer { tamPhu = .hoSo(p.id) } },
            xemCamXuc: { tamPhu = .aiCamXuc(m) },
            denTinGoc: { id in if vm.tin.contains(where: { $0.id == id }) { nhapNhay = id } })
    }

    private func tinCho(_ c: TinChoRiengCTW) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack {
                Spacer(minLength: 48)
                Text(verbatim: c.xemTruoc)
                    .font(.ctw(size: 16)).foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: GocBongCTW.lon, style: .continuous)
                        .fill(c.hong == nil ? AppColors.primary.opacity(0.55) : AppColors.error.opacity(0.75)))
            }
            if c.hong != nil {
                HStack(spacing: 12) {
                    Text("Not sent").foregroundColor(AppColors.error)
                    Button("Retry") { vm.thuLai(c.id) }.accessibilityIdentifier("dm.retry")
                    Button("Delete", role: .destructive) { vm.bo(c.id) }
                }
                .font(.ctw(size: 12, weight: .semibold))
            } else {
                Text("Sending…").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, 10).padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dm.pending.\(c.id.uuidString.prefix(4))")
    }

    @ViewBuilder private var dauHoiThoai: some View {
        if !vm.conCu, !vm.dangTai {
            VStack(spacing: 6) {
                AvatarHoatDongCTW(user: userKia, size: 76, moc: mocKia)
                Text(verbatim: tenKia).font(.ctw(size: 19, weight: .bold)).foregroundColor(AppColors.textPrimary)
                if let p = peer, let n = kho.thanhVien(p.id), !n.dongPhu.isEmpty {
                    Text(n.dongPhu).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
                }
                if let p = peer {
                    Button { tamPhu = .hoSo(p.id) } label: {
                        Text("View profile").font(.ctw(size: 13, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(AppColors.backgroundSecondary))
                    }
                    .buttonStyle(.plain).foregroundColor(AppColors.textPrimary)
                    .accessibilityIdentifier("dm.viewProfile")
                }
            }
            .padding(.vertical, 18).padding(.horizontal, 24)
        }
    }

    private var dauKhung: some View {
        Button { if let p = peer { tamPhu = .hoSo(p.id) } } label: {
            HStack(spacing: 8) {
                AvatarHoatDongCTW(user: userKia, size: 32, moc: mocKia)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: tenKia).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    let c = !(kho.dangGo[threadId] ?? []).isEmpty ? String(localized: "typing…") : TrangThaiHoatDongCTW.chu(mocKia)
                    if !c.isEmpty {
                        Text(c).font(.ctw(size: 11)).foregroundColor(mocKia == .dangHoatDong ? AppColors.success : AppColors.textSecondary).lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(peer == nil)
        .accessibilityHint(Text("Opens their profile"))
        .accessibilityIdentifier("dm.header")
    }

    @ViewBuilder private func nutXuongCuoi(_ cuon: ScrollViewProxy) -> some View {
        if !oDay && !vm.tin.isEmpty {
            Button { withAnimation { cuon.scrollTo("cuoi", anchor: .bottom) } } label: {
                Image(systemName: "arrow.down").font(.ctw(size: 16, weight: .bold)).foregroundColor(AppColors.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(AppColors.backgroundCard).shadow(color: .black.opacity(0.15), radius: 6, y: 2))
                    .overlay(alignment: .topTrailing) {
                        if vm.moiChuaXem > 0 {
                            Text(verbatim: "\(vm.moiChuaXem)").font(.ctw(size: 11, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(AppColors.error))
                                .offset(x: 6, y: -6)
                        }
                    }
            }
            .padding(.trailing, 14).padding(.bottom, 10)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel(vm.moiChuaXem > 0 ? String(localized: "\(vm.moiChuaXem) new messages, jump to latest") : String(localized: "Jump to latest"))
            .accessibilityIdentifier("dm.jump")
        }
    }

    // MARK: Ô soạn

    @ViewBuilder private var oSoan: some View {
        if daChan {
            VStack(spacing: 6) {
                Divider()
                Text("You blocked \(tenKia).").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text("You can't message each other while they're blocked.").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                Button("Unblock") { Task { if let p = peer { try? await kd.unblock(userId: p.id) } } }
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity).background(AppColors.backgroundCard)
        } else {
            VStack(spacing: 0) {
                if let l = vm.loi, !vm.tin.isEmpty { CTWErrorBanner(text: l) { vm.loi = nil }.padding(.horizontal, 12).padding(.vertical, 6) }
                OSoanTinRiengCTW(
                    chu: $chu, dangSoan: $dangSoan, cho: $cho,
                    traLoi: traLoi.map { TrichDanCTW.tuTin($0, toi: vm.toi, tenKia: tenKia) },
                    tenKia: tenKia, tienDo: vm.tienDoTai,
                    huyTraLoi: { traLoi = nil },
                    gui: gui,
                    guiThich: { vm.gui(.chu("👍"), traLoi: traLoi?.id); traLoi = nil },
                    guiThoai: { d, ms in vm.gui(.thoai(d, ms), traLoi: traLoi?.id); traLoi = nil },
                    mo: { m in
                        switch m {
                        case .tep: moTep = true
                        case .nhanDan: tamPhu = .gif(1)
                        case .mayAnh: moMayAnh = true
                        case .thuVien: moThuVien = true
                        case .gif: tamPhu = .gif(0)
                        case .emoji: tamPhu = .emoji
                        }
                    },
                    baoGo: { vm.baoGo($0) })
            }
        }
    }

    private func gui() {
        let c = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = traLoi?.id
        if !cho.isEmpty { vm.gui(.tep(c, cho), traLoi: r) } else if !c.isEmpty { vm.gui(.chu(c), traLoi: r) } else { return }
        chu = ""; cho = []; traLoi = nil
    }

    // MARK: Nhấn giữ

    private func menuGiu(_ m: Message) -> some View {
        MenuGiuTinRiengCTW(m: m, cuaToi: m.senderId == vm.toi, nguoiKia: userKia, tenKia: tenKia, toi: vm.toi,
                           chon: { t in xuLy(t, m) }, dong: { withAnimation(.easeOut(duration: 0.12)) { giu = nil } })
            .transition(.opacity)
            .zIndex(10)
    }

    private func xuLy(_ t: ThaoTacGiuCTW, _ m: Message) {
        withAnimation(.easeOut(duration: 0.12)) { giu = nil }
        switch t {
        case .camXuc(let e): vm.thaCamXuc(m, e); CTWRung.chon()
        case .themCamXuc: tamPhu = .camXuc(m)
        case .traLoi: traLoi = m; dangSoan = true
        case .chep: UIPasteboard.general.string = m.content; hien(String(localized: "Copied"))
        case .chuyenTiep: tamPhu = .chuyenTiep(m)
        case .luuAnh:
            let urls = TomTatTinCTW.anhTep(m).compactMap { DuongDanAnh.urlAnh($0.url) ?? URL(string: $0.url) }
            Task { hien(await LuuAnhCTW.luu(urls) ? String(localized: "Saved to Photos") : String(localized: "Couldn't save the photo")) }
        case .thuHoi: Task { await vm.thuHoi(m) }
        case .baoCao: tamPhu = .baoCao
        }
    }

    private func hien(_ s: String) {
        withAnimation { thongBao = s }
        Task { try? await Task.sleep(for: .seconds(1.8)); withAnimation { if thongBao == s { thongBao = nil } } }
    }

    // MARK: Tấm phủ

    @ViewBuilder private func tamPhuView(_ t: TamPhu) -> some View {
        switch t {
        case .baoCao: BaoCaoNguoiCTW(ten: tenKia, userId: peer?.id ?? 0, threadId: threadId)
        case .hoSo(let id): NavigationStack { HoSoThanhVienCTW(userId: id, laTamPhu: true) }
        case .anh(let u): XemAnhLonCTW(url: u)
        case .gif(let p):
            BangChonGifCTW(batDau: p) { url, kieu in vm.gui(.media(url, kieu), traLoi: traLoi?.id); traLoi = nil }
        case .emoji: BangEmojiCTW(tieuDe: "Emoji", chon: { chu += $0 }, dongSauKhiChon: false)
        case .camXuc(let m): BangEmojiCTW(tieuDe: "Add reaction", chon: { vm.thaCamXuc(m, $0) })
        case .aiCamXuc(let m):
            AiCamXucCTW(m: vm.tin.first { $0.id == m.id } ?? m, toi: vm.toi, tenKia: tenKia) { e in vm.thaCamXuc(m, e) }
        case .chuyenTiep(let m): ChuyenTiepTinRiengCTW(m: m, tuHoiThoai: threadId)
        case .thongTin:
            ThongTinHoiThoaiCTW(threadId: threadId, peerId: peer?.id, tenKia: tenKia, nguoi: userKia, moc: mocKia,
                                moHoSo: { mo(.hoSo(peer?.id ?? 0)) }, baoCao: { mo(.baoCao) },
                                daXoa: { if !nganXep.duong.isEmpty { nganXep.duong.removeLast() } })
        }
    }

    /// Mở tấm phủ khác SAU khi tấm đang mở đóng hẳn (SwiftUI bỏ qua lệnh mở khi một tấm còn đang đóng dở).
    private func mo(_ t: TamPhu) {
        Task { try? await Task.sleep(for: .milliseconds(450)); tamPhu = t }
    }

    private func moTepDinhKem(_ a: MessageAttachment) {
        guard let u = DuongDanAnh.url(a.url) else { return }
        Task { xemTep = try? await CTWXemTep.taiVe(url: u, ten: a.fileName ?? "file", khoa: "dm-\(a.id)") }
    }

    /// Ảnh gửi đi: cạnh dài ≤ 2048 px, JPEG 0,82 (máy chủ trần 10 MB / tệp).
    static func nen(_ u: UIImage) -> Data? {
        let dai = max(u.size.width, u.size.height) * u.scale
        guard dai > 2048 else { return u.jpegData(compressionQuality: 0.82) }
        let k = 2048 / dai
        let co = CGSize(width: u.size.width * u.scale * k, height: u.size.height * u.scale * k)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: co, format: f).image { _ in u.draw(in: CGRect(origin: .zero, size: co)) }
            .jpegData(compressionQuality: 0.82)
    }

    // MARK: Màn thử (DEBUG) — `CT_XEM_DM=giu|traloi|gif|info|camxuc`

    private func moManThu() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CT_XEM_DM_GO"] == "1", let p = peer { kho.giaDangGo(threadId: threadId, userId: p.id) }
        guard let k = ProcessInfo.processInfo.environment["CT_XEM_DM"], let cuoi = vm.tin.last(where: { $0.senderId != vm.toi }) else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            switch k {
            case "giu": giu = cuoi
            case "traloi": traLoi = cuoi
            case "gif": tamPhu = .gif(0)
            case "info": tamPhu = .thongTin
            case "camxuc": tamPhu = .aiCamXuc(vm.tin.first { !($0.reactions ?? []).isEmpty } ?? cuoi)
            default: break
            }
        }
        #endif
    }

    // MARK: Định dạng (dùng chung danh sách hội thoại + kiểm thử cũ)

    /// "14:05" hôm nay · "Th 2" trong tuần · "5 thg 10" xa hơn.
    static func gioNgan(_ d: Date, bayGio: Date = Date()) -> String { ThoiGianNganCTW.chuoi(d, bayGio: bayGio) }

    static func gioDai(_ d: Date) -> String { NhanMocCTW.chuoi(d) }

    /// Dòng tóm tắt một tin (danh sách hội thoại, trích dẫn khi trả lời).
    static func tomTat(_ m: Message) -> String { TomTatTinCTW.chu(m) }
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
