import SwiftUI

// MARK: - Tìm thẻ MỌI dự án — bộ lọc như web `globalsearch/SearchPage.tsx` + tìm gần đây (21/10/2026)
//
// `GET /work/search?q=&jql=&limit&offset` (chữ tự do đi `q` để máy chủ xếp theo độ khớp; bộ lọc dựng JQL như web
// `globalsearch/query.ts › basicToJql`: project · type · statusCategory · assignee) + "Updated" (`updated >= -7d`, app thêm
// theo yêu cầu chủ app). Giá trị bộ lọc lấy ở `GET /work/search/facets` (dự án, trạng thái, loại, người của mọi dự án).
// ⛔ JQL luôn mang TÊN GỐC ("To Do", "Bug") — chip hiển thị mới dịch (`CTWTen`).
// Tìm gần đây: 8 câu cuối, theo người dùng, chỉ trên máy (UserDefaults — đã khai CA92.1); xoá được.

extension CTWAPI {
    static func timToanCucLoc(q: String, jql: String, limit: Int = 30, offset: Int = 0) -> APIEndpoint {
        var p: [String: Any] = ["limit": limit]
        let t = q.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { p["q"] = String(t.prefix(200)) }
        if !jql.isEmpty { p["jql"] = String(jql.prefix(4000)) }
        if offset > 0 { p["offset"] = offset }
        return get("/search", p)
    }
    static var boLocTimToanCuc: APIEndpoint { CTWAPI.get("/search/facets") }
}

struct CTWTimFacets: Codable {
    struct DuAn: Codable, Hashable, Identifiable { var id: Int; var key: String; var name: String?; var archived: Bool? }
    struct TrangThai: Codable, Hashable { var name: String; var category: String? }
    struct Loai: Codable, Hashable { var key: String?; var name: String; var color: String? }
    var projects: [DuAn]?
    var statuses: [TrangThai]?
    var types: [Loai]?
    var assignees: [CTWUser]?
}

/// Bộ lọc tìm toàn cục (giữ ở My Work để quay lại không mất).
struct BoLocTimCTW: Equatable {
    var duAn: Set<String> = []
    var loai: Set<String> = []
    /// TODO · IN_PROGRESS · DONE
    var nhom: Set<String> = []
    /// "me" · "none" · username
    var nguoi: Set<String> = []
    /// Số ngày ("Updated in the last N days"); nil = bất kỳ.
    var capNhat: Int?

    var coLoc: Bool { !duAn.isEmpty || !loai.isEmpty || !nhom.isEmpty || !nguoi.isEmpty || capNhat != nil }

    static let tenNhom = ["TODO": "To Do", "IN_PROGRESS": "In Progress", "DONE": "Done"]

    /// JQL như web `basicToJql` (không gồm chữ — chữ đi `q`). Chưa có chữ ⇒ mới cập nhật lên đầu.
    func jql(coChu: Bool) -> String {
        var p: [String] = []
        func ds(_ f: String, _ xs: [String]) {
            guard !xs.isEmpty else { return }
            p.append(xs.count == 1 ? "\(f) = \(xs[0])" : "\(f) IN (\(xs.joined(separator: ", ")))")
        }
        ds("project", duAn.sorted().map(CTWJql.boc))
        ds("type", loai.sorted().map(CTWJql.boc))
        ds("statusCategory", ["TODO", "IN_PROGRESS", "DONE"].filter(nhom.contains).compactMap { Self.tenNhom[$0] }.map(CTWJql.boc))
        ds("assignee", nguoi.sorted().map { $0 == "me" ? "currentUser()" : ($0 == "none" ? "EMPTY" : CTWJql.boc($0)) })
        if let n = capNhat { p.append("updated >= -\(n)d") }
        let w = p.joined(separator: " AND ")
        return coChu ? w : CTWJql.voiThuTu(w, truong: "updated", giam: true)
    }
}

/// Tìm gần đây — theo user id, tối đa 8.
@MainActor
final class TimGanDayCTW: ObservableObject {
    static let shared = TimGanDayCTW()
    @Published private(set) var ds: [String] = []
    private var uid = ""
    private func khoa(_ u: String) -> String { "com.cuongthai.ctwork.timGanDay.\(u)" }

    func nap() {
        let u = AppState.shared.currentUser.map { String($0.id) } ?? "_"
        guard u != uid else { return }
        uid = u
        ds = UserDefaults.standard.stringArray(forKey: khoa(u)) ?? []
    }

