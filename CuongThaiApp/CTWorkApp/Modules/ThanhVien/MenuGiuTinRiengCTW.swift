import SwiftUI
import Kingfisher

// MARK: - Nhấn giữ một tin (22/10/2026 — bản 1.1, kiểu Messenger)
//
// Nền mờ + thanh cảm xúc nhanh (❤️😂😮😢😡👍 + "＋" bảng emoji đầy đủ) + bản xem trước tin + thẻ thao tác:
// Trả lời · Sao chép · Chuyển tiếp · Lưu ảnh · Thu hồi (tin của tôi, ≤ 5 phút — luật máy chủ) · Báo cáo (tin người khác, 1.2).
// Không có "Sửa": Messenger chung (`messages.routes.ts`) chưa có đường sửa tin — xem KIEN_TRUC §23.

enum ThaoTacGiuCTW: Equatable {
    case camXuc(String), themCamXuc, traLoi, chep, chuyenTiep, luuAnh, thuHoi, baoCao
}

struct MenuGiuTinRiengCTW: View {
    let m: Message
    let cuaToi: Bool
    let nguoiKia: CTWUser
    let tenKia: String
    let toi: Int?
    let chon: (ThaoTacGiuCTW) -> Void
    let dong: () -> Void
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong
    @State private var hien = false

    private var cua: Set<String> { CamXucCTW.cuaToi(m.reactions ?? [], toi: toi) }
    private var coAnh: Bool { !TomTatTinCTW.anhTep(m).isEmpty }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .overlay(Color.black.opacity(0.12).ignoresSafeArea())
                .onTapGesture(perform: dong)
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
            VStack(alignment: cuaToi ? .trailing : .leading, spacing: 10) {
                if !m.daXoaHoacThuHoi { thanhCamXuc }
                BongTinRiengCTW(m: m, cuaToi: cuaToi, viTri: .don, nguoiKia: nguoiKia, tenKia: tenKia, toi: toi, xemTruoc: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: cuaToi ? .trailing : .leading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                theThaoTac
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: 560)
            .scaleEffect(hien || giamChuyenDong ? 1 : 0.92)
            .opacity(hien ? 1 : 0)
        }
        .onAppear { withAnimation(giamChuyenDong ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.78)) { hien = true } }
        .accessibilityAddTraits(.isModal)
    }

    private var thanhCamXuc: some View {
        HStack(spacing: 4) {
            ForEach(Array(CamXucCTW.nhanh.enumerated()), id: \.offset) { i, e in
                Button { chon(.camXuc(e)) } label: {
                    Text(verbatim: e).font(.system(size: 30))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(cua.contains(e) ? AppColors.primary.opacity(0.18) : .clear))
                        .scaleEffect(hien || giamChuyenDong ? 1 : 0.3)
                        .animation(giamChuyenDong ? nil : .spring(response: 0.32, dampingFraction: 0.6).delay(Double(i) * 0.03), value: hien)
                }
                .buttonStyle(.nhan)
                .accessibilityLabel(cua.contains(e) ? String(localized: "Remove \(e)") : String(localized: "React \(e)"))
                .accessibilityIdentifier("dm.react.\(i)")
            }
            Button { chon(.themCamXuc) } label: {
                Image(systemName: "plus").font(.ctw(size: 17, weight: .bold)).foregroundColor(AppColors.textSecondary)
                    .frame(width: 40, height: 40).background(Circle().fill(AppColors.backgroundSecondary))
            }
            .buttonStyle(.nhan)
            .accessibilityLabel("More reactions")
            .accessibilityIdentifier("dm.react.more")
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(AppColors.backgroundCard).shadow(color: .black.opacity(0.18), radius: 14, y: 6))
    }

    private var theThaoTac: some View {
        VStack(spacing: 0) {
            let ds = cacThaoTac
            ForEach(Array(ds.enumerated()), id: \.offset) { i, t in
                if i > 0 { Divider().padding(.leading, 48) }
                Button { chon(t.0) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: t.2).font(.ctw(size: 16, weight: .medium)).frame(width: 22)
                        Text(t.1).font(.ctw(size: 16))
                        Spacer()
                    }
                    .foregroundColor(t.0 == .thuHoi || t.0 == .baoCao ? AppColors.error : AppColors.textPrimary)
                    .padding(.horizontal, 14).frame(minHeight: 48).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dm.menu.\(t.3)")
            }
        }
        .frame(width: 250)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColors.backgroundCard)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6))
    }

    private var cacThaoTac: [(ThaoTacGiuCTW, String, String, String)] {
        var ds: [(ThaoTacGiuCTW, String, String, String)] = []
        guard !m.daXoaHoacThuHoi else {
            if !cuaToi { ds.append((.baoCao, String(localized: "Report"), "exclamationmark.bubble", "report")) }
            return ds
        }
        ds.append((.traLoi, String(localized: "Reply"), "arrowshape.turn.up.left", "reply"))
        if let c = m.content, !c.isEmpty { ds.append((.chep, String(localized: "Copy"), "doc.on.doc", "copy")) }
        if ChuyenTiepCTW.duocChuyen(m) { ds.append((.chuyenTiep, String(localized: "Forward"), "arrowshape.turn.up.right", "forward")) }
        if coAnh { ds.append((.luuAnh, String(localized: "Save photo"), "square.and.arrow.down", "save")) }
        if ChatRiengVM.thuHoiDuoc(m, toi: toi) { ds.append((.thuHoi, String(localized: "Unsend"), "arrow.uturn.backward", "unsend")) }
        if !cuaToi { ds.append((.baoCao, String(localized: "Report"), "exclamationmark.bubble", "report")) }
        return ds
    }
}

