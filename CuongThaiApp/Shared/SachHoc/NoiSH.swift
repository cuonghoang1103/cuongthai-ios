#if os(iOS)
import SwiftUI
import AVFoundation

// ════════════════════════════════════════════════════════════════
// NÓI — khối `speak` (luyện nói + AI chấm) và `phatam` (chấm phát âm từng âm),
// bản native của Blocks2.tsx › Speak/SpeakQ, PhatAm.tsx, useMicro.ts.
//
// MỘT máy thu cho cả app (`MayThuSH.chung`): bấm ghi câu khác thì câu đang ghi
// dừng — hai micro cùng mở là micro treo (bài học useMicro.ts). Bắt đầu ghi là
// tắt giọng mẫu đang đọc (không thì giọng mẫu lọt vào bản ghi).
//   • speak  ⇒ m4a AAC, tối đa 3 phút, chỉ dừng bằng tay ⇒ `POST /ielts/ai/cham-noi`
//              (đã có `guiAudioChamNoi`). Khoá Nhật/Trung: chỉ ghi & nghe lại (máy
//              chấm nói chỉ hiểu tiếng Anh — như web).
//   • phatam ⇒ WAV PCM 16 kHz mono 16-bit (dạng DUY NHẤT Azure nhận — web phải tự
//              đổi webm → wav, iOS thu thẳng ra wav), tối đa 15 giây, nói xong im
//              1,2 giây là TỰ dừng và chấm ⇒ `POST /ielts/ai/cham-phat-am`.
// Bấm "Xong" thì ghi thêm ĐUÔI 0,4 giây rồi mới dừng: cắt ngay là mất âm cuối
// (/dz/ của "reads" — đo trên máy chấm prod 05/10, web useMicro.ts).
// Quyền micro: `NSMicrophoneUsageDescription` có sẵn; bị từ chối ⇒ báo cách bật,
// KHÔNG gọi record() (thu ra tệp câm).
// ════════════════════════════════════════════════════════════════

