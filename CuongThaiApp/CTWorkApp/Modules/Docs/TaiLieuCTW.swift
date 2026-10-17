import SwiftUI

// MARK: - Tài liệu (Docs) — CHỈ ĐỌC + tìm
//
// `GET /projects/:pid/pages` trả danh sách PHẲNG (có `parentId`, `position`)
// ⇒ app tự dựng cây. Đọc trang bằng `/pages/:n/markdown` (dựng bằng
// `CTWMarkdownView`), tìm bằng `/pages/search?q=` (≥ 2 ký tự).
// Mô-đun Docs tắt ở dự án ⇒ máy chủ trả 403 MODULE_DISABLED — nói rõ, không
// hiện màn trống.

@MainActor
final class TaiLieuVM: ObservableObject {
    let pid: Int
    @Published var ds: [CTWPageSummary]?
    @Published var ketQuaTim: [CTWPageHit]?
    @Published var loi: String?
    @Published var tatMoDun = false

    init(pid: Int) { self.pid = pid }

    func tai() async {
        do {
            let r: CTWPagesList = try await APIClient.shared.request(CTWAPI.dsTrang(pid: pid))
            ds = r.pages ?? []
            loi = nil
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" { tatMoDun = true; return }
            loi = CTW.loi(error)
        }
    }

