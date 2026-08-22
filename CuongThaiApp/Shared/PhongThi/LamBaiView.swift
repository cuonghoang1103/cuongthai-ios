import SwiftUI
import Kingfisher

// ════════════════════════════════════════════════════════════════
// LÀM BÀI
//
// Một câu một màn, vuốt/bấm để sang câu. Không dồn 50 câu vào một trang
// cuộn dài như web: trên điện thoại thì cuộn tìm câu 37 là cực hình, và
// người ta hay bấm nhầm đáp án của câu bên cạnh.
// ════════════════════════════════════════════════════════════════

@MainActor
final class LamBaiVM: ObservableObject {
    @Published var de: DeDangLam?
    @Published var luot: LuotThi?
    @Published var dangTai = true
    @Published var loi: String?
    @Published var viTri = 0
    /// Đáp án đã chọn: id câu → các chỉ số đáp án.
    @Published var chon: [Int: Set<Int>] = [:]
    @Published var conLai: Int = 0
    @Published var ketQua: XemLaiBaiThi?
    @Published var dangNop = false

    private let examId: Int
    private var dongHo: Timer?
    private var batDauLuc = Date()

    init(examId: Int) { self.examId = examId }

    var cauHoi: [CauHoiThi] { de?.questions ?? [] }
    var hienTai: CauHoiThi? { viTri < cauHoi.count ? cauHoi[viTri] : nil }
    var daLam: Int { chon.values.filter { !$0.isEmpty }.count }

    func batDau() async {
        dangTai = true; defer { dangTai = false }
        do {
            // Bắt đầu lượt TRƯỚC rồi mới lấy đề: máy chủ tự nối lại lượt
            // đang dở nếu có, nên thoát ra vào lại là làm tiếp, không mất bài.
            luot = try await APIClient.shared.request(.batDauLuotThi(examId: examId))
            de = try await APIClient.shared.request(.deDangLam(examId: examId))
            batDauLuc = Date()
            batDongHo()
            loi = nil
        } catch { loi = error.localizedDescription }
    }

    private func batDongHo() {
        let phut = de?.durationMinutes ?? 0
        guard phut > 0 else { return }
        // Nối lại lượt cũ thì đồng hồ phải tính từ `expiresAt` của máy chủ,
        // không phải từ lúc mở màn — không thì thoát ra vào lại là được
        // thêm nguyên một lượt thời gian.
        if let het = luot?.expiresAt, let moc = Date.tuChuoiISO(het) {
            conLai = max(0, Int(moc.timeIntervalSinceNow))
        } else {
            conLai = phut * 60
        }
        dongHo?.invalidate()
        dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.conLai > 0 {
                    self.conLai -= 1
                } else {
                    self.dongHo?.invalidate()
                    await self.nop()   // hết giờ thì nộp luôn, không hỏi
                }
            }
        }
    }

    func danhDau(_ cau: CauHoiThi, _ i: Int) {
        var s = chon[cau.id] ?? []
        if cau.chonNhieu {
            if s.contains(i) { s.remove(i) } else { s.insert(i) }
        } else {
            s = s.contains(i) ? [] : [i]
        }
        chon[cau.id] = s
        Haptics.cham()

        // Chọn xong câu MỘT đáp án thì tự sang câu sau — bớt một cú bấm cho
        // mỗi câu, mà bài 50 câu thì đó là 50 cú bấm.
        if !cau.chonNhieu, !s.isEmpty, viTri + 1 < cauHoi.count {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.2)) { self.viTri += 1 }
            }
        }
    }

    func nop() async {
        guard let l = luot, !dangNop else { return }
        dangNop = true; defer { dangNop = false }
        dongHo?.invalidate()
        let dapAn = chon.reduce(into: [String: [Int]]()) { m, kv in
            if !kv.value.isEmpty { m[String(kv.key)] = Array(kv.value).sorted() }
        }
        let giay = Int(Date().timeIntervalSince(batDauLuc))
        do {
            ketQua = try await APIClient.shared.request(
                .nopBaiTracNghiem(attemptId: l.attemptId, dapAn: dapAn, giay: giay))
        } catch { loi = error.localizedDescription }
    }

    func dung() { dongHo?.invalidate(); dongHo = nil }
}

struct LamBaiView: View {
    let de: DeThi
    /// ⚠️ Mặc định TIẾNG ANH — đề gốc là tiếng Anh, bản Việt là bản dịch kèm
    /// theo. Đúng như web (`useState<'en'|'vi'>('en')`).
    @State private var ngonNgu: NgonNguDe = .anh
    @StateObject private var vm: LamBaiVM
    @Environment(\.dismiss) private var dismiss
    @State private var hoiThoat = false
    @State private var hoiNop = false
    @State private var hienLuoi = false

