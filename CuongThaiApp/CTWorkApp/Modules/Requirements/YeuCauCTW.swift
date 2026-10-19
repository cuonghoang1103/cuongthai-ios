import SwiftUI

// MARK: - Yêu cầu (SRS) — màn chính của mô-đun `requirements`
//
// MỘT lời gọi `GET /projects/:pid/srs` trả cả actor · UC · BR · màn · Non-UI (rẻ nhất ở
// máy chủ) ⇒ giữ trong một kho chung theo dự án (`KhoYeuCauCTW`) để màn chi tiết đọc
// lại mà không gọi thêm, và duyệt ở chi tiết thì danh sách đổi theo ngay.
// Phần thiết kế nặng (sơ đồ luồng màn, ma trận phân quyền dạng lưới, xuất Report 3)
// để ở web; ở đây ĐỌC đầy đủ + đề xuất + duyệt + thảo luận.

@MainActor
final class KhoYeuCauCTW: ObservableObject {
    private static var theoDuAn: [Int: KhoYeuCauCTW] = [:]
    static func cua(_ pid: Int) -> KhoYeuCauCTW {
        if let k = theoDuAn[pid] { return k }
        let k = KhoYeuCauCTW(pid: pid)
        theoDuAn[pid] = k
        return k
    }

    let pid: Int
    @Published var srs: CTWSrsData?
    @Published var rtm: CTWRtmData?
    @Published var swr: CTWSwrRequirementList?
    @Published var loi: String?
    @Published var loiRtm: String?
    /// Máy chủ trả 403 WORK_INTERNAL_ONLY (khách, khách mời) — nói rõ thay vì màn lỗi.
    @Published var noiBo = false

    private init(pid: Int) { self.pid = pid }

    func taiSrs() async {
        do {
            srs = try await APIClient.shared.request(CTWAPI.srs(pid: pid))
            loi = nil
        } catch { xuLy(error, vao: \.loi) }
    }

    func taiRtm() async {
        do {
            rtm = try await APIClient.shared.request(CTWAPI.rtm(pid: pid))
            loiRtm = nil
        } catch { xuLy(error, vao: \.loiRtm) }
    }

    func taiSwr() async {
        do {
            swr = try await APIClient.shared.request(CTWAPI.swrYeuCau(pid: pid))
            loi = nil
        } catch { xuLy(error, vao: \.loi) }
    }

    private func xuLy(_ e: Error, vao kp: ReferenceWritableKeyPath<KhoYeuCauCTW, String?>) {
        if case APIError.coMa(let ma, _) = e, ma == "WORK_INTERNAL_ONLY" { noiBo = true; return }
        self[keyPath: kp] = CTW.loi(e)
    }
}

/// Route con của mô-đun (đăng ký ở `MoDunRequirements.swift`).
enum RouteYeuCauCTW: Hashable {
    case uc(pid: Int, n: Int)
    case man(pid: Int, id: Int)
}

enum CTWNhanYeuCau {
    static func mauUC(_ s: String?) -> Color {
        switch s {
        case "APPROVED": return AppColors.success
        case "PROPOSED": return AppColors.primary
        default: return AppColors.textSecondary
        }
    }
    static func mauUuTien(_ p: String?) -> Color {
        switch p {
        case "HIGH": return AppColors.error
        case "MEDIUM": return AppColors.warning
        default: return AppColors.textSecondary
        }
    }
    static func nhanUuTien(_ p: String?) -> String? {
        guard let p, !p.isEmpty else { return nil }
        return CTWMauTrangThai.nhan(p)
    }
}

struct YeuCauCTW: View {
    let pid: Int
    @ObservedObject private var kho: KhoYeuCauCTW
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var phan: Phan = .uc
    @State private var tim = ""
    @State private var tamPhu: TamPhu?