@MainActor
final class MayThuSH: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let chung = MayThuSH()

    enum Kieu { case m4a, wav16k }

    /// Khoá câu đang ghi / đang mở micro.
    @Published private(set) var dangGhi: String?
    @Published private(set) var dangMo: String?
    @Published private(set) var muc: Float = 0
    @Published private(set) var dangPhatLai: URL?
    @Published var loi: [String: String] = [:]

    private var may: AVAudioRecorder?
    private var phatLai: AVAudioPlayer?
    private var dongHo: Timer?
    private var xong: ((URL, Bool) -> Void)?
    private var tuDung = false
    private var batDauLuc = Date()
    private var daNoi = false
    private var khungTieng = 0
    private var imTu: Date?
    private var keoDuoi = false

    private override init() { super.init() }

    private static var thuMuc: URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("sach-hoc-noi", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Ghi một lượt. `xong(url, coTieng)` khi dừng (tay / tự / hết giờ); huỷ thì không gọi.
    func batDau(_ khoa: String, kieu: Kieu, toiDa: TimeInterval, tuDungKhiIm: Bool, xong: @escaping (URL, Bool) -> Void) async {
        guard dangMo == nil else { return }
        huy()
        dungPhatLai()
        GiongSachHoc.chung.dung()
        loi[khoa] = nil
        dangMo = khoa
        defer { dangMo = nil }
        guard await xinQuyen() else {
            loi[khoa] = "Chưa có quyền dùng micro. Bật trong Cài đặt → CuongThai → Micro rồi thử lại."
            return
        }
        let phien = AVAudioSession.sharedInstance()
        do {
            try phien.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try phien.setActive(true)
        } catch {
            loi[khoa] = "Không mở được micro: " + error.localizedDescription
            return
        }
        let url = Self.thuMuc.appendingPathComponent(UUID().uuidString + (kieu == .wav16k ? ".wav" : ".m4a"))
        let cauHinh: [String: Any] = kieu == .wav16k
            ? [AVFormatIDKey: Int(kAudioFormatLinearPCM), AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
               AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
            : [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1,
               AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        do {
            let r = try AVAudioRecorder(url: url, settings: cauHinh)
            r.isMeteringEnabled = true
            guard r.record(forDuration: toiDa) else {
                loi[khoa] = "Không bắt đầu ghi được. Thử lại nhé."
                return
            }
            may = r
            self.xong = xong
            tuDung = tuDungKhiIm
            batDauLuc = Date(); daNoi = false; khungTieng = 0; imTu = nil; keoDuoi = false
            dangGhi = khoa
            dongHo = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.nhip() }
            }
        } catch {
            loi[khoa] = "Không bắt đầu ghi được: " + error.localizedDescription
        }
    }

    private func nhip() {
        guard let r = may else { return }
        if !r.isRecording { ketThuc(goi: true); return }
        r.updateMeters()
        let db = r.averagePower(forChannel: 0)
        muc = max(0, min(1, (db + 50) / 50))
        // ≈ rms 0,02 của web (−34 dB).
        let coTieng = db > -34
        if coTieng { khungTieng += 1 }
        guard tuDung else { return }
        if coTieng { daNoi = true; imTu = nil }
        else if daNoi, Date().timeIntervalSince(batDauLuc) > 0.6 {
            if imTu == nil { imTu = Date() }
            if let t = imTu, Date().timeIntervalSince(t) > 1.2 { ketThuc(goi: true) }
        }
    }

    /// Người học bấm "Xong": ghi thêm đuôi 0,4 giây rồi dừng.
    func dung() {
        guard may?.isRecording == true, !keoDuoi else { return }
        keoDuoi = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.ketThuc(goi: true) }
    }

    /// Bỏ lượt đang ghi (rời bài, ghi câu khác) — không gửi.
    func huy() { ketThuc(goi: false) }

    private func ketThuc(goi: Bool) {
        guard let r = may else { return }
        dongHo?.invalidate(); dongHo = nil
        r.stop()
        may = nil
        dangGhi = nil
        muc = 0
        keoDuoi = false
        let cb = xong
        xong = nil
        // ≥ 2 khung 50 ms có tiếng (~0,1 giây) mới tính là đã nói — tiếng gõ/chạm không lọt.
        let coTieng = khungTieng >= 2
        if goi { cb?(r.url, coTieng) } else { try? FileManager.default.removeItem(at: r.url) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Nghe lại

    func phat(_ u: URL) {
        if dangPhatLai == u { dungPhatLai(); return }
        dungPhatLai()
        GiongSachHoc.chung.dung()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: u)
            p.delegate = self
            p.play()
            phatLai = p
            dangPhatLai = u
        } catch {}
    }

    func dungPhatLai() { phatLai?.stop(); phatLai = nil; dangPhatLai = nil }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.phatLai = nil; self.dangPhatLai = nil }
    }

    private func xinQuyen() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}

/// Thanh mức micro.
struct ThanhMucSH: View {
    let muc: Float
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.backgroundTertiary)
                Capsule().fill(AppColors.error).frame(width: max(4, g.size.width * CGFloat(muc)))
            }
        }
        .frame(width: 80, height: 6)
        .animation(.linear(duration: 0.05), value: muc)
    }
}

// MARK: - Luyện nói (speak)

struct LuyenNoiSH: View {
    let id: String
    let part: String
    let questions: [String]
    @EnvironmentObject private var vm: SachHocVM
    @State private var lamLai = 0

    private var ngoai: Bool { vm.khoa?.ngonNgu == "ja" || vm.khoa?.ngonNgu == "zh" }

    var body: some View {
        KhungBaiTapSH(bieuTuong: "mic.fill", tieuDe: ngoai ? "Luyện nói" : "Luyện nói — Speaking Part \(part)",
                      huongDan: ngoai ? "Bấm câu hỏi để nghe → ghi âm câu trả lời → nghe lại và so với câu mẫu."
                                      : "Bấm câu hỏi để nghe giám khảo hỏi → bấm ghi âm và trả lời → nghe lại → nhờ AI chấm.") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(questions.enumerated()), id: \.offset) { i, q in
                    CauNoiSH(khoa: "noi|\(id)|\(i)|\(lamLai)", q: q, part: part, ngoai: ngoai, giongHoi: ngoai ? "\(vm.khoa?.ngonNgu ?? "ja")-nam" : "uk-nam")
                }
            }
            .id(lamLai)
            HStack {
                Spacer()
                NutSH(ten: "Làm lại cả bài", bieuTuong: "arrow.counterclockwise", phu: true) { MayThuSH.chung.huy(); lamLai += 1 }
            }
        }
    }
}

