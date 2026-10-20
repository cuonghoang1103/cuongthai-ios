import SwiftUI

// MARK: - Sơ đồ (Diagram Studio) — XEM ảnh, phóng to, đổi phiên bản, bình luận
//
// Vẽ/sửa sơ đồ (Mermaid, ERD từ SQL, bảng trắng) là việc của màn lớn ⇒ để web.
// Điện thoại làm tốt việc XEM: ảnh đã dựng, chụm hai ngón để phóng, toàn màn hình,
// chia sẻ ảnh, đọc + viết bình luận (nội dung người dùng ⇒ báo cáo/chặn — 1.2).

struct RouteSoDoCTW: Hashable { var pid: Int; var so: Int; var ten: String }

@MainActor
final class DiagramsVM: ObservableObject {
    let pid: Int
    @Published var du: CTWDsSoDo?
    @Published var loi: String?
    init(pid: Int) { self.pid = pid }

    func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.dsSoDo(pid: pid)); loi = nil }
        catch {
            if case APIError.coMa(let ma, _) = error, ma == "WORK_INTERNAL_ONLY" {
                loi = String(localized: "Diagrams are only available to the project team.")
            } else { loi = CTW.loi(error) }
        }
    }
}

enum CTWSoDoHienThi {
    static func bieuTuong(_ type: String?) -> String {
        switch type {
        case "SEQUENCE": return "arrow.left.arrow.right"
        case "USE_CASE": return "person.2.wave.2"
        case "ERD", "CLASS": return "tablecells"
        case "ACTIVITY", "FLOWCHART": return "arrow.triangle.branch"
        case "STATE": return "circle.grid.cross"
        case "WHITEBOARD": return "scribble.variable"
        case "GANTT": return "chart.bar.xaxis"
        case "MINDMAP": return "point.3.filled.connected.trianglepath.dotted"
        default: return "square.on.square.dashed"
        }
    }
}

