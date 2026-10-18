import SwiftUI
import EventKit
import EventKitUI

// MARK: - Chi tiết một cuộc họp
//
// Gộp `GET /meetings/:n` (chương trình, biên bản, quyết định, việc, người dự) và
// `GET /meetings/:n/room` (RSVP, điểm danh, chương trình có cấu trúc, bản nháp AI).
// Vào họp: `POST /join` (điểm danh tự động) rồi mở link Meet/Zoom/Teams/Jitsi bằng hệ
// thống (Universal Link ⇒ app của họ nếu đã cài). Thêm vào Lịch: EventKitUI chạy
// ngoài tiến trình (iOS 17) ⇒ KHÔNG cần quyền Lịch.
// Biên bản là nội dung người dùng (1.2): Báo cáo + ẩn + chặn người tổ chức. Bản nháp
// biên bản do AI đề xuất luôn gắn nhãn AI (4.7).

@MainActor
final class HopVM: ObservableObject {
    let pid: Int
    let so: Int
    @Published var hop: CTWMeeting?
    @Published var phong: CTWMeetingRoom?
    @Published var loi: String?
    @Published var dangLam = false
    /// Biên bản dạng JSON THÔ (giữ nguyên định dạng web khi app nối thêm ghi chú).
    private var bienBanTho: [String: Any]?

    init(pid: Int, so: Int) { self.pid = pid; self.so = so }

    func tai() async {
        do {
            let d = try await APIClient.shared.requestRaw(CTWAPI.motHop(pid: pid, so: so))
            let goi = try JSONDecoder().decode(APIResponse<CTWMeeting>.self, from: d)
            hop = goi.data
            if let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let du = o["data"] as? [String: Any] {
                bienBanTho = du["minutesJson"] as? [String: Any]
            }
            loi = nil
        } catch { loi = CTW.loi(error) }
        phong = try? await APIClient.shared.request(CTWAPI.phongHop(pid: pid, so: so))
    }

    /// PATCH kèm `version`; 409 ⇒ nạp lại và báo.
    func sua(_ than: [String: Any]) async -> Bool {
        var b = than
        if let v = hop?.version { b["version"] = v }
        dangLam = true
        defer { dangLam = false }
        do {
            try await APIClient.shared.send(CTWAPI.suaHop(pid: pid, so: so, b))
            await tai()
            CTWRung.thanhCong()
            return true
        } catch {
            if CTW.laXungDot(error) {
                await tai()
                loi = "Someone else just changed this meeting — we loaded their version. Please try again."
            } else { loi = CTW.loi(error) }
            CTWRung.loi()
            return false
        }
    }

    /// Nối ghi chú vào CUỐI biên bản (giữ nguyên định dạng có sẵn).
    func noiBienBan(_ chu: String) async -> Bool {
        let moi = (CTWNode.docTuChu(chu)["content"] as? [[String: Any]]) ?? []
        var doc = bienBanTho ?? ["type": "doc", "content": [[String: Any]]()]
        var nd = (doc["content"] as? [Any]) ?? []
        nd.append(contentsOf: moi as [Any])
        doc["content"] = nd
        return await sua(["minutesJson": doc])
    }

    func traLoiMoi(_ r: String) async {
        do {
            phong = try await APIClient.shared.request(CTWAPI.traLoiMoi(pid: pid, so: so, rsvp: r))
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error) }
    }

    func vao() async {
        _ = try? await APIClient.shared.send(CTWAPI.vaoHop(pid: pid, so: so))
        phong = try? await APIClient.shared.request(CTWAPI.phongHop(pid: pid, so: so))
    }

    func luuViec(_ ds: [CTWHopViec]) async -> Bool {
        let items: [[String: Any]] = ds.map { v in
            var o: [String: Any] = ["text": v.text]
            if v.id > 0 { o["id"] = v.id }
            o["assigneeId"] = v.assignee?.id ?? NSNull()
            o["dueDate"] = v.dueDate ?? NSNull()
            return o
        }
        do {
            hop = try await APIClient.shared.request(CTWAPI.viecHop(pid: pid, so: so, items))
            CTWRung.thanhCong()
            return true
        } catch { loi = CTW.loi(error); return false }
    }

    func taoThe(_ ids: [Int]) async -> String? {
        do {
            let kq: CTWHopTaoTheKQ = try await APIClient.shared.request(CTWAPI.theTuViecHop(pid: pid, so: so, ids: ids))
            if let m = kq.meeting { hop = m } else { await tai() }
            CTWRung.thanhCong()
            let k = (kq.created ?? []).compactMap(\.key)
            return k.isEmpty ? "No new issues — every action item already has one." : "Created \(k.joined(separator: ", "))."
        } catch { loi = CTW.loi(error); return nil }
    }

    func moiNguoi(_ ids: [Int]) async {
        do {
            hop = try await APIClient.shared.request(CTWAPI.nguoiHop(pid: pid, so: so, ids: ids))
            phong = try? await APIClient.shared.request(CTWAPI.phongHop(pid: pid, so: so))
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error) }
    }

    func xoa() async -> Bool {
        do { try await APIClient.shared.send(CTWAPI.xoaHop(pid: pid, so: so)); return true } catch { loi = CTW.loi(error); return false }
    }

    func nhanBan() async -> CTWMeeting? {
        do { return try await APIClient.shared.request(CTWAPI.nhanBanHop(pid: pid, so: so)) } catch { loi = CTW.loi(error); return nil }
    }

    func banNhap(_ d: CTWHopBanNhapAI, ap: Bool) async {
        do {
            try await APIClient.shared.send(ap ? CTWAPI.apBanNhapAI(pid: pid, so: so, did: d.id) : CTWAPI.boBanNhapAI(pid: pid, so: so, did: d.id))
            await tai()
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error) }
    }
}

