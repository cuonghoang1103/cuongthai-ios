import SwiftUI

// MARK: - RAID — Risks · Assumptions · Issues · Dependencies (+ Questions)
//
// Tải MỘT lần cả sổ (`GET /raid`) rồi chia tab ở máy — đếm theo loại và ma trận
// 5×5 đã có sẵn trong phản hồi, đổi tab không phải gọi lại. Ma trận chỉ đếm rủi
// ro ĐANG MỞ (đúng như web); chạm một ô ⇒ lọc danh sách theo ô đó.

@MainActor
final class RaidVM: ObservableObject {
    let pid: Int
    @Published var ds: CTWRaidDanhSach?
    @Published var loi: String?
    @Published var tatMoDun = false
    init(pid: Int) { self.pid = pid }

    func tai() async {
        do { ds = try await APIClient.shared.request(CTWAPI.dsRaid(pid: pid, loai: nil)); loi = nil }
        catch {
            if GovLoi.laTatMoDun(error) { tatMoDun = true; return }
            loi = CTW.loi(error)
        }
    }
}

enum TamPhuRaid: Identifiable {
    case tao(String), sua(CTWRaid)
    var id: String {
        switch self {
        case .tao(let t): return "tao-\(t)"
        case .sua(let r): return "sua-\(r.id)"
        }
    }
}

struct RaidCTW: View {
    let pid: Int
    @StateObject private var vm: RaidVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var loai = "RISK"
    @State private var o: (p: Int, i: Int)?
    @State private var anDong = true
    @State private var tamPhu: TamPhuRaid?

    init(pid: Int) {
        self.pid = pid
        _vm = StateObject(wrappedValue: RaidVM(pid: pid))
    }

    private var hienLoai: [(ma: String, ten: String, bieuTuong: String)] {
        // Questions chỉ hiện khi có (web RAID cũng chỉ liệt kê bốn loại đầu).
        CTWRaidLuat.loai.filter { $0.ma != "QUESTION" || (vm.ds?.counts?["QUESTION"]?.total ?? 0) > 0 }
    }

    private var loc: [CTWRaid] {
        (vm.ds?.items ?? []).filter { r in
            guard r.type == loai else { return false }
            if anDong && r.closed == true && o == nil { return false }
            if let o { return r.probability == o.p && r.impact == o.i && r.closed != true }
            return true
        }
        .sorted { ($0.closed == true ? 1 : 0, -($0.score ?? 0), $0.number) < ($1.closed == true ? 1 : 0, -($1.score ?? 0), $1.number) }
    }