    func tim(_ q: String) async {
        let t = q.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { ketQuaTim = nil; return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        do { ketQuaTim = try await APIClient.shared.request(CTWAPI.timTrang(pid: pid, q: t)) } catch {
            if !Task.isCancelled { loi = CTW.loi(error) }
        }
    }

    /// Cây phẳng hoá: (trang, độ sâu), theo thứ tự `position`.
    var cay: [(trang: CTWPageSummary, sau: Int)] {
        let tatCa = (ds ?? []).filter { $0.status != "ARCHIVED" }
        let ids = Set(tatCa.map(\.id))
        var con: [Int: [CTWPageSummary]] = [:]
        for p in tatCa {
            let cha = p.parentId.flatMap { ids.contains($0) ? $0 : nil } ?? 0
            con[cha, default: []].append(p)
        }
        var out: [(CTWPageSummary, Int)] = []
        func di(_ cha: Int, _ sau: Int) {
            for p in (con[cha] ?? []).sorted(by: { ($0.position ?? 0, $0.id) < ($1.position ?? 0, $1.id) }) {
                out.append((p, sau))
                if sau < 8 { di(p.id, sau + 1) }
            }
        }
        di(0, 0)
        return out.map { (trang: $0.0, sau: $0.1) }
    }
}

/// Route con của mô-đun Docs (đăng ký ở `MoDunDocs.swift`).
struct RouteTaiLieuCTW: Hashable {
    var pid: Int
    var so: Int
    var ten: String
}

struct TaiLieuCTW: View {
    let pid: Int
    @StateObject private var vm: TaiLieuVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: TaiLieuVM(pid: pid))
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if vm.tatMoDun {
                trong("doc.text.magnifyingglass", "Docs are turned off", "A project admin can turn Docs on in project settings.")
                    .listRowBackground(Color.clear)
            } else if let kq = vm.ketQuaTim {
                Section("Results") {
                    if kq.isEmpty { Text("No pages match “\(tim)”.").foregroundColor(AppColors.textSecondary) }
                    ForEach(kq) { h in
                        NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: h.number, ten: h.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(h.title).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                                if let s = h.snippet, !s.isEmpty {
                                    Text(s.replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else if let _ = vm.ds {
                let cay = vm.cay
                if cay.isEmpty {
                    trong("doc.text", "No pages yet", "Pages your team writes on the web show up here to read on the go.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(cay, id: \.trang.id) { m in
                            NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: m.trang.number, ten: m.trang.title)) {
                                HStack(spacing: 10) {
                                    Image(systemName: m.sau == 0 ? "doc.text.fill" : "doc.text")
                                        .foregroundColor(AppColors.primary).frame(width: 20)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(m.trang.title).font(.system(size: 15)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                                        HStack(spacing: 6) {
                                            Text(CTWDocStatus.ten(m.trang.status)).font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(m.trang.status == "APPROVED" ? AppColors.success : AppColors.textSecondary)
                                            if m.trang.aiAssisted == true { CTWNhanAI(chu: "AI-assisted") }
                                            if let d = CTW.ngayNgan(m.trang.updatedAt) {
                                                Text("Updated \(d)").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, CGFloat(min(m.sau, 4)) * 14)
                                .padding(.vertical, 2)
                            }
                        }
                    } header: { Text("Pages") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.ds == nil && vm.loi == nil && !vm.tatMoDun { CTWKhungTai(soHang: 5, coAvatar: false) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search pages")
        .task(id: tim) { await vm.tim(tim) }
        .navigationTitle("Docs")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if vm.ds == nil { await vm.tai() } }
        // Đích `/work/<ws>/<KEY>/docs/<số trang>` ⇒ mở trang.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "docs" else { return }
            defer { app.dichCho = nil }
            if let so = d.duongDan.phanCon.first.flatMap(Int.init) {
                nganXep.duong.append(RouteTaiLieuCTW(pid: pid, so: so, ten: "Page"))
            }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.man?.lowercased() == "trang", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteTaiLieuCTW(pid: pid, so: 3, ten: "Release plan — v1.0"))
            }
        }
        #endif
    }

    private func trong(_ icon: String, _ tieuDe: String, _ moTa: String) -> some View {
        CTWOTrong(bieuTuong: icon, tieuDe: tieuDe, moTa: moTa)
    }
}

// MARK: - Đọc một trang

struct TrangTaiLieuCTW: View {
    let pid: Int
    let so: Int
    let ten: String
    @State private var md: String?
    @State private var chiTiet: CTWPageDetail?
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) }
                if let c = chiTiet {
                    if let anc = c.ancestors, !anc.isEmpty {
                        Text(anc.map(\.title).joined(separator: " › "))
                            .font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                    }
                    Text(c.title).font(.system(size: 26, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 8) {
                        Text(CTWDocStatus.ten(c.status)).font(.system(size: 11, weight: .bold))
                            .foregroundColor(c.status == "APPROVED" ? AppColors.success : AppColors.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.backgroundTertiary))
                        if c.aiAssisted == true { CTWNhanAI(chu: "AI-assisted") }
                        if let u = c.lastEditedBy ?? c.owner {
                            CTWAvatar(user: u, size: 18)
                            Text(u.ten).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                            if u.laAgent { CTWNhanAI() }
                        }
                        if let d = CTW.ngayNgan(c.updatedAt) {
                            Text("· \(d)").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                if let md {
                    CTWMarkdownView(markdown: md, coChu: 15.5)
                } else if loi == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
                if let con = chiTiet?.children, !con.isEmpty {
                    CTWSectionHeader("doc.on.doc", "Subpages", count: "\(con.count)").padding(.top, 8)
                    VStack(spacing: 0) {
                        ForEach(con) { c in
                            NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: c.number, ten: c.title)) {
                                HStack {
                                    Image(systemName: "doc.text").foregroundColor(AppColors.primary)
                                    Text(c.title).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if c.id != con.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 14)
                    .ctwThe(12)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(chiTiet?.title ?? ten)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if md == nil { await tai() } }
    }

    private func tai() async {
        do {
            async let a: CTWPageMarkdown = APIClient.shared.request(CTWAPI.trangMarkdown(pid: pid, so: so))
            async let b: CTWPageDetail? = try? APIClient.shared.request(CTWAPI.trang(pid: pid, so: so))
            let (m, c) = try await (a, b)
            var chu = m.markdown ?? ""
            // Markdown mở đầu bằng "# Tiêu đề" — tiêu đề đã ở thanh trên, bỏ dòng trùng.
            if chu.hasPrefix("# "), let xuong = chu.firstIndex(of: "\n") { chu = String(chu[chu.index(after: xuong)...]) }
            md = chu.trimmingCharacters(in: .whitespacesAndNewlines)
            chiTiet = c
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }
}
