import SwiftUI
#if os(iOS)
import UIKit

// MARK: - Ô soạn mã có tô màu
//
// Bọc `UITextView` chứ không dùng `TextEditor`: `TextEditor` không nhận
// `NSAttributedString` nên không tô màu trong lúc gõ được, mà đó chính là thứ
// người dùng phàn nàn.

struct OSoanMa: UIViewRepresentable {
    @Binding var ma: String
    let ngonNgu: String?
    @Binding var dangGo: Bool
    /// ⚠️ Truyền THẲNG chế độ màu vào, KHÔNG đọc `context.environment
    /// .colorScheme` trong `updateUIView`. Soi thật 23/08/2026: đọc kiểu đó
    /// trả về `.light` trong khi app đang ở chế độ tối, nên bộ tô màu dùng
    /// bảng SÁNG — chữ gần như ĐEN trên nền tối, không đọc nổi. Và nó không
    /// hề báo lỗi.
    let toi: Bool

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        tv.alwaysBounceVertical = true

        // ⚠️ BẮT BUỘC tắt hết mấy thứ này. Bàn phím iOS mặc định đổi `"` thành
        // “ ” và `--` thành —, tức mã dán vào hay gõ ra sẽ KHÔNG chạy được, mà
        // nhìn thì gần như y hệt. Đây là bẫy kinh điển của ô soạn mã trên iOS.
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.spellCheckingType = .no
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.smartInsertDeleteType = .no

        tv.inputAccessoryView = context.coordinator.thanhPhim(tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.cha = self
        // Chỉ dựng lại khi nội dung hoặc chế độ màu THỰC SỰ khác — không thì
        // mỗi lần SwiftUI vẽ lại là con trỏ nhảy về cuối.
        if tv.text != ma || context.coordinator.toiDangDung != toi {
            context.coordinator.toiDangDung = toi
            context.coordinator.toMau(tv, ma: ma, ngonNgu: ngonNgu, toi: toi)
        }
    }

    func makeCoordinator() -> Dieu { Dieu(self) }

    final class Dieu: NSObject, UITextViewDelegate {
        var cha: OSoanMa
        var toiDangDung: Bool?
        private var viecToMau: Task<Void, Never>?

        init(_ c: OSoanMa) { cha = c }

        /// Tô màu và GIỮ NGUYÊN vị trí con trỏ.
        ///
        /// ⚠️ Gán `attributedText` làm `selectedRange` nhảy về cuối văn bản —
        /// gõ tới đâu con trỏ văng tới đó, không dùng nổi. Phải chép lại vùng
        /// chọn trước rồi đặt lại sau.
        func toMau(_ tv: UITextView, ma: String, ngonNgu: String?, toi: Bool) {
            let chon = tv.selectedRange
            let font = UIFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
            let s = ToMauMa.toNS(ma, ngonNgu: ngonNgu)
            tv.attributedText = s
            // Ký tự gõ TIẾP THEO cũng phải đúng phông, không thì nó về phông hệ
            // thống và dòng đang gõ so le với dòng trên.
            tv.typingAttributes = [
                .font: font,
                // Cũng phải TỰ THÍCH ỨNG, không thì ký tự vừa gõ đúng màu còn
                // ký tự tiếp theo thì không.
                .foregroundColor: UIColor { $0.userInterfaceStyle == .dark
                    ? UIColor(white: 0.83, alpha: 1) : UIColor(white: 0.12, alpha: 1) },
            ]
            if chon.location + chon.length <= s.length { tv.selectedRange = chon }
        }

        func textViewDidChange(_ tv: UITextView) {
            cha.ma = tv.text
            // Tô lại sau 180ms kể từ phím cuối: tô ngay từng phím thì gõ nhanh
            // bị khựng, mà mã bài tập có khi vài nghìn ký tự.
            viecToMau?.cancel()
            let ngonNgu = cha.ngonNgu, toi = toiDangDung ?? true
            viecToMau = Task { [weak self, weak tv] in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled, let tv, let self else { return }
                await MainActor.run { self.toMau(tv, ma: tv.text, ngonNgu: ngonNgu, toi: toi) }
            }
        }

        func textViewDidBeginEditing(_ tv: UITextView) { Task { @MainActor in cha.dangGo = true } }
        func textViewDidEndEditing(_ tv: UITextView) { Task { @MainActor in cha.dangGo = false } }

