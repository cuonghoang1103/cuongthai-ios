import SwiftUI

// MARK: - Cổng khách — trang chủ dự án NHÌN TỪ PHÍA KHÁCH
//
// Khách (CLIENT): tiến độ giai đoạn, mốc phát hành, việc đang chờ mình, yêu cầu,
// phê duyệt, tài liệu đã chia sẻ, gửi yêu cầu mới. Đội dự án: cùng màn ở chế độ
// `?as=client` (chỉ đọc) để kiểm khách đang thấy gì — có dải nhắc rõ.

enum RoutePortalCTW: Hashable {
    case yeuCau(pid: Int, xemThu: Bool)
    case yeuCauCT(pid: Int, so: Int, xemThu: Bool)
    case duyet(pid: Int, xemThu: Bool)
    case taiLieu(pid: Int, xemThu: Bool)
    case trang(pid: Int, so: Int, xemThu: Bool)

    @MainActor @ViewBuilder
    var man: some View {
        switch self {
        case .yeuCau(let pid, let x): PortalYeuCauCTW(pid: pid, xemThu: x)
        case .yeuCauCT(let pid, let so, let x): PortalYeuCauCTCTW(pid: pid, so: so, xemThu: x)
        case .duyet(let pid, let x): PortalDuyetCTW(pid: pid, xemThu: x)
        case .taiLieu(let pid, let x): PortalTaiLieuCTW(pid: pid, xemThu: x)
        case .trang(let pid, let so, let x): PortalTrangCTW(pid: pid, so: so, xemThu: x)
        }
    }
}

struct PortalCTW: View {
    let pid: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tq: CTWPortalTongQuan?
    @State private var loi: String?
    @State private var biChan: String?
    @State private var taoMoi: TaoMoi?

    private struct TaoMoi: Identifiable { let id = 1 }

