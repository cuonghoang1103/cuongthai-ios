import SwiftUI
import Kingfisher

// MARK: - Hồ sơ một người (22/10/2026 — bản 1.1, kiểu Facebook / Instagram / X)
//
// Mở từ MỌI avatar: bong bóng chat, danh sách hội thoại, Thành viên, Bảng tin (bài + bình luận), thẻ (người báo cáo,
// bình luận), kênh chat. Đầu trang: ảnh bìa + avatar lớn + trạng thái (theo luật riêng tư — `KhoTinNhanCTW.moc`), tên,
// @username, chức danh, giới thiệu (`GET /users/:id` — cùng trang /profile/:id của web), chip vai theo không gian/dự án.
// Nút chính: Nhắn tin · Xem việc; menu "…": Tắt thông báo hội thoại · Chặn/Bỏ chặn · Báo cáo · Sao chép link hồ sơ (1.2).
// Khối: Dự án chung · Việc đang mở (dự án chọn) · Bài viết gần đây trên Bảng tin (khi máy chủ có Bảng tin).
// Người là chính mình ⇒ `HoSoCuaToiCTW`.

/// Mở hồ sơ dạng tấm phủ ở chỗ đang đứng — gắn MỘT lần ở gốc mỗi cột (`CotNganXepCTW`) và trong tấm phủ có avatar.
struct HoSoTamPhuCTW: ViewModifier {
    private struct Ma: Identifiable { let id: Int }
    @State private var mo: Ma?

    func body(content: Content) -> some View {
        content
            .environment(\.ctwMoHoSo) { id in mo = Ma(id: id) }
            .sheet(item: $mo) { m in
                NavigationStack { HoSoThanhVienCTW(userId: m.id, laTamPhu: true) }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func ctwHoSoTamPhu() -> some View { modifier(HoSoTamPhuCTW()) }
}

// MARK: Đầu hồ sơ (ảnh bìa + avatar) — dùng chung hồ sơ của tôi và của người khác

struct DauHoSoCTW<NutAnh: View, NutBia: View>: View {
    let user: CTWUser
    let anhBia: String?
    var moc: TrangThaiHoatDongCTW.Moc = .an
    @ViewBuilder var nutAnh: () -> NutAnh
    @ViewBuilder var nutBia: () -> NutBia

    static var caoBia: CGFloat { 168 }
    static var coAvatar: CGFloat { 112 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            bia
                .frame(height: Self.caoBia)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomTrailing) { nutBia().padding(10) }
                .padding(.bottom, Self.coAvatar / 2)
            // ⚠️ Mã nhận dạng gắn vào CHÍNH avatar (trước overlay): gắn vào cả khối thì nó đè lên nút đổi ảnh bên trong.
            AvatarHoatDongCTW(user: user, size: Self.coAvatar, moc: moc)
                .accessibilityValue(DuongDanAnh.urlAnh(user.avatarUrl) != nil ? String(localized: "Profile photo") : "")
                .accessibilityIdentifier("profile.avatar")
                .padding(4)
                .background(Circle().fill(AppColors.backgroundPrimary))
                .overlay(alignment: .bottomTrailing) { nutAnh().offset(x: -2, y: -2) }
                .padding(.leading, 16)
        }
    }

