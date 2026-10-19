import SwiftUI

// MARK: - Chi tiết một phê duyệt + ký duyệt / từ chối
//
// Quyền ký do MÁY CHỦ quyết (`canDecide`, `canCancel`) — app không tự suy từ vai
// trò. Từ chối bắt buộc có ý kiến (máy chủ trả `WORK_REJECT_REASON`, app chặn
// trước cho đỡ một vòng). Ý kiến của từng người duyệt là nội dung người dùng ⇒
// hiện bằng `CTWBinhLuanDong` (nhấn giữ: báo cáo / chặn — App Store 1.2).

struct ChiTietDuyetCTW: View {
    let pid: Int
    let id: Int
    @EnvironmentObject private var app: AppState
    @State private var a: CTWDuyet?
    @State private var loi: String?
    @State private var khoaSua = false
    @State private var yKien = ""
    @State private var hoi: Hoi?
    @State private var dangGui = false
    @State private var lyDoHuy = ""
    @FocusState private var dangGo: Bool

    private enum Hoi: Identifiable { case dongY, tuChoi, huy; var id: Int { hashValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if khoaSua { GovDaiKhoaSua(pid: pid) { khoaSua = false } }
                if let a {
                    dau(a)
                    if a.contentChanged == true || a.changedSinceRequest == true { canhBaoDoi(a) }
                    thongTin(a)
                    if let ev = a.evidence { bangChung(ev) }
                    cacBuoc(a)
                    if a.canDecide == true && a.dangCho { hopQuyetDinh(a) }
                    if a.canCancel == true && a.dangCho {
                        Button(role: .destructive) { hoi = .huy } label: {
                            Label("Cancel request", systemImage: "xmark.circle").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: true).padding(-Spacing.md)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.backgroundPrimary)
        .navigationTitle(a?.nhanDoiTuong ?? "Approval")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if a == nil { await tai() } }
        .confirmationDialog(tieuDeHoi, isPresented: Binding(get: { hoi != nil }, set: { if !$0 { hoi = nil } }), titleVisibility: .visible) {
            switch hoi {
            case .dongY: Button("Approve") { Task { await quyetDinh(true) } }
            case .tuChoi: Button("Reject", role: .destructive) { Task { await quyetDinh(false) } }
            case .huy: Button("Cancel request", role: .destructive) { Task { await huy() } }
            case nil: EmptyView()
            }
        } message: {
            switch hoi {
            case .dongY: Text("Your signature records the exact version you're approving.")
            case .tuChoi: Text("One rejection ends this request for everyone.")
            case .huy: Text("Pending approvers won't be able to sign it any more.")
            case nil: EmptyView()
            }
        }
    }

    private var tieuDeHoi: String {
        switch hoi {
        case .dongY: return "Approve “\(a?.title ?? "this")”?"
        case .tuChoi: return "Reject “\(a?.title ?? "this")”?"
        case .huy: return "Cancel this approval request?"
        case nil: return ""
        }
    }

    // MARK: Khối

    private func dau(_ a: CTWDuyet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CTWChipChu(chu: a.status)
                CTWNhanNho(chu: a.tuanTu ? "Sequential" : "Parallel", bieuTuong: a.tuanTu ? "arrow.down" : "arrow.left.and.right")
                Text("\(a.soDaDuyet) of \(a.dsBuoc.count) approved").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Text(a.title ?? "Approval").font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            CTWThanhPhanDoan(doan: [
                (a.soDaDuyet, AppColors.success),
                (a.dsBuoc.filter { $0.decision == "REJECTED" }.count, AppColors.error),
                (a.dsBuoc.filter { $0.decision == "PENDING" || $0.decision == nil }.count, AppColors.backgroundTertiary),
            ], cao: 6)
        }
    }

