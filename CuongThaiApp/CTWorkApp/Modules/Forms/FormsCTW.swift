import SwiftUI

// MARK: - Forms — danh sách form + câu trả lời (CHỈ ĐỌC trên máy)
//
// Soạn form (kéo thả trường, điều kiện hiện) là việc thiết kế — làm trên web.
// Trên máy: xem form nào đang mở, bao nhiêu câu trả lời, tóm tắt từng câu hỏi
// (đếm lựa chọn thành thanh ngang) và đọc từng câu trả lời — câu trả lời là của
// người ngoài ⇒ nhấn giữ để báo cáo (1.2).

struct RouteFormCTW: Hashable { var pid: Int; var form: CTWForm }

struct DsFormCTW: View {
    let pid: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var du: CTWDsForm?
    @State private var loi: String?
    @State private var biChan: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let b = biChan {
                    CTWOTrong(bieuTuong: "lock.shield", tieuDe: "Forms unavailable", moTa: b)
                } else {
                    if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                    if let ds = du?.forms {
                        if ds.isEmpty {
                            CTWOTrong(bieuTuong: "list.bullet.rectangle.portrait", tieuDe: "No forms yet",
                                      moTa: "Forms your team publishes collect requests that turn into issues automatically.")
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(ds) { f in
                                    NavigationLink(value: RouteFormCTW(pid: pid, form: f)) { hang(f) }.buttonStyle(.plain)
                                }
                            }
                        }
                    } else if loi == nil {
                        CTWKhungTai(soHang: 4, coAvatar: false).padding(.horizontal, -Spacing.md)
                    }
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Forms")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if du == nil { await tai() } }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "forms" else { return }
            defer { app.dichCho = nil }
            if du == nil { await tai() }
            if let ma = d.duongDan.phanCon.first,
               let f = du?.forms?.first(where: { $0.key == ma || "\($0.number ?? -1)" == ma }) {
                nganXep.duong.append(RouteFormCTW(pid: pid, form: f))
            }
        }
        #if DEBUG
        .task {
            if XemThuCTW.conCua("forms") == "detail", nganXep.duong.count <= 1 {
                if du == nil { await tai() }
                if let f = du?.forms?.first { nganXep.duong.append(RouteFormCTW(pid: pid, form: f)) }
            }
        }
        #endif
    }

    private func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.dsForm(pid: pid)); loi = nil } catch {
            if DichVuLoi.biChan(error) { biChan = DichVuLoi.cau(error) } else { loi = DichVuLoi.cau(error) }
        }
    }

    private func hang(_ f: CTWForm) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(f.key ?? "F-\(f.number ?? f.id)").font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(AppColors.textSecondary)
                    CTWChipChu(chu: f.status)
                    if f.access == "PUBLIC" { CTWNhanNho(chu: "Public", bieuTuong: "globe") }
                    else { CTWNhanNho(chu: "Members", bieuTuong: "person.2") }
                }
                Text(f.title).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                HStack(spacing: 8) {
                    Label("\(f.responses ?? 0) responses", systemImage: "tray.full").font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    if let l = CTWFormNhan.lyDoDong(f.closed) {
                        Text(l).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.warning)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
        }
        .padding(14)
        .ctwThe(14)
        .contentShape(Rectangle())
    }
}

// MARK: - Một form

struct FormCTW: View {
    let pid: Int
    let form: CTWForm
    @EnvironmentObject private var app: AppState
    @State private var tab = 0
    @State private var tl: CTWTraLoiForm?
    @State private var loi: String?