    enum Phan: String, CaseIterable, Identifiable {
        case uc = "Use cases", actor = "Actors", rule = "Rules", man = "Screens", nonUI = "Non-UI", trace = "Trace"
        var id: String { rawValue }
        var bieuTuong: String {
            switch self {
            case .uc: return "person.2.wave.2"
            case .actor: return "person.crop.rectangle.stack"
            case .rule: return "checkmark.shield"
            case .man: return "rectangle.on.rectangle"
            case .nonUI: return "gearshape.2"
            case .trace: return "point.3.connected.trianglepath.dotted"
            }
        }
    }

    enum TamPhu: String, Identifiable { case deXuatUC, deXuatQuyTac, web; var id: String { rawValue } }

    init(pid: Int) {
        self.pid = pid
        _kho = ObservedObject(wrappedValue: KhoYeuCauCTW.cua(pid))
    }

    var body: some View {
        List {
            if let loi = kho.loi {
                CTWErrorBanner(text: loi) { kho.loi = nil }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if kho.noiBo {
                CTWOTrong(bieuTuong: "lock.doc", tieuDe: "Team only",
                          moTa: "Requirements are only available to the project team and lecturers.")
                    .listRowBackground(Color.clear)
            } else if let d = kho.srs {
                Section { tomTat(d) }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                Section {
                    CTWThanhLoc(chip: Phan.allCases.map { CTWChipLoc(id: $0.rawValue, nhan: $0.rawValue, bieuTuong: $0.bieuTuong, bat: phan == $0) }) { c in
                        phan = Phan(rawValue: c.id) ?? .uc
                    }
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                noiDung(d)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if kho.srs == nil && kho.loi == nil && !kho.noiBo { CTWKhungTai(soHang: 6, coAvatar: false) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search requirements")
        .navigationTitle("Requirements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { thanhCongCu }
        .refreshable { await kho.taiSrs(); if phan == .trace { await kho.taiRtm() } }
        .task { if kho.srs == nil { await kho.taiSrs() } }
        .task(id: phan) { if phan == .trace, kho.rtm == nil { await kho.taiRtm() } }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .deXuatUC: DeXuatUCCTW(pid: pid)
            case .deXuatQuyTac: DeXuatQuyTacCTW(pid: pid)
            case .web:
                if let l = app.luaChon, let u = CTWWeb.url(slug: l.slug, ma: l.maDuAn, doan: "requirements") {
                    SafariCTW(url: u).ignoresSafeArea()
                }
            }
        }
        // `/work/<ws>/<KEY>/requirements?uc=3` ⇒ mở UC-03.
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "requirements" else { return }
            defer { app.dichCho = nil }
            if let n = d.duongDan.tham["uc"].flatMap(Int.init) ?? d.duongDan.phanCon.first.flatMap(Int.init) {
                nganXep.duong.append(RouteYeuCauCTW.uc(pid: pid, n: n))
            }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("requirements") == "uc", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteYeuCauCTW.uc(pid: pid, n: 3))
            }
        }
        #endif
    }

    @ToolbarContentBuilder
    private var thanhCongCu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if kho.srs?.canEdit == true {
                    Button { tamPhu = .deXuatUC } label: { Label("Propose use case", systemImage: "plus.bubble") }
                    Button { tamPhu = .deXuatQuyTac } label: { Label("Propose business rule", systemImage: "checkmark.shield") }
                    Divider()
                }
                Button { tamPhu = .web } label: { Label("Open SRS on the web", systemImage: "safari") }
            } label: {
                Image(systemName: kho.srs?.canEdit == true ? "plus.circle" : "ellipsis.circle")
            }
            .accessibilityLabel("Requirement actions")
        }
    }

    // MARK: Tóm tắt

    private func tomTat(_ d: CTWSrsData) -> some View {
        let c = d.counts
        let ucs = d.useCases ?? []
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
            CTWODem(so: "\(c?.useCases ?? ucs.count)", nhan: "Use cases", bieuTuong: "person.2.wave.2")
            CTWODem(so: "\(c?.approved ?? ucs.filter { $0.status == "APPROVED" }.count)", nhan: "Approved",
                    bieuTuong: "checkmark.seal", mau: AppColors.success)
            CTWODem(so: "\(c?.proposed ?? ucs.filter { $0.status == "PROPOSED" }.count)", nhan: "Proposals",
                    bieuTuong: "sparkles", mau: AppColors.accent)
            CTWODem(so: "\(c?.rules ?? d.rules?.count ?? 0)", nhan: "Business rules", bieuTuong: "checkmark.shield",
                    mau: AppColors.secondary)
        }
        .padding(.horizontal, 2)
    }

    // MARK: Nội dung theo phần

    @ViewBuilder
    private func noiDung(_ d: CTWSrsData) -> some View {
        let t = tim.trimmingCharacters(in: .whitespaces).lowercased()
        switch phan {
        case .uc:
            let nhom = d.ucTheoTinhNang.compactMap { n -> (String, [CTWSrsUseCase])? in
                let ds = n.ds.filter { khop(t, $0.ma, $0.name, $0.description, $0.feature) }
                return ds.isEmpty ? nil : (n.tinhNang, ds)
            }
            if nhom.isEmpty {
                trong("person.2.wave.2", t.isEmpty ? "No use cases yet" : "No matches",
                      t.isEmpty ? "Use cases your team writes in CT Work show up here." : "Try another word.")
            }
            ForEach(nhom, id: \.0) { n in
                Section(n.0) {
                    ForEach(n.1) { u in
                        NavigationLink(value: RouteYeuCauCTW.uc(pid: pid, n: u.number)) { HangUCCTW(uc: u, d: d) }
                    }
                }
            }
        case .actor:
            let ds = (d.actors ?? []).filter { khop(t, $0.name, $0.description) }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            if ds.isEmpty { trong("person.crop.rectangle.stack", "No actors", "Actors are the people and systems that use the product.") }
            Section {
                ForEach(ds) { a in hangActor(a, d) }
            }
        case .rule:
            let ds = (d.rules ?? []).filter { khop(t, $0.ma, $0.name, $0.definition, $0.category) }.sorted { $0.number < $1.number }
            if ds.isEmpty { trong("checkmark.shield", "No business rules", "") }
            Section {
                ForEach(ds) { r in HangQuyTacCTW(pid: pid, r: r, d: d) }
            }
        case .man:
            let ds = (d.screens ?? []).filter { khop(t, $0.name, $0.feature, $0.description) }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            if ds.isEmpty { trong("rectangle.on.rectangle", "No screens", "") }
            Section {
                ForEach(ds) { s in
                    NavigationLink(value: RouteYeuCauCTW.man(pid: pid, id: s.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.name ?? "Screen").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            HStack(spacing: 6) {
                                if let f = s.feature, !f.isEmpty { CTWNhanNho(chu: f, bieuTuong: "square.stack.3d.up") }
                                let a = d.actorsCho(screen: s.id).count
                                Text("\(a) actor\(a == 1 ? "" : "s") · \(d.diToi(tu: s.id).count) links")
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } footer: {
                if !ds.isEmpty { Text("The screen-flow diagram and the access grid are easier to edit on the web.") }
            }
        case .nonUI:
            let ds = (d.functions ?? []).filter { khop(t, $0.name, $0.feature, $0.description) }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            if ds.isEmpty { trong("gearshape.2", "No non-UI functions", "Background jobs, integrations and scheduled tasks are listed here.") }
            Section {
                ForEach(ds) { f in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(f.name ?? "Function").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            Spacer(minLength: 0)
                            if let fe = f.feature, !fe.isEmpty { CTWNhanNho(chu: fe) }
                        }
                        if let m = f.description, !m.isEmpty {
                            Text(m).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        case .trace:
            TruyVetCTW(pid: pid, kho: kho, tim: t)
        }
    }

    private func khop(_ t: String, _ s: String?...) -> Bool { t.isEmpty || s.contains { ($0 ?? "").lowercased().contains(t) } }

    private func hangActor(_ a: CTWSrsActor, _ d: CTWSrsData) -> some View {
        let chinh = (d.useCases ?? []).filter { $0.primaryActorId == a.id }
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: a.kind == "SYSTEM" ? "server.rack" : "person.fill")
                .font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(a.name ?? "Actor").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    CTWNhanNho(chu: a.kind == "SYSTEM" ? "System" : "Person")
                }
                if let m = a.description, !m.isEmpty {
                    Text(m).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                if !chinh.isEmpty {
                    Text("Primary actor in " + chinh.map(\.ma).joined(separator: ", "))
                        .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private func trong(_ icon: String, _ tieuDe: String, _ moTa: String) -> some View {
        CTWOTrong(bieuTuong: icon, tieuDe: tieuDe, moTa: moTa).listRowBackground(Color.clear)
    }
}

// MARK: - Hàng UC

struct HangUCCTW: View {
    let uc: CTWSrsUseCase
    let d: CTWSrsData

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(uc.ma).font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                Text(uc.name ?? "Use case").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                CTWChipChu(chu: uc.status ?? "DRAFT", mau: CTWNhanYeuCau.mauUC(uc.status))
                if let p = CTWNhanYeuCau.nhanUuTien(uc.priority) {
                    CTWNhanNho(chu: p, bieuTuong: "flag.fill", mau: CTWNhanYeuCau.mauUuTien(uc.priority))
                }
                if uc.aiModel != nil { CTWNhanAI(chu: "AI-drafted") }
                if let a = d.actor(uc.primaryActorId)?.name {
                    Text(a).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                }
            }
            if let m = uc.missing, !m.isEmpty {
                Label("Missing: " + m.joined(separator: ", "), systemImage: "exclamationmark.triangle.fill")
                    .font(.ctw(size: 11.5)).foregroundColor(AppColors.warning).lineLimit(2)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Hàng quy tắc nghiệp vụ (mở ra xem định nghĩa; duyệt bằng nhấn giữ)

struct HangQuyTacCTW: View {
    let pid: Int
    let r: CTWSrsRule
    let d: CTWSrsData
    @State private var mo = false
    @State private var loi: String?

    var body: some View {
        DisclosureGroup(isExpanded: $mo) {
            VStack(alignment: .leading, spacing: 8) {
                Text(r.definition?.isEmpty == false ? r.definition! : "No definition yet.")
                    .font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let u = r.usedIn, !u.isEmpty {
                    Text("Used in " + u.joined(separator: ", ")).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                if let loi { Text(loi).font(.ctw(size: 12)).foregroundColor(AppColors.error) }
                if d.canApprove == true, r.status != "APPROVED" {
                    Button {
                        Task { await doi(r.status == "PROPOSED" ? "DRAFT" : "APPROVED") }
                    } label: {
                        Label(r.status == "PROPOSED" ? "Accept proposal" : "Approve", systemImage: "checkmark.seal")
                            .font(.ctw(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.success)
                }
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(r.ma).font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.secondary)
                    Text(r.name ?? "Rule").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    CTWChipChu(chu: r.status ?? "DRAFT", mau: CTWNhanYeuCau.mauUC(r.status))
                    if let c = r.category, !c.isEmpty { CTWNhanNho(chu: c) }
                    if r.aiModel != nil { CTWNhanAI(chu: "AI-drafted") }
                }
            }
            .padding(.vertical, 2)
        }
        .contextMenu {
            Button { CTW.chepVaoBoNho("\(r.ma) \(r.name ?? "")\n\(r.definition ?? "")") } label: { Label("Copy", systemImage: "doc.on.doc") }
        }
    }

    private func doi(_ s: String) async {
        do {
            _ = try await APIClient.shared.send(CTWAPI.trangThaiQuyTac(pid: pid, n: r.number, trangThai: s))
            CTWRung.thanhCong()
            await KhoYeuCauCTW.cua(pid).taiSrs()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}

// MARK: - Truy vết (RTM) — chỉ đọc

struct TruyVetCTW: View {
    let pid: Int
    @ObservedObject var kho: KhoYeuCauCTW
    let tim: String

    var body: some View {
        if let loi = kho.loiRtm {
            Section { CTWErrorBanner(text: loi) { kho.loiRtm = nil } }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
        }
        if let r = kho.rtm {
            let s = r.summary
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    CTWODem(so: "\(s?.rows ?? r.rows?.count ?? 0)", nhan: "Traced items", bieuTuong: "list.bullet.rectangle")
                    CTWODem(so: "\(Int((s?.testedPct ?? 0).rounded()))%", nhan: "Have tests", bieuTuong: "checkmark.circle", mau: AppColors.success)
                    CTWODem(so: "\(s?.passing ?? 0)", nhan: "Passing", bieuTuong: "checkmark.seal", mau: AppColors.success)
                    CTWODem(so: "\(s?.withGaps ?? 0)", nhan: "With gaps", bieuTuong: "exclamationmark.triangle", mau: AppColors.warning)
                }
                .padding(.horizontal, 2)
            }
            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            let ds = (r.rows ?? []).filter {
                tim.isEmpty || [$0.reqId, $0.requirement, $0.feature, $0.issueKey].contains { ($0 ?? "").lowercased().contains(tim) }
            }
            Section {
                if ds.isEmpty {
                    Text(tim.isEmpty ? "Nothing to trace yet." : "No matches.").foregroundColor(AppColors.textSecondary)
                }
                ForEach(ds) { row in
                    if let n = row.issueNumber {
                        NavigationLink(value: CTWRoute.the(pid: pid, so: n)) { hang(row, r) }
                    } else if let uc = row.ucNumber {
                        NavigationLink(value: RouteYeuCauCTW.uc(pid: pid, n: uc)) { hang(row, r) }
                    } else {
                        hang(row, r)
                    }
                }
            } header: { Text("Requirements traceability") }
              footer: { Text("Export the full RTM (Excel) from the web.") }
        } else if kho.loiRtm == nil {
            Section { ProgressView().frame(maxWidth: .infinity).padding() }
                .listRowBackground(Color.clear)
        }
    }

    private func hang(_ row: CTWRtmRow, _ r: CTWRtmData) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(row.reqId).font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                Text(row.requirement ?? "").font(.ctw(size: 14.5, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
            }
            HStack(spacing: 6) {
                CTWChipChu(chu: row.status ?? "Planned", mau: mauTrangThai(row.status))
                if let k = row.issueKey { CTWNhanNho(chu: k, bieuTuong: "number") }
                let ca = row.soCaKiem
                if ca > 0 { CTWNhanNho(chu: "\(ca) test\(ca == 1 ? "" : "s")", bieuTuong: "checkmark.circle") }
                let mo = (row.bugs ?? []).filter { $0.open == true }.count
                if mo > 0 { CTWNhanNho(chu: "\(mo) open bug\(mo == 1 ? "" : "s")", bieuTuong: "ladybug", mau: AppColors.error) }
            }
            if let g = row.gaps, !g.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(g, id: \.self) { code in
                            CTWNhanNho(chu: r.gapLabels?[code] ?? CTWMauTrangThai.nhan(code), bieuTuong: "exclamationmark.triangle",
                                       mau: AppColors.warning)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func mauTrangThai(_ s: String?) -> Color {
        switch s {
        case "Tested": return AppColors.success
        case "Coded": return AppColors.info
        case "Designed", "Analyzed": return AppColors.secondary
        default: return AppColors.textSecondary
        }
    }
}
