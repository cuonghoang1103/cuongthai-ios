import SwiftUI

// MARK: - Một kênh chat
//
// Danh sách tin cuộn ngược tự tải thêm (chạm đỉnh ⇒ `before`), vạch NGÀY và vạch
// "New messages", "đang gõ…", tin chờ gửi (hàng chờ ngoại tuyến), thanh tin ghim,
// cuộc gọi đang mở (Join). Thanh công cụ: tìm trong kênh · tin ghim · thành viên &
// cài đặt thông báo · gọi nhóm.
// Nội dung người dùng (1.2): báo cáo + ẩn tin + chặn người gửi; tin của người đã chặn
// bị ẩn. Tin của AI agent gắn nhãn "AI agent" (4.7).

/// Route con của mô-đun Chat (đăng ký ở `MoDunChat.swift`).
struct RouteKenhCTW: Hashable {
    var pid: Int
    var kenh: CTWChannel
    var tenDuAn: String
    /// Deep link `m=` (tin cần cuộn tới) / `t=` (chuỗi cần mở).
    var toiTin: Int?
    var moChuoi: Int?
}

enum TamPhuChatCTW: Identifiable {
    case sua(CTWChatMessage)
    case chuoi(CTWChatMessage)
    case thongTin
    case tim
    case ghim
    case chuyenTiep(CTWChatMessage)
    case taoThe(CTWChatMessage)
    case camXuc(CTWChatMessage)
    var id: String {
        switch self {
        case .sua(let m): return "s\(m.id)"
        case .chuoi(let m): return "c\(m.id)"
        case .thongTin: return "info"
        case .tim: return "tim"
        case .ghim: return "ghim"
        case .chuyenTiep(let m): return "f\(m.id)"
        case .taoThe(let m): return "i\(m.id)"
        case .camXuc(let m): return "e\(m.id)"
        }
    }
}

struct KenhChatCTW: View {
    let pid: Int
    let tenDuAn: String
    var toiTin: Int?
    var moChuoiId: Int?
    @StateObject private var vm: KenhChatVM
    @EnvironmentObject private var app: AppState
    @ObservedObject private var kd = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungCTW.shared
    @ObservedObject private var hangCho = HangChoGuiCTW.shared
    @State private var baoCao: CTWChatMessage?
    @State private var hoiChan: CTWUser?
    @State private var hoiXoa: CTWChatMessage?
    @State private var thongBao: String?
    @State private var tamPhu: TamPhuChatCTW?
    @State private var xemNhanh: URL?
    @State private var dangMoTep = false
    @Environment(\.horizontalSizeClass) private var beRong
    @Environment(\.openURL) private var moUrl

    init(pid: Int, kenh: CTWChannel, tenDuAn: String, toiTin: Int? = nil, moChuoi: Int? = nil) {
        self.pid = pid
        self.tenDuAn = tenDuAn
        self.toiTin = toiTin
        self.moChuoiId = moChuoi
        _vm = StateObject(wrappedValue: KenhChatVM(pid: pid, kenh: kenh))
    }

    private var kenh: CTWChannel { vm.kenh }
    private var duocGui: Bool { kenh.canPost != false && kenh.archived != true }

    private var tinHien: [CTWChatMessage] {
        vm.tin.filter { m in
            if an.tinAn.contains(m.id) { return false }
            if let a = m.author?.id, kd.blockedUserIds.contains(a) { return false }
            return !(m.daXoa && (m.replyCount ?? 0) == 0)
        }
    }