private enum TamPhuHopCTW: Identifiable {
    case sua, ghiChu, viec(CTWHopViec?), moi, lich, banGhiLoi
    var id: String {
        switch self {
        case .sua: return "sua"
        case .ghiChu: return "ghi"
        case .viec(let v): return "v\(v?.id ?? 0)"
        case .moi: return "moi"
        case .lich: return "lich"
        case .banGhiLoi: return "loi"
        }
    }
}

struct ChiTietHopCTW: View {
    let pid: Int
    let so: Int
    @StateObject private var vm: HopVM
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @ObservedObject private var kd = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungHopCTW.shared
    @State private var tamPhu: TamPhuHopCTW?
    @State private var thongBao: String?
    @State private var hoiXoa = false
    @State private var hoiHuy = false
    @State private var baoCao = false
    @State private var hoiChan = false
    @State private var themQuyetDinh = false
    @State private var chuQuyetDinh = ""
    @State private var chonViec: Set<Int> = []
    @State private var chonMoi: Set<Int> = []
    @Environment(\.openURL) private var moUrl
    @Environment(\.dismiss) private var dong

    init(pid: Int, so: Int) {
        self.pid = pid
        self.so = so
        _vm = StateObject(wrappedValue: HopVM(pid: pid, so: so))
    }

    private var suaDuoc: Bool { vm.hop?.canEdit == true }
    private var daAn: Bool { an.daAn(pid: pid, so: so) || (vm.hop?.organizer.map { kd.blockedUserIds.contains($0.id) } ?? false) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let loi = vm.loi { CTWErrorBanner(text: loi) { vm.loi = nil } }
                if let h = vm.hop {
                    dau(h)
                    vaoHop(h)
                    if let me = vm.phong?.me, me.invited == true, !h.daHuy { rsvp(me) }
                    if daAn {
                        CTWOTrong(bieuTuong: "eye.slash", tieuDe: "Notes hidden", moTa: "You reported this meeting's notes or blocked its organizer, so its notes are hidden for you.")
                    } else {
                        chuongTrinh(h)
                        bienBan(h)
                        banNhapAI
                        quyetDinh(h)
                    }
                    viec(h)
                    nguoiDu(h)
                    lienQuan(h)
                } else if vm.loi == nil {
                    CTWKhungTai(soHang: 5)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.hop?.key ?? "M-\(so)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { thanhCongCu }
        .refreshable { await vm.tai() }
        .task { if vm.hop == nil { await vm.tai() } }
        .sheet(item: $tamPhu) { t in tamPhuView(t) }
        .alert(thongBao ?? "", isPresented: Binding(get: { thongBao != nil }, set: { if !$0 { thongBao = nil } })) { Button("OK", role: .cancel) {} }
        .alert("Add a decision", isPresented: $themQuyetDinh) {
            TextField("What was decided?", text: $chuQuyetDinh)
            Button("Add") {
                let s = chuQuyetDinh.trimmingCharacters(in: .whitespacesAndNewlines)
                chuQuyetDinh = ""
                guard !s.isEmpty else { return }
                Task { _ = await vm.sua(["decisions": (vm.hop?.decisions ?? []) + [s]]) }
            }
            Button("Cancel", role: .cancel) { chuQuyetDinh = "" }
        }
        .confirmationDialog("Delete this meeting?", isPresented: $hoiXoa, titleVisibility: .visible) {
            Button("Delete meeting", role: .destructive) { Task { if await vm.xoa() { nganXep.duong.removeLast(min(1, nganXep.duong.count)) } } }
        } message: { Text("Its notes, decisions and action items are removed. Issues already created stay.") }
        .confirmationDialog("Cancel this meeting?", isPresented: $hoiHuy, titleVisibility: .visible) {
            Button("Cancel meeting", role: .destructive) { Task { _ = await vm.sua(["status": "CANCELLED"]) } }
            Button("Keep it", role: .cancel) {}
        } message: { Text("Attendees' calendars are updated with the cancellation.") }
        .confirmationDialog("Report this meeting's notes", isPresented: $baoCao, titleVisibility: .visible) {
            ForEach(CTWBaoCao.lyDo, id: \.ma) { l in
                Button(l.nhan, role: .destructive) { Task { await guiBaoCao(l.ma) } }
            }
        } message: { Text("Reported notes are hidden for you right away.") }
        .confirmationDialog("Block \(vm.hop?.organizer?.ten ?? "the organizer")?", isPresented: $hoiChan, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                guard let u = vm.hop?.organizer else { return }
                Task { do { try await kd.block(userId: u.id) } catch { vm.loi = CTW.loi(error) } }
            }
        } message: { Text("You won't see their messages, comments or meeting notes anymore.") }
    }

