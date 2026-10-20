import SwiftUI

// MARK: - Hộp thư (thông báo CT Work)
//
// `GET /api/v1/social/notifications?surface=work` — máy chủ chỉ trả `WORK_*` (18/10/2026), nên
// một trang = một trang thật; app vẫn lọc `laCTW` thêm một lớp phòng máy chủ cũ bỏ qua tham số.
// "Read all" = `PATCH {all:true, surface:'work'}` (không đụng thông báo mạng xã hội của app chính).
//
// Hơn bản web: lọc theo loại (chip), GỘP theo thẻ / kênh, trả lời NGAY (bình luận thẻ hoặc
// chuỗi chat), Duyệt / Từ chối yêu cầu phê duyệt ngay trong hộp thư, vuốt để đánh dấu đã đọc.
// 1.2: thông báo của người đã chặn bị ẩn. 3.1.1: payload có lời mời mua ⇒ ẩn.

@MainActor
final class HopThuVM: ObservableObject {
    @Published var ds: [CTWThongBao] = []
    @Published var loi: String?
    @Published var dangTai = false
    @Published var daTai = false
    /// Phê duyệt đã quyết trong phiên này (ẩn nút Duyệt/Từ chối): id thông báo ⇒ đồng ý?
    @Published var daQuyet: [Int: Bool] = [:]
    private var conTro: Int?
    private var conNua = true

    func tai() async {
        conTro = nil
        conNua = true
        ds = []
        await taiThem(toiThieu: 20)
        daTai = true
    }