    private var hanhDong: HanhDongTinCTW {
        HanhDongTinCTW(
            camXuc: { m, e in Task { await vm.camXuc(m, e) } },
            themCamXuc: { m in tamPhu = .camXuc(m) },
            moChuoi: { m in tamPhu = .chuoi(m) },
            xemTep: { f in moTep(f) },
            moCuocGoi: { u in moCuocGoi(u) })
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.padding(.horizontal, Spacing.md).padding(.top, 6)
            }
            if !hangCho.coMang {
                Label("You're offline — messages will send when you reconnect.", systemImage: "wifi.slash")
                    .font(.ctw(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(AppColors.warning.opacity(0.12))
            }
            if let c = kenh.call, let s = c.url, let u = URL(string: s) { dayCuocGoi(u) }
            danhSach
            if let g = vm.chuDangGo {
                HStack(spacing: 6) {
                    DauGoCTW()
                    Text(g).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md).padding(.vertical, 4)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
            }
            oNhap
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(kenh.laRieng ? kenh.name : "#\(kenh.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { thanhCongCu }
        // Kênh chat cần chỗ cho ô nhập + bàn phím ⇒ ẩn thanh tab (CHỈ iPhone —
        // trong NavigationSplitView của iPad, ẩn tabBar làm mất luôn tiêu đề kênh).
        .toolbar(beRong == .compact ? .hidden : .automatic, for: .tabBar)
        .task {
            await vm.batDau(toiTin: toiTin)
            #if DEBUG
            if XemThuCTW.manGT == "ttkenh" { tamPhu = .thongTin }
            #endif
            if let c = moChuoiId {
                if let goc = vm.tin.first(where: { $0.id == c }) {
                    tamPhu = .chuoi(goc)
                } else if let goc: CTWChatMessage = try? await APIClient.shared.request(CTWAPI.motTin(pid: pid, cid: kenh.id, mid: c)) {
                    tamPhu = .chuoi(goc)
                }
            }
        }
        .onDisappear { vm.ketThuc() }
        .ctwXemTep($xemNhanh)
        .overlay { if dangMoTep { ProgressView().padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
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
        .confirmationDialog("Delete this message?", isPresented: Binding(get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let m = hoiXoa { Task { await vm.xoa(m) } } }
        }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $tamPhu) { t in tamPhuView(t) }
    }

    // MARK: Danh sách tin

    private var danhSach: some View {
        ScrollViewReader { cuon in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if vm.conCu {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.vertical, 12)
                            .onAppear {
                                let dau = vm.tin.first?.id
                                Task {
                                    await vm.taiCu()
                                    if let dau { cuon.scrollTo(dau, anchor: .top) }
                                }
                            }
                    } else if vm.daTai && !tinHien.isEmpty {
                        dauKenh
                    }
                    if vm.daTai && !vm.dangTai && tinHien.isEmpty && hangCho.cua(pid: pid, cid: kenh.id).isEmpty {
                        CTWOTrong(bieuTuong: "bubble.left.and.bubble.right", tieuDe: String(localized: "No messages yet"),
                                  moTa: duocGui ? String(localized: "Say hello to your team in #\(kenh.name).") : String(localized: "Nothing has been posted here yet."))
                            .padding(.top, 40)
                    }
                    ForEach(Array(tinHien.enumerated()), id: \.element.id) { i, m in
                        let truoc = i > 0 ? tinHien[i - 1] : nil
                        let doiNgay = !cungNgay(truoc?.createdAt, m.createdAt)
                        if doiNgay, let d = CTWChatThoiGian.date(m.createdAt) { VachNgayCTW(chu: CTWChatThoiGian.nhanNgay(d)) }
                        if m.id > vm.mocDaDoc, (truoc?.id ?? 0) <= vm.mocDaDoc, vm.mocDaDoc > 0, m.author?.id != app.currentUser?.id {
                            VachMoiCTW()
                        }
                        let gop = !doiNgay && truoc != nil && truoc?.author?.id == m.author?.id && !m.laHeThong
                            && truoc?.laHeThong == false && CTWChatThoiGian.phut(truoc?.createdAt, m.createdAt) < 5
                        TinChatCTW(tin: m, pid: pid, gop: gop, laCuaToi: m.author?.id == app.currentUser?.id, hanhDong: hanhDong)
                            .id(m.id)
                            .contextMenu { menu(m) } preview: { TinChatCTW(tin: m, pid: pid).padding().frame(width: 340).environmentObject(app) }
                    }
                    ForEach(hangCho.cua(pid: pid, cid: kenh.id)) { t in TinChoCTW(tin: t) }
                    Color.clear.frame(height: 4).id("day")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, 8)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .refreshable { await vm.tai() }
            .overlay { if !vm.daTai { CTWKhungTai(soHang: 6) } }
            // Lần nạp đầu: dữ liệu đến SAU khi ScrollView đã dựng ⇒ `defaultScrollAnchor`
            // không áp ⇒ cuộn tay xuống tin mới nhất (trừ khi deep link đòi một tin cụ thể).
            .onChange(of: vm.daTai) { _, xong in
                guard xong, vm.cuonToi == nil, toiTin == nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { cuon.scrollTo("day", anchor: .bottom) }
            }
            .onChange(of: vm.tin.last?.id) { _, _ in
                guard vm.cuonToi == nil else { return }
                withAnimation(.easeOut(duration: 0.2)) { cuon.scrollTo("day", anchor: .bottom) }
            }
            .onChange(of: hangCho.cua(pid: pid, cid: kenh.id).count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { cuon.scrollTo("day", anchor: .bottom) }
            }
            .onChange(of: vm.cuonToi) { _, id in
                guard let id else { return }
                Task {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    withAnimation { cuon.scrollTo(id, anchor: .center) }
                    vm.cuonToi = nil
                }
            }
        }
    }

    private var dauKenh: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: kenh.bieuTuong).font(.ctw(size: 20, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            Text(kenh.laDM ? "This is the start of your conversation with \(kenh.name)" : (kenh.laRieng ? "This is the start of \(kenh.name)" : "This is the start of #\(kenh.name)")).font(.ctw(size: 17, weight: .bold)).foregroundColor(AppColors.textPrimary)
            if let t = kenh.topic, !t.isEmpty { Text(t).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
        }
        .padding(.vertical, 16)
    }

    private func cungNgay(_ a: String?, _ b: String?) -> Bool {
        guard let x = CTWChatThoiGian.date(a), let y = CTWChatThoiGian.date(b) else { return a != nil }
        return Calendar.current.isDate(x, inSameDayAs: y)
    }

    private func dayCuocGoi(_ u: URL) -> some View {
        Button { moCuocGoi(u) } label: {
            HStack(spacing: 10) {
                Image(systemName: "phone.connection.fill").foregroundColor(.white)
                    .frame(width: 30, height: 30).background(Circle().fill(AppColors.success))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Call in progress").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text(u.host ?? "").font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Text("Join").font(.ctw(size: 14, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 7).background(Capsule().fill(AppColors.success))
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, 8)
            .background(AppColors.success.opacity(0.10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call in progress. Join")
    }

    // MARK: Thanh công cụ

    @ToolbarContentBuilder private var thanhCongCu: some ToolbarContent {
        // Tiêu đề hai dòng (tên + chủ đề) — đặt tường minh ở `.principal`: trên iPad
        // (cột chi tiết của NavigationSplitView) tiêu đề trơn của kênh không hiện.
        ToolbarItem(placement: .principal) {
            Button { tamPhu = .thongTin } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        if kenh.laRieng { Image(systemName: "lock.fill").font(.ctw(size: 11)) }
                        Text(kenh.laRieng ? kenh.name : "#\(kenh.name)").font(.ctw(size: 16, weight: .semibold))
                        if kenh.muted == true { Image(systemName: "bell.slash.fill").font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary) }
                    }
                    .foregroundColor(AppColors.textPrimary)
                    Text(phuDe).font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Shows channel details")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if duocGui {
                Button { Task { if let u = await vm.goiNhom() { moCuocGoi(u) } } } label: { Image(systemName: "video") }
                    .accessibilityLabel(kenh.call != nil ? "Join call" : "Start a call")
            }
            Menu {
                Button { tamPhu = .tim } label: { Label("Search in channel", systemImage: "magnifyingglass") }
                Button { tamPhu = .ghim } label: { Label("Pinned messages", systemImage: "pin") }
                Button { tamPhu = .thongTin } label: { Label("Members & notifications", systemImage: "person.2") }
                Button { Task { await vm.danhDauDaDoc() } } label: { Label("Mark as read", systemImage: "checkmark.circle") }
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("Channel options")
        }
    }

    private var phuDe: String {
        let tv = vm.thanhVien
        let online = tv.filter { $0.online == true }.count
        if !tv.isEmpty {
            let soNguoi = tv.count == 1 ? String(localized: "1 member") : String(localized: "\(tv.count) members")
            return online > 0 ? String(localized: "\(soNguoi) · \(online) online") : soNguoi
        }
        return kenh.topic ?? tenDuAn
    }

    // MARK: Menu tin

    @ViewBuilder
    private func menu(_ m: CTWChatMessage) -> some View {
        let laCuaToi = m.author?.id == app.currentUser?.id
        if !m.daXoa && !m.laHeThong && duocGui {
            ControlGroup {
                ForEach(["👍", "❤️", "😂", "🎉", "👀", "✅"], id: \.self) { e in
                    Button(e) { Task { await vm.camXuc(m, e) } }
                }
            }
            .controlGroupStyle(.compactMenu)
        }
        if !m.daXoa {
            if duocGui || (m.replyCount ?? 0) > 0 {
                Button { tamPhu = .chuoi(m) } label: { Label((m.replyCount ?? 0) > 0 ? "View thread" : "Reply in thread", systemImage: "arrowshape.turn.up.left") }
            }
            if !(m.body ?? "").isEmpty {
                Button { CTW.chepVaoBoNho(m.body ?? "") } label: { Label("Copy text", systemImage: "doc.on.doc") }
            }
            if !m.laHeThong {
                if duocGui { Button { Task { await vm.ghim(m) } } label: { Label(m.daGhim ? "Unpin" : "Pin to channel", systemImage: m.daGhim ? "pin.slash" : "pin") } }
                Button { tamPhu = .chuyenTiep(m) } label: { Label("Forward…", systemImage: "arrowshape.turn.up.right") }
                if app.cauHinhDuAn?.coTheTao == true { Button { tamPhu = .taoThe(m) } label: { Label("Create issue…", systemImage: "checkmark.square") } }
            }
        }
        if laCuaToi && !m.laHeThong && !m.daXoa && duocGui && !(m.body ?? "").isEmpty {
            Button { tamPhu = .sua(m) } label: { Label("Edit", systemImage: "pencil") }
        }
        if (laCuaToi || kenh.canManage == true) && !m.daXoa {
            Button(role: .destructive) { hoiXoa = m } label: { Label("Delete", systemImage: "trash") }
        }
        if !laCuaToi && !m.laHeThong && !m.daXoa {
            Divider()
            Button(role: .destructive) { baoCao = m } label: { Label("Report message", systemImage: "flag") }
            if let a = m.author {
                Button(role: .destructive) { hoiChan = a } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
            }
        }
    }

    // MARK: Ô nhập

    @ViewBuilder private var oNhap: some View {
        if !duocGui {
            Text(kenh.archived == true ? "This channel is archived." : "You can read this channel but not post in it.")
                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity).padding(12)
                .background(.bar)
        } else {
            SoanTinCTW(pid: pid, cid: kenh.id, goiY: kenh.laRieng ? String(localized: "Message \(kenh.name)") : String(localized: "Message #\(kenh.name)"),
                       thanhVien: vm.thanhVien,
                       gui: { chu, tep in await vm.gui(chu, tep: tep) },
                       chuDoi: { vm.chuDoi($0) },
                       guiGiongNoi: { f in await vm.gui("", tep: [f]) })
        }
    }

    // MARK: Tấm phủ

    @ViewBuilder
    private func tamPhuView(_ t: TamPhuChatCTW) -> some View {
        switch t {
        case .sua(let m):
            CTWSuaBinhLuanView(chuBanDau: m.body ?? "") { chu in await vm.sua(m, chu: chu) }
        case .chuoi(let m):
            ChuoiTraLoiCTW(pid: pid, kenh: kenh, goc: m, tenDuAn: tenDuAn).environmentObject(app)
        case .thongTin:
            ThongTinKenhCTW(vm: vm).environmentObject(app)
        case .tim:
            TimTinCTW(pid: pid, kenh: kenh) { m in Task { await vm.taiQuanh(m.parentId ?? m.id) } }.environmentObject(app)
        case .ghim:
            TinGhimCTW(pid: pid, kenh: kenh) { m in Task { await vm.taiQuanh(m.id) } }.environmentObject(app)
        case .chuyenTiep(let m):
            ChuyenTiepTinCTW(pid: pid, tuKenh: kenh, tin: m) { thongBao = $0 }
        case .taoThe(let m):
            TheTuTinCTW(pid: pid, kenh: kenh, tin: m) { thongBao = $0 }.environmentObject(app)
        case .camXuc(let m):
            ChonCamXucCTW { e in Task { await vm.camXuc(m, e) } }
        }
    }

    // MARK: Tệp + cuộc gọi

    private func moTep(_ f: CTWChatFile) {
        #if DEBUG
        if app.cheDoXemThu { return }
        #endif
        Task {
            dangMoTep = true
            defer { dangMoTep = false }
            do {
                let u = try await UrlTepChatCTW.lay(pid: pid, fid: f.id)
                xemNhanh = try await CTWXemTep.taiVe(url: u, ten: f.fileName ?? "file", khoa: "chat-\(f.id)")
            } catch { vm.loi = CTW.loi(error) }
        }
    }

    /// Meet/Zoom/Teams/Jitsi: mở bằng hệ thống ⇒ Universal Link vào app của họ nếu đã
    /// cài (micro/camera do app đó xin); chưa cài ⇒ Safari. Chỉ link không phải
    /// https mới mở trong app.
    private func moCuocGoi(_ u: URL) {
        CuocGoiCTW.mo(u, moUrl: moUrl)
    }
}

// MARK: - Vạch ngày / vạch tin mới / chấm gõ / tin chờ

struct VachNgayCTW: View {
    let chu: String
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColors.divider).frame(height: 0.5)
            Text(chu).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Capsule().fill(AppColors.backgroundTertiary))
                .fixedSize()
            Rectangle().fill(AppColors.divider).frame(height: 0.5)
        }
        .padding(.vertical, 10)
        .accessibilityAddTraits(.isHeader)
    }
}

