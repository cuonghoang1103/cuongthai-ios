import SwiftUI

struct ChayThuatToanView: View {
    let tt: ThuatToan
    @StateObject private var may = MayThuatToan()
    @State private var buoc = 0
    @State private var dangPhat = false
    @State private var tocDo = 1.0
    @State private var ma = ""
    @State private var moMa = false
    @State private var viecPhat: Task<Void, Never>?
    @State private var coAm = AmThuatToan.bat

    private var khung: [String: TrangThaiTracer] { may.khung(buoc) }
    /// Dòng mã đang chạy ở bước này (`-1` = không xác định).
    private var dongDangChay: Int {
        may.dongMa.indices.contains(buoc) ? may.dongMa[buoc] : -1
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    NeoDauTrang()
                    dauTrang
                    if may.dangChay {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
                    } else if let e = may.loi {
                        khoiLoi(e)
                    } else {
                        // Vẽ theo THỨ TỰ tracer được tạo, không theo thứ tự
                        // từ điển — mảng phải nằm trên nhật ký như trên web.
                        ForEach(may.tracer) { m in
                            if let s = khung[String(m.id)] { VeTracer(tt: s) }
                        }
                    }
                    if moMa { khoiMa }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }
            if may.soKhung > 0 { thanhDieuKhien }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(tt.ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    coAm.toggle()
                    AmThuatToan.bat = coAm
                    if coAm { AmMoPhong.shared.phat(.click) }
                } label: {
                    Image(systemName: coAm ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 13))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { moMa.toggle() } label: {
                    Image(systemName: moMa ? "chevron.left.forwardslash.chevron.right.rtl"
                                           : "chevron.left.forwardslash.chevron.right")
                }
            }
        }
        .onChange(of: buoc) { cu, m in
            AmThuatToan.theoKhung(truoc: may.khung(cu), sau: may.khung(m),
                                  cuoi: m == may.soKhung - 1)
        }
        .task {
            if ma.isEmpty { ma = tt.ma }
            await chay()
        }
        .onDisappear { viecPhat?.cancel(); AmMoPhong.shared.im() }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(tt.nhom.uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(0.5)
                    .foregroundColor(mauNhom(tt.nhom))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(mauNhom(tt.nhom).opacity(0.15)))
                Spacer(minLength: 0)
                if may.soKhung > 0 {
                    Text("\(may.soKhung) \(T("bước"))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            Text(tt.moTa)
                .font(.system(size: 12.5))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func khoiLoi(_ e: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(T("Mã lỗi"), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: 0xEF4444))
            Text(e).font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(Color(hex: 0xEF4444).opacity(0.10)))
    }

    // MARK: Mã

    private var khoiMa: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(T("Mã nguồn").uppercased())
                    .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Button { ma = tt.ma; Task { await chay() } } label: {
                    Label(T("Khôi phục"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                Button { Task { await chay() } } label: {
                    Label(T("Chạy lại"), systemImage: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            // Sửa được rồi chạy lại — đúng như web. Không có tô màu cú pháp
            // (SwiftUI không có sẵn), nhưng dòng đang chạy được đánh dấu ở
            // thanh dưới.
            TextEditor(text: $ma)
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .frame(minHeight: 260)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundTertiary.opacity(0.6)))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    // MARK: Thanh điều khiển

    private var thanhDieuKhien: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("\(buoc + 1)/\(may.soKhung)")
                    .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 62, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(buoc) },
                    set: { dungPhat(); buoc = Int($0.rounded()) }
                ), in: 0...Double(max(may.soKhung - 1, 1)))
                .tint(mauNhom(tt.nhom))
                if dongDangChay > 0 {
                    Text("\(T("dòng")) \(dongDangChay)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
            HStack(spacing: Spacing.md) {
                nut("backward.end.fill") { dungPhat(); buoc = 0 }
                nut("backward.fill") { dungPhat(); buoc = max(0, buoc - 1) }
                Button { dangPhat ? dungPhat() : phat() } label: {
                    Image(systemName: dangPhat ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 34)
                        .background(RoundedRectangle(cornerRadius: 9).fill(mauNhom(tt.nhom)))
                }
                .buttonStyle(.plain)
                nut("forward.fill") { dungPhat(); buoc = min(may.soKhung - 1, buoc + 1) }
                nut("forward.end.fill") { dungPhat(); buoc = may.soKhung - 1 }
                Spacer(minLength: 0)
                Menu {
                    ForEach([0.25, 0.5, 1.0, 2.0, 4.0], id: \.self) { t in
                        Button("\(so(t))×") { tocDo = t }
                    }
                } label: {
                    Text("\(so(tocDo))×")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundSecondary)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(AppColors.border), alignment: .top)
    }

    private func nut(_ hinh: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: hinh)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 32, height: 30)
        }
        .buttonStyle(.plain)
    }

    // MARK: Việc

    private func chay() async {
        dungPhat()
        buoc = 0
        await may.chay(ma)
    }

    private func phat() {
        guard may.soKhung > 1 else { return }
        if buoc >= may.soKhung - 1 { buoc = 0 }
        dangPhat = true
        viecPhat?.cancel()
        viecPhat = Task {
            // 180ms mỗi bước ở tốc độ 1× — đủ chậm để mắt theo kịp một phép
            // hoán vị, đủ nhanh để không sốt ruột với 500 bước.
            while !Task.isCancelled, buoc < may.soKhung - 1 {
                try? await Task.sleep(nanoseconds: UInt64(180_000_000 / max(tocDo, 0.1)))
                guard !Task.isCancelled else { return }
                await MainActor.run { if buoc < may.soKhung - 1 { buoc += 1 } }
            }
            await MainActor.run { dangPhat = false }
        }
    }

    private func dungPhat() {
        viecPhat?.cancel()
        dangPhat = false
    }
}