    private func canhBaoDoi(_ a: CTWDuyet) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.warning)
            Text(a.dangCho
                 ? "The content changed after this request was sent. Check the latest version before you sign."
                 : "The content changed after it was signed. The signature covers the earlier version.")
                .font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.warning.opacity(0.12)))
    }

    @ViewBuilder
    private func thongTin(_ a: CTWDuyet) -> some View {
        CTWKhoiTruong {
            doiTuong(a)
            Divider()
            CTWHangTruong(nhan: "Requested by", bieuTuong: "person") {
                HStack(spacing: 6) {
                    CTWAvatar(user: a.createdBy, size: 20)
                    Text(a.createdBy?.ten ?? "—")
                    if a.createdBy?.laAgent == true { CTWNhanAI() }
                }
            }
            Divider()
            CTWHangTruong("Requested", CTW.thoiDiem(a.createdAt), bieuTuong: "clock")
            if a.dueAt != nil {
                Divider()
                CTWHangTruong(nhan: "Due", bieuTuong: "calendar") {
                    Text(CTW.ngayNgan(a.dueAt) ?? "—").foregroundColor(a.quaHan ? AppColors.error : AppColors.textPrimary)
                }
            }
            if a.decidedAt != nil { Divider(); CTWHangTruong("Decided", CTW.thoiDiem(a.decidedAt), bieuTuong: "checkmark.circle") }
        }
        if let m = a.description?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            CTWSectionHeader("text.alignleft", "Description")
            CTWMarkdownView(markdown: m, coChu: 15)
                .padding(14).ctwThe(14)
                .ctwMenuBaoCaoChan(khoa: "approval-\(a.id)", noiDung: m, nguCanh: "Approval \(a.nhanDoiTuong)",
                                   tacGia: a.createdBy, laCuaToi: a.createdBy?.id == app.currentUser?.id)
        }
        if let n = a.clientNote?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            CTWSectionHeader("person.crop.rectangle", "Note for the client")
            Text(n).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(14).ctwThe(14)
        }
    }

    @ViewBuilder
    private func doiTuong(_ a: CTWDuyet) -> some View {
        let nhan = HStack(spacing: 6) {
            Image(systemName: a.bieuTuong).foregroundColor(AppColors.primary)
            Text(a.nhanDoiTuong).lineLimit(1)
        }
        if a.targetType == "DOC", let p = a.page {
            NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: p.number, ten: p.title ?? "Page")) {
                CTWHangTruong(nhan: "Document", bieuTuong: "link") { nhan }
            }.buttonStyle(.plain)
        } else if a.targetType == "CR", let c = a.changeRequest {
            NavigationLink(value: RouteCrCTW(pid: pid, so: c.number)) {
                CTWHangTruong(nhan: "Change request", bieuTuong: "link") { nhan }
            }.buttonStyle(.plain)
        } else if let i = a.issue {
            NavigationLink(value: CTWRoute.the(pid: pid, so: i.number)) {
                CTWHangTruong(nhan: a.targetType == "UAT" ? "UAT issue" : "Issue", bieuTuong: "link") { nhan }
            }.buttonStyle(.plain)
        } else {
            CTWHangTruong(nhan: a.targetType == "STAGE_GATE" ? "Stage" : "Target", bieuTuong: "scope") { nhan }
        }
    }

    @ViewBuilder
    private func bangChung(_ ev: CTWDuyetBangChung) -> some View {
        CTWSectionHeader("tray.full", "Gate evidence", count: ev.issueTotal.map { "\(ev.issueDone ?? 0)/\($0)" })
        VStack(alignment: .leading, spacing: 10) {
            if let c = ev.criteria {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: c.done == true ? "checkmark.circle.fill" : "circle").foregroundColor(c.done == true ? AppColors.success : AppColors.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exit criteria · \(c.key ?? "")").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        Text(c.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                        if let t = c.text, !t.isEmpty { Text(t).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(6) }
                    }
                }
                Divider()
            }
            if let t = ev.issueTotal, t > 0 {
                CTWThanhPhanDoan(doan: [(ev.issueDone ?? 0, AppColors.success), (t - (ev.issueDone ?? 0), AppColors.warning)], cao: 6)
            }
            ForEach(ev.issues ?? [], id: \.number) { i in
                NavigationLink(value: CTWRoute.the(pid: pid, so: i.number)) {
                    HStack(spacing: 8) {
                        Image(systemName: i.done == true ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundColor(i.done == true ? AppColors.success : AppColors.warning)
                        Text(i.key ?? "#\(i.number)").font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                        Text(i.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Spacer(minLength: 0)
                        if i.pinned == true { Image(systemName: "pin.fill").font(.ctw(size: 10)).foregroundColor(AppColors.textTertiary) }
                    }
                    .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
            ForEach(ev.pages ?? [], id: \.number) { p in
                NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: p.number, ten: p.title ?? "Page")) {
                    Label(p.title ?? "Page", systemImage: "doc.text").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            ForEach(ev.files ?? []) { f in
                Label(f.fileName ?? "File", systemImage: "paperclip").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
            }
            if let o = ev.openAtRequest, o > 0 {
                Text("\(o) issue\(o == 1 ? "" : "s") still open when requested\(ev.openReason.map { " — “\($0)”" } ?? "").")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.warning)
            }
        }
        .padding(14)
        .ctwThe(14)
    }

    @ViewBuilder
    private func cacBuoc(_ a: CTWDuyet) -> some View {
        CTWSectionHeader("person.2.badge.gearshape", "Approvers", count: "\(a.dsBuoc.count)")
        VStack(spacing: 10) {
            ForEach(Array(a.dsBuoc.enumerated()), id: \.element.id) { i, b in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        if a.tuanTu {
                            Text("\(i + 1)").font(.ctw(size: 12, weight: .bold)).foregroundColor(AppColors.textSecondary)
                                .frame(width: 22, height: 22).background(Circle().fill(AppColors.backgroundTertiary))
                        }
                        CTWAvatar(user: b.approver, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(b.approver?.ten ?? "Approver").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                if b.approverId == app.currentUser?.id { Text("(you)").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                            }
                            if let d = b.decidedAt {
                                Text(CTW.thoiDiem(d) + (CTWDuyet.bamNgan(b.contentHash).map { " · #\($0)" } ?? ""))
                                    .font(.ctw(size: 11).monospacedDigit()).foregroundColor(AppColors.textTertiary)
                            }
                        }
                        Spacer(minLength: 0)
                        if (b.decision == nil || b.decision == "PENDING"), let u = b.approverId, a.dangChoAi.contains(u) {
                            CTWNhanNho(chu: "Their turn", bieuTuong: "hourglass", mau: AppColors.warning)
                        } else {
                            CTWChipChu(chu: b.decision ?? "PENDING")
                        }
                    }
                    if let c = b.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
                        CTWBinhLuanDong(khoa: "approval-step-\(b.id)", tacGia: b.approver, noiDung: c, thoiDiem: b.decidedAt,
                                        nguCanh: "Approval \(a.nhanDoiTuong) — \(a.title ?? "")",
                                        dich: CTWDichBaoCao("approval_step", b.id))
                    }
                }
                .padding(12)
                .ctwThe(12)
            }
        }
    }

    private func hopQuyetDinh(_ a: CTWDuyet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CTWSectionHeader("signature", "Your decision")
            TextField("Comment (required to reject)", text: $yKien, axis: .vertical)
                .lineLimit(2...6)
                .focused($dangGo)
                .font(.ctw(size: 15))
                .padding(12)
                .ctwThe(12)
            HStack(spacing: 10) {
                Button {
                    if yKien.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        loi = "Add a comment explaining why you're rejecting."
                        dangGo = true
                        CTWRung.loi()
                    } else { hoi = .tuChoi }
                } label: {
                    Label("Reject", systemImage: "xmark").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.error)
                Button { hoi = .dongY } label: {
                    Group {
                        if dangGui { ProgressView().tint(AppColors.onPrimary) } else { Label("Approve", systemImage: "checkmark") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.success)
            }
            .disabled(dangGui)
        }
    }

    // MARK: Mạng

    private func tai() async {
        do { a = try await APIClient.shared.request(CTWAPI.duyet(pid: pid, id: id)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func quyetDinh(_ dongY: Bool) async {
        dangGui = true
        defer { dangGui = false }
        do {
            a = try await APIClient.shared.request(CTWAPI.quyetDinhDuyet(pid: pid, id: id, dongY: dongY, yKien: yKien))
            yKien = ""
            dangGo = false
            loi = nil
            CTWRung.thanhCong()
        } catch {
            CTWRung.loi()
            if GovLoi.laKhoaSua(error) { khoaSua = true } else { loi = CTW.loi(error) }
            // 409 (không tới lượt / đã quyết) ⇒ nạp lại để thấy trạng thái thật.
            if CTW.laXungDot(error) || GovLoi.ma(error) == "WORK_APPROVAL_NOT_YOUR_TURN" { await tai() }
        }
    }

    private func huy() async {
        do {
            a = try await APIClient.shared.request(CTWAPI.huyDuyet(pid: pid, id: id, lyDo: nil))
            CTWRung.thanhCong()
        } catch {
            if GovLoi.laKhoaSua(error) { khoaSua = true } else { loi = CTW.loi(error) }
        }
    }
}
