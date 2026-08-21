import SwiftUI

// ════════════════════════════════════════════════════════════════
// LUYỆN NÓI VỚI AI — RẢNH TAY
//
// Vòng lặp: nghe → nhận ra chữ → gửi → AI trả lời → ĐỌC câu trả lời →
// tự nghe tiếp. Người dùng không phải bấm gì giữa các lượt.
//
// ⚠️ Không bao giờ nghe và đọc CÙNG LÚC. Micro sẽ thu chính giọng AI, nhận
// thành chữ, gửi lại cho AI — hai bên tự nói với nhau và người dùng ngồi
// nhìn. Mọi đường chuyển trạng thái đều đi qua `docXong()` / `ngheTiep()`.
// ════════════════════════════════════════════════════════════════

@MainActor
final class TroChuyenAI: ObservableObject {
    @Published var loiNoi: [LoiNoi] = []
    @Published var dangCho = false
    @Published var loi: String?
    @Published var canPro = false
    @Published var ranhTay = true

    let ngonNgu: NgonNgu
    let canhHuong: String
    let nghe = NgheLienTuc()

    private var lichSu: [[String: String]] = []

    init(ngonNgu: NgonNgu, canhHuong: String) {
        self.ngonNgu = ngonNgu
        self.canhHuong = canhHuong
        nghe.khiXongCau = { [weak self] chu in
            Task { @MainActor in await self?.guiCau(chu) }
        }
    }

    /// AI chào trước để người học có cái mà đáp, đỡ phải nghĩ câu mở đầu.
    func batDau() async {
        await guiCau("", moDau: true)
    }

    func guiCau(_ chu: String, moDau: Bool = false) async {
        if !moDau {
            let sach = chu.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sach.isEmpty else { ngheTiep(); return }
            loiNoi.append(LoiNoi(cuaToi: true, chu: sach))
            lichSu.append(["role": "user", "content": sach])
        }
        dangCho = true
        defer { dangCho = false }

        do {
            let l: LuotRolePlay = try await APIClient.shared.request(
                .aiNoiChuyen(code: ngonNgu.code, canhHuong: canhHuong,
                             lichSu: lichSu, chu: moDau ? "" : chu))
            let noi = (l.reply ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !noi.isEmpty else { ngheTiep(); return }

            // Lời sửa gắn vào bong bóng CỦA NGƯỜI HỌC, không phải của AI —
            // nó nói về câu họ vừa nói, đặt dưới câu AI thì mất chỗ dựa.
            let sua = (l.correction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !sua.isEmpty, let i = loiNoi.lastIndex(where: { $0.cuaToi }) {
                loiNoi[i].sua = sua
            }

            loiNoi.append(LoiNoi(cuaToi: false, chu: noi, nghia: l.translation))
            lichSu.append(["role": "assistant", "content": noi])
            doc(noi)
        } catch {
            let s = error.localizedDescription.lowercased()
            if s.contains("pro/max") || s.contains("pro / max") || s.contains("403") {
                canPro = true
            } else {
                loi = error.localizedDescription
                ngheTiep()
            }
        }
    }

    // ── Đọc rồi nghe tiếp ───────────────────────────────────────
    private func doc(_ chu: String) {
        nghe.dung()   // CHẮC CHẮN micro tắt trước khi loa bật
        guard DocTu.doDuoc(ngonNgu.code) else { ngheTiep(); return }
        DocTu.shared.doc(chu, code: ngonNgu.code, id: -99, chamHon: true)
        Task { @MainActor in
            // Đợi đọc xong. Không có sự kiện "đọc xong" nào bắn thẳng vào
            // đây, nên canh bằng cờ `dangDoc` của bộ đọc — nó tự xoá khi
            // đọc hết hoặc bị huỷ.
            for _ in 0..<600 {
                try? await Task.sleep(for: .milliseconds(120))
                if DocTu.shared.dangDoc == nil { break }
            }
            // Nghỉ một nhịp cho tiếng loa tắt hẳn khỏi phòng, không thì
            // micro bắt được đuôi câu vọng lại.
            try? await Task.sleep(for: .milliseconds(320))
            self.ngheTiep()
        }
    }

    func ngheTiep() {
        guard ranhTay, !canPro else { return }
        nghe.batDau(code: ngonNgu.code)
    }

    func dungHet() {
        nghe.dung()
        DocTu.shared.dung()
    }
}

// ── Màn chọn chủ đề ─────────────────────────────────────────────

struct ChonChuDeNoiView: View {
    let ngonNgu: NgonNgu
    @State private var tuTao = ""
    @State private var canhHuongMo: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Chọn một tình huống, hoặc tự viết tình huống của bạn. "
                   + "Nói bằng \(ngonNgu.name) — AI nghe, trả lời, và sửa lỗi cho bạn.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: Spacing.sm) {
                    ForEach(ChuDeNoi.goiY(ngonNgu.code)) { c in
                        Button {
                            canhHuongMo = c.canhHuong
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Text(c.icon).font(.system(size: 24))
                                Text(c.ten)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.primary)
                            }
                            .padding(Spacing.md)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundCard))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("TỰ TẠO TÌNH HUỐNG")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textTertiary).kerning(0.6)
                    .padding(.top, Spacing.sm)

                HStack(spacing: Spacing.sm) {
                    TextField("Ví dụ: đặt phòng khách sạn", text: $tuTao)
                        .font(.system(size: 15))
                        .padding(Spacing.sm + 2)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundCard))
                        .oKhongTuSua()

                    Button {
                        let t = tuTao.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        canhHuongMo = "Tình huống: \(t). Bạn đóng vai người đối thoại, "
                                    + "nói câu ngắn và tự nhiên."
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 42)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(tuTao.trimmingCharacters(in: .whitespaces).isEmpty
                                      ? AppColors.primary.opacity(0.4) : AppColors.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(tuTao.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Luyện nói với AI")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: Binding(
            get: { canhHuongMo.map { CanhHuong(chu: $0) } },
            set: { canhHuongMo = $0?.chu })
        ) { c in
            TroChuyenAIView(ngonNgu: ngonNgu, canhHuong: c.chu)
        }
    }

    struct CanhHuong: Identifiable { let chu: String; var id: String { chu } }
}

