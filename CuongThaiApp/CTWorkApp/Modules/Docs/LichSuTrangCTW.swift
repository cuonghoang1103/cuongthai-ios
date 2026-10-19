import SwiftUI

// MARK: - Docs — LỊCH SỬ PHIÊN BẢN một trang (`/pages/:n/versions`)
//
// Danh sách ảnh chụp (mới nhất trước, máy chủ giữ tối đa 100; các lần lưu liên
// tiếp của cùng người trong 10 phút gộp làm một). Mở một bản ⇒ đọc nội dung bản đó,
// so với bản hiện tại (diff theo dòng do máy chủ tính), khôi phục (chủ trang/ADMIN).

struct LichSuTrangCTW: View {
    let pid: Int
    let so: Int
    let ten: String
    let quanLy: Bool
    @State private var ds: [CTWPageVersion]?
    @State private var loi: String?

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi) { self.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if let ds {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "clock.arrow.circlepath", tieuDe: "No saved versions yet",
                              moTa: "Versions appear as people edit the page.")
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(Array(ds.enumerated()), id: \.element.id) { i, v in
                        NavigationLink(value: RoutePhienBanTrangCTW(pid: pid, so: so, n: v.n, quanLy: quanLy)) {
                            hang(v, laMoiNhat: i == 0)
                        }
                    }
                } header: { if !ds.isEmpty { Text("\(ds.count) version\(ds.count == 1 ? "" : "s")") } }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if ds == nil && loi == nil { CTWKhungTai(soHang: 5) } }
        .navigationTitle("Version history")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if ds == nil { await tai() } }
    }

    private func hang(_ v: CTWPageVersion, laMoiNhat: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CTWAvatar(user: v.author, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("v\(v.n)").font(.ctw(size: 14, weight: .bold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                    CTWNhanNho(chu: Self.nhanKieu(v.kind), bieuTuong: Self.bieuTuongKieu(v.kind))
                    if laMoiNhat { CTWNhanNho(chu: "Latest", mau: AppColors.success) }
                }
                HStack(spacing: 4) {
                    Text(v.author?.ten ?? "Someone").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    if v.author?.laAgent == true { CTWNhanAI() }
                    Text("· \(CTW.thoiDiem(v.updatedAt ?? v.createdAt))").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
                if let n = v.note, !n.isEmpty {
                    Text(n).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if let c = v.chars {
                Text("\(c) chars").font(.ctw(size: 11).monospacedDigit()).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 3)
    }

    static func nhanKieu(_ k: String?) -> String {
        switch k {
        case "CREATE": return "Created"
        case "RESTORE": return "Restored"
        case "MANUAL": return "Saved version"
        default: return "Edit"
        }
    }
    static func bieuTuongKieu(_ k: String?) -> String {
        switch k {
        case "CREATE": return "plus"
        case "RESTORE": return "arrow.uturn.backward"
        case "MANUAL": return "bookmark.fill"
        default: return "pencil"
        }
    }

    private func tai() async {
        do { ds = try await APIClient.shared.request(CTWAPI.phienBanTrang(pid: pid, so: so)); loi = nil }
        catch { loi = CTW.loi(error) }
    }
}

// MARK: - Một phiên bản: đọc · so với hiện tại · khôi phục

struct PhienBanTrangCTW: View {
    let pid: Int
    let so: Int
    let n: Int
    let quanLy: Bool
    @Environment(\.dismiss) private var quayLai
    @State private var v: CTWPageVersion?
    @State private var so2: CTWPageCompare?
    @State private var cheDo = 0
    @State private var loi: String?
    @State private var hoiKhoiPhuc = false
    @State private var dangKhoiPhuc = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                Picker("View", selection: $cheDo) {
                    Text("This version").tag(0)
                    Text("Changes since").tag(1)
                }
                .pickerStyle(.segmented)
                if let v {
                    HStack(spacing: 8) {
                        CTWAvatar(user: v.author, size: 22)
                        Text(v.author?.ten ?? "Someone").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        if v.author?.laAgent == true { CTWNhanAI() }
                        Spacer()
                        Text(CTW.thoiDiem(v.updatedAt ?? v.createdAt)).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                    if cheDo == 0 {
                        Text(v.title ?? "").font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        CTWTipTapView(doc: v.contentJson, coChu: 15)
                    } else {
                        khoiSoSanh
                    }
                } else if loi == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Version \(n)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if quanLy {
                ToolbarItem(placement: .primaryAction) {
                    Button { hoiKhoiPhuc = true } label: {
                        if dangKhoiPhuc { ProgressView() } else { Label("Restore", systemImage: "arrow.uturn.backward") }
                    }
                }
            }
        }
        .confirmationDialog("Restore version \(n)?", isPresented: $hoiKhoiPhuc, titleVisibility: .visible) {
            Button("Restore this version") { Task { await khoiPhuc() } }
        } message: { Text("The current content is kept in history, so this can be undone.") }
        .task { if v == nil { await tai() } }
        .task(id: cheDo) { if cheDo == 1, so2 == nil { await taiSoSanh() } }
    }

    @ViewBuilder
    private var khoiSoSanh: some View {
        if let s = so2 {
            HStack(spacing: 12) {
                Label("\(s.added ?? 0) added", systemImage: "plus").foregroundColor(AppColors.success)
                Label("\(s.removed ?? 0) removed", systemImage: "minus").foregroundColor(AppColors.error)
            }
            .font(.ctw(size: 13, weight: .semibold))
            let dong = s.lines ?? []
            if dong.allSatisfy({ $0.op == "eq" }) {
                Text("No differences — this version matches the current page.").foregroundColor(AppColors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(dong.enumerated()), id: \.offset) { _, d in
                    HStack(alignment: .top, spacing: 6) {
                        Text(d.op == "add" ? "+" : (d.op == "del" ? "−" : " "))
                            .font(.ctw(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(d.op == "add" ? AppColors.success : (d.op == "del" ? AppColors.error : AppColors.textTertiary))
                            .frame(width: 12)
                        Text(d.text.isEmpty ? " " : d.text)
                            .font(.ctw(size: 13, design: .monospaced))
                            .foregroundColor(d.op == "eq" ? AppColors.textSecondary : AppColors.textPrimary)
                            .strikethrough(d.op == "del")
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(d.op == "add" ? AppColors.success.opacity(0.10) : (d.op == "del" ? AppColors.error.opacity(0.08) : Color.clear))
                }
            }
            .padding(.vertical, 6)
            .ctwThe(10)
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
        }
    }

    private func tai() async {
        do { v = try await APIClient.shared.request(CTWAPI.motPhienBan(pid: pid, so: so, n: n)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func taiSoSanh() async {
        do { so2 = try await APIClient.shared.request(CTWAPI.soPhienBan(pid: pid, so: so, tu: n)) }
        catch { loi = CTW.loi(error) }
    }

    private func khoiPhuc() async {
        dangKhoiPhuc = true
        defer { dangKhoiPhuc = false }
        do {
            let _: CTWPageDetail = try await APIClient.shared.request(CTWAPI.khoiPhucPhienBan(pid: pid, so: so, n: n))
            CTWRung.thanhCong()
            quayLai()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}