    var body: some View {
        List {
            if let loi = vm.loi {
                CTWErrorBanner(text: loi) { vm.loi = nil }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if vm.tatMoDun {
                GovTatMoDun(ten: "RAID log").listRowBackground(Color.clear)
            } else if let ds = vm.ds {
                Section {
                    CTWThanhLoc(chip: hienLoai.map { l in
                        let d = ds.counts?[l.ma]
                        return CTWChipLoc(id: l.ma, nhan: "\(l.ten) \(d?.open ?? 0)", bieuTuong: l.bieuTuong, bat: loai == l.ma)
                    }) { c in loai = c.id; o = nil }
                    .padding(.horizontal, -Spacing.md)
                    if loai == "RISK" {
                        tongRuiRo(ds)
                        MaTranRuiRoCTW(matran: ds.matrix ?? [], chon: o.map { ($0.p, $0.i) }, cao: ds.thresholds?.HIGH ?? 15, vua: ds.thresholds?.MEDIUM ?? 8) { p, i in
                            CTWRung.chon()
                            if o?.p == p && o?.i == i { o = nil } else { o = (p, i) }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                let ds2 = loc
                Section {
                    if ds2.isEmpty {
                        CTWOTrong(bieuTuong: CTWRaidLuat.loai.first { $0.ma == loai }?.bieuTuong ?? "tray",
                                  tieuDe: o != nil ? "No open risks in this cell" : "No \(CTWRaidLuat.tenLoai(loai).lowercased())s yet",
                                  moTa: "Keep risks, assumptions, issues and dependencies in one log so the team reviews them on time.",
                                  nut: ds.canEdit == true && o == nil ? "Add \(CTWRaidLuat.tenLoai(loai).lowercased())" : nil,
                                  hanhDong: { tamPhu = .tao(loai) })
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(ds2) { r in
                            NavigationLink(value: RouteRaidCTW(pid: pid, so: r.number)) { GovHangRaid(r: r) }
                        }
                    }
                } header: {
                    HStack {
                        if let o { Text("Probability \(o.p) × Impact \(o.i)") } else { Text(hienLoai.first { $0.ma == loai }?.ten ?? "") }
                        Spacer()
                        if o != nil {
                            Button("Clear filter") { o = nil }.font(.ctw(size: 13)).textCase(nil)
                        } else {
                            Button(anDong ? "Show closed" : "Hide closed") { anDong.toggle() }.font(.ctw(size: 13)).textCase(nil)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if vm.ds == nil && vm.loi == nil && !vm.tatMoDun { CTWKhungTai(soHang: 5) } }
        .navigationTitle("RAID log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.ds?.canEdit == true {
                ToolbarItem(placement: .primaryAction) {
                    Button { tamPhu = .tao(loai) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add \(CTWRaidLuat.tenLoai(loai).lowercased())")
                }
            }
        }
        .refreshable { await vm.tai() }
        .task { if vm.ds == nil { await vm.tai() } }
        .sheet(item: $tamPhu) { t in
            if case .tao(let l) = t {
                FormRaidCTW(pid: pid, ban: nil, loaiMoi: l) { r in
                    Task { await vm.tai() }
                    nganXep.duong.append(RouteRaidCTW(pid: pid, so: r.number))
                }
            }
        }
        .task(id: app.dichCho) {
            guard let d = app.dichCho, d.moDun == "raid" else { return }
            defer { app.dichCho = nil }
            let s = d.duongDan.phanCon.first ?? d.duongDan.tham["item"] ?? ""
            if let so = Int(s.split(separator: "-").last.map(String.init) ?? s) { nganXep.duong.append(RouteRaidCTW(pid: pid, so: so)) }
        }
        #if DEBUG
        .onAppear {
            if XemThuCTW.conCua("raid") == "detail", nganXep.duong.count <= 1 { nganXep.duong.append(RouteRaidCTW(pid: pid, so: 3)) }
        }
        #endif
    }

    private func tongRuiRo(_ ds: CTWRaidDanhSach) -> some View {
        HStack(spacing: 10) {
            CTWODem(so: "\(ds.highRisks ?? 0)", nhan: "High risks", bieuTuong: "exclamationmark.triangle.fill", mau: AppColors.error)
            CTWODem(so: "\(ds.counts?["RISK"]?.open ?? 0)", nhan: "Open risks", bieuTuong: "shield.lefthalf.filled", mau: AppColors.warning)
            CTWODem(so: "\(ds.reviewDue ?? 0)", nhan: "Review due", bieuTuong: "calendar.badge.exclamationmark", mau: AppColors.info)
        }
        .padding(.horizontal, Spacing.md)
    }
}

/// Ma trận 5×5: dọc là xác suất (5 trên cùng), ngang là tác động.
struct MaTranRuiRoCTW: View {
    let matran: [[Int]]
    var chon: (Int, Int)?
    var cao = 15
    var vua = 8
    let bam: (Int, Int) -> Void

    private func dem(_ p: Int, _ i: Int) -> Int {
        guard p - 1 < matran.count, i - 1 < matran[p - 1].count else { return 0 }
        return matran[p - 1][i - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {
                Text("Probability").font(.ctw(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                    .rotationEffect(.degrees(-90)).fixedSize().frame(width: 14)
                VStack(spacing: 4) {
                    ForEach((1...5).reversed(), id: \.self) { p in
                        HStack(spacing: 4) {
                            Text("\(p)").font(.ctw(size: 10, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textTertiary).frame(width: 12)
                            ForEach(1...5, id: \.self) { i in o(p, i) }
                        }
                    }
                    HStack(spacing: 4) {
                        Spacer().frame(width: 12)
                        ForEach(1...5, id: \.self) { i in
                            Text("\(i)").font(.ctw(size: 10, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textTertiary).frame(maxWidth: .infinity)
                        }
                    }
                    Text("Impact").font(.ctw(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(12)
        .ctwThe(14)
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private func o(_ p: Int, _ i: Int) -> some View {
        let n = dem(p, i)
        let mau = CTWRaidLuat.mauMuc(CTWRaidLuat.muc(p * i, cao: cao, vua: vua))
        let dangChon = chon.map { $0.0 == p && $0.1 == i } ?? false
        return Button { bam(p, i) } label: {
            Text(n > 0 ? "\(n)" : "")
                .font(.ctw(size: 14, weight: .bold).monospacedDigit())
                .foregroundColor(n > 0 ? .white : .clear)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(mau.opacity(n > 0 ? 0.85 : 0.14)))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(dangChon ? AppColors.textPrimary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(n == 0)
        .accessibilityLabel("Probability \(p), impact \(i): \(n) open risk\(n == 1 ? "" : "s")")
    }
}

struct GovHangRaid: View {
    let r: CTWRaid
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let s = r.score {
                Text("\(s)").font(.ctw(size: 14, weight: .bold).monospacedDigit()).foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CTWRaidLuat.mauMuc(r.level ?? CTWRaidLuat.muc(s))))
                    .accessibilityLabel("Score \(s)")
            } else {
                Image(systemName: CTWRaidLuat.loai.first { $0.ma == r.type }?.bieuTuong ?? "circle")
                    .font(.ctw(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppColors.primary.opacity(0.12)))
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(r.nhanKhoa).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                    CTWChipChu(chu: r.status)
                    if r.reviewDue == true { CTWNhanNho(chu: "Review due", bieuTuong: "calendar.badge.exclamationmark", mau: AppColors.warning) }
                }
                Text(r.title).font(.ctw(size: 15, weight: .medium)).foregroundColor(r.closed == true ? AppColors.textSecondary : AppColors.textPrimary)
                    .strikethrough(r.closed == true).lineLimit(2)
                HStack(spacing: 10) {
                    if let o = r.owner { HStack(spacing: 4) { CTWAvatar(user: o, size: 18); Text(o.ten).lineLimit(1) } }
                    if let d = CTW.ngayNgan(r.reviewDate) { Label(d, systemImage: "calendar") }
                    if let n = r.linkCount, n > 0 { Label("\(n)", systemImage: "link") }
                }
                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary).labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chi tiết

struct ChiTietRaidCTW: View {
    let pid: Int
    let so: Int
    @EnvironmentObject private var app: AppState
    @State private var r: CTWRaid?
    @State private var loi: String?
    @State private var khoaSua = false
    @State private var tamPhu: TamPhuRaid?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let loi { CTWErrorBanner(text: loi) { self.loi = nil } }
                if khoaSua { GovDaiKhoaSua(pid: pid) { khoaSua = false } }
                if let r { noiDung(r) } else if loi == nil { CTWKhungTai(soHang: 4, coAvatar: false).padding(-Spacing.md) }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(r?.nhanKhoa ?? "RAID")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let r, r.canEdit == true {
                ToolbarItem(placement: .primaryAction) { Button("Edit") { tamPhu = .sua(r) } }
            }
        }
        .refreshable { await tai() }
        .task { if r == nil { await tai() } }
        .sheet(item: $tamPhu) { t in
            if case .sua(let ban) = t { FormRaidCTW(pid: pid, ban: ban, loaiMoi: ban.type ?? "RISK") { moi in r = moi } }
        }
    }

    @ViewBuilder
    private func noiDung(_ r: CTWRaid) -> some View {
        let cuaToi = r.createdBy?.id == app.currentUser?.id
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CTWNhanNho(chu: CTWRaidLuat.tenLoai(r.type), bieuTuong: CTWRaidLuat.loai.first { $0.ma == r.type }?.bieuTuong)
                if r.canEdit == true {
                    Menu {
                        ForEach(r.statuses ?? CTWRaidLuat.trangThai(cho: r.type), id: \.self) { s in
                            Button { Task { await sua(["status": s]) } } label: {
                                if s == r.status { Label(CTWMauTrangThai.nhan(s), systemImage: "checkmark") } else { Text(CTWMauTrangThai.nhan(s)) }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) { CTWChipChu(chu: r.status); Image(systemName: "chevron.down").font(.ctw(size: 9, weight: .bold)).foregroundColor(AppColors.textTertiary) }
                            .frame(minHeight: 32)
                    }
                    .accessibilityLabel("Status: \(CTWMauTrangThai.nhan(r.status)). Change")
                } else {
                    CTWChipChu(chu: r.status)
                }
                if let l = r.level { CTWNhanNho(chu: "\(CTWMauTrangThai.nhan(l)) · \(r.score ?? 0)", bieuTuong: "gauge.with.dots.needle.67percent", mau: CTWRaidLuat.mauMuc(l)) }
            }
            Text(r.title).font(.ctw(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .ctwMenuBaoCaoChan(khoa: "raid-\(pid)-\(r.number)", noiDung: r.title, nguCanh: "RAID \(r.nhanKhoa)", tacGia: r.createdBy, laCuaToi: cuaToi,
                                   dich: CTWDichBaoCao("raid_item", r.id))
        }
        if r.type == "RISK" && r.canEdit == true { thangDiem(r) }
        CTWKhoiTruong {
            CTWHangTruong(nhan: "Owner", bieuTuong: "person") {
                HStack(spacing: 6) {
                    CTWAvatar(user: r.owner, size: 20)
                    Text(r.owner?.ten ?? "Unassigned")
                    if r.owner?.laAgent == true { CTWNhanAI() }
                }
            }
            if r.type == "RISK" {
                Divider(); CTWHangTruong("Probability", r.probability.map { "\($0) / 5" }, bieuTuong: "dice")
                Divider(); CTWHangTruong("Impact", r.impact.map { "\($0) / 5" }, bieuTuong: "bolt")
                Divider(); CTWHangTruong("Response", r.response.map(CTWMauTrangThai.nhan), bieuTuong: "shield")
            }
            if let c = r.category, !c.isEmpty { Divider(); CTWHangTruong("Category", c, bieuTuong: "tag") }
            Divider()
            CTWHangTruong(nhan: "Review date", bieuTuong: "calendar") {
                Text(CTW.ngayNgan(r.reviewDate) ?? "—").foregroundColor(r.reviewDue == true ? AppColors.error : AppColors.textPrimary)
            }
            if r.clientVisible == true { Divider(); CTWHangTruong("Client portal", "Visible to the client", bieuTuong: "person.crop.rectangle") }
            Divider(); CTWHangTruong("Updated", CTW.thoiDiem(r.updatedAt), bieuTuong: "clock")
        }
        ForEach([("Description", "text.alignleft", r.description), ("Mitigation / plan", "wrench.and.screwdriver", r.mitigation),
                 ("Trigger", "bell", r.trigger)], id: \.0) { m in
            if let t = m.2?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                CTWSectionHeader(m.1, m.0)
                CTWMarkdownView(markdown: t, coChu: 15)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
                    .ctwMenuBaoCaoChan(khoa: "raid-\(m.0.lowercased())-\(pid)-\(r.number)", noiDung: t, nguCanh: "RAID \(r.nhanKhoa)",
                                       tacGia: r.createdBy, laCuaToi: cuaToi, dich: CTWDichBaoCao("raid_item", r.id))
            }
        }
        lienKet(r)
        lichSu(r)
    }

    private func thangDiem(_ r: CTWRaid) -> some View {
        VStack(spacing: 10) {
            buoc("Probability", r.probability) { v in Task { await sua(["probability": govNull(v)]) } }
            Divider()
            buoc("Impact", r.impact) { v in Task { await sua(["impact": govNull(v)]) } }
        }
        .padding(12)
        .ctwThe(14)
    }

    private func buoc(_ ten: String, _ gt: Int?, _ dat: @escaping (Int?) -> Void) -> some View {
        HStack(spacing: 6) {
            Text(ten).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).frame(width: 86, alignment: .leading)
            ForEach(1...5, id: \.self) { v in
                Button { CTWRung.chon(); dat(gt == v ? nil : v) } label: {
                    Text("\(v)").font(.ctw(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundColor(gt == v ? AppColors.onPrimary : AppColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(gt == v ? AppColors.primary : AppColors.backgroundTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(ten) \(v)")
                .accessibilityAddTraits(gt == v ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func lienKet(_ r: CTWRaid) -> some View {
        let ds = r.links ?? []
        if !ds.isEmpty {
            CTWSectionHeader("link", "Linked", count: "\(ds.count)")
            VStack(spacing: 0) {
                ForEach(ds) { l in
                    Group {
                        if let i = l.issue {
                            NavigationLink(value: CTWRoute.the(pid: pid, so: i.number)) { hang("circle.inset.filled", i.key ?? "#\(i.number)", i.title ?? "") }
                        } else if let c = l.changeRequest {
                            NavigationLink(value: RouteCrCTW(pid: pid, so: c.number)) { hang("arrow.triangle.branch", c.key ?? "CR-\(c.number)", c.title ?? "") }
                        } else if let s = l.stage {
                            hang("flag.checkered", "Stage \(s.n.map(String.init) ?? "")", s.name ?? "")
                        }
                    }
                    .buttonStyle(.plain)
                    if l.id != ds.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14).ctwThe(14)
        }
    }

    private func hang(_ icon: String, _ k: String, _ t: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(AppColors.primary).frame(width: 18)
            Text(k).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
            Text(t).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44).contentShape(Rectangle())
    }

    @ViewBuilder
    private func lichSu(_ r: CTWRaid) -> some View {
        let ds = r.history ?? []
        if !ds.isEmpty {
            CTWSectionHeader("clock.arrow.circlepath", "History", count: "\(ds.count)")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(ds.prefix(30)) { h in
                    HStack(alignment: .top, spacing: 10) {
                        CTWAvatar(user: h.actor, size: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(h.actor?.ten ?? "Someone").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                if h.actor?.laAgent == true { CTWNhanAI() }
                            }
                            Text(moTa(h)).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                            Text(CTW.thoiDiem(h.createdAt)).font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).ctwThe(14)
        }
    }

    private func moTa(_ h: CTWRaidLichSu) -> String {
        let f = CTWRaidLuat.tenTruong(h.field)
        if h.field == "created" { return "created this item" }
        let tu = h.fromValue.map { h.field == "status" || h.field == "response" ? CTWMauTrangThai.nhan($0) : $0 }
        let den = h.toValue.map { h.field == "status" || h.field == "response" ? CTWMauTrangThai.nhan($0) : $0 }
        switch (tu, den) {
        case (nil, let d?): return "set \(f) to \(d)"
        case (let t?, nil): return "cleared \(f) (was \(t))"
        case (let t?, let d?): return "changed \(f) from \(t) to \(d)"
        default: return "updated \(f)"
        }
    }

    // MARK: Mạng

    private func tai() async {
        do { r = try await APIClient.shared.request(CTWAPI.raid(pid: pid, so: so)); loi = nil }
        catch { loi = CTW.loi(error) }
    }

    private func sua(_ than: [String: Any]) async {
        var t = than
        if let v = r?.version { t["version"] = v }
        do {
            r = try await APIClient.shared.request(CTWAPI.suaRaid(pid: pid, so: so, than: t))
            CTWRung.thanhCong()
        } catch {
            CTWRung.loi()
            if GovLoi.laKhoaSua(error) { khoaSua = true }
            else if CTW.laXungDot(error) { loi = "Someone else just changed this item. It has been reloaded."; await tai() }
            else { loi = CTW.loi(error) }
        }
    }
}

// MARK: - Tạo / sửa

struct FormRaidCTW: View {
    let pid: Int
    let ban: CTWRaid?
    let loaiMoi: String
    let xong: (CTWRaid) -> Void
    @Environment(\.dismiss) private var dong
    @EnvironmentObject private var app: AppState
    @State private var loai = "RISK"
    @State private var tieuDe = ""
    @State private var moTa = ""
    @State private var nhom = ""
    @State private var trangThai = "OPEN"
    @State private var chuSo: Int = 0
    @State private var xacSuat = 0
    @State private var tacDong = 0
    @State private var phanUng = ""
    @State private var giamThieu = ""
    @State private var dauHieu = ""
    @State private var coNgay = false
    @State private var ngay = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var loi: String?
    @State private var dangLuu = false
    @State private var khoaSua = false
    @State private var daNap = false

    private var thanhVien: [CTWUser] {
        (app.cauHinhDuAn?.dsThanhVien ?? []).filter { $0.role != "CLIENT" }
            .sorted { $0.ten.localizedCaseInsensitiveCompare($1.ten) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi) { self.loi = nil } }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                if khoaSua { Section { GovDaiKhoaSua(pid: pid) { khoaSua = false } }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                Section {
                    Picker("Type", selection: $loai) {
                        ForEach(CTWRaidLuat.loai, id: \.ma) { l in Text(CTWRaidLuat.tenLoai(l.ma)).tag(l.ma) }
                    }
                    .onChange(of: loai) { _, moi in
                        if !CTWRaidLuat.trangThai(cho: moi).contains(trangThai) { trangThai = CTWRaidLuat.macDinh(cho: moi) }
                    }
                    TextField("Title", text: $tieuDe, axis: .vertical).lineLimit(1...3)
                    TextField("Description", text: $moTa, axis: .vertical).lineLimit(2...6)
                    Picker("Status", selection: $trangThai) {
                        ForEach(CTWRaidLuat.trangThai(cho: loai), id: \.self) { s in Text(CTWMauTrangThai.nhan(s)).tag(s) }
                    }
                    Picker("Owner", selection: $chuSo) {
                        Text("Unassigned").tag(0)
                        ForEach(thanhVien) { u in Text(u.laAgent ? "\(u.ten) (AI agent)" : u.ten).tag(u.id) }
                    }
                    TextField("Category (optional)", text: $nhom)
                }
                if loai == "RISK" {
                    Section {
                        Stepper("Probability: \(xacSuat == 0 ? "not set" : "\(xacSuat)")", value: $xacSuat, in: 0...5)
                        Stepper("Impact: \(tacDong == 0 ? "not set" : "\(tacDong)")", value: $tacDong, in: 0...5)
                        if let d = CTWRaidLuat.diem(xacSuat, tacDong) {
                            HStack {
                                Text("Score")
                                Spacer()
                                CTWNhanNho(chu: "\(d) · \(CTWMauTrangThai.nhan(CTWRaidLuat.muc(d)))", mau: CTWRaidLuat.mauMuc(CTWRaidLuat.muc(d)))
                            }
                        }
                        Picker("Response", selection: $phanUng) {
                            Text("Not set").tag("")
                            ForEach(CTWRaidLuat.phanUng, id: \.self) { p in Text(CTWMauTrangThai.nhan(p)).tag(p) }
                        }
                        TextField("Trigger (what tells us it's happening)", text: $dauHieu, axis: .vertical).lineLimit(1...4)
                    } header: { Text("Assessment") } footer: { Text("Score = probability × impact. 15+ is high, 8+ is medium.") }
                }
                Section {
                    TextField("Mitigation / plan", text: $giamThieu, axis: .vertical).lineLimit(2...6)
                    Toggle("Review date", isOn: $coNgay)
                    if coNgay { DatePicker("Review on", selection: $ngay, displayedComponents: .date) }
                }
            }
            .navigationTitle(ban == nil ? "New \(CTWRaidLuat.tenLoai(loai).lowercased())" : "Edit \(ban!.nhanKhoa)")
            .ctwTieuDeNho()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    if dangLuu { ProgressView() } else {
                        Button(ban == nil ? "Add" : "Save") { Task { await luu() } }
                            .bold().disabled(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onAppear(perform: nap)
        }
    }

    private func nap() {
        guard !daNap else { return }
        daNap = true
        loai = ban?.type ?? loaiMoi
        trangThai = ban?.status ?? CTWRaidLuat.macDinh(cho: loai)
        guard let b = ban else { return }
        tieuDe = b.title
        moTa = b.description ?? ""
        nhom = b.category ?? ""
        chuSo = b.owner?.id ?? 0
        xacSuat = b.probability ?? 0
        tacDong = b.impact ?? 0
        phanUng = b.response ?? ""
        giamThieu = b.mitigation ?? ""
        dauHieu = b.trigger ?? ""
        if let d = CTW.ngayDate(b.reviewDate) {
            coNgay = true
            // ngayDate đọc theo UTC — đổi về ngày LỊCH của máy để DatePicker hiện đúng ngày.
            var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
            let p = c.dateComponents([.year, .month, .day], from: d)
            ngay = Calendar.current.date(from: p) ?? d
        }
    }

    private func luu() async {
        func ch(_ s: String) -> Any { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return govNull(t.isEmpty ? nil : t) }
        var t: [String: Any] = [
            "type": loai,
            "title": String(tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).prefix(255)),
            "description": ch(moTa), "category": ch(String(nhom.prefix(60))), "status": trangThai,
            "ownerId": govNull(chuSo == 0 ? nil : chuSo),
            "mitigation": ch(giamThieu),
            "reviewDate": govNull(coNgay ? CTW.chuoiNgay(ngay) : nil),
        ]
        if loai == "RISK" {
            t["probability"] = govNull(xacSuat == 0 ? nil : xacSuat)
            t["impact"] = govNull(tacDong == 0 ? nil : tacDong)
            t["response"] = govNull(phanUng.isEmpty ? nil : phanUng)
            t["trigger"] = ch(dauHieu)
        }
        dangLuu = true
        defer { dangLuu = false }
        do {
            let r: CTWRaid
            if let b = ban {
                if let v = b.version { t["version"] = v }
                r = try await APIClient.shared.request(CTWAPI.suaRaid(pid: pid, so: b.number, than: t))
            } else {
                r = try await APIClient.shared.request(CTWAPI.taoRaid(pid: pid, than: t))
            }
            CTWRung.thanhCong()
            xong(r)
            dong()
        } catch {
            CTWRung.loi()
            if GovLoi.laKhoaSua(error) { khoaSua = true }
            else if CTW.laXungDot(error) { loi = "Someone else changed this item. Close, pull to refresh and try again." }
            else { loi = CTW.loi(error) }
        }
    }
}
