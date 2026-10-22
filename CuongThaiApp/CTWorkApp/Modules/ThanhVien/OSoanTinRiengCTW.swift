import SwiftUI

// MARK: - Ô soạn tin nhắn riêng kiểu Messenger (22/10/2026 — bản 1.1)
//
// Trái: ＋ (Tệp · Nhãn dán) · Máy ảnh · Ảnh · Micro (GIỮ để ghi — trượt trái để huỷ, thả để gửi). Đang gõ ⇒ thu về một
// nút "›" (như Messenger) để ô chữ rộng ra. Giữa: ô chữ tự giãn (1–6 dòng) + nút GIF + nút 😊. Phải: Gửi khi có gì để gửi,
// không thì 👍 (gửi ngay một 👍 lớn). Trả lời: dải trích dẫn trên ô. Tệp/ảnh chờ gửi: hàng xem trước, gỡ được từng cái.
// Tin thoại: `POST /messages/upload` (audio/mp4 .m4a) ⇒ `fileIds` — cùng đường web gửi tin thoại (`useGhiAm.ts`);
// Messenger chung KHÔNG gửi âm thanh cho bên thứ ba (khác voice note kênh — có chép lời qua Groq).

struct TepChoGuiCTW: Identifiable, Equatable {
    let id = UUID()
    var data: Data
    var ten: String
    var mime: String
    var laAnh: Bool { mime.hasPrefix("image/") }
}

struct OSoanTinRiengCTW: View {
    @Binding var chu: String
    var dangSoan: FocusState<Bool>.Binding
    @Binding var cho: [TepChoGuiCTW]
    let traLoi: TrichDanCTW?
    let tenKia: String
    let tienDo: String?
    let huyTraLoi: () -> Void
    let gui: () -> Void
    let guiThich: () -> Void
    let guiThoai: (Data, Int) -> Void
    let mo: (MoTuOSoanCTW) -> Void
    let baoGo: (Bool) -> Void