struct DiagramsCTW: View {
    let nguCanh: CTWNguCanh
    @StateObject private var vm: DiagramsVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""
    @State private var loc = ""

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: DiagramsVM(pid: nguCanh.pid))
    }

    private var hienThi: [CTWSoDo] {
        let q = tim.trimmingCharacters(in: .whitespaces).lowercased()
        return (vm.du?.items ?? []).filter { d in
            if !loc.isEmpty && d.status != loc { return false }
            if q.isEmpty { return true }
            return [d.title, d.key, d.typeLabel, d.useCase?.key, d.issue?.key].compactMap { $0?.lowercased() }.contains { $0.contains(q) }
        }
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                if vm.du == nil { CTWOLoi(loi: loi) { Task { await vm.tai() } }.listRowBackground(Color.clear) }
                else { CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            }
            if let ds = vm.du?.items {
                if ds.isEmpty {
                    CTWOTrong(bieuTuong: "square.on.square.dashed", tieuDe: String(localized: "No diagrams yet"),
                              moTa: String(localized: "Sequence, use case, ERD and activity diagrams your team draws show up here to view and discuss."))
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        CTWThanhLoc(chip: [("", String(localized: "All")), ("APPROVED", String(localized: "Approved")), ("DRAFT", String(localized: "Draft")), ("PROPOSED", String(localized: "Proposed"))].map {
                            CTWChipLoc(id: $0.0, nhan: $0.1, bat: loc == $0.0)
                        }) { loc = $0.id }
                        .listRowInsets(EdgeInsets(top: 0, leading: -16, bottom: 0, trailing: -16))
                    }
                    .listRowBackground(Color.clear)
                    Section(hienThi.count == 1 ? String(localized: "1 diagram") : String(localized: "\(hienThi.count) diagrams")) {
                        ForEach(hienThi) { d in
                            NavigationLink(value: RouteSoDoCTW(pid: nguCanh.pid, so: d.number, ten: d.title)) { hang(d) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.du == nil && vm.loi == nil { CTWKhungTai(soHang: 5, coAvatar: false) } }
        .searchable(text: $tim, placement: .toolbar, prompt: "Search diagrams")
        .navigationTitle("Diagrams")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if vm.du == nil { await vm.tai() } }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "diagrams" else { return }
            defer { app.dichCho = nil }
            if let so = d.duongDan.phanCon.first.flatMap(Int.init) {
                nganXep.duong.append(RouteSoDoCTW(pid: nguCanh.pid, so: so, ten: String(localized: "Diagram")))
            }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("diagrams") == "detail", nganXep.duong.count <= 1 {
                nganXep.duong.append(RouteSoDoCTW(pid: nguCanh.pid, so: 2, ten: "Login flow"))
            }
        }
        #endif
    }

    private func hang(_ d: CTWSoDo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: CTWSoDoHienThi.bieuTuong(d.type))
                .font(.ctw(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let k = d.key { Text(k).font(.ctw(size: 11, weight: .bold).monospaced()).foregroundColor(AppColors.textTertiary) }
                    Text(d.title).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    CTWChipChu(chu: d.status)
                    if let t = d.typeLabel { Text(t).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1) }
                    if let v = d.currentVersion { Text("v\(v)").font(.ctw(size: 12).monospacedDigit()).foregroundColor(AppColors.textTertiary) }
                    if d.aiModel != nil || d.updatedBy?.isAgent == true { CTWNhanAI(chu: "AI") }
                }
                let lk = [d.useCase?.key, d.issue?.key, d.page.map { _ in String(localized: "Doc") }].compactMap { $0 }
                if !lk.isEmpty || (d.openComments ?? 0) > 0 {
                    HStack(spacing: 6) {
                        ForEach(lk, id: \.self) { CTWNhanNho(chu: $0, bieuTuong: "link") }
                        if let n = d.openComments, n > 0 { CTWNhanNho(chu: "\(n)", bieuTuong: "bubble.left", mau: AppColors.primary) }
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chi tiết sơ đồ

struct SoDoChiTietCTW: View {
    let r: RouteSoDoCTW
    @EnvironmentObject private var app: AppState
    @Environment(\.horizontalSizeClass) private var beRong
    @State private var d: CTWSoDoChiTiet?
    @State private var loi: String?
    @State private var ban: Int?
    @State private var anh: UIImage?
    @State private var loiAnh: CTWAnhSoDo.Loi?
    @State private var tamPhu: TamPhu?
    @State private var xemHetPhienBan = false

    private enum TamPhu: Identifiable {
        case toanMan(UIImage), web(URL)
        var id: String {
            switch self { case .toanMan: return "toanman"; case .web(let u): return u.absoluteString }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let d {
                    dau(d)
                    khungAnh(d)
                    if let mt = d.description, !mt.isEmpty {
                        CTWMarkdownView(markdown: mt, coChu: 15)
                    }
                    lienKet(d)
                    phienBan(d)
                    binhLuan(d)
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(d?.key ?? r.ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let d, let vs = d.versions, vs.count > 1 {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Version", selection: Binding(get: { ban ?? d.banMacDinh ?? 0 }, set: { doiBan($0) })) {
                            ForEach(vs) { v in
                                Text(v.number == d.approvedVersion ? String(localized: "v\(v.number) · approved")
                                     : v.number == d.currentVersion ? String(localized: "v\(v.number) · latest") : "v\(v.number)")
                                    .tag(v.number)
                            }
                        }
                    } label: { Label("Version", systemImage: "clock.arrow.circlepath") }
                }
            }
            if let anh {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(uiImage: anh), preview: SharePreview(d?.title ?? r.ten, image: Image(uiImage: anh))) {
                        Label("Share image", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .refreshable { await tai() }
        .task { if d == nil { await tai() } }
        .fullScreenCover(item: $tamPhu) { t in
            switch t {
            case .toanMan(let a): ToanManSoDoCTW(anh: a, tieuDe: d?.title ?? r.ten)
            case .web(let u): SafariCTW(url: u).ignoresSafeArea()
            }
        }
    }

    private func dau(_ d: CTWSoDoChiTiet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d.title).font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                CTWChipChu(chu: d.status)
                if let t = d.typeLabel { CTWNhanNho(chu: t, bieuTuong: CTWSoDoHienThi.bieuTuong(d.type)) }
                if d.aiModel != nil { CTWNhanAI(chu: String(localized: "AI-generated")) }
            }
            if let u = d.updatedBy {
                HStack(spacing: 6) {
                    CTWAvatar(user: u.nguoi, size: 18)
                    Text("Updated by \(u.name ?? String(localized: "someone"))").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    if u.isAgent == true { CTWNhanAI() }
                    if let t = d.updatedAt { Text("· \(CTW.thoiDiem(t))").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary) }
                }
            }
        }
    }

    @ViewBuilder
    private func khungAnh(_ d: CTWSoDoChiTiet) -> some View {
        let cao: CGFloat = beRong == .regular ? 460 : 300
        ZStack {
            if let anh {
                KhungPhongToCTW(anh: anh)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button { tamPhu = .toanMan(anh) } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.ctw(size: 14, weight: .semibold)).foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.black.opacity(0.55)))
                        }
                        .padding(10)
                        .accessibilityLabel("View full screen")
                    }
            } else if let loiAnh {
                VStack(spacing: 10) {
                    Image(systemName: loiAnh == .khongPhaiMermaid ? "scribble.variable" : "photo.badge.exclamationmark")
                        .font(.ctw(size: 30)).foregroundColor(AppColors.textTertiary)
                    Text(loiAnh.errorDescription ?? "").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    if let u = CTWWeb.url(slug: app.luaChon?.slug ?? "", ma: app.luaChon?.maDuAn ?? "", doan: "diagrams/\(d.number)") {
                        Button { tamPhu = .web(u) } label: { Label("Open in CT Work web", systemImage: "safari") }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cao)
        .ctwThe(14)
        .accessibilityHint(anh == nil ? "" : "Pinch to zoom, double-tap to zoom in")
    }

    @ViewBuilder
    private func lienKet(_ d: CTWSoDoChiTiet) -> some View {
        let co = d.issue != nil || d.page != nil || d.useCase != nil
        if co {
            CTWKhoiTruong {
                if let uc = d.useCase {
                    CTWHangTruong(String(localized: "Use case"), [uc.key, uc.name].compactMap { $0 }.joined(separator: " "), bieuTuong: "person.2.wave.2")
                }
                if let t = d.issue, let so = t.number {
                    if d.useCase != nil { Divider() }
                    NavigationLink(value: CTWRoute.the(pid: r.pid, so: so)) {
                        CTWHangTruong(String(localized: "Issue"), [t.key, t.title].compactMap { $0 }.joined(separator: " "), bieuTuong: "checkmark.square")
                    }
                    .buttonStyle(.plain)
                }
                if let p = d.page, let so = p.number {
                    if d.useCase != nil || d.issue != nil { Divider() }
                    NavigationLink(value: RouteTaiLieuCTW(pid: r.pid, so: so, ten: p.title ?? String(localized: "Page"))) {
                        CTWHangTruong(String(localized: "Document"), p.title, bieuTuong: "doc.text")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func phienBan(_ d: CTWSoDoChiTiet) -> some View {
        let vs = d.versions ?? []
        if !vs.isEmpty {
            CTWSectionHeader("clock.arrow.circlepath", String(localized: "Versions"), count: "\(vs.count)")
            VStack(spacing: 0) {
                ForEach(Array((xemHetPhienBan ? vs : Array(vs.prefix(4))).enumerated()), id: \.element.id) { i, v in
                    if i > 0 { Divider() }
                    Button { doiBan(v.number) } label: {
                        HStack(spacing: 10) {
                            Text("v\(v.number)").font(.ctw(size: 13, weight: .bold).monospacedDigit())
                                .foregroundColor((ban ?? d.banMacDinh) == v.number ? AppColors.primary : AppColors.textPrimary)
                                .frame(width: 36, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.note?.isEmpty == false ? v.note! : String(localized: "No note")).font(.ctw(size: 14))
                                    .foregroundColor(v.note?.isEmpty == false ? AppColors.textPrimary : AppColors.textTertiary).lineLimit(2)
                                HStack(spacing: 4) {
                                    Text(v.author?.name ?? "—")
                                    if v.author?.isAgent == true || v.aiModel != nil { CTWNhanAI(chu: "AI") }
                                    Text("· \(CTW.thoiDiem(v.createdAt))")
                                }
                                .font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                            }
                            Spacer(minLength: 4)
                            if v.number == d.approvedVersion { CTWNhanNho(chu: String(localized: "Approved"), mau: AppColors.success) }
                            if (ban ?? d.banMacDinh) == v.number { Image(systemName: "eye.fill").foregroundColor(AppColors.primary).font(.ctw(size: 12)) }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this version")
                }
                if vs.count > 4 {
                    Divider()
                    Button(xemHetPhienBan ? "Show fewer" : "Show all \(vs.count) versions") { xemHetPhienBan.toggle() }
                        .font(.ctw(size: 13, weight: .semibold)).padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 14)
            .ctwThe(12)
        }
    }

    @ViewBuilder
    private func binhLuan(_ d: CTWSoDoChiTiet) -> some View {
        let ds = (d.comments ?? []).sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        CTWSectionHeader("bubble.left.and.bubble.right", String(localized: "Comments"), count: "\(ds.count)")
        if ds.isEmpty {
            Text("No comments yet.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
        }
        ForEach(ds) { c in
            CTWBinhLuanDong(
                khoa: "diagram-comment-\(c.id)", tacGia: c.author?.nguoi, noiDung: c.body ?? "",
                thoiDiem: c.createdAt,
                nhanPhu: c.resolved == true ? String(localized: "Resolved") : (c.versionNumber.map { "v\($0)" }),
                nguCanh: "\(app.luaChon?.maDuAn ?? "") · \(d.key ?? "diagram") \(d.title)",
                themMuc: c.mine == true ? AnyView(Button(role: .destructive) { Task { await xoa(c) } } label: { Label("Delete", systemImage: "trash") }) : nil,
                dich: CTWDichBaoCao("diagram_comment", c.id))
        }
        if d.canComment == true {
            CTWHopSoan(goiY: String(localized: "Comment on v\(ban ?? d.banMacDinh ?? 1)…")) { chu in await gui(chu) }
        }
    }

    private func doiBan(_ v: Int) {
        guard v != (ban ?? d?.banMacDinh) else { return }
        CTWRung.chon()
        ban = v
        Task { await taiAnh() }
    }

    private func tai() async {
        do {
            let m: CTWSoDoChiTiet = try await APIClient.shared.request(CTWAPI.soDo(pid: r.pid, so: r.so))
            d = m
            loi = nil
            if anh == nil || ban == nil { await taiAnh() }
        } catch { loi = CTW.loi(error) }
    }

    private func taiAnh() async {
        guard let d else { return }
        loiAnh = nil
        anh = nil
        do { anh = try await CTWAnhSoDo.tai(pid: r.pid, so: d.number, ban: ban ?? d.banMacDinh) }
        catch let e as CTWAnhSoDo.Loi { loiAnh = e }
        catch { loiAnh = .khac(CTW.loi(error)) }
    }

    private func gui(_ chu: String) async -> Bool {
        guard let d else { return false }
        do {
            try await APIClient.shared.send(CTWAPI.binhLuanSoDo(pid: r.pid, so: d.number, chu: chu, banSo: ban ?? d.banMacDinh))
            await tai()
            return true
        } catch { loi = CTW.loi(error); return false }
    }

    private func xoa(_ c: CTWSoDoChiTiet.BinhLuan) async {
        guard let d else { return }
        do {
            try await APIClient.shared.send(CTWAPI.xoaBinhLuanSoDo(pid: r.pid, so: d.number, cid: c.id))
            await tai()
        } catch { loi = CTW.loi(error) }
    }
}

/// Toàn màn hình: nền tối, phóng to tự do, nút Đóng + Chia sẻ.
struct ToanManSoDoCTW: View {
    let anh: UIImage
    let tieuDe: String
    @Environment(\.dismiss) private var dong

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            KhungPhongToCTW(anh: anh)
                .background(Color.white)
                .ignoresSafeArea(edges: .bottom)
                .padding(.top, 56)
            HStack {
                Button { dong() } label: {
                    Image(systemName: "xmark").font(.ctw(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(Circle().fill(Color.white.opacity(0.18)))
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(tieuDe).font(.ctw(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Spacer()
                ShareLink(item: Image(uiImage: anh), preview: SharePreview(tieuDe, image: Image(uiImage: anh))) {
                    Image(systemName: "square.and.arrow.up").font(.ctw(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(Circle().fill(Color.white.opacity(0.18)))
                }
                .accessibilityLabel("Share image")
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .statusBarHidden()
    }
}