    /// Đội dự án luôn xem ở chế độ thử (chỉ đọc); khách xem thật.
    private var xemThu: Bool { app.cauHinhDuAn?.role != "CLIENT" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let b = biChan {
                    CTWOTrong(bieuTuong: "lock.shield", tieuDe: "Client portal unavailable", moTa: b)
                } else {
                    if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                    if let tq {
                        dau(tq)
                        menu(tq)
                        if let w = tq.waitingOnClient, !w.isEmpty { choKhach(w) }
                        if let s = tq.stages, !s.isEmpty { giaiDoan(s) }
                        if let m = tq.milestones, !m.isEmpty { mocPhatHanh(m) }
                    } else if loi == nil {
                        CTWKhungTai(soHang: 4, coAvatar: false).padding(.horizontal, -Spacing.md)
                    }
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .safeAreaInset(edge: .top, spacing: 0) { if xemThu && biChan == nil { DaiXemThuKhach() } }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Client portal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if tq?.viewer?.canSubmitRequest == true && !xemThu {
                ToolbarItem(placement: .primaryAction) {
                    Button { taoMoi = TaoMoi() } label: { Image(systemName: "plus") }.accessibilityLabel("New request")
                }
            }
        }
        .sheet(item: $taoMoi) { _ in
            TaoYeuCauPortal(pid: pid) { so in nganXep.duong.append(RoutePortalCTW.yeuCauCT(pid: pid, so: so, xemThu: false)) }
        }
        .refreshable { await tai() }
        .task { if tq == nil { await tai() } }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "portal" else { return }
            defer { app.dichCho = nil }
            switch d.duongDan.phanCon.first {
            case "requests":
                if let so = d.duongDan.phanCon.dropFirst().first.flatMap(Int.init) {
                    nganXep.duong.append(RoutePortalCTW.yeuCauCT(pid: pid, so: so, xemThu: xemThu))
                } else { nganXep.duong.append(RoutePortalCTW.yeuCau(pid: pid, xemThu: xemThu)) }
            case "approvals": nganXep.duong.append(RoutePortalCTW.duyet(pid: pid, xemThu: xemThu))
            case "documents": nganXep.duong.append(RoutePortalCTW.taiLieu(pid: pid, xemThu: xemThu))
            default: break
            }
        }
    }

    private func tai() async {
        do { tq = try await APIClient.shared.request(CTWAPI.portalTongQuan(pid: pid, xemThu: xemThu)); loi = nil } catch {
            if DichVuLoi.biChan(error) { biChan = DichVuLoi.cau(error) } else { loi = DichVuLoi.cau(error) }
        }
    }

    private func dau(_ t: CTWPortalTongQuan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t.project?.organization ?? t.project?.workspaceName ?? "").font(.ctw(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Text(t.project?.name ?? "Project").font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary)
            if let d = t.project?.description, !d.isEmpty {
                Text(d).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).lineLimit(3)
            }
            if let p = t.overallPercent {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Overall progress").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(Int(p.rounded()))%").font(.ctw(size: 13, weight: .bold).monospacedDigit()).foregroundColor(AppColors.primary)
                    }
                    CTWThanhPhanDoan(doan: [(Int(p.rounded()), AppColors.primary), (100 - Int(p.rounded()), Color.clear)], cao: 8)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 10) {
                CTWODem(so: "\(t.counts?.sharedOpen ?? 0)", nhan: "In progress", bieuTuong: "hammer")
                CTWODem(so: "\(t.counts?.sharedDone ?? 0)", nhan: "Delivered", bieuTuong: "checkmark.seal", mau: AppColors.success)
                CTWODem(so: "\(t.counts?.requestsOpen ?? 0)", nhan: "Open requests", bieuTuong: "tray", mau: AppColors.secondary)
            }
        }
    }

    private func menu(_ t: CTWPortalTongQuan) -> some View {
        VStack(spacing: 0) {
            dong("tray.full", "Requests", "What you asked for and its status", RoutePortalCTW.yeuCau(pid: pid, xemThu: xemThu))
            Divider().padding(.leading, 56)
            dong("checkmark.seal", "Approvals", "Sign-offs waiting for you", RoutePortalCTW.duyet(pid: pid, xemThu: xemThu),
                 dem: t.waitingOnClient?.count)
            Divider().padding(.leading, 56)
            dong("doc.richtext", "Documents & files", "Everything shared with you", RoutePortalCTW.taiLieu(pid: pid, xemThu: xemThu))
        }
        .ctwThe(14)
    }

    private func dong(_ icon: String, _ ten: String, _ phu: String, _ r: RoutePortalCTW, dem: Int? = nil) -> some View {
        NavigationLink(value: r) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ten).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text(phu).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
                if let dem, dem > 0 {
                    Text("\(dem)").font(.ctw(size: 12, weight: .bold)).foregroundColor(AppColors.onPrimary)
                        .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(AppColors.error))
                }
                Image(systemName: "chevron.right").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, 12).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choKhach(_ w: [CTWPortalTongQuan.ChoKhach]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("hourglass", xemThu ? "Waiting on the client" : "Waiting on you", count: "\(w.count)")
            ForEach(w) { x in
                NavigationLink(value: RoutePortalCTW.duyet(pid: pid, xemThu: xemThu)) {
                    HStack(spacing: 10) {
                        Image(systemName: x.kind == "UAT" ? "checklist.checked" : "signature").foregroundColor(AppColors.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.title ?? "Approval").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            Text(x.kind == "UAT" ? "Acceptance test" : "Approval").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if let d = x.dueAt {
                            Text("Due \(CTW.ngayNgan(d) ?? "")").font(.ctw(size: 12, weight: .semibold))
                                .foregroundColor(DichVuLoi.daQua(d) ? AppColors.error : AppColors.textSecondary)
                        }
                    }
                    .padding(12).ctwThe(12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func giaiDoan(_ s: [CTWPortalTongQuan.GiaiDoan]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("flag.checkered", "Project stages")
            VStack(spacing: 0) {
                ForEach(s) { g in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(g.status == "DONE" ? AppColors.success : (g.status == "NOT_STARTED" ? AppColors.backgroundTertiary : AppColors.primary))
                                .frame(width: 28, height: 28)
                            if g.status == "DONE" { Image(systemName: "checkmark").font(.ctw(size: 12, weight: .bold)).foregroundColor(.white) }
                            else { Text("\(g.n ?? 0)").font(.ctw(size: 12, weight: .bold)).foregroundColor(g.status == "NOT_STARTED" ? AppColors.textSecondary : .white) }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(g.name ?? "Stage").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                Spacer()
                                CTWChipChu(chu: g.status)
                            }
                            if let p = g.percent, g.status != "NOT_STARTED" {
                                CTWThanhPhanDoan(doan: [(Int(p.rounded()), CTWMauTrangThai.mau(g.status == "DONE" ? "DONE" : "IN_PROGRESS")),
                                                        (100 - Int(p.rounded()), Color.clear)], cao: 5)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    if g.id != s.last?.id { Divider().padding(.leading, 40) }
                }
            }
            .padding(.horizontal, 12)
            .ctwThe(14)
        }
    }

    private func mocPhatHanh(_ m: [CTWPortalTongQuan.MocPhatHanh]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("shippingbox", "Releases")
            VStack(spacing: 0) {
                ForEach(m) { x in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.name ?? "Release").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            Text("\(x.done ?? 0) of \(x.items ?? 0) items done" + (x.releaseDate.flatMap(CTW.ngayNgan).map { " · \($0)" } ?? ""))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        CTWChipChu(chu: x.status)
                    }
                    .padding(.vertical, 10)
                    if x.id != m.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 12)
            .ctwThe(14)
        }
    }
}

