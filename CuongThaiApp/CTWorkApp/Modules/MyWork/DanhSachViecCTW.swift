import SwiftUI

// MARK: - My Work → Issues (app CT Work riêng, 20/10/2026)
//
// Phản hồi chủ app (ảnh IMG_1258, 104 thẻ quá hạn): bốn ô đếm lệch lề với ô tìm + công tắc, khoảng trống lớn, danh
// sách một bức tường không nhóm, không gập được. Màn này:
//   · MỌI thứ nằm trong MỘT List ⇒ cùng một lề với ô tìm của thanh điều hướng (List insetGrouped theo lề hệ thống).
//   · Ô đếm là BỘ LỌC (bấm Overdue ⇒ chỉ thẻ quá hạn; bấm lại ⇒ bỏ lọc).
//   · Nhóm theo Hạn (như web: quá hạn · hôm nay · sắp tới · sau · không hạn) / Dự án / Trạng thái; mỗi nhóm GẬP được
//     (nhớ qua lần mở) và chỉ hiện 12 thẻ đầu + "Show all N".
//   · Hàng gọn kiểu web: loại · dấu dự án · mã · trạng thái … ưu tiên · hạn (đỏ khi quá hạn).
//   · Vuốt: Move (chuyển trạng thái theo quy trình của dự án), Log time; vuốt phải: mở Board của dự án. Nhấn giữ: menu.
// Dữ liệu: `GET /work/me/work` (CTWMyWorkVM dùng chung với app chính).

struct DanhSachViecCTW: View {
    /// Hàng đầu (công tắc Issues/Agenda) — nằm trong List để thẳng lề.
    var dau: AnyView? = nil

    @StateObject private var vm = CTWMyWorkVM()
    @EnvironmentObject private var nganXep: NganXepCTW
    @Environment(\.dynamicTypeSize) private var coChu

    @AppStorage("ctw.myWork.nhomTheo") private var nhomTheo: NhomTheo = .han
    /// Id các nhóm đang gập, nối bằng "|" (AppStorage không giữ được Set).
    @AppStorage("ctw.myWork.thuGon") private var thuGonLuu = ""
    @State private var loc: Loc?
    @State private var moHet: Set<String> = []
    @State private var tamPhu: TamPhu?

    enum NhomTheo: String, CaseIterable, Identifiable {
        case han, duAn, trangThai
        var id: String { rawValue }
        var ten: LocalizedStringKey {
            switch self {
            case .han: return "Due date"
            case .duAn: return "Project"
            case .trangThai: return "Status"
            }
        }
        var bieuTuong: String {
            switch self {
            case .han: return "calendar"
            case .duAn: return "folder"
            case .trangThai: return "circle.lefthalf.filled"
            }
        }
    }

    enum Loc: String { case quaHan, homNay, sapToi, dangLam }

    enum TamPhu: Identifiable {
        case chuyen(CTWMyWorkItem), ghiGio(CTWMyWorkItem)
        var id: String {
            switch self {
            case .chuyen(let i): return "chuyen-\(i.key)"
            case .ghiGio(let i): return "gio-\(i.key)"
            }
        }
    }

    /// Một nhóm trong danh sách.
    struct Nhom: Identifiable {
        enum Loai { case han(String), duAn(ma: String, ten: String, slug: String?), trangThai(String, String?) }
        let id: String
        let loai: Loai
        let items: [CTWMyWorkItem]
    }

    private static let gioiHan = 12

