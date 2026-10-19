import SwiftUI

// MARK: - Code — màn chính (tổng quan + Hoạt động · Nhánh · Pull request · Mã nguồn)
//
// Đọc `code.service.ts`: tổng quan (`/code/overview`) cho số liệu đầu trang, mỗi tab một route. Mã nguồn là proxy
// GitHub/GitLab (`canViewSource` = false với agent ⇒ ẩn tab). Chip mã thẻ (NW-12) mở thẻ ngay trong app.
// Link ra GitHub/GitLab (commit, PR) mở Safari của hệ thống — không phải trang mua bán.

enum TabCodeCTW: String, Hashable, CaseIterable {
    case hoatDong = "activity", nhanh = "branches", pr = "pulls", nguon = "source"
    var ten: String {
        switch self {
        case .hoatDong: return "Activity"
        case .nhanh: return "Branches"
        case .pr: return "Pull requests"
        case .nguon: return "Source"
        }
    }
    var bieuTuong: String {
        switch self {
        case .hoatDong: return "waveform.path.ecg"
        case .nhanh: return "arrow.triangle.branch"
        case .pr: return "arrow.triangle.pull"
        case .nguon: return "folder"
        }
    }
}

@MainActor
final class CodeVM: ObservableObject {
    let pid: Int
    @Published var tongQuan: TaiCTW<CTWCodeTongQuan> = .dangTai
    @Published var hoatDong: TaiCTW<[CTWCodeSuKien]> = .dangTai
    @Published var theHoatDong: [String: CTWCodeThe] = [:]
    @Published var sauCung: String?
    @Published var dangTaiThem = false
    @Published var locLoai: String?
    @Published var nhanh: TaiCTW<CTWCodeDSNhanh> = .dangTai
    @Published var pr: TaiCTW<CTWCodeDSPR> = .dangTai
    @Published var locPR = "open"
    @Published var loiThem: String?

    init(pid: Int) { self.pid = pid }

    func taiTongQuan() async {
        do {
            let t: CTWCodeTongQuan = try await APIClient.shared.request(CTWAPI.codeTongQuan(pid: pid))
            tongQuan = .xong(t)
        } catch {
            if tongQuan.giaTri == nil { tongQuan = .loi(CTW.loi(error)) }
        }
    }

    func taiHoatDong() async {
        if hoatDong.giaTri == nil { hoatDong = .dangTai }
        do {
            let r: CTWCodeTrangHoatDong = try await APIClient.shared.request(CTWAPI.codeHoatDong(pid: pid, kind: locLoai))
            theHoatDong = r.issues ?? [:]
            sauCung = r.nextBefore
            hoatDong = .xong(r.items)
        } catch {
            if hoatDong.giaTri == nil { hoatDong = .loi(CTW.loi(error)) } else { loiThem = CTW.loi(error) }
        }
    }

    func taiThemHoatDong() async {
        guard let truoc = sauCung, !dangTaiThem, let cu = hoatDong.giaTri else { return }
        dangTaiThem = true
        defer { dangTaiThem = false }
        do {
            let r: CTWCodeTrangHoatDong = try await APIClient.shared.request(CTWAPI.codeHoatDong(pid: pid, kind: locLoai, before: truoc))
            theHoatDong.merge(r.issues ?? [:]) { $1 }
            let daCo = Set(cu.map(\.id))
            hoatDong = .xong(cu + r.items.filter { !daCo.contains($0.id) })
            sauCung = r.nextBefore
        } catch {
            loiThem = CTW.loi(error)
        }
    }

    func taiNhanh() async {
        do {
            let r: CTWCodeDSNhanh = try await APIClient.shared.request(CTWAPI.codeNhanh(pid: pid))
            nhanh = .xong(r)
        } catch {
            if nhanh.giaTri == nil { nhanh = .loi(CTW.loi(error)) } else { loiThem = CTW.loi(error) }
        }
    }

    func taiPR() async {
        do {
            let r: CTWCodeDSPR = try await APIClient.shared.request(CTWAPI.codePR(pid: pid, state: locPR))
            pr = .xong(r)
        } catch {
            if pr.giaTri == nil { pr = .loi(CTW.loi(error)) } else { loiThem = CTW.loi(error) }
        }
    }
}