// MARK: - Yêu cầu

struct PortalYeuCauCTW: View {
    let pid: Int
    let xemThu: Bool
    @State private var loc = "all"
    @State private var ds: [CTWPortalYeuCau]?
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if xemThu { DaiXemThuKhach().clipShape(RoundedRectangle(cornerRadius: 10)) }
                CTWThanhLoc(chip: CTWPortal.locYeuCau.map { CTWChipLoc(id: $0.ma, nhan: $0.nhan, bat: loc == $0.ma) }) { loc = $0.id }
                    .padding(.horizontal, -Spacing.md)
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let ds {
                    if ds.isEmpty { CTWOTrong(bieuTuong: "tray", tieuDe: "No requests", moTa: "Shared work and your requests appear here.") }
                    LazyVStack(spacing: 10) {
                        ForEach(ds) { r in
                            NavigationLink(value: RoutePortalCTW.yeuCauCT(pid: pid, so: r.number, xemThu: xemThu)) { hang(r) }
                                .buttonStyle(.plain)
                        }
                    }
                } else if loi == nil { CTWKhungTai(soHang: 4, coAvatar: false).padding(.horizontal, -Spacing.md) }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task(id: loc) { await tai() }
    }

    private func tai() async {
        do {
            let r: CTWPortalDsYeuCau = try await APIClient.shared.request(CTWAPI.portalYeuCau(pid: pid, loc: loc, xemThu: xemThu))
            ds = r.items ?? []; loi = nil
        } catch { if !Task.isCancelled { loi = DichVuLoi.cau(error) } }
    }

    private func hang(_ r: CTWPortalYeuCau) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: CTW.bieuTuongLoai(key: r.type?.icon ?? r.type?.key))
                    .font(.ctw(size: 11, weight: .bold)).foregroundColor(CTW.mau(r.type?.color, macDinh: AppColors.primary))
                Text(r.key ?? "#\(r.number)").font(.ctw(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                if r.fromClient == true { CTWNhanNho(chu: r.mine == true ? "Yours" : "From client", bieuTuong: "person") }
                Spacer(minLength: 0)
                CTWChipChu(chu: r.status?.name, mau: r.status?.color.map { CTW.mau($0) } ?? CTW.mauNhom(r.status?.category))
            }
            Text(r.title).font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
            HStack(spacing: 12) {
                Label("\(r.replies ?? 0)", systemImage: "bubble.left").accessibilityLabel("\(r.replies ?? 0) replies")
                Label("\(r.files ?? 0)", systemImage: "paperclip").accessibilityLabel("\(r.files ?? 0) files")
                if let s = r.stage { Label(s, systemImage: "flag") }
                Spacer(minLength: 0)
                Text("Updated \(CTW.ngayNgan(r.updatedAt) ?? "")")
            }
            .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
        }
        .padding(14).ctwThe(14).contentShape(Rectangle())
    }
}

