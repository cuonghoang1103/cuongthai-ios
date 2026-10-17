import SwiftUI

// MARK: - Cuộc họp — DANH SÁCH + LỊCH
//
// `GET /projects/:pid/meetings?scope=upcoming|past` ⇒ `{items, canEdit}`. Dải lịch 2 tuần
// (chấm = ngày có họp; chạm ⇒ lọc theo ngày), nhóm theo ngày, nút "Join" nổi khi
// cuộc họp sắp/đang diễn ra. Tạo cuộc họp (canEdit). Deep link `/meetings/<n>`.

struct RouteHopCTW: Hashable {
    var pid: Int
    var so: Int
    var tieuDe: String
}

struct CuocHopCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var pham = "upcoming"
    @State private var ds: CTWMeetingList?
    @State private var loi: String?
    @State private var ngayChon: Date?
    @State private var moTao = false
    @Environment(\.openURL) private var moUrl

    private var hien: [CTWMeeting] {
        let a = ds?.items ?? []
        guard let ngayChon else { return a }
        return a.filter { $0.batDau.map { Calendar.current.isDate($0, inSameDayAs: ngayChon) } ?? false }
    }

    var body: some View {
        List {
            if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            Section {
                Picker("Show", selection: $pham) {
                    Text("Upcoming").tag("upcoming")
                    Text("Past").tag("past")
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                if pham == "upcoming" {
                    DaiLichHopCTW(ds: ds?.items ?? [], chon: $ngayChon)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            if ds != nil && hien.isEmpty {
                CTWOTrong(bieuTuong: "calendar", tieuDe: ngayChon != nil ? "No meetings that day" : (pham == "upcoming" ? "No upcoming meetings" : "No past meetings"),
                          moTa: ds?.canEdit == true ? "Schedule a meeting and invite your team." : "Meetings your team schedules appear here.",
                          nut: ds?.canEdit == true && pham == "upcoming" ? "New meeting" : nil) { moTao = true }
                    .listRowBackground(Color.clear)
            }
            ForEach(nhomTheoNgay, id: \.0) { n in
                Section {
                    ForEach(n.1) { m in
                        NavigationLink(value: RouteHopCTW(pid: nguCanh.pid, so: m.number, tieuDe: m.title)) {
                            HangHopCTW(hop: m) { u in vao(m, u) }
                        }
                    }
                } header: { Text(n.0) }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if ds == nil && loi == nil { CTWKhungTai(soHang: 4) } }
        .refreshable { await tai() }
        .navigationTitle("Meetings")
        .toolbar {
            if ds?.canEdit == true {
                ToolbarItem(placement: .primaryAction) {
                    Button { moTao = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New meeting")
                }
            }
        }
        .sheet(isPresented: $moTao) {
            SoanHopCTW(pid: nguCanh.pid, hop: nil) { m in
                Task {
                    await tai()
                    nganXep.duong.append(RouteHopCTW(pid: nguCanh.pid, so: m.number, tieuDe: m.title))
                }
            }
            .environmentObject(app)
        }
        .onChange(of: pham) { _, _ in ngayChon = nil; Task { await tai() } }
        .task {
            if ds == nil { await tai() }
            #if DEBUG
            if XemThuCTW.manGT == "taohop" { moTao = true }
            #endif
        }
        .task(id: app.dichCho) { await moDich() }
    }

    private var nhomTheoNgay: [(String, [CTWMeeting])] {
        var ra: [(String, [CTWMeeting])] = []
        for m in hien {
            let k = m.batDau.map { CTWChatThoiGian.nhanNgay($0) } ?? "No date"
            if let i = ra.firstIndex(where: { $0.0 == k }) { ra[i].1.append(m) } else { ra.append((k, [m])) }
        }
        return ra
    }

    private func tai() async {
        do {
            ds = try await APIClient.shared.request(CTWAPI.dsHop(pid: nguCanh.pid, pham: pham))
            loi = nil
        } catch {
            if case APIError.coMa(let ma, _) = error, ma == "MODULE_DISABLED" { loi = "Meetings are turned off for this project." } else { loi = CTW.loi(error) }
        }
    }

    private func vao(_ m: CTWMeeting, _ u: URL) {
        Task { _ = try? await APIClient.shared.send(CTWAPI.vaoHop(pid: nguCanh.pid, so: m.number)) }
        moUrl(u)
    }

    /// Đích `/work/<ws>/<KEY>/meetings/<n>`.
    private func moDich() async {
        guard let d = app.dichCho, d.moDun == "meetings", d.pid == nil || d.pid == nguCanh.pid else { return }
        defer { app.dichCho = nil }
        guard let so = d.duongDan.phanCon.first.flatMap(Int.init) else { return }
        var p = NavigationPath()
        p.append(RouteHopCTW(pid: nguCanh.pid, so: so, tieuDe: "M-\(so)"))
        nganXep.duong = p
    }
}

// MARK: - Một dòng cuộc họp

struct HangHopCTW: View {
    let hop: CTWMeeting
    var vao: ((URL) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(gio(hop.batDau)).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
                Text(gio(hop.ketThuc)).font(.system(size: 11).monospacedDigit()).foregroundColor(AppColors.textTertiary)
            }
            .frame(width: 48)
            RoundedRectangle(cornerRadius: 2).fill(mauLoaiHopCTW(hop.type)).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(hop.title).font(.system(size: 15, weight: .semibold)).foregroundColor(hop.daHuy ? AppColors.textTertiary : AppColors.textPrimary)
                        .strikethrough(hop.daHuy).lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text(hop.typeLabel ?? "Meeting").font(.system(size: 11, weight: .semibold)).foregroundColor(mauLoaiHopCTW(hop.type))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(mauLoaiHopCTW(hop.type).opacity(0.12)))
                        .fixedSize()
                    if hop.daHuy { Text("Cancelled").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.error) }
                    if hop.urlHop != nil {
                        Label(hop.tenNhaCungCap, systemImage: "video.fill").font(.system(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    } else if let l = hop.location, !l.isEmpty {
                        Label(l, systemImage: "mappin.and.ellipse").font(.system(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                    }
                }
                HStack(spacing: 8) {
                    ChongAvatarCTW(ds: (hop.attendees ?? []).map(\.nguoi))
                    if let n = hop.actionsOpen, n > 0 {
                        Label("\(n) open", systemImage: "checklist").font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                            .lineLimit(1).fixedSize()
                    }
                }
            }
            Spacer(minLength: 0)
            if hop.sapHoacDangHop, let u = hop.urlHop, let vao {
                Button { vao(u) } label: {
                    Text("Join").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7).background(Capsule().fill(AppColors.success))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Join \(hop.title)")
            }
        }
        .padding(.vertical, 4)
    }

    private func gio(_ d: Date?) -> String {
        guard let d else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

func mauLoaiHopCTW(_ t: String?) -> Color {
    switch t {
    case "DAILY": return AppColors.secondary
    case "PLANNING", "KICKOFF": return AppColors.primary
    case "DEMO": return AppColors.success
    case "RETRO": return AppColors.accent
    case "CLIENT", "STEERING": return AppColors.brandPink
    case "MENTOR", "ELICITATION": return AppColors.warning
    default: return AppColors.textSecondary
    }
}

/// Chồng avatar (tối đa 5 + số còn lại).
struct ChongAvatarCTW: View {
    let ds: [CTWUser]
    var co: CGFloat = 22
    var body: some View {
        HStack(spacing: -6) {
            ForEach(ds.prefix(5)) { u in
                CTWAvatar(user: u, size: co).overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1.5))
            }
            if ds.count > 5 {
                Text("+\(ds.count - 5)").font(.system(size: 10, weight: .bold)).foregroundColor(AppColors.textSecondary)
                    .frame(width: co, height: co).background(Circle().fill(AppColors.backgroundTertiary))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ds.count) attendee\(ds.count == 1 ? "" : "s")")
    }
}

// MARK: - Dải lịch 2 tuần

struct DaiLichHopCTW: View {
    let ds: [CTWMeeting]
    @Binding var chon: Date?

    private var ngay: [Date] {
        let hom = Calendar.current.startOfDay(for: Date())
        return (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: hom) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ngay, id: \.self) { d in
                    let so = ds.filter { $0.batDau.map { Calendar.current.isDate($0, inSameDayAs: d) } ?? false }.count
                    let dangChon = chon.map { Calendar.current.isDate($0, inSameDayAs: d) } ?? false
                    Button {
                        CTWRung.chon()
                        chon = dangChon ? nil : d
                    } label: {
                        VStack(spacing: 4) {
                            Text(thu(d)).font(.system(size: 11, weight: .medium)).foregroundColor(dangChon ? .white : AppColors.textSecondary)
                            Text(ngaySo(d)).font(.system(size: 17, weight: .bold).monospacedDigit())
                                .foregroundColor(dangChon ? .white : (Calendar.current.isDateInToday(d) ? AppColors.primary : AppColors.textPrimary))
                            HStack(spacing: 2) {
                                ForEach(0..<min(so, 3), id: \.self) { _ in
                                    Circle().fill(dangChon ? .white : AppColors.primary).frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .frame(width: 46, height: 64)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(dangChon ? AppColors.primary : AppColors.backgroundCard))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(CTWChatThoiGian.nhanNgay(d)), \(so) meeting\(so == 1 ? "" : "s")")
                    .accessibilityAddTraits(dangChon ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func thu(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEE"
        return f.string(from: d)
    }
    private func ngaySo(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: d)
    }
}