// MARK: - Bảng emoji đầy đủ (thả cảm xúc "＋" · nút 😊 của ô soạn)

struct BangEmojiCTW: View {
    let tieuDe: LocalizedStringKey
    let chon: (String) -> Void
    var dongSauKhiChon = true
    @Environment(\.dismiss) private var dong
    @AppStorage("ctw.emoji.ganDay") private var ganDayLuu = ""
    @State private var nhom = 0

    static var bang: [(String, String, String)] { [
        (String(localized: "Smileys"), "face.smiling",
         "😀😃😄😁😆😅🤣😂🙂🙃😉😊😇🥰😍🤩😘😗😚😙😋😛😜🤪😝🤑🤗🤭🤫🤔🤐🤨😐😑😶😏😒🙄😬😮‍💨🤥😌😔😪🤤😴😷🤒🤕🤢🤮🥵🥶🥴😵🤯🤠🥳😎🤓🧐😕😟🙁😮😯😲😳🥺😦😧😨😰😥😢😭😱😖😣😞😓😩😫🥱😤😡😠🤬😈💀💩🤡👻👽🤖"),
        (String(localized: "People"), "hand.wave",
         "👋🤚🖐✋🖖👌🤌🤏✌️🤞🤟🤘🤙👈👉👆👇☝️👍👎✊👊🤛🤜👏🙌👐🤲🤝🙏✍️💅🤳💪🦾🧠👀👁👅👄💋🫶🙋🙆🙅🤷🤦🧑‍💻👩‍💻👨‍💻🧑‍🎓🧑‍🏫🧑‍🔧🧑‍🎨🕺💃🏃🚶"),
        (String(localized: "Hearts"), "heart",
         "❤️🧡💛💚💙💜🖤🤍🤎💔❣️💕💞💓💗💖💘💝💟❤️‍🔥✨⭐️🌟💫🔥💯💢💥💦💨🎉🎊🎈🎁🏆🥇🥈🥉🏅"),
        (String(localized: "Work"), "briefcase",
         "✅☑️✔️❌❎⚠️❓❗️💡📌📍📎🖇📝✏️🖊📒📓📔📕📗📘📙📚📅📆🗓📊📈📉🗂📁📂🗃🗄🗑🔒🔓🔑🔨🛠⚙️🐛🧪🧩💻🖥⌨️🖱📱☎️📞📧📨📤📥⏰⏱⏳⌛️🚀🎯🏁🚧"),
        (String(localized: "Food"), "fork.knife",
         "☕️🍵🧋🥤🍺🍻🥂🍷🍕🍔🍟🌭🥪🌮🍜🍝🍣🍱🍛🍚🍙🥟🍤🍗🍖🥩🥗🍩🍪🎂🍰🧁🍫🍬🍭🍦🍨🍉🍎🍌🍇🍓🥭🍍🥑"),
        (String(localized: "Nature"), "leaf",
         "🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🐔🐧🐦🐤🦆🦉🐝🦋🐌🐞🐢🐍🐙🐬🐳🦈🌵🌲🌳🌴🌱🌿🍀🍁🍂🌸🌼🌻🌹🌷☀️🌤⛅️🌧⛈🌈❄️☃️🌊"),
        (String(localized: "Activities"), "sportscourt",
         "⚽️🏀🏈⚾️🎾🏐🏓🏸🥊🥋⛳️🏹🎣🛹⛸🎿🏋️🚴🏊🧘🎮🕹🎲♟🎯🎳🎨🎬🎤🎧🎼🎹🥁🎸🎺📷📸🎥✈️🚗🚕🚌🚲🛵🏍🚆🚢🏖🏝🏔🗺"),
    ] }