    @StateObject private var ghi = GhiAmCTW()
    @State private var moRong = false
    @State private var dangGiu = false
    @State private var keoHuy = false
    @State private var goiY: String?
    @State private var hoiQuyen = false
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    private var coChu: Bool { !chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var coGiDeGui: Bool { coChu || !cho.isEmpty }
    private var thuGon: Bool { (coChu || dangSoan.wrappedValue) && !moRong }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if let t = tienDo {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text(t).font(.ctw(size: 12)) }
                    .foregroundColor(AppColors.textSecondary).padding(.top, 6)
            }
            if let goiY {
                Text(goiY).font(.ctw(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
                    .padding(.top, 6).transition(.opacity)
            }
            if let r = traLoi { daiTraLoi(r) }
            if !cho.isEmpty { hangCho }
            HStack(alignment: .bottom, spacing: 2) {
                if thuGon {
                    nut("chevron.right", String(localized: "More options")) { withAnimation(.snappy) { moRong = true } }
                        .accessibilityIdentifier("dm.expand")
                } else {
                    Menu {
                        Button { mo(.tep) } label: { Label("File", systemImage: "doc") }
                        Button { mo(.nhanDan) } label: { Label("Sticker", systemImage: "face.smiling") }
                    } label: { bieuTuong("plus.circle.fill") }
                    .accessibilityLabel("More attachments")
                    .accessibilityIdentifier("dm.plus")
                    if MayAnh.coMayAnh { nut("camera.fill", String(localized: "Camera")) { mo(.mayAnh) } }
                    nut("photo.fill", String(localized: "Photos")) { mo(.thuVien) }.accessibilityIdentifier("dm.photos")
                    micro
                }
                oChu
                if coGiDeGui {
                    Button(action: gui) {
                        Image(systemName: "paperplane.fill").font(.ctw(size: 21)).foregroundColor(AppColors.primary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Send")
                    .accessibilityIdentifier("dm.send")
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button { guiThich() } label: {
                        Text(verbatim: "👍").font(.system(size: 27)).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.nhan)
                    .accessibilityLabel("Send a like")
                    .accessibilityIdentifier("dm.like")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
            .overlay { if ghi.trangThai == .dangGhi { thanhGhi } }
            .animation(giamChuyenDong ? nil : .snappy(duration: 0.22), value: thuGon)
            .animation(giamChuyenDong ? nil : .snappy(duration: 0.22), value: coGiDeGui)
        }
        .background(AppColors.backgroundCard)
        .onChange(of: chu) { _, m in baoGo(!m.isEmpty); if m.isEmpty { moRong = false } }
        .onChange(of: dangSoan.wrappedValue) { _, f in if !f { moRong = false } }
        .onAppear { ghi.xongTuDong = { d, ms in guiThoai(d, ms) } }
        .alert("Microphone access is off", isPresented: $hoiQuyen) {
            Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Allow CT Work to use the microphone in Settings to send voice messages.") }
    }

    // MARK: Phần

    private func bieuTuong(_ s: String) -> some View {
        Image(systemName: s).font(.ctw(size: 21)).foregroundColor(AppColors.primary).frame(width: 38, height: 44)
    }

    private func nut(_ s: String, _ nhan: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { bieuTuong(s) }.accessibilityLabel(Text(verbatim: nhan))
    }

    private var oChu: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField("Aa", text: $chu, axis: .vertical)
                .lineLimit(1...6)
                .focused(dangSoan)
                .font(.ctw(size: 16))
                .padding(.leading, 14).padding(.vertical, 9)
                .accessibilityLabel("Message")
                .accessibilityIdentifier("dm.composer")
            Button { mo(.gif) } label: {
                Text(verbatim: "GIF").font(.ctw(size: 11, weight: .heavy)).foregroundColor(AppColors.primary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.primary, lineWidth: 1.5))
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("GIF")
            .accessibilityIdentifier("dm.gif.open")
            Button { mo(.emoji) } label: {
                Image(systemName: "face.smiling").font(.ctw(size: 20)).foregroundColor(AppColors.primary).frame(width: 38, height: 38)
            }
            .accessibilityLabel("Emoji")
            .accessibilityIdentifier("dm.emoji")
        }
        .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(AppColors.backgroundPrimary))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
        .padding(.horizontal, 4)
    }

    private func daiTraLoi(_ r: TrichDanCTW) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColors.primary).frame(width: 3).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text(r.cuaToi ? String(localized: "Replying to yourself") : String(localized: "Replying to \(r.ten)"))
                    .font(.ctw(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                Text(verbatim: r.chu).font(.ctw(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(1)
            }
            Spacer()
            Button(action: huyTraLoi) { Image(systemName: "xmark.circle.fill").font(.ctw(size: 18)).foregroundColor(AppColors.textTertiary) }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Cancel reply")
        }
        .frame(height: 44).padding(.leading, 14).padding(.top, 4)
        .accessibilityIdentifier("dm.replyBar")
    }

    private var hangCho: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cho) { t in
                    ZStack(alignment: .topTrailing) {
                        if t.laAnh, let u = UIImage(data: t.data) {
                            Image(uiImage: u).resizable().scaledToFill().frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: BongTinRiengCTW.bieuTuongTep(t.ten)).font(.ctw(size: 20)).foregroundColor(AppColors.primary)
                                Text(verbatim: t.ten).font(.ctw(size: 10)).lineLimit(2).multilineTextAlignment(.center)
                                Text(ByteCountFormatter.string(fromByteCount: Int64(t.data.count), countStyle: .file)).font(.ctw(size: 9)).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(6).frame(width: 96, height: 72)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.backgroundSecondary))
                        }
                        Button { cho.removeAll { $0.id == t.id } } label: {
                            Image(systemName: "xmark.circle.fill").font(.ctw(size: 20)).foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .offset(x: 6, y: -6)
                        .accessibilityLabel(t.laAnh ? String(localized: "Remove photo") : String(localized: "Remove file"))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 2)
        }
        .accessibilityIdentifier("dm.pending")
    }

    // MARK: Ghi âm (giữ để ghi)

    private var micro: some View {
        bieuTuong("mic.fill")
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !dangGiu { dangGiu = true; keoHuy = false; Task { await batDauGhi() } }
                        let huy = v.translation.width < -70
                        if huy != keoHuy { keoHuy = huy; CTWRung.chon() }
                    }
                    .onEnded { _ in thaRa() }
            )
            .accessibilityElement()
            .accessibilityLabel(ghi.trangThai == .dangGhi ? String(localized: "Stop and send voice message") : String(localized: "Record voice message"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if ghi.trangThai == .dangGhi { if case let (d, ms)? = ghi.dung() { guiThoai(d, ms) } }
                else { dangGiu = true; Task { await batDauGhi(); dangGiu = false } }
            }
            .accessibilityIdentifier("dm.mic")
    }

    private func batDauGhi() async {
        await ghi.batDau()
        if ghi.trangThai == .biTuChoi { dangGiu = false; hoiQuyen = true; return }
        // Thả tay trong lúc iOS đang hỏi quyền ⇒ không để máy ghi chạy một mình.
        if !dangGiu, ghi.trangThai == .dangGhi { ghi.huy() }
    }

    private func thaRa() {
        dangGiu = false
        guard ghi.trangThai == .dangGhi else { return }
        if keoHuy {
            ghi.huy(); CTWRung.loi()
        } else if case let (d, ms)? = ghi.dung() {
            guiThoai(d, ms)
        } else {
            hienGoiY(String(localized: "Hold to record, release to send"))
        }
        keoHuy = false
    }

    private func hienGoiY(_ s: String) {
        withAnimation { goiY = s }
        Task { try? await Task.sleep(for: .seconds(2.2)); withAnimation { goiY = nil } }
    }

    private var thanhGhi: some View {
        HStack(spacing: 10) {
            Circle().fill(AppColors.error).frame(width: 10, height: 10)
                .opacity(giamChuyenDong ? 1 : (Int(ghi.giay * 2) % 2 == 0 ? 1 : 0.35))
            Text(verbatim: ThoaiCTW.dongHo(ghi.giay)).font(.ctw(size: 15, weight: .semibold).monospacedDigit())
                .foregroundColor(AppColors.textPrimary)
            HStack(spacing: 2) {
                ForEach(Array(ghi.muc.enumerated()), id: \.offset) { _, m in
                    Capsule().fill(keoHuy ? AppColors.error : AppColors.primary).frame(width: 3, height: max(4, 26 * m))
                }
            }
            .frame(height: 28)
            Spacer(minLength: 4)
            Text(keoHuy ? String(localized: "Release to cancel") : String(localized: "‹ Slide to cancel"))
                .font(.ctw(size: 13, weight: .medium)).foregroundColor(keoHuy ? AppColors.error : AppColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundCard)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Recording \(ThoaiCTW.dongHo(ghi.giay))"))
    }
}

/// Thứ ô soạn nhờ màn chat mở (MỘT `.sheet(item:)` ở màn chat — CLAUDE.md C5).
enum MoTuOSoanCTW { case tep, nhanDan, mayAnh, thuVien, gif, emoji }
