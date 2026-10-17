import SwiftUI
import Combine

// MARK: - Chat nhóm của dự án — DANH SÁCH KÊNH
//
// Backend: `work.ctwk3.routes.ts` + `services/work/chat.service.ts`.
//   · `GET /projects/:pid/chat/channels[?archived=1]` ⇒ `{channels, total, me}`
//   · Kênh công khai / khách (`PUBLIC`/`CLIENT`) và NHÓM RIÊNG (`PRIVATE`, có danh sách
//     thành viên) — CT Work không có tin nhắn 1-1 riêng: "nhắn riêng" = nhóm riêng 2 người.
//   · Tạo kênh / nhóm riêng (`me.canCreate`), đánh dấu đã đọc cả dự án, cuộc gọi đang mở.
// Màn một kênh: `KenhChatCTW.swift`. Tin + tệp + voice: `TinChatCTW.swift`.

struct ChatCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var dsKenh: CTWChannelList?
    @State private var loi: String?
    /// MỘT tấm phủ cho cả màn (bẫy C5: hai `.sheet` cùng view ⇒ chỉ cái cuối chạy).
    @State private var tamPhu: TamPhuDS?
    @State private var tim = ""
    @State private var coLuuTru = false

    private func loc(_ ds: [CTWChannel]) -> [CTWChannel] {
        ds.filter { (coLuuTru || $0.archived != true) && (tim.isEmpty || $0.name.localizedCaseInsensitiveContains(tim) || ($0.topic ?? "").localizedCaseInsensitiveContains(tim)) }
            .sorted { a, b in
                if a.isGeneral == true && b.isGeneral != true { return true }
                if b.isGeneral == true && a.isGeneral != true { return false }
                if (a.badge ?? 0 > 0) != (b.badge ?? 0 > 0) { return (a.badge ?? 0) > 0 }
                return (a.lastMessageAt ?? "") > (b.lastMessageAt ?? "")
            }
    }

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if let ds = dsKenh?.channels {
                let tatCa = loc(ds)
                let kenh = tatCa.filter { !$0.laRieng }
                let nhom = tatCa.filter(\.laRieng)
                let dangGoi = tatCa.filter { $0.call != nil }
                if tatCa.isEmpty {
                    CTWOTrong(bieuTuong: "number", tieuDe: tim.isEmpty ? "No channels yet" : "No matching channels",
                              moTa: tim.isEmpty ? "Create a channel to start talking with your team." : "Try another name.",
                              nut: tim.isEmpty && dsKenh?.me?.canCreate == true ? "New channel" : nil) { tamPhu = .tao(false) }
                        .listRowBackground(Color.clear)
                }
                if !dangGoi.isEmpty {
                    Section("Live now") {
                        ForEach(dangGoi) { k in
                            NavigationLink(value: RouteKenhCTW(pid: nguCanh.pid, kenh: k, tenDuAn: nguCanh.tenDuAn)) {
                                Label { Text("Call in \(k.laRieng ? k.name : "#\(k.name)")") } icon: {
                                    Image(systemName: "phone.connection.fill").foregroundColor(AppColors.success)
                                }
                            }
                        }
                    }
                }
                if !kenh.isEmpty {
                    Section { ForEach(kenh) { k in dong(k) } } header: { Text("Channels") }
                }
                if !nhom.isEmpty {
                    Section { ForEach(nhom) { k in dong(k) } } header: { Text("Private groups") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $tim, prompt: "Find a channel")
        .overlay { if dsKenh == nil && loi == nil { CTWKhungTai(soHang: 5) } }
        .refreshable { await tai() }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { tamPhu = .chonDuAn } label: {
                    HStack(spacing: 4) {
                        Text(nguCanh.maDuAn).font(.system(size: 15, weight: .bold).monospaced())
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                }
                .accessibilityLabel("Switch project, current \(nguCanh.tenDuAn)")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if dsKenh?.me?.canCreate == true {
                        Button { tamPhu = .tao(false) } label: { Label("New channel", systemImage: "number") }
                        Button { tamPhu = .tao(true) } label: { Label("New private group", systemImage: "lock") }
                        Divider()
                    }
                    Button { Task { await docTatCa() } } label: { Label("Mark all as read", systemImage: "checkmark.circle") }
                        .disabled((dsKenh?.total ?? 0) == 0)
                    Toggle(isOn: $coLuuTru) { Label("Show archived", systemImage: "archivebox") }
                } label: { Image(systemName: "square.and.pencil") }
                .accessibilityLabel("New conversation and options")
            }
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .chonDuAn: ChonDuAnCTW()
            case .tao(let rieng):
                TaoKenhCTW(pid: nguCanh.pid, rieng: rieng) { k in
                    Task {
                        await tai()
                        if let c = dsKenh?.channels?.first(where: { $0.id == k.id }) {
                            nganXep.duong.append(RouteKenhCTW(pid: nguCanh.pid, kenh: c, tenDuAn: nguCanh.tenDuAn))
                        }
                    }
                }
                .environmentObject(app)
            }
        }
        .onChange(of: coLuuTru) { _, _ in Task { await tai() } }
        .onReceive(RealtimeCTW.shared.suKienChat.filter { [pid = nguCanh.pid] in $0.projectId == pid && $0.type != "reaction" }
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)) { _ in
            Task { await tai() }
        }
        .task {
            if dsKenh == nil { await tai() }
            #if DEBUG
            if XemThuCTW.manGT == "taokenh" { tamPhu = .tao(true) }
            #endif
        }
        .task(id: app.dichCho) { await moDich() }
    }

    enum TamPhuDS: Identifiable {
        case chonDuAn, tao(Bool)
        var id: String {
            switch self {
            case .chonDuAn: return "chon"
            case .tao(let r): return r ? "rieng" : "kenh"
            }
        }
    }

    private func dong(_ k: CTWChannel) -> some View {
        NavigationLink(value: RouteKenhCTW(pid: nguCanh.pid, kenh: k, tenDuAn: nguCanh.tenDuAn)) { HangKenhCTW(kenh: k) }
            .contextMenu {
                Button { Task { await tatTieng(k, k.muted == true ? "off" : "8h") } } label: {
                    Label(k.muted == true ? "Unmute" : "Mute for 8 hours", systemImage: k.muted == true ? "bell" : "bell.slash")
                }
                if (k.badge ?? 0) > 0 {
                    Button { Task { await docKenh(k) } } label: { Label("Mark as read", systemImage: "checkmark.circle") }
                }
            }
            .swipeActions(edge: .leading) {
                if (k.badge ?? 0) > 0 {
                    Button { Task { await docKenh(k) } } label: { Label("Read", systemImage: "checkmark") }.tint(AppColors.primary)
                }
            }
            .swipeActions(edge: .trailing) {
                Button { Task { await tatTieng(k, k.muted == true ? "off" : "8h") } } label: {
                    Label(k.muted == true ? "Unmute" : "Mute", systemImage: k.muted == true ? "bell" : "bell.slash")
                }
                .tint(AppColors.textTertiary)
            }
    }

    private func tai() async {
        do {
            dsKenh = try await APIClient.shared.request(CTWAPI.dsKenh(pid: nguCanh.pid, coLuuTru: coLuuTru))
            loi = nil
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" {
                loi = "Chat is turned off for this project."
            } else {
                loi = CTW.loi(error)
            }
        }
    }

    private func docTatCa() async {
        _ = try? await APIClient.shared.send(CTWAPI.daDocTatCa(pid: nguCanh.pid))
        await tai()
        await app.taiSoChuaDoc()
    }

    private func docKenh(_ k: CTWChannel) async {
        _ = try? await APIClient.shared.send(CTWAPI.daDocKenh(pid: nguCanh.pid, cid: k.id))
        await tai()
        await app.taiSoChuaDoc()
    }

    private func tatTieng(_ k: CTWChannel, _ muc: String) async {
        do {
            let _: CTWKenhBao = try await APIClient.shared.request(CTWAPI.baoKenh(pid: nguCanh.pid, cid: k.id, ["mute": muc]))
            CTWRung.chon()
            await tai()
            await app.taiSoChuaDoc()
        } catch { loi = CTW.loi(error) }
    }

    /// Đích `/work/<ws>/<KEY>/chat?c=<cid>&m=<tin>&t=<chuỗi>` (khung đã chọn đúng dự án trước).
    private func moDich() async {
        guard let d = app.dichCho, d.moDun == "chat", d.pid == nil || d.pid == nguCanh.pid else { return }
        // ⚠️ Xoá cờ ở CUỐI: đổi `dichCho` làm `.task(id:)` HUỶ chính tác vụ này
        // ⇒ mọi `await` sau đó ném CancellationError (đã dính 17/10/2026).
        defer { app.dichCho = nil }
        if dsKenh == nil { await tai() }
        guard let cid = d.duongDan.tham["c"].flatMap(Int.init),
              let k = dsKenh?.channels?.first(where: { $0.id == cid }) else { return }
        var p = NavigationPath()
        p.append(RouteKenhCTW(pid: nguCanh.pid, kenh: k, tenDuAn: nguCanh.tenDuAn,
                              toiTin: d.duongDan.tham["m"].flatMap(Int.init), moChuoi: d.duongDan.tham["t"].flatMap(Int.init)))
        nganXep.duong = p
    }
}

