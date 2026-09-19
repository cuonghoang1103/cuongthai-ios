import SwiftUI
import AVFoundation

/// Luyện Nói IELTS có nhân vật — robot hỏi bằng giọng nói, mình trả lời bằng
/// miệng, AI chấm theo tiêu chí Speaking.
///
/// Nhịp bám đúng kỳ thi thật:
///   · Part 1 · Part 3 — nghe câu hỏi rồi trả lời ngay
///   · Part 2 — 1 phút chuẩn bị (được ghi ý ra giấy), rồi nói 2 phút liền mạch
///
/// ⚠️ Part 2 phải có đủ hai đồng hồ đó. Bỏ phút chuẩn bị đi thì người học
/// luyện một thứ không giống bài thi; bỏ trần 2 phút thì họ nói 5 phút và
/// không bao giờ biết mình thiếu ý ở phút thứ hai.
struct LuyenNoiIeltsView: View {
    let chuDe: ChuDeNoiIelts

    @Environment(\.dismiss) private var dong
    @StateObject private var thu = ThuAmNoi()

    @State private var chiSo = 0
    @State private var giaiDoan: Nhip = .nghe
    @State private var conLai = 0
    @State private var dongHo: Timer?
    @State private var dangCham = false
    @State private var banPhienAm: String?
    @State private var ketQua: String?
    @State private var loi: String?
    @State private var ghiY = ""

    enum Nhip: Equatable { case nghe, chuanBi, dangNoi, daCham }