struct PortalYeuCauCTCTW: View {
    let pid: Int
    let so: Int
    let xemThu: Bool
    @EnvironmentObject private var app: AppState
    @State private var ct: CTWPortalYeuCauCT?
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if xemThu { DaiXemThuKhach().clipShape(RoundedRectangle(cornerRadius: 10)) }
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let c = ct {
                    HStack(spacing: 6) {
                        Text(c.key ?? "#\(c.number)").font(.ctw(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                        Spacer()
                        CTWChipChu(chu: c.status?.name, mau: c.status?.color.map { CTW.mau($0) } ?? CTW.mauNhom(c.status?.category))
                    }
                    Text(c.title).font(.ctw(size: 21, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    CTWKhoiTruong {
                        CTWHangTruong("Type", c.type?.name, bieuTuong: "tag")
                        Divider()
                        CTWHangTruong("Priority", CTW.uuTien(c.priority).ten, bieuTuong: "flag")
                        if let s = c.stage { Divider(); CTWHangTruong("Stage", "\(s.n.map { "\($0). " } ?? "")\(s.name ?? "")", bieuTuong: "flag.checkered") }
                        if let v = c.fixVersion { Divider(); CTWHangTruong("Release", v.name, bieuTuong: "shippingbox") }
                        if let d = c.dueDate { Divider(); CTWHangTruong("Due", CTW.ngayNgan(d), bieuTuong: "calendar") }
                        Divider()
                        CTWHangTruong("Requested", DichVuLoi.luc(c.createdAt), bieuTuong: "clock")
                    }
                    if let d = c.descriptionJson, !d.chuTron.isEmpty {
                        CTWTipTapView(doc: d, coChu: 15).padding(14).ctwThe(12)
                    }
                    if let f = c.attachments, !f.isEmpty {
                        CTWSectionHeader("paperclip", "Files", count: "\(f.count)")
                        VStack(spacing: 0) {
                            ForEach(f) { a in
                                HStack(spacing: 10) {
                                    Image(systemName: a.bieuTuong).foregroundColor(AppColors.primary).frame(width: 22)
                                    Text(a.fileName ?? "File").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if a.deliverable == true { CTWNhanNho(chu: "Deliverable", mau: AppColors.success) }
                                }
                                .padding(.vertical, 10)
                                if a.id != f.last?.id { Divider() }
                            }
                        }
                        .padding(.horizontal, 12).ctwThe(12)
                    }
                    CTWSectionHeader("bubble.left.and.bubble.right", "Conversation", count: "\(c.comments?.count ?? 0)")
                    ForEach(c.comments ?? []) { b in DongBinhLuanTheCTW(pid: pid, so: so, c: b) }
                    if (c.comments ?? []).isEmpty {
                        Text("No replies yet.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    if !xemThu {
                        CTWHopSoan(goiY: "Write a reply…", nutGui: "Send reply") { chu in
                            do {
                                let m: CTWComment = try await APIClient.shared.request(CTWAPI.dvGuiBinhLuan(pid: pid, so: so, chu: chu, congKhai: nil))
                                ct?.comments = (ct?.comments ?? []) + [m]
                                return true
                            } catch { loi = DichVuLoi.cau(error); return false }
                        }
                    }
                } else if loi == nil { CTWKhungTai(soHang: 3, coAvatar: false).padding(.horizontal, -Spacing.md) }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(ct?.key ?? "Request")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if ct == nil { await tai() } }
    }

    private func tai() async {
        do { ct = try await APIClient.shared.request(CTWAPI.portalYeuCauCT(pid: pid, so: so, xemThu: xemThu)); loi = nil } catch {
            loi = DichVuLoi.cau(error)
        }
    }
}

// MARK: - Phê duyệt của khách

struct PortalDuyetCTW: View {
    let pid: Int
    let xemThu: Bool
    @State private var ds: [CTWPortalDuyet]?
    @State private var loi: String?
    @State private var quyet: CTWPortalDuyet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if xemThu { DaiXemThuKhach().clipShape(RoundedRectangle(cornerRadius: 10)) }
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let ds {
                    if ds.isEmpty { CTWOTrong(bieuTuong: "checkmark.seal", tieuDe: "Nothing to approve", moTa: "Sign-off requests for you appear here.") }
                    ForEach(ds) { d in the(d) }
                } else if loi == nil { CTWKhungTai(soHang: 3, coAvatar: false).padding(.horizontal, -Spacing.md) }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Approvals")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if ds == nil { await tai() } }
        .sheet(item: $quyet) { d in
            QuyetDuyetPortal(pid: pid, d: d) { await tai() }
        }
    }

    private func tai() async {
        do {
            let r: CTWPortalDsDuyet = try await APIClient.shared.request(CTWAPI.portalDuyet(pid: pid, xemThu: xemThu))
            ds = r.items ?? []; loi = nil
        } catch { loi = DichVuLoi.cau(error) }
    }

    private func the(_ d: CTWPortalDuyet) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                CTWNhanNho(chu: d.targetType == "UAT" ? "Acceptance test" : CTWMauTrangThai.nhan(d.targetType),
                           bieuTuong: d.targetType == "UAT" ? "checklist.checked" : "signature", mau: AppColors.primary)
                if d.waitingOnClient == true { CTWNhanNho(chu: "Your turn", mau: AppColors.warning) }
                if d.contentChanged == true { CTWNhanNho(chu: "Changed since sign-off", bieuTuong: "exclamationmark.triangle", mau: AppColors.warning) }
                Spacer(minLength: 0)
                CTWChipChu(chu: d.status)
            }
            Text(d.title ?? "Approval").font(.ctw(size: 16, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let m = d.description, !m.isEmpty {
                Text(m).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(4)
            }
            if let n = d.clientNote, !n.isEmpty {
                Text(n).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.primary.opacity(0.07)))
            }
            VStack(spacing: 6) {
                ForEach(d.steps ?? []) { b in
                    HStack(spacing: 8) {
                        CTWAvatar(user: b.approver, size: 22)
                        Text(b.approver?.ten ?? "Approver").font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        if b.isClient == true { CTWNhanNho(chu: "Client") }
                        Spacer(minLength: 0)
                        CTWChipChu(chu: b.decision)
                    }
                    if let c = b.comment, !c.isEmpty {
                        Text("“\(c)”").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 30)
                    }
                }
            }
            if let dd = d.dueAt {
                Text("Due \(CTW.ngayNgan(dd) ?? "")").font(.ctw(size: 12, weight: .semibold))
                    .foregroundColor(DichVuLoi.daQua(dd) && d.status == "PENDING" ? AppColors.error : AppColors.textTertiary)
            }
            if d.canDecide == true && !xemThu {
                Button { quyet = d } label: { Text("Review & decide").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14).ctwThe(14)
    }
}

