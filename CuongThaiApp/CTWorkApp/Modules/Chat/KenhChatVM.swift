import Foundation
import Combine
import SwiftUI

// MARK: - ViewModel của MỘT kênh chat
//
// Nguồn: `GET …/messages?before|around&limit` (cũ→mới, `hasMoreBefore`),
// realtime `work:chat:event` (message/update/delete/reaction/pin) + `work:chat:typing`.
// Gửi chữ đi qua `HangChoGuiCTW` (ngoại tuyến được); gửi kèm tệp gọi thẳng
// (tệp nháp cần mạng để tải lên trước).

@MainActor
final class KenhChatVM: ObservableObject {
    let pid: Int
    @Published var kenh: CTWChannel
    @Published var tin: [CTWChatMessage] = []
    @Published var conCu = false
    @Published var conMoi = false
    @Published var loi: String?
    @Published var dangTai = false
    @Published var dangTaiCu = false
    @Published var daTai = false
    @Published var dangGui = false
    @Published var thanhVien: [CTWChannelMember] = []
    /// Người đang gõ (id ⇒ người + lúc nhận) — tự hết sau 6 giây.
    @Published var dangGo: [Int: (nguoi: CTWUser, luc: Date)] = [:]
    /// Mốc "đã đọc" lúc MỞ kênh — vạch "New messages" đặt trước tin đầu tiên sau mốc.
    @Published var mocDaDoc: Int
    /// Tin cần cuộn tới (deep link `m=`, kết quả tìm, tin ghim).
    @Published var cuonToi: Int?

    private var huy = Set<AnyCancellable>()
    private var lanBaoGo = Date.distantPast
    private var dongHo: Timer?

    init(pid: Int, kenh: CTWChannel) {
        self.pid = pid
        self.kenh = kenh
        mocDaDoc = kenh.lastReadId ?? 0
        RealtimeCTW.shared.suKienChat
            .filter { [pid, cid = kenh.id] in $0.projectId == pid && $0.channelId == cid }
            .sink { [weak self] sk in Task { await self?.nhan(sk) } }
            .store(in: &huy)
        RealtimeCTW.shared.suKienGo
            .filter { [pid, cid = kenh.id] in $0.projectId == pid && $0.channelId == cid && $0.threadId == nil }
            .sink { [weak self] sk in self?.nhanGo(sk) }
            .store(in: &huy)
        HangChoGuiCTW.shared.daGui
            .filter { [pid, cid = kenh.id] in $0.0.pid == pid && $0.0.cid == cid && $0.0.parentId == nil }
            .sink { [weak self] cap in self?.chen(cap.1) }
            .store(in: &huy)
    }

    // MARK: Vòng đời

