import SwiftUI

// MARK: - Wiegers — các mục đọc: tính năng · stakeholder · thuật ngữ · elicitation · NFR · prototype
//
// Mỗi màn tự tải một route nhẹ của `swr*` (đều chỉ 1–2 truy vấn ở máy chủ).

/// Khung chung: tải `T` một lần, kéo để làm mới, lỗi tại chỗ, 403 nội bộ nói rõ.
@MainActor
final class TaiMotCTW<T: Decodable>: ObservableObject {
    @Published var gt: T?
    @Published var loi: String?
    @Published var noiBo = false
    let ep: () -> APIEndpoint
    init(_ ep: @escaping () -> APIEndpoint) { self.ep = ep }
    func tai() async {
        do { gt = try await APIClient.shared.request(ep()); loi = nil }
        catch {
            if case APIError.coMa(let ma, _) = error, ma == "WORK_INTERNAL_ONLY" { noiBo = true; return }
            loi = CTW.loi(error)
        }
    }
}

private struct KhungDanhSach<NoiDung: View>: View {
    let tieuDe: LocalizedStringKey
    let dangTai: Bool
    let loi: String?
    let noiBo: Bool
    let lamMoi: () async -> Void
    @ViewBuilder let noiDung: () -> NoiDung

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if noiBo {
                CTWOTrong(bieuTuong: "lock.doc", tieuDe: String(localized: "Team only"), moTa: String(localized: "This part of the project is only available to the team and lecturers."))
                    .listRowBackground(Color.clear)
            } else { noiDung() }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if dangTai { CTWKhungTai(soHang: 5, coAvatar: false) } }
        .navigationTitle(tieuDe)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await lamMoi() }
        .task { if dangTai { await lamMoi() } }
    }
}

// MARK: Tính năng

struct WTinhNangCTW: View {
    let pid: Int
    @StateObject private var t: TaiMotCTW<CTWSwrFeatureList>
    init(pid: Int) { self.pid = pid; _t = StateObject(wrappedValue: TaiMotCTW { CTWAPI.swrTinhNang(pid: pid) }) }

    var body: some View {
        KhungDanhSach(tieuDe: "Features", dangTai: t.gt == nil && t.loi == nil && !t.noiBo, loi: t.loi, noiBo: t.noiBo, lamMoi: t.tai) {
            let ds = t.gt?.features ?? []
            if t.gt != nil && ds.isEmpty {
                CTWOTrong(bieuTuong: "square.stack.3d.up", tieuDe: String(localized: "No features yet"), moTa: String(localized: "Features define the product scope in the vision document."))
                    .listRowBackground(Color.clear)
            }
            ForEach(["IN", "OUT"], id: \.self) { pv in
                let nhom = ds.filter { ($0.scope ?? "IN") == pv }
                if !nhom.isEmpty {
                    Section(pv == "IN" ? "In scope" : "Out of scope") {
                        ForEach(nhom) { f in hang(f) }
                    }
                }
            }
        }
    }

