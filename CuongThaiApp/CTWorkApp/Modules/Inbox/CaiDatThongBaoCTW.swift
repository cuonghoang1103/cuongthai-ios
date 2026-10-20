import SwiftUI
import UserNotifications

// MARK: - Cài đặt thông báo
//
// · Thông báo đẩy: trạng thái quyền của iOS (+ mở Cài đặt nếu đã tắt).
// · Chat (`GET|PUT /work/chat/prefs`): báo mọi tin / chỉ khi được nhắc & trả lời; tạm dừng
//   (30m … đến khi bật lại); email tóm tắt tin chưa đọc. Từng kênh chỉnh ở màn kênh.
// · Email theo thông báo (`GET|PUT /work/me/notify-settings`): ngay / thư gộp 08:00 / tắt.
// · Đẩy theo loại (`push: {assign, comment, mention, alert, approval, chatAll, git}`) — máy chủ lọc trong
//   `dayRaNgoaiApp` nên tắt ở đây là tắt THẬT trên mọi máy của người này (không chỉ máy này).
// · Giờ im lặng theo `timezone` (IANA) của người dùng; `null` ⇒ máy chủ dùng Asia/Ho_Chi_Minh.
//   App mặc định đề xuất múi giờ của máy; người dùng bật/tắt được.

struct CaiDatThongBaoCTW: View {
    @Environment(\.dismiss) private var dong
    @Environment(\.openURL) private var moUrl
    @State private var quyen: UNAuthorizationStatus?
    @State private var chat: CTWChatPrefs?
    @State private var email: CTWCaiDatBao?
    @State private var nangCao = false
    @State private var coIm = false
    @State private var imTu = 22
    @State private var imDen = 7
    @State private var loi: String?
    @State private var daNap = false

