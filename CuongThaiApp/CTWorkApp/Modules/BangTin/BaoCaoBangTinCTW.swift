import SwiftUI

// MARK: - Báo cáo bài / bình luận (App Store 1.2) + hàng chờ kiểm duyệt của quản trị
//
// `POST /feed/posts/:id/report` · `POST /feed/comments/:cid/report` `{reason, detail?}` — lý do theo hợp đồng
// (spam | harassment | hate | sexual | violence | other). Báo cáo xong ⇒ nội dung biến khỏi bảng tin của người báo cáo
// (máy chủ lọc lần tải sau, app ẩn ngay). Kèm công tắc "Chặn luôn" (chặn của site — `/messages/blocks`).

struct BaoCaoBangTinCTW: View {
    enum Dich: Equatable { case bai(Int), binhLuan(Int) }
    let dich: Dich
    let tacGia: CTWUser?
    var xong: () -> Void = {}

    @Environment(\.dismiss) private var dong
    @State private var lyDo: LyDoBaoCaoBangTin = .spam
    @State private var chiTiet = ""
    @State private var chanLuon = false
    @State private var dangGui = false
    @State private var loi: String?

    private var laBinhLuan: Bool { if case .binhLuan = dich { return true }; return false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $lyDo) {
                        ForEach(LyDoBaoCaoBangTin.allCases) { l in Text(l.ten).tag(l) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                    .accessibilityIdentifier("feed.report.reason")
                } header: {
                    laBinhLuan ? Text("Why are you reporting this comment?") : Text("Why are you reporting this post?")
                }
                Section("Details (optional)") {
                    TextField("What happened?", text: $chiTiet, axis: .vertical).lineLimit(3...6)
                }
                if let a = tacGia, !a.laAgent {
                    Section {
                        Toggle(isOn: $chanLuon) { Text("Also block \(a.ten)") }
                    } footer: {
                        Text("Reports go to the admins of this space and the CT Work moderation team, who review them within 24 hours. The author isn't told who reported them.")
                    }
                }
                if let loi { Section { CTWErrorBanner(text: loi) }.listRowBackground(Color.clear) }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangGui { ProgressView() } else {
                        Button("Send") { Task { await gui() } }.accessibilityIdentifier("feed.report.send")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func gui() async {
        dangGui = true; loi = nil
        defer { dangGui = false }
        let ct = chiTiet.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let ep: APIEndpoint
            switch dich {
            case .bai(let id): ep = CTWAPI.baoCaoBai(id, lyDo: lyDo.rawValue, chiTiet: ct)
            case .binhLuan(let id): ep = CTWAPI.baoCaoBinhLuan(id, lyDo: lyDo.rawValue, chiTiet: ct)
            }
            let _: CTWFeedDaBaoCao = try await APIClient.shared.request(ep)
            if chanLuon, let a = tacGia { try? await ModerationStore.shared.block(userId: a.id, reason: lyDo.rawValue) }
            CTWRung.thanhCong()
            xong()
            dong()
        } catch {
            CTWRung.loi()
            loi = BangTinLoi.chu(error)
        }
    }
}

// MARK: - Kiểm duyệt (quản trị không gian / dự án)

struct KiemDuyetBangTinCTW: View {
    @State private var trangThai = "OPEN"
    @State private var ds: [CTWFeedBaoCao] = []
    @State private var con: String?
    @State private var dangTai = false
    @State private var daTai = false
    @State private var loi: String?
    @State private var dangXuLy: Int?

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $trangThai) {
                    Text("Open").tag("OPEN")
                    Text("Resolved").tag("RESOLVED")
                    Text("Dismissed").tag("DISMISSED")
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            if let loi { CTWErrorBanner(text: loi) }
            if daTai && ds.isEmpty && loi == nil {
                CTWOTrong(bieuTuong: "checkmark.shield", tieuDe: String(localized: "No reports here"),
                          moTa: String(localized: "Reports from members about posts and comments in spaces you manage show up here."))
                    .listRowBackground(Color.clear)
            }
            ForEach(ds) { r in hang(r) }
            if con != nil {
                Button("Load more") { Task { await taiThem() } }.frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if dangTai && ds.isEmpty { CTWKhungTai(soHang: 3) } }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task(id: trangThai) { await tai() }
    }

    private func hang(_ r: CTWFeedBaoCao) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(LyDoBaoCaoBangTin(rawValue: r.reason ?? "")?.ten ?? (r.reason ?? ""))
                    .font(.ctw(size: 12, weight: .bold)).foregroundColor(AppColors.error)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(AppColors.error.opacity(0.12)))
                if (r.reportCount ?? 1) > 1 {
                    Text("\(r.reportCount ?? 1) reports").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Text(ThoiGianBangTin.nhan(r.createdAt)).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
            }
            HStack(spacing: 8) {
                CTWAvatar(user: r.target?.author, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.target?.author?.ten ?? "").font(.ctw(size: 13, weight: .semibold))
                    Text(r.target?.type == "comment" ? String(localized: "Comment") : String(localized: "Post"))
                        .font(.ctw(size: 11)).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Text(verbatim: [r.workspace?.name, r.project?.key].compactMap { $0 }.joined(separator: " › "))
                    .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
            }
            if let e = r.target?.excerpt, !e.isEmpty {
                Text(verbatim: e).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(4)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundSecondary))
            }
            if let d = r.detail, !d.isEmpty {
                Text("“\(d)”").font(.ctw(size: 13).italic()).foregroundColor(AppColors.textSecondary)
            }
            if r.status == "OPEN" {
                HStack(spacing: 10) {
                    Button(role: .destructive) { Task { await xuLy(r, go: true) } } label: {
                        Label("Remove content", systemImage: "eye.slash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(AppColors.error)
                    Button { Task { await xuLy(r, go: false) } } label: {
                        Label("Dismiss", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(dangXuLy == r.id)
                .controlSize(.regular)
            } else {
                Text(r.action == "remove" ? String(localized: "Removed") : String(localized: "Dismissed"))
                    .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false; daTai = true }
        do {
            let t: CTWFeedTrangBaoCao = try await APIClient.shared.request(CTWAPI.baoCaoBangTin(ws: nil, trangThai: trangThai, cursor: nil))
            ds = t.reports ?? []
            con = t.nextCursor
            loi = nil
        } catch { loi = BangTinLoi.chu(error) }
    }

    private func taiThem() async {
        guard let c = con else { return }
        if let t: CTWFeedTrangBaoCao = try? await APIClient.shared.request(CTWAPI.baoCaoBangTin(ws: nil, trangThai: trangThai, cursor: c)) {
            ds += t.reports ?? []
            con = t.nextCursor
        }
    }

    private func xuLy(_ r: CTWFeedBaoCao, go: Bool) async {
        dangXuLy = r.id
        defer { dangXuLy = nil }
        do {
            let _: CTWFeedBaoCao = try await APIClient.shared.request(CTWAPI.xuLyBaoCao(r.id, go: go))
            ds.removeAll { $0.id == r.id || ($0.target?.postId == r.target?.postId && $0.target?.commentId == r.target?.commentId) }
            if go, let pid = r.target?.postId, r.target?.commentId == nil { KhoBangTinCTW.shared.baiMat.send(pid) }
            CTWRung.thanhCong()
            await KhoBangTinCTW.shared.taiPhamVi()
        } catch {
            CTWRung.loi()
            loi = BangTinLoi.chu(error)
        }
    }
}