    func them(_ q: String) {
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { return }
        nap()
        ds = Array(([t] + ds.filter { $0.caseInsensitiveCompare(t) != .orderedSame }).prefix(8))
        UserDefaults.standard.set(ds, forKey: khoa(uid))
    }

    func xoa(_ q: String? = nil) {
        nap()
        ds = q.map { x in ds.filter { $0 != x } } ?? []
        UserDefaults.standard.set(ds, forKey: khoa(uid))
    }
}

struct TimKiemNangCaoCTW: View {
    let q: String
    @Binding var loc: BoLocTimCTW
    let chonGanDay: (String) -> Void
    @ObservedObject private var ganDay = TimGanDayCTW.shared
    @State private var facets: CTWTimFacets?
    @State private var kq: CTWSearchResult?
    @State private var loi: String?
    @State private var dangTai = false

    private var chu: String { q.trimmingCharacters(in: .whitespaces) }
    private var coTim: Bool { chu.count >= 2 || loc.coLoc }

    var body: some View {
        List {
            Section {
                hangLoc
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
            }
            if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear) }
            if !coTim {
                Section {
                    if ganDay.ds.isEmpty {
                        Text("Type at least 2 characters, or pick a filter above.").font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary)
                    }
                    ForEach(ganDay.ds, id: \.self) { s in
                        Button { chonGanDay(s) } label: {
                            Label { Text(verbatim: s).foregroundColor(AppColors.textPrimary) } icon: { Image(systemName: "clock.arrow.circlepath").foregroundColor(AppColors.textTertiary) }
                        }
                        .swipeActions { Button(role: .destructive) { ganDay.xoa(s) } label: { Label("Remove", systemImage: "trash") } }
                    }
                } header: {
                    if !ganDay.ds.isEmpty {
                        HStack {
                            Text("Recent searches")
                            Spacer()
                            Button("Clear") { ganDay.xoa() }.font(.ctw(size: 13)).textCase(nil)
                        }
                    }
                }
            } else {
                Section {
                    if let kq, (kq.items ?? []).isEmpty {
                        (chu.isEmpty ? Text("No issues match these filters.") : Text("No issues match “\(chu)”."))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    ForEach(kq?.items ?? []) { i in hang(i) }
                } header: {
                    if let n = kq?.total { n == 1 ? Text("1 issue") : Text("\(n) issues") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundPrimary)
        .overlay { if coTim && kq == nil && loi == nil { ProgressView() } }
        .onAppear { ganDay.nap() }
        .task { if facets == nil { facets = try? await APIClient.shared.request(CTWAPI.boLocTimToanCuc) } }
        .task(id: "\(chu)|\(loc.jql(coChu: !chu.isEmpty))") {
            guard coTim else { kq = nil; return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                kq = try await APIClient.shared.request(CTWAPI.timToanCucLoc(q: chu.count >= 2 ? chu : "", jql: loc.jql(coChu: chu.count >= 2)))
                loi = nil
            } catch {
                if !Task.isCancelled { loi = CTW.loi(error) }
            }
        }
    }

    // MARK: Hàng bộ lọc

    private var hangLoc: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                menuDuAn
                menuLoai
                menuNhom
                menuNguoi
                menuCapNhat
                if loc.coLoc {
                    Button { loc = BoLocTimCTW() } label: {
                        Text("Clear all").font(.ctw(size: 13, weight: .semibold)).foregroundColor(AppColors.primary).fixedSize()
                            .padding(.horizontal, 6).frame(minHeight: 36)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func chip(_ ten: Text, _ bieuTuong: String, so: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: bieuTuong).font(.ctw(size: 12, weight: .semibold))
            ten.font(.ctw(size: 13, weight: .medium)).fixedSize()
            if so > 0 {
                Text("\(so)").font(.ctw(size: 11, weight: .bold).monospacedDigit()).foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, 5).background(Capsule().fill(AppColors.primary))
            }
            Image(systemName: "chevron.down").font(.ctw(size: 9, weight: .bold)).opacity(0.6)
        }
        .foregroundColor(so > 0 ? AppColors.primary : AppColors.textPrimary)
        .padding(.horizontal, 11).frame(minHeight: 36)
        .background(Capsule().fill(so > 0 ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard))
        .overlay(Capsule().strokeBorder(so > 0 ? AppColors.primary.opacity(0.35) : AppColors.border, lineWidth: 0.5))
    }

    private func bat(_ s: WritableKeyPath<BoLocTimCTW, Set<String>>, _ v: String) -> Binding<Bool> {
        Binding(get: { loc[keyPath: s].contains(v) }, set: { if $0 { loc[keyPath: s].insert(v) } else { loc[keyPath: s].remove(v) } })
    }

    private var menuDuAn: some View {
        Menu {
            ForEach(facets?.projects ?? []) { p in
                Toggle(isOn: bat(\.duAn, p.key)) { Text(verbatim: "\(p.key) · \(p.name ?? "")") }
            }
        } label: { chip(Text("Project"), "folder", so: loc.duAn.count) }
        .accessibilityIdentifier("search.project")
    }

    private var menuLoai: some View {
        Menu {
            ForEach(facets?.types ?? [], id: \.name) { t in
                Toggle(isOn: bat(\.loai, t.name)) { Label(CTWTen.loai(t.name), systemImage: CTW.bieuTuongLoai(key: t.key)) }
            }
        } label: { chip(Text("Type"), "square.stack", so: loc.loai.count) }
    }

    private var menuNhom: some View {
        Menu {
            Toggle(isOn: bat(\.nhom, "TODO")) { Label(CTWTen.trangThai("To Do"), systemImage: "circle") }
            Toggle(isOn: bat(\.nhom, "IN_PROGRESS")) { Label(CTWTen.trangThai("In Progress"), systemImage: "circle.lefthalf.filled") }
            Toggle(isOn: bat(\.nhom, "DONE")) { Label(CTWTen.trangThai("Done"), systemImage: "checkmark.circle.fill") }
        } label: { chip(Text("Status"), "circle.dashed", so: loc.nhom.count) }
    }

    private var menuNguoi: some View {
        Menu {
            Toggle(isOn: bat(\.nguoi, "me")) { Text("Me") }
            Toggle(isOn: bat(\.nguoi, "none")) { Text("Unassigned") }
            ForEach((facets?.assignees ?? []).filter { $0.id != AppState.shared.currentUser?.id && $0.username != nil }) { u in
                Toggle(isOn: bat(\.nguoi, u.username ?? "")) {
                    if u.laAgent { Text("\(u.ten) · AI agent") } else { Text(verbatim: u.ten) }
                }
            }
        } label: { chip(Text("Assignee"), "person", so: loc.nguoi.count) }
    }

    private var menuCapNhat: some View {
        Menu {
            Picker(selection: $loc.capNhat) {
                Text("Any time").tag(Int?.none)
                Text("Last 24 hours").tag(Int?.some(1))
                Text("Last 7 days").tag(Int?.some(7))
                Text("Last 30 days").tag(Int?.some(30))
            } label: { Text("Updated") }
        } label: { chip(Text("Updated"), "clock", so: loc.capNhat == nil ? 0 : 1) }
    }

    // MARK: Hàng kết quả

    @ViewBuilder
    private func hang(_ i: CTWSearchItem) -> some View {
        if let slug = i.workspace?.slug, let ma = i.project?.key {
            NavigationLink(value: CTWRoute.theTheoMa(slug: slug, ma: ma, so: i.number)) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: CTW.bieuTuongLoai(key: i.type?.key))
                        .font(.ctw(size: 10, weight: .bold)).foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(CTW.mau(i.type?.color, macDinh: AppColors.info)))
                        .accessibilityLabel(Text(verbatim: CTWTen.loai(i.type?.name ?? "")))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(i.title).font(.ctw(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                        FlowNgangCTW(spacing: 7) {
                            Text(verbatim: i.key ?? "").font(.ctw(size: 12, weight: .semibold).monospaced()).foregroundColor(AppColors.textSecondary)
                            if let s = i.status?.name { CTWStatusChip(ten: s, category: i.status?.category).fixedSize() }
                            CTWPriorityIcon(priority: i.priority)
                            CTWDueChip(dueDate: i.dueDate)
                            if let a = i.assignee { CTWAvatar(user: a, size: 18) }
                            Text(verbatim: i.project?.name ?? "").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            .simultaneousGesture(TapGesture().onEnded { if chu.count >= 2 { ganDay.them(chu) } })
        }
    }
}
