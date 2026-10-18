import SwiftUI

// MARK: - Wiegers (SWR302) — trung tâm đọc + yêu cầu có vòng đời
//
// Web có 15 tab; trên điện thoại giữ những thứ người ta THẬT SỰ mở khi đi họp/ôn bài:
// yêu cầu (duyệt vòng đời được), tính năng, stakeholder, thuật ngữ, phiên elicitation,
// NFR, prototype. Phần thiết kế nặng (mô hình, ma trận ưu tiên, RACI, khảo sát, xuất
// tài liệu) mở web trong trình duyệt an toàn — một dòng, không phải lối thoát chính.

enum RouteWiegersCTW: Hashable {
    case yeuCau(pid: Int)
    case yeuCauChiTiet(pid: Int, so: Int)
    case tinhNang(pid: Int)
    case benLienQuan(pid: Int)
    case benLienQuanChiTiet(pid: Int, sh: CTWSwrStakeholder)
    case thuatNgu(pid: Int)
    case phien(pid: Int)
    case phienChiTiet(pid: Int, n: Int)
    case nfr(pid: Int)
    case mau(pid: Int)

    @MainActor @ViewBuilder
    var man: some View {
        switch self {
        case .yeuCau(let pid): WYeuCauCTW(pid: pid)
        case .yeuCauChiTiet(let pid, let so): WYeuCauChiTietCTW(pid: pid, so: so)
        case .tinhNang(let pid): WTinhNangCTW(pid: pid)
        case .benLienQuan(let pid): WBenLienQuanCTW(pid: pid)
        case .benLienQuanChiTiet(_, let sh): WBenLienQuanChiTietCTW(sh: sh)
        case .thuatNgu(let pid): WThuatNguCTW(pid: pid)
        case .phien(let pid): WPhienCTW(pid: pid)
        case .phienChiTiet(let pid, let n): WPhienChiTietCTW(pid: pid, n: n)
        case .nfr(let pid): WNfrCTW(pid: pid)
        case .mau(let pid): WMauCTW(pid: pid)
        }
    }
}

struct WiegersCTW: View {
    let pid: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @ObservedObject private var kho: KhoYeuCauCTW
    @State private var moWeb = false

    init(pid: Int) {
        self.pid = pid
        _kho = ObservedObject(wrappedValue: KhoYeuCauCTW.cua(pid))
    }

    var body: some View {
        List {
            if kho.noiBo {
                CTWOTrong(bieuTuong: "lock.doc", tieuDe: "Team only",
                          moTa: "The Wiegers requirements workspace is only available to the project team and lecturers.")
                    .listRowBackground(Color.clear)
            } else {
                if let r = kho.swr {
                    Section { tomTat(r) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section("Requirements") {
                    muc(.yeuCau(pid: pid), "list.bullet.rectangle.portrait", "Requirements", "Business, user, functional and quality requirements",
                        dem: kho.swr?.counts?.total)
                    muc(.tinhNang(pid: pid), "square.stack.3d.up", "Features", "Scope, releases and the use cases behind each feature")
                    muc(.nfr(pid: pid), "gauge.with.dots.needle.67percent", "Quality attributes", "Measurable non-functional requirements (ISO 25010)")
                }
                Section("Elicitation") {
                    muc(.benLienQuan(pid: pid), "person.3", "Stakeholders", "Influence / interest grid and who each one is")
                    muc(.phien(pid: pid), "bubble.left.and.text.bubble.right", "Elicitation sessions", "Interviews, workshops and the requirements they produced")
                    muc(.thuatNgu(pid: pid), "character.book.closed", "Glossary", "Shared vocabulary of the project")
                    muc(.mau(pid: pid), "iphone.gen3", "Prototypes", "Screen mockups and their review status")
                }
                Section {
                    Button { moWeb = true } label: {
                        Label("Models, priority matrix, RACI & exports", systemImage: "safari")
                    }
                } footer: {
                    Text("Diagram editing and document exports open in a secure in-app browser.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Wiegers")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await kho.taiSwr() }
        .task { if kho.swr == nil { await kho.taiSwr() } }
        .sheet(isPresented: $moWeb) {
            if let l = app.luaChon, let u = CTWWeb.url(slug: l.slug, ma: l.maDuAn, doan: "wiegers") {
                SafariCTW(url: u).ignoresSafeArea()
            }
        }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "wiegers" else { return }
            defer { app.dichCho = nil }
            if let so = d.duongDan.tham["req"].flatMap(Int.init) {
                nganXep.duong.append(RouteWiegersCTW.yeuCauChiTiet(pid: pid, so: so))
            }
        }
        #if DEBUG
        .onAppear {
            guard nganXep.duong.count <= 1, let con = XemThuCTW.conCua("wiegers") else { return }
            switch con {
            case "req": nganXep.duong.append(RouteWiegersCTW.yeuCau(pid: pid))
            case "reqdetail": nganXep.duong.append(RouteWiegersCTW.yeuCauChiTiet(pid: pid, so: 31))
            case "sh": nganXep.duong.append(RouteWiegersCTW.benLienQuan(pid: pid))
            case "elc": nganXep.duong.append(RouteWiegersCTW.phienChiTiet(pid: pid, n: 2))
            case "nfr": nganXep.duong.append(RouteWiegersCTW.nfr(pid: pid))
            default: break
            }
        }
        #endif
    }

    private func tomTat(_ r: CTWSwrRequirementList) -> some View {
        let bl = r.counts?.byLifecycle ?? [:]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
            CTWODem(so: "\(r.counts?.total ?? r.requirements?.count ?? 0)", nhan: "Requirements", bieuTuong: "list.bullet.rectangle.portrait")
            CTWODem(so: "\(bl["APPROVED"] ?? 0)", nhan: "Approved", bieuTuong: "checkmark.seal", mau: AppColors.success)
            CTWODem(so: "\(bl["PROPOSED"] ?? 0)", nhan: "Proposed", bieuTuong: "sparkles", mau: AppColors.accent)
            CTWODem(so: "\(r.counts?.unclassified ?? 0)", nhan: "Unclassified", bieuTuong: "questionmark.square.dashed", mau: AppColors.warning)
        }
        .padding(.horizontal, 2)
    }

    private func muc(_ r: RouteWiegersCTW, _ icon: String, _ ten: String, _ moTa: String, dem: Int? = nil) -> some View {
        NavigationLink(value: r) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ten).font(.system(size: 16, weight: .medium)).foregroundColor(AppColors.textPrimary)
                    Text(moTa).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                if let dem { Text("\(dem)").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textTertiary) }
            }
            .padding(.vertical, 3)
        }
    }
}

