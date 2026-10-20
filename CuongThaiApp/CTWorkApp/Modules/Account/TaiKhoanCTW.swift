import SwiftUI
import SafariServices

// MARK: - Liên hệ + đường dẫn pháp lý (App Store 1.2 #4, 5.1.1)

enum LienHeCTW {
    static let email = "cuongthaihnhe176322@gmail.com"
    static let chinhSach = URL(string: "https://cuongthai.com/chinh-sach-bao-mat")!
    static let dieuKhoan = URL(string: "https://cuongthai.com/dieu-khoan-su-dung")!
    static let eulaApple = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let web = URL(string: "https://cuongthai.com/work")!
}

enum TrangPhapLyCTW: String, Identifiable {
    case dieuKhoan, baoMat, troGiup
    var id: String { rawValue }
}

struct TrangPhapLyView: View {
    let trang: TrangPhapLyCTW
    @Environment(\.dismiss) private var dong
    @State private var web: URL?

    var body: some View {
        List {
            switch trang {
            case .dieuKhoan: dieuKhoan
            case .baoMat: baoMat
            case .troGiup: troGiup
            }
        }
        .navigationTitle(tieuDe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
        .sheet(item: Binding(get: { web.map(URLCoID.init) }, set: { web = $0?.url })) { u in
            SafariCTW(url: u.url).ignoresSafeArea()
        }
    }

    private var tieuDe: String {
        switch trang {
        case .dieuKhoan: return String(localized: "Terms of Use")
        case .baoMat: return String(localized: "Privacy Policy")
        case .troGiup: return String(localized: "Help & Contact")
        }
    }

    @ViewBuilder private var dieuKhoan: some View {
        Section {
            muc("CT Work is a team work-management service by cuongthai.com: issues, boards, backlogs, comments, files, project chat and documents.")
            muc("You are responsible for what you post. Do not post content that is illegal, harassing, hateful, sexual, violent, or that infringes someone else's rights.")
            muc("There is zero tolerance for objectionable content or abusive users. Reported content is reviewed within 24 hours; content that breaks these rules is removed and the account responsible is suspended.")
            muc("Workspace admins can add AI agents as members. Content created by an agent is labelled “AI agent”; the person who owns the agent is responsible for it.")
            muc("You can delete your account at any time from Account › Delete account.")
        } header: { Text("Summary") }
        Section {
            Button("Full Terms of Use") { web = LienHeCTW.dieuKhoan }
            Button("Apple Standard EULA") { web = LienHeCTW.eulaApple }
        }
    }

    @ViewBuilder private var baoMat: some View {
        Section {
            muc("We store your account (username, email, name, avatar) and the work you create: issues, comments, attachments, chat messages and documents.")
            muc("Photos and files are uploaded only when you choose to attach them. The camera is used only when you tap “Take Photo”.")
            muc("The microphone is used only while you record a voice note in chat. Voice notes are stored for the people in that channel and sent to Groq, a third-party speech-to-text service, to create a transcript — the app asks for your consent before your first voice note.")
            muc("Video meetings open in Google Meet, Zoom, Microsoft Teams or Jitsi (or Safari). CT Work itself does not use your camera or microphone for calls.")
            muc("If you allow notifications, we store your device's push token to deliver CT Work notifications.")
            muc("AI assistant: when you ask it a question, your question and the project content needed to answer it (issues, comments, Docs pages, attached files and links you can already see) are sent to a third-party AI model provider (large language models such as Anthropic Claude and OpenAI GPT, through our AI gateway). The app asks for your consent before your first question; you can withdraw it in Account › Privacy. Answers are labelled “AI-generated” and can be reported.")
            muc("Apart from the AI assistant and voice-note transcription, this app does not send your data to third-party AI services. AI agents that a workspace admin adds can read the project they are members of, like any other member; AI-drafted meeting minutes are labelled “AI-generated”.")
            muc("Widgets, Siri and Spotlight use a copy of your own data kept on this device only (today's work, your timer, issues you opened recently). Signing out deletes it.")
            muc("Face ID lock is optional and off by default. Face ID is handled by iOS; the app never sees your face data.")
            muc("No tracking, no advertising, no data sale.")
        } header: { Text("Summary") }
        Section {
            Button("Full Privacy Policy") { web = LienHeCTW.chinhSach }
        }
    }

    @ViewBuilder private var troGiup: some View {
        Section {
            muc("To report a comment or chat message, touch and hold it, then choose Report. To report meeting notes, open the meeting and choose ••• › Report notes. To stop seeing someone, choose Block.")
            muc("Blocked users and hidden content are managed in Account › Blocked users.")
            muc("Our moderators review every report within 24 hours.")
        } header: { Text("Safety") }
        Section {
            Link(destination: URL(string: "mailto:\(LienHeCTW.email)?subject=CT%20Work%20support")!) {
                Label(LienHeCTW.email, systemImage: "envelope")
            }
        } header: { Text("Contact us") }
    }

    private func muc(_ s: LocalizedStringKey) -> some View {
        Text(s).font(.ctw(size: 14)).foregroundColor(AppColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
    }
}

struct URLCoID: Identifiable { let url: URL; var id: String { url.absoluteString } }

/// Trình duyệt hệ thống cho trang NGOÀI cuongthai.com (link người dùng dán, EULA của Apple).
/// Trang của cuongthai.com đi qua `SafariCTW` → `TrinhDuyetCuongThaiCTW` (có chốt 3.1.1).
struct SafariGocCTW: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController(url: url)
        c.preferredControlTintColor = UIColor(AppColors.primary)
        return c
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Tài khoản

struct TaiKhoanCTW: View {
    @EnvironmentObject private var app: AppState
    @State private var tamPhu: TamPhu?
    @State private var hoiDangXuat = false
    /// 5.1.2(i): đồng ý gửi câu hỏi + nội dung dự án cho nhà cung cấp AI (Modules/AI/TroLyAICTW.swift).
    @AppStorage("com.cuongthai.ctwork.ai.dongY") private var aiDongY = false
    @ObservedObject private var ngonNgu = NgonNguApCTW.shared

    enum TamPhu: Identifiable {
        case phapLy(TrangPhapLyCTW), chonDuAn, web(URL)
        var id: String {
            switch self {
            case .phapLy(let t): return "pl-\(t.rawValue)"
            case .chonDuAn: return "chon"
            case .web(let u): return u.absoluteString
            }
        }
    }

    var body: some View {
        // Khung (`CotCTW`) đã bọc NavigationStack.
        Group {
            List {
                Section {
                    HStack(spacing: 14) {
                        CTWAvatar(user: app.currentUser.map {
                            CTWUser(id: $0.id, username: $0.username, fullName: $0.fullName,
                                    displayName: $0.displayName, avatarUrl: $0.avatarUrl)
                        }, size: 54)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.currentUser?.displayName ?? app.currentUser?.fullName ?? app.currentUser?.username ?? "—")
                                .font(.ctw(size: 18, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                            Text("@\(app.currentUser?.username ?? "")")
                                .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                            if let e = app.currentUser?.email {
                                Text(e).font(.ctw(size: 12)).foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Button { tamPhu = .chonDuAn } label: {
                        HStack {
                            Label("Current project", systemImage: "rectangle.3.group")
                            Spacer()
                            Text(app.luaChon.map { "\($0.maDuAn) · \($0.tenKhongGian)" } ?? String(localized: "None"))
                                .foregroundColor(AppColors.textSecondary).lineLimit(1)
                        }
                    }
                } header: { Text("Workspace") }

                // 20/10/2026 — ngôn ngữ app. Bảng chọn dạng menu (không đẩy màn) ⇒ đổi xong vẫn đứng ở Account
                // dù cả cây dựng lại (`GocCTW` `.id(ngonNgu.ma)`).
                Section {
                    Picker(selection: Binding(get: { ngonNgu.cheDo }, set: { ngonNgu.dat($0) })) {
                        ForEach(NgonNguCTW.CheDo.allCases) { c in
                            Text(verbatim: NgonNguApCTW.ten(c)).tag(c)
                        }
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("account.language")
                } header: { Text("Language") } footer: {
                    Text("Changes apply right away. Names of projects, statuses and issues stay as your team wrote them.")
                }

                Section("Notifications") {
                    NavigationLink { CaiDatThongBaoCTW() } label: { Label("What to notify me about", systemImage: "slider.horizontal.3") }
                    Button {
                        if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) }
                    } label: { Label("Notification settings", systemImage: "bell.badge") }
                }

                // 19/10/2026 — gom theo chủ đề (8 khối ⇒ 6): Quyền riêng tư & bảo mật · Trợ giúp & pháp lý.
                Section {
                    KhoaAppCongTacCTW()
                    Toggle(isOn: $aiDongY) { Label("AI assistant may use project content", systemImage: "sparkles") }
                        .accessibilityIdentifier("account.aiConsent")
                    NavigationLink { DanhSachChanCTW() } label: { Label("Blocked users & hidden content", systemImage: "hand.raised") }
                } header: { Text("Privacy & security") } footer: {
                    Text("App lock asks for \(KhoaAppCTW.tenSinhTracHoc) (or your passcode) when you return to CT Work. The AI assistant sends your question and the project content it needs to a third-party AI model provider; turn it off to be asked again before your next question.")
                }

                Section("Help & legal") {
                    Button { tamPhu = .phapLy(.troGiup) } label: { Label("Help & contact", systemImage: "questionmark.circle") }
                    Button { tamPhu = .phapLy(.dieuKhoan) } label: { Label("Terms of Use", systemImage: "doc.text") }
                    Button { tamPhu = .phapLy(.baoMat) } label: { Label("Privacy Policy", systemImage: "lock.shield") }
                }

                Section {
                    Button(role: .destructive) { hoiDangXuat = true } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    NavigationLink { XoaTaiKhoanCTW() } label: {
                        Label("Delete account", systemImage: "person.crop.circle.badge.minus").foregroundColor(AppColors.error)
                    }
                } footer: {
                    Text("CT Work \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                }
            }
            .navigationTitle("Account")
            .confirmationDialog("Sign out of CT Work?", isPresented: $hoiDangXuat, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { app.logout() }
            }
            #if DEBUG
            .onAppear { if XemThuCTW.man?.lowercased() == "chonduan" { tamPhu = .chonDuAn } }
            #endif
            .sheet(item: $tamPhu) { t in
                switch t {
                case .phapLy(let p): NavigationStack { TrangPhapLyView(trang: p) }
                case .chonDuAn: ChonDuAnCTW()
                case .web(let u): SafariCTW(url: u).ignoresSafeArea()
                }
            }
        }
    }
}

// MARK: - Danh sách chặn + nội dung đã ẩn (1.2)

struct DanhSachChanCTW: View {
    @ObservedObject private var kd = ModerationStore.shared
    @ObservedObject private var an = AnNoiDungCTW.shared
    @State private var loi: String?

    var body: some View {
        List {
            if let loi { Section { CTWErrorBanner(text: loi) } }
            Section {
                if kd.blockedUsers.isEmpty {
                    Text("You haven't blocked anyone.").foregroundColor(AppColors.textSecondary)
                }
                ForEach(kd.blockedUsers) { u in
                    HStack(spacing: 12) {
                        CTWAvatar(user: CTWUser(id: u.id, username: u.username, displayName: u.displayName, avatarUrl: u.avatarUrl), size: 34)
                        VStack(alignment: .leading) {
                            Text(u.displayName).foregroundColor(AppColors.textPrimary)
                            Text("@\(u.username)").font(.caption).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Button("Unblock") {
                            Task { do { try await kd.unblock(userId: u.id) } catch { loi = CTW.loi(error) } }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: { Text("Blocked users") } footer: {
                Text("Comments and chat messages from blocked users are hidden everywhere in the app.")
            }
            Section {
                let n = an.tinAn.count + an.binhLuanAn.count
                Text(n == 0 ? "Nothing hidden." : n == 1 ? "1 reported item hidden" : "\(n) reported items hidden")
                    .foregroundColor(AppColors.textSecondary)
                if n > 0 {
                    Button("Show hidden content again") { an.boAnHet() }
                }
            } header: { Text("Hidden content") } footer: {
                Text("Content you report is hidden for you immediately.")
            }
        }
        .navigationTitle("Blocked users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await kd.refreshBlocks() }
        .refreshable { await kd.refreshBlocks() }
    }
}

// MARK: - Xoá tài khoản (5.1.1(v)) — cùng luồng máy chủ với app chính

private struct YeuCauXoa: Codable {
    var id: Int
    var status: String
    var reason: String?
    var createdAt: String?
}
private struct GoiYeuCauXoa: Codable { var request: YeuCauXoa? }

struct XoaTaiKhoanCTW: View {
    @State private var yc: YeuCauXoa?
    @State private var lyDo = ""
    @State private var dangTai = true
    @State private var dangGui = false
    @State private var loi: String?
    @State private var hoi = false

    var body: some View {
        List {
            if dangTai {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            } else if let yc, yc.status == "PENDING" {
                Section {
                    Label("Your account is scheduled for deletion \(han(yc)).", systemImage: "clock.fill")
                        .foregroundColor(AppColors.warning)
                } footer: {
                    Text("Your account and personal data will be permanently deleted 72 hours after the request. Until then you can keep using CT Work and cancel the request.")
                }
                Section {
                    Button { Task { await huy() } } label: {
                        HStack { Spacer(); if dangGui { ProgressView() } else { Text("Cancel deletion request") }; Spacer() }
                    }
                    .disabled(dangGui)
                }
            } else {
                Section("What happens") {
                    dong("Your profile, comments, chat messages and files you uploaded are removed from the service.")
                    dong("Your email and username are disabled and can't be reused.")
                    dong("You are signed out everywhere — on the web and in every app.")
                    dong("This applies to your whole cuongthai.com account and can't be undone.")
                }
                Section("Reason (optional)") {
                    TextField("Why are you leaving?", text: $lyDo, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    Button(role: .destructive) { hoi = true } label: {
                        HStack { Spacer(); if dangGui { ProgressView() } else { Text("Delete my account") }; Spacer() }
                    }
                    .disabled(dangGui)
                } footer: {
                    Text("Need help instead? Contact \(LienHeCTW.email)")
                }
            }
            if let loi { Section { Text(loi).foregroundColor(AppColors.error) } }
        }
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
        .task { await tai() }
        .alert("Permanently delete your account?", isPresented: $hoi) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await gui() } }
        } message: {
            Text("72 hours after you confirm, your account and personal data are deleted and can't be recovered. You can cancel within those 72 hours.")
        }
    }

    private func dong(_ s: LocalizedStringKey) -> some View {
        Label { Text(s).font(.ctw(size: 14)) } icon: { Image(systemName: "circle.fill").font(.ctw(size: 6)) }
    }

    private func han(_ r: YeuCauXoa) -> String {
        guard let s = r.createdAt else { return String(localized: "in 72 hours") }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: s) ?? ISO8601DateFormatter().date(from: s) else { return String(localized: "in 72 hours") }
        let h = d.addingTimeInterval(72 * 3600)
        let ngay = CTWDinhDang.mau("MMMd").string(from: h)
        let gio = CTWDinhDang.gio(h)
        return String(localized: "on \(ngay) at \(gio)")
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            let g: GoiYeuCauXoa = try await APIClient.shared.request(.getDeletionRequest)
            yc = g.request
        } catch { loi = CTW.loi(error) }
    }

    private func gui() async {
        dangGui = true
        defer { dangGui = false }
        loi = nil
        struct KQ: Codable { var request: YeuCauXoa }
        do {
            let t = lyDo.trimmingCharacters(in: .whitespacesAndNewlines)
            let k: KQ = try await APIClient.shared.request(.requestDeletion(reason: t.isEmpty ? nil : t))
            yc = k.request
        } catch { loi = CTW.loi(error) }
    }

    private func huy() async {
        dangGui = true
        defer { dangGui = false }
        do {
            let g: GoiYeuCauXoa = try await APIClient.shared.request(.cancelDeletionRequest)
            yc = g.request?.status == "PENDING" ? g.request : nil
        } catch { loi = CTW.loi(error) }
    }
}