    private func hang(_ f: CTWSwrFeature) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                if let m = f.description, !m.isEmpty {
                    Text(m).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
                if let e = f.epic, let n = e.number {
                    NavigationLink(value: CTWRoute.the(pid: pid, so: n)) {
                        Label("Epic \(e.key ?? "#\(n)") · \(e.title ?? "")", systemImage: "bolt.fill").font(.ctw(size: 13))
                    }
                }
                ForEach(f.useCases ?? [], id: \.number) { u in
                    NavigationLink(value: RouteYeuCauCTW.uc(pid: pid, n: u.number)) {
                        HStack(spacing: 6) {
                            Text(u.key ?? "UC").font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                            Text(u.name ?? "").font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                            Spacer(minLength: 0)
                            CTWChipChu(chu: u.status, mau: CTWNhanYeuCau.mauUC(u.status))
                        }
                    }
                }
                ForEach(f.issues ?? [], id: \.number) { i in
                    NavigationLink(value: CTWRoute.the(pid: pid, so: i.number)) {
                        Label("\(i.key ?? "#\(i.number)") · \(i.title ?? "")", systemImage: CTW.bieuTuongLoai(key: i.type))
                            .font(.ctw(size: 13)).lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(f.key ?? "FE").font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                    Text(f.name ?? String(localized: "Feature")).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    if let p = CTWNhanYeuCau.nhanUuTien(f.priority) { CTWNhanNho(chu: p, bieuTuong: "flag.fill", mau: CTWNhanYeuCau.mauUuTien(f.priority)) }
                    if let r = f.release, !r.isEmpty { CTWNhanNho(chu: r, bieuTuong: "shippingbox") }
                    Text("\(f.useCases?.count ?? 0) use cases").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    if f.realized == true {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success).font(.ctw(size: 13))
                            .accessibilityLabel("Realized")
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: Stakeholder — lưới ảnh hưởng/quan tâm 2×2

struct WBenLienQuanCTW: View {
    let pid: Int
    @StateObject private var t: TaiMotCTW<CTWSwrStakeholderList>
    init(pid: Int) { self.pid = pid; _t = StateObject(wrappedValue: TaiMotCTW { CTWAPI.swrBenLienQuan(pid: pid) }) }

    /// Thứ tự ô như web: hàng trên = ảnh hưởng CAO.
    static var o: [(ma: String, ten: String, icon: String)] { [
        ("KEEP_SATISFIED", String(localized: "Keep satisfied"), "hand.thumbsup"), ("MANAGE_CLOSELY", String(localized: "Manage closely"), "star.circle"),
        ("MONITOR", String(localized: "Monitor"), "eye"), ("KEEP_INFORMED", String(localized: "Keep informed"), "envelope"),
    ] }

    var body: some View {
        KhungDanhSach(tieuDe: "Stakeholders", dangTai: t.gt == nil && t.loi == nil && !t.noiBo, loi: t.loi, noiBo: t.noiBo, lamMoi: t.tai) {
            let ds = t.gt?.stakeholders ?? []
            if t.gt != nil && ds.isEmpty {
                CTWOTrong(bieuTuong: "person.3", tieuDe: String(localized: "No stakeholders yet"), moTa: String(localized: "Add stakeholders on the web to plan elicitation."))
                    .listRowBackground(Color.clear)
            }
            if !ds.isEmpty {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Self.o, id: \.ma) { q in
                            let ten = ds.filter { $0.quadrant == q.ma }.compactMap(\.name)
                            VStack(alignment: .leading, spacing: 6) {
                                Label(q.ten, systemImage: q.icon).font(.ctw(size: 12.5, weight: .semibold))
                                    .foregroundColor(q.ma == "MANAGE_CLOSELY" ? AppColors.primary : AppColors.textSecondary)
                                Text(ten.isEmpty ? "—" : ten.joined(separator: ", "))
                                    .font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(q.ma == "MANAGE_CLOSELY" ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    HStack {
                        Text("↑ Influence").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                        Spacer()
                        Text("Interest →").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                    .accessibilityHidden(true)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)).listRowBackground(Color.clear)
                Section("All stakeholders") {
                    ForEach(ds) { s in
                        NavigationLink(value: RouteWiegersCTW.benLienQuanChiTiet(pid: pid, sh: s)) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(s.name ?? String(localized: "Stakeholder")).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                                    if s.isChampion == true { CTWNhanNho(chu: String(localized: "Champion"), bieuTuong: "crown", mau: AppColors.accent) }
                                }
                                Text([s.role, s.organization].compactMap { $0 }.joined(separator: " · "))
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}

struct WBenLienQuanChiTietCTW: View {
    let sh: CTWSwrStakeholder
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sh.key ?? "SH").font(.ctw(size: 13, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                    Text(sh.name ?? String(localized: "Stakeholder")).font(.ctw(size: 24, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    HStack(spacing: 6) {
                        if let q = sh.quadrant { CTWChipChu(chu: q, mau: q == "MANAGE_CLOSELY" ? AppColors.primary : AppColors.textSecondary) }
                        if let a = sh.attitude { CTWNhanNho(chu: CTWMauTrangThai.nhan(a), mau: a == "BLOCKER" || a == "CRITIC" ? AppColors.error : AppColors.success) }
                    }
                }
                CTWKhoiTruong {
                    CTWHangTruong(String(localized: "Role"), sh.role, bieuTuong: "person.text.rectangle"); Divider()
                    CTWHangTruong(String(localized: "Organization"), sh.organization, bieuTuong: "building.2"); Divider()
                    CTWHangTruong(String(localized: "User class"), sh.userClass, bieuTuong: "person.2"); Divider()
                    CTWHangTruong(String(localized: "Influence"), sh.influence.map { "\($0) / 5" }, bieuTuong: "arrow.up.right"); Divider()
                    CTWHangTruong(String(localized: "Interest"), sh.interest.map { "\($0) / 5" }, bieuTuong: "heart"); Divider()
                    CTWHangTruong(String(localized: "Requirements"), sh.requirements.map(String.init), bieuTuong: "list.bullet"); Divider()
                    CTWHangTruong(String(localized: "Sessions"), (sh.sessions ?? []).joined(separator: ", "), bieuTuong: "bubble.left.and.bubble.right")
                }
                ForEach([(String(localized: "Decision rights"), sh.decisionRights), (String(localized: "Major value"), sh.majorValue), (String(localized: "Interests"), sh.interests),
                         (String(localized: "Constraints"), sh.constraints), (String(localized: "Notes"), sh.notes)], id: \.0) { m in
                    if let c = m.1, !c.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(m.0).font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            Text(c).font(.ctw(size: 15)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(sh.key ?? String(localized: "Stakeholder"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Thuật ngữ

struct WThuatNguCTW: View {
    let pid: Int
    @StateObject private var t: TaiMotCTW<CTWSwrGlossary>
    @State private var tim = ""
    init(pid: Int) { self.pid = pid; _t = StateObject(wrappedValue: TaiMotCTW { CTWAPI.swrThuatNgu(pid: pid) }) }

    var body: some View {
        KhungDanhSach(tieuDe: "Glossary", dangTai: t.gt == nil && t.loi == nil && !t.noiBo, loi: t.loi, noiBo: t.noiBo, lamMoi: t.tai) {
            let q = tim.trimmingCharacters(in: .whitespaces).lowercased()
            let ds = (t.gt?.terms ?? []).filter { x in
                q.isEmpty || ([x.term, x.definition] + (x.aliases ?? []).map { Optional($0) }).contains { ($0 ?? "").lowercased().contains(q) }
            }.sorted { ($0.term ?? "").localizedCaseInsensitiveCompare($1.term ?? "") == .orderedAscending }
            if let c = t.gt?.clashes, !c.isEmpty {
                Section {
                    let tu = c.compactMap(\.word).joined(separator: ", ")
                    Label(c.count == 1 ? String(localized: "1 word defined more than once: \(tu)") : String(localized: "\(c.count) words defined more than once: \(tu)"),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.warning)
                }
            }
            if t.gt != nil && ds.isEmpty {
                CTWOTrong(bieuTuong: "character.book.closed", tieuDe: q.isEmpty ? String(localized: "No terms yet") : String(localized: "No matches")).listRowBackground(Color.clear)
            }
            Section {
                ForEach(ds) { x in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(x.term ?? "").font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                        Text(x.definition ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                        if let a = x.aliases, !a.isEmpty {
                            Text(String(localized: "Also: \(a.joined(separator: ", "))")).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        if let s = x.source, !s.isEmpty { Text("Source: \(s)").font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary) }
                    }
                    .padding(.vertical, 3)
                    .textSelection(.enabled)
                }
            }
        }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search terms")
    }
}

// MARK: Phiên elicitation

struct WPhienCTW: View {
    let pid: Int
    @StateObject private var t: TaiMotCTW<CTWSwrSessions>
    init(pid: Int) { self.pid = pid; _t = StateObject(wrappedValue: TaiMotCTW { CTWAPI.swrPhien(pid: pid) }) }

    var body: some View {
        KhungDanhSach(tieuDe: "Elicitation", dangTai: t.gt == nil && t.loi == nil && !t.noiBo, loi: t.loi, noiBo: t.noiBo, lamMoi: t.tai) {
            let ds = t.gt?.sessions ?? []
            if t.gt != nil && ds.isEmpty {
                CTWOTrong(bieuTuong: "bubble.left.and.text.bubble.right", tieuDe: String(localized: "No sessions yet"),
                          moTa: String(localized: "Plan interviews and workshops on the web; notes and proposals show up here."))
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(ds) { s in
                    NavigationLink(value: RouteWiegersCTW.phienChiTiet(pid: pid, n: s.number)) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(s.key ?? "ELC").font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                                Text(s.title ?? String(localized: "Session")).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                            }
                            HStack(spacing: 6) {
                                CTWChipChu(chu: s.status ?? "PLANNED", mau: s.status == "DONE" ? AppColors.success : (s.status == "CANCELLED" ? AppColors.error : AppColors.info))
                                CTWNhanNho(chu: CTWMauTrangThai.nhan(s.technique), bieuTuong: bieuTuongKyThuat(s.technique))
                                if s.aiSimulated == true { CTWNhanAI(chu: String(localized: "AI-simulated")) }
                            }
                            Text(([String(localized: "\(s.answered ?? 0)/\(s.questions ?? 0) answered"),
                                  String(localized: "\(s.requirements ?? 0) requirements"),
                                  (s.pending ?? 0) > 0 ? String(localized: "\(s.pending ?? 0) pending") : nil,
                                  CTW.ngayNgan(s.scheduledAt)] as [String?]).compactMap { $0 }.joined(separator: " · "))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }
}

func bieuTuongKyThuat(_ t: String?) -> String {
    switch t {
    case "INTERVIEW": return "person.2.wave.2"
    case "WORKSHOP": return "person.3.sequence"
    case "SURVEY": return "list.clipboard"
    case "OBSERVATION": return "eye"
    case "DOCUMENT_ANALYSIS": return "doc.text.magnifyingglass"
    case "PROTOTYPE": return "iphone.gen3"
    default: return "bubble.left.and.bubble.right"
    }
}

struct WPhienChiTietCTW: View {
    let pid: Int
    let n: Int
    @StateObject private var t: TaiMotCTW<CTWSwrSessionDetail>
    @State private var deXuat = false

    init(pid: Int, n: Int) {
        self.pid = pid; self.n = n
        _t = StateObject(wrappedValue: TaiMotCTW { CTWAPI.swrPhien(pid: pid, n: n) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi = t.loi { CTWErrorBanner(text: loi) }
                if let s = t.gt { noiDung(s) } else if t.loi == nil { CTWKhungTai(soHang: 4, coAvatar: false) }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(t.gt?.key ?? String(localized: "Session"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if t.gt?.canEdit == true {
                ToolbarItem(placement: .primaryAction) {
                    Button { deXuat = true } label: { Image(systemName: "plus.bubble") }
                        .accessibilityLabel("Propose requirement")
                }
            }
        }
        .refreshable { await t.tai() }
        .task { if t.gt == nil { await t.tai() } }
        .sheet(isPresented: $deXuat) {
            DeXuatYeuCauCTW(pid: pid, n: n, nguoi: t.gt?.participants ?? []) { await t.tai() }
        }
    }

    @ViewBuilder
    private func noiDung(_ s: CTWSwrSessionDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.title ?? String(localized: "Session")).font(.ctw(size: 23, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                CTWChipChu(chu: s.status ?? "PLANNED", mau: s.status == "DONE" ? AppColors.success : AppColors.info)
                CTWNhanNho(chu: CTWMauTrangThai.nhan(s.technique), bieuTuong: bieuTuongKyThuat(s.technique))
                if s.aiSimulated == true { CTWNhanAI(chu: String(localized: "AI-simulated")) }
            }
        }
        CTWKhoiTruong {
            CTWHangTruong(String(localized: "When"), s.scheduledAt.map { CTW.thoiDiem($0) }, bieuTuong: "calendar"); Divider()
            CTWHangTruong(String(localized: "Duration"), s.durationMin.map { String(localized: "\($0) min") }, bieuTuong: "clock"); Divider()
            CTWHangTruong(String(localized: "Location"), s.location, bieuTuong: "mappin.and.ellipse"); Divider()
            CTWHangTruong(String(localized: "Participants"), (s.participants ?? []).compactMap { p in
                p.name.map { $0 + (p.rolePlayed.map { " (\($0))" } ?? "") }
            }.joined(separator: ", "), bieuTuong: "person.2")
        }
        ForEach([(String(localized: "Objective"), "target", s.objective), (String(localized: "Plan"), "list.number", s.plan)], id: \.0) { k in
            if let c = k.2, !c.isEmpty {
                CTWSectionHeader(k.1, k.0)
                CTWMarkdownView(markdown: c, coChu: 15).padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
            }
        }
        if let q = s.questions, !q.isEmpty {
            CTWSectionHeader("questionmark.bubble", String(localized: "Questions"), count: "\(q.filter { !($0.answer ?? "").isEmpty }.count)/\(q.count)")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(q.enumerated()), id: \.offset) { i, c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(i + 1). \(c.text ?? "")").font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(c.answer?.isEmpty == false ? c.answer! : String(localized: "Not answered yet"))
                            .font(.ctw(size: 14)).foregroundColor(c.answer?.isEmpty == false ? AppColors.textPrimary : AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 9)
                    if i < q.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14).ctwThe(14)
        }
        ForEach([(String(localized: "Notes"), "note.text", s.notes), (String(localized: "Outcome"), "flag.checkered", s.outcome)], id: \.0) { k in
            if let c = k.2, !c.isEmpty {
                CTWSectionHeader(k.1, k.0)
                CTWMarkdownView(markdown: c, coChu: 15).padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
            }
        }
        if let p = s.proposals, !p.isEmpty {
            CTWSectionHeader("sparkles", String(localized: "Proposed requirements"), count: "\(p.count)")
            VStack(spacing: 8) {
                ForEach(p) { x in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            CTWChipChu(chu: x.status ?? "PENDING", mau: x.status == "ACCEPTED" ? AppColors.success : (x.status == "DISMISSED" ? AppColors.textTertiary : AppColors.warning))
                            CTWNhanNho(chu: CTWVongDoiYeuCau.tenLoai(x.reqType))
                            if x.model != nil { CTWNhanAI(chu: String(localized: "AI-drafted")) }
                            Spacer(minLength: 0)
                            if let i = x.issue { Text(i).font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary) }
                        }
                        Text(x.title ?? "").font(.ctw(size: 14.5, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let tx = x.text, !tx.isEmpty {
                            Text(tx).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                        if let q = x.evidence?.first?.quote, !q.isEmpty {
                            Text("“\(q)”").font(.ctw(size: 12.5).italic()).foregroundColor(AppColors.textTertiary).lineLimit(3)
                        }
                        if let sh = x.stakeholder?.name { Text("From \(sh)").font(.ctw(size: 11.5)).foregroundColor(AppColors.textTertiary) }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).ctwThe(12)
                }
            }
            Text("Accept or dismiss proposals on the web — accepting creates a requirement issue.")
                .font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
        }
        if let r = s.requirements, !r.isEmpty {
            CTWSectionHeader("list.bullet.rectangle.portrait", String(localized: "Requirements from this session"), count: "\(r.count)")
            VStack(spacing: 0) {
                ForEach(Array(r.enumerated()), id: \.offset) { i, q in
                    if let num = q.number {
                        NavigationLink(value: RouteWiegersCTW.yeuCauChiTiet(pid: pid, so: num)) {
                            HStack(spacing: 8) {
                                Text(q.key ?? "#\(num)").font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                                Text(q.title ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                                Spacer(minLength: 0)
                                CTWChipChu(chu: q.lifecycle ?? "PROPOSED", mau: mauVongDoi(q.lifecycle))
                            }
                            .padding(.vertical, 10).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if i < r.count - 1 { Divider() }
                    }
                }
            }
            .padding(.horizontal, 14).ctwThe(14)
        }
    }
}

struct DeXuatYeuCauCTW: View {
    let pid: Int
    let n: Int
    let nguoi: [CTWSwrSessionDetail.NguoiThamGia]
    let xong: () async -> Void
    @Environment(\.dismiss) private var dong
    @State private var tieuDe = ""
    @State private var chu = ""
    @State private var loai = "FUNCTIONAL"
    @State private var uuTien = "MEDIUM"
    @State private var benLQ: Int?
    @State private var dangGui = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
                Section {
                    TextField("Short title (at least 3 characters)", text: $tieuDe)
                    TextField("The system shall…", text: $chu, axis: .vertical).lineLimit(3...10)
                } footer: { Text("Proposals wait in this session until someone accepts them.") }
                Section {
                    Picker("Type", selection: $loai) {
                        ForEach(["BUSINESS", "USER", "FUNCTIONAL", "QUALITY", "CONSTRAINT", "EXTERNAL_INTERFACE", "DATA"], id: \.self) {
                            Text(CTWVongDoiYeuCau.tenLoai($0)).tag($0)
                        }
                    }
                    Picker("Priority", selection: $uuTien) { Text("High").tag("HIGH"); Text("Medium").tag("MEDIUM"); Text("Low").tag("LOW") }
                    if !nguoi.isEmpty {
                        Picker("Stakeholder", selection: $benLQ) {
                            Text("None").tag(Int?.none)
                            ForEach(nguoi.compactMap { p in p.stakeholderId.map { ($0, p.name ?? String(localized: "Stakeholder")) } }, id: \.0) { Text($0.1).tag(Int?.some($0.0)) }
                        }
                    }
                }
            }
            .navigationTitle("Propose requirement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Propose") { Task { await gui() } }
                        .disabled(tieuDe.trimmingCharacters(in: .whitespaces).count < 3 || dangGui)
                }
            }
        }
    }

    private func gui() async {
        dangGui = true
        defer { dangGui = false }
        let tx = chu.trimmingCharacters(in: .whitespacesAndNewlines)
        var than: [String: Any] = ["title": tieuDe.trimmingCharacters(in: .whitespaces), "reqType": loai, "priority": uuTien,
                                   "text": tx.isEmpty ? NSNull() : tx]
        if let b = benLQ { than["stakeholder"] = b }
        do {
            _ = try await APIClient.shared.send(CTWAPI.swrDeXuatYeuCau(pid: pid, n: n, than: than))
            CTWRung.thanhCong()
            await xong()
            dong()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}

// MARK: NFR

struct WNfrCTW: View {
    let pid: Int
    @StateObject private var t: TaiMotCTW<CTWSwrNfr>
    init(pid: Int) { self.pid = pid; _t = StateObject(wrappedValue: TaiMotCTW { CTWAPI.swrNfr(pid: pid) }) }

    var body: some View {
        KhungDanhSach(tieuDe: "Quality attributes", dangTai: t.gt == nil && t.loi == nil && !t.noiBo, loi: t.loi, noiBo: t.noiBo, lamMoi: t.tai) {
            let ds = t.gt?.requirements ?? []
            if t.gt != nil && ds.isEmpty {
                CTWOTrong(bieuTuong: "gauge.with.dots.needle.67percent", tieuDe: String(localized: "No quality requirements"),
                          moTa: String(localized: "Quality requirements (performance, security…) show up here with their measures."))
                    .listRowBackground(Color.clear)
            }
            if !ds.isEmpty {
                Section {
                    Text("\(t.gt?.measured ?? 0) of \(ds.count) have a measurable spec (scale, meter, target).")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            let nhom = Dictionary(grouping: ds) { $0.spec?.characteristic ?? "" }
            ForEach(nhom.keys.sorted { ($0.isEmpty ? "~" : $0) < ($1.isEmpty ? "~" : $1) }, id: \.self) { k in
                Section(k.isEmpty ? String(localized: "Not measured yet") : (t.gt?.characteristics?.first { $0.key == k }?.label ?? CTWMauTrangThai.nhan(k))) {
                    ForEach(nhom[k] ?? []) { q in hang(q) }
                }
            }
        }
    }

    private func hang(_ q: CTWSwrNfr.Muc) -> some View {
        NavigationLink(value: RouteWiegersCTW.yeuCauChiTiet(pid: pid, so: q.number)) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(q.key ?? "#\(q.number)").font(.ctw(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                    Text(q.title ?? "").font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                }
                if let st = q.statement, !st.isEmpty {
                    Text(st).font(.ctw(size: 13)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
                if let s = q.spec {
                    HStack(spacing: 6) {
                        if let m = s.mustValue { CTWNhanNho(chu: String(localized: "Must \(s.comparator ?? "") \(so(m)) \(s.unit ?? "")"), mau: AppColors.error) }
                        if let p = s.planValue { CTWNhanNho(chu: String(localized: "Plan \(s.comparator ?? "") \(so(p)) \(s.unit ?? "")"), mau: AppColors.success) }
                        if let v = s.verification { CTWNhanNho(chu: CTWMauTrangThai.nhan(v), bieuTuong: "checkmark.circle") }
                    }
                } else {
                    Label("No measurable target yet", systemImage: "exclamationmark.triangle").font(.ctw(size: 12)).foregroundColor(AppColors.warning)
                }
            }
            .padding(.vertical, 3)
        }
    }

    private func so(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(format: "%.2g", d) }
}

// MARK: Prototype

struct WMauCTW: View {
    let pid: Int
    @StateObject private var t: TaiMotCTW<CTWSwrMockups>
    @State private var mo: URL?
    init(pid: Int) { self.pid = pid; _t = StateObject(wrappedValue: TaiMotCTW { CTWAPI.swrMau(pid: pid) }) }

    var body: some View {
        KhungDanhSach(tieuDe: "Prototypes", dangTai: t.gt == nil && t.loi == nil && !t.noiBo, loi: t.loi, noiBo: t.noiBo, lamMoi: t.tai) {
            if let c = t.gt?.counts {
                Section {
                    Text("\(c.withPrototype ?? 0) of \(c.screens ?? 0) screens have a prototype · \(c.approved ?? 0) approved")
                        .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                }
            }
            ForEach(t.gt?.screens ?? []) { s in
                Section {
                    if (s.mockups ?? []).isEmpty {
                        Text("No prototype yet").font(.ctw(size: 13)).foregroundColor(AppColors.textTertiary)
                    }
                    ForEach(s.mockups ?? []) { m in hang(m) }
                } header: {
                    HStack {
                        Text(s.name ?? String(localized: "Screen"))
                        if s.approved == true { Image(systemName: "checkmark.seal.fill").foregroundColor(AppColors.success) }
                    }
                }
            }
        }
        .sheet(item: Binding(get: { mo.map { URLMoCTW(url: $0) } }, set: { mo = $0?.url })) { u in
            SafariCTW(url: u.url).ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func hang(_ m: CTWSwrMockup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CTWChipChu(chu: m.status ?? "DRAFT", mau: m.status == "APPROVED" ? AppColors.success : (m.status == "CHANGES" ? AppColors.error : AppColors.warning))
                Text(m.title ?? (m.kind == "LINK" ? (m.provider ?? String(localized: "Link")) : String(localized: "Image")))
                    .font(.ctw(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(1)
            }
            if let img = m.image { CTWAnhCoXacThuc(src: img, alt: m.title ?? String(localized: "Prototype")) }
            if m.kind == "LINK", let s = m.url, let u = URL(string: s), u.scheme == "https" {
                Button { mo = u } label: {
                    Label("Open \(m.provider ?? String(localized: "prototype"))", systemImage: "arrow.up.right.square").font(.ctw(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderless)
            }
            if let r = m.reviewerName {
                Text("Reviewed by \(r)\(m.reviewNote.map { ": “\($0)”" } ?? "")")
                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct URLMoCTW: Identifiable { let url: URL; var id: String { url.absoluteString } }
