import SwiftUI

// MARK: - Tin nhắn riêng — danh sách hội thoại (Messenger chung web + app chính)
//
// Hàng: avatar + chấm hoạt động · tên · dòng tin cuối ("Bạn: …") · giờ · số chưa đọc (đậm khi chưa đọc). Bút soạn ⇒
// chọn một thành viên. `kho.canMo` (thông báo đẩy / "Nhắn tin" ở hồ sơ) ⇒ đẩy thẳng màn chat.

struct DanhSachTinNhanCTW: View {
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @ObservedObject private var kd = ModerationStore.shared
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    @State private var tim = ""
    @State private var chonNguoi = false
    @State private var bayGio = Date()

    private var ds: [MessageThread] {
        let t = tim.trimmingCharacters(in: .whitespaces)
        return kho.hoiThoai
            .filter { !kd.blockedUserIds.contains($0.peer?.id ?? -1) }
            .filter { t.isEmpty || tenHoiThoai($0).localizedCaseInsensitiveContains(t) }
    }

    var body: some View {
        List {
            ForEach(ds) { t in
                NavigationLink(value: RouteChatRiengCTW(threadId: t.id)) {
                    HangHoiThoaiCTW(t: t, ten: tenHoiThoai(t), moc: t.peer.map { kho.moc($0.id, mocHoiThoai: $0.lastActiveAt, bayGio: bayGio) } ?? .an,
                                    dangGo: !(kho.dangGo[t.id] ?? []).isEmpty, toi: app.currentUser?.id)
                }
                .accessibilityIdentifier("dm.\(t.id)")
            }
        }
        .listStyle(.plain)
        .overlay {
            if !kho.daTaiHoiThoai && kho.hoiThoai.isEmpty {
                CTWKhungTai()
            } else if let l = kho.loiHoiThoai, kho.hoiThoai.isEmpty {
                CTWOLoi(loi: l) { Task { await kho.taiHoiThoai() } }
            } else if ds.isEmpty {
                CTWOTrong(bieuTuong: "bubble.left.and.text.bubble.right", tieuDe: String(localized: "No messages yet"),
                          moTa: String(localized: "Message a teammate from Members."),
                          nut: String(localized: "New message")) { chonNguoi = true }
            }
        }
        .searchable(text: $tim, prompt: "Search messages")
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { chonNguoi = true } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("New message")
            }
        }
        .refreshable { await kho.taiHoiThoai() }
        .task {
            if kho.danhBa.isEmpty { await kho.taiDanhBa() }
            while !Task.isCancelled {
                await kho.taiHoiThoai()
                bayGio = Date()
                try? await Task.sleep(for: .seconds(45))
            }
        }
        // Hội thoại cần mở (thông báo đẩy / hồ sơ) ⇒ đẩy màn chat, xoá cờ ở CUỐI (KIEN_TRUC mục 6).
        .task(id: kho.canMo) {
            guard let id = kho.canMo else { return }
            defer { kho.canMo = nil }
            nganXep.veDau()
            try? await Task.sleep(for: .milliseconds(120))
            nganXep.duong.append(RouteChatRiengCTW(threadId: id))
        }
        #if DEBUG
        .onAppear { if XemThuCTW.conCua("tin-nhan") == "chat", nganXep.duong.isEmpty { kho.canMo = 101 } }
        #endif
        .sheet(isPresented: $chonNguoi) { ChonNguoiNhanTinCTW() }
    }

    private func tenHoiThoai(_ t: MessageThread) -> String {
        if t.laHoTro && t.peer == nil { return String(localized: "CuongThai support") }
        if let p = t.peer, let n = kho.thanhVien(p.id), t.bietDanh == nil { return n.ten }
        return t.peer?.displayName ?? t.peer?.username ?? String(localized: "User")
    }
}

