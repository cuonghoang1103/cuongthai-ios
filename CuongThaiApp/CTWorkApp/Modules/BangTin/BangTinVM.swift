import Foundation
import Combine
import SwiftUI

// MARK: - VM một bảng tin (gộp · không gian · dự án · hashtag)
//
// Trang theo con trỏ mờ `nextCursor` (`GET /feed`), mục ghim riêng ở trang đầu khi lọc MỘT phạm vi. Thời gian thực:
// socket `work:feed:event` (KHÔNG mang nội dung — tải lại qua REST, REST lọc quyền); mất socket ⇒ hỏi
// `/feed/new-count` mỗi 60 s khi màn đang hiện. Thao tác người dùng (cảm xúc, lưu, ghim…) áp LẠC QUAN rồi chốt
// theo máy chủ; hỏng ⇒ trả lại + rung lỗi.

@MainActor
final class BangTinVM: ObservableObject {
    @Published var loc: LocBangTin
    @Published private(set) var bai: [CTWFeedPost] = []
    @Published private(set) var ghim: [CTWFeedPost] = []
    @Published private(set) var con: String?
    @Published private(set) var dangTai = false
    @Published private(set) var dangTaiThem = false
    @Published private(set) var daTai = false
    @Published var loi: String?
    /// Viên "N bài mới".
    @Published private(set) var soMoi = 0
    /// Băng nhỏ ở đáy (ẩn bài + Hoàn tác, lỗi nhanh).
    @Published var bang: BangNho?

    struct BangNho: Identifiable, Equatable {
        let id = UUID()
        var chu: String
        var hoanTac: Int?
    }

    private var huy = Set<AnyCancellable>()
    private var mocMoi = Date()
    private var dangHien = false
    private var hen: Task<Void, Never>?
    private var taiLaiBai: [Int: Task<Void, Never>] = [:]
    private var toi: Int? { AppState.shared.currentUser?.id }
    /// Màn chi tiết: chỉ một bài — bỏ qua bài mới (socket / ô soạn).
    private var chiMot = false

    init(loc: LocBangTin) {
        self.loc = loc
        let kho = KhoBangTinCTW.shared
        kho.baiDoi.sink { [weak self] p in self?.thay(p) }.store(in: &huy)
        kho.baiMat.sink { [weak self] id in self?.bo(id) }.store(in: &huy)
        kho.dangBai.sink { [weak self] e in self?.nhanDang(e) }.store(in: &huy)
        RealtimeCTW.shared.suKienBangTin.sink { [weak self] e in self?.nhanSocket(e) }.store(in: &huy)
        ModerationStore.shared.$blockedUserIds.dropFirst().sink { [weak self] chan in
            guard let self else { return }
            bai = TrangBangTin.loc(bai, daChan: chan, daAn: [])
            ghim = TrangBangTin.loc(ghim, daChan: chan, daAn: [])
        }.store(in: &huy)
    }

    var trong: Bool { daTai && bai.isEmpty && ghim.isEmpty }

    /// Màn chi tiết: VM chỉ giữ MỘT bài (không tải danh sách) — dùng lại mọi thao tác của thẻ.
    func datMot(_ p: CTWFeedPost) {
        chiMot = true
        bai = [p]; ghim = []; con = nil; daTai = true
    }

    // MARK: Tải

    func tai() async {
        guard !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        do {
            let t: CTWFeedTrang = try await APIClient.shared.request(CTWAPI.bangTin(loc, cursor: nil))
            let kho = KhoBangTinCTW.shared
            let chan = ModerationStore.shared.blockedUserIds
            ghim = TrangBangTin.loc(loc.coMucGhim ? (t.pinned ?? []) : [], daChan: chan, daAn: kho.daAn)
            bai = TrangBangTin.loc(TrangBangTin.lamMoi(bai, dau: t.posts ?? []), daChan: chan, daAn: kho.daAn)
            // Bài ghim KHÔNG lặp trong `posts` (hợp đồng) — phòng máy chủ lệch: bỏ bản trùng.
            let idGhim = Set(ghim.map(\.id))
            bai.removeAll { idGhim.contains($0.id) }
            con = t.nextCursor
            loi = nil
            soMoi = 0
            mocMoi = Date()
        } catch {
            if bai.isEmpty && ghim.isEmpty { loi = BangTinLoi.chu(error) }
            else { bang = BangNho(chu: BangTinLoi.chu(error)) }
        }
        daTai = true
    }