    private var truong: [CTWTruongForm] { tl?.form?.fields ?? form.fields ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                dau
                Picker("View", selection: $tab) {
                    Text("Summary").tag(0)
                    Text("Responses").tag(1)
                    Text("Questions").tag(2)
                }
                .pickerStyle(.segmented)
                switch tab {
                case 0: tomTat
                case 1: phanHoi
                default: cauHoi
                }
            }
            .padding(Spacing.md)
            .dvBeRong()
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(form.key ?? "Form")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let l = form.link, let u = URL(string: l) {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: u) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Share form link")
                }
            }
        }
        .refreshable { await tai() }
        .task { if tl == nil { await tai() } }
    }

    private func tai() async {
        do { tl = try await APIClient.shared.request(CTWAPI.traLoiForm(pid: pid, so: form.number ?? form.id)); loi = nil } catch {
            loi = DichVuLoi.cau(error)
        }
    }

    private var dau: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CTWChipChu(chu: form.status)
                CTWNhanNho(chu: form.access == "PUBLIC" ? "Anyone with the link" : "Signed-in members", bieuTuong: form.access == "PUBLIC" ? "globe" : "lock")
                if let l = CTWFormNhan.lyDoDong(form.closed) { CTWNhanNho(chu: l, mau: AppColors.warning) }
            }
            Text(form.title).font(.system(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let d = form.description, !d.isEmpty {
                Text(d).font(.system(size: 14)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                CTWODem(so: "\(tl?.total ?? form.responses ?? 0)", nhan: "Responses", bieuTuong: "tray.full")
                CTWODem(so: "\(truong.count)", nhan: "Questions", bieuTuong: "questionmark.circle", mau: AppColors.secondary)
                if let m = form.maxResponses { CTWODem(so: "\(m)", nhan: "Limit", bieuTuong: "gauge", mau: AppColors.accent) }
            }
        }
    }

    @ViewBuilder
    private var tomTat: some View {
        if let ds = tl?.summary {
            if ds.isEmpty { CTWOTrong(bieuTuong: "chart.bar", tieuDe: "No responses yet") }
            ForEach(ds) { s in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: CTWFormNhan.bieuTuong(s.kind)).foregroundColor(AppColors.primary).font(.system(size: 12))
                        Text(s.label ?? "Question").font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        Spacer(minLength: 0)
                        Text("\(s.answered ?? 0) answered").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    if let c = s.counts, !c.isEmpty {
                        let tong = max(1, c.reduce(0) { $0 + ($1.n ?? 0) })
                        ForEach(Array(c.enumerated()), id: \.offset) { _, d in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(d.option ?? "—").font(.system(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                    Spacer()
                                    Text("\(d.n ?? 0)").font(.system(size: 12, weight: .semibold).monospacedDigit())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                CTWThanhPhanDoan(doan: [(d.n ?? 0, AppColors.primary), (tong - (d.n ?? 0), Color.clear)], cao: 6)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } else if let a = s.average {
                        Text("Average \(String(format: "%.1f", a))" + (s.min.map { " · min \(CTWGiaTri.so($0).hienThi)" } ?? "")
                             + (s.max.map { " · max \(CTWGiaTri.so($0).hienThi)" } ?? ""))
                            .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    } else if let e = s.earliest {
                        Text("From \(CTW.ngayNgan(e) ?? e) to \(CTW.ngayNgan(s.latest) ?? s.latest ?? "")")
                            .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    } else if let m = s.samples, !m.isEmpty {
                        ForEach(Array(m.prefix(3).enumerated()), id: \.offset) { _, t in
                            Text("“\(t)”").font(.system(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(3)
                        }
                    }
                }
                .padding(14)
                .ctwThe(14)
            }
        } else if loi == nil {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        }
    }

    @ViewBuilder
    private var phanHoi: some View {
        if let ds = tl?.responses {
            if ds.isEmpty { CTWOTrong(bieuTuong: "tray", tieuDe: "No responses yet") }
            ForEach(ds) { r in
                let chu = truong.map { "\($0.label ?? $0.id): \(r.answers?[$0.id]?.hienThi ?? "")" }.joined(separator: "\n")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle").foregroundColor(AppColors.textSecondary)
                        Text(r.respondent ?? r.email ?? "Anonymous").font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(CTW.thoiDiem(r.createdAt)).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    ForEach(truong) { t in
                        let gt = r.answers?[t.id]?.hienThi ?? ""
                        if !gt.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.label ?? t.id).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                                Text(gt).font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if let so = r.issue?.number {
                        NavigationLink(value: CTWRoute.the(pid: pid, so: so)) {
                            Label(r.issue?.key ?? "Issue #\(so)", systemImage: "arrow.up.right.square")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(minHeight: 32)
                        }
                    }
                }
                .padding(14)
                .ctwThe(14)
                .ctwMenuBaoCaoChan(khoa: "form-response-\(r.id)", noiDung: chu,
                                   nguCanh: "\(app.cauHinhDuAn?.key ?? "") form \(form.key ?? "")", tacGia: nil, laCuaToi: false)
            }
            if (tl?.total ?? 0) > ds.count {
                Text("Showing the latest \(ds.count) of \(tl?.total ?? 0).").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            }
        } else if loi == nil {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        }
    }

    private var cauHoi: some View {
        VStack(spacing: 0) {
            ForEach(Array(truong.enumerated()), id: \.element.id) { i, t in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundColor(AppColors.primary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(AppColors.primary.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(t.label ?? t.id).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            if t.required == true { Text("*").foregroundColor(AppColors.error) }
                        }
                        if let h = t.help, !h.isEmpty { Text(h).font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }
                        if let o = t.options, !o.isEmpty {
                            Text(o.joined(separator: " · ")).font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: CTWFormNhan.bieuTuong(t.kind)).foregroundColor(AppColors.textTertiary).font(.system(size: 12))
                }
                .padding(.vertical, 10)
                if t.id != truong.last?.id { Divider() }
            }
        }
        .padding(.horizontal, 14)
        .ctwThe(14)
    }
}