    /// Tải tới khi có thêm ≥ `toiThieu` thông báo CT Work (tối đa 3 trang/lượt — có `surface=work`
    /// thì thường một trang là đủ).
    func taiThem(toiThieu: Int = 15) async {
        guard conNua, !dangTai else { return }
        dangTai = true
        defer { dangTai = false }
        var them = 0
        var lan = 0
        do {
            while conNua && them < toiThieu && lan < 3 {
                lan += 1
                let r: CTWTrangThongBao = try await APIClient.shared.request(CTWAPI.tbDanhSach(cursor: conTro, limit: 50))
                let co = Set(ds.map(\.id))
                let moi = r.items.filter { $0.laCTW && !co.contains($0.id) }
                ds += moi
                them += moi.count
                conTro = r.pagination?.nextCursor
                conNua = r.pagination?.hasNextPage == true && conTro != nil
            }
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    func danhDauDaDoc(_ ids: [Int]) async {
        guard !ids.isEmpty else { return }
        do {
            try await HanhDongThongBaoCTW.daDoc(ids)
            for i in ds.indices where ids.contains(ds[i].id) { ds[i].isRead = true }
            await AppState.shared.taiSoChuaDoc()
        } catch { loi = CTW.loi(error) }
    }

    /// Đánh dấu đọc MỌI thông báo CT Work (cả những trang chưa tải) bằng một lời gọi.
    func docHet() async {
        do {
            try await APIClient.shared.send(CTWAPI.tbDocHet())
            for i in ds.indices { ds[i].isRead = true }
            CTWRung.chon()
            await AppState.shared.taiSoChuaDoc()
        } catch { loi = CTW.loi(error) }
    }

    func traLoi(_ n: CTWThongBao, _ chu: String) async -> Bool {
        guard let u = n.payload?.url else { return false }
        do {
            try await HanhDongThongBaoCTW.traLoi(duongDan: u, chu: chu)
            CTWRung.thanhCong()
            await danhDauDaDoc([n.id])
            return true
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
            return false
        }
    }

    func pheDuyet(_ n: CTWThongBao, dongY: Bool) async {
        guard let u = n.payload?.url, let aid = n.payload?.approvalId else { return }
        do {
            try await HanhDongThongBaoCTW.pheDuyet(duongDan: u, approvalId: aid, dongY: dongY)
            daQuyet[n.id] = dongY
            CTWRung.thanhCong()
            await danhDauDaDoc([n.id])
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
        }
    }
}

private enum TamPhuHopThu: Identifiable {
    case traLoi(CTWThongBao)
    case caiDat
    var id: String {
        switch self {
        case .traLoi(let n): return "r\(n.id)"
        case .caiDat: return "cd"
        }
    }
}

struct HopThuCTW: View {
    @StateObject private var vm = HopThuVM()
    @ObservedObject private var kd = ModerationStore.shared
    @AppStorage("ctw.hopThu.chiChuaDoc") private var chiChuaDoc = false
    @AppStorage("ctw.hopThu.gop") private var gop = false
    @State private var loai = "all"
    @State private var tamPhu: TamPhuHopThu?
    @State private var hoiDuyet: (CTWThongBao, Bool)?

    private var hien: [CTWThongBao] {
        vm.ds.filter { n in
            if chiChuaDoc && n.isRead { return false }
            if loai != "all" && n.loai != loai { return false }
            if let s = n.sender?.id, kd.blockedUserIds.contains(s) { return false }
            // 3.1.1: máy chủ CHƯA lọc lời mời mua trong payload thông báo — ẩn ở app.
            if CTW.coLoiMoiMua(n.cau) { return false }
            return true
        }
    }

    private var nhom: [(khoa: String, ds: [CTWThongBao])] {
        var ra: [(khoa: String, ds: [CTWThongBao])] = []
        for n in hien {
            if let i = ra.firstIndex(where: { $0.khoa == n.khoaNhom }) { ra[i].ds.append(n) } else { ra.append((n.khoaNhom, [n])) }
        }
        return ra
    }

    var body: some View {
        // Khung (`CotCTW`) đã bọc NavigationStack.
        List {
            if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            Section {
                CTWThanhLoc(chip: chip) { c in CTWRung.chon(); loai = c.id }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            if vm.daTai && hien.isEmpty {
                CTWOTrong(bieuTuong: "bell.slash", tieuDe: chiChuaDoc || loai != "all" ? String(localized: "You're all caught up") : String(localized: "No notifications yet"),
                          moTa: String(localized: "Assignments, mentions, comments, approvals and alerts from your projects appear here."))
                .listRowBackground(Color.clear)
            }
            if gop {
                ForEach(nhom, id: \.khoa) { g in
                    Section {
                        ForEach(g.ds) { n in hang(n) }
                    } header: {
                        HStack {
                            Text(g.khoa).font(.ctw(size: 13, weight: .semibold)).textCase(nil)
                            Spacer()
                            let chua = g.ds.filter { !$0.isRead }
                            if !chua.isEmpty {
                                Button("Mark \(chua.count) read") { Task { await vm.danhDauDaDoc(chua.map(\.id)) } }
                                    .font(.ctw(size: 12, weight: .semibold)).textCase(nil)
                            }
                        }
                    }
                }
            } else {
                Section { ForEach(hien) { n in hang(n) } }
            }
            if vm.dangTai && !vm.ds.isEmpty {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if vm.dangTai && vm.ds.isEmpty { CTWKhungTai() } }
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Show", selection: $chiChuaDoc) {
                        Text("All").tag(false)
                        Text("Unread").tag(true)
                    }
                    Toggle(isOn: $gop) { Label("Group by issue & channel", systemImage: "square.stack") }
                    Divider()
                    Button { tamPhu = .caiDat } label: { Label("Notification settings", systemImage: "gearshape") }
                } label: { Image(systemName: chiChuaDoc || gop ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }
                .accessibilityLabel("Filter and settings")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Read all") {
                    Task { await vm.docHet() }
                }
                .disabled(!vm.ds.contains { !$0.isRead })
            }
        }
        .refreshable { await vm.tai() }
        .task {
            if !vm.daTai { await vm.tai() }
            #if DEBUG
            if XemThuCTW.manGT == "caidattb" { tamPhu = .caiDat }
            if XemThuCTW.manGT == "traloinhanh", let n = vm.ds.first(where: \.traLoiDuoc) { tamPhu = .traLoi(n) }
            #endif
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .traLoi(let n): TraLoiNhanhCTW(tb: n) { chu in await vm.traLoi(n, chu) }
            case .caiDat: NavigationStack { CaiDatThongBaoCTW() }
            }
        }
        .confirmationDialog(hoiDuyet?.1 == true ? "Approve this request?" : "Reject this request?",
                            isPresented: Binding(get: { hoiDuyet != nil }, set: { if !$0 { hoiDuyet = nil } }), titleVisibility: .visible) {
            if let (n, dongY) = hoiDuyet {
                Button(dongY ? "Approve" : "Reject", role: dongY ? nil : .destructive) { Task { await vm.pheDuyet(n, dongY: dongY) } }
            }
        } message: { Text(hoiDuyet?.0.payload?.title ?? "") }
    }

    private var chip: [CTWChipLoc] {
        let ds: [(String, String, String)] = [("all", String(localized: "All"), "tray"), ("mentions", String(localized: "Mentions"), "at"), ("assigned", String(localized: "Assigned"), "person.fill.checkmark"),
                                             ("comments", String(localized: "Replies"), "text.bubble"), ("approvals", String(localized: "Approvals"), "checkmark.seal"), ("alerts", String(localized: "Alerts"), "exclamationmark.circle")]
            // Chip "Code" chỉ khi có thông báo Git (dự án nối GitHub/GitLab) — không làm rối hộp thư của nhóm không dùng.
            + (vm.ds.contains { $0.laGit } ? [("code", String(localized: "Code"), "chevron.left.forwardslash.chevron.right")] : [])
        return ds.map { x in
            let so = x.0 == "all" ? 0 : vm.ds.filter { $0.loai == x.0 && !$0.isRead }.count
            return CTWChipLoc(id: x.0, nhan: so > 0 ? "\(x.1) \(so)" : x.1, bieuTuong: x.2, bat: loai == x.0)
        }
    }

    private func hang(_ n: CTWThongBao) -> some View {
        Button { mo(n) } label: { HangThongBaoCTW(tb: n, daQuyet: vm.daQuyet[n.id]) { a in
            switch a {
            case .traLoi: tamPhu = .traLoi(n)
            case .duyet: hoiDuyet = (n, true)
            case .tuChoi: hoiDuyet = (n, false)
            }
        } }
        .buttonStyle(.plain)
        .onAppear { if n.id == hien.last?.id { Task { await vm.taiThem() } } }
        .swipeActions(edge: .leading) {
            if !n.isRead {
                Button { Task { await vm.danhDauDaDoc([n.id]) } } label: { Label("Read", systemImage: "checkmark") }.tint(AppColors.primary)
            }
        }
        .swipeActions(edge: .trailing) {
            if n.traLoiDuoc {
                Button { tamPhu = .traLoi(n) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }.tint(AppColors.secondary)
            }
        }
        .contextMenu {
            if !n.isRead { Button { Task { await vm.danhDauDaDoc([n.id]) } } label: { Label("Mark as read", systemImage: "checkmark.circle") } }
            if n.traLoiDuoc { Button { tamPhu = .traLoi(n) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") } }
            if let u = n.payload?.url { Button { DinhTuyenCTW.mo(duongDan: u) } label: { Label("Open", systemImage: "arrow.up.forward.app") } }
        }
    }

    private func mo(_ n: CTWThongBao) {
        if !n.isRead { Task { await vm.danhDauDaDoc([n.id]) } }
        if let u = n.payload?.url { DinhTuyenCTW.mo(duongDan: u) }
    }
}

// MARK: - Một thông báo

struct HangThongBaoCTW: View {
    enum HanhDong { case traLoi, duyet, tuChoi }
    let tb: CTWThongBao
    var daQuyet: Bool?
    var bam: (HanhDong) -> Void = { _ in }
    @Environment(\.openURL) private var moURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let u = tb.sender {
                    CTWAvatar(user: u.nguoi, size: 40)
                } else {
                    // Thông báo hệ thống (cảnh báo hạn, tự động hoá) — không có người gửi.
                    Image("LogoCTWork").resizable().scaledToFit().frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityLabel("CT Work")
                }
                Image(systemName: tb.bieuTuong).font(.ctw(size: 10, weight: .bold)).foregroundColor(.white)
                    .frame(width: 20, height: 20).background(Circle().fill(mau))
                    .overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1.5))
                    .offset(x: 4, y: 4)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(tb.sender?.nguoi.ten ?? "CT Work").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    if tb.sender?.kind == "AGENT" { CTWNhanAI() }
                    Spacer(minLength: 0)
                    Text(CTWChatThoiGian.gio(tb.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                Text(tb.cau).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if let t = tb.payload?.title, tb.type != "WORK_ASSIGN" {
                    Text(t).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
                if tb.laPheDuyet {
                    if let q = daQuyet {
                        Label(q ? "You approved" : "You rejected", systemImage: q ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.ctw(size: 12, weight: .semibold)).foregroundColor(q ? AppColors.success : AppColors.error)
                    } else {
                        HStack(spacing: 8) {
                            Button { bam(.duyet) } label: { Label("Approve", systemImage: "checkmark").font(.ctw(size: 13, weight: .semibold)) }
                                .buttonStyle(.borderedProminent).tint(AppColors.success).controlSize(.small)
                            Button { bam(.tuChoi) } label: { Label("Reject", systemImage: "xmark").font(.ctw(size: 13, weight: .semibold)) }
                                .buttonStyle(.bordered).tint(AppColors.error).controlSize(.small)
                        }
                        .padding(.top, 2)
                    }
                } else if let u = tb.linkVaoHop {
                    // Nhắc họp: mở Meet/Zoom/Teams/Jitsi bằng hệ thống (Universal Link vào app của họ).
                    Button { moURL(u) } label: { Label("Join meeting", systemImage: "video.fill").font(.ctw(size: 13, weight: .semibold)) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .padding(.top, 2)
                } else if tb.traLoiDuoc {
                    Button { bam(.traLoi) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left").font(.ctw(size: 13, weight: .semibold)) }
                        .buttonStyle(.bordered).controlSize(.small)
                        .padding(.top, 2)
                }
            }
            if !tb.isRead {
                Circle().fill(AppColors.primary).frame(width: 9, height: 9).padding(.top, 6)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var mau: Color {
        if tb.laPheDuyet { return AppColors.warning }
        switch tb.type {
        case "WORK_ALERT": return AppColors.error
        case "WORK_MENTION": return AppColors.accent
        case "WORK_ASSIGN": return AppColors.success
        default: return AppColors.primary
        }
    }
}

// MARK: - Trả lời nhanh

struct TraLoiNhanhCTW: View {
    let tb: CTWThongBao
    let gui: (String) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chu = ""
    @State private var dangGui = false
    @FocusState private var tieuDiem: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    CTWAvatar(user: tb.sender?.nguoi, size: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(tb.sender?.nguoi.ten ?? "CT Work").font(.ctw(size: 14, weight: .semibold))
                            if tb.sender?.kind == "AGENT" { CTWNhanAI() }
                        }
                        Text(tb.payload?.excerpt ?? tb.payload?.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ctwThe(12)
                Text(tb.laChat ? "Replies in the chat thread \(tb.payload?.issueKey ?? "")." : "Replies on \(tb.payload?.issueKey ?? String(localized: "the issue")) as a threaded comment.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                TextField("Write a reply…", text: $chu, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($tieuDiem)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundCard))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                Spacer()
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            dangGui = true
                            if await gui(chu) { dong() }
                            dangGui = false
                        }
                    }
                    .bold()
                    .disabled(chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dangGui)
                }
            }
            .onAppear { tieuDiem = true }
        }
        .presentationDetents([.medium, .large])
    }
}
