import SwiftUI

// MARK: - Giảng dạy — sức khoẻ các nhóm đồ án (giảng viên)
//
// `GET /teaching/overview?q=` tính sẵn cho mỗi nhóm: thẻ mở/quá hạn, sprint, giai đoạn,
// đóng góp, hồ sơ FPT (R1–R7, T5x…) thiếu bao nhiêu, Q&A chưa trả lời, rủi ro, điểm,
// và một nhãn đỏ/vàng/xanh kèm lý do. Không có route chi tiết từng nhóm ⇒ màn chi
// tiết dựng từ chính hàng tổng quan.

struct GiangDayCTW: View {
    @State private var du: CTWTongQuanGiangDay?
    @State private var loi: String?
    @State private var tim = ""
    @State private var loc = "all"

    private var nhom: [CTWNhomGiangDay] {
        (du?.groups ?? []).filter { loc == "all" || $0.health?.status == loc }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let t = du?.totals {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        CTWODem(so: "\(t.groups ?? 0)", nhan: "Groups · \(t.students ?? 0) students", bieuTuong: "person.3")
                        CTWODem(so: "\(t.red ?? 0)", nhan: "Need attention", bieuTuong: "exclamationmark.octagon", mau: AppColors.error)
                        CTWODem(so: "\(t.overdue ?? 0)", nhan: "Overdue issues", bieuTuong: "calendar.badge.exclamationmark", mau: AppColors.warning)
                        CTWODem(so: "\(t.docsMissing ?? 0)", nhan: "Missing documents", bieuTuong: "doc.badge.ellipsis", mau: AppColors.secondary)
                    }
                    CTWThanhLoc(chip: [
                        CTWChipLoc(id: "all", nhan: "All", bat: loc == "all"),
                        CTWChipLoc(id: "red", nhan: "Red \(t.red ?? 0)", bieuTuong: "circle.fill", bat: loc == "red"),
                        CTWChipLoc(id: "amber", nhan: "Amber \(t.amber ?? 0)", bieuTuong: "circle.fill", bat: loc == "amber"),
                        CTWChipLoc(id: "green", nhan: "Green \(t.green ?? 0)", bieuTuong: "circle.fill", bat: loc == "green"),
                    ]) { loc = $0.id }
                        .padding(.horizontal, -Spacing.md)
                }
                if du != nil {
                    if nhom.isEmpty { CTWOTrong(bieuTuong: "person.3", tieuDe: "No groups match") }
                    LazyVStack(spacing: 10) {
                        ForEach(nhom) { g in
                            NavigationLink(value: RouteLopCTW.nhom(g)) { HangNhomGiangDay(g: g) }.buttonStyle(.plain)
                        }
                    }
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false).padding(.horizontal, -Spacing.md)
                }
            }
            .padding(Spacing.md)
            .dvBeRong(900)
        }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search groups or students")
        .refreshable { await tai() }
        .task(id: tim) {
            if !tim.isEmpty { try? await Task.sleep(nanoseconds: 350_000_000) }
            guard !Task.isCancelled else { return }
            await tai()
        }
    }

    private func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.tongQuanGiangDay(q: tim)); loi = nil } catch {
            if !Task.isCancelled { loi = DichVuLoi.cau(error) }
        }
    }
}

private func mauSK(_ s: String?) -> Color { CTWMauTrangThai.mau(CTWLopNhan.mauSucKhoe(s)) }

struct HangNhomGiangDay: View {
    let g: CTWNhomGiangDay
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(mauSK(g.health?.status)).frame(width: 10, height: 10)
                    .accessibilityLabel("Health: \(g.health?.status ?? "green")")
                Text(g.key ?? "").font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.textSecondary)
                Text(g.name ?? "Group").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                Spacer(minLength: 0)
                if let c = g.classCode { CTWNhanNho(chu: c) }
            }
            HStack(spacing: 12) {
                Label("\(g.issues?.open ?? 0) open", systemImage: "circle.dashed")
                Label("\(g.issues?.overdue ?? 0) overdue", systemImage: "calendar.badge.exclamationmark")
                    .foregroundColor((g.issues?.overdue ?? 0) > 0 ? AppColors.error : AppColors.textTertiary)
                Label("\(g.docsSubmitted ?? 0)/\(g.docsExpected ?? 0) docs", systemImage: "doc.text")
            }
            .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            if let s = g.sprint {
                HStack(spacing: 8) {
                    Text(s.name ?? "Sprint").font(.ctw(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    CTWThanhPhanDoan(doan: [(s.done ?? 0, s.atRisk == true ? AppColors.warning : AppColors.primary),
                                            (max(0, (s.total ?? 0) - (s.done ?? 0)), Color.clear)], cao: 5)
                    Text("\(s.done ?? 0)/\(s.total ?? 0)").font(.ctw(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textSecondary)
                }
            }
            if let r = g.health?.reasons, !r.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(r.enumerated()), id: \.offset) { _, x in
                            CTWNhanNho(chu: CTWNhomNhan.lyDo(x.code, n: x.n), mau: x.level == "red" ? AppColors.error : AppColors.warning)
                        }
                    }
                }
            }
        }
        .padding(14).ctwThe(14).contentShape(Rectangle())
    }
}