    private var ganDay: [String] { ganDayLuu.split(separator: "|").map(String.init).filter { !$0.isEmpty } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    if !ganDay.isEmpty { khoi(String(localized: "Recently used"), ganDay) }
                    let b = Self.bang
                    khoi(b[nhom].0, b[nhom].2.map(String.init))
                }
                .padding(14)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 2) {
                    ForEach(Array(Self.bang.enumerated()), id: \.offset) { i, g in
                        Button { nhom = i } label: {
                            Image(systemName: g.1).font(.ctw(size: 16, weight: .medium))
                                .foregroundColor(i == nhom ? AppColors.primary : AppColors.textTertiary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityLabel(Text(verbatim: g.0))
                    }
                }
                .padding(.horizontal, 8)
                .background(.bar)
            }
            .navigationTitle(tieuDe)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dong() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func khoi(_ ten: String, _ ds: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: ten).font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 4) {
                ForEach(Array(ds.enumerated()), id: \.offset) { _, e in
                    Button {
                        ghiGanDay(e); chon(e); CTWRung.chon()
                        if dongSauKhiChon { dong() }
                    } label: { Text(verbatim: e).font(.system(size: 30)).frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func ghiGanDay(_ e: String) {
        var ds = ganDay.filter { $0 != e }
        ds.insert(e, at: 0)
        ganDayLuu = ds.prefix(16).joined(separator: "|")
    }
}

// MARK: - Ai đã bày tỏ cảm xúc

struct AiCamXucCTW: View {
    let m: Message
    let toi: Int?
    let tenKia: String
    let goCuaToi: (String) -> Void
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            List {
                ForEach(m.reactions ?? []) { r in
                    ForEach(r.userIds, id: \.self) { u in
                        let laToi = u == toi
                        Button {
                            if laToi { goCuaToi(r.emoji); dong() }
                        } label: {
                            HStack(spacing: 12) {
                                CTWAvatar(user: CTWUser(id: u, username: kho.thanhVien(u)?.username,
                                                        displayName: laToi ? String(localized: "You") : (kho.thanhVien(u)?.ten ?? tenKia),
                                                        avatarUrl: laToi ? AppState.shared.currentUser?.avatarUrl : kho.thanhVien(u)?.avatarUrl), size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(verbatim: laToi ? String(localized: "You") : (kho.thanhVien(u)?.ten ?? tenKia)).foregroundColor(AppColors.textPrimary)
                                    if laToi { Text("Tap to remove").font(.ctw(size: 12)).foregroundColor(AppColors.textSecondary) }
                                }
                                Spacer()
                                Text(verbatim: r.emoji).font(.system(size: 24))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!laToi)
                    }
                }
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dong() } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Chuyển tiếp (như ChuyenTiepModal.tsx của web: mỗi hàng một nút Gửi ⇒ "Đã gửi")

struct ChuyenTiepTinRiengCTW: View {
    let m: Message
    let tuHoiThoai: Int
    @ObservedObject private var kho = KhoTinNhanCTW.shared
    @ObservedObject private var kd = ModerationStore.shared
    @Environment(\.dismiss) private var dong
    @State private var tim = ""
    @State private var trangThai: [Int: Bool] = [:]   // id ⇒ true đã gửi / false đang gửi
    @State private var loi: String?

    private var ds: [MessageThread] {
        let t = tim.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return SapHoiThoaiCTW.sap(kho.hoiThoai).filter { h in
            guard h.laNhanRieng, let p = h.peer, !kd.blockedUserIds.contains(p.id) else { return false }
            if t.isEmpty { return true }
            return [p.displayName, p.username, p.alias].compactMap { $0 }.contains {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(t)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(verbatim: TomTatTinCTW.chu(m)).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                if let loi { Section { CTWErrorBanner(text: loi) } }
                Section {
                    ForEach(ds) { h in
                        HStack(spacing: 12) {
                            CTWAvatar(user: CTWUser(id: h.peer?.id ?? 0, username: h.peer?.username, displayName: h.peer?.displayName,
                                                    avatarUrl: h.peer?.avatarUrl), size: 40)
                            Text(verbatim: h.peer?.displayName ?? h.peer?.username ?? "").lineLimit(1)
                            Spacer()
                            Button {
                                Task { await gui(h.id) }
                            } label: {
                                Group {
                                    if trangThai[h.id] == false { ProgressView() }
                                    else if trangThai[h.id] == true { Label("Sent", systemImage: "checkmark") }
                                    else { Text("Send") }
                                }
                                .font(.ctw(size: 13, weight: .semibold)).frame(minWidth: 70, minHeight: 32)
                            }
                            .buttonStyle(.bordered)
                            .disabled(trangThai[h.id] != nil)
                            .accessibilityIdentifier("forward.\(h.id)")
                        }
                    }
                }
            }
            .searchable(text: $tim, prompt: "Search")
            .navigationTitle("Forward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dong() } } }
        }
    }

    private func gui(_ id: Int) async {
        trangThai[id] = false; loi = nil
        do {
            let moi: Message = try await APIClient.shared.request(TinNhanAPI.chuyenTiep(m, toi: id))
            kho.capNhatTinCuoi(id, moi)
            trangThai[id] = true
            CTWRung.thanhCong()
        } catch {
            trangThai[id] = nil
            loi = CTW.loi(error)
        }
    }
}

// MARK: - Lưu ảnh vào Thư viện (chỉ ảnh người dùng gửi — không lưu GIF của GIPHY)

enum LuuAnhCTW {
    /// Tải ảnh (Kingfisher, đã đệm) rồi ghi vào Ảnh. iOS hỏi quyền "chỉ thêm" lần đầu (NSPhotoLibraryAddUsageDescription).
    @MainActor
    static func luu(_ urls: [URL]) async -> Bool {
        var duoc = 0
        for u in urls {
            if let r = try? await KingfisherManager.shared.retrieveImage(with: u) {
                UIImageWriteToSavedPhotosAlbum(r.image, nil, nil, nil)
                duoc += 1
            }
        }
        return duoc > 0
    }
}
