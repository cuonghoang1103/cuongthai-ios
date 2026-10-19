import SwiftUI

// MARK: - Nộp sản phẩm — mỗi thành viên đã nộp tệp cho thẻ nào, thẻ nào quá hạn
//
// Chỉ xem + điều hướng: chạm một thẻ ⇒ mở thẻ đó (đính kèm tệp ở màn chi tiết thẻ có sẵn).

struct NopSanPhamCTW: View {
    let pid: Int
    @EnvironmentObject private var app: AppState
    @State private var du: CTWNopSanPham?
    @State private var loi: String?
    @State private var mo: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let du {
                    cong(du)
                    if let t = du.totals {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                            CTWODem(so: "\(t.submitted ?? 0)/\(t.issues ?? 0)", nhan: "Issues with files", bieuTuong: "tray.and.arrow.up", mau: AppColors.success)
                            CTWODem(so: "\(t.files ?? 0)", nhan: "Files", bieuTuong: "paperclip")
                            CTWODem(so: "\(t.overdue ?? 0)", nhan: "Overdue", bieuTuong: "calendar.badge.exclamationmark", mau: AppColors.error)
                            CTWODem(so: "\(t.members ?? 0)", nhan: "Members", bieuTuong: "person.3", mau: AppColors.secondary)
                        }
                    }
                    let ms = du.members ?? []
                    if ms.isEmpty { CTWOTrong(bieuTuong: "tray", tieuDe: "Nothing assigned yet", moTa: "Issues with assignees appear here.") }
                    ForEach(ms) { m in thanhVien(m) }
                } else if loi == nil {
                    CTWKhungTai(soHang: 4).padding(.horizontal, -Spacing.md)
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Deliverables")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if du == nil { await tai() } }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "submit" else { return }
            app.dichCho = nil
        }
    }

    private func tai() async {
        do {
            du = try await APIClient.shared.request(CTWAPI.nopSanPham(pid: pid))
            loi = nil
            if mo.isEmpty, let ten = du?.members?.first(where: { $0.username == app.currentUser?.username })?.id { mo = [ten] }
        } catch { loi = DichVuLoi.cau(error) }
    }

    private func cong(_ d: CTWNopSanPham) -> some View {
        let bat = d.gate?.enabled == true
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: bat ? (d.gate?.mode == "hard" ? "lock.shield.fill" : "exclamationmark.shield.fill") : "shield")
                .font(.ctw(size: 18)).foregroundColor(bat ? AppColors.primary : AppColors.textTertiary)
            VStack(alignment: .leading, spacing: 3) {
                Text(bat ? (d.gate?.mode == "hard" ? "Files required to finish" : "Files recommended") : "No submission rule")
                    .font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text(bat
                     ? "Each issue\(d.gate?.typeKeys.map { " (\($0.joined(separator: ", ")))" } ?? "") needs at least \(d.gate?.minAttachments ?? 1) attached file\((d.gate?.minAttachments ?? 1) == 1 ? "" : "s")\(d.gate?.mode == "hard" ? " before it can move to Done." : ".")"
                     : "Issues can be finished without attaching files.")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12).ctwThe(12)
    }

    private func thanhVien(_ m: CTWNopSanPham.ThanhVien) -> some View {
        let dangMo = mo.contains(m.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { if dangMo { mo.remove(m.id) } else { mo.insert(m.id) } }
            } label: {
                HStack(spacing: 10) {
                    CTWAvatar(user: CTWUser(id: 0, username: m.username, fullName: m.name, kind: m.kind), size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(m.name ?? m.username ?? "Member").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            if m.kind == "AGENT" { CTWNhanAI() }
                        }
                        Text("\(m.submitted ?? 0)/\(m.total ?? 0) submitted · \(m.onTime ?? 0)/\(m.onTimeOf ?? 0) on time")
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if (m.overdue ?? 0) > 0 { CTWNhanNho(chu: "\(m.overdue ?? 0) overdue", mau: AppColors.error) }
                    Image(systemName: "chevron.down").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(dangMo ? 180 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(dangMo ? "Collapse" : "Expand")
            CTWThanhPhanDoan(doan: [(m.submitted ?? 0, AppColors.success), (max(0, (m.total ?? 0) - (m.submitted ?? 0)), Color.clear)], cao: 4)
                .padding(.horizontal, 12).padding(.bottom, dangMo ? 4 : 12)
            if dangMo {
                ForEach(m.items ?? []) { it in
                    Divider().padding(.leading, 12)
                    NavigationLink(value: CTWRoute.the(pid: pid, so: it.number)) {
                        HStack(spacing: 10) {
                            Image(systemName: it.submitted == true ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(it.submitted == true ? AppColors.success : AppColors.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(it.title).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                Text([it.key, it.status, it.dueDate.flatMap(CTW.ngayNgan).map { "due \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.ctw(size: 11)).foregroundColor(it.overdue == true ? AppColors.error : AppColors.textTertiary)
                            }
                            Spacer(minLength: 0)
                            Label("\(it.attachmentCount ?? 0)", systemImage: "paperclip").font(.ctw(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                                .accessibilityLabel("\(it.attachmentCount ?? 0) files")
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .ctwThe(14)
    }
}