/// Một hàng hội thoại.
///
/// ⚠️ KHÔNG giữ `MessageThread` làm thuộc tính: `MessageThread ==` chỉ so `id` (để `navigationDestination(item:)` không
/// đẩy lại màn khi tin mới về) ⇒ SwiftUI so hàng cũ/mới bằng `==`, thấy "bằng nhau" và KHÔNG vẽ lại — dòng tin cuối +
/// giờ đứng nguyên "Say hi 👋 · Wed" sau khi gửi tin cho tới lần mở app sau (ảnh lỗi 08, 22/10/2026), dù kho đã có
/// tin mới. App chính né cùng bẫy bằng `.id(...)` ở MessagesView. Ở đây hàng chỉ giữ GIÁ TRỊ đã rút ra (so sánh đủ).
struct HangHoiThoaiCTW: View {
    let ten: String
    let moc: TrangThaiHoatDongCTW.Moc
    var dangGo = false
    private let nguoi: CTWUser
    private let chuaDoc: Bool
    private let soChuaDoc: Int
    private let tatThongBao: Bool
    private let thoiDiem: Date?
    private let xemTruoc: String

    init(t: MessageThread, ten: String, moc: TrangThaiHoatDongCTW.Moc, dangGo: Bool = false, toi: Int? = nil) {
        self.ten = ten
        self.moc = moc
        self.dangGo = dangGo
        nguoi = CTWUser(id: t.peer?.id ?? 0, username: t.peer?.username, displayName: ten, avatarUrl: t.peer?.avatarUrl)
        chuaDoc = t.chuaDoc
        soChuaDoc = t.unreadCount
        tatThongBao = t.daTatThongBao
        thoiDiem = t.lastMessage?.ngayGio ?? t.updatedAt.flatMap(Date.tuChuoiISO)
        xemTruoc = Self.xemTruoc(t.lastMessage, toi: toi)
    }

    static func xemTruoc(_ m: Message?, toi: Int?) -> String {
        guard let m else { return String(localized: "Say hi 👋") }
        let tom = ChatRiengCTW.tomTat(m)
        return m.senderId == toi ? String(localized: "You: \(tom)") : tom
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarHoatDongCTW(user: nguoi, size: 52, moc: moc)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(ten).font(.ctw(size: 16, weight: chuaDoc ? .bold : .semibold)).foregroundColor(AppColors.textPrimary).lineLimit(1)
                    if tatThongBao { Image(systemName: "bell.slash.fill").font(.ctw(size: 11)).foregroundColor(AppColors.textTertiary) }
                    Spacer(minLength: 4)
                    if let d = thoiDiem {
                        Text(ChatRiengCTW.gioNgan(d)).font(.ctw(size: 12)).foregroundColor(chuaDoc ? AppColors.primary : AppColors.textTertiary)
                    }
                }
                HStack {
                    Text(dangGo ? String(localized: "typing…") : xemTruoc)
                        .font(.ctw(size: 14, weight: chuaDoc ? .semibold : .regular))
                        .foregroundColor(dangGo ? AppColors.primary : (chuaDoc ? AppColors.textPrimary : AppColors.textSecondary))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if soChuaDoc > 0 {
                        Text("\(soChuaDoc)").font(.ctw(size: 12, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.primary))
                    } else if chuaDoc {
                        Circle().fill(AppColors.primary).frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chọn người để nhắn

struct ChonNguoiNhanTinCTW: View {
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @Environment(\.dismiss) private var dong
    @State private var tim = ""
    @State private var loi: String?
    @State private var dangMo: Int?

    var body: some View {
        NavigationStack {
            List {
                if let loi { CTWErrorBanner(text: loi) }
                ForEach(kho.danhBaDaSap(tim: tim).filter { !$0.laAgent && $0.blocked != true }) { n in
                    Button { Task { await mo(n.id) } } label: {
                        HStack {
                            HangThanhVienCTW(n: n, moc: kho.moc(n.id))
                            if dangMo == n.id { ProgressView() }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(dangMo != nil)
                }
            }
            .searchable(text: $tim, prompt: "Search members")
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dong() } } }
            .task { if kho.danhBa.isEmpty { await kho.taiDanhBa() } }
        }
    }

    private func mo(_ id: Int) async {
        dangMo = id; loi = nil
        defer { dangMo = nil }
        do {
            let t = try await kho.moVoi(id)
            dong()
            try? await Task.sleep(for: .milliseconds(350))
            kho.moHoiThoai(t.id)
        } catch { loi = CTW.loi(error) }
    }
}