private struct CauNoiSH: View {
    let khoa: String
    let q: String
    let part: String
    let ngoai: Bool
    let giongHoi: String
    @ObservedObject private var may = MayThuSH.chung
    @State private var tep: URL?
    @State private var dangCham = false
    @State private var kq: DapAnChamNoi?
    @State private var loi: String?

    var body: some View {
        let dangGhi = may.dangGhi == khoa
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text("🎙").font(.system(size: 18)).frame(width: 34, height: 34).background(Circle().fill(MauChuSH.mau(0x1E3A8A).color.opacity(0.15)))
                Button { GiongSachHoc.chung.phat(ClipSH(text: q, giong: giongHoi), khoa: "hoi|\(khoa)") } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 13)).foregroundColor(AppColors.primary).padding(.top, 3)
                        ChuSH(text: q, co: 17)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundTertiary))
                }
                .buttonStyle(.plain)
                .environment(\.moChuHanSH, nil)
            }
            HStack(spacing: 10) {
                if dangGhi {
                    Button { may.dung() } label: {
                        Label("Xong", systemImage: "stop.fill").font(.system(size: 14.5, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .foregroundColor(.white).background(Capsule().fill(AppColors.error))
                    }
                    .buttonStyle(.plain)
                    ThanhMucSH(muc: may.muc)
                } else {
                    NutSH(ten: may.dangMo == khoa ? "Đang mở micro…" : (tep == nil ? "Trả lời (ghi âm)" : "Ghi lại"), bieuTuong: "mic.fill", phu: true) { ghi() }
                        .disabled(may.dangMo != nil)
                }
                if let tep, !dangGhi {
                    Button { may.phat(tep) } label: {
                        Label(may.dangPhatLai == tep ? "Dừng" : "Nghe lại", systemImage: may.dangPhatLai == tep ? "stop.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    if !ngoai {
                        NutSH(ten: dangCham ? "Đang chấm…" : "AI chấm", bieuTuong: "sparkles") { Task { await cham(tep) } }
                            .disabled(dangCham).opacity(dangCham ? 0.6 : 1)
                    }
                }
            }
            .padding(.leading, 42)
            if let l = loi ?? may.loi[khoa] { PhanHoiSH(dung: false, chu: l).padding(.leading, 42) }
            if let k = kq?.ketQua, !k.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if let chu = kq?.chu, !chu.isEmpty {
                        Text("Máy nghe được: “\(chu)”").font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary)
                    }
                    NoiDungMarkdown(noiDung: k)
                }
                .theKhoiSH(vien: AppColors.primary.opacity(0.3), nen: AppColors.primary.opacity(0.05))
                .padding(.leading, 42)
            }
        }
        .onDisappear { if may.dangGhi == khoa { may.huy() } }
    }

    private func ghi() {
        kq = nil; loi = nil; tep = nil
        Task {
            await may.batDau(khoa, kieu: .m4a, toiDa: 180, tuDungKhiIm: false) { url, _ in
                tep = url
            }
        }
    }

    private func cham(_ u: URL) async {
        dangCham = true; loi = nil
        defer { dangCham = false }
        do {
            let d = try await APIClient.shared.guiAudioChamNoi(duong: u, cauHoi: PhanTichChuSH.tron(q), part: part)
            if d.ketQua?.isEmpty == false { kq = d }
            else { loi = d.lyDo == "khong_nghe_thay" ? "Chưa nghe thấy bạn nói — thử nói to và gần micro hơn." : "Chưa chấm được, thử lại nhé." }
        } catch APIError.unauthorized {
            loi = "Đăng nhập để AI chấm phần nói."
        } catch {
            loi = error.localizedDescription
        }
    }
}