        /// Hàng phím phụ. Bàn phím iOS KHÔNG có Tab, `{}`, `[]`, `<>`, `|` ở
        /// lớp đầu — thiếu nó thì mỗi dấu ngoặc nhọn phải chuyển hai lớp phím.
        func thanhPhim(_ tv: UITextView) -> UIView {
            let ky = ["Tab", "{", "}", "(", ")", "[", "]", "<", ">", ";", "\"", "'", "=", "+", "-", "*", "/", "_", "|", "&"]
            let cuon = UIScrollView()
            cuon.backgroundColor = .secondarySystemBackground
            let hang = UIStackView()
            hang.axis = .horizontal; hang.spacing = 6
            hang.translatesAutoresizingMaskIntoConstraints = false
            for k in ky {
                let b = UIButton(type: .system)
                b.setTitle(k, for: .normal)
                b.titleLabel?.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
                b.backgroundColor = .tertiarySystemBackground
                b.layer.cornerRadius = 6
                b.widthAnchor.constraint(greaterThanOrEqualToConstant: k == "Tab" ? 46 : 34).isActive = true
                b.heightAnchor.constraint(equalToConstant: 34).isActive = true
                b.addAction(UIAction { [weak tv] _ in
                    tv?.insertText(k == "Tab" ? "    " : k)
                }, for: .touchUpInside)
                hang.addArrangedSubview(b)
            }
            cuon.addSubview(hang)
            cuon.frame = CGRect(x: 0, y: 0, width: 0, height: 46)
            NSLayoutConstraint.activate([
                hang.leadingAnchor.constraint(equalTo: cuon.leadingAnchor, constant: 8),
                hang.trailingAnchor.constraint(equalTo: cuon.trailingAnchor, constant: -8),
                hang.topAnchor.constraint(equalTo: cuon.topAnchor, constant: 6),
                hang.heightAnchor.constraint(equalToConstant: 34),
            ])
            return cuon
        }
    }
}
#endif

// MARK: - Màn soạn mã

@MainActor
final class SoanMaVM: ObservableObject {
    @Published var ma = ""
    @Published var dangGo = false
    @Published var dangCham = false
    @Published var ketQua: KetQuaChamMa?
    @Published var loi: String?
    @Published var trangThaiLuu = ""

    private var viecLuu: Task<Void, Never>?
    private let bai: BaiTapCode

    init(bai: BaiTapCode) {
        self.bai = bai
        // Bắt đầu từ mã khởi tạo của đề. Người học không phải gõ lại khung
        // sườn, và cũng thấy ngay đề muốn mình viết vào đâu.
        ma = bai.starterCodeJson?.first?.code ?? ""
    }

    /// Nạp mã đã lưu lần trước, nếu có. Cần `trackId` để hỏi đúng lộ trình.
    func napMaDaLuu(loTrinhId: Int?) async {
        guard let id = loTrinhId else { return }
        guard let ds: [TienDoBai] = try? await APIClient.shared.request(.tienDoCodeLab(loTrinhId: id)),
              let t = ds.first(where: { $0.exerciseId == bai.id }), let cu = t.maDaLuu else { return }
        ma = cu
    }

    /// Lưu sau 1,5 giây kể từ phím cuối. Lưu từng phím thì mỗi ký tự là một
    /// lượt gọi mạng.
    func luuHoan() {
        viecLuu?.cancel()
        viecLuu = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.luu()
        }
    }

    private func luu() async {
        guard !ma.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        trangThaiLuu = "Đang lưu…"
        struct R: Codable { let status: String? }
        do {
            _ = try await APIClient.shared.request(
                .luuMaBaiTap(baiId: bai.id, ma: ma, ngonNgu: bai.language ?? "text")) as R
            trangThaiLuu = "Đã lưu"
        } catch {
            // Chưa đăng nhập thì lưu KHÔNG được, nhưng vẫn phải gõ được —
            // đừng biến một lỗi lưu thành cái chặn cả màn soạn.
            trangThaiLuu = "Chưa lưu được"
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { if trangThaiLuu != "Đang lưu…" { trangThaiLuu = "" } }
        }
    }

    /// Trần 24.000 ký tự là do máy chủ đặt — chặn ở đây để người dùng biết
    /// TRƯỚC khi tốn một lượt gọi AI.
    var quaDai: Bool { ma.count > 24_000 }

    func cham() async {
        guard !dangCham, !ma.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !quaDai else { loi = "Mã dài quá \(ma.count)/24.000 ký tự — dán phần chính thôi."; return }
        dangCham = true; loi = nil; defer { dangCham = false }
        do {
            ketQua = try await APIClient.shared.request(.chamMaBaiTap(baiId: bai.id, ma: ma))
        } catch {
            let s = error.localizedDescription
            loi = s.lowercased().contains("pro") || s.contains("403")
                ? "Chấm mã bằng AI dành cho tài khoản Pro."
                : s
        }
    }
}

