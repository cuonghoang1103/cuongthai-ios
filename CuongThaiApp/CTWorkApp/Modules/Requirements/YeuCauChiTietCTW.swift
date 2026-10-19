import SwiftUI

// MARK: - Chi tiết use case · màn hình · thảo luận · đề xuất

// MARK: Use case

struct ChiTietUCCTW: View {
    let pid: Int
    let n: Int
    @ObservedObject private var kho: KhoYeuCauCTW
    @EnvironmentObject private var app: AppState
    @State private var dangDoi = false
    @State private var loi: String?

    init(pid: Int, n: Int) {
        self.pid = pid; self.n = n
        _kho = ObservedObject(wrappedValue: KhoYeuCauCTW.cua(pid))
    }

    var body: some View {
        ScrollView {
            if let d = kho.srs, let uc = d.useCases?.first(where: { $0.number == n }) {
                noiDung(uc, d)
                    .padding(Spacing.md)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
            } else if kho.srs != nil {
                CTWOTrong(bieuTuong: "questionmark.folder", tieuDe: "Use case not found",
                          moTa: "It may have been deleted or merged.")
            } else if let l = kho.loi {
                CTWOLoi(loi: l) { Task { await kho.taiSrs() } }
            } else {
                CTWKhungTai(soHang: 5, coAvatar: false)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(kho.srs?.useCases?.first(where: { $0.number == n })?.ma ?? String(format: "UC-%02d", n))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await kho.taiSrs() }
        .task { if kho.srs == nil { await kho.taiSrs() } }
    }

    @ViewBuilder
    private func noiDung(_ uc: CTWSrsUseCase, _ d: CTWSrsData) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Đầu trang
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(uc.ma).font(.ctw(size: 13, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                    if let s = uc.section { Text("§ \(s)").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary) }
                    if let f = uc.feature, !f.isEmpty { CTWNhanNho(chu: f, bieuTuong: "square.stack.3d.up") }
                }
                Text(uc.name ?? "Use case").font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 6) {
                    CTWChipChu(chu: uc.status ?? "DRAFT", mau: CTWNhanYeuCau.mauUC(uc.status))
                    if let p = CTWNhanYeuCau.nhanUuTien(uc.priority) {
                        CTWNhanNho(chu: "\(p) priority", bieuTuong: "flag.fill", mau: CTWNhanYeuCau.mauUuTien(uc.priority))
                    }
                    if uc.aiModel != nil { CTWNhanAI(chu: "AI-drafted") }
                    if let u = CTW.ngayNgan(uc.updatedAt) {
                        Text("Updated \(u)").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
            if uc.status == "PROPOSED" {
                ghiChu("sparkles", "This use case is a proposal. It isn't part of the SRS until someone on the team accepts it.", AppColors.primary)
            }
            if let m = uc.missing, !m.isEmpty {
                ghiChu("exclamationmark.triangle.fill", "Missing for a complete specification: " + m.joined(separator: ", ") + ".", AppColors.warning)
            }
            hanhDongDuyet(uc, d)

            // Diễn viên + kích hoạt
            CTWKhoiTruong {
                CTWHangTruong("Primary actor", d.actor(uc.primaryActorId)?.name, bieuTuong: "person.fill")
                Divider()
                CTWHangTruong("Secondary", (uc.secondaryActorIds ?? []).compactMap { d.actor($0)?.name }.joined(separator: ", "),
                              bieuTuong: "person.2")
                Divider()
                CTWHangTruong("Trigger", uc.trigger, bieuTuong: "bolt")
            }

            khoiChu("Description", "text.alignleft", uc.description)
            khoiChu("Preconditions", "arrow.right.to.line", uc.preconditions)
            khoiLuong("Normal flow", "arrow.triangle.turn.up.right.circle", uc.normalFlow, AppColors.primary)
            khoiLuong("Alternative flows", "arrow.triangle.branch", uc.alternativeFlows, AppColors.secondary)
            khoiLuong("Exceptions", "exclamationmark.octagon", uc.exceptionFlows, AppColors.error)
            khoiChu("Postconditions", "flag.checkered", uc.postconditions)

            let rules = (uc.ruleNumbers ?? []).compactMap { d.rule($0) }
            if !rules.isEmpty {
                CTWSectionHeader("checkmark.shield", "Business rules", count: "\(rules.count)")
                VStack(spacing: 0) {
                    ForEach(rules) { r in
                        HangQuyTacCTW(pid: pid, r: r, d: d)
                            .padding(.vertical, 6)
                        if r.id != rules.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .ctwThe(14)
            }

            CTWSectionHeader("text.bubble", "Discussion")
            if let i = uc.issue {
                NavigationLink(value: CTWRoute.the(pid: pid, so: i.number)) {
                    HStack(spacing: 10) {
                        Image(systemName: CTW.bieuTuongLoai(key: i.type?.key)).foregroundColor(AppColors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(i.key ?? uc.issueKey ?? "Issue #\(i.number)").font(.ctw(size: 12, weight: .bold).monospaced())
                                .foregroundColor(AppColors.textSecondary)
                            Text(i.title ?? "").font(.ctw(size: 14.5, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        if let s = i.status?.name { CTWChipChu(chu: s, mau: CTW.mauNhom(i.status?.category)) }
                        Image(systemName: "chevron.right").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                    .padding(12)
                    .ctwThe(12)
                }
                .buttonStyle(.plain)
                ThaoLuanTheCTW(pid: pid, so: i.number, nguCanh: "\(uc.ma) \(uc.name ?? "")")
            } else {
                ghiChu("link", "Comments on a use case live on its linked issue. Link an issue to \(uc.ma) on the web to start a discussion.",
                       AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func hanhDongDuyet(_ uc: CTWSrsUseCase, _ d: CTWSrsData) -> some View {
        if d.canApprove == true, uc.status != "APPROVED" {
            HStack(spacing: 10) {
                Button {
                    Task { await doi(uc, uc.status == "PROPOSED" ? "DRAFT" : "APPROVED") }
                } label: {
                    Label(uc.status == "PROPOSED" ? "Accept proposal" : "Approve use case", systemImage: "checkmark.seal.fill")
                        .font(.ctw(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.success)
                .disabled(dangDoi)
            }
        }
    }

    private func doi(_ uc: CTWSrsUseCase, _ s: String) async {
        dangDoi = true
        defer { dangDoi = false }
        do {
            _ = try await APIClient.shared.send(CTWAPI.trangThaiUC(pid: pid, n: uc.number, trangThai: s))
            CTWRung.thanhCong()
            await kho.taiSrs()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }

    @ViewBuilder
    private func khoiChu(_ tieuDe: String, _ icon: String, _ chu: String?) -> some View {
        if let c = chu?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CTWSectionHeader(icon, tieuDe)
                CTWMarkdownView(markdown: c, coChu: 15)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ctwThe(14)
            }
        }
    }

    @ViewBuilder
    private func khoiLuong(_ tieuDe: String, _ icon: String, _ chu: String?, _ mau: Color) -> some View {
        let buoc = CTWLuongUC.tach(chu)
        if !buoc.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CTWSectionHeader(icon, tieuDe, count: "\(buoc.filter { $0.nhan != nil }.count)")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(buoc.enumerated()), id: \.offset) { i, b in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            if let nh = b.nhan {
                                Text(nh).font(.ctw(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundColor(b.laNhanh ? mau : AppColors.onPrimary)
                                    .padding(.horizontal, 6).frame(minWidth: 26, minHeight: 22)
                                    .background(Capsule().fill(b.laNhanh ? mau.opacity(0.14) : mau))
                            } else {
                                Color.clear.frame(width: 26, height: 1)
                            }
                            Text(CTWKhoiView.dong(b.chu)).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, b.laNhanh ? 18 : 0)
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                        if i < buoc.count - 1 { Divider().padding(.leading, b.laNhanh ? 54 : 36) }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 4)
                .ctwThe(14)
            }
        }
    }

    private func ghiChu(_ icon: String, _ chu: String, _ mau: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundColor(mau)
            Text(chu).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(mau.opacity(0.10)))
    }
}

// MARK: Màn hình (screen) — đi tới / đi từ / ai được vào

struct ChiTietManSrsCTW: View {
    let pid: Int
    let id: Int
    @ObservedObject private var kho: KhoYeuCauCTW

    init(pid: Int, id: Int) {
        self.pid = pid; self.id = id
        _kho = ObservedObject(wrappedValue: KhoYeuCauCTW.cua(pid))
    }

    var body: some View {
        List {
            if let d = kho.srs, let s = d.screen(id) {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.name ?? "Screen").font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        if let f = s.feature, !f.isEmpty { CTWNhanNho(chu: f, bieuTuong: "square.stack.3d.up") }
                        if let m = s.description, !m.isEmpty {
                            Text(m).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                let toi = d.diToi(tu: id)
                Section("Navigates to") {
                    if toi.isEmpty { Text("No outgoing links").foregroundColor(AppColors.textTertiary) }
                    ForEach(toi, id: \.screen.id) { t in
                        NavigationLink(value: RouteYeuCauCTW.man(pid: pid, id: t.screen.id)) {
                            HStack {
                                Image(systemName: "arrow.right.circle").foregroundColor(AppColors.primary)
                                Text(t.screen.name ?? "Screen").foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if let nh = t.nhan, !nh.isEmpty { Text(nh).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                            }
                        }
                    }
                }
                let tu = d.diTu(den: id)
                if !tu.isEmpty {
                    Section("Reached from") {
                        ForEach(tu) { t in
                            NavigationLink(value: RouteYeuCauCTW.man(pid: pid, id: t.id)) {
                                Label(t.name ?? "Screen", systemImage: "arrow.left.circle").foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                }
                Section {
                    ForEach((d.actors ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }) { a in
                        let duoc = d.duocVao(screen: id, actor: a.id)
                        HStack {
                            Text(a.name ?? "Actor").foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: duoc ? "checkmark.circle.fill" : "minus.circle")
                                .foregroundColor(duoc ? AppColors.success : AppColors.textTertiary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(duoc ? "Allowed" : "No access")
                    }
                } header: { Text("Screen authorization") }
                  footer: { Text("Who can open this screen. Edit the access grid on the web.") }
            } else if kho.srs != nil {
                CTWOTrong(bieuTuong: "rectangle.on.rectangle", tieuDe: "Screen not found").listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .navigationTitle(kho.srs?.screen(id)?.name ?? "Screen")
        .navigationBarTitleDisplayMode(.inline)
        .task { if kho.srs == nil { await kho.taiSrs() } }
    }
}

// MARK: Thảo luận = bình luận của thẻ liên kết

/// Bình luận thẻ hiện ngay trong UC / yêu cầu. Báo cáo đi route RIÊNG của bình luận thẻ
/// (`POST …/comments/:cid/report` — máy chủ ghi audit + báo admin dự án), ẩn bằng chung
/// kho với màn chi tiết thẻ ⇒ báo cáo ở đâu cũng ẩn ở mọi nơi.
struct ThaoLuanTheCTW: View {
    let pid: Int
    let so: Int
    let nguCanh: String
    @EnvironmentObject private var app: AppState
    @ObservedObject private var an = AnNoiDungCTW.shared
    @ObservedObject private var kiemDuyet = ModerationStore.shared
    @State private var ds: [CTWComment]?
    @State private var loi: String?
    @State private var baoCao: CTWComment?
    @State private var hoiChan: CTWUser?
    @State private var thongBao: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
            let hien = (ds ?? []).filter { c in
                !an.binhLuanAn.contains(c.id) && !(c.author.map { kiemDuyet.blockedUserIds.contains($0.id) } ?? false)
            }
            if ds != nil && hien.isEmpty {
                Text("No comments yet.").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
            }
            ForEach(hien) { c in dong(c) }
            if ds == nil && loi == nil { ProgressView().frame(maxWidth: .infinity) }
            if app.cauHinhDuAn?.coTheBinhLuan ?? true {
                CTWHopSoan(goiY: "Add to the discussion…") { chu in await gui(chu) }
            }
        }
        .task { if ds == nil { await tai() } }
        .confirmationDialog("Report this comment", isPresented: Binding(get: { baoCao != nil }, set: { if !$0 { baoCao = nil } }),
                            titleVisibility: .visible) {
            ForEach(ctwLyDoBaoCao, id: \.ma) { l in
                Button(l.nhan, role: .destructive) {
                    guard let c = baoCao else { return }
                    Task { await baoCaoBL(c, l.ma) }
                }
            }
        } message: { Text("Project admins will review it and remove it if it breaks the rules.") }
        .confirmationDialog("Block \(hoiChan?.ten ?? "this user")?", isPresented: Binding(get: { hoiChan != nil }, set: { if !$0 { hoiChan = nil } }),
                            titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                guard let u = hoiChan else { return }
                Task { do { try await kiemDuyet.block(userId: u.id) } catch { loi = CTW.loi(error) } }
            }
        } message: { Text("You won't see their comments or messages anywhere in the app.") }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func dong(_ c: CTWComment) -> some View {
        let laCuaToi = c.author?.id != nil && c.author?.id == app.currentUser?.id
        return HStack(alignment: .top, spacing: 10) {
            CTWAvatar(user: c.author, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.author?.ten ?? "Someone").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    if c.author?.laAgent == true { CTWNhanAI() } else if c.isAi == true { CTWNhanAI(chu: "AI-drafted") }
                    Spacer(minLength: 0)
                    Text(CTW.thoiDiem(c.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                }
                CTWTipTapView(doc: c.bodyJson, coChu: 14)
            }
        }
        .padding(12)
        .ctwThe(12)
        .contextMenu {
            Button { CTW.chepVaoBoNho(c.bodyJson?.chuTron ?? "") } label: { Label("Copy text", systemImage: "doc.on.doc") }
            if !laCuaToi {
                Button(role: .destructive) { baoCao = c } label: { Label("Report comment", systemImage: "flag") }
                if let a = c.author {
                    Button(role: .destructive) { hoiChan = a } label: { Label("Block \(a.ten)", systemImage: "hand.raised") }
                }
            }
        }
    }

    private func tai() async {
        do { ds = try await APIClient.shared.request(.workDsBinhLuan(pid: pid, so: so)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func gui(_ chu: String) async -> Bool {
        do {
            let c: CTWComment = try await APIClient.shared.request(
                .workThemBinhLuan(pid: pid, so: so, than: ["bodyJson": CTWNode.docTuChu(chu)]))
            ds = (ds ?? []) + [c]
            return true
        } catch { loi = CTW.loi(error); return false }
    }

    private func baoCaoBL(_ c: CTWComment, _ lyDo: String) async {
        do {
            let r: CTWBaoCaoKetQua = try await APIClient.shared.request(.workBaoCaoBinhLuan(pid: pid, so: so, cid: c.id, lyDo: lyDo))
            an.anBinhLuan(c.id)
            thongBao = r.duplicate == true ? "You already reported this comment."
                : "Thanks — project admins have been notified. The comment is hidden for you."
        } catch { loi = CTW.loi(error) }
    }
}

// MARK: Đề xuất use case

struct DeXuatUCCTW: View {
    let pid: Int
    @Environment(\.dismiss) private var dong
    @ObservedObject private var kho: KhoYeuCauCTW
    @State private var ten = ""
    @State private var tinhNang = ""
    @State private var actorChinh: Int?
    @State private var moTa = ""
    @State private var truoc = ""
    @State private var sau = ""
    @State private var luong = ""
    @State private var nhanh = ""
    @State private var uuTien = "MEDIUM"
    @State private var dangGui = false
    @State private var loi: String?

    init(pid: Int) {
        self.pid = pid
        _kho = ObservedObject(wrappedValue: KhoYeuCauCTW.cua(pid))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
                Section {
                    TextField("Name (e.g. Submit assignment)", text: $ten)
                    TextField("Feature", text: $tinhNang)
                    Picker("Primary actor", selection: $actorChinh) {
                        Text("None").tag(Int?.none)
                        ForEach(kho.srs?.actors ?? []) { a in Text(a.name ?? "Actor").tag(Int?.some(a.id)) }
                    }
                    Picker("Priority", selection: $uuTien) {
                        Text("High").tag("HIGH"); Text("Medium").tag("MEDIUM"); Text("Low").tag("LOW")
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Proposals stay out of the SRS until a teammate or lecturer accepts them.")
                }
                Section("Description") { o($moTa, "What the user achieves") }
                Section("Preconditions") { o($truoc, "e.g. The student is logged in") }
                Section("Normal flow") { o($luong, "1. …\n2. …\n3. …") }
                Section("Alternative flows") { o($nhanh, "2A. …") }
                Section("Postconditions") { o($sau, "e.g. The submission is stored") }
            }
            .navigationTitle("Propose use case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Propose") { Task { await gui() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangGui)
                }
            }
        }
    }

    private func o(_ b: Binding<String>, _ goiY: String) -> some View {
        TextField(goiY, text: b, axis: .vertical).lineLimit(2...10)
    }

    private func gui() async {
        dangGui = true
        defer { dangGui = false }
        func c(_ s: String) -> Any { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? NSNull() : t }
        var than: [String: Any] = [
            "name": ten.trimmingCharacters(in: .whitespaces), "status": "PROPOSED", "priority": uuTien,
            "feature": c(tinhNang), "description": c(moTa), "preconditions": c(truoc), "postconditions": c(sau),
            "normalFlow": c(luong), "alternativeFlows": c(nhanh),
        ]
        if let a = actorChinh { than["primaryActorId"] = a }
        do {
            _ = try await APIClient.shared.send(CTWAPI.deXuatUC(pid: pid, than: than))
            CTWRung.thanhCong()
            await kho.taiSrs()
            dong()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}

// MARK: Đề xuất quy tắc nghiệp vụ

struct DeXuatQuyTacCTW: View {
    let pid: Int
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var nhom = ""
    @State private var dinhNghia = ""
    @State private var dangGui = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
                Section {
                    TextField("Name (e.g. Max file size 20 MB)", text: $ten)
                    TextField("Category (e.g. Constraint)", text: $nhom)
                } footer: { Text("The rule is added as a proposal for the team to review.") }
                Section("Definition") {
                    TextField("State the rule precisely", text: $dinhNghia, axis: .vertical).lineLimit(3...10)
                }
            }
            .navigationTitle("Propose business rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Propose") { Task { await gui() } }
                        .disabled(ten.trimmingCharacters(in: .whitespaces).isEmpty || dangGui)
                }
            }
        }
    }

    private func gui() async {
        dangGui = true
        defer { dangGui = false }
        func c(_ s: String) -> Any { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? NSNull() : t }
        do {
            _ = try await APIClient.shared.send(CTWAPI.deXuatQuyTac(pid: pid, than: [
                "name": ten.trimmingCharacters(in: .whitespaces), "category": c(nhom), "definition": c(dinhNghia), "status": "PROPOSED",
            ]))
            CTWRung.thanhCong()
            await KhoYeuCauCTW.cua(pid).taiSrs()
            dong()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}
