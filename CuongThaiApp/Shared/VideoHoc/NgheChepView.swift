#if os(iOS)
import SwiftUI

// ════════════════════════════════════════════════════════════════
// NGHE — CHÉP (dictation)
//
// Phát MỘT câu, giấu chữ, người học gõ lại những gì nghe được, rồi so từng
// từ. Đây là phương pháp có bằng chứng mạnh nhất cho kỹ năng nghe, và nó
// ép tai nghe ra từng âm thay vì đoán ý.
//
// Chạy hoàn toàn trên dữ liệu ĐÃ CÓ: 336.669 câu phụ đề kèm mốc thời gian.
// Không thêm nội dung, không thêm bảng, không cần deploy cho riêng phần này.
// ════════════════════════════════════════════════════════════════

struct NgheChepView: View {
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
    @State private var i = 0
    @State private var nhap = ""
    @State private var daSo = false
    @State private var soDung = 0
    @State private var soCau = 0
    @FocusState private var dangGo: Bool

    private var cau: CauPhuDe? { i < cues.count ? cues[i] : nil }

    var body: some View {
        VStack(spacing: 0) {
            // Trình phát vẫn phải có mặt (không có nó thì không phát được),
            // nhưng thu nhỏ còn 1pt: nhìn thấy hình là đọc được khẩu hình và
            // chữ trên slide — mất sạch ý nghĩa của bài nghe.
            if dkNgoai == nil {
                TrinhPhatYouTube(videoId: video.videoId, dk: dkRieng)
                    .frame(width: 1, height: 1).opacity(0.02)
            }

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    thanhTienDo
                    nutNghe
                    oGo
                    if daSo { ketQua }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
        }
        .navigationTitle(dkNgoai == nil ? T("Nghe — chép") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(dkNgoai == nil ? .automatic : .hidden, for: .navigationBar)
        .onAppear { dangGo = true }
    }

    private var thanhTienDo: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(T("Câu")) \(i + 1)/\(cues.count)")
                    .font(.caption).foregroundStyle(AppColors.textTertiary)
                Spacer()
                if soCau > 0 {
                    Text("\(soDung)/\(soCau) \(T("câu đúng"))")
                        .font(.caption).foregroundStyle(AppColors.success)
                }
            }
            ProgressView(value: Double(i + 1), total: Double(max(cues.count, 1)))
                .tint(AppColors.primary)
        }
    }

    private var nutNghe: some View {
        VStack(spacing: Spacing.md) {
            Button { phatCau() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill").font(.system(size: 54))
                    Text(T("Nghe câu này")).font(.captionBold)
                }
                .foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)
            HStack(spacing: Spacing.lg) {
                Button { dk.tocDo(0.5); phatCau() } label: {
                    Label(T("Chậm 0,5x"), systemImage: "tortoise.fill").font(.caption)
                }
                Button { dk.tocDo(1.0); phatCau() } label: {
                    Label(T("Bình thường"), systemImage: "hare.fill").font(.caption)
                }
            }
            .buttonStyle(.plain).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    private var oGo: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField(T("Gõ lại những gì bạn nghe được…"), text: $nhap, axis: .vertical)
                .lineLimit(2...5)
                .focused($dangGo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()      // ⚠️ Tự sửa chính tả là sửa hộ
                                               // bài tập — mất hết ý nghĩa đo.
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .cornerRadius(CornerRadius.medium)

            HStack(spacing: Spacing.sm) {
                if daSo {
                    Button(T("Câu tiếp")) { sangCauSau() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(T("So kết quả")) { so() }
                        .buttonStyle(.borderedProminent)
                        .disabled(nhap.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(T("Bỏ qua")) { daSo = true; soCau += 1 }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var ketQua: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Câu đúng")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            // Tô từng TỪ: xanh = đúng, đỏ = sai/thiếu. Chỉ báo "sai rồi" thì
            // người học không biết sai ở đâu, và lần sau vẫn sai chỗ đó.
            Text(chuDaTo)
                .font(.system(size: 16))
                .fixedSize(horizontal: false, vertical: true)
            if let c = cau {
                NutLuuTiengAnh(tieuDe: String(c.en.prefix(60)), than: c.en, loai: .ghiChu)
                    .padding(.top, 4)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var chuDaTo: AttributedString {
        guard let c = cau else { return AttributedString("") }
        let daGo = Set(chuanHoa(nhap).split(separator: " ").map(String.init))
        var ra = AttributedString("")
        for t in c.en.split(separator: " ") {
            var m = AttributedString(String(t) + " ")
            m.foregroundColor = daGo.contains(chuanHoa(String(t))) ? AppColors.success : AppColors.error
            ra += m
        }
        return ra
    }

    /// Bỏ dấu câu và hạ chữ thường trước khi so. Đánh trượt vì thiếu một dấu
    /// phẩy là đo chính tả dấu câu, không phải đo nghe.
    private func chuanHoa(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isWhitespace || $0 == "'" }
    }

    private func phatCau() {
        guard let c = cau else { return }
        let den = i + 1 < cues.count ? cues[i + 1].t : c.t + 8
        dk.lapCau(tu: c.t, den: den)
    }

    private func so() {
        guard let c = cau else { return }
        let dung = Set(chuanHoa(c.en).split(separator: " ").map(String.init))
        let go = Set(chuanHoa(nhap).split(separator: " ").map(String.init))
        // Đạt khi nghe ra ≥80% số từ. Đòi 100% thì một chữ "a" rơi ra cũng
        // thành trượt, và người học bỏ sau năm câu.
        if !dung.isEmpty, Double(dung.intersection(go).count) / Double(dung.count) >= 0.8 {
            soDung += 1
        }
        soCau += 1
        daSo = true
        dk.dung()
    }

    private func sangCauSau() {
        dk.thoiLap()
        nhap = ""
        daSo = false
        i = min(i + 1, cues.count - 1)
        dangGo = true
    }
}
#endif