struct SoanMaView: View {
    let bai: BaiTapCode
    var loTrinhId: Int?

    @StateObject private var vm: SoanMaVM
    @State private var moKetQua = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var che

    init(bai: BaiTapCode, loTrinhId: Int? = nil) {
        self.bai = bai
        self.loTrinhId = loTrinhId
        _vm = StateObject(wrappedValue: SoanMaVM(bai: bai))
    }

    var body: some View {
        VStack(spacing: 0) {
            thanhTren
            #if os(iOS)
            // Nền của ô soạn tối hơn hẳn nền app, đúng cách trình soạn mã tách
            // vùng gõ khỏi phần còn lại — và trùng nền của `KhoiMaNguon`.
            OSoanMa(ma: $vm.ma, ngonNgu: bai.language, dangGo: $vm.dangGo,
                    toi: che == .dark)
                .background(che == .dark ? Color(hex: 0x1E1E1E) : Color(hex: 0xF6F8FA))
                .onChange(of: vm.ma) { _, _ in vm.luuHoan() }
            #endif
            thanhDuoi
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Viết mã")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $moKetQua) {
            if let kq = vm.ketQua { KetQuaChamView(kq: kq) }
        }
        .task { await vm.napMaDaLuu(loTrinhId: loTrinhId) }
    }

    private var thanhTren: some View {
        HStack(spacing: Spacing.sm) {
            Text(bai.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: Spacing.sm)
            if !vm.trangThaiLuu.isEmpty {
                Text(vm.trangThaiLuu)
                    .font(.system(size: 10))
                    .foregroundColor(vm.trangThaiLuu == "Đã lưu" ? AppColors.success : AppColors.textTertiary)
            }
            Text("\(vm.ma.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(vm.quaDai ? AppColors.error : AppColors.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }

    private var thanhDuoi: some View {
        VStack(spacing: Spacing.sm) {
            if let l = vm.loi {
                Text(l)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.error)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Spacing.sm) {
                if vm.ketQua != nil {
                    Button { moKetQua = true } label: {
                        Text("Xem kết quả")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm + 2)
                            .background(Capsule().strokeBorder(AppColors.primary.opacity(0.5), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    Task { await vm.cham(); if vm.ketQua != nil { moKetQua = true } }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if vm.dangCham { ProgressView().controlSize(.small) }
                        else { Image(systemName: "checkmark.seal.fill") }
                        Text(vm.dangCham ? "AI đang đọc mã…" : "Kiểm tra bằng AI")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm + 3)
                    .background(Capsule().fill(AppColors.primary))
                }
                .buttonStyle(.plain)
                .disabled(vm.dangCham || vm.ma.isEmpty)
            }
            // Nói TRƯỚC là nó không chạy mã, để không ai chờ một dòng kết quả
            // chương trình rồi thất vọng.
            Text("AI đối chiếu mã của bạn với từng yêu cầu của đề — không chạy chương trình.")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
    }
}

// MARK: - Kết quả chấm

struct KetQuaChamView: View {
    let kq: KetQuaChamMa
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.md) {
                        ZStack {
                            Circle().stroke(AppColors.backgroundTertiary, lineWidth: 7)
                            Circle()
                                .trim(from: 0, to: kq.tong > 0 ? CGFloat(kq.dat) / CGFloat(kq.tong) : 0)
                                .stroke(AppColors.success, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(kq.dat)/\(kq.tong)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .frame(width: 68, height: 68)
                        Text(kq.tomTat)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }

                    ForEach(kq.items ?? []) { m in mucYeuCau(m) }

                    if !kq.dsRuiRo.isEmpty {
                        Text("RỦI RO")
                            .font(.system(size: 10, weight: .bold)).kerning(0.5)
                            .foregroundColor(AppColors.textTertiary)
                        ForEach(kq.dsRuiRo, id: \.self) { r in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11)).foregroundColor(AppColors.warning)
                                Text(r).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("AI chấm mã")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }

    private func mucYeuCau(_ m: KetQuaChamMa.MucYeuCau) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: m.mucDat.bieuTuong)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: m.mucDat.mau))
                Text(m.yeuCau)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            if !m.bangChung.isEmpty {
                Text(m.bangChung)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Cách sửa chỉ hiện khi CHƯA đạt — mục đã đạt mà vẫn bày cách sửa
            // thì người đọc tưởng mình còn sai.
            if m.mucDat != .dat, !m.cachSua.isEmpty {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 10)).foregroundColor(AppColors.primary)
                    Text(m.cachSua)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(AppColors.primary.opacity(0.10)))
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}