    @ViewBuilder private var bia: some View {
        let mau = CTWKieuWeb.mau(user.username ?? user.ten)
        // Ảnh bìa nằm trong OVERLAY của nền gradient: `scaledToFill` rộng hơn màn KHÔNG được đẩy bố cục (đã dính 22/10:
        // cả trang hồ sơ lệch trái vì ZStack nhận bề rộng của ảnh).
        LinearGradient(colors: [mau.opacity(0.95), AppColors.primary.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay {
            if let u = DuongDanAnh.urlAnh(anhBia) {
                KFImage(u).resizable().scaledToFill()
            } else {
                // Không có ảnh bìa: hoạ tiết nhẹ từ biểu tượng CT Work (không để một mảng màu phẳng).
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 120)).foregroundStyle(.white.opacity(0.08))
                    .offset(x: 110, y: 20)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Chip vai: "Admin · Northwind Studio", "NW · Member".
struct ChipVaiCTW: View {
    let chu: String
    var bieuTuong: String = "building.2"
    var nhan = false

    var body: some View {
        Label { Text(verbatim: chu).lineLimit(1) } icon: { Image(systemName: bieuTuong).font(.ctw(size: 10, weight: .semibold)) }
            .font(.ctw(size: 12, weight: .medium))
            .foregroundColor(nhan ? AppColors.primary : AppColors.textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(nhan ? AppColors.primary.opacity(0.12) : AppColors.backgroundSecondary))
            .fixedSize()
    }
}

// MARK: Hồ sơ người khác

struct HoSoThanhVienCTW: View {
    let userId: Int
    var laTamPhu = false
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @ObservedObject private var kd = ModerationStore.shared
    @ObservedObject private var bangTin = KhoBangTinCTW.shared
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var congKhai: CTWHoSoCongKhai?
    @State private var duAnChon: Int?
    @State private var the: [CTWIssueCard]?
    @State private var bai: [CTWFeedPost]?
    @State private var dangMo = false
    @State private var loi: String?
    @State private var thongBao: String?
    @State private var hoiChan = false
    @State private var tamPhu: TamPhu?
    @State private var bayGio = Date()

    enum TamPhu: String, Identifiable { case baoCao, viec; var id: String { rawValue } }

    private var n: CTWThanhVien? { kho.thanhVien(userId) }
    private var daChan: Bool { kd.blockedUserIds.contains(userId) || n?.blocked == true }
    private var laAgent: Bool { n?.laAgent ?? false }
    private var ten: String { n?.ten ?? congKhai?.ten ?? String(localized: "Member") }
    private var username: String? { n?.username ?? congKhai?.username }
    private var nguoi: CTWUser {
        CTWUser(id: userId, username: username, fullName: n?.fullName ?? congKhai?.fullName, displayName: ten,
                avatarUrl: n?.avatarUrl ?? congKhai?.avatarUrl, kind: n?.kind)
    }
    private var moc: TrangThaiHoatDongCTW.Moc { kho.moc(userId, mocHoiThoai: kho.hoiThoaiVoi(userId)?.peer?.lastActiveAt, bayGio: bayGio) }
    private var duAnChung: [CTWThanhVien.DuAn] { n?.projects ?? [] }
    private var duAnDangXem: CTWThanhVien.DuAn? {
        duAnChung.first { $0.id == duAnChon } ?? duAnChung.first { $0.id == app.luaChon?.pid } ?? duAnChung.first
    }
    private var hoiThoai: MessageThread? { kho.hoiThoaiVoi(userId) }

    var body: some View {
        if userId == app.currentUser?.id {
            HoSoCuaToiCTW(laTamPhu: laTamPhu)
        } else {
            noiDung
        }
    }

    private var noiDung: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DauHoSoCTW(user: nguoi, anhBia: congKhai?.coverPhotoUrl, moc: moc) { EmptyView() } nutBia: { EmptyView() }
                VStack(alignment: .leading, spacing: 16) {
                    tieuDe
                    nutChinh
                    if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                    chipVai
                    if !duAnChung.isEmpty { khoiDuAn }
                    khoiViec
                    if bangTin.hien && !laAgent { khoiBaiViet }
                    if !laAgent { khoiAnToan }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if laTamPhu { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
            ToolbarItem(placement: .primaryAction) { menuPhu }
        }
        .task { await tai() }
        .task(id: duAnDangXem?.id) { await taiThe() }
        .refreshable { await kho.taiDanhBa(); await tai() }
        .confirmationDialog("Block \(ten)?", isPresented: $hoiChan, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task {
                    do { try await kd.block(userId: userId, reason: nil); await kho.taiDanhBa(); CTWRung.thanhCong() }
                    catch { loi = CTW.loi(error) }
                }
            }
        } message: { Text("They won't be able to message you, and you won't see their messages, posts or active status. You can unblock them in Account › Blocked users.") }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .baoCao: BaoCaoNguoiCTW(ten: ten, userId: userId, threadId: hoiThoai?.id)
            case .viec:
                NavigationStack {
                    if let d = duAnDangXem { ViecCuaNguoiCTW(userId: userId, ten: ten, username: username ?? "", duAn: d) }
                }
            }
        }
    }

    // MARK: Phần

    private var tieuDe: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(verbatim: ten).font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if laAgent { CTWNhanAI() }
            }
            if let u = username { Text(verbatim: "@\(u)").font(.ctw(size: 15)).foregroundColor(AppColors.textSecondary) }
            let chu = TrangThaiHoatDongCTW.chu(moc)
            if !chu.isEmpty {
                HStack(spacing: 6) {
                    if moc == .dangHoatDong { Circle().fill(AppColors.success).frame(width: 8, height: 8) }
                    Text(chu).font(.ctw(size: 13, weight: .medium))
                        .foregroundColor(moc == .dangHoatDong ? AppColors.success : AppColors.textSecondary)
                }
                .accessibilityIdentifier("profile.presence")
            }
            if let c = congKhai, !c.dongNghe.isEmpty {
                Label { Text(verbatim: c.dongNghe) } icon: { Image(systemName: "briefcase") }
                    .font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).padding(.top, 2)
            }
            if let b = congKhai?.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty {
                Text(verbatim: b).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                    .accessibilityIdentifier("profile.bio")
            }
        }
    }

    private var nutChinh: some View {
        HStack(spacing: 10) {
            if !laAgent {
                Button { Task { await nhanTin() } } label: {
                    Label(daChan ? String(localized: "Blocked") : String(localized: "Message"), systemImage: "bubble.left.fill")
                        .font(.ctw(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(alignment: .trailing) { if dangMo { ProgressView().padding(.trailing, 10) } }
                }
                .buttonStyle(.borderedProminent)
                .disabled(dangMo || daChan)
                .accessibilityIdentifier("member.message")
            }
            Button { tamPhu = .viec } label: {
                Label("View work", systemImage: "checklist")
                    .font(.ctw(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(duAnDangXem == nil || username == nil)
            .accessibilityIdentifier("profile.work")
        }
    }

    @ViewBuilder private var chipVai: some View {
        let ws = n?.workspaces ?? []
        if !ws.isEmpty || !duAnChung.isEmpty {
            BoCucBocDongCTW(khoang: 6) {
                ForEach(ws, id: \.id) { w in
                    ChipVaiCTW(chu: "\(CTWThanhVien.tenVai(w.role ?? "")) · \(w.name ?? "")", bieuTuong: "building.2",
                               nhan: (w.role ?? "").uppercased() == "OWNER" || (w.role ?? "").uppercased() == "ADMIN")
                }
                ForEach(duAnChung, id: \.id) { d in
                    ChipVaiCTW(chu: "\(d.key ?? "") · \(CTWThanhVien.tenVai(d.role ?? ""))", bieuTuong: "rectangle.3.group")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var khoiDuAn: some View {
        KhoiHoSoCTW(tieuDe: String(localized: "Projects in common"), bieuTuong: "rectangle.3.group") {
            ForEach(duAnChung, id: \.id) { d in
                Button { duAnChon = d.id } label: {
                    HStack(spacing: 10) {
                        CTWProjectMark(ma: d.key ?? "?", co: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: d.name ?? d.key ?? "").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Text(verbatim: "\(d.key ?? "") · \(CTWThanhVien.tenVai(d.role ?? ""))").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if d.id == duAnDangXem?.id { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var khoiViec: some View {
        KhoiHoSoCTW(tieuDe: duAnDangXem.map { String(localized: "Open issues · \($0.key ?? "")") } ?? String(localized: "Open issues"),
                    bieuTuong: "checklist") {
            if duAnDangXem == nil {
                Text("You don't share a project with them yet.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            } else if let the {
                if the.isEmpty {
                    Text("No open issues assigned to them here.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                ForEach(the.prefix(5)) { t in HangViecNguoiCTW(ma: duAnDangXem?.key ?? "", the: t) }
                if the.count > 5 {
                    Button { tamPhu = .viec } label: { Text("See all \(the.count)").font(.ctw(size: 14, weight: .semibold)) }
                        .frame(minHeight: 36)
                }
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder private var khoiBaiViet: some View {
        let ds = (bai ?? []).filter { $0.hiddenForMe != true && $0.hidden != true }
        if bai == nil || !ds.isEmpty {
            KhoiHoSoCTW(tieuDe: String(localized: "Recent posts"), bieuTuong: "newspaper") {
                if bai == nil { HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 8) }
                ForEach(ds.prefix(3)) { p in
                    Button {
                        if laTamPhu { dong() }
                        bangTin.moBai(DichBangTin(slug: p.workspace?.slug ?? "", post: p.id, comment: nil))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: (p.body ?? "").isEmpty ? String(localized: "Shared a post") : (p.body ?? ""))
                                .font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(3)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 6) {
                                if let d = p.createdAt.flatMap(Date.tuChuoiISO) { Text(CTWDinhDang.tuongDoi(d)) }
                                if let k = p.project?.key ?? p.workspace?.name { Text(verbatim: "· \(k)") }
                                Spacer()
                                if (p.reactionCount ?? 0) > 0 { Label("\(p.reactionCount ?? 0)", systemImage: "heart") }
                                if (p.commentCount ?? 0) > 0 { Label("\(p.commentCount ?? 0)", systemImage: "bubble.right") }
                            }
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.vertical, 6).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var khoiAnToan: some View {
        VStack(alignment: .leading, spacing: 0) {
            if daChan {
                nutAnToan("Unblock", "hand.raised.slash", vaiTro: nil) { Task { await boChan() } }
            } else {
                nutAnToan("Block", "hand.raised", vaiTro: .destructive) { hoiChan = true }
            }
            Divider().padding(.leading, 44)
            nutAnToan("Report", "exclamationmark.bubble", vaiTro: .destructive) { tamPhu = .baoCao }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
    }

    private func nutAnToan(_ chu: LocalizedStringKey, _ bt: String, vaiTro: ButtonRole?, _ f: @escaping () -> Void) -> some View {
        Button(role: vaiTro, action: f) {
            Label(chu, systemImage: bt).font(.ctw(size: 15)).frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .padding(.horizontal, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(vaiTro == .destructive ? AppColors.error : AppColors.primary)
    }

    private var menuPhu: some View {
        Menu {
            if let t = hoiThoai {
                Menu {
                    if t.daTatThongBao {
                        Button { Task { await tat(t.id, 0) } } label: { Label("Unmute", systemImage: "bell") }
                    }
                    ForEach(TatThongBaoCTW.allCases) { m in Button(m.nhan) { Task { await tat(t.id, m.phut) } } }
                } label: { Label(t.daTatThongBao ? String(localized: "Muted") : String(localized: "Mute conversation"), systemImage: "bell.slash") }
            }
            Button { UIPasteboard.general.url = HoSoAPICTW.linkHoSo(userId); thongBao = String(localized: "Profile link copied") } label: {
                Label("Copy profile link", systemImage: "link")
            }
            if !laAgent {
                Divider()
                if daChan {
                    Button { Task { await boChan() } } label: { Label("Unblock", systemImage: "hand.raised.slash") }
                } else {
                    Button(role: .destructive) { hoiChan = true } label: { Label("Block", systemImage: "hand.raised") }
                }
                Button(role: .destructive) { tamPhu = .baoCao } label: { Label("Report", systemImage: "exclamationmark.bubble") }
            }
        } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
            .accessibilityLabel("More")
            .accessibilityIdentifier("profile.more")
    }

    // MARK: Tải + hành động

    private func tai() async {
        bayGio = Date()
        if kho.danhBa.isEmpty { await kho.taiDanhBa() }
        if !kho.daTaiHoiThoai { await kho.taiHoiThoai() }
        async let c: CTWHoSoCongKhai? = try? APIClient.shared.request(TinNhanAPI.hoSoCongKhai(userId))
        if bangTin.hien, !laAgent {
            let t: CTWFeedTrang? = try? await APIClient.shared.request(CTWAPI.bangTin(LocBangTin(tacGia: userId), cursor: nil, limit: 5))
            bai = (t?.posts ?? []).filter { !kd.blockedUserIds.contains($0.author?.id ?? -1) }
        }
        congKhai = await c
    }

    private func taiThe() async {
        guard let d = duAnDangXem, let u = username else { the = []; return }
        the = nil
        the = await ViecCuaNguoiCTW.tai(pid: d.id, username: u, gioiHan: 20)
    }

    private func nhanTin() async {
        dangMo = true; loi = nil
        defer { dangMo = false }
        do {
            let t = try await kho.moVoi(userId)
            if laTamPhu { dong() }
            try? await Task.sleep(for: .milliseconds(laTamPhu ? 350 : 0))
            kho.moHoiThoai(t.id)
        } catch { loi = CTW.loi(error) }
    }

    private func tat(_ id: Int, _ phut: Int?) async {
        do {
            try await kho.tatThongBao(id, phut: phut)
            thongBao = phut == 0 ? String(localized: "Notifications on") : String(localized: "Conversation muted")
        } catch { loi = CTW.loi(error) }
    }

    private func boChan() async {
        do { try await kd.unblock(userId: userId); await kho.taiDanhBa() } catch { loi = CTW.loi(error) }
    }
}

/// Khối có tiêu đề trên nền thẻ (hồ sơ).
struct KhoiHoSoCTW<NoiDung: View>: View {
    let tieuDe: String
    let bieuTuong: String
    @ViewBuilder var noiDung: () -> NoiDung

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label { Text(verbatim: tieuDe) } icon: { Image(systemName: bieuTuong) }
                .font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) { noiDung() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundCard))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
        }
    }
}

struct HangViecNguoiCTW: View {
    let ma: String
    let the: CTWIssueCard

    var body: some View {
        Button {
            Task { await DinhTuyenCTW.moTheoKhoa("\(ma)-\(the.number)") }
        } label: {
            HStack(spacing: 8) {
                Text(verbatim: "\(ma)-\(the.number)").font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                Text(verbatim: the.title).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if the.dueDate != nil { CTWDueChip(dueDate: the.dueDate) }
                Image(systemName: "chevron.right").font(.ctw(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
            }
            .frame(minHeight: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// "Xem việc": mọi thẻ đang mở được giao cho người này trong MỘT dự án chung (JQL như màn List).
struct ViecCuaNguoiCTW: View {
    let userId: Int
    let ten: String
    let username: String
    let duAn: CTWThanhVien.DuAn
    @Environment(\.dismiss) private var dong
    @State private var ds: [CTWIssueCard]?

    static func tai(pid: Int, username: String, gioiHan: Int) async -> [CTWIssueCard] {
        let jql = "assignee = \"\(username)\" AND statusCategory != Done ORDER BY updated DESC"
        let r: CTWKetQuaJql? = try? await APIClient.shared.request(CTWAPI.timTheoJql(pid: pid, jql: jql, limit: gioiHan))
        return r?.items ?? []
    }

    var body: some View {
        List {
            if let ds {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "checkmark.circle", tieuDe: String(localized: "Nothing open"),
                              moTa: String(localized: "\(ten) has no open issues in \(duAn.key ?? "")."))
                        .listRowBackground(Color.clear)
                }
                ForEach(ds) { t in
                    HangViecNguoiCTW(ma: duAn.key ?? "", the: t)
                        .simultaneousGesture(TapGesture().onEnded { dong() })
                }
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
        }
        .navigationTitle(String(localized: "\(TenNguoi.tenNgan(ten))'s work · \(duAn.key ?? "")"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        .task { ds = await Self.tai(pid: duAn.id, username: username, gioiHan: 100) }
    }
}