    private var cau: CauHoiNoi? {
        chuDe.questions.indices.contains(chiSo) ? chuDe.questions[chiSo] : nil
    }
    private var laPart2: Bool { chuDe.part.contains("2") }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                nhanVat
                if let c = cau { theCauHoi(c) }
                if laPart2 && giaiDoan == .chuanBi { oGhiY }
                khoiNut
                if let b = banPhienAm { theChu(T("Bạn đã nói"), b, AppColors.secondary, laAI: false) }
                if let k = ketQua { theChu(T("Giám khảo nhận xét"), k, AppColors.primary) }
                if let l = loi {
                    Text(l).font(.bodySmall).foregroundStyle(AppColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let c = cau { theMau(c) }
            }
            .padding(Spacing.md)
            .padding(.bottom, 60)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("\(chuDe.part) · \(chuDe.title)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) { NutGiongIelts() }
            ToolbarItem(placement: .primaryAction) {
                if chuDe.questions.count > 1 {
                    Text("\(chiSo + 1)/\(chuDe.questions.count)")
                        .font(.captionBold).foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .onDisappear { tatDongHo(); thu.dung(); DocTu.shared.dung() }
    }

    // MARK: Nhân vật

    private var nhanVat: some View {
        VStack(spacing: Spacing.sm) {
            RobotChaoMung(ten: nil, tamTrang: tamTrang, gon: true)
                .frame(height: 110)
            Text(loiRobot)
                .font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if giaiDoan == .chuanBi || giaiDoan == .dangNoi {
                Text(dongHoChu)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(conLai <= 10 ? AppColors.error : AppColors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var tamTrang: TamTrangRobot {
        switch giaiDoan {
        case .nghe: return .binhThuong
        case .chuanBi: return .binhThuong
        case .dangNoi: return .dangHoc
        case .daCham: return .xongViec
        }
    }

    private var loiRobot: String {
        switch giaiDoan {
        case .nghe:
            return laPart2
                ? T("Part 2: nghe đề, bạn có 1 phút chuẩn bị rồi nói 2 phút.")
                : T("Nghe câu hỏi rồi trả lời như đang ngồi trước giám khảo.")
        case .chuanBi: return T("Đang chuẩn bị — ghi ý ra bên dưới.")
        case .dangNoi: return T("Đang nghe bạn nói…")
        case .daCham: return T("Xong. Đọc nhận xét rồi thử lại cho tốt hơn.")
        }
    }

    private var dongHoChu: String {
        String(format: "%01d:%02d", max(0, conLai) / 60, max(0, conLai) % 60)
    }

    // MARK: Câu hỏi

    private func theCauHoi(_ c: CauHoiNoi) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(c.q).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(c.qVi).font(.caption).foregroundStyle(AppColors.textTertiary)
            Button { DocTu.shared.doc(c.q, code: "en") } label: {
                Label(T("Nghe lại câu hỏi"), systemImage: "speaker.wave.2.fill").font(.captionBold)
            }
            .buttonStyle(.plain).foregroundStyle(AppColors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var oGhiY: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(T("Ghi ý (không ai chấm phần này)"), systemImage: "pencil")
                .font(.captionBold).foregroundStyle(AppColors.textSecondary)
            TextEditor(text: $ghiY)
                .font(.bodyMedium).frame(height: 110)
                .padding(Spacing.sm)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.medium)
                .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Nút

    @ViewBuilder
    private var khoiNut: some View {
        switch giaiDoan {
        case .nghe:
            nut(T("Nghe đề và bắt đầu"), "play.fill", AppColors.primary) { batDau() }
        case .chuanBi:
            nut(T("Nói luôn, không cần hết giờ"), "mic.fill", AppColors.success) { sangNoi() }
        case .dangNoi:
            nut(T("Xong — gửi chấm"), "stop.fill", AppColors.error) { Task { await dungVaCham() } }
        case .daCham:
            VStack(spacing: Spacing.sm) {
                nut(T("Thử lại câu này"), "arrow.clockwise", AppColors.primary) { datLai() }
                if chiSo + 1 < chuDe.questions.count {
                    nut(T("Câu tiếp theo"), "arrow.right", AppColors.secondary) {
                        chiSo += 1; datLai()
                    }
                }
            }
        }
    }

    private func nut(_ ten: String, _ bt: String, _ mau: Color, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            HStack {
                Spacer()
                if dangCham { ProgressView().tint(.white) } else { Label(ten, systemImage: bt) }
                Spacer()
            }
            .font(.buttonText)
            .padding(.vertical, Spacing.md)
            .background(mau)
            .foregroundStyle(Color.white)
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .disabled(dangCham)
    }

    /// `laAI` quyết định có dựng markdown hay không.
    ///
    /// Bản phiên âm là chữ CHÍNH BẠN vừa nói — vẽ thẳng. Nhận xét của giám
    /// khảo mới là chữ model sinh ra và mới cần dựng.
    private func theChu(_ ten: String, _ chu: String, _ mau: Color, laAI: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(ten).font(.captionBold).foregroundStyle(mau)
            Group {
                if laAI {
                    NoiDungMarkdown(noiDung: chu)
                } else {
                    Text(chu).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    /// Câu mẫu đặt CUỐI và chỉ mở sau khi đã nói. Đọc mẫu trước thì người học
    /// đọc lại mẫu chứ không tự nghĩ, và bài chấm không nói lên trình độ nào.
    private func theMau(_ c: CauHoiNoi) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                mau("✗ " + T("Cụt — band thấp"), c.weak, AppColors.error)
                mau("✓ " + T("Đủ ý"), c.good, AppColors.success)
                Text(c.why).font(.caption).foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        } label: {
            Label(T("Câu mẫu — mở SAU khi đã tự nói"), systemImage: "text.quote")
                .font(.captionBold).foregroundStyle(AppColors.textSecondary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private func mau(_ nhan: String, _ chu: String, _ m: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(nhan).font(.captionBold).foregroundStyle(m)
                Spacer()
                Button { DocTu.shared.doc(chu, code: "en") } label: {
                    Image(systemName: "speaker.wave.2").font(.caption2)
                }
                .buttonStyle(.plain).foregroundStyle(AppColors.textTertiary)
            }
            Text(chu).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(m.opacity(0.08))
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: Luồng

    private func batDau() {
        guard let c = cau else { return }
        DocTu.shared.doc(c.q, code: "en")
        if laPart2 {
            giaiDoan = .chuanBi
            batDongHo(60) { sangNoi() }
        } else {
            sangNoi()
        }
    }

    private func sangNoi() {
        tatDongHo()
        Task {
            let ok = await thu.batDau()
            guard ok else { loi = T("Không ghi âm được — kiểm tra quyền micro trong Cài đặt."); return }
            giaiDoan = .dangNoi
            // Part 2 trần 2 phút; Part 1/3 để 90 giây — đủ cho một câu trả lời
            // đầy đủ mà không để người học nói lan man mất trọng tâm.
            batDongHo(laPart2 ? 120 : 90) { Task { await dungVaCham() } }
        }
    }

    private func dungVaCham() async {
        tatDongHo()
        guard let duong = thu.dung() else {
            loi = T("Không có bản ghi nào.")
            giaiDoan = .nghe
            return
        }
        dangCham = true
        defer { dangCham = false }
        do {
            let kq = try await APIClient.shared.guiAudioChamNoi(
                duong: duong, cauHoi: cau?.q ?? "", part: chuDe.part)
            banPhienAm = kq.chu
            switch kq.lyDo {
            case "khong_nghe_thay":
                loi = T("Không nghe thấy tiếng nói nào. Thử lại, nói to hơn và gần micro hơn.")
            case "stt_unavailable":
                loi = T("Máy chủ chưa bật phần nghe. Phần câu mẫu bên dưới vẫn dùng được.")
            case "ai_unavailable":
                loi = T("Đã nghe được bạn nói, nhưng AI chấm đang tắt.")
            default:
                ketQua = kq.ketQua
            }
            giaiDoan = .daCham
        } catch {
            loi = error.localizedDescription
            giaiDoan = .daCham
        }
        // Xoá tệp ghi âm NGAY sau khi gửi. Giọng nói là dữ liệu sinh trắc học;
        // máy chủ đã không giữ thì app cũng không có lý do giữ.
        thu.xoaTep(duong)
    }

    private func datLai() {
        tatDongHo()
        thu.dung()
        giaiDoan = .nghe
        banPhienAm = nil; ketQua = nil; loi = nil; ghiY = ""
    }

    private func batDongHo(_ giay: Int, xong: @escaping () -> Void) {
        tatDongHo()
        conLai = giay
        dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                conLai -= 1
                if conLai <= 0 { tatDongHo(); xong() }
            }
        }
    }

    private func tatDongHo() { dongHo?.invalidate(); dongHo = nil }
}

// MARK: - Ghi âm

/// Ghi âm câu trả lời. Tệp nằm trong `Documents/ielts-noi/` và bị xoá ngay
/// sau khi gửi đi — không giữ lại bản sao giọng nói nào.
@MainActor
final class ThuAmNoi: NSObject, ObservableObject {
    private var may: AVAudioRecorder?

    private static func thuMuc() -> URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ielts-noi", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func batDau() async -> Bool {
        #if os(iOS)
        let phien = AVAudioSession.sharedInstance()
        // `.defaultToSpeaker` để câu hỏi robot vừa đọc xong vẫn ra loa ngoài;
        // không có nó thì sau lượt ghi âm đầu tiên mọi âm thanh chuyển sang
        // loa nghe điện thoại và người dùng tưởng app hỏng tiếng.
        try? phien.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? phien.setActive(true)
        let cho: Bool = await withCheckedContinuation { c in
            phien.requestRecordPermission { c.resume(returning: $0) }
        }
        guard cho else { return false }
        #endif

        let duong = Self.thuMuc().appendingPathComponent("\(UUID().uuidString).m4a")
        let dat: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            // 16 kHz mono: Whisper hạ mẫu về đúng mức này, nên ghi cao hơn chỉ
            // làm tệp nặng và lượt tải lên lâu hơn mà không chính xác hơn.
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            let m = try AVAudioRecorder(url: duong, settings: dat)
            m.record()
            may = m
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func dung() -> URL? {
        guard let m = may else { return nil }
        let u = m.url
        m.stop()
        may = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func xoaTep(_ u: URL) { try? FileManager.default.removeItem(at: u) }
}

// MARK: - Gửi audio

struct DapAnChamNoi: Decodable {
    let chu: String?
    let ketQua: String?
    let lyDo: String?
}

extension APIClient {
    /// Gửi bản ghi lên `/ielts/ai/cham-noi` dạng multipart.
    ///
    /// Viết riêng chứ không dùng `request(_:)`: đường chung gửi JSON, còn ở
    /// đây phải là `multipart/form-data` vì thân là một tệp âm thanh.
    func guiAudioChamNoi(duong: URL, cauHoi: String, part: String) async throws -> DapAnChamNoi {
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/ielts/ai/cham-noi") else {
            throw APIError.serverError("URL không hợp lệ")
        }
        let bien = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(bien)", forHTTPHeaderField: "Content-Type")
        if let tok = StorageManager.shared.getAuthToken() {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        // Chấm nói đi qua hai chặng (phiên âm rồi chấm) nên lâu hơn hẳn một
        // lời gọi thường; để nguyên trần mặc định là nó tự huỷ giữa chừng.
        req.timeoutInterval = 120

        var than = Data()
        func them(_ s: String) { than.append(s.data(using: .utf8)!) }
        for (k, v) in [("cauHoi", cauHoi), ("part", part)] where !v.isEmpty {
            them("--\(bien)\r\nContent-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n")
        }
        them("--\(bien)\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"noi.m4a\"\r\n")
        them("Content-Type: audio/m4a\r\n\r\n")
        than.append(try Data(contentsOf: duong))
        them("\r\n--\(bien)--\r\n")
        req.httpBody = than

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.serverError("Không có phản hồi") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        let goi = try JSONDecoder().decode(APIResponse<DapAnChamNoi>.self, from: data)
        guard goi.success, let d = goi.data else {
            throw APIError.serverError(goi.message ?? "Máy chủ từ chối bản ghi")
        }
        return d
    }
}
