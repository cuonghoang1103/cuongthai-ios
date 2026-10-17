import SwiftUI

// MARK: - Resources — kho liên kết của dự án (repo, Figma, Drive, tài liệu API…)
//
// Chạm ⇒ báo máy chủ một lượt mở (`/open`, để "mở gần đây" và đếm đúng như web) rồi
// mở trong trình duyệt an toàn trong app. Liên kết không phải http(s) (vd `figma://`)
// giao cho hệ thống. Thêm/sửa liên kết để ở web (biểu mẫu dài, kiểm link).

@MainActor
final class ResourcesVM: ObservableObject {
    let pid: Int
    @Published var du: CTWDsNguonLuc?
    @Published var loi: String?
    @Published var tatMoDun = false
    init(pid: Int) { self.pid = pid }

    func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.dsNguonLuc(pid: pid)); loi = nil }
        catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" { tatMoDun = true; return }
            loi = CTW.loi(error)
        }
    }

    /// Ghi lượt mở; hỏng cũng vẫn mở url gốc (đếm lượt không đáng chặn người dùng).
    func mo(_ r: CTWNguonLuc) async -> URL? {
        let kq: CTWMoNguonLuc? = try? await APIClient.shared.request(CTWAPI.moNguonLuc(pid: pid, id: r.id))
        return URL(string: kq?.url ?? r.url)
    }
}

struct ResourcesCTW: View {
    let nguCanh: CTWNguCanh
    @StateObject private var vm: ResourcesVM
    @Environment(\.openURL) private var moNgoai
    @State private var tim = ""
    @State private var web: URLToChucCTW?
    @State private var the: String?

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: ResourcesVM(pid: nguCanh.pid))
    }

    private var loc: [CTWNguonLuc] {
        let q = tim.trimmingCharacters(in: .whitespaces).lowercased()
        return (vm.du?.items ?? []).filter { r in
            if let the, !(r.tags ?? []).contains(the) { return false }
            if q.isEmpty { return true }
            return ([r.title, r.url, r.description, r.groupName] + (r.tags ?? []).map { Optional($0) })
                .compactMap { $0?.lowercased() }.contains { $0.contains(q) }
        }
    }

    /// Ghim lên đầu, rồi theo nhóm (thứ tự `rank` của nhóm), cuối cùng "Other links".
    private var khoi: [(ten: String, icon: String?, ds: [CTWNguonLuc])] {
        let ds = loc
        var out: [(String, String?, [CTWNguonLuc])] = []
        let ghim = ds.filter { $0.pinned == true }
        if !ghim.isEmpty { out.append(("Pinned", "📌", ghim)) }
        let nhom = (vm.du?.groups ?? []).sorted { ($0.rank ?? 0, $0.id) < ($1.rank ?? 0, $1.id) }
        for g in nhom {
            let m = ds.filter { $0.groupId == g.id && $0.pinned != true }
            if !m.isEmpty { out.append((g.name, g.icon, m)) }
        }
        let le = ds.filter { $0.groupId == nil && $0.pinned != true }
        if !le.isEmpty { out.append(("Other links", nil, le)) }
        return out.map { (ten: $0.0, icon: $0.1, ds: $0.2.sorted { ($0.rank ?? 0, $0.id) < ($1.rank ?? 0, $1.id) }) }
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                if vm.du == nil { CTWOLoi(loi: loi) { Task { await vm.tai() } }.listRowBackground(Color.clear) }
                else { CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            }
            if vm.tatMoDun {
                CTWOTrong(bieuTuong: "link", tieuDe: "Resources are turned off",
                          moTa: "A project admin can turn Resources on in project settings.")
                    .listRowBackground(Color.clear)
            } else if let du = vm.du {
                if let tags = du.tags, !tags.isEmpty {
                    Section {
                        CTWThanhLoc(chip: [CTWChipLoc(id: "", nhan: "All", bat: the == nil)]
                                    + tags.prefix(20).map { CTWChipLoc(id: $0.tag, nhan: "#\($0.tag)", bat: the == $0.tag) }) { c in
                            the = c.id.isEmpty ? nil : c.id
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: -16, bottom: 0, trailing: -16))
                    }
                    .listRowBackground(Color.clear)
                }
                if let b = du.broken, b > 0 {
                    Label("\(b) link\(b == 1 ? "" : "s") looked broken at the last check.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13)).foregroundColor(AppColors.warning)
                        .listRowBackground(Color.clear)
                }
                if (du.items ?? []).isEmpty {
                    CTWOTrong(bieuTuong: "link", tieuDe: "No links yet",
                              moTa: "Repositories, designs, drives and docs your team saves for this project appear here.")
                        .listRowBackground(Color.clear)
                } else if loc.isEmpty {
                    Text("Nothing matches.").foregroundColor(AppColors.textSecondary).listRowBackground(Color.clear)
                }
                ForEach(khoi, id: \.ten) { k in
                    Section {
                        ForEach(k.ds) { r in
                            Button { Task { await mo(r) } } label: { hang(r) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { CTW.chepVaoBoNho(r.url) } label: { Label("Copy link", systemImage: "doc.on.doc") }
                                    if let u = URL(string: r.url) { ShareLink(item: u) { Label("Share", systemImage: "square.and.arrow.up") } }
                                }
                        }
                    } header: {
                        Text([k.icon, k.ten].compactMap { $0 }.joined(separator: " "))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.du == nil && vm.loi == nil && !vm.tatMoDun { CTWKhungTai(soHang: 6, coAvatar: false) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search links")
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if vm.du == nil { await vm.tai() } }
        .sheet(item: $web) { w in SafariCTW(url: w.url).ignoresSafeArea() }
    }

    private func mo(_ r: CTWNguonLuc) async {
        guard let u = await vm.mo(r) else { return }
        CTWRung.chon()
        if ["http", "https"].contains(u.scheme?.lowercased() ?? "") { web = URLToChucCTW(url: u) } else { moNgoai(u) }
    }

    private func hang(_ r: CTWNguonLuc) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: CTWNguonLucHienThi.bieuTuong(r.kind))
                .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(r.tenHien).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if r.linkStatus == "BROKEN" {
                        CTWNhanNho(chu: "Broken", bieuTuong: "exclamationmark.triangle.fill", mau: AppColors.error)
                    }
                }
                Text(URL(string: r.url)?.host ?? r.url).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                if let d = r.github?.description ?? r.description, !d.isEmpty {
                    Text(d).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                let tags = r.tags ?? []
                if !tags.isEmpty || r.github?.stars != nil {
                    HStack(spacing: 6) {
                        if let s = r.github?.stars { CTWNhanNho(chu: "\(s)", bieuTuong: "star.fill", mau: AppColors.warning) }
                        if let l = r.github?.language { CTWNhanNho(chu: l) }
                        ForEach(tags.prefix(3), id: \.self) { CTWNhanNho(chu: "#\($0)", mau: AppColors.primary) }
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the link")
    }
}
