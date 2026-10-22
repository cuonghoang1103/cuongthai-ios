import SwiftUI

// MARK: - Thẻ một bài trong Bảng tin
//
// Đầu: avatar (chấm hoạt động nếu danh bạ Thành viên có người đó) · tên (+ nhãn AI) · chip vai · nhãn phạm vi
// (không gian › dự án) · thời gian tương đối · "đã chỉnh sửa" · ghim · menu "…".
// Thân: chữ (markdown nội dòng, @nhắc / #tag / link / mã thẻ chạm được, "Xem thêm") · thẻ link · thẻ CT Work ·
// lưới ảnh/video · tệp · bình chọn. Đáy: dải cảm xúc + số bình luận · Thích (giữ ⇒ 6 cảm xúc) · Bình luận · Chia sẻ ·
// 2 bình luận mới nhất.
// 1.2 (UGC): menu có Ẩn bài · Báo cáo · Chặn tác giả trên MỌI bài của người khác.

/// Mọi việc một thẻ bài có thể yêu cầu — màn chứa (bảng tin / chi tiết) quyết định làm gì.
struct HanhDongBaiCTW {
    var camXuc: (CTWFeedPost, CamXucBangTin?) -> Void = { _, _ in }
    var binhLuan: (CTWFeedPost) -> Void = { _ in }
    var xemCamXuc: (CTWFeedPost) -> Void = { _ in }
    var luu: (CTWFeedPost) -> Void = { _ in }
    var an: (CTWFeedPost) -> Void = { _ in }
    var baoCao: (CTWFeedPost) -> Void = { _ in }
    var chan: (CTWUser) -> Void = { _ in }
    var xoa: (CTWFeedPost) -> Void = { _ in }
    var ghim: (CTWFeedPost) -> Void = { _ in }
    var go: (CTWFeedPost) -> Void = { _ in }
    var sua: (CTWFeedPost) -> Void = { _ in }
    var bauChon: (CTWFeedPost, [String]) -> Void = { _, _ in }
    var moURL: (URL) -> Void = { _ in }
    var xemPhuongTien: ([CTWFeedAttachment], Int) -> Void = { _, _ in }
    var moTep: (CTWFeedAttachment) -> Void = { _ in }
    var thuLai: (String) -> Void = { _ in }
    var boTam: (String) -> Void = { _ in }
    /// Bài tạm bị bộ lọc chặn ⇒ mở lại ô soạn với bản nháp.
    var suaTam: (CTWFeedPost) -> Void = { _ in }
    var boAn: (CTWFeedPost) -> Void = { _ in }
    var moBai: (CTWFeedPost) -> Void = { _ in }
}

struct TheBaiCTW: View {
    let p: CTWFeedPost
    /// Hiện nhãn phạm vi (bảng tin gộp / không gian). Bảng tin dự án ⇒ ẩn (đã biết là dự án nào).
    var hienPhamVi = true
    /// Màn chi tiết: chữ đầy đủ, không xem trước bình luận.
    var chiTiet = false
    let hd: HanhDongBaiCTW

    @EnvironmentObject private var app: AppState
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @State private var moRong = false
    @State private var hoiXoa = false
    @State private var hoiChan = false

    private var cuaToi: Bool { p.author?.id != nil && p.author?.id == app.currentUser?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if p.pinned == true && !p.laTam { nhanGhim }
            dau.padding(.horizontal, 14).padding(.top, p.pinned == true ? 6 : 14)
            if p.hidden == true { bangDaGo.padding(.horizontal, 14).padding(.top, 10) }
            if p.hiddenForMe == true { bangDaAn.padding(.horizontal, 14).padding(.top, 10) }
            noiDung
            if !p.laTam { dayBai }
            if p.laTam { trangThaiTam }
        }
        .ctwThe(16)
        .opacity(p.laTam && p.dangHong != true ? 0.75 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed.post.\(p.id)")
        .confirmationDialog("Delete this post?", isPresented: $hoiXoa, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { hd.xoa(p) }
        } message: { Text("It will be removed for everyone, with its comments and reactions.") }
        .confirmationDialog(Text("Block \(p.author?.ten ?? "")?"), isPresented: $hoiChan, titleVisibility: .visible) {
            Button("Block", role: .destructive) { if let a = p.author { hd.chan(a) } }
        } message: { Text("You won't see their posts, and their comments will be collapsed. They won't be told.") }
    }