enum CTWNhomNhan {
    /// Mã lý do sức khoẻ nhóm → câu ngắn tiếng Anh (mã lạ ⇒ tự đổi dạng chữ).
    static func lyDo(_ c: String?, n: Int?) -> String {
        let so = n.map { "\($0) " } ?? ""
        switch c {
        case "OVERDUE": return "\(so)overdue"
        case "SPRINT_AT_RISK": return "Sprint at risk"
        case "SILENT_MEMBERS", "SILENT": return "\(so)silent members"
        case "DOCS_MISSING": return "\(so)docs missing"
        case "QNA_OPEN": return "\(so)open questions"
        case "HIGH_RISKS": return "\(so)high risks"
        default: return CTWMauTrangThai.nhan(c)
        }
    }
}

struct NhomGiangDayCTW: View {
    let n: CTWNhomGiangDay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: 8) {
                    CTWChipChu(chu: (n.health?.status ?? "green").capitalized, mau: mauSK(n.health?.status))
                    if let s = n.subject { CTWNhanNho(chu: s, mau: AppColors.primary) }
                    if let c = n.classCode { CTWNhanNho(chu: c) }
                    if let t = n.term { CTWNhanNho(chu: t) }
                }
                Text(n.name ?? "Group").font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                if let r = n.health?.reasons, !r.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(r.enumerated()), id: \.offset) { _, x in
                            Label(CTWNhomNhan.lyDo(x.code, n: x.n), systemImage: "exclamationmark.circle.fill")
                                .font(.ctw(size: 13)).foregroundColor(x.level == "red" ? AppColors.error : AppColors.warning)
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    CTWODem(so: "\(n.issues?.open ?? 0)", nhan: "Open issues", bieuTuong: "circle.dashed")
                    CTWODem(so: "\(n.issues?.overdue ?? 0)", nhan: "Overdue", bieuTuong: "calendar.badge.exclamationmark", mau: AppColors.error)
                    CTWODem(so: "\(n.issues?.done14 ?? 0)", nhan: "Done in 14 days", bieuTuong: "checkmark.circle", mau: AppColors.success)
                    CTWODem(so: "\(n.qna?.open ?? 0)", nhan: "Open questions", bieuTuong: "questionmark.bubble", mau: AppColors.secondary)
                }
                CTWKhoiTruong {
                    if let s = n.sprint {
                        CTWHangTruong("Sprint", "\(s.name ?? "") · \(s.done ?? 0)/\(s.total ?? 0) · \(s.daysLeft ?? 0) days left", bieuTuong: "arrow.triangle.2.circlepath")
                        Divider()
                    }
                    if let s = n.stage {
                        CTWHangTruong("Stage", "\(s.n ?? 0). \(s.name ?? "") (\(s.completed ?? 0)/\(s.total ?? 0) done)", bieuTuong: "flag.checkered")
                        Divider()
                    }
                    CTWHangTruong("Risks", "\(n.risks?.open ?? 0) open · \(n.risks?.high ?? 0) high", bieuTuong: "exclamationmark.shield")
                    Divider()
                    CTWHangTruong("Grades", "\(n.grades?.published ?? 0)/\(n.grades?.total ?? 0) published" + (n.grades?.latestMilestone.map { " · \($0)" } ?? ""), bieuTuong: "rosette")
                    if let c = n.contrib {
                        Divider()
                        CTWHangTruong("Last active", c.lastActiveDay.flatMap(CTW.ngayNgan) ?? "—", bieuTuong: "clock")
                    }
                }
                if let d = n.docs, !d.isEmpty {
                    CTWSectionHeader("doc.on.doc", "FPT documents", count: "\(n.docsSubmitted ?? 0)/\(n.docsExpected ?? 0)")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(d.keys.sorted(), id: \.self) { k in
                            let s = d[k] ?? "NA"
                            VStack(spacing: 3) {
                                Text(k).font(.ctw(size: 13, weight: .bold).monospaced()).foregroundColor(AppColors.textPrimary)
                                Text(s == "NA" ? "N/A" : CTWMauTrangThai.nhan(s)).font(.ctw(size: 10, weight: .semibold))
                                    .foregroundColor(s == "SUBMITTED" ? AppColors.success : (s == "MISSING" ? AppColors.error : AppColors.textSecondary))
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                if let ms = n.members, !ms.isEmpty {
                    CTWSectionHeader("person.3", "Members", count: "\(ms.count)")
                    VStack(spacing: 0) {
                        ForEach(ms) { m in
                            HStack(spacing: 10) {
                                CTWAvatar(user: CTWUser(id: m.id, username: m.username, fullName: m.name), size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.name ?? m.username ?? "Member").font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                                    if let sg = m.signals, !sg.isEmpty {
                                        Text(sg.map { CTWMauTrangThai.nhan($0) }.joined(separator: " · "))
                                            .font(.ctw(size: 11)).foregroundColor(AppColors.warning)
                                    }
                                }
                                Spacer(minLength: 0)
                                CTWNhanNho(chu: CTWMauTrangThai.nhan(m.role))
                            }
                            .padding(.vertical, 8)
                            if m.id != ms.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 12).ctwThe(14)
                }
                if let href = n.href {
                    Button { DinhTuyenCTW.mo(duongDan: href) } label: {
                        Label("Open project \(n.key ?? "")", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(n.key ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
    }
}