    // MARK: Đầu trang

    private func dau(_ h: CTWMeeting) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(h.typeLabel ?? "Meeting").font(.system(size: 12, weight: .semibold)).foregroundColor(mauLoaiHopCTW(h.type))
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(mauLoaiHopCTW(h.type).opacity(0.12)))
                ChipTrangThaiHopCTW(trangThai: h.status)
                if h.seriesId != nil { Label("Recurring", systemImage: "repeat").font(.system(size: 11)).foregroundColor(AppColors.textSecondary) }
                if h.hasClients == true { Label("Client", systemImage: "person.2").font(.system(size: 11)).foregroundColor(AppColors.textSecondary) }
            }
            Text(h.title).font(.system(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
                .strikethrough(h.daHuy)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Label(khoangGio(h), systemImage: "clock").foregroundColor(AppColors.textPrimary)
                if let l = h.location, !l.isEmpty { Label(l, systemImage: "mappin.and.ellipse").foregroundColor(AppColors.textPrimary) }
                if let s = h.series?.summary { Label(s, systemImage: "repeat").foregroundColor(AppColors.textSecondary) }
                if let o = h.organizer {
                    HStack(spacing: 6) {
                        CTWAvatar(user: o, size: 20)
                        Text("Organized by \(o.ten)").foregroundColor(AppColors.textSecondary)
                        if o.laAgent { CTWNhanAI() }
                    }
                }
            }
            .font(.system(size: 14))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ctwThe()
    }

    private func khoangGio(_ h: CTWMeeting) -> String {
        guard let b = h.batDau else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d · HH:mm"
        let g = DateFormatter()
        g.dateFormat = "HH:mm"
        var s = f.string(from: b)
        if let k = h.ketThuc { s += "–" + g.string(from: k) }
        if let tz = h.timezone, tz != TimeZone.current.identifier { s += " (your time)" }
        return s
    }

    // MARK: Vào họp

    @ViewBuilder
    private func vaoHop(_ h: CTWMeeting) -> some View {
        if let u = h.urlHop, !h.daHuy {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Task { await vm.vao() }
                    moUrl(u)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "video.fill")
                        Text("Join with \(h.tenNhaCungCap)").fontWeight(.semibold)
                        Spacer()
                        if h.sapHoacDangHop { Text(h.batDau.map { $0 > Date() ? "Starting soon" : "Now" } ?? "").font(.system(size: 12, weight: .bold)) }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(h.sapHoacDangHop ? AppColors.success : AppColors.primary))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the meeting in \(h.tenNhaCungCap) and marks you present")
                HStack(spacing: 16) {
                    Button { CTW.chepVaoBoNho(u.absoluteString); thongBao = "Meeting link copied." } label: { Label("Copy link", systemImage: "link") }
                    ShareLink(item: u, subject: Text(h.title)) { Label("Share", systemImage: "square.and.arrow.up") }
                    Button { tamPhu = .lich } label: { Label("Add to Calendar", systemImage: "calendar.badge.plus") }
                }
                .font(.system(size: 13, weight: .medium))
            }
        } else if !h.daHuy {
            HStack(spacing: 12) {
                Image(systemName: "video.slash").foregroundColor(AppColors.textTertiary)
                Text("No video link").font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                Spacer()
                if suaDuoc {
                    Button("Add video room") { Task { _ = await vm.sua(["meetingUrl": "jitsi"]) } }
                        .font(.system(size: 13, weight: .semibold))
                }
                Button { tamPhu = .lich } label: { Image(systemName: "calendar.badge.plus") }
                    .accessibilityLabel("Add to Calendar")
            }
            .padding(14)
            .ctwThe()
        }
    }

    private func rsvp(_ me: CTWHopToi) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Going?").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            HStack(spacing: 8) {
                ForEach([("YES", "Yes", "checkmark"), ("MAYBE", "Maybe", "questionmark"), ("NO", "No", "xmark")], id: \.0) { r in
                    let chon = me.rsvp == r.0
                    Button { Task { await vm.traLoiMoi(r.0) } } label: {
                        Label(r.1, systemImage: r.2).font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .foregroundColor(chon ? .white : AppColors.textPrimary)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(chon ? AppColors.primary : AppColors.backgroundCard))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chon ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Nội dung

    @ViewBuilder
    private func chuongTrinh(_ h: CTWMeeting) -> some View {
        let ds = vm.phong?.agenda ?? []
        if !ds.isEmpty || h.agendaJson?.content?.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                CTWSectionHeader("list.number", "Agenda", count: vm.phong?.agendaMinutes.map { "\($0) min" })
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(ds.enumerated()), id: \.element.id) { i, a in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)").font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundColor(AppColors.primary)
                                .frame(width: 22, height: 22).background(Circle().fill(AppColors.primary.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.title).font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                                let nguoi = a.presenterId.flatMap { id in h.attendees?.first { $0.id == id }?.nguoi.ten }
                                if nguoi != nil || a.minutes != nil {
                                    Text([nguoi, a.minutes.map { "\($0) min" }].compactMap { $0 }.joined(separator: " · "))
                                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    if ds.isEmpty { CTWTipTapView(doc: h.agendaJson, coChu: 14) }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ctwThe()
            }
        }
    }

    private func bienBan(_ h: CTWMeeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("doc.text", "Notes", trailing: suaDuoc ? AnyView(
                Button { tamPhu = .ghiChu } label: { Label("Add", systemImage: "plus.circle.fill").labelStyle(.iconOnly).font(.system(size: 20)) }
                    .frame(width: 44, height: 32)
                    .accessibilityLabel("Add to notes")) : nil)
            Group {
                if h.minutesJson?.content?.isEmpty == false {
                    CTWTipTapView(doc: h.minutesJson, coChu: 14)
                } else {
                    Text(suaDuoc ? "No notes yet. Tap + to write the minutes." : "No notes yet.")
                        .font(.system(size: 13)).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ctwThe()
        }
    }

    @ViewBuilder private var banNhapAI: some View {
        let ds = (vm.phong?.drafts ?? []).filter { $0.status == "PROPOSED" }
        if let d = ds.first, let c = d.content {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    CTWSectionHeader("sparkles", "Proposed minutes")
                    CTWNhanAI(chu: "AI-generated")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Drafted by AI from the meeting transcript. Check it before applying — it can be wrong.")
                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    if let s = c.summary, !s.isEmpty { Text(s).font(.system(size: 14)).foregroundColor(AppColors.textPrimary) }
                    nhomDeXuat("Decisions", c.decisions ?? [])
                    nhomDeXuat("Action items", c.actions ?? [])
                    nhomDeXuat("Open questions", c.openIssues ?? [])
                    if vm.phong?.can?.edit == true {
                        HStack {
                            Button { Task { await vm.banNhap(d, ap: true) } } label: { Text("Apply to notes").fontWeight(.semibold) }
                                .buttonStyle(.borderedProminent)
                            Button("Dismiss") { Task { await vm.banNhap(d, ap: false) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.primary.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func nhomDeXuat(_ ten: String, _ ds: [CTWHopDeXuat]) -> some View {
        if !ds.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(ten).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                ForEach(Array(ds.enumerated()), id: \.offset) { _, x in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(AppColors.textTertiary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(x.text ?? "").font(.system(size: 13)).foregroundColor(AppColors.textPrimary)
                            let phu = [x.ownerName, x.due, x.unsupported == true ? "Not found in transcript" : nil].compactMap { $0 }
                            if !phu.isEmpty {
                                Text(phu.joined(separator: " · ")).font(.system(size: 11))
                                    .foregroundColor(x.unsupported == true ? AppColors.warning : AppColors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func quyetDinh(_ h: CTWMeeting) -> some View {
        let ds = h.decisions ?? []
        if !ds.isEmpty || suaDuoc {
            VStack(alignment: .leading, spacing: 8) {
                CTWSectionHeader("checkmark.seal", "Decisions", count: ds.isEmpty ? nil : "\(ds.count)", trailing: suaDuoc ? AnyView(
                    Button { themQuyetDinh = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)) }
                        .frame(width: 44, height: 32).accessibilityLabel("Add decision")) : nil)
                VStack(alignment: .leading, spacing: 0) {
                    if ds.isEmpty {
                        Text("No decisions recorded.").font(.system(size: 13)).foregroundColor(AppColors.textTertiary).padding(.vertical, 6)
                    }
                    ForEach(Array(ds.enumerated()), id: \.offset) { i, d in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success).font(.system(size: 14))
                            Text(d).font(.system(size: 14)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .contextMenu {
                            Button { CTW.chepVaoBoNho(d) } label: { Label("Copy", systemImage: "doc.on.doc") }
                            if suaDuoc {
                                Button(role: .destructive) {
                                    var a = ds; a.remove(at: i)
                                    Task { _ = await vm.sua(["decisions": a]) }
                                } label: { Label("Remove", systemImage: "trash") }
                            }
                        }
                        if i < ds.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .ctwThe()
            }
        }
    }

    private func viec(_ h: CTWMeeting) -> some View {
        let ds = h.actions ?? []
        let mo = ds.filter { $0.issue == nil }
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("checklist", "Action items", count: ds.isEmpty ? nil : "\(ds.count)", trailing: suaDuoc ? AnyView(
                Button { tamPhu = .viec(nil) } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)) }
                    .frame(width: 44, height: 32).accessibilityLabel("Add action item")) : nil)
            VStack(alignment: .leading, spacing: 0) {
                if ds.isEmpty {
                    Text("No action items.").font(.system(size: 13)).foregroundColor(AppColors.textTertiary).padding(.vertical, 8)
                }
                ForEach(ds) { v in
                    HangViecHopCTW(viec: v, chon: chonViec.contains(v.id), choChon: h.canCreateIssues == true && v.issue == nil) {
                        if chonViec.contains(v.id) { chonViec.remove(v.id) } else { chonViec.insert(v.id) }
                    } moThe: { k in
                        if let so = k.number { nganXep.duong.append(CTWRoute.the(pid: pid, so: so)) }
                    }
                    .contextMenu {
                        if suaDuoc {
                            Button { tamPhu = .viec(v) } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) {
                                Task { _ = await vm.luuViec(ds.filter { $0.id != v.id }) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    if v.id != ds.last?.id { Divider() }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .ctwThe()
            if h.canCreateIssues == true && !mo.isEmpty {
                Button {
                    let ids = chonViec.isEmpty ? mo.map(\.id) : Array(chonViec)
                    Task {
                        if let s = await vm.taoThe(ids) { thongBao = s }
                        chonViec = []
                    }
                } label: {
                    Label(chonViec.isEmpty ? "Create issues for \(mo.count) open item\(mo.count == 1 ? "" : "s")" : "Create \(chonViec.count) issue\(chonViec.count == 1 ? "" : "s")",
                          systemImage: "checkmark.square.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 42)
                }
                .buttonStyle(.bordered)
                .disabled(vm.dangLam)
            }
        }
    }

    private func nguoiDu(_ h: CTWMeeting) -> some View {
        let phong = vm.phong?.attendees ?? []
        let ds = h.attendees ?? []
        return VStack(alignment: .leading, spacing: 8) {
            CTWSectionHeader("person.2", "Attendees", count: "\(ds.count)", trailing: suaDuoc ? AnyView(
                Button { chonMoi = Set(ds.map(\.id)); tamPhu = .moi } label: { Image(systemName: "person.badge.plus").font(.system(size: 17)) }
                    .frame(width: 44, height: 32).accessibilityLabel("Invite people")) : nil)
            VStack(spacing: 0) {
                ForEach(ds) { a in
                    let p = phong.first { $0.userId == a.id }
                    HStack(spacing: 10) {
                        CTWAvatar(user: a.nguoi, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text(a.nguoi.ten).font(.system(size: 14)).foregroundColor(AppColors.textPrimary)
                                if a.nguoi.laAgent { CTWNhanAI() }
                                if a.isClient == true { Text("Client").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.brandPink) }
                            }
                            if let s = moTaNguoi(p) { Text(s).font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }
                        }
                        Spacer()
                        Image(systemName: bieuTuongRsvp(p?.rsvp)).foregroundColor(mauRsvp(p?.rsvp))
                            .accessibilityLabel(p?.rsvp.map { "RSVP \($0.lowercased())" } ?? "No reply")
                    }
                    .padding(.vertical, 7)
                    .accessibilityElement(children: .combine)
                    if a.id != ds.last?.id { Divider() }
                }
                if ds.isEmpty { Text("No one invited yet.").font(.system(size: 13)).foregroundColor(AppColors.textTertiary).padding(.vertical, 8) }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .ctwThe()
        }
    }

    private func moTaNguoi(_ p: CTWHopNguoiPhong?) -> String? {
        guard let p else { return nil }
        var a: [String] = []
        if p.present == true { a.append("In the meeting") }
        switch p.attendance {
        case "PRESENT": a.append("Present")
        case "LATE": a.append("Late")
        case "EXCUSED": a.append("Excused")
        case "ABSENT": a.append("Absent")
        default: break
        }
        if let n = p.rsvpNote, !n.isEmpty { a.append("“\(n)”") }
        return a.isEmpty ? nil : a.joined(separator: " · ")
    }
    private func bieuTuongRsvp(_ r: String?) -> String {
        switch r { case "YES": return "checkmark.circle.fill"; case "NO": return "xmark.circle.fill"; case "MAYBE": return "questionmark.circle.fill"; default: return "circle.dashed" }
    }
    private func mauRsvp(_ r: String?) -> Color {
        switch r { case "YES": return AppColors.success; case "NO": return AppColors.error; case "MAYBE": return AppColors.warning; default: return AppColors.textTertiary }
    }

    @ViewBuilder
    private func lienQuan(_ h: CTWMeeting) -> some View {
        let coLoi = !(vm.phong?.recordings ?? []).isEmpty
        let ghi = vm.phong?.recordingUrl.flatMap(URL.init(string:))
        if coLoi || ghi != nil || h.previous != nil || !(h.next ?? []).isEmpty {
            VStack(spacing: 0) {
                if coLoi {
                    Button { tamPhu = .banGhiLoi } label: { hangLienKet("text.quote", "Transcript", nil) }.buttonStyle(.plain)
                    Divider()
                }
                if let ghi {
                    Button { moUrl(ghi) } label: { hangLienKet("play.rectangle", "Recording", ghi.host) }.buttonStyle(.plain)
                    Divider()
                }
                if let p = h.previous {
                    NavigationLink(value: RouteHopCTW(pid: pid, so: p.number, tieuDe: p.title ?? "")) { hangLienKet("arrow.uturn.backward", "Previous: \(p.title ?? "M-\(p.number)")", nil) }
                        .buttonStyle(.plain)
                    Divider()
                }
                ForEach(h.next ?? [], id: \.number) { n in
                    NavigationLink(value: RouteHopCTW(pid: pid, so: n.number, tieuDe: n.title ?? "")) { hangLienKet("arrow.uturn.forward", "Next: \(n.title ?? "M-\(n.number)")", nil) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .ctwThe()
        }
    }

    private func hangLienKet(_ icon: String, _ ten: String, _ phu: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(AppColors.primary).frame(width: 24)
            Text(ten).font(.system(size: 14)).foregroundColor(AppColors.textPrimary).lineLimit(1)
            Spacer()
            if let phu { Text(phu).font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: Thanh công cụ

    @ToolbarContentBuilder private var thanhCongCu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if suaDuoc, let h = vm.hop {
                    Button { tamPhu = .sua } label: { Label("Edit meeting", systemImage: "pencil") }
                    if !h.daXong && !h.daHuy {
                        Button { Task { _ = await vm.sua(["status": "DONE"]) } } label: { Label("Mark as done", systemImage: "checkmark.circle") }
                    }
                    Button {
                        Task {
                            if let m = await vm.nhanBan() {
                                nganXep.duong.append(RouteHopCTW(pid: pid, so: m.number, tieuDe: m.title))
                            }
                        }
                    } label: { Label("Duplicate for next week", systemImage: "plus.square.on.square") }
                    if !h.daHuy {
                        Button(role: .destructive) { hoiHuy = true } label: { Label("Cancel meeting", systemImage: "calendar.badge.minus") }
                    }
                }
                Button { tamPhu = .lich } label: { Label("Add to Calendar", systemImage: "calendar.badge.plus") }
                if let h = vm.hop, let ws = app.luaChon?.slug, let ma = app.luaChon?.maDuAn,
                   let u = URL(string: "https://cuongthai.com/work/\(ws)/\(ma)/meetings/\(h.number)") {
                    ShareLink(item: u) { Label("Share link", systemImage: "square.and.arrow.up") }
                }
                if vm.hop?.organizer?.id != app.currentUser?.id {
                    Divider()
                    Button(role: .destructive) { baoCao = true } label: { Label("Report notes", systemImage: "flag") }
                    if let o = vm.hop?.organizer {
                        Button(role: .destructive) { hoiChan = true } label: { Label("Block \(o.ten)", systemImage: "hand.raised") }
                    }
                }
                if vm.hop?.canDelete == true {
                    Divider()
                    Button(role: .destructive) { hoiXoa = true } label: { Label("Delete meeting", systemImage: "trash") }
                }
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("Meeting options")
        }
    }

    // MARK: Tấm phủ

    @ViewBuilder
    private func tamPhuView(_ t: TamPhuHopCTW) -> some View {
        switch t {
        case .sua:
            if let h = vm.hop {
                SoanHopCTW(pid: pid, hop: h) { _ in Task { await vm.tai() } }.environmentObject(app)
            }
        case .ghiChu:
            GhiChuHopCTW { chu in await vm.noiBienBan(chu) }
        case .viec(let v):
            SoanViecHopCTW(viec: v, thanhVien: (vm.hop?.attendees ?? []).map(\.nguoi), duAn: app.cauHinhDuAn?.dsThanhVien ?? []) { moi in
                var ds = vm.hop?.actions ?? []
                if let i = ds.firstIndex(where: { $0.id == moi.id && moi.id > 0 }) { ds[i] = moi } else { ds.append(moi) }
                return await vm.luuViec(ds)
            }
        case .moi:
            CTWChonNguoiView(ds: (app.cauHinhDuAn?.dsThanhVien ?? []).filter { !$0.laAgent }, toi: app.currentUser?.id,
                             nhieu: true, choPhepTrong: false, chon: $chonMoi) {
                let ids = Array(chonMoi)
                Task { await vm.moiNguoi(ids) }
            }
        case .lich:
            if let h = vm.hop {
                ThemVaoLichCTW(hop: h, duongWeb: app.luaChon.map { "https://cuongthai.com/work/\($0.slug)/\($0.maDuAn)/meetings/\(h.number)" })
                    .ignoresSafeArea()
            }
        case .banGhiLoi:
            BanGhiLoiHopCTW(pid: pid, so: so)
        }
    }

    private func guiBaoCao(_ ma: String) async {
        guard vm.hop != nil else { return }
        let l = CTWBaoCao.lyDo.first { $0.ma == ma } ?? CTWBaoCao.lyDo[5]
        do {
            // `POST /projects/:pid/meetings/:num/report` — máy chủ tự trích tiêu đề + biên bản vào hàng chờ.
            let _: CTWKetQuaBaoCao = try await APIClient.shared.request(CTWAPI.baoCaoHop(pid: pid, so: so, lyDo: l.ma))
            an.an(pid: pid, so: so)
            thongBao = "Thanks — our moderators will review it within 24 hours. The notes are hidden for you."
        } catch { vm.loi = CTW.loi(error) }
    }
}

// MARK: - Thành phần

struct ChipTrangThaiHopCTW: View {
    let trangThai: String?
    var body: some View {
        let (ten, mau): (String, Color) = {
            switch trangThai {
            case "DONE": return ("Done", AppColors.success)
            case "CANCELLED": return ("Cancelled", AppColors.error)
            default: return ("Scheduled", AppColors.secondary)
            }
        }()
        HStack(spacing: 4) {
            Circle().fill(mau).frame(width: 6, height: 6)
            Text(ten).font(.system(size: 11, weight: .semibold)).foregroundColor(mau)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(mau.opacity(0.12)))
    }
}

struct HangViecHopCTW: View {
    let viec: CTWHopViec
    var chon = false
    var choChon = false
    var bamChon: () -> Void = {}
    var moThe: (CTWHopTheRef) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if choChon {
                Button(action: bamChon) {
                    Image(systemName: chon ? "checkmark.circle.fill" : "circle").font(.system(size: 18))
                        .foregroundColor(chon ? AppColors.primary : AppColors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chon ? "Selected" : "Select for issue creation")
            } else {
                Image(systemName: viec.issue?.done == true ? "checkmark.square.fill" : "square").font(.system(size: 17))
                    .foregroundColor(viec.issue?.done == true ? AppColors.success : AppColors.textTertiary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(viec.text).font(.system(size: 14)).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if let a = viec.assignee {
                        HStack(spacing: 4) { CTWAvatar(user: a, size: 16); Text(a.ten).font(.system(size: 12)) }
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let d = CTW.ngayNgan(viec.dueDate) {
                        Label(d, systemImage: "calendar").font(.system(size: 12))
                            .foregroundColor(CTW.quaHan(viec.dueDate) && viec.issue?.done != true ? AppColors.error : AppColors.textSecondary)
                    }
                    if let k = viec.issue {
                        Button { moThe(k) } label: {
                            Text(k.key ?? "").font(.system(size: 11, weight: .semibold).monospaced())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                                .foregroundColor(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open issue \(k.key ?? "")")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Ghi nối vào biên bản

struct GhiChuHopCTW: View {
    let luu: (String) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chu = ""
    @State private var dangLuu = false
    @FocusState private var tieuDiem: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your notes are added to the end of the meeting minutes. Formatting written on the web is kept.")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                TextEditor(text: $chu)
                    .focused($tieuDiem)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundCard))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                    .accessibilityLabel("Notes")
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Add to notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            dangLuu = true
                            if await luu(chu) { dong() }
                            dangLuu = false
                        }
                    }
                    .bold()
                    .disabled(chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dangLuu)
                }
            }
            .onAppear { tieuDiem = true }
        }
    }
}

// MARK: - Sửa / thêm một việc

struct SoanViecHopCTW: View {
    let viec: CTWHopViec?
    let thanhVien: [CTWUser]
    let duAn: [CTWUser]
    let luu: (CTWHopViec) async -> Bool
    @Environment(\.dismiss) private var dong
    @State private var chu = ""
    @State private var nguoi: Int?
    @State private var coHan = false
    @State private var han = Date()
    @State private var dangLuu = false

    private var ds: [CTWUser] {
        var a = thanhVien
        for u in duAn where !a.contains(where: { $0.id == u.id }) { a.append(u) }
        return a
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") { TextField("What needs to happen?", text: $chu, axis: .vertical).lineLimit(1...4) }
                Section("Owner") {
                    Picker("Owner", selection: $nguoi) {
                        Text("Unassigned").tag(Int?.none)
                        ForEach(ds) { u in Text(u.laAgent ? "\(u.ten) (AI agent)" : u.ten).tag(Optional(u.id)) }
                    }
                }
                Section {
                    Toggle("Due date", isOn: $coHan)
                    if coHan { DatePicker("Due", selection: $han, displayedComponents: .date) }
                }
            }
            .navigationTitle(viec == nil ? "New action item" : "Edit action item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            dangLuu = true
                            var v = viec ?? CTWHopViec(id: 0, text: "")
                            v.text = chu.trimmingCharacters(in: .whitespacesAndNewlines)
                            v.assignee = nguoi.flatMap { id in ds.first { $0.id == id } }
                            v.dueDate = coHan ? CTW.chuoiNgay(han) : nil
                            if await luu(v) { dong() }
                            dangLuu = false
                        }
                    }
                    .bold()
                    .disabled(chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dangLuu)
                }
            }
            .onAppear {
                chu = viec?.text ?? ""
                nguoi = viec?.assignee?.id
                if let d = CTW.ngayDate(viec?.dueDate) { coHan = true; han = d }
            }
        }
    }
}

// MARK: - Thêm vào Lịch (EventKitUI, ngoài tiến trình — không cần quyền Lịch từ iOS 17)

struct ThemVaoLichCTW: UIViewControllerRepresentable {
    let hop: CTWMeeting
    var duongWeb: String?
    @Environment(\.dismiss) private var dong

    func makeCoordinator() -> DieuPhoi { DieuPhoi(dong: { dong() }) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let kho = EKEventStore()
        let e = EKEvent(eventStore: kho)
        e.title = hop.title
        e.startDate = hop.batDau ?? Date()
        e.endDate = hop.ketThuc ?? (hop.batDau ?? Date()).addingTimeInterval(1800)
        e.location = hop.urlHop?.absoluteString ?? hop.location
        if let u = hop.urlHop { e.url = u } else if let w = duongWeb { e.url = URL(string: w) }
        e.notes = [hop.typeLabel, duongWeb.map { "CT Work: \($0)" }].compactMap { $0 }.joined(separator: "\n")
        let c = EKEventEditViewController()
        c.eventStore = kho
        c.event = e
        c.editViewDelegate = context.coordinator
        return c
    }

    func updateUIViewController(_ c: EKEventEditViewController, context: Context) {}

    final class DieuPhoi: NSObject, EKEventEditViewDelegate {
        let dong: () -> Void
        init(dong: @escaping () -> Void) { self.dong = dong }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dong()
        }
    }
}

// MARK: - Ẩn ghi chú cuộc họp đã báo cáo (1.2)

@MainActor
final class AnNoiDungHopCTW: ObservableObject {
    static let shared = AnNoiDungHopCTW()
    @Published private(set) var ds: Set<String> = []
    private let khoa = "com.cuongthai.ctwork.hopAn"
    private init() { ds = Set(UserDefaults.standard.stringArray(forKey: khoa) ?? []) }
    func daAn(pid: Int, so: Int) -> Bool { ds.contains("\(pid):\(so)") }
    func an(pid: Int, so: Int) { ds.insert("\(pid):\(so)"); UserDefaults.standard.set(Array(ds), forKey: khoa) }
    func xoaHet() { ds = []; UserDefaults.standard.removeObject(forKey: khoa) }
}