    var body: some View {
        List {
            Section {
                if let dau { dau }
                if let c = vm.duLieu?.counts { oDem(c) }
                if vm.duLieu != nil, !(vm.duLieu?.items ?? []).isEmpty { hangDieuKhien }
                if let loi = vm.loi {
                    VStack(spacing: 10) {
                        CTWErrorBanner(text: loi)
                        if vm.duLieu == nil { Button("Try again") { Task { await vm.tai() } }.buttonStyle(.bordered) }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if vm.duLieu == nil && vm.loi == nil {
                Section { ForEach(0..<6, id: \.self) { _ in HangGiuChoCTW() } }
            } else if let d = vm.duLieu {
                if (d.items ?? []).isEmpty {
                    oTrong(icon: "checkmark.circle.fill", mau: AppColors.success,
                           tieuDe: "You're all caught up",
                           moTa: "Open issues assigned to you in any project show up here.")
                } else if dsNhom.isEmpty {
                    oTrong(icon: "line.3.horizontal.decrease.circle", mau: AppColors.primary,
                           tieuDe: "Nothing matches this filter",
                           moTa: "No issues in this group right now.", boLoc: true)
                }
                ForEach(dsNhom) { n in phan(n) }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .animation(.snappy(duration: 0.25), value: thuGonLuu)
        .animation(.snappy(duration: 0.25), value: loc)
        .refreshable { await vm.tai() }
        .task { if vm.duLieu == nil { await vm.tai() } }
        .sheet(item: $tamPhu) { t in
            switch t {
            case .chuyen(let i):
                ChuyenNhanhCTW(item: i) { Task { await vm.tai() } }
                    .presentationDetents([.medium, .large])
            case .ghiGio(let i):
                NavigationStack {
                    if let slug = i.workspace?.slug, let ma = i.project?.key {
                        CTWResolver(slug: slug, ma: ma) { pid in
                            GhiGioCTW(pid: pid, so: i.number, tieuDe: i.title, maDuAn: ma) { tamPhu = nil }
                        }
                    }
                }
            }
        }
    }

    // MARK: Ô đếm = bộ lọc

    private func oDem(_ c: CTWMyWorkCounts) -> some View {
        let cot = coChu >= .xxLarge ? 2 : 4
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: cot), spacing: 8) {
            o(.quaHan, "Overdue", "exclamationmark.triangle.fill", c.overdue ?? 0, AppColors.error)
            o(.homNay, "Today", "calendar.badge.clock", c.dueToday ?? 0, AppColors.accent)
            o(.sapToi, "Soon", "clock", c.dueSoon ?? 0, AppColors.warning)
            o(.dangLam, "In progress", "circle.lefthalf.filled", c.inProgress ?? 0, AppColors.info)
        }
    }

    private func o(_ l: Loc, _ ten: LocalizedStringKey, _ icon: String, _ so: Int, _ mau: Color) -> some View {
        let chon = loc == l
        let co = so > 0
        return Button {
            CTWRung.chon()
            loc = chon ? nil : l
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.ctw(size: 11, weight: .semibold))
                        .foregroundColor(co ? mau : AppColors.textTertiary)
                    Spacer(minLength: 0)
                    if chon {
                        Image(systemName: "checkmark.circle.fill").font(.ctw(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                }
                Text("\(so)").font(.ctw(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundColor(co ? mau : AppColors.textTertiary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(ten).font(.ctw(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(chon ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(chon ? AppColors.primary : AppColors.border, lineWidth: chon ? 1.5 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ten))
        .accessibilityValue(Text("\(so)"))
        .accessibilityHint(chon ? Text("Shows all issues again") : Text("Shows only these issues"))
        .accessibilityAddTraits(chon ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Hàng điều khiển: nhóm theo · gập/mở hết · số thẻ

    private var hangDieuKhien: some View {
        HStack(spacing: 8) {
            Menu {
                Picker(selection: $nhomTheo) {
                    ForEach(NhomTheo.allCases) { n in Label(n.ten, systemImage: n.bieuTuong).tag(n) }
                } label: { Text("Group by") }
                Divider()
                Button { thuGonLuu = dsNhom.map(\.id).joined(separator: "|") } label: {
                    Label("Collapse all", systemImage: "rectangle.compress.vertical")
                }
                Button { thuGonLuu = "" } label: { Label("Expand all", systemImage: "rectangle.expand.vertical") }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.3.group").font(.ctw(size: 12, weight: .semibold))
                    Text("Group:").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                    Text(nhomTheo.ten).font(.ctw(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down").font(.ctw(size: 10, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                }
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 10).frame(minHeight: 32)
                .background(Capsule().fill(AppColors.backgroundCard))
                .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 0.5))
            }
            .accessibilityLabel(Text("Group by"))
            .accessibilityValue(Text(nhomTheo.ten))
            if loc != nil {
                Button { CTWRung.chon(); loc = nil } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark").font(.ctw(size: 10, weight: .bold))
                        Text("Clear filter").font(.ctw(size: 13, weight: .medium))
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 10).frame(minHeight: 32)
                    .background(Capsule().fill(AppColors.primary.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            let hien = itemsDaLoc.count
            let tong = vm.duLieu?.items?.count ?? 0
            Group {
                if hien == tong { Text("\(tong) issues") } else { Text("\(hien) of \(tong)") }
            }
            .font(.ctw(size: 12).monospacedDigit())
            .foregroundColor(AppColors.textTertiary)
            .lineLimit(1)
        }
        .padding(.top, 2)
    }

    // MARK: Dữ liệu

    private var itemsDaLoc: [CTWMyWorkItem] {
        let ds = vm.duLieu?.items ?? []
        switch loc {
        case nil: return ds
        case .quaHan: return ds.filter { $0.bucket == "overdue" }
        case .homNay: return ds.filter { $0.bucket == "today" }
        case .sapToi: return ds.filter { $0.bucket == "soon" }
        case .dangLam: return ds.filter { $0.status?.category == "IN_PROGRESS" }
        }
    }

    private static let thuTuHan = ["overdue", "today", "soon", "later", "none"]
    private static func han(_ i: CTWMyWorkItem) -> String { i.bucket ?? (i.dueDate == nil ? "none" : "later") }

    /// Trong nhóm: hạn sớm trước (không hạn cuối), rồi ưu tiên cao trước.
    private static func xep(_ a: CTWMyWorkItem, _ b: CTWMyWorkItem) -> Bool {
        let da = CTW.ngay(a.dueDate) ?? "9999", db = CTW.ngay(b.dueDate) ?? "9999"
        if da != db { return da < db }
        return (a.priority ?? 3) < (b.priority ?? 3)
    }

    private var dsNhom: [Nhom] {
        let ds = itemsDaLoc
        switch nhomTheo {
        case .han:
            return Self.thuTuHan.compactMap { b in
                let m = ds.filter { Self.han($0) == b }.sorted(by: Self.xep)
                return m.isEmpty ? nil : Nhom(id: "han:\(b)", loai: .han(b), items: m)
            }
        case .duAn:
            let g = Dictionary(grouping: ds) { $0.project?.key ?? "?" }
            return g.map { ma, m in
                Nhom(id: "da:\(ma)", loai: .duAn(ma: ma, ten: m.first?.project?.name ?? ma, slug: m.first?.workspace?.slug),
                     items: m.sorted(by: Self.xep))
            }
            // Dự án có nhiều thẻ quá hạn lên đầu, rồi theo số thẻ.
            .sorted {
                let qa = $0.items.filter { $0.bucket == "overdue" }.count, qb = $1.items.filter { $0.bucket == "overdue" }.count
                return qa != qb ? qa > qb : ($0.items.count != $1.items.count ? $0.items.count > $1.items.count : $0.id < $1.id)
            }
        case .trangThai:
            let g = Dictionary(grouping: ds) { $0.status?.name ?? "—" }
            let thuTu = ["IN_PROGRESS": 0, "TODO": 1, "DONE": 2]
            return g.map { ten, m in
                Nhom(id: "tt:\(ten)", loai: .trangThai(ten, m.first?.status?.category), items: m.sorted(by: Self.xep))
            }
            .sorted {
                guard case .trangThai(_, let ca) = $0.loai, case .trangThai(_, let cb) = $1.loai else { return false }
                let a = thuTu[ca ?? "TODO"] ?? 1, b = thuTu[cb ?? "TODO"] ?? 1
                return a != b ? a < b : $0.id < $1.id
            }
        }
    }

    private var thuGon: Set<String> { Set(thuGonLuu.split(separator: "|").map(String.init)) }

    private func doiGon(_ id: String) {
        var s = thuGon
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        thuGonLuu = s.sorted().joined(separator: "|")
        CTWRung.chon()
    }

    // MARK: Nhóm

    @ViewBuilder
    private func phan(_ n: Nhom) -> some View {
        let gon = thuGon.contains(n.id)
        let hetCho = moHet.contains(n.id) || n.items.count <= Self.gioiHan + 3
        Section {
            if !gon {
                ForEach(hetCho ? n.items : Array(n.items.prefix(Self.gioiHan))) { i in hang(i) }
                if !hetCho {
                    Button { moHet.insert(n.id) } label: {
                        HStack {
                            Text("Show all \(n.items.count)").font(.ctw(size: 14, weight: .medium))
                            Image(systemName: "chevron.down").font(.ctw(size: 11, weight: .semibold))
                        }
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            dauNhom(n, gon: gon)
        }
    }

    private func dauNhom(_ n: Nhom, gon: Bool) -> some View {
        HStack(spacing: 8) {
            Button { doiGon(n.id) } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.ctw(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(gon ? 0 : 90))
                        .frame(width: 14)
                    bieuTuongNhom(n.loai)
                    tenNhom(n.loai)
                        .font(.ctw(size: 14, weight: .semibold))
                        .foregroundColor(mauTenNhom(n.loai))
                        .lineLimit(1)
                    Text("\(n.items.count)")
                        .font(.ctw(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(gon ? Text("Collapsed") : Text("Expanded"))
            .accessibilityHint(gon ? Text("Expands the group") : Text("Collapses the group"))
            if case .duAn(let ma, _, let slug?) = n.loai {
                Button { moBang(slug: slug, ma: ma) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.split.3x1")
                        Text("Board")
                    }
                        .font(.ctw(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 9).frame(minHeight: 28)
                        .background(Capsule().fill(AppColors.primary.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel(Text("Open \(ma) board"))
            }
        }
        .textCase(nil)
        .padding(.horizontal, -4)
    }

    @ViewBuilder private func bieuTuongNhom(_ l: Nhom.Loai) -> some View {
        switch l {
        case .han(let b):
            Circle().fill(mauHan(b)).frame(width: 8, height: 8)
        case .duAn(let ma, _, _):
            CTWProjectMark(ma: ma, co: 18)
        case .trangThai(_, let c):
            CTWStatusGlyph(category: c, co: 12)
        }
    }

    private func tenNhom(_ l: Nhom.Loai) -> Text {
        switch l {
        case .han(let b):
            switch b {
            case "overdue": return Text("Overdue")
            case "today": return Text("Due today")
            case "soon": return Text("Due soon")
            case "later": return Text("Later")
            default: return Text("No due date")
            }
        case .duAn(_, let ten, _): return Text(verbatim: ten)
        case .trangThai(let ten, _): return Text(verbatim: CTWTen.trangThaiCau(ten))
        }
    }

    private func mauHan(_ b: String) -> Color {
        switch b {
        case "overdue": return AppColors.error
        case "today": return AppColors.accent
        case "soon": return AppColors.warning
        default: return AppColors.textTertiary
        }
    }

    private func mauTenNhom(_ l: Nhom.Loai) -> Color {
        if case .han(let b) = l, b == "overdue" || b == "today" { return mauHan(b) }
        return AppColors.textPrimary
    }

    // MARK: Hàng

    @ViewBuilder
    private func hang(_ i: CTWMyWorkItem) -> some View {
        let noiDung = HStack(alignment: .top, spacing: 10) {
            Image(systemName: CTW.bieuTuongLoai(key: i.type?.key))
                .font(.ctw(size: 10, weight: .bold)).foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(CTW.mau(i.type?.color, macDinh: AppColors.info)))
                .padding(.top, 1)
                .accessibilityLabel(Text(verbatim: CTWTen.loai(i.type?.name ?? "")))
            VStack(alignment: .leading, spacing: 6) {
                Text(i.title)
                    .font(.ctw(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        siDau(i)
                        Spacer(minLength: 4)
                        siCuoi(i)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        siDau(i)
                        siCuoi(i)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)

        Group {
            if let slug = i.workspace?.slug, let ma = i.project?.key {
                NavigationLink(value: CTWRoute.theTheoMa(slug: slug, ma: ma, so: i.number)) { noiDung }
            } else {
                noiDung
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { tamPhu = .chuyen(i) } label: { Label("Move", systemImage: "arrow.right.circle") }
                .tint(AppColors.primary)
            Button { tamPhu = .ghiGio(i) } label: { Label("Log time", systemImage: "clock.badge.checkmark") }
                .tint(AppColors.secondary)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let slug = i.workspace?.slug, let ma = i.project?.key {
                Button { moBang(slug: slug, ma: ma) } label: { Label("Board", systemImage: "rectangle.split.3x1") }
                    .tint(AppColors.info)
            }
        }
        .contextMenu {
            Button { tamPhu = .chuyen(i) } label: { Label("Move to…", systemImage: "arrow.right.circle") }
            Button { tamPhu = .ghiGio(i) } label: { Label("Log time", systemImage: "clock.badge.checkmark") }
            if let slug = i.workspace?.slug, let ma = i.project?.key {
                Button { moBang(slug: slug, ma: ma) } label: { Label("Open \(ma) board", systemImage: "rectangle.split.3x1") }
            }
            Button { CTW.chepVaoBoNho(i.key) } label: { Label("Copy key", systemImage: "number") }
        }
    }

    /// Mã · trạng thái (+ dấu dự án khi không nhóm theo dự án).
    private func siDau(_ i: CTWMyWorkItem) -> some View {
        HStack(spacing: 6) {
            if nhomTheo != .duAn, let ma = i.project?.key {
                CTWProjectMark(ma: ma, co: 15)
                    .accessibilityLabel(Text(verbatim: i.project?.name ?? ma))
            }
            Text(i.key)
                .font(.ctw(size: 12, weight: .medium).monospaced())
                .foregroundColor(AppColors.primary)
                .fixedSize()
            CTWStatusChip(ten: i.status?.name, category: i.status?.category)
                .fixedSize()
        }
    }

    /// Ưu tiên · hạn.
    private func siCuoi(_ i: CTWMyWorkItem) -> some View {
        HStack(spacing: 7) {
            CTWPriorityIcon(priority: i.priority)
            CTWDueChip(dueDate: i.dueDate, xong: i.status?.category == "DONE")
        }
        .fixedSize()
    }

    // MARK: Ô trống

    private func oTrong(icon: String, mau: Color, tieuDe: LocalizedStringKey, moTa: LocalizedStringKey, boLoc: Bool = false) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.ctw(size: 28, weight: .semibold)).foregroundColor(mau)
                .frame(width: 64, height: 64)
                .background(Circle().fill(mau.opacity(0.12)))
                .accessibilityHidden(true)
            Text(tieuDe).font(.ctw(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
            Text(moTa).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
            if boLoc {
                Button("Show all issues") { loc = nil }.buttonStyle(.bordered).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func moBang(slug: String, ma: String) {
        nganXep.duong.append(CTWRoute.bangTheoMa(slug: slug, ma: ma))
    }
}

// MARK: - Chuyển trạng thái nhanh (từ My Work)
//
// My Work không mang quy trình của dự án ⇒ tra id dự án, nạp cấu hình + thẻ (để có `statusId`/`typeId`/`version`),
// rồi CHỈ liệt kê bước chuyển hợp lệ (`trangThaiDich`) — cùng luật với Board/chi tiết thẻ. Máy chủ vẫn là nơi phán.

struct ChuyenNhanhCTW: View {
    let item: CTWMyWorkItem
    let xong: () -> Void

    @Environment(\.dismiss) private var dong
    @State private var pid: Int?
    @State private var cfg: CTWProjectConfig?
    @State private var the: CTWIssueDetail?
    @State private var loi: String?
    @State private var dangGui: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.key).font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.primary)
                        Text(item.title).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(3)
                    }
                    .padding(.vertical, 2)
                }
                if let loi {
                    Section { CTWErrorBanner(text: loi) }
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                if let cfg, let t = the {
                    let dich = cfg.trangThaiDich(loai: t.typeId, tu: t.statusId)
                    Section {
                        if !cfg.coTheChuyen {
                            Text("You can view this project but not move issues.").foregroundColor(AppColors.textSecondary)
                        } else if dich.filter({ $0.id != t.statusId }).isEmpty {
                            Text("No transitions available from this status.").foregroundColor(AppColors.textSecondary)
                        }
                        if cfg.coTheChuyen {
                            ForEach(dich) { s in
                                Button { Task { await chuyen(s, t) } } label: {
                                    HStack(spacing: 10) {
                                        CTWStatusGlyph(category: s.category, co: 14)
                                        Text(verbatim: CTWTen.trangThaiCau(s.name)).foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        if dangGui == s.id { ProgressView() }
                                        else if s.id == t.statusId {
                                            Text("Current").font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                                        }
                                    }
                                    .frame(minHeight: 36)
                                }
                                .disabled(s.id == t.statusId || dangGui != nil)
                            }
                        }
                    } header: { Text("Move to") }
                } else if loi == nil {
                    Section { ForEach(0..<3, id: \.self) { _ in HangGiuChoCTW() } }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Move issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
            .task { if the == nil { await tai() } }
        }
    }

    private func tai() async {
        guard let slug = item.workspace?.slug, let ma = item.project?.key else {
            loi = CTW.loi(APIError.unknown)
            return
        }
        do {
            let r: CTWResolve = try await APIClient.shared.request(.workTimDuAn(slug: slug, ma: ma))
            async let c: CTWProjectConfig = APIClient.shared.request(.workDuAn(pid: r.projectId))
            async let t: CTWIssueDetail = APIClient.shared.request(.workThe(pid: r.projectId, so: item.number))
            let (cc, tt) = try await (c, t)
            pid = r.projectId
            cfg = cc
            the = tt
            loi = nil
        } catch {
            loi = CTW.loi(error)
        }
    }

    private func chuyen(_ s: CTWStatus, _ t: CTWIssueDetail) async {
        guard let pid else { return }
        dangGui = s.id
        defer { dangGui = nil }
        var than: [String: Any] = ["statusId": s.id]
        if let v = t.version { than["version"] = v }
        do {
            try await APIClient.shared.send(.workChuyenThe(pid: pid, so: t.number, than: than))
            CTWRung.thanhCong()
            xong()
            dong()
        } catch {
            CTWRung.loi()
            loi = CTW.loi(error)
            if CTW.laXungDot(error) { await tai() }
        }
    }
}