struct VachMoiCTW: View {
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(AppColors.error.opacity(0.6)).frame(height: 1)
            Text("New messages").font(.ctw(size: 11, weight: .bold)).foregroundColor(AppColors.error).fixedSize()
        }
        .padding(.vertical, 6)
    }
}

struct DauGoCTW: View {
    @State private var pha = 0.0
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle().fill(AppColors.textTertiary).frame(width: 5, height: 5)
                    .opacity(giamChuyenDong ? 0.8 : 0.35 + 0.65 * abs(sin(pha + Double(i) * 0.8)))
            }
        }
        .onAppear {
            guard !giamChuyenDong else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { pha = .pi }
        }
    }
}

struct TinChoCTW: View {
    let tin: TinChoGuiCTW
    @EnvironmentObject private var app: AppState
    @ObservedObject private var hang = HangChoGuiCTW.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CTWAvatar(user: app.currentUser.map { CTWUser(id: $0.id, username: $0.username, fullName: $0.fullName, displayName: $0.displayName, avatarUrl: $0.avatarUrl) }, size: 36)
                .opacity(0.6)
            VStack(alignment: .leading, spacing: 4) {
                Text(tin.body).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                switch tin.trangThai {
                case .dangGui:
                    Label("Sending…", systemImage: "arrow.up.circle").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                case .cho:
                    Label("Waiting for network", systemImage: "clock").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                case .loi:
                    HStack(spacing: 10) {
                        Label(tin.loi ?? String(localized: "Not sent"), systemImage: "exclamationmark.circle.fill").font(.ctw(size: 11))
                            .foregroundColor(AppColors.error)
                        Button("Retry") { Task { await hang.thuLai(tin.id) } }.font(.ctw(size: 12, weight: .semibold))
                        Button("Delete", role: .destructive) { hang.xoa(tin.id) }.font(.ctw(size: 12))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mở cuộc gọi

enum CuocGoiCTW {
    /// Mở link phòng họp: hệ thống chuyển sang app Meet/Zoom/Teams/Jitsi nếu đã cài
    /// (Universal Link), không thì Safari — nơi có quyền micro/camera của chính nó.
    @MainActor
    static func mo(_ u: URL, moUrl: OpenURLAction) {
        moUrl(u)
    }
}
