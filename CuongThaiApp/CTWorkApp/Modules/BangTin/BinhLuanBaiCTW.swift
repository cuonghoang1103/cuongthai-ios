import SwiftUI
import Combine

// MARK: - Bình luận của một bài (tấm phủ ở bảng tin · nhúng trong màn chi tiết bài)
//
// `GET /feed/posts/:id/comments` xếp CŨ → MỚI; gốc kèm ≤ 2 trả lời đầu + `replyCount`, phần còn lại xin bằng `parentId`.
// Trả lời đúng MỘT cấp (trả lời một trả lời ⇒ máy chủ gắn vào gốc). @nhắc gợi ý từ `/feed/mentionable`.
// 1.2: nhấn giữ ⇒ Báo cáo / Chặn; bình luận của người đã chặn thu gọn ("Bình luận từ người bạn đã chặn").

@MainActor
final class BinhLuanVM: ObservableObject {
    let postId: Int
    @Published var bai: CTWFeedPost?
    @Published private(set) var ds: [CTWFeedComment] = []
    @Published private(set) var con: String?
    @Published private(set) var dangTai = false
    @Published private(set) var daTai = false
    @Published var loi: String?
    @Published private(set) var dangGui = false
    @Published private(set) var goiY: [CTWUser] = []
    @Published var bang: String?
    /// Bộ lọc nội dung từ chối bình luận (422 CONTENT_BLOCKED) — hiện TẠI CHỖ trên ô soạn, chữ vẫn nằm trong ô.
    @Published var loiChan: String?

    private var huy = Set<AnyCancellable>()
    private var timNhacTask: Task<Void, Never>?

    init(postId: Int, bai: CTWFeedPost?) {
        self.postId = postId
        self.bai = bai
        RealtimeCTW.shared.suKienBangTin.sink { [weak self] e in
            guard let self, e.postId == postId, e.type.hasPrefix("comment."), e.actorId != AppState.shared.currentUser?.id else { return }
            Task { await self.nhanSuKien(e) }
        }.store(in: &huy)
        KhoBangTinCTW.shared.baiDoi.sink { [weak self] p in if p.id == postId { self?.bai = p } }.store(in: &huy)
    }

    var toi: Int? { AppState.shared.currentUser?.id }

    func tai() async {
        dangTai = true
        defer { dangTai = false; daTai = true }
        if bai == nil { bai = try? await APIClient.shared.request(CTWAPI.bai(postId)) }
        do {
            let t: CTWFeedTrangBinhLuan = try await APIClient.shared.request(CTWAPI.binhLuanBai(postId, cha: nil, cursor: nil))
            ds = BinhLuanLogic.noi([], t.comments ?? [])
            con = t.nextCursor
            loi = nil
        } catch { if ds.isEmpty { loi = BangTinLoi.chu(error) } }
    }

    func taiThem() async {
        guard let c = con else { return }
        if let t: CTWFeedTrangBinhLuan = try? await APIClient.shared.request(CTWAPI.binhLuanBai(postId, cha: nil, cursor: c)) {
            ds = BinhLuanLogic.noi(ds, t.comments ?? [])
            con = t.nextCursor
        }
    }

    /// "Xem thêm N trả lời" — tải mọi trả lời của một gốc (đủ dùng: trả lời một cấp thường ngắn).
    func taiTraLoi(_ goc: CTWFeedComment) async {
        var cursor: String?
        var gom: [CTWFeedComment] = goc.replies ?? []
        for _ in 0..<5 {
            guard let t: CTWFeedTrangBinhLuan = try? await APIClient.shared.request(CTWAPI.binhLuanBai(postId, cha: goc.id, cursor: cursor, limit: 50)) else { break }
            gom = BinhLuanLogic.noi(gom, t.comments ?? [])
            cursor = t.nextCursor
            if cursor == nil { break }
        }
        if let i = ds.firstIndex(where: { $0.id == goc.id }) {
            ds[i].replies = gom
            ds[i].replyCount = max(ds[i].replyCount ?? 0, gom.count)
        }
    }

