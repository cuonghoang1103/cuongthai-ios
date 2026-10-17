import SwiftUI

// MARK: - Sổ tài sản & giấy phép — CHỈ ĐỌC
//
// Phần mềm, font, ảnh, thiết bị… nhóm đang dùng, hạn giấy phép và ghi công tác giả.
// Chi phí chỉ HIỆN như thông tin (App Store 3.1.1: không nút trả tiền, không link mua).
// Thêm/sửa tài sản là việc nhập liệu dài ⇒ để ở web; điện thoại để tra nhanh
// "font này dùng được thương mại không, giấy phép nào sắp hết".

struct RouteTaiSanCTW: Hashable { var pid: Int; var so: Int; var ten: String }

@MainActor
final class AssetsVM: ObservableObject {
    let pid: Int
    @Published var du: CTWDsTaiSan?
    @Published var loi: String?
    init(pid: Int) { self.pid = pid }

    func tai() async {
        do { du = try await APIClient.shared.request(CTWAPI.dsTaiSan(pid: pid)); loi = nil }
        catch { loi = CTW.loi(error) }
    }
}

struct AssetsCTW: View {
    let nguCanh: CTWNguCanh
    @StateObject private var vm: AssetsVM
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var loc = "all"
    @State private var tim = ""

    init(nguCanh: CTWNguCanh) {
        self.nguCanh = nguCanh
        _vm = StateObject(wrappedValue: AssetsVM(pid: nguCanh.pid))
    }

    private var tatCa: [CTWTaiSan] { vm.du?.items ?? [] }

    private var hienThi: [CTWTaiSan] {
        let q = tim.trimmingCharacters(in: .whitespaces).lowercased()
        return tatCa.filter { a in
            let hop: Bool
            switch loc {
            case "all": hop = true
            case "expiring": hop = a.expiry?.state == "EXPIRING"
            case "expired": hop = a.expiry?.state == "EXPIRED" || a.status == "EXPIRED"
            case "attribution": hop = a.attributionRequired == true
            default: hop = a.category == loc
            }
            guard hop else { return false }
            if q.isEmpty { return true }
            return [a.name, a.key, a.source, a.licenseLabel].compactMap { $0?.lowercased() }.contains { $0.contains(q) }
        }
    }