/// Một dòng kênh: biểu tượng loại, tên đậm khi chưa đọc, chủ đề, @, số chưa đọc, tắt tiếng, đang gọi.
struct HangKenhCTW: View {
    let kenh: CTWChannel

    var body: some View {
        let dam = (kenh.badge ?? 0) > 0
        HStack(spacing: 12) {
            Image(systemName: kenh.bieuTuong)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(kenh.archived == true ? AppColors.textTertiary : AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(kenh.archived == true ? 0.05 : 0.12)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(kenh.name).font(.system(size: 15, weight: dam ? .bold : .medium)).foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    if kenh.muted == true { Image(systemName: "bell.slash.fill").font(.system(size: 10)).foregroundColor(AppColors.textTertiary) }
                    if kenh.archived == true { Text("Archived").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
                }
                if let t = kenh.topic, !t.isEmpty {
                    Text(t).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                if let l = kenh.lastMessageAt { Text(CTWChatThoiGian.gio(l)).font(.system(size: 11)).foregroundColor(dam ? AppColors.primary : AppColors.textTertiary) }
                HStack(spacing: 4) {
                    if kenh.call != nil { Image(systemName: "phone.fill").font(.system(size: 11)).foregroundColor(AppColors.success) }
                    if let m = kenh.mentions, m > 0 {
                        Text("@").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .frame(width: 20, height: 20).background(Circle().fill(AppColors.error))
                    }
                    if dam {
                        Text("\(kenh.badge ?? 0)").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(AppColors.primary))
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nhanTroNang)
    }

    private var nhanTroNang: String {
        var s = (kenh.laRieng ? "Private group " : "Channel ") + kenh.name
        if let b = kenh.badge, b > 0 { s += ", \(b) unread" }
        if let m = kenh.mentions, m > 0 { s += ", \(m) mention\(m == 1 ? "" : "s")" }
        if kenh.muted == true { s += ", muted" }
        if kenh.call != nil { s += ", call in progress" }
        return s
    }
}