    init(de: DeThi) {
        self.de = de
        _vm = StateObject(wrappedValue: LamBaiVM(examId: de.id))
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if let kq = vm.ketQua {
                KetQuaView(kq: kq, de: de) { dismiss() }
            } else if vm.dangTai {
                ProgressView()
            } else if let l = vm.loi, vm.de == nil {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36)).foregroundColor(AppColors.warning)
                    Text(l).font(.body).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Đóng") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.lg).padding(.vertical, 10)
                        .background(Capsule().fill(AppColors.primary))
                }
                .padding(Spacing.lg)
            } else {
                VStack(spacing: 0) {
                    thanhDau
                    if let c = vm.hienTai { khungCau(c) } else { Spacer() }
                    thanhDuoi
                }
            }
        }
        .task { if vm.de == nil { await vm.batDau() } }
        .onDisappear { vm.dung() }
        .alert("Thoát khỏi bài thi?", isPresented: $hoiThoat) {
            Button("Ở lại", role: .cancel) { }
            Button("Thoát", role: .destructive) { vm.dung(); dismiss() }
        } message: {
            Text("Bài đang làm được giữ lại. Vào lại đề này là làm tiếp, "
               + "nhưng ĐỒNG HỒ VẪN CHẠY.")
        }
        .alert("Nộp bài?", isPresented: $hoiNop) {
            Button("Xem lại", role: .cancel) { }
            Button("Nộp") { Task { await vm.nop() } }
        } message: {
            Text("Bạn đã làm \(vm.daLam)/\(vm.cauHoi.count) câu."
                 + (vm.daLam < vm.cauHoi.count ? " Những câu chưa làm sẽ tính 0 điểm." : ""))
        }
        .sheet(isPresented: $hienLuoi) { luoiCau }
        // Cả màn dùng CHUNG một ngôn ngữ: bấm nút là đề bài và mọi đáp án đổi
        // cùng lúc, không có chuyện đề tiếng Anh mà đáp án tiếng Việt.
        .environment(\.ngonNguDe, ngonNgu)
    }

    // ── Thanh trên ──────────────────────────────────────────────
    private var thanhDau: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Button { hoiThoat = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 38, height: 38).contentShape(Rectangle())
                }
                .accessibilityLabel("Thoát")

                Spacer()
                if vm.conLai > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(dinhDang(vm.conLai))
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                    }
                    // Năm phút cuối đổi màu — đủ để giục mà chưa tới mức doạ.
                    .foregroundColor(vm.conLai < 300 ? AppColors.error : AppColors.textPrimary)
                }
                Spacer()

                // Nút đổi ngôn ngữ, đúng chỗ web đặt. Nhãn là ngôn ngữ SẮP
                // chuyển sang, không phải ngôn ngữ đang xem.
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(AppColors.border, lineWidth: 1))
                }
                .accessibilityLabel(ngonNgu == .viet ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt")

                Button { hienLuoi = true } label: {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 38, height: 38).contentShape(Rectangle())
                }
                .accessibilityLabel("Danh sách câu hỏi")
            }

            HStack(spacing: 3) {
                ForEach(Array(vm.cauHoi.enumerated()), id: \.offset) { i, c in
                    Capsule()
                        .fill(i == vm.viTri ? AppColors.primary
                              : (vm.chon[c.id]?.isEmpty == false)
                                ? AppColors.success.opacity(0.65)
                                : AppColors.backgroundTertiary)
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
    }

    // ── Câu hỏi ─────────────────────────────────────────────────
    private func khungCau(_ c: CauHoiThi) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Text("Câu \(vm.viTri + 1)/\(vm.cauHoi.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    if c.chonNhieu {
                        Text("Chọn \(c.soDapAn) đáp án")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.accent))
                    }
                    Spacer()
                    Text("\(nz(c.diem)) điểm")
                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }

                // Đề bài đi qua `NoiDungThi`: tách `|||`, dựng công thức
                // KaTeX, sơ đồ mermaid, bảng, ảnh và mã đã tô màu — đúng bộ
                // mà web dựng (`ExamRichContent.tsx`).
                NoiDungThi(chu: c.prompt, coChu: 17, laDeBai: true)

                // Ảnh đề bài (sơ đồ, đoạn mã chụp màn hình…). Qua
                // `getMediaUrl` vì máy chủ trả về KHOÁ R2 trần, không phải
                // URL đầy đủ.
                if let m = c.imageUrl, !m.isEmpty, let u = URL(string: duongAnh(m)) {
                    KFImage(u)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }

                if let sc = c.starterCode, !sc.isEmpty {
                    KhoiMaNguon(ma: sc, ngonNgu: c.language, tieuDe: nil, choChep: false)
                }

                if let ds = c.options, !ds.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        ForEach(Array(ds.enumerated()), id: \.offset) { i, o in
                            oDapAn(c, i, o.text)
                        }
                    }
                } else {
                    // Câu tự luận / lập trình: chưa làm được trên iOS, nói
                    // thẳng ra thay vì hiện một câu hỏi không có chỗ trả lời.
                    Text("Câu này cần gõ mã hoặc viết bài — hãy làm trên web. "
                       + "Trên app bạn vẫn nộp được phần trắc nghiệm.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.warning.opacity(0.12)))
                }
            }
            .padding(Spacing.md)
        }
    }

    private func oDapAn(_ c: CauHoiThi, _ i: Int, _ chu: String) -> some View {
        let chon = vm.chon[c.id]?.contains(i) ?? false
        return Button {
            vm.danhDau(c, i)
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: c.chonNhieu
                      ? (chon ? "checkmark.square.fill" : "square")
                      : (chon ? "largecircle.fill.circle" : "circle"))
                    .font(.system(size: 19))
                    .foregroundColor(chon ? AppColors.primary : AppColors.textTertiary)
                // Đáp án cũng có thể mang `|||`, công thức hay mã — dùng
                // chung một bộ dựng với đề bài. `NoiDungThi` tự chọn: chuỗi
                // thường thì vẽ bằng `Text`, chỉ khi có thẻ/công thức mới
                // dựng WebView, nên 60 câu × 4 đáp án không thành 240 WebView.
                NoiDungThi(chu: chu, coChu: 15)
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(chon ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(chon ? AppColors.primary : Color.clear, lineWidth: 1.5)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ── Thanh dưới ──────────────────────────────────────────────
    private var thanhDuoi: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { vm.viTri = max(0, vm.viTri - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(vm.viTri > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 50, height: 46)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundTertiary))
            }
            .disabled(vm.viTri == 0)
            .buttonStyle(.plain)

            if vm.viTri + 1 < vm.cauHoi.count {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { vm.viTri += 1 }
                } label: {
                    Text("Câu tiếp")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.primary))
                }
                .buttonStyle(.plain)
            } else {
                Button { hoiNop = true } label: {
                    HStack(spacing: Spacing.sm) {
                        if vm.dangNop { ProgressView().tint(.white) }
                        Text("Nộp bài").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.success))
                }
                .disabled(vm.dangNop)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    // ── Lưới câu hỏi ────────────────────────────────────────────
    private var luoiCau: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                          spacing: 8) {
                    ForEach(Array(vm.cauHoi.enumerated()), id: \.offset) { i, c in
                        Button {
                            vm.viTri = i
                            hienLuoi = false
                        } label: {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor((vm.chon[c.id]?.isEmpty == false)
                                                 ? .white : AppColors.textPrimary)
                                .frame(maxWidth: .infinity).frame(height: 42)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill((vm.chon[c.id]?.isEmpty == false)
                                          ? AppColors.success : AppColors.backgroundCard))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(i == vm.viTri ? AppColors.primary : .clear,
                                                  lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Đã làm \(vm.daLam)/\(vm.cauHoi.count)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    /// Khoá R2 trần thì phải ghép tiền tố CDN; `http`/`blob`/`data` thì để
    /// nguyên — cùng bẫy đã làm vỡ ảnh xem trước hồi 02/07.
    private func duongAnh(_ s: String) -> String {
        if s.hasPrefix("http") || s.hasPrefix("data:") || s.hasPrefix("blob:") { return s }
        return APIClient.diaChiGoc + (s.hasPrefix("/") ? s : "/" + s)
    }

    private func dinhDang(_ g: Int) -> String {
        String(format: "%d:%02d", g / 60, g % 60)
    }
    private func nz(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2g", v)
    }
}

// ── Kết quả ─────────────────────────────────────────────────────

struct KetQuaView: View {
    let kq: XemLaiBaiThi
    let de: DeThi
    let dong: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text(kq.dat ? "🎉" : "📘").font(.system(size: 60))
            Text(kq.dat ? "Đạt!" : "Chưa đạt")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(kq.dat ? AppColors.success : AppColors.warning)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.2g", kq.diem))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("/ \(String(format: "%.2g", kq.tongDiem))")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textTertiary)
            }

            if let dung = kq.soDung, let tong = kq.soCau {
                Text("Đúng \(dung)/\(tong) câu")
                    .font(.system(size: 15)).foregroundColor(AppColors.textSecondary)
            }

            Text(de.ten)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()

            // Đáp án đúng + lời giải của TỪNG câu đã nằm sẵn trong phản hồi
            // nộp bài, nên nút này không tốn thêm lời gọi mạng nào.
            NavigationLink {
                XemLaiView(xemLai: kq, tenDe: de.ten)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("Xem lại từng câu")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(AppColors.primary)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Capsule().strokeBorder(AppColors.primary.opacity(0.5), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)

            Button(action: dong) {
                Text("Xong")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }
}