// MARK: - Chấm phát âm (phatam)

struct KetQuaPhatAmSH: Decodable {
    struct Diem: Decodable { let chinhXac: Double; let troiChay: Double; let dayDu: Double; let tong: Double }
    struct Am: Decodable { var am: String; let diem: Double }
    struct Tu: Decodable { let tu: String; let diem: Double; var loi: String; var am: [Am] }
    let diem: Diem
    var ngheRa: String
    var tu: [Tu]

    enum CodingKeys: String, CodingKey { case diem, ngheRa, tu }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        diem = try c.decode(Diem.self, forKey: .diem)
        ngheRa = (try? c.decode(String.self, forKey: .ngheRa)) ?? ""
        tu = (try? c.decode([Tu].self, forKey: .tu)) ?? []
    }
    init(diem: Diem, ngheRa: String, tu: [Tu]) { self.diem = diem; self.ngheRa = ngheRa; self.tu = tu }
}

extension KetQuaPhatAmSH.Tu {
    enum CodingKeys: String, CodingKey { case tu, diem, loi, am }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        tu = (try? c.decode(String.self, forKey: .tu)) ?? ""
        diem = (try? c.decode(Double.self, forKey: .diem)) ?? 0
        loi = (try? c.decode(String.self, forKey: .loi)) ?? ""
        am = (try? c.decode([KetQuaPhatAmSH.Am].self, forKey: .am)) ?? []
    }
}

extension KetQuaPhatAmSH.Am {
    enum CodingKeys: String, CodingKey { case am, diem }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        am = (try? c.decode(String.self, forKey: .am)) ?? ""
        diem = (try? c.decode(Double.self, forKey: .diem)) ?? 0
    }
}

enum PhatAmSH {
    static let LOI: [String: String] = [
        "chua_co_khoa": "Máy chấm phát âm chưa được bật trên máy chủ.",
        "het_luot_ngay": "Hôm nay bạn đã chấm 150 lượt — mai luyện tiếp nhé.",
        "het_luot_thang": "Máy chấm phát âm đã hết lượt miễn phí của tháng này.",
        "khong_nghe_thay": "Chưa nghe rõ — đọc to, gần micro hơn và đọc đúng câu mẫu.",
        "loi_may_cham": "Máy chấm đang trục trặc, thử lại sau ít phút.",
    ]

    /// Tách phiên âm thành âm: nhị trùng âm, tʃ/dʒ và nguyên âm dài (ː) là MỘT âm — `tachAm` của web.
    static func tachAm(_ ipa: String) -> [String] {
        let ghep = ["eɪ", "aɪ", "ɔɪ", "aʊ", "əʊ", "oʊ", "ɪə", "eə", "ʊə", "tʃ", "dʒ"]
        let t = Array(ipa.filter { !"ˈˌ./".contains($0) }.unicodeScalars)
        var out: [String] = []
        var i = 0
        while i < t.count {
            var a = ""
            if let g = ghep.first(where: { g in
                let gs = Array(g.unicodeScalars)
                return i + gs.count <= t.count && Array(t[i..<(i + gs.count)]) == gs
            }) {
                a = g; i += g.unicodeScalars.count
            } else {
                a = String(t[i]); i += 1
            }
            if i < t.count, t[i] == "ː" { a += "ː"; i += 1 }
            out.append(a)
        }
        return out
    }

    static func mau(_ d: Double) -> Color { d >= 80 ? AppColors.success : d >= 60 ? AppColors.warning : AppColors.error }

