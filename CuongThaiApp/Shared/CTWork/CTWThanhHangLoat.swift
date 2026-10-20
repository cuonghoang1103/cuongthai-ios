import SwiftUI

// MARK: - Thanh sửa hàng loạt (web `board/BulkBar.tsx`) — dùng chung Board · Backlog · List (21/10/2026)
//
// Nổi ở đáy màn khi đang chọn thẻ: số thẻ đã chọn · Trạng thái · Sprint · Giao · Ưu tiên · Nhãn · Epic · Xoá · bỏ chọn.
// Nút nào hiện theo cờ quyền của dự án (máy chủ vẫn kiểm lại). Mọi thay đổi đi `POST /issues/bulk` (`CTWHangLoat`):
// thẻ hỏng báo riêng, thẻ khác vẫn đi. Đổi trạng thái đi THEO TÊN (mỗi quy trình một id).
// Chạm tối thiểu 44 pt; hàng nút cuộn ngang trên iPhone (chữ `fixedSize` — bẫy cắt chữ).

struct CTWThanhHangLoat: View {
    let cauHinh: CTWProjectConfig
    let soChon: Int
    var dangGui = false
    /// Epic để gắn (nil ⇒ ẩn nút Epic).
    var epics: [(id: Int, so: Int, ten: String)]?
    let doiTrangThai: (String) -> Void
    /// `patch` của `POST /issues/bulk` + nhãn mô tả (cho câu báo kết quả).
    let sua: ([String: Any], String) -> Void
    var xoa: (() -> Void)?
    let boChon: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("\(soChon) selected")
                .font(.ctw(size: 14, weight: .semibold).monospacedDigit())
                .foregroundColor(AppColors.textPrimary)
                .fixedSize()
                .padding(.leading, 12)
            if dangGui { ProgressView().controlSize(.small).padding(.horizontal, 4) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) { cacNut }
                    .padding(.horizontal, 4)
            }
            .disabled(soChon == 0 || dangGui)
            Button(action: boChon) {
                Image(systemName: "xmark").font(.ctw(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppColors.textSecondary)
            .accessibilityLabel("Clear selection")
        }
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.backgroundCard)
            .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Bulk actions"))
    }

    private var quyen: CTWPermissions? { cauHinh.permissions }

    @ViewBuilder private var cacNut: some View {
        if quyen?.transition == true {
            Menu {
                ForEach(CTWHangLoat.tenTrangThai(cauHinh), id: \.name) { s in
                    Button { doiTrangThai(s.name) } label: {
                        Label { Text(verbatim: CTWTen.trangThaiCau(s.name)) } icon: { Image(systemName: CTWBoardView.bieuTuongNhom(s.category)) }
                    }
                }
            } label: { nut("Status", "circle.dashed") }
        }
        if quyen?.editIssues == true {
            if cauHinh.type != "KANBAN" {
                Menu {
                    ForEach((cauHinh.sprints ?? []).filter { $0.state != "CLOSED" }) { s in
                        Button {
                            sua(["sprintId": s.id], String(localized: "moved to \(s.name)"))
                        } label: {
                            if s.state == "ACTIVE" { Text("\(s.name) (active)") } else { Text(verbatim: s.name) }
                        }
                    }
                    Button { sua(["sprintId": NSNull()], String(localized: "moved to the backlog")) } label: { Label("Backlog", systemImage: "tray.full") }
                } label: { nut("Sprint", "arrow.left.arrow.right") }
            }
            Menu {
                Button { sua(["assigneeId": NSNull()], String(localized: "unassigned")) } label: { Label("Unassigned", systemImage: "person.crop.circle.badge.questionmark") }
                ForEach(cauHinh.nguoiGiaoDuoc) { u in
                    Button { sua(["assigneeId": u.id], String(localized: "assigned to \(u.ten)")) } label: {
                        if u.laAgent { Text("\(u.ten) · AI agent") } else { Text(verbatim: u.ten) }
                    }
                }
            } label: { nut("Assign", "person") }
            Menu {
                ForEach(CTW.doUuTien, id: \.so) { p in
                    Button { sua(["priority": p.so], String(localized: "priority set to \(p.ten)")) } label: { Label(p.ten, systemImage: p.bieuTuong) }
                }
            } label: { nut("Priority", "flag") }
            if !(cauHinh.labels ?? []).isEmpty {
                Menu {
                    ForEach(cauHinh.labels ?? []) { l in
                        Button { sua(["addLabelIds": [l.id]], String(localized: "labelled \(l.name)")) } label: { Text(verbatim: l.name) }
                    }
                } label: { nut("Label", "tag") }
            }
            if let epics {
                Menu {
                    Button { sua(["parentId": NSNull()], String(localized: "removed from epic")) } label: { Text("No epic") }
                    ForEach(epics, id: \.id) { e in
                        Button { sua(["parentId": e.id], String(localized: "added to \(e.ten)")) } label: { Text(verbatim: "\(cauHinh.key)-\(e.so) · \(e.ten)") }
                    }
                } label: { nut("Epic", "bolt") }
            }
        }
        if let xoa, quyen?.deleteIssues == true {
            Button(role: .destructive, action: xoa) { nut("Delete", "trash", mau: AppColors.error) }
                .buttonStyle(.plain)
        }
    }

    private func nut(_ ten: LocalizedStringKey, _ bieuTuong: String, mau: Color = AppColors.primary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: bieuTuong).font(.ctw(size: 13, weight: .semibold))
            Text(ten).font(.ctw(size: 13, weight: .medium)).fixedSize()
        }
        .foregroundColor(mau)
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// Câu báo kết quả sửa hàng loạt (web `backlog.bulkDone` / `bulkFailed`).
enum CTWBaoHangLoat {
    static func cau(_ kq: CTWKetQuaHangLoat, nhan: String, ma: String) -> (thanhCong: String?, loi: String?) {
        let ok = kq.updated?.count ?? 0
        let hong = kq.failed ?? []
        let tc: String? = ok == 0 ? nil : (ok == 1 ? String(localized: "1 issue \(nhan)") : String(localized: "\(ok) issues \(nhan)"))
        guard !hong.isEmpty else { return (tc, nil) }
        let ds = hong.prefix(3).map { "\(ma)-\($0.number) (\($0.error ?? ""))" }.joined(separator: ", ")
        return (tc, hong.count == 1 ? String(localized: "1 issue couldn't be changed: \(ds)") : String(localized: "\(hong.count) issues couldn't be changed: \(ds)"))
    }
}

/// Dải báo thành công ngắn (tự ẩn) — đặt ở đầu màn.
struct CTWDaiBao: View {
    let chu: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success)
            Text(chu).font(.ctw(size: 13, weight: .medium)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Capsule().fill(AppColors.backgroundCard).shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2))
        .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 0.5))
        .accessibilityAddTraits(.updatesFrequently)
    }
}
