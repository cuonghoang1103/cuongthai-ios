#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// NHẠI THEO (shadowing)
//
// Nghe một câu → nói lại → máy chép lại lời bạn vừa nói → so TỪNG TỪ.
// Đây là phương pháp luyện phát âm và nhịp điệu mạnh nhất mà không cần
// giáo viên: tai nghe mẫu, miệng lặp ngay, và bản chép chỉ ra đúng những
// từ bị nuốt.
//
// ⚠️ KHÔNG chấm bằng LLM. Câu hỏi ở đây chỉ là "có nói ra đúng những từ
// đó không" — chỉ cần bản phiên âm. Gọi LLM cho từng câu thì một buổi học
// tốn hơn cả ngày dùng chat.
// ════════════════════════════════════════════════════════════════

struct NhaiTheoView: View {
    let video: VideoHoc
    let cues: [CauPhuDe]
    /// Trình phát DÙNG CHUNG với màn học (khi màn này nằm trong bảng bên
    /// phải). `nil` = màn đứng riêng, tự dựng trình phát của mình.
    ///
    /// ⚠️ Không có tham số này thì nhúng vào bảng sẽ có HAI trình phát cùng
    /// phát một video — hai luồng tiếng chồng lên nhau.
    var dkNgoai: DieuKhienVideo? = nil

    @StateObject private var dkRieng = DieuKhienVideo()
    private var dk: DieuKhienVideo { dkNgoai ?? dkRieng }
    @StateObject private var thu = ThuAmNoi()
    @State private var i = 0
    @State private var dangThu = false
    @State private var dangCham = false
    @State private var banChep: String?
    @State private var loi: String?
    @State private var soDat = 0
    @State private var soLuot = 0

    private var cau: CauPhuDe? { i < cues.count ? cues[i] : nil }

    var body: some View {
        VStack(spacing: 0) {
            if dkNgoai == nil {
                TrinhPhatYouTube(videoId: video.videoId, dk: dkRieng)
                    .frame(width: 1, height: 1).opacity(0.02)
            }
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    thanhTren
                    theCau
                    nutThu
                    if let b = banChep { ketQua(b) }
                    if let l = loi {
                        Text(l).font(.caption).foregroundStyle(AppColors.error)
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
        }
        .navigationTitle(dkNgoai == nil ? T("Nhại theo") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(dkNgoai == nil ? .automatic : .hidden, for: .navigationBar)
        .onDisappear { dk.thoiLap(); dk.dung() }
    }

    private var thanhTren: some View {
        HStack {
            Text("\(T("Câu")) \(i + 1)/\(cues.count)")
                .font(.caption).foregroundStyle(AppColors.textTertiary)
            Spacer()
            if soLuot > 0 {
                Text("\(soDat)/\(soLuot) \(T("câu đạt"))")
                    .font(.caption).foregroundStyle(AppColors.success)
            }
        }
    }

    /// Câu mẫu hiện RÕ — khác hẳn nghe-chép. Nhại theo không giấu chữ: mục
    /// tiêu là bắt chước nhịp và âm, không phải đoán từ.
    private var theCau: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(cau?.en ?? "")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.lg) {
                Button { nghe(1.0) } label: {
                    Label(T("Nghe mẫu"), systemImage: "play.circle.fill").font(.captionBold)
                }
                Button { nghe(0.6) } label: {
                    Label(T("Nghe chậm"), systemImage: "tortoise.fill").font(.captionBold)
                }
            }
            .buttonStyle(.plain).foregroundStyle(AppColors.primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var nutThu: some View {
        VStack(spacing: Spacing.sm) {
            Button { Task { await bamThu() } } label: {
                VStack(spacing: 6) {
                    Image(systemName: dangThu ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(dangThu ? AppColors.error : AppColors.primary)
                    Text(dangThu ? T("Đang thu — bấm để dừng") : T("Bấm rồi nói lại câu trên"))
                        .font(.captionBold).foregroundStyle(AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(dangCham)
            if dangCham {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text(T("Đang nghe lại lời bạn…")).font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ketQua(_ chep: String) -> some View {
        let dung = Set(chuanHoa(cau?.en ?? "").split(separator: " ").map(String.init))
        let noi = Set(chuanHoa(chep).split(separator: " ").map(String.init))
        let thieu = dung.subtracting(noi)
        let tiLe = dung.isEmpty ? 0 : Double(dung.count - thieu.count) / Double(dung.count)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(tiLe >= 0.8 ? T("Đạt") : T("Thử lại câu này"))
                    .font(.titleSmall)
                    .foregroundStyle(tiLe >= 0.8 ? AppColors.success : AppColors.warning)
                Spacer()
                Text("\(Int(tiLe * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(tiLe >= 0.8 ? AppColors.success : AppColors.warning)
            }
            Text(T("Máy nghe bạn nói:")).font(.caption).foregroundStyle(AppColors.textTertiary)
            Text(chep).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !thieu.isEmpty {
                // Chỉ đúng TỪ BỊ NUỐT. "Phát âm chưa chuẩn" là lời phê vô
                // dụng; "bạn nuốt mất 'asked', 'finished'" thì sửa được ngay.
                Text("\(T("Chưa nghe ra")): \(thieu.sorted().joined(separator: ", "))")
                    .font(.caption).foregroundStyle(AppColors.error)
            }
            HStack {
                Button(T("Nói lại")) { banChep = nil }.buttonStyle(.bordered)
                Button(T("Câu tiếp")) { sangCau() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Việc

    private func nghe(_ x: Double) {
        guard let c = cau else { return }
        dk.tocDo(x)
        let den = i + 1 < cues.count ? cues[i + 1].t : c.t + 8
        dk.lapCau(tu: c.t, den: den)
        // Dừng lặp sau đúng một lượt: để nó lặp mãi thì người học không có
        // khoảng lặng nào để nói vào.
        Task {
            let dai = UInt64(max(1.0, (den - c.t) / max(x, 0.1)) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: dai)
            dk.thoiLap(); dk.dung()
        }
    }

    private func bamThu() async {
        loi = nil
        if dangThu {
            dangThu = false
            guard let duong = thu.dung() else { return }
            await cham(duong)
        } else {
            dk.dung()
            banChep = nil
            dangThu = await thu.batDau()
            if !dangThu { loi = T("Không bật được micro. Kiểm tra quyền trong Cài đặt.") }
        }
    }

    private func cham(_ duong: URL) async {
        guard let c = cau else { return }
        dangCham = true
        defer { dangCham = false }
        do {
            let kq = try await VideoHocAPI.nhai(duong: duong, cau: c.en)
            if kq.imLang {
                loi = T("Không nghe thấy gì. Nói to hơn và gần micro hơn nhé.")
            } else {
                banChep = kq.chu
                soLuot += 1
                let dung = Set(chuanHoa(c.en).split(separator: " ").map(String.init))
                let noi = Set(chuanHoa(kq.chu).split(separator: " ").map(String.init))
                if !dung.isEmpty,
                   Double(dung.intersection(noi).count) / Double(dung.count) >= 0.8 { soDat += 1 }
            }
        } catch { loi = error.localizedDescription }
    }

    private func sangCau() {
        banChep = nil
        i = min(i + 1, cues.count - 1)
    }

    private func chuanHoa(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isWhitespace || $0 == "'" }
    }
}
#endif