/// Bảng quyết định (đồng ý / từ chối + ý kiến). Từ chối BẮT BUỘC có ý kiến (máy chủ cũng đòi).
private struct QuyetDuyetPortal: View {
    let pid: Int
    let d: CTWPortalDuyet
    let xong: () async -> Void
    @Environment(\.dismiss) private var dong
    @State private var yKien = ""
    @State private var dangGui = false
    @State private var loi: String?
    @State private var hoi: Bool?

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(d.title ?? "Approval").font(.headline) }
                if d.contentChanged == true {
                    Section { Label("The content changed after it was sent for approval. Review it before deciding.", systemImage: "exclamationmark.triangle")
                        .foregroundColor(AppColors.warning) }
                }
                Section("Comment") {
                    TextField("Add a comment (required to reject)", text: $yKien, axis: .vertical).lineLimit(3...8)
                }
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
                Section {
                    Button { hoi = true } label: { Label("Approve", systemImage: "checkmark.seal.fill") }
                        .disabled(dangGui)
                    Button(role: .destructive) { hoi = false } label: { Label("Reject", systemImage: "xmark.octagon") }
                        .disabled(dangGui || yKien.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Your decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
            .confirmationDialog(hoi == true ? "Approve this?" : "Reject this?",
                                isPresented: Binding(get: { hoi != nil }, set: { if !$0 { hoi = nil } }), titleVisibility: .visible) {
                Button(hoi == true ? "Approve" : "Reject", role: hoi == true ? nil : .destructive) {
                    let ok = hoi == true
                    Task { await gui(ok) }
                }
            } message: { Text("Your decision is recorded with the time and the content version you saw.") }
        }
    }

    private func gui(_ dongY: Bool) async {
        dangGui = true
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(CTWAPI.portalQuyet(pid: pid, d: d, dongY: dongY,
                                                               yKien: yKien.trimmingCharacters(in: .whitespacesAndNewlines)))
            CTWRung.thanhCong()
            await xong()
            dong()
        } catch { loi = DichVuLoi.cau(error); CTWRung.loi() }
    }
}

// MARK: - Tài liệu đã chia sẻ

