import SwiftUI

// MARK: - Tạo / sửa cuộc họp
//
// `POST /projects/:pid/meetings {title, startsAt, endsAt, type, timezone, location,
// meetingUrl ("jitsi" ⇒ máy chủ tự tạo phòng), attendeeIds, agendaJson, sendInvites}`.
// Sửa: `PATCH … {…, version}` (409 ⇒ người khác vừa sửa). Người dự sửa riêng ở màn chi tiết.

struct SoanHopCTW: View {
    let pid: Int
    let hop: CTWMeeting?
    let xong: (CTWMeeting) -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong

    @State private var tieuDe = ""
    @State private var loai = "OTHER"
    @State private var batDau = SoanHopCTW.lamTron(Date().addingTimeInterval(3600))
    @State private var phut = 30
    @State private var diaDiem = ""
    /// none | jitsi | link
    @State private var kieuVideo = "jitsi"
    @State private var link = ""
    @State private var nguoi: Set<Int> = []
    @State private var chuongTrinh = ""
    @State private var guiMoi = true
    @State private var moChonNguoi = false
    @State private var loi: String?
    @State private var dangLuu = false

    static let loaiHop: [(String, String)] = [
        ("OTHER", "Meeting"), ("DAILY", "Daily stand-up"), ("WEEKLY", "Weekly"), ("PLANNING", "Sprint planning"),
        ("DEMO", "Demo"), ("RETRO", "Retrospective"), ("KICKOFF", "Kick-off"), ("CLIENT", "Client meeting"),
        ("STEERING", "Steering committee"), ("MENTOR", "Lecturer / mentor"), ("ELICITATION", "Requirements elicitation"),
    ]

    static func lamTron(_ d: Date) -> Date {
        let c = Calendar.current
        var x = c.dateComponents([.year, .month, .day, .hour], from: d)
        x.minute = 0
        return c.date(from: x) ?? d
    }