    private func nhanSuKien(_ e: SuKienBangTinCTW) async {
        if let n = e.commentCount { suaBai { $0.commentCount = n } }
        switch e.type {
        case "comment.deleted":
            if let cid = e.commentId { ds = BinhLuanLogic.xoa(ds, id: cid).0 }
        default:
            if let cha = e.parentId, let g = ds.first(where: { $0.id == cha }) { await taiTraLoi(g); return }
            // Gốc mới/sửa: tải lại các trang đã có (gộp, giữ vị trí).
            if let t: CTWFeedTrangBinhLuan = try? await APIClient.shared.request(CTWAPI.binhLuanBai(postId, cha: nil, cursor: nil, limit: 50)) {
                ds = BinhLuanLogic.noi(ds, t.comments ?? [])
            }
        }
    }

    private func suaBai(_ f: (inout CTWFeedPost) -> Void) {
        guard var b = bai else { return }
        f(&b)
        bai = b
        KhoBangTinCTW.shared.baiDoi.send(b)
    }

    // MARK: Gửi / sửa / xoá

    func gui(_ chu: String, cha: CTWFeedComment?) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        dangGui = true
        defer { dangGui = false }
        do {
            let c: CTWFeedComment = try await APIClient.shared.request(
                CTWAPI.guiBinhLuan(postId, chu: s, cha: cha.map { $0.parentId ?? $0.id }, khoa: TrangBangTin.khoaMoi()))
            ds = c.parentId == nil ? BinhLuanLogic.noi(ds, [c]) : BinhLuanLogic.themTraLoi(ds, c)
            suaBai { b in
                b.commentCount = (b.commentCount ?? 0) + 1
                if c.parentId == nil { b.comments = Array(((b.comments ?? []) + [c]).suffix(2)) }
            }
            CTWRung.chon()
            loiChan = nil
            return true
        } catch where CTWLoiDich.laNoiDungBiChan(error) {
            CTWRung.loi()
            loiChan = BangTinLoi.chu(error)
            return false
        } catch {
            CTWRung.loi()
            bang = BangTinLoi.chu(error)
            return false
        }
    }

    func sua(_ c: CTWFeedComment, _ chu: String) async -> Bool {
        do {
            let m: CTWFeedComment = try await APIClient.shared.request(CTWAPI.suaBinhLuanBai(c.id, chu: chu))
            ds = BinhLuanLogic.thay(ds, m)
            loiChan = nil
            return true
        } catch where CTWLoiDich.laNoiDungBiChan(error) {
            CTWRung.loi()
            loiChan = BangTinLoi.chu(error)
            return false
        } catch {
            bang = BangTinLoi.chu(error)
            return false
        }
    }

    func xoa(_ c: CTWFeedComment) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaBinhLuanBai(c.id))
            let (moi, bot) = BinhLuanLogic.xoa(ds, id: c.id)
            ds = moi
            suaBai { b in
                b.commentCount = max(0, (b.commentCount ?? 0) - bot)
                b.comments = b.comments?.filter { $0.id != c.id }
            }
        } catch { bang = BangTinLoi.chu(error) }
    }

    func doiGo(_ c: CTWFeedComment) async {
        do {
            let m: CTWFeedComment = try await APIClient.shared.request(CTWAPI.goBinhLuan(c.id, !(c.hidden ?? false)))
            ds = BinhLuanLogic.thay(ds, m)
        } catch { bang = BangTinLoi.chu(error) }
    }

    func camXuc(_ c: CTWFeedComment, _ k: CamXucBangTin?) {
        let cu = TrangThaiCamXuc(c)
        let moi = CamXucLogic.ap(cu, chon: k)
        ds = BinhLuanLogic.thay(ds, c.voi(moi))
        Task {
            do {
                let r: CTWFeedKetQuaCamXuc = try await APIClient.shared.request(
                    CTWAPI.camXucBinhLuan(c.id, moi.cuaToi.flatMap(CamXucBangTin.init(rawValue:))))
                ds = BinhLuanLogic.thay(ds, c.voi(TrangThaiCamXuc(tong: r.reactionCount ?? moi.tong, ds: r.reactions ?? moi.ds, cuaToi: r.myReaction)))
            } catch {
                ds = BinhLuanLogic.thay(ds, c.voi(cu))
                CTWRung.loi()
            }
        }
    }

    func daBaoCao(_ c: CTWFeedComment) {
        var m = c
        m.reportedByMe = true
        ds = BinhLuanLogic.thay(ds, m)
    }

    // MARK: @nhắc

    func timNhac(_ q: String?) {
        timNhacTask?.cancel()
        guard let q, let ws = bai?.workspace?.id else { goiY = []; return }
        let pid = bai?.project?.id
        timNhacTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            let r: CTWFeedNguoiNhac? = try? await APIClient.shared.request(CTWAPI.bangTinNguoiNhac(ws: ws, pid: pid, q: q))
            guard !Task.isCancelled else { return }
            goiY = (r?.users ?? []).filter { $0.id != toi && !$0.laAgent }
        }
    }
}