struct CodeCTW: View {
    let pid: Int
    @StateObject private var vm: CodeVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tab: TabCodeCTW = .hoatDong
    @State private var prMo: Int?

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: CodeVM(pid: pid))
    }

    private var xemNguon: Bool { vm.tongQuan.giaTri?.canViewSource ?? true }
    private var cacTab: [TabCodeCTW] { TabCodeCTW.allCases.filter { $0 != .nguon || xemNguon } }

    var body: some View {
        KhungTaiCTW(trangThai: vm.tongQuan, thuLai: { Task { await vm.taiTongQuan() } }) { t in
            if t.connected == false {
                CTWOTrong(bieuTuong: "chevron.left.forwardslash.chevron.right", tieuDe: "No repository connected",
                          moTa: "A project admin can connect GitHub or GitLab in the project settings. Pushes, branches and pull requests then show up here.")
                    .frame(maxHeight: .infinity)
            } else {
                noiDung(t)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Code")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.taiTongQuan() }
        .task(id: tab) { await taiTab() }
        .alert(vm.loiThem ?? "", isPresented: Binding(get: { vm.loiThem != nil }, set: { if !$0 { vm.loiThem = nil } })) {
            Button("OK", role: .cancel) {}
        }
        // Deep link / thông báo Git: `?tab=pulls&pr=12` · `?tab=activity` · `?tab=source`. Xoá cờ ở CUỐI.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "code" else { return }
            defer { app.dichCho = nil }
            if let t = d.duongDan.tham["tab"].flatMap(TabCodeCTW.init(rawValue:)) { tab = t }
            if let n = d.duongDan.tham["pr"].flatMap(Int.init) {
                tab = .pr
                vm.locPR = "all"
                prMo = n
                await vm.taiPR()
            }
        }
        #if DEBUG
        .onAppear {
            if let c = XemThuCTW.conCua("code"), let t = TabCodeCTW(rawValue: c) { tab = t }
        }
        #endif
    }

    private func taiTab() async {
        switch tab {
        case .hoatDong: await vm.taiHoatDong()
        case .nhanh: await vm.taiNhanh()
        case .pr: await vm.taiPR()
        case .nguon: break
        }
    }

    @ViewBuilder
    private func noiDung(_ t: CTWCodeTongQuan) -> some View {
        List {
            Section {
                DauTrangCodeCTW(t: t)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ThanhTabCTW(tab: cacTab.map { ($0, $0.ten, $0.bieuTuong) }, chon: $tab)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            switch tab {
            case .hoatDong: phanHoatDong
            case .nhanh: phanNhanh
            case .pr: phanPR
            case .nguon: CayThuMucCTW.phanGoc(pid: pid, repo: t.providers?.first)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .refreshable {
            await vm.taiTongQuan()
            await taiTab()
        }
    }

    // MARK: Hoạt động

    @ViewBuilder private var phanHoatDong: some View {
        Section {
            CTWThanhLoc(chip: [
                CTWChipLoc(id: "", nhan: "All", bat: vm.locLoai == nil),
                CTWChipLoc(id: "push", nhan: "Pushes", bieuTuong: "arrow.up.circle", bat: vm.locLoai == "push"),
                CTWChipLoc(id: "branch", nhan: "Branches", bieuTuong: "arrow.triangle.branch", bat: vm.locLoai == "branch"),
                CTWChipLoc(id: "pr", nhan: "Pull requests", bieuTuong: "arrow.triangle.pull", bat: vm.locLoai == "pr"),
            ]) { c in
                vm.locLoai = c.id.isEmpty ? nil : c.id
                Task { await vm.taiHoatDong() }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        switch vm.hoatDong {
        case .dangTai:
            Section { ProgressView().frame(maxWidth: .infinity).padding() }.listRowBackground(Color.clear)
        case .loi(let l):
            Section { CTWOLoi(loi: l) { Task { await vm.taiHoatDong() } } }.listRowBackground(Color.clear)
        case .xong(let ds):
            if ds.isEmpty {
                Section {
                    CTWOTrong(bieuTuong: "waveform.path.ecg", tieuDe: "No activity yet",
                              moTa: "Pushes, new branches and pull requests appear here as soon as the repository sends them.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(ds) { e in
                        HangSuKienCodeCTW(e: e, pid: pid, the: vm.theHoatDong)
                    }
                    if vm.sauCung != nil {
                        Button {
                            Task { await vm.taiThemHoatDong() }
                        } label: {
                            HStack {
                                Spacer()
                                if vm.dangTaiThem { ProgressView() } else { Text("Load more") }
                                Spacer()
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    // MARK: Nhánh

    @ViewBuilder private var phanNhanh: some View {
        switch vm.nhanh {
        case .dangTai:
            Section { ProgressView().frame(maxWidth: .infinity).padding() }.listRowBackground(Color.clear)
        case .loi(let l):
            Section { CTWOLoi(loi: l) { Task { await vm.taiNhanh() } } }.listRowBackground(Color.clear)
        case .xong(let r):
            let song = r.items.filter { $0.deleted != true }
            let xoa = r.items.filter { $0.deleted == true }
            if r.items.isEmpty {
                Section {
                    CTWOTrong(bieuTuong: "arrow.triangle.branch", tieuDe: "No branches yet",
                              moTa: "Branches show up after the first push. Put an issue key such as \(app.luaChon?.maDuAn ?? "KEY")-12 in the branch name to link it.")
                }
                .listRowBackground(Color.clear)
            }
            if !song.isEmpty {
                Section { ForEach(song) { HangNhanhCodeCTW(b: $0, pid: pid, the: r.issues ?? [:]) } } header: { Text("Active (\(song.count))") }
            }
            if !xoa.isEmpty {
                Section { ForEach(xoa) { HangNhanhCodeCTW(b: $0, pid: pid, the: r.issues ?? [:]) } } header: { Text("Deleted (\(xoa.count))") }
            }
        }
    }

    // MARK: Pull request

    @ViewBuilder private var phanPR: some View {
        Section {
            let d = vm.pr.giaTri?.counts
            CTWThanhLoc(chip: [
                CTWChipLoc(id: "open", nhan: "Open\(d?.open.map { " \($0)" } ?? "")", bieuTuong: "arrow.triangle.pull", bat: vm.locPR == "open"),
                CTWChipLoc(id: "merged", nhan: "Merged\(d?.merged.map { " \($0)" } ?? "")", bieuTuong: "arrow.triangle.merge", bat: vm.locPR == "merged"),
                CTWChipLoc(id: "closed", nhan: "Closed\(d?.closed.map { " \($0)" } ?? "")", bieuTuong: "xmark.circle", bat: vm.locPR == "closed"),
                CTWChipLoc(id: "all", nhan: "All", bat: vm.locPR == "all"),
            ]) { c in
                vm.locPR = c.id
                Task { await vm.taiPR() }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        switch vm.pr {
        case .dangTai:
            Section { ProgressView().frame(maxWidth: .infinity).padding() }.listRowBackground(Color.clear)
        case .loi(let l):
            Section { CTWOLoi(loi: l) { Task { await vm.taiPR() } } }.listRowBackground(Color.clear)
        case .xong(let r):
            if r.items.isEmpty {
                Section {
                    CTWOTrong(bieuTuong: "arrow.triangle.pull", tieuDe: vm.locPR == "open" ? "No open pull requests" : "No pull requests",
                              moTa: "Pull requests that mention an issue key are linked to that issue automatically.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(r.items) { p in
                        HangPRCodeCTW(p: p, pid: pid, the: r.issues ?? [:], noiBat: p.number == prMo)
                    }
                }
            }
        }
    }
}

// MARK: - Đầu trang: repo + số liệu 7/30 ngày + biểu đồ commit 30 ngày

struct DauTrangCodeCTW: View {
    let t: CTWCodeTongQuan
    @Environment(\.openURL) private var moUrl

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(t.providers ?? [], id: \.provider) { p in
                HStack(spacing: 10) {
                    Image(systemName: p.provider == "GITLAB" ? "square.stack.3d.up.fill" : "chevron.left.forwardslash.chevron.right")
                        .font(.ctw(size: 13, weight: .bold)).foregroundColor(AppColors.onPrimary)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.primary))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.repo ?? "Repository not known yet").font(.ctw(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary).lineLimit(1).truncationMode(.middle)
                        Text(p.provider == "GITLAB" ? "GitLab" : "GitHub").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if let s = p.webUrl, let u = URL(string: s) {
                        Button { moUrl(u) } label: {
                            Image(systemName: "arrow.up.right.square").font(.ctw(size: 17)).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(AppColors.primary)
                        .accessibilityLabel("Open repository in Safari")
                    }
                }
            }
            let s = t.stats
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                CTWODem(so: "\(s?.commits7d ?? 0)", nhan: "Commits · 7 days", bieuTuong: "smallcircle.filled.circle", mau: AppColors.primary)
                CTWODem(so: "\(s?.pushes7d ?? 0)", nhan: "Pushes · 7 days", bieuTuong: "arrow.up.circle", mau: AppColors.info)
                CTWODem(so: "\(s?.openPrs ?? 0)", nhan: "Open pull requests", bieuTuong: "arrow.triangle.pull", mau: AppColors.success)
                CTWODem(so: "\(s?.contributors30d?.count ?? 0)", nhan: "Contributors · 30 days", bieuTuong: "person.2", mau: AppColors.accent)
            }
            if let d = s?.daily, !d.isEmpty { BieuDoCommitCTW(ngay: d) }
        }
    }
}

/// 30 cột nhỏ: số commit mỗi ngày (giờ VN, máy chủ đã chia sẵn).
struct BieuDoCommitCTW: View {
    let ngay: [CTWCodeTongQuan.Ngay]

    var body: some View {
        let lon = max(1, ngay.map { $0.commits ?? 0 }.max() ?? 1)
        let tong = ngay.reduce(0) { $0 + ($1.commits ?? 0) }
        VStack(alignment: .leading, spacing: 6) {
            Text("Commits in the last 30 days").font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(ngay, id: \.day) { d in
                    let c = d.commits ?? 0
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(c == 0 ? AppColors.backgroundTertiary : AppColors.primary.opacity(0.35 + 0.65 * Double(c) / Double(lon)))
                        .frame(height: max(4, 44 * CGFloat(c) / CGFloat(lon)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 46, alignment: .bottom)
        }
        .padding(12)
        .ctwThe(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Commits in the last 30 days: \(tong)")
    }
}

// MARK: - Chip mã thẻ — mở thẻ ngay trong app

struct ChipTheCodeCTW: View {
    let pid: Int
    let so: Int
    let the: CTWCodeThe?
    /// Màn được ĐẨY (chi tiết commit) ⇒ dùng NavigationLink: trên iPad màn được đẩy không thấy `NganXepCTW`.
    var dungLink = false

    var body: some View {
        if dungLink {
            NavigationLink(value: CTWRoute.the(pid: pid, so: so)) { nhan }.buttonStyle(.borderless)
                .accessibilityLabel("Open issue \(the?.key ?? "\(so)")\(the?.title.map { ", \($0)" } ?? "")")
        } else {
            ChipTheNutCTW(pid: pid, so: so) { nhan }
                .accessibilityLabel("Open issue \(the?.key ?? "\(so)")\(the?.title.map { ", \($0)" } ?? "")")
        }
    }

    @ViewBuilder private var nhan: some View {
        ChipTheNhanCTW(so: so, the: the)
    }
}

private struct ChipTheNhanCTW: View {
    let so: Int
    let the: CTWCodeThe?
    @EnvironmentObject private var app: AppState
    var body: some View {
            HStack(spacing: 4) {
                Circle().fill(CTW.mauNhom(the?.status?.category)).frame(width: 6, height: 6)
                Text(the?.key ?? "\(app.luaChon?.maDuAn ?? "#")-\(so)")
                    .font(.ctw(size: 11.5, weight: .bold).monospaced()).fixedSize()
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(AppColors.primary.opacity(0.12)))
            .frame(minHeight: 30)
            .contentShape(Rectangle())
    }
}

/// Button (không NavigationLink) cho màn GỐC của mô-đun: trong hàng của List, NavigationLink biến CẢ HÀNG thành một
/// link — hàng có nhiều chip thì bấm chip nào cũng mở cùng một đích. Nút `.borderless` bấm được riêng từng cái.
private struct ChipTheNutCTW<N: View>: View {
    let pid: Int
    let so: Int
    @ViewBuilder let nhan: () -> N
    @EnvironmentObject private var nganXep: NganXepCTW
    var body: some View {
        Button { nganXep.duong.append(CTWRoute.the(pid: pid, so: so)) } label: { nhan() }
            .buttonStyle(.borderless)
    }
}

struct HangChipTheCodeCTW: View {
    let pid: Int
    let so: [Int]
    let the: [String: CTWCodeThe]
    var dungLink = false
    var body: some View {
        if !so.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(so.prefix(8), id: \.self) { n in ChipTheCodeCTW(pid: pid, so: n, the: the[String(n)], dungLink: dungLink) }
                }
            }
        }
    }
}

// MARK: - Một sự kiện trong dòng thời gian

struct HangSuKienCodeCTW: View {
    let e: CTWCodeSuKien
    let pid: Int
    let the: [String: CTWCodeThe]
    @Environment(\.openURL) private var moUrl

    var body: some View {
        let h = CTWCodeChu.hanhDong(e)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: h.bieuTuong).font(.ctw(size: 14, weight: .semibold))
                    .foregroundColor(mau)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(mau.opacity(0.13)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        CTWAvatar(user: e.actor?.user, size: 18)
                        Text(h.cau).font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let t = e.title, !t.isEmpty, e.kind.hasPrefix("PR_") || e.kind == "REVIEW_REQUESTED" {
                        Text(t).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                    }
                    Text(CTW.thoiDiem(e.occurredAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                if let s = e.url, let u = URL(string: s) {
                    Button { moUrl(u) } label: {
                        Image(systemName: "arrow.up.right").font(.ctw(size: 12, weight: .semibold)).frame(width: 36, height: 36)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(AppColors.textTertiary)
                    .accessibilityLabel("Open on \(e.provider == "GITLAB" ? "GitLab" : "GitHub")")
                }
            }
            let cs = e.commits ?? []
            if !cs.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(cs.prefix(4), id: \.sha) { c in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(c.shaNgan).font(.ctw(size: 11.5, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                            Text(c.dongDau).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if cs.count > 4 {
                        Text("+ \(cs.count - 4) more commit\(cs.count - 4 == 1 ? "" : "s")").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.leading, 38)
            }
            HangChipTheCodeCTW(pid: pid, so: e.tatCaThe, the: the).padding(.leading, 38)
        }
        .padding(.vertical, 4)
    }

    private var mau: Color {
        switch e.kind {
        case "PR_MERGED": return AppColors.primary
        case "PR_CLOSED", "BRANCH_DELETED": return AppColors.error
        case "PR_OPENED", "PR_REOPENED": return AppColors.success
        case "REVIEW_REQUESTED": return AppColors.warning
        default: return AppColors.info
        }
    }
}

// MARK: - Một nhánh

struct HangNhanhCodeCTW: View {
    let b: CTWCodeNhanh
    let pid: Int
    let the: [String: CTWCodeThe]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch").font(.ctw(size: 13, weight: .semibold))
                    .foregroundColor(b.deleted == true ? AppColors.textTertiary : AppColors.primary)
                    .accessibilityHidden(true)
                Text(b.name).font(.ctw(size: 14, weight: .semibold).monospaced())
                    .foregroundColor(b.deleted == true ? AppColors.textSecondary : AppColors.textPrimary)
                    .strikethrough(b.deleted == true)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                if let p = b.pr { CTWNhanNho(chu: "PR #\(p.number)", bieuTuong: "arrow.triangle.pull", mau: AppColors.success) }
                if b.deleted == true { CTWNhanNho(chu: "Deleted", mau: AppColors.error) }
            }
            if let c = b.lastCommit?.title {
                Text(c).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
            }
            HStack(spacing: 6) {
                if let a = b.lastAuthor { CTWAvatar(user: a.user, size: 16); Text(a.ten).lineLimit(1) }
                if let t = b.lastPushAt { Text("· \(CTW.thoiDiem(t))") }
                if let n = b.commitCount, n > 0 { Text("· \(n) commit\(n == 1 ? "" : "s")") }
            }
            .font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary)
            HangChipTheCodeCTW(pid: pid, so: b.issueNumbers ?? [], the: the)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Một pull request

struct HangPRCodeCTW: View {
    let p: CTWCodePR
    let pid: Int
    let the: [String: CTWCodeThe]
    var noiBat = false
    @Environment(\.openURL) private var moUrl

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: bieuTuong).font(.ctw(size: 14, weight: .semibold)).foregroundColor(mau)
                    .frame(width: 22).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.title ?? "Pull request").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("#\(p.number) · \(dongPhu)").font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    CTWChipChu(chu: CTWCodeChu.trangThaiPR(p.state), mau: mau)
                    if let s = p.url, let u = URL(string: s) {
                        Button { moUrl(u) } label: {
                            Image(systemName: "arrow.up.right.square").font(.ctw(size: 16)).frame(width: 44, height: 36)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(AppColors.primary)
                        .accessibilityLabel("Open pull request #\(p.number) in Safari")
                    }
                }
            }
            if let h = p.headRef {
                HStack(spacing: 4) {
                    Text(h).lineLimit(1).truncationMode(.middle)
                    Image(systemName: "arrow.right").font(.ctw(size: 9, weight: .bold))
                    Text(p.baseRef ?? "main").lineLimit(1)
                }
                .font(.ctw(size: 11.5, weight: .medium).monospaced()).foregroundColor(AppColors.textSecondary)
                .padding(.leading, 30)
            }
            HStack(spacing: 10) {
                if let a = p.additions { Text("+\(a)").foregroundColor(AppColors.success) }
                if let d = p.deletions { Text("−\(d)").foregroundColor(AppColors.error) }
                if let f = p.changedFiles { Text("\(f) file\(f == 1 ? "" : "s")").foregroundColor(AppColors.textTertiary) }
                if let r = p.reviewers, !r.isEmpty {
                    Text("Reviewers: \(r.map(\.ten).joined(separator: ", "))").foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
            }
            .font(.ctw(size: 11.5, weight: .semibold).monospacedDigit())
            .padding(.leading, 30)
            HangChipTheCodeCTW(pid: pid, so: p.issueNumbers ?? [], the: the).padding(.leading, 30)
        }
        .padding(.vertical, 4)
        .listRowBackground(noiBat ? AppColors.primary.opacity(0.08) : AppColors.backgroundCard)
        .contextMenu {
            if let s = p.url, let u = URL(string: s) {
                Button { moUrl(u) } label: { Label("Open in Safari", systemImage: "safari") }
                Button { CTW.chepVaoBoNho(s) } label: { Label("Copy link", systemImage: "link") }
            }
        }
    }

    private var dongPhu: String {
        let ai = p.author?.ten ?? "someone"
        switch p.state {
        case "merged": return "merged\(p.mergedBy.map { " by \($0.ten)" } ?? "") \(CTW.thoiDiem(p.mergedAt ?? p.openedAt))"
        case "closed": return "closed \(CTW.thoiDiem(p.closedAt ?? p.openedAt))"
        default: return "opened by \(ai) \(CTW.thoiDiem(p.openedAt))"
        }
    }
    private var bieuTuong: String {
        switch p.state {
        case "merged": return "arrow.triangle.merge"
        case "closed": return "xmark.circle"
        default: return "arrow.triangle.pull"
        }
    }
    private var mau: Color {
        switch p.state {
        case "merged": return AppColors.primary
        case "closed": return AppColors.error
        case "draft": return AppColors.textSecondary
        default: return AppColors.success
        }
    }
}