    func batDau(toiTin: Int? = nil) async {
        RealtimeCTW.shared.vaoKenh(pid: pid, cid: kenh.id)
        dongHo?.invalidate()
        dongHo = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.donGo() }
        }
        if let toiTin { await taiQuanh(toiTin) } else { await tai() }
        await taiThanhVien()
        await HangChoGuiCTW.shared.xa()
    }

    func ketThuc() {
        RealtimeCTW.shared.roiKenh(pid: pid, cid: kenh.id)
        RealtimeCTW.shared.baoDangGo(pid: pid, cid: kenh.id, chuoi: nil, dangGo: false)
        dongHo?.invalidate()
        dongHo = nil
    }

    func tai() async {
        dangTai = true
        defer { dangTai = false; daTai = true }
        do {
            let p: CTWChatPage = try await APIClient.shared.request(CTWAPI.dsTin(pid: pid, cid: kenh.id))
            tin = p.messages ?? []
            conCu = p.hasMoreBefore == true
            conMoi = false
            loi = nil
            await danhDauDaDoc()
        } catch { loi = CTW.loi(error) }
    }

    /// Tải quanh một tin (deep link / tìm kiếm / ghim) rồi cuộn tới nó.
    func taiQuanh(_ mid: Int) async {
        if tin.contains(where: { $0.id == mid }) { cuonToi = mid; return }
        dangTai = true
        defer { dangTai = false; daTai = true }
        do {
            let p: CTWChatPage = try await APIClient.shared.request(CTWAPI.dsTin(pid: pid, cid: kenh.id, quanh: mid))
            tin = p.messages ?? []
            conCu = p.hasMoreBefore == true
            conMoi = p.hasMoreAfter == true
            loi = nil
            cuonToi = mid
            await danhDauDaDoc()
        } catch { loi = CTW.loi(error) }
    }

    /// Cuộn ngược ⇒ tải thêm tin cũ (trước tin đầu đang có).
    func taiCu() async {
        guard conCu, !dangTaiCu, let dau = tin.first?.id else { return }
        dangTaiCu = true
        defer { dangTaiCu = false }
        do {
            let p: CTWChatPage = try await APIClient.shared.request(CTWAPI.dsTin(pid: pid, cid: kenh.id, truoc: dau))
            let co = Set(tin.map(\.id))
            tin = (p.messages ?? []).filter { !co.contains($0.id) } + tin
            conCu = p.hasMoreBefore == true
        } catch { loi = CTW.loi(error) }
    }

    func taiThanhVien() async {
        if let ds: [CTWChannelMember] = try? await APIClient.shared.request(CTWAPI.thanhVienKenh(pid: pid, cid: kenh.id)) {
            thanhVien = ds
        }
    }

    func danhDauDaDoc() async {
        guard let cuoi = tin.last?.id else { return }
        _ = try? await APIClient.shared.send(CTWAPI.daDocKenh(pid: pid, cid: kenh.id, toiTin: cuoi))
        await AppState.shared.taiSoChuaDoc()
    }

    // MARK: Gửi / sửa / xoá

    /// Gửi chữ (+ tệp nháp đã tải lên). Chỉ chữ ⇒ qua hàng chờ (ngoại tuyến được).
    func gui(_ chu: String, tep: [CTWChatFile] = []) async -> Bool {
        let s = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty || !tep.isEmpty else { return false }
        RealtimeCTW.shared.baoDangGo(pid: pid, cid: kenh.id, chuoi: nil, dangGo: false)
        lanBaoGo = .distantPast
        if tep.isEmpty {
            if let m = await HangChoGuiCTW.shared.them(pid: pid, cid: kenh.id, parentId: nil, body: s) { chen(m) }
            CTWRung.chon()
            return true
        }
        dangGui = true
        defer { dangGui = false }
        do {
            let m: CTWChatMessage = try await APIClient.shared.request(
                CTWAPI.guiTin(pid: pid, cid: kenh.id, chu: s, traLoi: nil, khoa: "ios-\(UUID().uuidString.prefix(23))", tep: tep.map(\.id)))
            chen(m)
            loi = nil
            CTWRung.chon()
            return true
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
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
            if (m.replyCount ?? 0) > 0, let i = tin.firstIndex(where: { $0.id == m.id }) {
                tin[i].deleted = true; tin[i].body = ""
            } else {
                tin.removeAll { $0.id == m.id }
            }
        } catch { loi = CTW.loi(error) }
    }

    /// Thả/bỏ cảm xúc — đổi ngay trên màn rồi lấy số thật của máy chủ.
    func camXuc(_ m: CTWChatMessage, _ emoji: String) async {
        guard let i = tin.firstIndex(where: { $0.id == m.id }) else { return }
        var r = tin[i].reactions ?? []
        let bat: Bool
        if let j = r.firstIndex(where: { $0.emoji == emoji }) {
            bat = r[j].mine != true
            r[j].mine = bat
            r[j].count = max(0, (r[j].count ?? 0) + (bat ? 1 : -1))
            if r[j].count == 0 { r.remove(at: j) }
        } else {
            bat = true
            r.append(CTWReaction(emoji: emoji, count: 1, mine: true))
        }
        tin[i].reactions = r
        CTWRung.chon()
        do {
            let kq: CTWReactionKQ = try await APIClient.shared.request(CTWAPI.camXuc(pid: pid, cid: kenh.id, mid: m.id, emoji: emoji, bat: bat))
            if let k = tin.firstIndex(where: { $0.id == m.id }) { tin[k].reactions = kq.reactions ?? [] }
        } catch { loi = CTW.loi(error) }
    }

    func ghim(_ m: CTWChatMessage) async {
        let muon = !m.daGhim
        do {
            let _: CTWPinKQ = try await APIClient.shared.request(CTWAPI.ghimTin(pid: pid, cid: kenh.id, mid: m.id, ghim: muon))
            if let i = tin.firstIndex(where: { $0.id == m.id }) {
                tin[i].pinned = muon ? CTWPinInfo(at: ISO8601DateFormatter().string(from: Date()), byId: AppState.shared.currentUser?.id) : nil
            }
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error) }
    }

    /// "Gọi nhóm" ⇒ url phòng họp (dùng lại cuộc gọi đang mở ≤ 4 giờ).
    func goiNhom() async -> URL? {
        do {
            let kq: CTWCallKQ = try await APIClient.shared.request(CTWAPI.goiNhom(pid: pid, cid: kenh.id))
            if let u = kq.url { kenh.call = CTWCallInfo(url: u, startedAt: ISO8601DateFormatter().string(from: Date())) }
            return kq.url.flatMap(URL.init(string:))
        } catch {
            loi = CTW.loi(error)
            return nil
        }
    }

    // MARK: Đang gõ

    /// Gọi mỗi lần ô nhập đổi — báo "đang gõ" tối đa 1 lần / 3 giây.
    func chuDoi(_ chu: String) {
        if chu.isEmpty {
            if lanBaoGo != .distantPast {
                RealtimeCTW.shared.baoDangGo(pid: pid, cid: kenh.id, chuoi: nil, dangGo: false)
                lanBaoGo = .distantPast
            }
            return
        }
        guard Date().timeIntervalSince(lanBaoGo) > 3 else { return }
        lanBaoGo = Date()
        RealtimeCTW.shared.baoDangGo(pid: pid, cid: kenh.id, chuoi: nil, dangGo: true)
    }

    private func nhanGo(_ sk: SuKienGoCTW) {
        guard let u = sk.user, u.id != AppState.shared.currentUser?.id else { return }
        if sk.dangGo { dangGo[u.id] = (u, Date()) } else { dangGo[u.id] = nil }
    }

    private func donGo() {
        let het = dangGo.filter { Date().timeIntervalSince($0.value.luc) > 6 }.map(\.key)
        for k in het { dangGo[k] = nil }
    }

    var chuDangGo: String? {
        let ten = dangGo.values.sorted { $0.luc < $1.luc }.map(\.nguoi.ten)
        switch ten.count {
        case 0: return nil
        case 1: return String(localized: "\(ten[0]) is typing…")
        case 2: return String(localized: "\(ten[0]) and \(ten[1]) are typing…")
        default: return String(localized: "Several people are typing…")
        }
    }

    // MARK: Realtime

    func chen(_ m: CTWChatMessage) {
        // Trả lời trong chuỗi không nằm ở dòng chính (số trả lời đến qua sự kiện realtime).
        guard m.parentId == nil else { return }
        if let i = tin.firstIndex(where: { $0.id == m.id }) { tin[i] = m } else {
            tin.append(m)
            tin.sort { $0.id < $1.id }
        }
        if let a = m.author?.id { dangGo[a] = nil }
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
            if let id = sk.messageId { tin.removeAll { $0.id == id && ($0.replyCount ?? 0) == 0 } }
        case "channel":
            if let ds: CTWChannelList = try? await APIClient.shared.request(CTWAPI.dsKenh(pid: pid)),
               let k = ds.channels?.first(where: { $0.id == kenh.id }) { kenh = k }
        default:
            break
        }
    }
}

// MARK: - Url ký sẵn của tệp chat (bộ nhớ đệm theo phiên)
//
// Url ký sẵn sống vài phút ⇒ giữ 4 phút rồi xin lại. Một chỗ cho mọi hàng tin
// (ảnh thu nhỏ, voice note, Xem nhanh) — không xin trùng khi cuộn qua lại.

@MainActor
enum UrlTepChatCTW {
    private static var dem: [Int: (url: URL, luc: Date)] = [:]

    static func lay(pid: Int, fid: Int) async throws -> URL {
        if let c = dem[fid], Date().timeIntervalSince(c.luc) < 240 { return c.url }
        let kq: CTWUrlKQ = try await APIClient.shared.request(CTWAPI.urlTepChat(pid: pid, fid: fid))
        guard let s = kq.url, let u = URL(string: s) ?? URL(string: APIClient.diaChiGoc + s) else { throw APIError.noData }
        dem[fid] = (u, Date())
        return u
    }
}
