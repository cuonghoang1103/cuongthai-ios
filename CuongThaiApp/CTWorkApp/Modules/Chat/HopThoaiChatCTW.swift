import SwiftUI

// MARK: - Các tấm phủ của kênh chat
//
// ThongTinKenhCTW (thành viên + online, chế độ báo, tắt tiếng, đổi tên/chủ đề, lưu trữ,
// thêm/bớt người ở nhóm riêng) · TimTinCTW · TinGhimCTW · ChuyenTiepTinCTW ·
// TheTuTinCTW · ChonCamXucCTW · TaoKenhCTW.

// MARK: Thông tin kênh

struct ThongTinKenhCTW: View {
    @ObservedObject var vm: KenhChatVM
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var baoMoi: String = "DEFAULT"
    @State private var ten = ""
    @State private var chuDe = ""
    @State private var loi: String?
    @State private var dangLuu = false
    @State private var hoiLuuTru = false
    @State private var moThem = false
    @State private var chonThem: Set<Int> = []

    private var kenh: CTWChannel { vm.kenh }

    var body: some View {
        NavigationStack {
            Form {
                if let loi { Section { CTWErrorBanner(text: loi) { self.loi = nil } }.listRowBackground(Color.clear) }
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: kenh.bieuTuong).font(.ctw(size: 18, weight: .semibold)).foregroundColor(AppColors.primary)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(AppColors.primary.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kenh.laRieng ? kenh.name : "#\(kenh.name)").font(.ctw(size: 17, weight: .bold))
                            Text(kenh.laRieng ? "Private group" : (kenh.laKhach ? "Client channel" : "Public channel"))
                                .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    if let t = kenh.topic, !t.isEmpty { Text(t).font(.ctw(size: 14)).foregroundColor(AppColors.textSecondary) }
                }

                Section {
                    Picker("Notify me about", selection: $baoMoi) {
                        Text("Default").tag("DEFAULT")
                        Text("All new messages").tag("ALL")
                        Text("Mentions only").tag("MENTIONS")
                    }
                    .onChange(of: baoMoi) { _, v in
                        guard v != (kenh.notify ?? "DEFAULT") else { return }
                        Task { await luuBao(["notify": v]) }
                    }
                    Menu {
                        ForEach([("30m", "30 minutes"), ("1h", "1 hour"), ("8h", "8 hours"), ("tomorrow", "Until tomorrow"), ("forever", "Until I turn it back on")], id: \.0) { m in
                            Button(m.1) { Task { await luuBao(["mute": m.0]) } }
                        }
                        if kenh.muted == true {
                            Divider()
                            Button("Unmute") { Task { await luuBao(["mute": "off"]) } }
                        }
                    } label: {
                        HStack {
                            Label(kenh.muted == true ? "Muted" : "Mute channel", systemImage: kenh.muted == true ? "bell.slash.fill" : "bell.slash")
                            Spacer()
                            if kenh.muted == true {
                                Text(kenh.mutedForever == true ? "Until you unmute" : (CTWChatThoiGian.date(kenh.mutedUntil).map { "Until \(CTWChatThoiGian.gio(ISO8601DateFormatter().string(from: $0)))" } ?? ""))
                                    .font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                } header: { Text("Notifications") } footer: {
                    Text("Muted channels only notify you when someone @mentions you.")
                }

                if kenh.canManage == true {
                    Section("Channel details") {
                        TextField("Name", text: $ten).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Topic (optional)", text: $chuDe, axis: .vertical).lineLimit(1...3)
                        Button("Save details") { Task { await luuChiTiet() } }
                            .disabled(dangLuu || (ten == kenh.name && chuDe == (kenh.topic ?? "")) || ten.trimmingCharacters(in: .whitespaces).count < 2)
                    }
                }

                Section {
                    ForEach(vm.thanhVien) { m in
                        HStack(spacing: 10) {
                            ZStack(alignment: .bottomTrailing) {
                                CTWAvatar(user: m.nguoi, size: 32)
                                if m.online == true {
                                    Circle().fill(AppColors.success).frame(width: 10, height: 10)
                                        .overlay(Circle().strokeBorder(AppColors.backgroundCard, lineWidth: 1.5))
                                }
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    Text(m.id == app.currentUser?.id ? "\(m.nguoi.ten) (you)" : m.nguoi.ten).font(.ctw(size: 15))
                                    if m.nguoi.laAgent { CTWNhanAI() }
                                }
                                Text([m.username.map { "@\($0)" }, m.role?.capitalized, m.online == true ? "Online" : nil].compactMap { $0 }.joined(separator: " · "))
                                    .font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .swipeActions {
                            if kenh.laRieng && kenh.canManage == true && m.id != app.currentUser?.id {
                                Button("Remove", role: .destructive) { Task { await doiThanhVien(them: [], bot: [m.id]) } }
                            }
                        }
                    }
                    if kenh.laRieng && kenh.canManage == true {
                        Button { chonThem = []; moThem = true } label: { Label("Add people", systemImage: "person.badge.plus") }
                    }
                } header: { Text("Members (\(vm.thanhVien.count))") }

                if kenh.canManage == true && kenh.isGeneral != true {
                    Section {
                        Button(kenh.archived == true ? "Restore channel" : "Archive channel", role: kenh.archived == true ? nil : .destructive) {
                            if kenh.archived == true { Task { await luuTru(false) } } else { hoiLuuTru = true }
                        }
                    } footer: { Text("Archived channels become read-only. History is kept.") }
                }
            }
            .navigationTitle("Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
            .confirmationDialog("Archive #\(kenh.name)?", isPresented: $hoiLuuTru, titleVisibility: .visible) {
                Button("Archive", role: .destructive) { Task { await luuTru(true) } }
            }
            .sheet(isPresented: $moThem) {
                let co = Set(vm.thanhVien.map(\.id))
                CTWChonNguoiView(ds: (app.cauHinhDuAn?.dsThanhVien ?? []).filter { !co.contains($0.id) && $0.role != "CLIENT" },
                                 toi: app.currentUser?.id, nhieu: true, choPhepTrong: false, chon: $chonThem) {
                    let ids = Array(chonThem)
                    Task { await doiThanhVien(them: ids, bot: []) }
                }
            }
            .task {
                baoMoi = kenh.notify ?? "DEFAULT"
                ten = kenh.name
                chuDe = kenh.topic ?? ""
                if vm.thanhVien.isEmpty { await vm.taiThanhVien() }
            }
        }
    }

    private func luuBao(_ than: [String: Any]) async {
        do {
            let kq: CTWKenhBao = try await APIClient.shared.request(CTWAPI.baoKenh(pid: vm.pid, cid: kenh.id, than))
            vm.kenh.notify = kq.notify ?? vm.kenh.notify
            vm.kenh.mutedUntil = kq.mutedUntil
            vm.kenh.mutedForever = kq.mutedForever
            vm.kenh.muted = kq.mutedUntil != nil || kq.mutedForever == true
            CTWRung.thanhCong()
            await AppState.shared.taiSoChuaDoc()
        } catch { loi = CTW.loi(error) }
    }

    private func luuChiTiet() async {
        dangLuu = true
        defer { dangLuu = false }
        do {
            try await APIClient.shared.send(CTWAPI.suaKenh(pid: vm.pid, cid: kenh.id, ["name": ten.trimmingCharacters(in: .whitespaces), "topic": chuDe.isEmpty ? NSNull() : chuDe]))
            vm.kenh.name = ten.trimmingCharacters(in: .whitespaces).lowercased()
            vm.kenh.topic = chuDe.isEmpty ? nil : chuDe
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error) }
    }

    private func luuTru(_ bat: Bool) async {
        do {
            try await APIClient.shared.send(CTWAPI.suaKenh(pid: vm.pid, cid: kenh.id, ["archived": bat]))
            vm.kenh.archived = bat
            CTWRung.thanhCong()
        } catch { loi = CTW.loi(error) }
    }

    private func doiThanhVien(them: [Int], bot: [Int]) async {
        do {
            try await APIClient.shared.send(CTWAPI.doiThanhVienKenh(pid: vm.pid, cid: kenh.id, them: them, bot: bot))
            await vm.taiThanhVien()
        } catch { loi = CTW.loi(error) }
    }
}

// MARK: Tìm trong kênh

struct TimTinCTW: View {
    let pid: Int
    let kenh: CTWChannel
    let chon: (CTWChatMessage) -> Void
    @Environment(\.dismiss) private var dong
    @EnvironmentObject private var app: AppState
    @State private var q = ""
    @State private var kq: [CTWChatMessage] = []
    @State private var dangTim = false
    @State private var daTim = false

    var body: some View {
        NavigationStack {
            List {
                if daTim && kq.isEmpty && !dangTim {
                    CTWOTrong(bieuTuong: "magnifyingglass", tieuDe: "No results", moTa: "Try another word. Search covers messages, file names and voice-note transcripts.")
                        .listRowBackground(Color.clear)
                }
                ForEach(kq) { m in
                    Button { chon(m); dong() } label: {
                        TinChatCTW(tin: m, pid: pid).allowsHitTesting(false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay { if dangTim { ProgressView() } }
            .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search #\(kenh.name)")
            .onSubmit(of: .search) { Task { await tim() } }
            .task(id: q) {
                try? await Task.sleep(nanoseconds: 400_000_000)
                await tim()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
    }

    private func tim() async {
        let s = q.trimmingCharacters(in: .whitespaces)
        guard s.count >= 2 else { kq = []; daTim = false; return }
        dangTim = true
        defer { dangTim = false; daTim = true }
        kq = (try? await APIClient.shared.request(CTWAPI.timTin(pid: pid, cid: kenh.id, q: s)) as [CTWChatMessage]) ?? []
    }
}

// MARK: Tin ghim

struct TinGhimCTW: View {
    let pid: Int
    let kenh: CTWChannel
    let chon: (CTWChatMessage) -> Void
    @Environment(\.dismiss) private var dong
    @EnvironmentObject private var app: AppState
    @State private var ds: [CTWChatMessage]?
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            List {
                if let loi { CTWErrorBanner(text: loi).listRowBackground(Color.clear) }
                if let ds, ds.isEmpty {
                    CTWOTrong(bieuTuong: "pin", tieuDe: "No pinned messages", moTa: "Touch and hold a message, then choose Pin to channel.")
                        .listRowBackground(Color.clear)
                }
                ForEach(ds ?? []) { m in
                    Button { chon(m); dong() } label: { TinChatCTW(tin: m, pid: pid).allowsHitTesting(false) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            if kenh.canPost != false {
                                Button("Unpin") { Task { await boGhim(m) } }.tint(AppColors.warning)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .overlay { if ds == nil && loi == nil { ProgressView() } }
            .navigationTitle("Pinned")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
            .task { await tai() }
        }
    }

    private func tai() async {
        do { ds = try await APIClient.shared.request(CTWAPI.tinGhim(pid: pid, cid: kenh.id)) } catch { loi = CTW.loi(error) }
    }

    private func boGhim(_ m: CTWChatMessage) async {
        do {
            let _: CTWPinKQ = try await APIClient.shared.request(CTWAPI.ghimTin(pid: pid, cid: kenh.id, mid: m.id, ghim: false))
            ds?.removeAll { $0.id == m.id }
        } catch { loi = CTW.loi(error) }
    }
}

// MARK: Chuyển tiếp

struct ChuyenTiepTinCTW: View {
    let pid: Int
    let tuKenh: CTWChannel
    let tin: CTWChatMessage
    let xong: (String) -> Void
    @Environment(\.dismiss) private var dong
    @State private var kenh: [CTWChannel] = []
    @State private var chon: Int?
    @State private var ghiChu = ""
    @State private var loi: String?
    @State private var dangGui = false

    var body: some View {
        NavigationStack {
            Form {
                if let loi { CTWErrorBanner(text: loi) }
                Section("Message") {
                    Text(tin.body ?? (tin.files?.first?.fileName ?? "Attachment")).font(.ctw(size: 14)).lineLimit(4)
                        .foregroundColor(AppColors.textSecondary)
                }
                Section("Send to") {
                    ForEach(kenh.filter { $0.id != tuKenh.id && $0.canPost != false && $0.archived != true }) { k in
                        Button { chon = k.id } label: {
                            HStack {
                                Label(k.laRieng ? k.name : "#\(k.name)", systemImage: k.bieuTuong).foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if chon == k.id { Image(systemName: "checkmark").foregroundColor(AppColors.primary) }
                            }
                        }
                    }
                }
                Section("Note (optional)") { TextField("Add a note…", text: $ghiChu, axis: .vertical).lineLimit(1...4) }
            }
            .navigationTitle("Forward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await gui() } }.bold().disabled(chon == nil || dangGui)
                }
            }
            .task {
                if let ds: CTWChannelList = try? await APIClient.shared.request(CTWAPI.dsKenh(pid: pid)) { kenh = ds.channels ?? [] }
            }
        }
    }

    private func gui() async {
        guard let chon else { return }
        dangGui = true
        defer { dangGui = false }
        do {
            try await APIClient.shared.send(CTWAPI.chuyenTiep(pid: pid, cid: tuKenh.id, mid: tin.id, toi: chon, ghiChu: ghiChu))
            CTWRung.thanhCong()
            let ten = kenh.first { $0.id == chon }?.name ?? ""
            dong()
            xong("Forwarded to #\(ten).")
        } catch { loi = CTW.loi(error) }
    }
}

// MARK: Tạo thẻ từ tin

struct TheTuTinCTW: View {
    let pid: Int
    let kenh: CTWChannel
    let tin: CTWChatMessage
    let xong: (String) -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var loai: Int?
    @State private var tieuDe = ""
    @State private var loi: String?
    @State private var dangTao = false

    private var dsLoai: [CTWIssueType] { (app.cauHinhDuAn?.dsLoai ?? []).filter { ($0.level ?? 0) == 0 } }

    var body: some View {
        NavigationStack {
            Form {
                if let loi { CTWErrorBanner(text: loi) }
                Section("Title") { TextField("Issue title", text: $tieuDe, axis: .vertical).lineLimit(1...3) }
                Section("Type") {
                    Picker("Type", selection: $loai) {
                        ForEach(dsLoai) { t in
                            Label(t.name, systemImage: CTW.bieuTuongLoai(t)).tag(Optional(t.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Text(tin.body ?? "").font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(6)
                } header: { Text("Description") } footer: {
                    Text("The message and a link back to it become the issue description. A note is posted in the thread.")
                }
            }
            .navigationTitle("Create issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await tao() } }.bold().disabled(loai == nil || dangTao)
                }
            }
            .onAppear {
                if loai == nil { loai = (dsLoai.first { $0.key == "TASK" } ?? dsLoai.first)?.id }
                if tieuDe.isEmpty { tieuDe = String((tin.body ?? "").split(separator: "\n").first ?? "").prefix(120).description }
            }
        }
    }

    private func tao() async {
        guard let loai else { return }
        dangTao = true
        defer { dangTao = false }
        do {
            let kq: CTWTheTuTinKQ = try await APIClient.shared.request(CTWAPI.theTuTin(pid: pid, cid: kenh.id, mid: tin.id, loai: loai, tieuDe: tieuDe))
            CTWRung.thanhCong()
            dong()
            xong("Created \(kq.key ?? "the issue").")
        } catch { loi = CTW.loi(error) }
    }
}

// MARK: Chọn cảm xúc

struct ChonCamXucCTW: View {
    let chon: (String) -> Void
    @Environment(\.dismiss) private var dong
    private let nhom: [(String, [String])] = [
        ("Frequently used", ["👍", "❤️", "😂", "🎉", "👀", "🙏", "✅", "🔥"]),
        ("Smileys", ["😀", "😄", "😊", "😍", "🤩", "😎", "🤔", "😅", "😢", "😮", "😴", "🤯"]),
        ("Work", ["🚀", "💯", "👏", "🙌", "💪", "🤝", "📌", "📝", "🐛", "⚠️", "❓", "⏳", "☕️", "🍕"]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(nhom, id: \.0) { n in
                        Text(n.0).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                            ForEach(n.1, id: \.self) { e in
                                Button { chon(e); dong() } label: {
                                    Text(e).font(.ctw(size: 28)).frame(width: 46, height: 46)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle("Add reaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: Tạo kênh / nhóm riêng

struct TaoKenhCTW: View {
    let pid: Int
    var rieng: Bool
    let xong: (CTWKenhMoi) -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var chuDe = ""
    @State private var chon: Set<Int> = []
    @State private var loi: String?
    @State private var dangTao = false
    @State private var tim = ""

    private var nguoi: [CTWUser] {
        (app.cauHinhDuAn?.dsThanhVien ?? []).filter { $0.id != app.currentUser?.id && $0.role != "CLIENT" }
            .filter { tim.isEmpty || $0.ten.localizedCaseInsensitiveContains(tim) }
    }

    private var tenHopLe: Bool {
        let s = ten.trimmingCharacters(in: .whitespaces)
        return s.count >= 2 && s.count <= 40
    }

    var body: some View {
        NavigationStack {
            Form {
                if let loi { CTWErrorBanner(text: loi) }
                Section {
                    TextField(rieng ? "e.g. design-review" : "e.g. release-planning", text: $ten)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Topic (optional)", text: $chuDe, axis: .vertical).lineLimit(1...3)
                } header: { Text("Name") } footer: {
                    Text("2–40 letters, numbers or dashes. Spaces become dashes.")
                }
                if rieng {
                    Section {
                        TextField("Search people", text: $tim)
                        ForEach(nguoi) { u in
                            Button {
                                if chon.contains(u.id) { chon.remove(u.id) } else { chon.insert(u.id) }
                            } label: {
                                HStack(spacing: 10) {
                                    CTWAvatar(user: u, size: 28)
                                    Text(u.ten).foregroundColor(AppColors.textPrimary)
                                    if u.laAgent { CTWNhanAI() }
                                    Spacer()
                                    Image(systemName: chon.contains(u.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(chon.contains(u.id) ? AppColors.primary : AppColors.textTertiary)
                                }
                            }
                            .accessibilityAddTraits(chon.contains(u.id) ? .isSelected : [])
                        }
                    } header: { Text("Members (\(chon.count) selected)") } footer: {
                        Text("Only the people you add can see a private group.")
                    }
                }
            }
            .navigationTitle(rieng ? "New private group" : "New channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await tao() } }.bold().disabled(!tenHopLe || dangTao || (rieng && chon.isEmpty))
                }
            }
        }
    }

    private func tao() async {
        dangTao = true
        defer { dangTao = false }
        do {
            let k: CTWKenhMoi = try await APIClient.shared.request(
                CTWAPI.taoKenh(pid: pid, ten: ten.trimmingCharacters(in: .whitespaces), chuDe: chuDe.trimmingCharacters(in: .whitespacesAndNewlines),
                               kieu: rieng ? "PRIVATE" : "PUBLIC", thanhVien: Array(chon)))
            CTWRung.thanhCong()
            dong()
            xong(k)
        } catch { loi = CTW.loi(error) }
    }
}