    private var chip: [CTWChipLoc] {
        var c = [CTWChipLoc(id: "all", nhan: "All", bat: loc == "all")]
        if (vm.du?.summary?.expiring ?? 0) > 0 {
            c.append(CTWChipLoc(id: "expiring", nhan: "Expiring", bieuTuong: "clock.badge.exclamationmark", bat: loc == "expiring"))
        }
        if (vm.du?.summary?.expired ?? 0) > 0 {
            c.append(CTWChipLoc(id: "expired", nhan: "Expired", bieuTuong: "xmark.octagon", bat: loc == "expired"))
        }
        if (vm.du?.summary?.needsAttribution ?? 0) > 0 {
            c.append(CTWChipLoc(id: "attribution", nhan: "Needs credit", bieuTuong: "quote.bubble", bat: loc == "attribution"))
        }
        let loai = Array(Set(tatCa.compactMap(\.category))).sorted()
        for l in loai {
            c.append(CTWChipLoc(id: l, nhan: CTWMauTrangThai.nhan(l).replacingOccurrences(of: "3d", with: "3D"),
                                bieuTuong: CTWTaiSanHienThi.bieuTuong(l), bat: loc == l))
        }
        return c
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                if vm.du == nil { CTWOLoi(loi: loi) { Task { await vm.tai() } }.listRowBackground(Color.clear) }
                else { CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            }
            if let s = vm.du?.summary {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        CTWODem(so: "\(s.active ?? 0)", nhan: "Active of \(s.total ?? 0)", bieuTuong: "checkmark.seal.fill", mau: AppColors.success)
                        CTWODem(so: "\(s.expiring ?? 0)", nhan: "Expiring soon", bieuTuong: "clock.badge.exclamationmark.fill",
                                mau: (s.expiring ?? 0) > 0 ? AppColors.warning : AppColors.textSecondary)
                        CTWODem(so: "\(s.expired ?? 0)", nhan: "Expired", bieuTuong: "xmark.octagon.fill",
                                mau: (s.expired ?? 0) > 0 ? AppColors.error : AppColors.textSecondary)
                        CTWODem(so: "\(s.needsAttribution ?? 0)", nhan: "Need a credit line", bieuTuong: "quote.bubble.fill", mau: AppColors.primary)
                    }
                    if let c = s.annualCost, !c.isEmpty {
                        Text("Yearly running cost: " + c.sorted { $0.key < $1.key }.map { CTWTien.dinhDang($0.value, $0.key) }.joined(separator: " + "))
                            .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                            .padding(.top, 2)
                            .listRowSeparator(.hidden)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                Section {
                    CTWThanhLoc(chip: chip) { loc = $0.id }
                        .listRowInsets(EdgeInsets(top: 0, leading: -16, bottom: 0, trailing: -16))
                }
                .listRowBackground(Color.clear)
            }
            if vm.du != nil {
                if tatCa.isEmpty {
                    CTWOTrong(bieuTuong: "archivebox", tieuDe: "No assets yet",
                              moTa: "Software, fonts, images and licenses your team tracks appear here with their expiry dates.")
                        .listRowBackground(Color.clear)
                } else if hienThi.isEmpty {
                    Text("Nothing matches this filter.").foregroundColor(AppColors.textSecondary).listRowBackground(Color.clear)
                } else {
                    Section("\(hienThi.count) item\(hienThi.count == 1 ? "" : "s")") {
                        ForEach(hienThi) { a in
                            NavigationLink(value: RouteTaiSanCTW(pid: nguCanh.pid, so: a.number ?? a.id, ten: a.name)) { hang(a) }
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
        .searchable(text: $tim, placement: .toolbar, prompt: "Search assets")
        .navigationTitle("Assets & licenses")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.tai() }
        .task { if vm.du == nil { await vm.tai() } }
    }

    private func hang(_ a: CTWTaiSan) -> some View {
        let h = CTWTaiSanHienThi.nhanHan(a.expiry)
        return HStack(spacing: 12) {
            Image(systemName: CTWTaiSanHienThi.bieuTuong(a.category))
                .font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let k = a.key { Text(k).font(.system(size: 11, weight: .bold).monospaced()).foregroundColor(AppColors.textTertiary) }
                    Text(a.name).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                }
                if a.expiry?.state != nil && a.expiry?.state != "NONE" { CTWNhanNho(chu: h.chu, mau: h.mau) }
                HStack(spacing: 6) {
                    if let l = a.licenseLabel ?? a.licenseName {
                        Text(l).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    }
                    if a.attributionRequired == true {
                        Image(systemName: "quote.bubble").font(.system(size: 10)).foregroundColor(AppColors.primary)
                            .accessibilityLabel("Needs a credit line")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chi tiết tài sản

struct TaiSanChiTietCTW: View {
    let r: RouteTaiSanCTW
    @EnvironmentObject private var app: AppState
    @State private var a: CTWTaiSan?
    @State private var loi: String?
    @State private var web: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if let a {
                    dau(a)
                    CTWKhoiTruong {
                        CTWHangTruong("Category", CTWMauTrangThai.nhan(a.category), bieuTuong: CTWTaiSanHienThi.bieuTuong(a.category))
                        Divider()
                        CTWHangTruong("License", a.licenseLabel ?? a.licenseName, bieuTuong: "checkmark.seal")
                        if let v = a.version, !v.isEmpty { Divider(); CTWHangTruong("Version", v, bieuTuong: "number") }
                        if let s = a.source, !s.isEmpty { Divider(); CTWHangTruong("Source", s, bieuTuong: "building.2") }
                        Divider()
                        CTWHangTruong(nhan: "Owner", bieuTuong: "person.crop.circle") {
                            HStack(spacing: 6) { CTWAvatar(user: a.owner, size: 20); Text(a.owner?.ten ?? "—") }
                        }
                        Divider()
                        CTWHangTruong("Expires", a.expiresAt.flatMap { CTW.ngayNgan($0) } ?? "No expiry", bieuTuong: "calendar")
                        if let n = a.remindDays, a.expiresAt != nil { Divider(); CTWHangTruong("Reminder", "\(n) days before", bieuTuong: "bell") }
                        if let s = a.seats { Divider(); CTWHangTruong("Seats", "\(s)", bieuTuong: "person.2") }
                        if let c = a.cost {
                            Divider()
                            CTWHangTruong("Cost", ([CTWTien.dinhDang(c, a.currency), CTWTaiSanHienThi.nhanThanhToan(a.billing)].compactMap { $0 }).joined(separator: " "),
                                          bieuTuong: "banknote")
                        } else if a.billing == "FREE" {
                            Divider(); CTWHangTruong("Cost", "Free", bieuTuong: "banknote")
                        }
                    }
                    if a.attributionRequired == true {
                        CTWSectionHeader("quote.bubble", "Credit line")
                        VStack(alignment: .leading, spacing: 8) {
                            Text(a.attribution?.isEmpty == false ? a.attribution! : "This license requires a credit line, but none has been written yet.")
                                .font(.system(size: 14, design: a.attribution == nil ? .default : .monospaced))
                                .foregroundColor(a.attribution == nil ? AppColors.warning : AppColors.textPrimary)
                                .textSelection(.enabled)
                            if let t = a.attribution, !t.isEmpty {
                                Button { CTW.chepVaoBoNho(t); CTWRung.thanhCong() } label: { Label("Copy credit line", systemImage: "doc.on.doc") }
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(12)
                    }
                    let nut = [("License terms", a.licenseUrl), ("Source page", a.sourceUrl)].compactMap { t -> URLToChucCTW? in
                        guard let s = t.1, s.hasPrefix("https://") || s.hasPrefix("http://"), let u = URL(string: s) else { return nil }
                        return URLToChucCTW(url: u, nhan: t.0)
                    }
                    if !nut.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(nut) { n in
                                Button { web = n.url } label: { Label(n.nhan ?? "Open", systemImage: "safari") }.buttonStyle(.bordered)
                            }
                        }
                    }
                    if let ls = a.links, !ls.isEmpty {
                        CTWSectionHeader("link", "Used in", count: "\(ls.count)")
                        VStack(spacing: 0) {
                            ForEach(Array(ls.enumerated()), id: \.offset) { i, l in
                                if i > 0 { Divider() }
                                lienKet(l)
                            }
                        }
                        .padding(.horizontal, 14).ctwThe(12)
                    }
                    if let n = a.notes, !n.isEmpty {
                        CTWSectionHeader("note.text", "Notes")
                        CTWMarkdownView(markdown: n, coChu: 14).padding(14).ctwThe(12)
                    }
                } else if loi == nil {
                    CTWKhungTai(soHang: 4, coAvatar: false)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(a?.key ?? r.ten)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await tai() }
        .task { if a == nil { await tai() } }
        .sheet(item: Binding(get: { web.map { URLToChucCTW(url: $0) } }, set: { web = $0?.url })) { w in
            SafariCTW(url: w.url).ignoresSafeArea()
        }
    }

    private func dau(_ a: CTWTaiSan) -> some View {
        let h = CTWTaiSanHienThi.nhanHan(a.expiry)
        return HStack(spacing: 14) {
            Image(systemName: CTWTaiSanHienThi.bieuTuong(a.category))
                .font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 6) {
                Text(a.name).font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    CTWChipChu(chu: a.status)
                    CTWNhanNho(chu: h.chu, mau: h.mau)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16).ctwThe(16)
    }

    @ViewBuilder
    private func lienKet(_ l: CTWTaiSan.LienKet) -> some View {
        let hang = HStack(spacing: 10) {
            Image(systemName: l.kind == "PAGE" ? "doc.text" : "checkmark.square").foregroundColor(AppColors.primary).frame(width: 20)
            if let k = l.key { Text(k).font(.system(size: 12, weight: .bold).monospaced()).foregroundColor(AppColors.textSecondary) }
            Text(l.title ?? "—").foregroundColor(AppColors.textPrimary).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
        }
        .font(.system(size: 14))
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        if l.kind == "PAGE", let so = l.number {
            NavigationLink(value: RouteTaiLieuCTW(pid: r.pid, so: so, ten: l.title ?? "Page")) { hang }.buttonStyle(.plain)
        } else if let so = l.number {
            NavigationLink(value: CTWRoute.the(pid: r.pid, so: so)) { hang }.buttonStyle(.plain)
        } else {
            hang
        }
    }

    private func tai() async {
        do { a = try await APIClient.shared.request(CTWAPI.taiSan(pid: r.pid, so: r.so)); loi = nil }
        catch { loi = CTW.loi(error) }
    }
}

/// URL bọc Identifiable cho `.sheet(item:)`.
struct URLToChucCTW: Identifiable { var url: URL; var nhan: String? = nil; var id: String { url.absoluteString } }
