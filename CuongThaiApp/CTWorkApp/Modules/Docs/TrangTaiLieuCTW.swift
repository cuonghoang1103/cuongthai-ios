import SwiftUI

// MARK: - Docs — ĐỌC một trang + thao tác: sửa, đổi tên, trạng thái, xin duyệt,
// lịch sử phiên bản, thẻ liên kết, bình luận (báo cáo/chặn — App Store 1.2).
//
// Liên kết trong trang dạng `/work/<ws>/<KEY>/issue/<n>` (cách web chèn liên kết
// thẻ) mở NGAY trong app: cùng dự án ⇒ đẩy màn thẻ; khác ⇒ bộ định tuyến chung.

@MainActor
final class TrangTaiLieuVM: ObservableObject {
    let pid: Int
    let so: Int
    @Published var ct: CTWPageDetail?
    @Published var md: String?
    @Published var binhLuan: [CTWPageComment]?
    @Published var loi: String?
    @Published var thongBao: String?

    init(pid: Int, so: Int) { self.pid = pid; self.so = so }

    func tai() async {
        do {
            async let a: CTWPageMarkdown = APIClient.shared.request(CTWAPI.trangMarkdown(pid: pid, so: so))
            async let b: CTWPageDetail = APIClient.shared.request(CTWAPI.trang(pid: pid, so: so))
            let (m, c) = try await (a, b)
            md = CTWSuaTrang.boTieuDe(m.markdown ?? "", tieuDe: c.title)
            ct = c
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
        binhLuan = (try? await APIClient.shared.request(CTWAPI.binhLuanTrang(pid: pid, so: so)) as [CTWPageComment]) ?? binhLuan ?? []
    }

    func doiTrangThai(_ s: String) async {
        do {
            _ = try? await APIClient.shared.send(CTWAPI.xaCollab(pid: pid, so: so))
            let _: CTWPageDetail = try await APIClient.shared.request(CTWAPI.suaTrang(pid: pid, so: so, phienBan: nil, trangThai: s))
            CTWRung.thanhCong()
            await tai()
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "WORK_PAGE_APPROVAL_REQUIRED" {
                loi = "This project uses approvals — use “Request approval” to move the page to review."
            } else { loi = CTW.loi(error) }
            CTWRung.loi()
        }
    }

    func doiTen(_ ten: String) async {
        let t = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do {
            _ = try? await APIClient.shared.send(CTWAPI.xaCollab(pid: pid, so: so))
            let moi: CTWPageDetail = try await APIClient.shared.request(CTWAPI.trang(pid: pid, so: so))
            let _: CTWPageDetail = try await APIClient.shared.request(CTWAPI.suaTrang(pid: pid, so: so, phienBan: moi.version, tieuDe: t))
            CTWRung.thanhCong()
            await tai()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }

    func xoa() async -> Bool {
        do { try await APIClient.shared.send(CTWAPI.xoaTrang(pid: pid, so: so)); CTWRung.thanhCong(); return true }
        catch { loi = CTW.loi(error); CTWRung.loi(); return false }
    }

    func guiBinhLuan(_ chu: String) async -> Bool {
        do {
            let c: CTWPageComment = try await APIClient.shared.request(CTWAPI.guiBinhLuanTrang(pid: pid, so: so, chu: chu))
            binhLuan = (binhLuan ?? []) + [c]
            return true
        } catch { loi = CTW.loi(error); return false }
    }

    func xoaBinhLuan(_ c: CTWPageComment) async {
        do {
            try await APIClient.shared.send(CTWAPI.xoaBinhLuanTrang(pid: pid, so: so, cid: c.id))
            binhLuan?.removeAll { $0.id == c.id }
        } catch { loi = CTW.loi(error) }
    }

    func ganThe(_ so2: Int) async {
        do {
            let _: [CTWPageDetail.TheLienKet] = try await APIClient.shared.request(CTWAPI.ganTheVaoTrang(pid: pid, so: so, the: so2))
            CTWRung.thanhCong()
            await tai()
        } catch { loi = CTW.loi(error) }
    }

    func goThe(_ so2: Int) async {
        do {
            let _: [CTWPageDetail.TheLienKet] = try await APIClient.shared.request(CTWAPI.goTheKhoiTrang(pid: pid, so: so, the: so2))
            await tai()
        } catch { loi = CTW.loi(error) }
    }

    func xinDuyet(nguoi: [Int], tuanTu: Bool) async -> Bool {
        do {
            try await APIClient.shared.send(CTWAPI.xinDuyetTrang(pid: pid, so: so, nguoiDuyet: nguoi, tuanTu: tuanTu))
            CTWRung.thanhCong()
            thongBao = "Approval requested. The page is now In review."
            await tai()
            return true
        } catch { loi = CTW.loi(error); CTWRung.loi(); return false }
    }
}

struct TrangTaiLieuCTW: View {
    let pid: Int
    let so: Int
    let ten: String
    @StateObject private var vm: TrangTaiLieuVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @Environment(\.dismiss) private var quayLai
    @State private var tamPhu: TamPhu?
    @State private var dangSua = false
    @State private var hoiDoiTen = false
    @State private var tenMoi = ""
    @State private var hoiXoa = false

    private enum TamPhu: String, Identifiable { case chonThe, xinDuyet, web; var id: String { rawValue } }

    init(pid: Int, so: Int, ten: String) {
        self.pid = pid; self.so = so; self.ten = ten
        _vm = StateObject(wrappedValue: TrangTaiLieuVM(pid: pid, so: so))
    }

    private var cfg: CTWProjectConfig? { app.cauHinhDuAn }
    /// Web bật sửa khi `page.canEdit && permissions.editDocs && status != ARCHIVED` (DocView.tsx:185).
    private var suaDuoc: Bool {
        guard let c = vm.ct else { return false }
        return c.canEdit == true && (cfg?.permissions?.tatCa["editDocs"] ?? true) && c.status != "ARCHIVED"
    }
    private var quanLy: Bool { vm.ct?.canManage == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                if let c = vm.ct { dau(c) }
                if let md = vm.md {
                    if md.isEmpty {
                        Text(suaDuoc ? "This page is empty. Tap Edit to start writing." : "This page is empty.")
                            .font(.system(size: 15)).foregroundColor(AppColors.textSecondary).padding(.vertical, 8)
                    } else {
                        CTWMarkdownView(markdown: md, coChu: 15.5)
                    }
                } else if vm.loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false).padding(-Spacing.md)
                }
                if let c = vm.ct {
                    khoiTrangCon(c)
                    khoiThe(c)
                    khoiBinhLuan(c)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .environment(\.openURL, OpenURLAction { url in moLienKet(url) })
        .navigationTitle(vm.ct?.title ?? ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if suaDuoc {
                    Button { dangSua = true } label: { Label("Edit", systemImage: "square.and.pencil") }
                }
                if vm.ct != nil { menu }
            }
        }
        .refreshable { await vm.tai() }
        .task { if vm.ct == nil { await vm.tai() } }
        .fullScreenCover(isPresented: $dangSua) {
            if let l = app.luaChon {
                SuaTrangCTW(pid: pid, so: so, slug: l.slug, maDuAn: l.maDuAn) { Task { await vm.tai() } }
            }
        }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .chonThe:
                ChonTheCTW(pid: pid, tieuDe: "Link an issue") { the in Task { await vm.ganThe(the.number) } }
            case .xinDuyet:
                XinDuyetTrangCTW(thanhVien: (cfg?.dsThanhVien ?? []).filter { !$0.laAgent && $0.role != "VIEWER" && $0.id != app.currentUser?.id }) { nguoi, tuanTu in
                    await vm.xinDuyet(nguoi: nguoi, tuanTu: tuanTu)
                }
            case .web:
                if let l = app.luaChon, let u = CTWWeb.url(slug: l.slug, ma: l.maDuAn, doan: "docs/\(so)") {
                    SafariCTW(url: u).ignoresSafeArea()
                }
            }
        }
        .alert("Rename page", isPresented: $hoiDoiTen) {
            TextField("Title", text: $tenMoi)
            Button("Rename") { Task { await vm.doiTen(tenMoi) } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this page?", isPresented: $hoiXoa, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { Task { if await vm.xoa() { quayLai() } } }
        } message: { Text("Subpages are deleted too. Pending approvals are cancelled. You can restore from Trash.") }
        .alert(vm.thongBao ?? "", isPresented: Binding(get: { vm.thongBao != nil }, set: { if !$0 { vm.thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        }
        #if DEBUG
        .onAppear { if XemThuCTW.conCua("docs") == "edit" { dangSua = true } }
        #endif
    }

    // MARK: Menu ⋯

    private var menu: some View {
        Menu {
            if suaDuoc {
                Button { tenMoi = vm.ct?.title ?? ""; hoiDoiTen = true } label: { Label("Rename", systemImage: "pencil") }
            }
            if let c = vm.ct, c.canEdit == true {
                let dich = CTWDocStatus.dich(tu: c.status, duyetBat: c.approvalsOn == true, quanLy: quanLy)
                if !dich.isEmpty {
                    Menu {
                        ForEach(dich, id: \.self) { s in
                            Button { Task { await vm.doiTrangThai(s) } } label: {
                                Label(CTWDocStatus.ten(s), systemImage: CTWDocStatus.bieuTuong(s))
                            }
                        }
                    } label: { Label("Status", systemImage: "flag") }
                }
            }
            if vm.ct?.approvalsOn == true, vm.ct?.canRequestApproval == true, vm.ct?.approval?.status != "PENDING" {
                Button { tamPhu = .xinDuyet } label: { Label("Request approval…", systemImage: "checkmark.seal") }
            }
            Button {
                nganXep.duong.append(RouteLichSuTrangCTW(pid: pid, so: so, ten: vm.ct?.title ?? ten, quanLy: quanLy))
            } label: { Label("Version history", systemImage: "clock.arrow.circlepath") }
            if suaDuoc {
                Button { tamPhu = .chonThe } label: { Label("Link an issue", systemImage: "link") }
            }
            Divider()
            if let l = app.luaChon {
                Button {
                    CTW.chepVaoBoNho("\(APIClient.diaChiGoc)/work/\(l.slug)/\(l.maDuAn)/docs/\(so)")
                    CTWRung.thanhCong()
                } label: { Label("Copy link", systemImage: "doc.on.doc") }
            }
            Button { tamPhu = .web } label: { Label("Open on the web", systemImage: "safari") }
            if quanLy {
                Button(role: .destructive) { hoiXoa = true } label: { Label("Delete", systemImage: "trash") }
            }
        } label: { Image(systemName: "ellipsis.circle") }
        .accessibilityLabel("Page actions")
    }

    // MARK: Khối

    @ViewBuilder
    private func dau(_ c: CTWPageDetail) -> some View {
        if let anc = c.ancestors, !anc.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(anc) { a in
                        Button { nganXep.duong.append(RouteTaiLieuCTW(pid: pid, so: a.number, ten: a.title)) } label: {
                            Text(a.title).font(.system(size: 12)).foregroundColor(AppColors.textTertiary).fixedSize()
                        }
                        .buttonStyle(.plain)
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        Text(c.title).font(.system(size: 26, weight: .bold)).foregroundColor(AppColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
        HStack(spacing: 8) {
            CTWChipChu(chu: c.status ?? "DRAFT")
            if c.visibility == "CLIENT" { CTWNhanNho(chu: "Client", bieuTuong: "person.2.wave.2") }
            if c.aiAssisted == true { CTWNhanAI(chu: "AI-assisted") }
            if let u = c.lastEditedBy ?? c.owner {
                CTWAvatar(user: u, size: 18)
                Text(u.ten).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                if u.laAgent { CTWNhanAI() }
            }
            if let d = CTW.ngayNgan(c.updatedAt) {
                Text("· \(d)").font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
            }
        }
        if let a = c.approval {
            HStack(spacing: 10) {
                Image(systemName: a.status == "APPROVED" ? "checkmark.seal.fill" : "hourglass")
                    .foregroundColor(CTWMauTrangThai.mau(a.status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.status == "PENDING" ? "Waiting for approval" : "Approval \(CTWMauTrangThai.nhan(a.status).lowercased())")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    if a.contentChanged == true {
                        Text("The page changed after it was signed.").font(.system(size: 12)).foregroundColor(AppColors.warning)
                    } else if let d = CTW.ngayNgan(a.decidedAt ?? a.createdAt) {
                        Text(d).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                CTWChipChu(chu: a.status)
            }
            .padding(12)
            .ctwThe(12)
        }
        Divider().padding(.vertical, 2)
    }

    @ViewBuilder
    private func khoiTrangCon(_ c: CTWPageDetail) -> some View {
        if let con = c.children, !con.isEmpty {
            CTWSectionHeader("doc.on.doc", "Subpages", count: "\(con.count)").padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(con) { r in
                    NavigationLink(value: RouteTaiLieuCTW(pid: pid, so: r.number, ten: r.title)) {
                        HStack {
                            Image(systemName: "doc.text").foregroundColor(AppColors.primary)
                            Text(r.title).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if r.id != con.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14)
            .ctwThe(12)
        }
    }

    @ViewBuilder
    private func khoiThe(_ c: CTWPageDetail) -> some View {
        let ds = c.issues ?? []
        if !ds.isEmpty || suaDuoc {
            CTWSectionHeader("link", "Linked issues", count: ds.isEmpty ? nil : "\(ds.count)",
                             trailing: suaDuoc ? AnyView(Button { tamPhu = .chonThe } label: {
                                 Image(systemName: "plus.circle.fill").font(.system(size: 20))
                             }.accessibilityLabel("Link an issue")) : nil)
                .padding(.top, 8)
            if ds.isEmpty {
                Text("Link the issues this page specifies or decides.")
                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ds) { t in
                        Button { nganXep.duong.append(CTWRoute.the(pid: pid, so: t.number)) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: CTW.bieuTuongLoai(key: t.type?.icon ?? t.type?.key))
                                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(CTW.mau(t.type?.color, macDinh: Color(hex: 0x2563EB))))
                                Text(t.key ?? "#\(t.number)").font(.system(size: 12, weight: .semibold).monospaced())
                                    .foregroundColor(AppColors.textSecondary)
                                Text(t.title).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                    .strikethrough(t.resolvedAt != nil)
                                Spacer(minLength: 4)
                                Text(t.status?.name ?? "").font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(CTW.mauNhom(t.status?.category)).lineLimit(1)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if suaDuoc {
                                Button(role: .destructive) { Task { await vm.goThe(t.number) } } label: {
                                    Label("Unlink", systemImage: "link.badge.plus")
                                }
                            }
                        }
                        if t.id != ds.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(12)
            }
        }
    }

    @ViewBuilder
    private func khoiBinhLuan(_ c: CTWPageDetail) -> some View {
        let ds = vm.binhLuan ?? []
        CTWSectionHeader("bubble.left.and.bubble.right", "Comments", count: ds.isEmpty ? nil : "\(ds.count)").padding(.top, 8)
        if ds.isEmpty && vm.binhLuan != nil {
            Text("No comments yet.").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
        }
        ForEach(ds) { b in
            CTWBinhLuanDong(
                khoa: "page-comment-\(b.id)", tacGia: b.author,
                noiDung: b.bodyText ?? b.bodyJson?.chuTron ?? "", doc: b.bodyJson,
                thoiDiem: b.createdAt,
                nhanPhu: b.anchor?.quote.map { "On “\($0.prefix(24))…”" },
                nguCanh: "Page \(app.luaChon?.maDuAn ?? "")-DOC-\(so) · \(c.title)",
                themMuc: b.canDelete == true ? AnyView(Button(role: .destructive) { Task { await vm.xoaBinhLuan(b) } } label: {
                    Label("Delete", systemImage: "trash")
                }) : nil)
        }
        if c.canComment == true {
            CTWHopSoan(goiY: "Comment on this page…") { await vm.guiBinhLuan($0) }
                .padding(.top, 4)
        }
    }

    // MARK: Liên kết trong trang

    private func moLienKet(_ url: URL) -> OpenURLAction.Result {
        if url.scheme == "http" || url.scheme == "https" {
            if url.host == URL(string: APIClient.diaChiGoc)?.host, url.path.hasPrefix("/work/") { return moDuongWork(url.path) }
            return .systemAction
        }
        if url.scheme == nil, url.path.hasPrefix("/work/") { return moDuongWork(url.path) }
        return .systemAction
    }

    private func moDuongWork(_ p: String) -> OpenURLAction.Result {
        if let d = DuongDanCTW.tach(p), let l = app.luaChon, d.slug == l.slug, d.maDuAn == l.maDuAn {
            if d.doan == "issue", let n = d.phanCon.first.flatMap(Int.init) {
                nganXep.duong.append(CTWRoute.the(pid: pid, so: n)); return .handled
            }
            if d.doan == "docs", let n = d.phanCon.first.flatMap(Int.init) {
                nganXep.duong.append(RouteTaiLieuCTW(pid: pid, so: n, ten: "Page")); return .handled
            }
        }
        DinhTuyenCTW.mo(duongDan: p)
        return .handled
    }
}

// MARK: - Xin phê duyệt trang

struct XinDuyetTrangCTW: View {
    let thanhVien: [CTWUser]
    let gui: ([Int], Bool) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chon: [Int] = []
    @State private var tuanTu = true
    @State private var dangGui = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Order", selection: $tuanTu) {
                        Text("One after another").tag(true)
                        Text("All at once").tag(false)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(tuanTu ? "Approvers sign in the order you pick them." : "Everyone can sign at the same time.")
                }
                Section("Approvers · up to 10") {
                    if thanhVien.isEmpty { Text("No other members can approve in this project.").foregroundColor(AppColors.textSecondary) }
                    ForEach(thanhVien) { u in
                        Button {
                            if let i = chon.firstIndex(of: u.id) { chon.remove(at: i) } else if chon.count < 10 { chon.append(u.id) }
                            CTWRung.chon()
                        } label: {
                            HStack(spacing: 10) {
                                CTWAvatar(user: u, size: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(u.ten).foregroundColor(AppColors.textPrimary)
                                    if let r = u.role { Text(r.capitalized).font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }
                                }
                                Spacer()
                                if let i = chon.firstIndex(of: u.id) {
                                    Text(tuanTu ? "\(i + 1)" : "")
                                        .font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.onPrimary)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(AppColors.primary))
                                        .overlay { if !tuanTu { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white) } }
                                } else {
                                    Circle().strokeBorder(AppColors.border, lineWidth: 1.5).frame(width: 24, height: 24)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Request approval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dangGui = true
                        Task { if await gui(chon, tuanTu) { dong() }; dangGui = false }
                    } label: { if dangGui { ProgressView() } else { Text("Send").bold() } }
                    .disabled(chon.isEmpty || dangGui)
                }
            }
        }
    }
}