    var body: some View {
        Form {
            if let loi { Section { CTWErrorBanner(text: loi) { self.loi = nil } }.listRowBackground(Color.clear) }
            Section {
                HStack {
                    Label("Push notifications", systemImage: "bell.badge")
                    Spacer()
                    Text(tenQuyen).foregroundColor(quyen == .denied ? AppColors.error : AppColors.textSecondary)
                }
                if quyen == .denied || quyen == .notDetermined {
                    Button(quyen == .denied ? "Turn on in Settings" : "Allow notifications") {
                        if quyen == .denied {
                            if let u = URL(string: UIApplication.openNotificationSettingsURLString) { moUrl(u) }
                        } else {
                            Task {
                                await DayCTW.shared.xinQuyenVaDangKy()
                                await napQuyen()
                            }
                        }
                    }
                }
            } footer: {
                Text("Long-press a notification to reply, approve, join a meeting or mark it as read without opening the app.")
            }

            if let e = email {
                Section {
                    congTac(String(localized: "Assigned to me"), "person.fill.checkmark", \.assign, "assign", e)
                    congTac(String(localized: "Comments & replies"), "text.bubble", \.comment, "comment", e)
                    congTac(String(localized: "Mentions"), "at", \.mention, "mention", e)
                    congTac(String(localized: "Approvals waiting for me"), "checkmark.seal", \.approval, "approval", e)
                    congTac(String(localized: "Alerts & meeting reminders"), "exclamationmark.circle", \.alert, "alert", e)
                    congTac(String(localized: "Every new chat message"), "bubble.left.and.bubble.right", \.chatAll, "chatAll", e)
                    congTac(String(localized: "Git activity (pushes, pull requests, reviews)"), "chevron.left.forwardslash.chevron.right", \.git, "git", e)
                } header: { Text("Push me about") } footer: {
                    Text("Applies to every device you're signed in on. The inbox keeps everything either way. \"Every new chat message\" only matters for channels set to all messages.")
                }
            }

            if let c = chat {
                Section {
                    Picker("Notify me about", selection: Binding(get: { c.notify ?? "ALL" }, set: { v in Task { await luuChat(["notify": v]) } })) {
                        Text("All new messages").tag("ALL")
                        Text("Mentions & replies").tag("MENTIONS")
                    }
                    Menu {
                        ForEach([("30m", String(localized: "30 minutes")), ("1h", String(localized: "1 hour")), ("8h", String(localized: "8 hours")), ("tomorrow", String(localized: "Until tomorrow")), ("forever", String(localized: "Until I turn it back on"))], id: \.0) { m in
                            Button(m.1) { Task { await luuChat(["mute": m.0]) } }
                        }
                    } label: {
                        HStack {
                            Label(dangDung(c) ? "Chat notifications paused" : "Pause chat notifications",
                                  systemImage: dangDung(c) ? "pause.circle.fill" : "pause.circle")
                            Spacer()
                            if dangDung(c) {
                                Text(c.mutedForever == true ? String(localized: "Until resumed") : (c.mutedUntil.map { String(localized: "Until \(CTWChatThoiGian.gio($0))") } ?? ""))
                                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    if dangDung(c) {
                        Button("Resume chat notifications") { Task { await luuChat(["mute": "off"]) } }
                    }
                    Toggle("Email me a summary of unread chat", isOn: Binding(get: { c.emailDigest == true }, set: { v in Task { await luuChat(["emailDigest": v]) } }))
                } header: { Text("Chat") } footer: {
                    Text("You can also mute or change notifications for a single channel from the channel's details.")
                }
            }

            if let e = email {
                // "Hiện dần" (19/10/2026): email + giờ im lặng + múi giờ là mục NÂNG CAO — thu gọn mặc định.
                Section {
                    DisclosureGroup(isExpanded: $nangCao) {
                    Picker("Email for notifications", selection: Binding(get: { e.emailMode ?? "INSTANT" }, set: { v in Task { await luuEmail(["emailMode": v]) } })) {
                        Text("Right away").tag("INSTANT")
                        Text("Daily digest at 08:00").tag("DIGEST")
                        Text("Off").tag("OFF")
                    }
                    Toggle("Quiet hours", isOn: $coIm)
                        .onChange(of: coIm) { _, v in
                            guard daNap else { return }
                            Task { await luuEmail(v ? ["quietStart": imTu, "quietEnd": imDen] : ["quietStart": NSNull(), "quietEnd": NSNull()]) }
                        }
                    if coIm {
                        Picker("From", selection: $imTu) { ForEach(0..<24, id: \.self) { Text(gio($0)).tag($0) } }
                            .onChange(of: imTu) { _, v in guard daNap else { return }; Task { await luuEmail(["quietStart": v, "quietEnd": imDen]) } }
                        Picker("To", selection: $imDen) { ForEach(0..<24, id: \.self) { Text(gio($0)).tag($0) } }
                            .onChange(of: imDen) { _, v in guard daNap else { return }; Task { await luuEmail(["quietStart": imTu, "quietEnd": v]) } }
                    }
                    Toggle(isOn: Binding(get: { e.timezone != nil }, set: { v in
                        Task { await luuEmail(["timezone": v ? TimeZone.current.identifier : NSNull()]) }
                    })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use this device's time zone")
                            Text(e.timezone ?? TimeZone.current.identifier).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                        Text(String(localized: "During quiet hours, emails wait for the next digest and chat stays silent. \(chuMuiGio(e))"))
                            .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                    } label: {
                        Label("Email & quiet hours", systemImage: "envelope.badge")
                    }
                    .accessibilityIdentifier("settings.advanced")
                } header: { Text("Advanced") }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
        .overlay { if chat == nil && email == nil && loi == nil { ProgressView() } }
        .task { await nap() }
    }

    private var tenQuyen: String {
        switch quyen {
        case .authorized: return String(localized: "On")
        case .provisional: return String(localized: "Delivered quietly")
        case .ephemeral: return String(localized: "On")
        case .denied: return String(localized: "Off")
        case .notDetermined: return String(localized: "Not set")
        default: return "…"
        }
    }

    private func dangDung(_ c: CTWChatPrefs) -> Bool { c.mutedForever == true || c.mutedUntil != nil }

    private func gio(_ h: Int) -> String { String(format: "%02d:00", h) }

    private func chuMuiGio(_ e: CTWCaiDatBao) -> String {
        if let tz = e.timezone { return String(localized: "Hours follow \(TimeZone(identifier: tz)?.localizedName(for: .generic, locale: CTWDinhDang.locale) ?? tz).") }
        return String(localized: "Hours are Vietnam time (GMT+7) until you choose your own time zone.")
    }

    /// Một công tắc đẩy theo loại — gửi MỘT khoá (máy chủ gộp với phần còn lại).
    private func congTac(_ ten: String, _ icon: String, _ kp: WritableKeyPath<CTWCaiDatBao.Day, Bool?>, _ khoa: String,
                         _ e: CTWCaiDatBao) -> some View {
        Toggle(isOn: Binding(get: { e.push?[keyPath: kp] ?? true }, set: { v in
            var moi = e
            var p = moi.push ?? CTWCaiDatBao.Day()
            p[keyPath: kp] = v
            moi.push = p
            email = moi    // phản hồi ngay, máy chủ trả lại bản thật
            Task { await luuEmail(["push": [khoa: v]]) }
        })) { Label(ten, systemImage: icon) }
    }

    private func napQuyen() async {
        quyen = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func nap() async {
        await napQuyen()
        do {
            async let a: CTWChatPrefs = APIClient.shared.request(CTWAPI.caiDatChat())
            async let b: CTWCaiDatBao = APIClient.shared.request(CTWAPI.tbCaiDat())
            let (c, e) = try await (a, b)
            chat = c
            email = e
            coIm = e.quietStart != nil && e.quietEnd != nil
            imTu = e.quietStart ?? 22
            imDen = e.quietEnd ?? 7
            loi = nil
        } catch { loi = CTW.loi(error) }
        // Bật cờ SAU khi gán giá trị ban đầu ⇒ `onChange` không gửi ngược lại máy chủ.
        DispatchQueue.main.async { daNap = true }
    }

    private func luuChat(_ than: [String: Any]) async {
        do {
            chat = try await APIClient.shared.request(CTWAPI.luuCaiDatChat(than))
            CTWRung.chon()
            await AppState.shared.taiSoChuaDoc()
        } catch { loi = CTW.loi(error) }
    }

    private func luuEmail(_ than: [String: Any]) async {
        do {
            email = try await APIClient.shared.request(CTWAPI.tbLuuCaiDat(than))
            CTWRung.chon()
        } catch { loi = CTW.loi(error) }
    }
}