// ── Màn trò chuyện ──────────────────────────────────────────────

struct TroChuyenAIView: View {
    let ngonNgu: NgonNgu
    let canhHuong: String

    @StateObject private var vm: TroChuyenAI
    @ObservedObject private var doc = DocTu.shared
    @Environment(\.dismiss) private var dismiss
    @State private var hienNghia: Set<UUID> = []
    @State private var thieuQuyen = false
    @State private var song: CGFloat = 0

    init(ngonNgu: NgonNgu, canhHuong: String) {
        self.ngonNgu = ngonNgu
        self.canhHuong = canhHuong
        _vm = StateObject(wrappedValue: TroChuyenAI(ngonNgu: ngonNgu, canhHuong: canhHuong))
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                thanhDau
                Divider().background(AppColors.divider)

                if vm.canPro {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36)).foregroundColor(AppColors.accent)
                        Text("Luyện nói với AI dành cho tài khoản Pro")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Các mục khác trong Ngoại ngữ vẫn dùng bình thường.")
                            .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(Spacing.lg)
                    Spacer()
                } else if thieuQuyen {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 36)).foregroundColor(AppColors.textTertiary)
                        Text("Chưa được phép dùng micro hoặc nhận giọng nói")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Bật lại trong Cài đặt → CuongThai.")
                            .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(Spacing.lg)
                    Spacer()
                } else {
                    ScrollViewReader { p in
                        ScrollView {
                            LazyVStack(spacing: Spacing.md) {
                                ForEach(vm.loiNoi) { l in bong(l).id(l.id) }
                                if vm.dangCho { dangGo }
                                Color.clear.frame(height: 1).id("DAY")
                            }
                            .padding(Spacing.md)
                        }
                        .onChange(of: vm.loiNoi.count) { _, _ in
                            withAnimation { p.scrollTo("DAY", anchor: .bottom) }
                        }
                    }
                    thanhMic
                }
            }
        }
        .task {
            guard await NgheLienTuc.xinQuyen() else { thieuQuyen = true; return }
            await vm.batDau()
        }
        .onDisappear { vm.dungHet() }
    }

    // ── Bong bóng ───────────────────────────────────────────────
    private func bong(_ l: LoiNoi) -> some View {
        HStack {
            if l.cuaToi { Spacer(minLength: 44) }
            VStack(alignment: l.cuaToi ? .trailing : .leading, spacing: 5) {
                Text(l.chu)
                    .font(.system(size: 16))
                    .foregroundColor(l.cuaToi ? .white : AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 17)
                        .fill(l.cuaToi ? AppColors.primary : AppColors.backgroundCard))

                if !l.cuaToi {
                    HStack(spacing: Spacing.md) {
                        if DocTu.doDuoc(ngonNgu.code) {
                            Button {
                                // Nghe lại: phải TẮT micro trước, không thì
                                // máy thu chính câu nó vừa đọc.
                                vm.nghe.dung()
                                doc.doc(l.chu, code: ngonNgu.code, id: -98, chamHon: true)
                            } label: {
                                Label("Nghe lại", systemImage: "speaker.wave.2")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                        if l.nghia != nil {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if hienNghia.contains(l.id) { hienNghia.remove(l.id) }
                                    else { hienNghia.insert(l.id) }
                                }
                            } label: {
                                Label(hienNghia.contains(l.id) ? "Ẩn nghĩa" : "Nghĩa",
                                      systemImage: "character.book.closed")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if hienNghia.contains(l.id), let n = l.nghia {
                        Text(n).font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Lời sửa — gắn dưới câu CỦA NGƯỜI HỌC.
                if let s = l.sua, !s.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accent)
                            .padding(.top, 2)
                        Text(s)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 11)
                        .fill(AppColors.accent.opacity(0.14)))
                }
            }
            if !l.cuaToi { Spacer(minLength: 44) }
        }
    }

    private var dangGo: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(AppColors.textTertiary).frame(width: 6, height: 6)
                        .opacity(song > CGFloat(i) * 0.3 ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 17).fill(AppColors.backgroundCard))
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever()) { song = 1 }
        }
    }

    // ── Thanh trên / dưới ───────────────────────────────────────
    private var thanhDau: some View {
        HStack(spacing: Spacing.sm) {
            Button { vm.dungHet(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 38, height: 38).contentShape(Rectangle())
            }
            .accessibilityLabel("Kết thúc")

            VStack(alignment: .leading, spacing: 1) {
                Text("Luyện nói \(ngonNgu.co)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(vm.nghe.dangNghe ? "Đang nghe bạn nói…"
                     : doc.dangDoc != nil ? "AI đang nói…"
                     : vm.dangCho ? "AI đang nghĩ…" : "Tạm dừng")
                    .font(.system(size: 11))
                    .foregroundColor(vm.nghe.dangNghe ? AppColors.success : AppColors.textSecondary)
            }
            Spacer()

            // Tắt rảnh tay = dừng vòng lặp, chỉ nói khi bấm giữ.
            Button {
                vm.ranhTay.toggle()
                if vm.ranhTay { vm.ngheTiep() } else { vm.nghe.dung() }
                Haptics.cham()
            } label: {
                Image(systemName: vm.ranhTay ? "infinity.circle.fill" : "infinity.circle")
                    .font(.system(size: 21))
                    .foregroundColor(vm.ranhTay ? AppColors.primary : AppColors.textTertiary)
                    .frame(width: 38, height: 38).contentShape(Rectangle())
            }
            .accessibilityLabel(vm.ranhTay ? "Tắt chế độ rảnh tay" : "Bật chế độ rảnh tay")
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: 50)
    }

    private var thanhMic: some View {
        VStack(spacing: Spacing.sm) {
            if vm.nghe.dangNghe && !vm.nghe.chuTamThoi.isEmpty {
                Text(vm.nghe.chuTamThoi)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
            }

            if let l = vm.loi ?? vm.nghe.loi {
                Text(l).font(.system(size: 12)).foregroundColor(AppColors.error)
                    .padding(.horizontal, Spacing.md)
            }

            Button {
                if vm.nghe.dangNghe {
                    vm.nghe.chotNgay()          // gửi ngay, khỏi đợi 1,4 giây
                } else {
                    doc.dung()                  // cắt lời AI để nói xen vào
                    vm.ngheTiep()
                }
                Haptics.cham()
            } label: {
                ZStack {
                    if vm.nghe.dangNghe {
                        Circle().stroke(AppColors.success.opacity(0.35), lineWidth: 3)
                            .frame(width: 84, height: 84)
                            .scaleEffect(song > 0.5 ? 1.15 : 1)
                    }
                    Image(systemName: vm.nghe.dangNghe ? "waveform" : "mic.fill")
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(vm.nghe.dangNghe
                                                  ? AppColors.success : AppColors.primary))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(vm.nghe.dangNghe ? "Gửi ngay câu vừa nói" : "Bắt đầu nói")

            Text(vm.nghe.dangNghe
                 ? "Nói xong cứ im — tôi tự gửi. Hoặc bấm để gửi ngay."
                 : "Bấm để nói. AI sẽ trả lời và sửa lỗi cho bạn.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
}