    func taiThem() async {
        guard let c = con, !dangTaiThem, !dangTai else { return }
        dangTaiThem = true
        defer { dangTaiThem = false }
        do {
            let t: CTWFeedTrang = try await APIClient.shared.request(CTWAPI.bangTin(loc, cursor: c))
            let chan = ModerationStore.shared.blockedUserIds
            bai = TrangBangTin.loc(TrangBangTin.noi(bai, t.posts ?? []), daChan: chan, daAn: KhoBangTinCTW.shared.daAn)
            con = t.nextCursor
        } catch {
            bang = BangNho(chu: BangTinLoi.chu(error))
        }
    }

    func doiLoc(_ l: LocBangTin) async {
        guard l != loc else { return }
        loc = l
        bai = []; ghim = []; con = nil; daTai = false; loi = nil
        await tai()
    }

    /// Màn hiện/khuất — bật/tắt hỏi định kỳ khi mất socket.
    func hien(_ b: Bool) {
        dangHien = b
        hen?.cancel()
        guard b else { return }
        hen = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if !RealtimeCTW.shared.daNoi { await self.hoiBaiMoi() }
            }
        }
    }

    func hoiBaiMoi() async {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let r: CTWFeedDemMoi = try? await APIClient.shared.request(CTWAPI.bangTinDemMoi(since: f.string(from: mocMoi), ws: loc.ws, pid: loc.pid)) {
            soMoi = max(soMoi, r.count ?? 0)
        }
    }

    // MARK: Thời gian thực

    private func nhanSocket(_ e: SuKienBangTinCTW) {
        switch e.type {
        case "post.created":
            guard !chiMot, e.actorId != toi, loc.thuoc(ws: e.workspaceId, pid: e.projectId), !bai.contains(where: { $0.id == e.postId }) else { return }
            // Lọc "của tôi"/"đã lưu"/"có tệp" ⇒ bài người khác vừa đăng không thuộc ⇒ không báo.
            guard loc.kieu == .all || loc.kieu == .media else { return }
            soMoi += 1
        case "post.deleted":
            bo(e.postId)
        case "post.updated", "reaction", "poll":
            if coBai(e.postId) { henTaiLai(e.postId, e.type == "post.updated" ? 0 : 0.6) }
        case "comment.created", "comment.deleted", "comment.updated":
            if let n = e.commentCount { suaBai(e.postId) { $0.commentCount = n } }
            if e.type != "comment.updated", coBai(e.postId) { henTaiLai(e.postId, 0.8) }
        default: break
        }
    }

    private func coBai(_ id: Int) -> Bool { bai.contains { $0.id == id } || ghim.contains { $0.id == id } }

    /// Gộp nhiều sự kiện liên tiếp của một bài thành MỘT lần `GET /feed/posts/:id`.
    private func henTaiLai(_ id: Int, _ tre: Double) {
        taiLaiBai[id]?.cancel()
        taiLaiBai[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(tre * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.taiLaiMot(id)
        }
    }

    func taiLaiMot(_ id: Int) async {
        do {
            let p: CTWFeedPost = try await APIClient.shared.request(CTWAPI.bai(id))
            thay(p)
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "NOT_FOUND" { bo(id) }
        }
    }

    // MARK: Đăng (từ ô soạn)

    private func nhanDang(_ e: SuKienDangBaiCTW) {
        guard !chiMot else { return }
        switch e {
        case .batDau(let tam):
            guard loc.thuoc(ws: tam.workspace?.id, pid: tam.project?.id), loc.kieu == .all || loc.kieu == .mine
                    || (loc.kieu == .media && !tam.anhVaVideo.isEmpty) else { return }
            bai = TrangBangTin.chenTam(bai, tam)
        case .xong(let khoa, let p):
            guard bai.contains(where: { $0.khoaTam == khoa }) else { return }
            bai = TrangBangTin.thayTam(bai, khoa: khoa, bang: p)
        case .hong(let khoa, let loi):
            guard bai.contains(where: { $0.khoaTam == khoa }) else { return }
            bai = TrangBangTin.danhDauHong(bai, khoa: khoa)
            bang = BangNho(chu: loi)
        case .bo(let khoa):
            bai = TrangBangTin.boTam(bai, khoa: khoa)
        }
    }

    // MARK: Sửa tại chỗ

    func thay(_ p: CTWFeedPost) {
        if let i = bai.firstIndex(where: { $0.id == p.id }) { bai[i] = p }
        if let i = ghim.firstIndex(where: { $0.id == p.id }) {
            // Bỏ ghim ⇒ về dòng thời gian.
            if p.pinned == true { ghim[i] = p } else { ghim.remove(at: i); if !bai.contains(where: { $0.id == p.id }) { bai = TrangBangTin.noi([p], bai).sortedTheoThoiGian() } }
        } else if p.pinned == true, loc.coMucGhim, bai.contains(where: { $0.id == p.id }) {
            bai.removeAll { $0.id == p.id }
            ghim.insert(p, at: 0)
        }
        if p.hidden == true, p.can?.moderate != true, p.author?.id != toi { bo(p.id) }
    }

    private func suaBai(_ id: Int, _ f: (inout CTWFeedPost) -> Void) {
        if let i = bai.firstIndex(where: { $0.id == id }) { f(&bai[i]) }
        if let i = ghim.firstIndex(where: { $0.id == id }) { f(&ghim[i]) }
    }

    func baiTheoId(_ id: Int) -> CTWFeedPost? { bai.first { $0.id == id } ?? ghim.first { $0.id == id } }

    private func bo(_ id: Int) {
        bai.removeAll { $0.id == id }
        ghim.removeAll { $0.id == id }
    }

    // MARK: Thao tác

    func thaCamXuc(_ p: CTWFeedPost, _ k: CamXucBangTin?) {
        let cu = TrangThaiCamXuc(p)
        let moi = CamXucLogic.ap(cu, chon: k)
        thay(p.voi(moi))
        let gui: CamXucBangTin? = moi.cuaToi.flatMap(CamXucBangTin.init(rawValue:))
        Task {
            do {
                let r: CTWFeedKetQuaCamXuc = try await APIClient.shared.request(CTWAPI.camXucBai(p.id, gui))
                if var b = baiTheoId(p.id) {
                    b.reactionCount = r.reactionCount; b.reactions = r.reactions; b.myReaction = r.myReaction
                    thay(b); KhoBangTinCTW.shared.baiDoi.send(b)
                }
            } catch {
                if let b = baiTheoId(p.id) { thay(b.voi(cu)) }
                CTWRung.loi()
                bang = BangNho(chu: BangTinLoi.chu(error))
            }
        }
    }

    func luu(_ p: CTWFeedPost) {
        let moi = !(p.saved ?? false)
        suaBai(p.id) { $0.saved = moi }
        CTWRung.chon()
        Task {
            do {
                let r: CTWFeedLuu = try await APIClient.shared.request(CTWAPI.luuBai(p.id, moi))
                suaBai(p.id) { $0.saved = r.saved ?? moi }
                bang = BangNho(chu: moi ? String(localized: "Saved. Find it under Saved in the filter.") : String(localized: "Removed from saved"))
                if !moi, loc.kieu == .saved { bo(p.id) }
            } catch {
                suaBai(p.id) { $0.saved = !moi }
                bang = BangNho(chu: BangTinLoi.chu(error))
            }
        }
    }

    /// Ẩn bài cho riêng tôi (1.2 — lọc) + Hoàn tác.
    func an(_ p: CTWFeedPost) {
        bo(p.id)
        Task {
            do {
                let _: CTWFeedAn = try await APIClient.shared.request(CTWAPI.anBai(p.id, true))
                KhoBangTinCTW.shared.an(p.id)
                bang = BangNho(chu: String(localized: "Post hidden. You won't see it in your feed."), hoanTac: p.id)
            } catch {
                bai = TrangBangTin.noi(bai, [p]).sortedTheoThoiGian()
                bang = BangNho(chu: BangTinLoi.chu(error))
            }
        }
        anTam[p.id] = p
    }

    private var anTam: [Int: CTWFeedPost] = [:]

    /// Bỏ ẩn (màn chi tiết bài đã ẩn).
    func boAn(_ p: CTWFeedPost) async {
        do {
            let _: CTWFeedAn = try await APIClient.shared.request(CTWAPI.anBai(p.id, false))
            suaBai(p.id) { $0.hiddenForMe = false }
            CTWRung.chon()
        } catch { bang = BangNho(chu: BangTinLoi.chu(error)) }
    }

    func hoanTacAn(_ id: Int) {
        guard let p = anTam[id] else { return }
        bang = nil
        Task {
            if (try? await APIClient.shared.request(CTWAPI.anBai(id, false)) as CTWFeedAn) != nil {
                bai = TrangBangTin.noi(bai, [p]).sortedTheoThoiGian()
            }
        }
    }

    func xoa(_ p: CTWFeedPost) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaBai(p.id))
            bo(p.id)
            KhoBangTinCTW.shared.baiMat.send(p.id)
            CTWRung.thanhCong()
            bang = BangNho(chu: String(localized: "Post deleted"))
        } catch {
            CTWRung.loi()
            bang = BangNho(chu: BangTinLoi.chu(error))
        }
    }

    func doiGhim(_ p: CTWFeedPost) async {
        do {
            let r: CTWFeedPost = try await APIClient.shared.request(CTWAPI.ghimBai(p.id, !(p.pinned ?? false)))
            thay(r)
            KhoBangTinCTW.shared.baiDoi.send(r)
            CTWRung.thanhCong()
            bang = BangNho(chu: r.pinned == true ? String(localized: "Pinned to the top of this feed") : String(localized: "Unpinned"))
        } catch {
            CTWRung.loi()
            bang = BangNho(chu: BangTinLoi.chu(error))
        }
    }

    /// Quản trị gỡ / khôi phục (1.2 — phản hồi báo cáo).
    func doiGo(_ p: CTWFeedPost) async {
        do {
            let r: CTWFeedPost = try await APIClient.shared.request(CTWAPI.goBai(p.id, !(p.hidden ?? false)))
            thay(r)
            KhoBangTinCTW.shared.baiDoi.send(r)
            CTWRung.thanhCong()
        } catch {
            CTWRung.loi()
            bang = BangNho(chu: BangTinLoi.chu(error))
        }
    }

    func bauChon(_ p: CTWFeedPost, _ ids: [String]) async {
        do {
            let poll: CTWFeedPoll = try await APIClient.shared.request(CTWAPI.bauChon(p.id, ids))
            suaBai(p.id) { $0.poll = poll }
            if let b = baiTheoId(p.id) { KhoBangTinCTW.shared.baiDoi.send(b) }
            CTWRung.chon()
        } catch {
            CTWRung.loi()
            bang = BangNho(chu: BangTinLoi.chu(error))
        }
    }

    /// Báo cáo xong (tấm phủ báo cáo) ⇒ bài biến khỏi bảng tin của người báo cáo.
    func daBaoCao(_ id: Int) {
        bo(id)
        KhoBangTinCTW.shared.an(id)
        bang = BangNho(chu: String(localized: "Thanks — our moderators will review it within 24 hours. It's hidden for you now."))
    }
}

extension Array where Element == CTWFeedPost {
    /// Bài tạm trước, rồi mới nhất trước (`createdAt desc, id desc` như máy chủ).
    func sortedTheoThoiGian() -> [CTWFeedPost] {
        sorted { a, b in
            if a.laTam != b.laTam { return a.laTam }
            let (x, y) = (a.createdAt ?? "", b.createdAt ?? "")
            return x != y ? x > y : a.id > b.id
        }
    }
}
