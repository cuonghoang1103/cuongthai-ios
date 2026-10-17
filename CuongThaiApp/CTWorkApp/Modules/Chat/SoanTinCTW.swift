import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Ô soạn tin (kênh + chuỗi trả lời)
//
// · "+" ⇒ Chụp ảnh · Thư viện ảnh (tối đa 10) · Chọn tệp ⇒ tải NGAY thành tệp nháp
//   (chip có tiến trình, bỏ được); Gửi ⇒ tin kèm `fileIds`.
// · Gõ "@" ⇒ gợi ý thành viên kênh (người + agent có nhãn AI); chọn ⇒ chèn `@username `.
// · Ô trống ⇒ nút micro: ghi voice note (đồng ý công bố phiên âm lần đầu).
// · Mỗi lần chữ đổi ⇒ báo "đang gõ" (VM tự giãn nhịp).
// Ba trình bày (máy ảnh, thư viện ảnh, chọn tệp) gắn ở BA view khác nhau (bẫy C5).

struct TepNhapCTW: Identifiable, Equatable {
    enum TT: Equatable { case dangTai, xong(CTWChatFile), loi(String) }
    let id = UUID()
    var ten: String
    var laAnh: Bool
    var tt: TT = .dangTai
    var tep: CTWChatFile? { if case .xong(let f) = tt { return f }; return nil }
}

struct SoanTinCTW: View {
    let pid: Int
    let cid: Int
    var goiY: String
    var thanhVien: [CTWChannelMember] = []
    var choTep = true
    var choGiongNoi = true
    /// Gửi chữ + tệp nháp. Trả `true` nếu đã nhận (gửi được hoặc vào hàng chờ).
    let gui: (String, [CTWChatFile]) async -> Bool
    var chuDoi: ((String) -> Void)?
    /// Gửi voice note đã tải lên.
    var guiGiongNoi: ((CTWChatFile) async -> Bool)?

    @State private var chu = ""
    @State private var nhap: [TepNhapCTW] = []
    @State private var dangGui = false
    @State private var moThuVien = false
    @State private var chonAnh: [PhotosPickerItem] = []
    @State private var moChonTep = false
    @State private var moMayAnh = false
    @State private var hoiDongY = false
    @State private var biTuChoiMic = false
    @State private var loi: String?
    @StateObject private var ghi = GhiAmCTW()
    @FocusState private var dangGo: Bool
    @Environment(\.openURL) private var moUrl

    private var dangTaiTep: Bool { nhap.contains { $0.tt == .dangTai } }
    private var tepXong: [CTWChatFile] { nhap.compactMap(\.tep) }
    private var trong: Bool { chu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && tepXong.isEmpty }

    // MARK: @nhắc

    private var tuDangNhac: String? {
        guard let r = chu.range(of: "(^|\\s)@([A-Za-z0-9_.-]*)$", options: .regularExpression) else { return nil }
        let t = chu[r].trimmingCharacters(in: .whitespaces)
        return String(t.dropFirst())
    }

    private var goiYNhac: [CTWChannelMember] {
        guard let q = tuDangNhac?.lowercased() else { return [] }
        let toi = AppState.shared.currentUser?.id
        return thanhVien.filter { m in
            m.id != toi && m.username != nil &&
            (q.isEmpty || (m.username ?? "").lowercased().hasPrefix(q) || m.nguoi.ten.lowercased().contains(q))
        }
        .prefix(6).map { $0 }
    }

    private func chenNhac(_ m: CTWChannelMember) {
        guard let u = m.username, let r = chu.range(of: "@([A-Za-z0-9_.-]*)$", options: .regularExpression) else { return }
        chu.replaceSubrange(r, with: "@\(u) ")
        CTWRung.chon()
    }

    // MARK: Giao diện