/// Tấm phủ bình luận (từ bảng tin).
struct BinhLuanBaiCTW: View {
    @StateObject private var vm: BinhLuanVM
    var moURL: (URL) -> Void
    @Environment(\.dismiss) private var dong

    init(post: CTWFeedPost, moURL: @escaping (URL) -> Void) {
        _vm = StateObject(wrappedValue: BinhLuanVM(postId: post.id, bai: post))
        self.moURL = moURL
    }

    var body: some View {
        NavigationStack {
            KhungBinhLuanCTW(vm: vm, nhung: false, moURL: moURL)
                .navigationTitle(tieuDe)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var tieuDe: String {
        let n = vm.bai?.commentCount ?? vm.ds.count
        return n == 0 ? String(localized: "Comments") : (n == 1 ? String(localized: "1 comment") : String(localized: "\(n) comments"))
    }
}

/// Danh sách bình luận + ô soạn (dùng ở tấm phủ và màn chi tiết bài).
struct KhungBinhLuanCTW: View {
    @ObservedObject var vm: BinhLuanVM
    /// Nhúng trong màn chi tiết: thẻ bài nằm trên đầu danh sách (`dau`).
    var nhung: Bool
    var dau: AnyView? = nil
    var cuonToi: Int? = nil
    var moURL: (URL) -> Void

    @ObservedObject private var kd = ModerationStore.shared
    @State private var chu = ""
    @State private var traLoi: CTWFeedComment?
    @State private var dangSua: CTWFeedComment?
    @State private var tamPhu: TamPhu?
    @State private var hoiXoa: CTWFeedComment?
    @State private var hoiChan: CTWUser?
    @State private var sang: Int?
    @FocusState private var dangGo: Bool

    enum TamPhu: Identifiable {
        case baoCao(CTWFeedComment), hoSo(Int)
        var id: String {
            switch self { case .baoCao(let c): return "bc\(c.id)"; case .hoSo(let i): return "hs\(i)" }
        }
    }

    private var tatBinhLuan: Bool { vm.bai?.can?.comment == false }

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let dau { dau }
                    if vm.dangTai && vm.ds.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in hangGiuCho }
                    } else if let l = vm.loi {
                        CTWOLoi(loi: l) { Task { await vm.tai() } }
                    } else if vm.daTai && vm.ds.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right").font(.ctw(size: 26)).foregroundColor(AppColors.primary)
                            Text("No comments yet").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            Text(tatBinhLuan ? "Comments are turned off for this post." : "Start the conversation.")
                                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 28)
                    }
                    ForEach(vm.ds) { c in
                        hang(c, traLoiCua: nil).id(c.id)
                        ForEach(c.replies ?? []) { r in hang(r, traLoiCua: c).id(r.id).padding(.leading, 44) }
                        let conLai = (c.replyCount ?? 0) - (c.replies ?? []).count
                        if conLai > 0 {
                            Button { Task { await vm.taiTraLoi(c) } } label: {
                                Label(conLai == 1 ? String(localized: "View 1 more reply") : String(localized: "View \(conLai) more replies"),
                                      systemImage: "arrow.turn.down.right")
                                    .font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                    .frame(minHeight: 32)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 44)
                        }
                    }
                    if vm.con != nil {
                        Button { Task { await vm.taiThem() } } label: {
                            Text("Load more comments").font(.ctw(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain).foregroundColor(AppColors.primary)
                    }
                    Color.clear.frame(height: 4).id("cuoi")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .task(id: vm.daTai) {
                guard vm.daTai, let id = cuonToi else { return }
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation { cuon.scrollTo(id, anchor: .center) }
                sang = id
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(.easeOut(duration: 0.6)) { sang = nil }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { oSoan }
        .background(AppColors.backgroundPrimary)
        .task { if !vm.daTai { await vm.tai() } }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .baoCao(let c):
                BaoCaoBangTinCTW(dich: .binhLuan(c.id), tacGia: c.author) { vm.daBaoCao(c) }
            case .hoSo(let id): NavigationStack { HoSoThanhVienCTW(userId: id, laTamPhu: true) }
            }
        }
        .confirmationDialog("Delete this comment?", isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let c = hoiXoa { Task { await vm.xoa(c) } } }
        } message: { Text("Replies to it are deleted too.") }
        .confirmationDialog(Text("Block \(hoiChan?.ten ?? "")?"), isPresented: Binding(get: { hoiChan != nil }, set: { if !$0 { hoiChan = nil } }), titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                if let u = hoiChan { Task { try? await ModerationStore.shared.block(userId: u.id); CTWRung.thanhCong() } }
            }
        } message: { Text("You won't see their posts, and their comments will be collapsed. They won't be told.") }
        .alert(vm.bang ?? "", isPresented: Binding(get: { vm.bang != nil }, set: { if !$0 { vm.bang = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: chu) { _, m in vm.timNhac(NhacDangGo.dangGo(m)) }
    }

    private var hangGiuCho: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).frame(width: 110, height: 11)
                RoundedRectangle(cornerRadius: 4).frame(height: 11)
                RoundedRectangle(cornerRadius: 4).frame(width: 180, height: 11)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.backgroundSecondary))
        }
        .foregroundColor(AppColors.backgroundTertiary)
        .anhLuot()
    }

    // MARK: Một bình luận

    @ViewBuilder private func hang(_ c: CTWFeedComment, traLoiCua goc: CTWFeedComment?) -> some View {
        let chan = c.hiddenForMe == true || c.authorBlocked == true || (c.author.map { kd.blockedUserIds.contains($0.id) } ?? false)
        if chan {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill").foregroundColor(AppColors.textTertiary)
                Text("Comment from someone you blocked").italic().foregroundColor(AppColors.textTertiary)
            }
            .font(.ctw(size: 13))
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        } else if c.reportedByMe == true {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill").foregroundColor(AppColors.textTertiary)
                Text("You reported this comment. It's hidden for you.").italic().foregroundColor(AppColors.textTertiary)
            }
            .font(.ctw(size: 13)).padding(.vertical, 6)
        } else {
            let cuaToi = c.author?.id != nil && c.author?.id == vm.toi
            HStack(alignment: .top, spacing: 10) {
                Button { if let a = c.author { tamPhu = .hoSo(a.id) } } label: { CTWAvatar(user: c.author, size: goc == nil ? 34 : 28) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(c.author?.ten ?? ""))
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(c.author?.ten ?? String(localized: "Someone")).font(.ctw(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            if c.author?.laAgent == true { CTWNhanAI() }
                        }
                        if c.hidden == true {
                            Text("Removed by an admin").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.warning)
                        }
                        Text(ChuBangTin.dung(c.body ?? "", nhac: c.mentions ?? [], maDuAn: vm.bai?.project?.key, slug: vm.bai?.workspace?.slug))
                            .font(.ctw(size: 14))
                            .foregroundColor(AppColors.textPrimary)
                            .tint(AppColors.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .environment(\.openURL, OpenURLAction { u in moLienKet(u); return .handled })
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(sang == c.id ? AppColors.primary.opacity(0.18) : AppColors.backgroundSecondary))
                    .overlay(alignment: .bottomTrailing) {
                        let cx = TrangThaiCamXuc(c)
                        if cx.tong > 0 {
                            HStack(spacing: 2) {
                                ForEach(CamXucLogic.baDau(cx)) { Text($0.emoji).font(.ctw(size: 11)) }
                                Text(verbatim: "\(cx.tong)").font(.ctw(size: 11).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.backgroundCard).shadow(color: .black.opacity(0.12), radius: 2, y: 1))
                            .offset(x: 8, y: 10)
                            .accessibilityLabel(Text(cx.tong == 1 ? String(localized: "1 reaction") : String(localized: "\(cx.tong) reactions")))
                        }
                    }
                    .contextMenu { menu(c, cuaToi: cuaToi, goc: goc) }
                    HStack(spacing: 14) {
                        Text(ThoiGianBangTin.nhan(c.createdAt))
                        if c.editedAt != nil { Text("Edited") }
                        NutCamXucCTW(trangThai: TrangThaiCamXuc(c), choPhep: true, nho: true) { vm.camXuc(c, $0) }
                        if c.can?.reply != false && !tatBinhLuan {
                            Button("Reply") { batDauTraLoi(c, goc: goc) }
                                .font(.ctw(size: 12, weight: .semibold))
                                .frame(minHeight: 30)
                                .accessibilityIdentifier("feed.comment.reply")
                        }
                    }
                    .font(.ctw(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.leading, 8)
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("feed.comment.\(c.id)")
        }
    }

    @ViewBuilder private func menu(_ c: CTWFeedComment, cuaToi: Bool, goc: CTWFeedComment?) -> some View {
        Button { CTW.chepVaoBoNho(ChuBangTin.thuan(c.body ?? "")) } label: { Label("Copy text", systemImage: "doc.on.doc") }
        if !tatBinhLuan && c.can?.reply != false {
            Button { batDauTraLoi(c, goc: goc) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
        }
        if cuaToi && c.can?.edit != false {
            Button { dangSua = c; traLoi = nil; chu = c.body ?? ""; dangGo = true } label: { Label("Edit", systemImage: "pencil") }
        }
        if c.can?.moderate == true && !cuaToi {
            Button { Task { await vm.doiGo(c) } } label: {
                c.hidden == true ? Label("Restore comment", systemImage: "eye") : Label("Remove for everyone", systemImage: "eye.slash")
            }
        }
        if c.can?.delete == true || cuaToi {
            Button(role: .destructive) { hoiXoa = c } label: { Label("Delete", systemImage: "trash") }
        }
        if !cuaToi {
            Button(role: .destructive) { tamPhu = .baoCao(c) } label: { Label("Report comment", systemImage: "flag") }
            if let a = c.author, !a.laAgent {
                Button(role: .destructive) { hoiChan = a } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
            }
        }
    }

    private func batDauTraLoi(_ c: CTWFeedComment, goc: CTWFeedComment?) {
        dangSua = nil
        traLoi = c
        if let u = c.author?.username, c.author?.id != vm.toi, !chu.contains("@\(u)") { chu = "@\(u) " + chu }
        dangGo = true
    }

    private func moLienKet(_ u: URL) {
        if u.scheme == ChuBangTin.luocDo, u.host == "nguoi", let id = Int(u.lastPathComponent) { tamPhu = .hoSo(id); return }
        moURL(u)
    }

    // MARK: Ô soạn

    @ViewBuilder private var oSoan: some View {
        VStack(spacing: 0) {
            Divider()
            if tatBinhLuan {
                Label("Comments are turned off for this post.", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity).padding(14)
            } else {
                if !vm.goiY.isEmpty && NhacDangGo.dangGo(chu) != nil { goiYNhac }
                if let l = vm.loiChan {
                    CTWErrorBanner(text: l) { vm.loiChan = nil }
                        .accessibilityIdentifier("ctw.noiDungBiChan")
                        .padding(.horizontal, 12).padding(.top, 8)
                }
                if let r = traLoi ?? dangSua {
                    HStack(spacing: 6) {
                        Image(systemName: dangSua != nil ? "pencil" : "arrowshape.turn.up.left").font(.ctw(size: 11, weight: .bold))
                        Text(dangSua != nil ? String(localized: "Editing your comment") : String(localized: "Replying to \(r.author?.tenNgan ?? "")"))
                            .font(.ctw(size: 12, weight: .semibold))
                        Spacer()
                        Button { traLoi = nil; if dangSua != nil { dangSua = nil; chu = "" } } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary).frame(width: 30, height: 30)
                        }
                        .accessibilityLabel(Text("Cancel"))
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 14).padding(.top, 6)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    CTWAvatar(user: AppState.shared.currentUser?.nguoiBangTin, size: 30)
                        .padding(.bottom, 6)
                    TextField(traLoi != nil ? "Write a reply…" : "Write a comment…", text: $chu, axis: .vertical)
                        .lineLimit(1...6)
                        .focused($dangGo)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppColors.backgroundSecondary))
                        .accessibilityIdentifier("feed.comment.field")
                    Button { Task { await gui() } } label: {
                        Group {
                            if vm.dangGui { ProgressView() } else { Image(systemName: "paperplane.fill").font(.ctw(size: 19)) }
                        }
                        .foregroundColor(coChu ? AppColors.primary : AppColors.textTertiary)
                        .frame(width: 44, height: 44)
                    }
                    .disabled(!coChu || vm.dangGui)
                    .accessibilityLabel(Text("Send"))
                    .accessibilityIdentifier("feed.comment.send")
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .background(AppColors.backgroundCard)
    }

    private var goiYNhac: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.goiY.prefix(8)) { u in
                    Button { chu = NhacDangGo.chen(chu, username: u.username ?? ""); vm.timNhac(nil) } label: {
                        HStack(spacing: 6) {
                            CTWAvatar(user: u, size: 22)
                            Text(u.ten).font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textPrimary).fixedSize()
                            if let n = u.username { Text(verbatim: "@\(n)").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary).fixedSize() }
                        }
                        .padding(.horizontal, 10).frame(minHeight: 36)
                        .background(Capsule().fill(AppColors.backgroundSecondary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feed.mention.\(u.username ?? "")")
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)
        }
    }

    private var coChu: Bool { !chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func gui() async {
        let s = chu
        if let c = dangSua {
            if await vm.sua(c, s) { chu = ""; dangSua = nil; dangGo = false }
            return
        }
        let r = traLoi
        chu = ""; traLoi = nil
        if !(await vm.gui(s, cha: r)) { chu = s; traLoi = r }
    }
}

