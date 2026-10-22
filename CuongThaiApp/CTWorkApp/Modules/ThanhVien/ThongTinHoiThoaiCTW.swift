import SwiftUI

// MARK: - Thông tin hội thoại (nút ⓘ trên đầu khung chat — như "Thông tin" của Messenger)
//
// Hồ sơ · biệt danh (`PUT /threads/:id/nickname`) · tắt thông báo theo thời lượng (`mute-for`) · chặn/bỏ chặn ·
// báo cáo (1.2) · xoá cuộc trò chuyện CHỈ phía tôi (`DELETE /threads/:id/hard` — người kia vẫn giữ).

struct ThongTinHoiThoaiCTW: View {
    let threadId: Int
    let peerId: Int?
    let tenKia: String
    let nguoi: CTWUser
    let moc: TrangThaiHoatDongCTW.Moc
    let moHoSo: () -> Void
    let baoCao: () -> Void
    let daXoa: () -> Void
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @ObservedObject private var kd = ModerationStore.shared
    @Environment(\.dismiss) private var dong
    @State private var suaBietDanh = false
    @State private var bietDanh = ""
    @State private var hoiChan = false
    @State private var hoiXoa = false
    @State private var loi: String?

    private var t: MessageThread? { kho.hoiThoai(threadId) }
    private var daChan: Bool { peerId.map { kd.blockedUserIds.contains($0) } ?? false }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        AvatarHoatDongCTW(user: nguoi, size: 84, moc: moc)
                        Text(verbatim: tenKia).font(.ctw(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        let c = TrangThaiHoatDongCTW.chu(moc)
                        if !c.isEmpty { Text(c).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary) }
                        HStack(spacing: 22) {
                            nutTron("person.crop.circle", String(localized: "Profile")) { dong(); moHoSo() }
                                .accessibilityIdentifier("dminfo.profile")
                            Menu {
                                if t?.daTatThongBao == true {
                                    Button { Task { await tat(0) } } label: { Label("Unmute", systemImage: "bell") }
                                }
                                ForEach(TatThongBaoCTW.allCases) { m in Button(m.nhan) { Task { await tat(m.phut) } } }
                            } label: {
                                cotNut(t?.daTatThongBao == true ? "bell.slash.fill" : "bell.fill",
                                       t?.daTatThongBao == true ? String(localized: "Muted") : String(localized: "Mute"))
                            }
                            .accessibilityIdentifier("dminfo.mute")
                        }
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                if let loi { Section { CTWErrorBanner(text: loi) } }
                Section("Customize") {
                    Button { bietDanh = t?.bietDanh ?? ""; suaBietDanh = true } label: {
                        HStack {
                            Label("Nickname", systemImage: "character.cursor.ibeam")
                            Spacer()
                            Text(verbatim: t?.bietDanh ?? String(localized: "None")).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .disabled(peerId == nil)
                }
                Section {
                    if daChan {
                        Button { Task { if let p = peerId { try? await kd.unblock(userId: p) } } } label: { Label("Unblock", systemImage: "hand.raised.slash") }
                    } else {
                        Button(role: .destructive) { hoiChan = true } label: { Label("Block", systemImage: "hand.raised") }.disabled(peerId == nil)
                    }
                    Button(role: .destructive) { dong(); baoCao() } label: { Label("Report conversation", systemImage: "exclamationmark.bubble") }
                    Button(role: .destructive) { hoiXoa = true } label: { Label("Delete conversation", systemImage: "trash") }
                        .accessibilityIdentifier("dminfo.delete")
                } header: { Text("Privacy & support") } footer: {
                    Text("Deleting removes the conversation for you only; \(TenNguoi.tenNgan(tenKia)) keeps their copy.")
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
            .alert("Nickname", isPresented: $suaBietDanh) {
                TextField(tenKia, text: $bietDanh)
                Button("Save") { Task { await luuBietDanh() } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Only you see the nickname you set.") }
            .confirmationDialog("Block \(tenKia)?", isPresented: $hoiChan, titleVisibility: .visible) {
                Button("Block", role: .destructive) {
                    Task { if let p = peerId { try? await kd.block(userId: p, reason: nil); await kho.taiDanhBa() } }
                }
            } message: { Text("They won't be able to message you, and you won't see their active status.") }
            .confirmationDialog("Delete this conversation?", isPresented: $hoiXoa, titleVisibility: .visible) {
                Button("Delete for me", role: .destructive) { Task { await xoa() } }
            } message: { Text("It disappears from your inbox. You can restore it from Messages › Deleted on cuongthai.com.") }
        }
    }

    private func cotNut(_ bt: String, _ nhan: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: bt).font(.ctw(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                .frame(width: 44, height: 44).background(Circle().fill(AppColors.backgroundSecondary))
            Text(verbatim: nhan).font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary)
        }
    }

    private func nutTron(_ bt: String, _ nhan: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { cotNut(bt, nhan) }.buttonStyle(.plain)
    }

    private func tat(_ phut: Int?) async {
        do { try await kho.tatThongBao(threadId, phut: phut) } catch { loi = CTW.loi(error) }
    }

    private func luuBietDanh() async {
        guard let p = peerId else { return }
        do { try await kho.datBietDanh(threadId, nguoi: p, ten: bietDanh) } catch { loi = CTW.loi(error) }
    }

    private func xoa() async {
        do { try await kho.xoaPhiaToi(threadId); dong(); daXoa() } catch { loi = CTW.loi(error) }
    }
}