    // MARK: Đầu

    private var nhanGhim: some View {
        HStack(spacing: 5) {
            Image(systemName: "pin.fill").font(.ctw(size: 10, weight: .bold)).rotationEffect(.degrees(45))
            Text("Pinned").font(.ctw(size: 11, weight: .semibold))
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 14).padding(.top, 10)
        .accessibilityElement(children: .combine)
    }

    private var dau: some View {
        HStack(alignment: .top, spacing: 10) {
            Button { if let a = p.author { hd.moURL(URL(string: "\(ChuBangTin.luocDo)://nguoi/\(a.id)")!) } } label: {
                AvatarHoatDongCTW(user: p.author, size: 42, moc: p.author.map { kho.moc($0.id) } ?? .an)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(p.author?.ten ?? ""))
            .accessibilityHint(Text("Opens their profile"))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(p.author?.ten ?? String(localized: "Someone"))
                        .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if p.author?.laAgent == true { CTWNhanAI() }
                    if let r = p.authorRole, ["OWNER", "ADMIN", "TEACHER"].contains(r) {
                        Text(verbatim: CTWMauTrangThai.nhan(r))
                            .font(.ctw(size: 10, weight: .bold)).foregroundColor(AppColors.primary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                            .fixedSize()
                    }
                }
                dongPhu
            }
            Spacer(minLength: 4)
            if !p.laTam { menu }
        }
    }

    /// "Northwind › NW · 2 giờ trước · Đã chỉnh sửa".
    private var dongPhu: some View {
        HStack(spacing: 4) {
            if hienPhamVi { nhanPhamVi }
            Text(ThoiGianBangTin.nhan(p.createdAt)).lineLimit(1)
                .accessibilityLabel(Text(ThoiGianBangTin.day(p.createdAt)))
            if p.editedAt != nil {
                Text(verbatim: "·").accessibilityHidden(true)
                Text("Edited").lineLimit(1)
            }
        }
        .font(.ctw(size: 12))
        .foregroundColor(AppColors.textSecondary)
    }

    @ViewBuilder private var nhanPhamVi: some View {
        if let d = p.project {
            HStack(spacing: 4) {
                CTWProjectMark(ma: d.key ?? "?", co: 14)
                Text(verbatim: d.name ?? d.key ?? "").fontWeight(.medium).lineLimit(1)
            }
            .foregroundColor(AppColors.textPrimary.opacity(0.8))
            Text(verbatim: "·").accessibilityHidden(true)
        } else if let w = p.workspace {
            HStack(spacing: 3) {
                Image(systemName: "building.2").font(.ctw(size: 10, weight: .semibold))
                Text(verbatim: w.name ?? "").fontWeight(.medium).lineLimit(1)
            }
            .foregroundColor(AppColors.textPrimary.opacity(0.8))
            Text(verbatim: "·").accessibilityHidden(true)
        }
    }

    private var menu: some View {
        Menu {
            Button { hd.luu(p) } label: {
                p.saved == true ? Label("Remove from saved", systemImage: "bookmark.slash") : Label("Save post", systemImage: "bookmark")
            }
            if let u = DichBangTin.urlWeb(p.url) {
                Button { CTW.chepVaoBoNho(u.absoluteString); CTWRung.chon() } label: { Label("Copy link", systemImage: "link") }
                ShareLink(item: u) { Label("Share…", systemImage: "square.and.arrow.up") }
            }
            if cuaToi || p.can?.pin == true || p.can?.moderate == true || p.can?.delete == true {
                Divider()
                if cuaToi && p.can?.edit != false { Button { hd.sua(p) } label: { Label("Edit post", systemImage: "pencil") } }
                if p.can?.pin == true {
                    Button { hd.ghim(p) } label: {
                        p.pinned == true ? Label("Unpin", systemImage: "pin.slash") : Label("Pin to top", systemImage: "pin")
                    }
                }
                if p.can?.moderate == true && !cuaToi {
                    Button { hd.go(p) } label: {
                        p.hidden == true ? Label("Restore post", systemImage: "eye") : Label("Remove for everyone", systemImage: "eye.slash")
                    }
                }
                if p.can?.delete == true {
                    Button(role: .destructive) { hoiXoa = true } label: { Label("Delete post", systemImage: "trash") }
                }
            }
            if !cuaToi {
                Divider()
                Button { hd.an(p) } label: { Label("Hide post", systemImage: "eye.slash") }
                Button(role: .destructive) { hd.baoCao(p) } label: { Label("Report post", systemImage: "flag") }
                if let a = p.author, !a.laAgent {
                    Button(role: .destructive) { hoiChan = true } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.ctw(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Post options"))
        .accessibilityIdentifier("feed.post.menu")
    }

    private var bangDaGo: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
            Text("Removed by an admin. Only the author and admins can see it.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.ctw(size: 12, weight: .medium))
        .foregroundColor(AppColors.warning)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.warning.opacity(0.12)))
    }

    /// Mở thẳng một bài mình đã ẩn (thông báo / link) ⇒ nói rõ + Bỏ ẩn.
    private var bangDaAn: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash")
            Text("You hid this post. It doesn't show in your feed.").fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Unhide") { hd.boAn(p) }.font(.ctw(size: 12, weight: .semibold))
        }
        .font(.ctw(size: 12, weight: .medium))
        .foregroundColor(AppColors.textSecondary)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.backgroundTertiary))
    }

    // MARK: Thân

    @ViewBuilder private var noiDung: some View {
        let body = p.body ?? ""
        if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let gon = !chiTiet && !moRong && ChuBangTin.canThuGon(body)
            VStack(alignment: .leading, spacing: 4) {
                Text(ChuBangTin.dung(body, nhac: p.mentions ?? [], maDuAn: p.project?.key, slug: p.workspace?.slug))
                    .font(.ctw(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .tint(AppColors.primary)
                    .lineSpacing(3)
                    .lineLimit(gon ? 6 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .environment(\.openURL, OpenURLAction { u in hd.moURL(u); return .handled })
                if gon {
                    Button { withAnimation(.easeOut(duration: 0.2)) { moRong = true } } label: {
                        Text("See more").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feed.post.more")
                }
            }
            .padding(.horizontal, 14).padding(.top, 10)
        }
        if let l = p.linkPreview, l.url != nil { TheLinkCTW(l: l) { hd.moURL($0) }.padding(.horizontal, 14).padding(.top, 10) }
        ForEach(Array((p.refs ?? []).prefix(3).enumerated()), id: \.offset) { _, r in
            TheThamChieuCTW(r: r) { hd.moURL($0) }.padding(.horizontal, 14).padding(.top, 8)
        }
        if let poll = p.poll { BinhChonCTW(poll: poll, choBau: !p.laTam) { hd.bauChon(p, $0) }.padding(.horizontal, 14).padding(.top, 10) }
        let pt = p.anhVaVideo
        if !pt.isEmpty {
            LuoiPhuongTienCTW(ds: pt) { hd.xemPhuongTien(pt, $0) }
                .padding(.top, 10)
        }
        if !p.tep.isEmpty {
            VStack(spacing: 6) { ForEach(p.tep) { a in ChipTepCTW(a: a) { hd.moTep(a) } } }
                .padding(.horizontal, 14).padding(.top, 10)
        }
    }

    // MARK: Đáy — dải cảm xúc + nút

    private var dayBai: some View {
        let cx = TrangThaiCamXuc(p)
        let dau3 = CamXucLogic.baDau(cx)
        return VStack(spacing: 0) {
            if cx.tong > 0 || (p.commentCount ?? 0) > 0 {
                HStack(spacing: 6) {
                    if cx.tong > 0 {
                        Button { hd.xemCamXuc(p) } label: {
                            HStack(spacing: 5) {
                                HStack(spacing: -5) {
                                    ForEach(dau3) { k in
                                        Text(k.emoji).font(.ctw(size: 13))
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(AppColors.backgroundCard))
                                            .overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1.5))
                                    }
                                }
                                Text(CTWDinhDang.so(cx.tong)).font(.ctw(size: 13).monospacedDigit())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .frame(minHeight: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(cx.tong == 1 ? String(localized: "1 reaction") : String(localized: "\(cx.tong) reactions")))
                        .accessibilityHint(Text("Shows who reacted"))
                        .accessibilityIdentifier("feed.post.reactions")
                    }
                    Spacer(minLength: 0)
                    if let n = p.commentCount, n > 0 {
                        Button { hd.binhLuan(p) } label: {
                            Text(n == 1 ? String(localized: "1 comment") : String(localized: "\(n) comments"))
                                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                                .frame(minHeight: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.top, 10)
            }
            Divider().padding(.horizontal, 14).padding(.top, 8)
            HStack(spacing: 0) {
                NutCamXucCTW(trangThai: cx, choPhep: p.can?.react != false) { hd.camXuc(p, $0) }
                    .frame(maxWidth: .infinity)
                Button { hd.binhLuan(p) } label: {
                    Label("Comment", systemImage: "bubble.left")
                        .font(.ctw(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.nhan)
                .accessibilityIdentifier("feed.post.comment")
                if let u = DichBangTin.urlWeb(p.url) {
                    ShareLink(item: u) {
                        Label("Share", systemImage: "arrowshape.turn.up.right")
                            .font(.ctw(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.nhan)
                }
            }
            .labelStyle(NhanNutDayCTW())
            .padding(.horizontal, 6)
            if !chiTiet, let ds = p.comments, !ds.isEmpty {
                xemTruocBinhLuan(ds)
            }
        }
    }

    private func xemTruocBinhLuan(_ ds: [CTWFeedComment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let n = p.commentCount, n > ds.count {
                Button { hd.binhLuan(p) } label: {
                    Text("View all \(n) comments").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            ForEach(ds.suffix(2)) { c in
                Button { hd.binhLuan(p) } label: {
                    HStack(alignment: .top, spacing: 8) {
                        CTWAvatar(user: c.hiddenForMe == true ? nil : c.author, size: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            if c.hiddenForMe == true {
                                Text("Comment from someone you blocked").italic()
                                    .font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                            } else {
                                Text(c.author?.ten ?? "").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                Text(ChuBangTin.thuan(c.body ?? "")).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundSecondary))
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 12).padding(.top, 2)
    }

    // MARK: Bài tạm (đang đăng / hỏng)

    @ViewBuilder private var trangThaiTam: some View {
        HStack(spacing: 10) {
            if p.dangHong == true, let l = p.loiChan {
                // 1.2 — bộ lọc nội dung: câu của máy chủ tại chỗ, bản nháp giữ ⇒ "Sửa" (gửi lại y nguyên vô ích).
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(AppColors.error)
                        Text(l).font(.ctw(size: 13)).foregroundColor(AppColors.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("bangTin.loiChan")
                    }
                    HStack {
                        Spacer()
                        Button("Discard") { if let k = p.khoaTam { hd.boTam(k) } }.font(.ctw(size: 13))
                        Button("Edit") { hd.suaTam(p) }.font(.ctw(size: 13, weight: .semibold))
                            .buttonStyle(.borderedProminent).controlSize(.small)
                            .accessibilityIdentifier("bangTin.suaBiChan")
                    }
                }
            } else if p.dangHong == true {
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(AppColors.error)
                Text("Couldn't post").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.error)
                Spacer()
                Button("Discard") { if let k = p.khoaTam { hd.boTam(k) } }.font(.ctw(size: 13))
                Button("Retry") { if let k = p.khoaTam { hd.thuLai(k) } }.font(.ctw(size: 13, weight: .semibold))
                    .buttonStyle(.borderedProminent).controlSize(.small)
            } else {
                ProgressView().controlSize(.small)
                Text("Posting…").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                Spacer()
            }
        }
        .padding(14)
    }
}

/// Nhãn nút ở đáy thẻ: biểu tượng + chữ, chữ tự ẩn khi chỗ hẹp (Dynamic Type rất lớn).
struct NhanNutDayCTW: LabelStyle {
    @Environment(\.dynamicTypeSize) private var co
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            if co < .accessibility2 { configuration.title.lineLimit(1).minimumScaleFactor(0.8) }
        }
    }
}

// MARK: - Nút Thích + bảng 6 cảm xúc (giữ)

struct NutCamXucCTW: View {
    let trangThai: TrangThaiCamXuc
    var choPhep = true
    var nho = false
    let chon: (CamXucBangTin?) -> Void
    @State private var moBang = false
    @Environment(\.accessibilityReduceMotion) private var giam

    private var cua: CamXucBangTin? { trangThai.cuaToi.flatMap(CamXucBangTin.init(rawValue:)) }

    var body: some View {
        HStack(spacing: 6) {
            if let c = cua {
                Text(c.emoji).font(.ctw(size: nho ? 13 : 16))
                    .transition(.scale.combined(with: .opacity))
                Text(c.ten)
            } else {
                Image(systemName: "hand.thumbsup")
                Text("Like")
            }
        }
        .font(.ctw(size: nho ? 12 : 14, weight: .semibold))
        .foregroundColor(cua == nil ? AppColors.textSecondary : mau(cua!))
        .frame(maxWidth: nho ? nil : .infinity, minHeight: nho ? 30 : 44)
        .padding(.horizontal, nho ? 2 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            guard choPhep else { return }
            RungNhe.cham()
            withAnimation(giam ? nil : .spring(response: 0.3, dampingFraction: 0.6)) { chon(CamXucLogic.khiCham(trangThai)) }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard choPhep else { return }
            RungNhe.mem()
            moBang = true
        }
        .popover(isPresented: $moBang, arrowEdge: .bottom) {
            BangCamXucCTW(dangChon: cua) { k in
                moBang = false
                CTWRung.chon()
                chon(k == cua ? nil : k)
            }
            .presentationCompactAdaptation(.popover)
        }
        .opacity(choPhep ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(cua.map { Text("Reaction: \($0.ten)") } ?? Text("Like"))
        .accessibilityHint(Text("Double-tap to like. Use actions to choose another reaction."))
        .accessibilityAction { chon(CamXucLogic.khiCham(trangThai)) }
        .accessibilityActions {
            ForEach(CamXucBangTin.allCases) { k in
                Button(String(localized: "React with \(k.ten)")) { chon(k) }
            }
            if cua != nil { Button(String(localized: "Remove reaction")) { chon(nil) } }
        }
        .accessibilityIdentifier(nho ? "feed.comment.like" : "feed.post.like")
    }

    private func mau(_ k: CamXucBangTin) -> Color {
        switch k {
        case .like: return AppColors.primary
        case .love: return Color(red: 0.89, green: 0.2, blue: 0.33)
        case .celebrate: return AppColors.success
        default: return AppColors.warning
        }
    }
}

/// Dải 6 cảm xúc (popover) — bật lần lượt, phóng nhẹ khi nhấn.
struct BangCamXucCTW: View {
    let dangChon: CamXucBangTin?
    let chon: (CamXucBangTin) -> Void
    @State private var hien = false
    @Environment(\.accessibilityReduceMotion) private var giam

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(CamXucBangTin.allCases.enumerated()), id: \.element) { i, k in
                Button { chon(k) } label: {
                    Text(k.emoji)
                        .font(.system(size: 30))
                        .frame(width: 46, height: 50)
                        .background(Circle().fill(k == dangChon ? AppColors.primary.opacity(0.15) : .clear))
                        .scaleEffect(hien || giam ? 1 : 0.3)
                        .opacity(hien ? 1 : 0)
                        .animation(giam ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.55).delay(Double(i) * 0.03), value: hien)
                }
                .buttonStyle(KieuNutNhan(co: 1.25))
                .accessibilityLabel(Text(k.ten))
                .accessibilityIdentifier("feed.reaction.\(k.rawValue)")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .onAppear { hien = true }
    }
}