    private var hopLe: Bool {
        !tieuDe.trimmingCharacters(in: .whitespaces).isEmpty && (kieuVideo != "link" || URL(string: link.trimmingCharacters(in: .whitespaces))?.scheme?.hasPrefix("http") == true)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi) { self.loi = nil } }.listRowBackground(Color.clear) }
                Section {
                    TextField("Title", text: $tieuDe)
                    Picker("Type", selection: $loai) {
                        ForEach(Self.loaiHop, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }
                Section("When") {
                    DatePicker("Starts", selection: $batDau, displayedComponents: [.date, .hourAndMinute])
                    Picker("Duration", selection: $phut) {
                        ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { m in
                            Text(m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min")).tag(m)
                        }
                    }
                    LabeledContent("Time zone", value: TimeZone.current.identifier)
                }
                Section {
                    Picker("Video", selection: $kieuVideo) {
                        Text("Create a video room").tag("jitsi")
                        Text("Paste a link").tag("link")
                        Text("No video").tag("none")
                    }
                    if kieuVideo == "link" {
                        TextField("https://meet.google.com/…", text: $link)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    TextField("Location (optional)", text: $diaDiem)
                } header: { Text("Where") } footer: {
                    if kieuVideo == "jitsi" { Text("A private Jitsi Meet room is created for this meeting.") }
                }
                if hop == nil {
                    Section {
                        Button { moChonNguoi = true } label: {
                            HStack {
                                Text("Invite people").foregroundColor(AppColors.textPrimary)
                                Spacer()
                                ChongAvatarCTW(ds: (app.cauHinhDuAn?.dsThanhVien ?? []).filter { nguoi.contains($0.id) })
                                Text(nguoi.isEmpty ? "None" : "\(nguoi.count)").foregroundColor(AppColors.textSecondary)
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                        Toggle("Email calendar invites", isOn: $guiMoi)
                    } header: { Text("Attendees") }
                    Section {
                        TextEditor(text: $chuongTrinh).frame(minHeight: 90)
                            .accessibilityLabel("Agenda")
                    } header: { Text("Agenda (optional)") } footer: { Text("One item per line.") }
                }
            }
            .navigationTitle(hop == nil ? "New meeting" : "Edit meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hop == nil ? "Schedule" : "Save") { Task { await luu() } }.bold().disabled(!hopLe || dangLuu)
                }
            }
            .sheet(isPresented: $moChonNguoi) {
                CTWChonNguoiView(ds: (app.cauHinhDuAn?.dsThanhVien ?? []).filter { !$0.laAgent }, toi: app.currentUser?.id,
                                 nhieu: true, choPhepTrong: false, chon: $nguoi)
            }
            .onAppear(perform: napBanDau)
        }
    }

    private func napBanDau() {
        guard let h = hop else {
            if let toi = app.currentUser?.id { nguoi = [toi] }
            return
        }
        tieuDe = h.title
        loai = h.type ?? "OTHER"
        if let b = h.batDau { batDau = b }
        if let b = h.batDau, let k = h.ketThuc { phut = max(15, Int(k.timeIntervalSince(b) / 60)) }
        diaDiem = h.location ?? ""
        if let u = h.meetingUrl, !u.isEmpty { kieuVideo = "link"; link = u } else { kieuVideo = "none" }
    }

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        let f = ISO8601DateFormatter()
        var b: [String: Any] = [
            "title": tieuDe.trimmingCharacters(in: .whitespaces),
            "type": loai,
            "startsAt": f.string(from: batDau),
            "endsAt": f.string(from: batDau.addingTimeInterval(Double(phut) * 60)),
            "timezone": TimeZone.current.identifier,
            "location": diaDiem.trimmingCharacters(in: .whitespaces).isEmpty ? NSNull() : diaDiem.trimmingCharacters(in: .whitespaces),
        ]
        switch kieuVideo {
        case "jitsi": b["meetingUrl"] = (hop?.meetingUrl?.isEmpty == false && hop?.provider == "JITSI") ? hop!.meetingUrl! : "jitsi"
        case "link": b["meetingUrl"] = link.trimmingCharacters(in: .whitespaces)
        default: b["meetingUrl"] = NSNull()
        }
        do {
            if let h = hop {
                if let v = h.version { b["version"] = v }
                let m: CTWMeeting = try await APIClient.shared.request(CTWAPI.suaHop(pid: pid, so: h.number, b))
                CTWRung.thanhCong()
                dong()
                xong(m)
            } else {
                b["attendeeIds"] = Array(nguoi)
                b["sendInvites"] = guiMoi
                let ct = chuongTrinh.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if !ct.isEmpty { b["agendaJson"] = CTWNode.docTuChu(ct.joined(separator: "\n")) }
                let m: CTWMeeting = try await APIClient.shared.request(CTWAPI.taoHop(pid: pid, b))
                // Chương trình có cấu trúc (phòng họp) — mỗi dòng một mục.
                if !ct.isEmpty {
                    _ = try? await APIClient.shared.send(CTWAPI.chuongTrinhHop(pid: pid, so: m.number, ct.map { ["title": String($0.prefix(300))] }))
                }
                CTWRung.thanhCong()
                dong()
                xong(m)
            }
        } catch {
            loi = CTW.laXungDot(error) ? "Someone else just changed this meeting. Close and reopen it to see their version." : CTW.loi(error)
            CTWRung.loi()
        }
    }
}

// MARK: - Bản ghi lời (transcript) — chỉ đọc, tìm được

struct BanGhiLoiHopCTW: View {
    let pid: Int
    let so: Int
    @Environment(\.dismiss) private var dong
    @State private var kq: CTWHopTranscript?
    @State private var loi: String?
    @State private var tim = ""

    var body: some View {
        NavigationStack {
            List {
                if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear) }
                let ds = (kq?.recordings ?? []).flatMap { r in (r.lines ?? []).map { (r.id, $0) } }
                    .filter { tim.isEmpty || ($0.1.text ?? "").localizedCaseInsensitiveContains(tim) }
                if kq != nil && ds.isEmpty {
                    CTWOTrong(bieuTuong: "text.quote", tieuDe: tim.isEmpty ? "No transcript yet" : "No matches",
                              moTa: tim.isEmpty ? "Transcripts appear here after a meeting is recorded." : "Try another word.")
                        .listRowBackground(Color.clear)
                }
                ForEach(ds, id: \.1.id) { _, l in
                    HStack(alignment: .top, spacing: 10) {
                        Text(l.at ?? "").font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textTertiary)
                            .frame(width: 44, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            if let s = l.speakerId, let u = kq?.speakers?.first(where: { $0.id == s }) {
                                Text(u.ten).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                            }
                            Text(l.text ?? "").font(.system(size: 14)).foregroundColor(AppColors.textPrimary).textSelection(.enabled)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .listStyle(.plain)
            .searchable(text: $tim, prompt: "Search transcript")
            .overlay { if kq == nil && loi == nil { ProgressView() } }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
            .task {
                do { kq = try await APIClient.shared.request(CTWAPI.banGhiLoiHop(pid: pid, so: so)) } catch { loi = CTW.loi(error) }
            }
        }
    }
}