    /// Gửi WAV 16 kHz lên `/ielts/ai/cham-phat-am` (multipart). Tự dựng URLRequest ⇒ PHẢI xin đồng ý AI trước.
    static func gui(_ tep: URL, cau: String, giong: String) async throws -> (KetQuaPhatAmSH?, String?) {
        try await DongYChiaSeAI.batBuoc()
        guard let url = URL(string: APIClient.diaChiGoc + "/api/v1/ielts/ai/cham-phat-am") else { throw APIError.invalidURL }
        let bien = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 90
        req.setValue("multipart/form-data; boundary=\(bien)", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.nenTang, forHTTPHeaderField: "X-Client-Platform")
        if let tok = StorageManager.shared.getAuthToken() { req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization") }
        var than = Data()
        func them(_ s: String) { than.append(Data(s.utf8)) }
        for (k, v) in [("cau", cau), ("giong", giong)] {
            them("--\(bien)\r\nContent-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n")
        }
        them("--\(bien)\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"phat-am.wav\"\r\nContent-Type: audio/wav\r\n\r\n")
        than.append(try Data(contentsOf: tep))
        them("\r\n--\(bien)--\r\n")
        req.httpBody = than
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.unknown }
        if http.statusCode == 401 { throw APIError.unauthorized }
        struct Goi: Decodable { let success: Bool; let message: String?; let data: D? }
        struct D: Decodable { let ketQua: KetQuaPhatAmSH?; let lyDo: String? }
        let g = try JSONDecoder().decode(Goi.self, from: data)
        guard g.success, let d = g.data else { throw APIError.serverError(g.message ?? "Máy chủ từ chối bản ghi") }
        return (d.ketQua, d.lyDo)
    }
}

struct PhatAmKhoiSH: View {
    let id: String
    let title: String?
    let note: String?
    let items: [CauPhatAmSH]
    @EnvironmentObject private var vm: SachHocVM
    @AppStorage("sachhoc:phat-am-giong") private var giongAnh = "uk"

    private var nn: String { vm.khoa?.ngonNgu ?? "en" }

    var body: some View {
        KhungBaiTapSH(bieuTuong: "waveform", tieuDe: title ?? "Luyện phát âm — máy chấm từng âm",
                      huongDan: note.map(PhanTichChuSH.tron) ?? "Bấm “Nghe mẫu”, rồi “Đọc & chấm” và đọc to đúng câu đó (tối đa 15 giây). Máy tô màu từng từ và từng âm: xanh là đúng, vàng là gần đúng, đỏ là cần sửa.") {
            if nn == "en" {
                Picker("Chấm theo giọng", selection: $giongAnh) {
                    Text("🇬🇧 Giọng Anh").tag("uk")
                    Text("🇺🇸 Giọng Mỹ").tag("us")
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                    CauPhatAmView(khoa: "pa|\(id)|\(i)|\(nn == "en" ? giongAnh : nn)", cau: it, giong: nn == "en" ? giongAnh : nn)
                    if i < items.count - 1 { Divider() }
                }
            }
        }
    }
}

private struct CauPhatAmView: View {
    let khoa: String
    let cau: CauPhatAmSH
    let giong: String
    @ObservedObject private var may = MayThuSH.chung
    @State private var tep: URL?
    @State private var dangCham = false
    @State private var kq: KetQuaPhatAmSH?
    @State private var loi: String?

    private var ngoai: Bool { giong == "ja" || giong == "zh" }
    private var giongMau: String { ["uk": "uk-nu", "us": "us-nu", "ja": "ja-nu", "zh": "zh-nu"][giong] ?? "uk-nu" }

