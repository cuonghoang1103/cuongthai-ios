import SwiftUI
import UserNotifications

// MARK: - Cài đặt thông báo
//
// · Thông báo đẩy: trạng thái quyền của iOS (+ mở Cài đặt nếu đã tắt).
// · Chat (`GET|PUT /work/chat/prefs`): báo mọi tin / chỉ khi được nhắc & trả lời; tạm dừng
//   (30m … đến khi bật lại); email tóm tắt tin chưa đọc. Từng kênh chỉnh ở màn kênh.
// · Email theo thông báo (`GET|PUT /work/me/notify-settings`): ngay / thư gộp 08:00 / tắt.
// · Giờ im lặng: tính theo GIỜ VIỆT NAM (máy chủ dùng `Asia/Ho_Chi_Minh`) — ghi rõ.

struct CaiDatThongBaoCTW: View {
    @Environment(\.dismiss) private var dong
    @Environment(\.openURL) private var moUrl
    @State private var quyen: UNAuthorizationStatus?
    @State private var chat: CTWChatPrefs?
    @State private var email: CTWCaiDatBao?
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
                Text("Assignments, mentions, replies, approvals and alerts. Long-press a notification to reply, approve or mark it as read without opening the app.")
            }

            if let c = chat {
                Section {
                    Picker("Notify me about", selection: Binding(get: { c.notify ?? "ALL" }, set: { v in Task { await luuChat(["notify": v]) } })) {
                        Text("All new messages").tag("ALL")
                        Text("Mentions & replies").tag("MENTIONS")
                    }
                    Menu {
                        ForEach([("30m", "30 minutes"), ("1h", "1 hour"), ("8h", "8 hours"), ("tomorrow", "Until tomorrow"), ("forever", "Until I turn it back on")], id: \.0) { m in
                            Button(m.1) { Task { await luuChat(["mute": m.0]) } }
                        }
                    } label: {
                        HStack {
                            Label(dangDung(c) ? "Chat notifications paused" : "Pause chat notifications",
                                  systemImage: dangDung(c) ? "pause.circle.fill" : "pause.circle")
                            Spacer()
                            if dangDung(c) {
                                Text(c.mutedForever == true ? "Until resumed" : (c.mutedUntil.map { "Until \(CTWChatThoiGian.gio($0))" } ?? ""))
                                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
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
                Section {
                    Picker("Email for notifications", selection: Binding(get: { e.emailMode ?? "INSTANT" }, set: { v in Task { await luuEmail(["emailMode": v]) } })) {
                        Text("Right away").tag("INSTANT")
                        Text("Daily digest at 08:00").tag("DIGEST")
                        Text("Off").tag("OFF")
                    }
                } header: { Text("Email") }

                Section {
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
                } header: { Text("Quiet hours") } footer: {
                    Text("During quiet hours, emails wait for the next digest and chat stays silent. Hours are Vietnam time (GMT+7).")
                }
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
        case .authorized: return "On"
        case .provisional: return "Delivered quietly"
        case .ephemeral: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Not set"
        default: return "…"
        }
    }

    private func dangDung(_ c: CTWChatPrefs) -> Bool { c.mutedForever == true || c.mutedUntil != nil }

    private func gio(_ h: Int) -> String { String(format: "%02d:00", h) }

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