struct PortalTaiLieuCTW: View {
    let pid: Int
    let xemThu: Bool
    @State private var du: CTWPortalTaiLieu?
    @State private var loi: String?

    var body: some View {
        List {
            if xemThu { DaiXemThuKhach().listRowInsets(EdgeInsets()) }
            if let loi { Text(loi).foregroundColor(AppColors.error) }
            if let du {
                Section("Documents") {
                    if (du.pages ?? []).isEmpty { Text("No documents shared yet.").foregroundColor(AppColors.textSecondary) }
                    ForEach(du.pages ?? []) { p in
                        NavigationLink(value: RoutePortalCTW.trang(pid: pid, so: p.number, xemThu: xemThu)) {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.richtext").foregroundColor(AppColors.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.title).foregroundColor(AppColors.textPrimary)
                                    Text("\(CTWMauTrangThai.nhan(p.status)) · Updated \(CTW.ngayNgan(p.updatedAt) ?? "")")
                                        .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                }
                Section("Files") {
                    if (du.files ?? []).isEmpty { Text("No files shared yet.").foregroundColor(AppColors.textSecondary) }
                    ForEach(du.files ?? []) { f in
                        HStack(spacing: 10) {
                            Image(systemName: (f.mime ?? "").hasPrefix("image/") ? "photo" : "doc").foregroundColor(AppColors.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.fileName ?? "File").foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Text([f.issue?.key, f.size.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
            } else if loi == nil { ProgressView().frame(maxWidth: .infinity) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Documents & files")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if du == nil { await tai() } }
    }

    private func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.portalTaiLieu(pid: pid, xemThu: xemThu)); loi = nil } catch { loi = DichVuLoi.cau(error) }
    }
}

struct PortalTrangCTW: View {
    let pid: Int
    let so: Int
    let xemThu: Bool
    @State private var t: CTWPortalTrang?
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) }
                if let t {
                    Text(t.title).font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    HStack(spacing: 6) {
                        CTWChipChu(chu: t.status)
                        Text("Updated \(CTW.ngayNgan(t.updatedAt) ?? "")").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                    CTWTipTapView(doc: t.contentJson, coChu: 15.5)
                } else if loi == nil { ProgressView().frame(maxWidth: .infinity).padding(.top, 40) }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(t?.title ?? "Document")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { t = try await APIClient.shared.request(CTWAPI.portalTrang(pid: pid, so: so, xemThu: xemThu)) } catch { loi = DichVuLoi.cau(error) }
        }
    }
}

// MARK: - Gửi yêu cầu mới (chỉ khách)

private struct TaoYeuCauPortal: View {
    let pid: Int
    let mo: (Int) -> Void
    @Environment(\.dismiss) private var dong
    @State private var loai = "BUG"
    @State private var tieuDe = ""
    @State private var moTa = ""
    @State private var uuTien = 3
    @State private var dangGui = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("What do you need?") {
                    Picker("Type", selection: $loai) {
                        ForEach(CTWPortal.loaiYeuCau, id: \.ma) { l in Label(l.nhan, systemImage: l.bieuTuong).tag(l.ma) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Details") {
                    TextField("Short summary", text: $tieuDe)
                    TextField("Describe it — steps, links, what you expected…", text: $moTa, axis: .vertical).lineLimit(4...12)
                    Picker("Priority", selection: $uuTien) {
                        ForEach(CTW.doUuTien, id: \.so) { p in Text(p.ten).tag(p.so) }
                    }
                }
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
            }
            .navigationTitle("New request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dangGui = true
                        Task {
                            do {
                                let r: CTWPortalTaoYeuCau = try await APIClient.shared.request(CTWAPI.portalTaoYeuCau(
                                    pid: pid, loai: loai, tieuDe: tieuDe.trimmingCharacters(in: .whitespacesAndNewlines),
                                    moTa: moTa.trimmingCharacters(in: .whitespacesAndNewlines), uuTien: uuTien))
                                CTWRung.thanhCong()
                                dong()
                                if let so = r.number { mo(so) }
                            } catch { loi = DichVuLoi.cau(error); CTWRung.loi() }
                            dangGui = false
                        }
                    } label: { if dangGui { ProgressView() } else { Text("Send").bold() } }
                    .disabled(dangGui || tieuDe.trimmingCharacters(in: .whitespaces).count < 3)
                }
            }
        }
    }
}