// MARK: - Ai đã bày tỏ cảm xúc

struct AiThaCamXucCTW: View {
    let post: CTWFeedPost
    @Environment(\.dismiss) private var dong
    @State private var loai: String?
    @State private var ds: [CTWFeedNguoiThaCamXuc.Muc] = []
    @State private var tong: [CTWFeedDemCamXuc] = []
    @State private var con: String?
    @State private var dangTai = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(nil, Text("All \(CTWDinhDang.so((tong.isEmpty ? post.reactions ?? [] : tong).reduce(0) { $0 + ($1.count ?? 0) }))"))
                        ForEach(tong.isEmpty ? (post.reactions ?? []) : tong, id: \.kind) { r in
                            chip(r.kind, Text(verbatim: "\(CamXucBangTin(rawValue: r.kind)?.emoji ?? "") \(r.count ?? 0)"))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                Divider()
                List {
                    if let loi { CTWErrorBanner(text: loi) }
                    ForEach(Array(ds.enumerated()), id: \.offset) { _, m in
                        HStack(spacing: 12) {
                            CTWAvatar(user: m.user, size: 38)
                                .overlay(alignment: .bottomTrailing) {
                                    Text(CamXucBangTin(rawValue: m.kind ?? "")?.emoji ?? "").font(.ctw(size: 13)).offset(x: 4, y: 4)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.user?.ten ?? "").font(.ctw(size: 15, weight: .medium))
                                if let u = m.user?.username { Text(verbatim: "@\(u)").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(Text(CamXucBangTin(rawValue: m.kind ?? "")?.ten ?? ""))
                        .onAppear { if m == ds.last { Task { await taiThem() } } }
                    }
                    if dangTai { ProgressView().frame(maxWidth: .infinity) }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
            .task(id: loai) { await tai() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func chip(_ k: String?, _ chu: Text) -> some View {
        Button { loai = k } label: {
            chu.font(.ctw(size: 14, weight: .semibold))
                .foregroundColor(loai == k ? AppColors.onPrimary : AppColors.textPrimary)
                .padding(.horizontal, 12).frame(minHeight: 34)
                .background(Capsule().fill(loai == k ? AppColors.primary : AppColors.backgroundSecondary))
                .fixedSize()
        }
        .buttonStyle(.plain)
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            let r: CTWFeedNguoiThaCamXuc = try await APIClient.shared.request(CTWAPI.nguoiThaCamXuc(post.id, kind: loai, cursor: nil))
            ds = r.items ?? []
            if let t = r.reactions, !t.isEmpty { tong = t }
            con = r.nextCursor
            loi = nil
        } catch { loi = BangTinLoi.chu(error) }
    }

    private func taiThem() async {
        guard let c = con, !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        if let r: CTWFeedNguoiThaCamXuc = try? await APIClient.shared.request(CTWAPI.nguoiThaCamXuc(post.id, kind: loai, cursor: c)) {
            ds += r.items ?? []
            con = r.nextCursor
        }
    }
}