// MARK: - Danh sách yêu cầu

struct WYeuCauCTW: View {
    let pid: Int
    @ObservedObject private var kho: KhoYeuCauCTW
    @State private var loai: String?
    @State private var vongDoi: String?
    @State private var tim = ""

    init(pid: Int) {
        self.pid = pid
        _kho = ObservedObject(wrappedValue: KhoYeuCauCTW.cua(pid))
    }

    private static let cacLoai = ["BUSINESS", "USER", "FUNCTIONAL", "QUALITY", "CONSTRAINT", "EXTERNAL_INTERFACE", "DATA", "UNCLASSIFIED"]

    var body: some View {
        List {
            if let loi = kho.loi {
                CTWErrorBanner(text: loi) { kho.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if let r = kho.swr {
                Section {
                    VStack(spacing: 6) {
                        CTWThanhLoc(chip: [CTWChipLoc(id: "", nhan: "All types", bat: loai == nil)] + Self.cacLoai.compactMap { t in
                            let n = t == "UNCLASSIFIED" ? (r.counts?.unclassified ?? 0) : (r.counts?.byType?[t] ?? 0)
                            return n > 0 ? CTWChipLoc(id: t, nhan: "\(CTWVongDoiYeuCau.tenLoai(t == "UNCLASSIFIED" ? nil : t)) \(n)", bat: loai == t) : nil
                        }) { c in loai = c.id.isEmpty ? nil : c.id }
                        CTWThanhLoc(chip: [CTWChipLoc(id: "", nhan: "Any status", bat: vongDoi == nil)] + CTWVongDoiYeuCau.tatCa.compactMap { v in
                            let n = r.counts?.byLifecycle?[v] ?? 0
                            return n > 0 ? CTWChipLoc(id: v, nhan: "\(CTWMauTrangThai.nhan(v)) \(n)", bat: vongDoi == v) : nil
                        }) { c in vongDoi = c.id.isEmpty ? nil : c.id }
                    }
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                let ds = loc(r.requirements ?? [])
                Section {
                    if ds.isEmpty {
                        CTWOTrong(bieuTuong: "list.bullet.rectangle.portrait", tieuDe: (r.requirements ?? []).isEmpty ? "No requirements yet" : "No matches",
                                  moTa: (r.requirements ?? []).isEmpty ? "Requirement issues your team creates show up here." : "Change the filters to see more.")
                            .listRowBackground(Color.clear)
                    }
                    ForEach(ds) { q in
                        NavigationLink(value: RouteWiegersCTW.yeuCauChiTiet(pid: pid, so: q.number)) { HangYeuCauCTW(r: q) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if kho.swr == nil && kho.loi == nil { CTWKhungTai(soHang: 6, coAvatar: false) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search requirements")
        .navigationTitle("Requirements")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await kho.taiSwr() }
        .task { if kho.swr == nil { await kho.taiSwr() } }
    }

    private func loc(_ ds: [CTWSwrRequirement]) -> [CTWSwrRequirement] {
        let t = tim.trimmingCharacters(in: .whitespaces).lowercased()
        return ds.filter { q in
            (loai == nil || (loai == "UNCLASSIFIED" ? q.reqType == nil : q.reqType == loai))
                && (vongDoi == nil || (q.lifecycle ?? "PROPOSED") == vongDoi)
                && (t.isEmpty || [q.key, q.title, q.text].contains { ($0 ?? "").lowercased().contains(t) })
        }
    }
}

struct HangYeuCauCTW: View {
    let r: CTWSwrRequirement
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(r.key ?? "#\(r.number)").font(.system(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
                Text(r.title ?? "").font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
            }
            HStack(spacing: 6) {
                CTWChipChu(chu: r.lifecycle ?? "PROPOSED", mau: mauVongDoi(r.lifecycle))
                CTWNhanNho(chu: CTWVongDoiYeuCau.tenLoai(r.reqType), bieuTuong: r.reqType == nil ? "questionmark.square.dashed" : "tag")
                if let p = CTWNhanYeuCau.nhanUuTien(r.priority) {
                    CTWNhanNho(chu: p, bieuTuong: "flag.fill", mau: CTWNhanYeuCau.mauUuTien(r.priority))
                }
            }
            if let t = r.text, !t.isEmpty {
                Text(t).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary).lineLimit(2)
            }
        }
        .padding(.vertical, 3)
    }
}

func mauVongDoi(_ s: String?) -> Color {
    switch s {
    case "APPROVED", "VERIFIED": return AppColors.success
    case "IMPLEMENTED": return Color(hex: 0x2563EB)
    case "REJECTED", "DELETED": return AppColors.error
    default: return AppColors.primary
    }
}

// MARK: - Chi tiết yêu cầu

struct WYeuCauChiTietCTW: View {
    let pid: Int
    let so: Int
    @ObservedObject private var kho: KhoYeuCauCTW
    @State private var lichSu: [CTWSwrHistoryRow]?
    @State private var hoi: String?
    @State private var ghiChu = ""
    @State private var dangDoi = false
    @State private var loi: String?

    init(pid: Int, so: Int) {
        self.pid = pid; self.so = so
        _kho = ObservedObject(wrappedValue: KhoYeuCauCTW.cua(pid))
    }

    /// Bản tải riêng (`GET /swr/requirements/:num`) — mới hơn danh sách, và có cả khi danh sách chưa nạp.
    @State private var motMuc: CTWSwrRequirement?
    private var r: CTWSwrRequirement? { motMuc ?? kho.swr?.requirements?.first { $0.number == so } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let r {
                    dau(r)
                    hanhDong(r)
                    if let t = r.text, !t.isEmpty {
                        CTWSectionHeader("text.alignleft", "Requirement")
                        Text(t).font(.system(size: 15)).foregroundColor(AppColors.textPrimary)
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
                    }
                    CTWKhoiTruong {
                        CTWHangTruong("Type", CTWVongDoiYeuCau.tenLoai(r.reqType) + (r.subtype.map { " · \(CTWMauTrangThai.nhan($0))" } ?? ""),
                                      bieuTuong: "tag")
                        Divider()
                        CTWHangTruong("Source", r.source, bieuTuong: "person.wave.2")
                        Divider()
                        CTWHangTruong("Owner", kho.swr?.owners?.first { $0.id == r.ownerId }?.name, bieuTuong: "person.crop.circle")
                        Divider()
                        CTWHangTruong("Stability", r.stability.map { CTWMauTrangThai.nhan($0) }, bieuTuong: "waveform.path")
                        Divider()
                        CTWHangTruong("Version", r.reqVersion.map { "v\($0)" }, bieuTuong: "number")
                        Divider()
                        CTWHangTruong("Issue status", r.status?.name, bieuTuong: "circle.dashed")
                    }
                    if let ra = r.rationale, !ra.isEmpty {
                        CTWSectionHeader("lightbulb", "Rationale")
                        Text(ra).font(.system(size: 14)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
                    }
                    NavigationLink(value: CTWRoute.the(pid: pid, so: r.number)) {
                        Label("Open issue \(r.key ?? "#\(r.number)")", systemImage: "arrow.up.forward.square")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).ctwThe(12)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.primary)
                    khoiLichSu()
                    CTWSectionHeader("text.bubble", "Discussion")
                    ThaoLuanTheCTW(pid: pid, so: r.number, nguCanh: "\(r.key ?? "") \(r.title ?? "")")
                } else if kho.swr != nil {
                    CTWOTrong(bieuTuong: "questionmark.folder", tieuDe: "Requirement not found")
                } else {
                    CTWKhungTai(soHang: 4, coAvatar: false)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(r?.key ?? "Requirement")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await taiMotMuc(); await kho.taiSwr(); await taiLichSu() }
        .task {
            await taiMotMuc()
            if kho.swr == nil { await kho.taiSwr() }
            if lichSu == nil { await taiLichSu() }
        }
        .alert(hoi.map { "\(CTWVongDoiYeuCau.nhanHanhDong($0))?" } ?? "",
               isPresented: Binding(get: { hoi != nil }, set: { if !$0 { hoi = nil } })) {
            TextField("Note (optional)", text: $ghiChu)
            Button("Cancel", role: .cancel) { ghiChu = "" }
            Button(hoi.map { CTWVongDoiYeuCau.nhanHanhDong($0) } ?? "OK") {
                if let den = hoi { Task { await doi(den) } }
            }
        } message: {
            Text("The change is recorded in the requirement's history.")
        }
    }

    private func dau(_ r: CTWSwrRequirement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(r.key ?? "#\(r.number)").font(.system(size: 13, weight: .bold).monospaced()).foregroundColor(AppColors.primary)
            Text(r.title ?? "").font(.system(size: 23, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                CTWChipChu(chu: r.lifecycle ?? "PROPOSED", mau: mauVongDoi(r.lifecycle))
                if let p = CTWNhanYeuCau.nhanUuTien(r.priority) {
                    CTWNhanNho(chu: "\(p) priority", bieuTuong: "flag.fill", mau: CTWNhanYeuCau.mauUuTien(r.priority))
                }
                if let u = CTW.ngayNgan(r.updatedAt) { Text("Updated \(u)").font(.system(size: 12)).foregroundColor(AppColors.textTertiary) }
            }
        }
    }

    @ViewBuilder
    private func hanhDong(_ r: CTWSwrRequirement) -> some View {
        let nut = CTWVongDoiYeuCau.nutHien(r, canEdit: kho.swr?.canEdit == true, canApprove: kho.swr?.canApprove == true)
        if !nut.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(nut, id: \.self) { den in
                        Button { ghiChu = ""; hoi = den } label: {
                            Text(CTWVongDoiYeuCau.nhanHanhDong(den)).font(.system(size: 14, weight: .semibold)).fixedSize()
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(den == "DELETED" || den == "REJECTED" ? AppColors.error : mauVongDoi(den))
                        .disabled(dangDoi)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func khoiLichSu() -> some View {
        if let ls = lichSu, !ls.isEmpty {
            CTWSectionHeader("clock.arrow.circlepath", "History", count: "\(ls.count)")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ls.prefix(20)) { h in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "circle.fill").font(.system(size: 6)).foregroundColor(AppColors.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(moTa(h)).font(.system(size: 13)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 4) {
                                Text("\(h.actor ?? "Someone") · \(CTW.thoiDiem(h.at))").font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                                if h.actorKind == "AGENT" { CTWNhanAI() }
                            }
                        }
                    }
                    .padding(.vertical, 7)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ctwThe(14)
        }
    }

    private func moTa(_ h: CTWSwrHistoryRow) -> String {
        let truong = CTWMauTrangThai.nhan(h.field).lowercased()
        switch (h.from, h.to) {
        case (nil, let t?): return "Set \(truong) to \(CTWMauTrangThai.nhan(t))"
        case (let f?, let t?): return "Changed \(truong): \(CTWMauTrangThai.nhan(f)) → \(CTWMauTrangThai.nhan(t))"
        case (_?, nil): return "Cleared \(truong)"
        default: return "Updated \(truong)"
        }
    }

    private func taiLichSu() async {
        lichSu = try? await APIClient.shared.request(CTWAPI.swrLichSu(pid: pid, so: so))
    }

    private func taiMotMuc() async {
        if let m: CTWSwrRequirement = try? await APIClient.shared.request(CTWAPI.swrMotYeuCau(pid: pid, so: so)) { motMuc = m }
    }

    private func doi(_ den: String) async {
        dangDoi = true
        defer { dangDoi = false; ghiChu = "" }
        let note = ghiChu.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await APIClient.shared.send(CTWAPI.swrVongDoi(pid: pid, so: so, den: den, ghiChu: note.isEmpty ? nil : note))
            CTWRung.thanhCong()
            await taiMotMuc()
            await kho.taiSwr()
            await taiLichSu()
        } catch { loi = CTW.loi(error); CTWRung.loi() }
    }
}