    var body: some View {
        let dangGhi = may.dangGhi == khoa
        VStack(alignment: .leading, spacing: 8) {
            ChuSH(text: cau.text, co: 20, dam: true)
            Text((ngoai ? cau.ipa : "/\(cau.ipa)/") + (cau.vi.map { " · \($0)" } ?? ""))
                .font(.system(size: 13.5)).foregroundColor(AppColors.textTertiary)
            HStack(spacing: 8) {
                NutSH(ten: "Nghe mẫu", bieuTuong: "speaker.wave.2.fill", phu: true) { GiongSachHoc.chung.phat(ClipSH(text: cau.text, giong: giongMau), khoa: "mau|\(khoa)") }
                if dangGhi {
                    Button { may.dung() } label: {
                        Label("Xong", systemImage: "stop.fill").font(.system(size: 14.5, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .foregroundColor(.white).background(Capsule().fill(AppColors.error))
                    }
                    .buttonStyle(.plain)
                } else {
                    NutSH(ten: may.dangMo == khoa ? "Đang mở micro…" : dangCham ? "Đang chấm…" : kq != nil ? "Đọc lại" : "Đọc & chấm", bieuTuong: "mic.fill") { ghi() }
                        .disabled(dangCham || may.dangMo != nil).opacity(dangCham ? 0.6 : 1)
                }
            }
            if dangGhi {
                HStack(spacing: 8) {
                    Circle().fill(AppColors.error).frame(width: 8, height: 8)
                    Text("Đang nghe — đọc to dòng trên, nói xong máy tự chấm").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    ThanhMucSH(muc: may.muc)
                }
            }
            if let l = loi ?? may.loi[khoa] { PhanHoiSH(dung: false, chu: l) }
            if let kq { ketQua(kq) }
        }
        .onDisappear { if may.dangGhi == khoa { may.huy() } }
        #if DEBUG
        .onAppear {
            // Màn soi: `CT_SACHHOC_DIEN=1` ⇒ câu đầu có sẵn một kết quả mẫu (máy ảo không nói vào micro được).
            guard ProcessInfo.processInfo.environment["CT_SACHHOC_DIEN"] == "1", kq == nil, khoa.contains("|0|") else { return }
            let tus = PhanTichChuSH.tron(cau.text).split(separator: " ").map(String.init)
            kq = KetQuaPhatAmSH(diem: .init(chinhXac: 78, troiChay: 85, dayDu: 100, tong: 81), ngheRa: PhanTichChuSH.tron(cau.text),
                                tu: tus.enumerated().map { i, w in .init(tu: w, diem: i == tus.count - 1 ? 52 : 88, loi: "None", am: [.init(am: "", diem: 90), .init(am: "", diem: i == tus.count - 1 ? 40 : 82)]) })
        }
        #endif
    }

    private func ghi() {
        kq = nil; loi = nil
        Task {
            await may.batDau(khoa, kieu: .wav16k, toiDa: 15, tuDungKhiIm: true) { url, coTieng in
                tep = url
                // Im lặng cả lượt (bấm nhầm) thì đừng gửi: máy chấm coi là "đọc thiếu" từng từ.
                guard coTieng else { loi = "Mình chưa nghe thấy bạn nói gì. Bấm “Đọc & chấm” rồi đọc to câu trên nhé."; return }
                Task { await cham(url) }
            }
        }
    }

    private func cham(_ u: URL) async {
        dangCham = true
        defer { dangCham = false }
        do {
            let (k, lyDo) = try await PhatAmSH.gui(u, cau: PhanTichChuSH.tron(cau.text), giong: giong)
            if let k { kq = k } else { loi = PhatAmSH.LOI[lyDo ?? ""] ?? "Chưa chấm được, thử lại nhé." }
        } catch APIError.unauthorized {
            loi = "Đăng nhập để chấm phát âm."
        } catch {
            loi = error.localizedDescription
        }
    }

    /// Gắn phiên âm của bài vào từ máy chấm trả về (bỏ từ "Insertion" — đọc thừa). Tiếng Nhật/Trung: không tách tên âm.
    private func tuCoTen(_ kq: KetQuaPhatAmSH) -> [(tu: KetQuaPhatAmSH.Tu, ipa: String?)] {
        let ipaTu = ngoai ? [] : cau.ipa.split(whereSeparator: \.isWhitespace).map(String.init)
        var vi = 0
        return kq.tu.map { w in
            var w = w
            let ipa: String? = w.loi == "Insertion" ? nil : (vi < ipaTu.count ? ipaTu[vi] : nil)
            if w.loi != "Insertion" { vi += 1 }
            let ten = ipa.map(PhatAmSH.tachAm) ?? []
            w.am = w.am.enumerated().map { i, a in
                var a = a
                if a.am.isEmpty, ten.count == w.am.count { a.am = ten[i] }
                return a
            }
            return (w, ipa)
        }
    }

    @ViewBuilder
    private func ketQua(_ kq: KetQuaPhatAmSH) -> some View {
        let tu = tuCoTen(kq)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("\(Int(kq.diem.tong.rounded()))").font(.system(size: 30, weight: .heavy).monospacedDigit()).foregroundColor(PhatAmSH.mau(kq.diem.tong))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chính xác \(Int(kq.diem.chinhXac.rounded())) · Trôi chảy \(Int(kq.diem.troiChay.rounded())) · Đọc đủ \(Int(kq.diem.dayDu.rounded()))")
                        .font(.system(size: 13.5, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                }
            }
            HangCuonSH(cach: 6) {
                ForEach(Array(tu.enumerated()), id: \.offset) { _, x in
                    let w = x.tu
                    VStack(spacing: 3) {
                        Text(w.tu).font(.system(size: 16, weight: .bold)).foregroundColor(w.loi == "Omission" ? AppColors.textTertiary : PhatAmSH.mau(w.diem))
                            .strikethrough(w.loi == "Omission")
                        if w.loi == "Omission" { Text("đọc thiếu").font(.system(size: 10.5)).foregroundColor(AppColors.textTertiary) }
                        else if w.loi == "Insertion" { Text("đọc thừa").font(.system(size: 10.5)).foregroundColor(AppColors.textTertiary) }
                        else {
                            HStack(spacing: 2) {
                                ForEach(Array(w.am.enumerated()), id: \.offset) { _, a in
                                    Text(a.am.isEmpty ? "•" : a.am).font(.system(size: 11.5, weight: .semibold)).foregroundColor(PhatAmSH.mau(a.diem))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill((w.loi == "Omission" ? AppColors.textTertiary : PhatAmSH.mau(w.diem)).opacity(0.1)))
                }
            }
            goiY(tu)
            if !kq.ngheRa.isEmpty { Text("Máy nghe ra: “\(kq.ngheRa)”").font(.system(size: 13)).foregroundColor(AppColors.textSecondary) }
            if let tep {
                Button { may.phat(tep) } label: {
                    Label(may.dangPhatLai == tep ? "Dừng" : "Nghe lại bản ghi của bạn", systemImage: may.dangPhatLai == tep ? "stop.fill" : "play.circle.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .theKhoiSH(vien: PhatAmSH.mau(kq.diem.tong).opacity(0.4), nen: PhatAmSH.mau(kq.diem.tong).opacity(0.05))
    }

    @ViewBuilder
    private func goiY(_ tu: [(tu: KetQuaPhatAmSH.Tu, ipa: String?)]) -> some View {
        let that = tu.filter { $0.tu.loi != "Insertion" }
        if ngoai {
            if let t = that.min(by: { $0.tu.diem < $1.tu.diem }), t.tu.diem < 80 {
                ChuSH(text: "Chữ cần sửa nhất: **\(t.tu.tu)** (\(Int(t.tu.diem)) điểm). " + (giong == "zh" ? "Nghe lại mẫu, để ý THANH ĐIỆU của chữ đó." : "Nghe lại mẫu, để ý độ dài âm (trường âm, っ, ん)."), co: 13.5, mau: .phu)
            }
        } else {
            let yeu = tu.flatMap { x in x.tu.am.map { (am: $0.am, diem: $0.diem, tu: x.tu.tu) } }.filter { !$0.am.isEmpty && $0.diem < 70 }.min { $0.diem < $1.diem }
            if let y = yeu {
                ChuSH(text: "Âm cần sửa nhất: **/\(y.am)/** trong “\(y.tu)” (\(Int(y.diem)) điểm). Bấm “Nghe mẫu”, để ý khẩu hình âm đó rồi đọc lại.", co: 13.5, mau: .phu)
            }
            if let cuoi = that.last, cuoi.tu.loi == "Omission" || cuoi.tu.diem < 60 {
                ChuSH(text: "💡 Chữ cuối “**\(cuoi.tu.tu)**” bị chấm thấp. Người Việt rất hay **nuốt âm cuối** ở từ cuối câu — đọc rõ trọn âm cuối" + (cuoi.ipa.map { " (**/\($0)/**)" } ?? "") + ", giữ hơi thêm một nhịp rồi mới dừng. Nghe lại bản ghi xem âm cuối có rõ không.", co: 13.5, mau: .phu)
            }
        }
    }
}
#endif