    var body: some View {
        VStack(spacing: 0) {
            if !goiYNhac.isEmpty { bangNhac }
            Divider()
            if let loi {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
                    Text(loi).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Button { self.loi = nil } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)) }
                        .accessibilityLabel("Dismiss")
                }
                .padding(.horizontal, Spacing.md).padding(.top, 8)
            }
            if !nhap.isEmpty { hangNhap }
            if ghi.trangThai == .dangGhi { hangGhiAm } else { hangNhapChu }
        }
        .background(.bar)
        .onChange(of: chu) { _, s in chuDoi?(s) }
        .alert(CongBoGiongNoiCTW.tieuDe, isPresented: $hoiDongY) {
            Button("Allow and record") {
                GhiAmCTW.daDongYPhienAm = true
                Task { await ghi.batDau() }
            }
            Button("Not now", role: .cancel) {}
        } message: { Text(CongBoGiongNoiCTW.noiDung) }
        .onChange(of: ghi.trangThai) { _, t in if t == .biTuChoi { biTuChoiMic = true } }
        .onAppear { ghi.xongTuDong = { d, ms in Task { await guiGhiAm(d, ms) } } }
    }

    private var bangNhac: some View {
        VStack(spacing: 0) {
            ForEach(goiYNhac) { m in
                Button { chenNhac(m) } label: {
                    HStack(spacing: 10) {
                        ZStack(alignment: .bottomTrailing) {
                            CTWAvatar(user: m.nguoi, size: 28)
                            if m.online == true {
                                Circle().fill(AppColors.success).frame(width: 9, height: 9)
                                    .overlay(Circle().strokeBorder(AppColors.backgroundSecondary, lineWidth: 1.5))
                            }
                        }
                        Text(m.nguoi.ten).font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                        if m.nguoi.laAgent { CTWNhanAI() }
                        Text("@\(m.username ?? "")").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md).padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mention \(m.nguoi.ten)")
            }
        }
        .padding(.vertical, 4)
        .background(AppColors.backgroundSecondary)
    }

    private var hangNhap: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(nhap) { t in
                    HStack(spacing: 6) {
                        switch t.tt {
                        case .dangTai: ProgressView().scaleEffect(0.7)
                        case .xong: Image(systemName: t.laAnh ? "photo" : "doc").foregroundColor(AppColors.primary)
                        case .loi: Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
                        }
                        Text(t.ten).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            .lineLimit(1).fixedSize()
                        Button { bo(t) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(t.ten)")
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
                }
            }
            .padding(.horizontal, Spacing.md).padding(.top, 8)
        }
    }

    private var hangNhapChu: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if choTep { nutDinhKem }
            TextField(goiY, text: $chu, axis: .vertical)
                .lineLimit(1...6)
                .focused($dangGo)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppColors.backgroundCard))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppColors.border, lineWidth: 0.5))
                .accessibilityLabel(goiY)
            if trong && choGiongNoi && nhap.isEmpty && guiGiongNoi != nil {
                Button {
                    if GhiAmCTW.daDongYPhienAm { Task { await ghi.batDau() } } else { hoiDongY = true }
                } label: {
                    Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(AppColors.primary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.primary.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Record voice note")
                .alert("Microphone access is off", isPresented: $biTuChoiMic) {
                    Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { moUrl(u) } }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("Allow CT Work to use the microphone in Settings to record voice notes.") }
            } else {
                Button { Task { await bamGui() } } label: {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(trong || dangTaiTep ? AppColors.textTertiary : AppColors.primary))
                }
                .buttonStyle(.plain)
                .disabled(trong || dangTaiTep || dangGui)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, 8)
    }

    private var nutDinhKem: some View {
        Menu {
            if MayAnh.coMayAnh {
                Button { moMayAnh = true } label: { Label("Take Photo", systemImage: "camera") }
            }
            Button { moThuVien = true } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
            Button { moChonTep = true } label: { Label("Choose File", systemImage: "folder") }
        } label: {
            Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).foregroundColor(AppColors.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(AppColors.primary.opacity(0.12)))
        }
        .accessibilityLabel("Attach")
        .disabled(nhap.count >= 10)
        // Ba trình bày gắn ba chỗ (bẫy C5): máy ảnh trên nút, ảnh + tệp trên hai nền rỗng.
        .fullScreenCover(isPresented: $moMayAnh) {
            MayAnh { du in themTep(du: TaiTepChatCTW.chuanHoaAnh(du), ten: "Photo \(CTW.tenTepTheoGio()).jpg", kieu: "image/jpeg", laAnh: true) }
                .ignoresSafeArea()
        }
        .background(
            Color.clear.photosPicker(isPresented: $moThuVien, selection: $chonAnh, maxSelectionCount: 10, matching: .any(of: [.images, .videos]))
        )
        .background(
            Color.clear.fileImporter(isPresented: $moChonTep, allowedContentTypes: [.item], allowsMultipleSelection: true) { kq in
                guard case .success(let ds) = kq else { return }
                for u in ds.prefix(10) {
                    let mo = u.startAccessingSecurityScopedResource()
                    defer { if mo { u.stopAccessingSecurityScopedResource() } }
                    guard let du = try? Data(contentsOf: u) else { loi = "Couldn't read \(u.lastPathComponent)."; continue }
                    themTep(du: du, ten: u.lastPathComponent, kieu: nil, laAnh: false)
                }
            }
        )
        .onChange(of: chonAnh) { _, ds in
            guard !ds.isEmpty else { return }
            chonAnh = []
            Task {
                for (i, item) in ds.enumerated() {
                    guard let du = try? await item.loadTransferable(type: Data.self) else { continue }
                    let loai = item.supportedContentTypes.first
                    if loai?.conforms(to: .image) == true {
                        themTep(du: TaiTepChatCTW.chuanHoaAnh(du), ten: "Image \(CTW.tenTepTheoGio())\(ds.count > 1 ? "-\(i + 1)" : "").jpg", kieu: "image/jpeg", laAnh: true)
                    } else {
                        let duoi = loai?.preferredFilenameExtension ?? "mov"
                        themTep(du: du, ten: "Video \(CTW.tenTepTheoGio()).\(duoi)", kieu: loai?.preferredMIMEType ?? "video/quicktime", laAnh: false)
                    }
                }
            }
        }
    }

    private var hangGhiAm: some View {
        HStack(spacing: 12) {
            Button { ghi.huy() } label: {
                Image(systemName: "trash").font(.system(size: 16, weight: .semibold)).foregroundColor(AppColors.error)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Cancel recording")
            Circle().fill(AppColors.error).frame(width: 9, height: 9)
            Text(String(format: "%d:%02d", Int(ghi.giay) / 60, Int(ghi.giay) % 60))
                .font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundColor(AppColors.textPrimary)
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(ghi.muc.enumerated()), id: \.offset) { _, m in
                    Capsule().fill(AppColors.primary.opacity(0.7)).frame(width: 3, height: max(4, 26 * m))
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            Button {
                if let kq = ghi.dung() { Task { await guiGhiAm(kq.0, kq.1) } }
            } label: {
                Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    .frame(width: 40, height: 40).background(Circle().fill(AppColors.primary))
            }
            .accessibilityLabel("Send voice note")
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording voice note")
    }

    // MARK: Hành động

    private func themTep(du: Data, ten: String, kieu: String?, laAnh: Bool) {
        let t = TepNhapCTW(ten: ten, laAnh: laAnh)
        nhap.append(t)
        Task {
            do {
                let f = try await TaiTepChatCTW.taiTep(pid: pid, cid: cid, du: du, ten: ten, kieu: kieu)
                if let i = nhap.firstIndex(where: { $0.id == t.id }) { nhap[i].tt = .xong(f) } else {
                    // Người dùng đã bỏ trong lúc tải ⇒ dọn nháp trên máy chủ.
                    _ = try? await APIClient.shared.send(CTWAPI.boTepNhap(pid: pid, fid: f.id))
                }
            } catch {
                if let i = nhap.firstIndex(where: { $0.id == t.id }) { nhap[i].tt = .loi(CTW.loi(error)) }
                loi = CTW.loi(error)
            }
        }
    }

    private func bo(_ t: TepNhapCTW) {
        nhap.removeAll { $0.id == t.id }
        if let f = t.tep { Task { _ = try? await APIClient.shared.send(CTWAPI.boTepNhap(pid: pid, fid: f.id)) } }
    }

    private func bamGui() async {
        let s = chu
        let tep = tepXong
        dangGui = true
        defer { dangGui = false }
        chu = ""
        let giuNhap = nhap
        nhap.removeAll { $0.tep != nil }
        if !(await gui(s, tep)) {
            chu = s
            nhap = giuNhap
        }
    }

    private func guiGhiAm(_ d: Data, _ ms: Int) async {
        guard let guiGiongNoi else { return }
        dangGui = true
        defer { dangGui = false }
        do {
            let f = try await TaiTepChatCTW.taiGiongNoi(pid: pid, cid: cid, du: d, thoiLuongMs: ms)
            if !(await guiGiongNoi(f)) {
                _ = try? await APIClient.shared.send(CTWAPI.boTepNhap(pid: pid, fid: f.id))
            }
        } catch {
            loi = CTW.loi(error)
            CTWRung.loi()
        }
    }
}
