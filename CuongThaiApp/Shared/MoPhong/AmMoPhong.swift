import Foundation
import AVFoundation

// ════════════════════════════════════════════════════════════════
// ÂM THANH MÔ PHỎNG — port nguyên 9 công thức của web
//
// Nguồn: `frontend/src/components/simulation/sfx.ts`. Web tổng hợp bằng Web
// Audio (dao động ký + nhiễu qua bộ lọc dải), KHÔNG dùng file âm thanh nào.
// Bên này dựng thẳng đệm PCM bằng Swift theo đúng công thức ấy, rồi phát qua
// `AVAudioEngine` — nhờ vậy hai nơi nghe giống nhau và app không phải mang
// thêm tệp tài nguyên.
//
// ⚠️ TẤT ĐỊNH: nhiễu trắng sinh bằng LCG hạt giống CỐ ĐỊNH (0x2f6e2b1), đúng
// hằng số của web. Dùng `Double.random` thì mỗi lần chạy một tiếng khác.
//
// ⚠️ Đệm dựng MỘT LẦN rồi dùng lại. Tổng hợp lại mỗi lần phát là vài ms tính
// toán ngay giữa lúc hoạt ảnh đang chạy — đủ để thấy khựng.
//
// ⚠️ Phiên âm thanh dùng `.ambient` + `.mixWithOthers`: tiếng hiệu ứng là
// thông tin PHỤ, nó không có quyền ngắt nhạc người dùng đang nghe, và phải
// im khi máy gạt sang chế độ rung. Xem cùng lý lẽ trong `AmThanh.swift`.
// ════════════════════════════════════════════════════════════════

enum TiengMP: String, CaseIterable {
    case click, blip, swoosh, stream, ping, success, lock, buzz, error
}

@MainActor
final class AmMoPhong {
    static let shared = AmMoPhong()

    private let mau = 44100.0
    private var may: AVAudioEngine?
    private var nut: AVAudioPlayerNode?
    private var dem: [TiengMP: AVAudioPCMBuffer] = [:]
    private var nhieu: [Float] = []

    private init() {}

    /// Bật/tắt do người dùng chọn, nhớ qua các lần mở app.
    static var bat: Bool {
        get { UserDefaults.standard.object(forKey: "mophong.am") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "mophong.am") }
    }

    func phat(_ t: TiengMP) {
        guard Self.bat else { return }
        chuanBi()
        guard let nut, let b = dem[t] ?? dung(t) else { return }
        dem[t] = b
        nut.scheduleBuffer(b, at: nil, options: [], completionHandler: nil)
        if !nut.isPlaying { nut.play() }
    }

    func phat(_ ten: String?) {
        guard let ten, let t = TiengMP(rawValue: ten) else { return }
        phat(t)
    }

    // MARK: Máy phát

    private func chuanBi() {
        guard may == nil else { return }
        // ⚠️ Đang trong cuộc gọi thì TUYỆT ĐỐI không đụng vào phiên — WebRTC
        // đang giữ nó. Cùng cái bẫy đã ghi trong `AmThanh.swift`.
        if AmThanh.shared.dangTrongCuocGoi { return }
        let phien = AVAudioSession.sharedInstance()
        try? phien.setCategory(.ambient, options: [.mixWithOthers])
        try? phien.setActive(true)

        let e = AVAudioEngine()
        let n = AVAudioPlayerNode()
        e.attach(n)
        guard let dinhDang = AVAudioFormat(standardFormatWithSampleRate: mau, channels: 1) else { return }
        e.connect(n, to: e.mainMixerNode, format: dinhDang)
        do { try e.start() } catch {
            NhatKy.sach.error("không mở được máy âm mô phỏng: \(error)")
            return
        }
        may = e; nut = n
        if nhieu.isEmpty { nhieu = dungNhieu() }
    }

    /// Nhiễu trắng 1 giây, LCG hạt giống cố định — chép hằng số của web.
    private func dungNhieu() -> [Float] {
        var seed: UInt32 = 0x2F6E2B1
        return (0..<Int(mau)).map { _ in
            seed = seed &* 1664525 &+ 1013904223
            return Float(Double(seed) / 2147483648.0 - 1.0)
        }
    }

    // MARK: Tổng hợp

    private func dung(_ t: TiengMP) -> AVAudioPCMBuffer? {
        var v = [Float](repeating: 0, count: Int(mau * 1.2))   // 1,2 s là đủ cho hiệu ứng dài nhất
        switch t {
        case .click:
            not(&v, 0, 1400, .vuong, 0.045, 0.06)
        case .blip:
            not(&v, 0, 660, .tamGiac, 0.09, 0.10)
        case .swoosh:
            gio(&v, 0, from: 380, to: 2600, dur: 0.30, gain: 0.13, q: 1.1)
        case .stream:
            gio(&v, 0, from: 900, to: 900, dur: 0.50, gain: 0.05, q: 6)
        case .ping:
            // Quãng năm hoàn hảo — nghe "sạch".
            not(&v, 0, 988, .sin, 0.34, 0.16)
            not(&v, 0.012, 1480, .sin, 0.26, 0.08)
        case .success:
            // Hợp âm rải trưởng (C–E–G): tín hiệu "xong việc" quen thuộc.
            not(&v, 0, 523.25, .tamGiac, 0.24, 0.16)
            not(&v, 0.075, 659.25, .tamGiac, 0.24, 0.15)
            not(&v, 0.15, 783.99, .tamGiac, 0.36, 0.17)
        case .lock:
            not(&v, 0, 440, .vuong, 0.07, 0.08)
            not(&v, 0.07, 880, .vuong, 0.12, 0.09)
            gio(&v, 0, from: 3000, to: 900, dur: 0.10, gain: 0.05, q: 3, cao: true)
        case .buzz:
            not(&v, 0, 190, .rangCua, 0.10, 0.10)
            not(&v, 0.13, 150, .rangCua, 0.13, 0.10)
        case .error:
            // Cố tình khó chịu: răng cưa trượt xuống + nhiễu trầm.
            not(&v, 0, 220, .rangCua, 0.42, 0.17, quetToi: 70)
            not(&v, 0, 110, .vuong, 0.38, 0.10, quetToi: 55)
            gio(&v, 0, from: 700, to: 120, dur: 0.34, gain: 0.09, q: 0.8)
        }
        guard let f = AVAudioFormat(standardFormatWithSampleRate: mau, channels: 1),
              let b = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: AVAudioFrameCount(v.count))
        else { return nil }
        b.frameLength = AVAudioFrameCount(v.count)
        v.withUnsafeBufferPointer { p in
            b.floatChannelData![0].update(from: p.baseAddress!, count: v.count)
        }
        return b
    }

    private enum Dang { case sin, vuong, tamGiac, rangCua }

    /// Một nốt: dao động ký + envelope tăng 6ms rồi tắt theo hàm mũ.
    ///
    /// ⚠️ 6ms tăng dần là BẮT BUỘC, không phải làm đẹp: nhảy biên độ đột ngột
    /// từ 0 lên đỉnh tạo tiếng "cạch" nghe rõ trên tai nghe.
    private func not(_ v: inout [Float], _ tre: Double, _ f0: Double, _ dang: Dang,
                     _ dur: Double, _ gain: Double, quetToi: Double? = nil) {
        let b = Int(tre * mau), n = Int(dur * mau)
        var pha = 0.0
        for i in 0..<n {
            let k = b + i
            guard k < v.count else { break }
            let t = Double(i) / mau
            let f = quetToi.map { f0 * pow(max($0, 20) / f0, t / dur) } ?? f0
            pha += 2 * .pi * f / mau
            let s: Double
            switch dang {
            case .sin:      s = sin(pha)
            case .vuong:    s = sin(pha) >= 0 ? 1 : -1
            case .tamGiac:  s = 2 / .pi * asin(sin(pha))
            case .rangCua:  s = 2 * (pha / (2 * .pi) - floor(0.5 + pha / (2 * .pi)))
            }
            // Envelope: 0,0001 → gain trong 6ms, rồi → 0,0001 tới hết.
            let e: Double
            if t < 0.006 { e = 0.0001 * pow(gain / 0.0001, t / 0.006) }
            else { e = gain * pow(0.0001 / gain, (t - 0.006) / max(dur - 0.006, 0.001)) }
            v[k] += Float(s * e)
        }
    }

    /// Nhiễu qua bộ lọc dải quét tần số — nền của mọi tiếng "gió".
    ///
    /// Biquad theo công thức RBJ, hệ số tính LẠI mỗi mẫu vì tần số đang quét.
    private func gio(_ v: inout [Float], _ tre: Double, from: Double, to: Double,
                     dur: Double, gain: Double, q: Double, cao: Bool = false) {
        guard !nhieu.isEmpty else { return }
        let b = Int(tre * mau), n = Int(dur * mau)
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        for i in 0..<n {
            let k = b + i
            guard k < v.count else { break }
            let t = Double(i) / mau
            let f = from * pow(to / from, t / dur)
            let w = 2 * .pi * f / mau
            let al = sin(w) / (2 * q)
            let cw = cos(w)
            // bandpass (đỉnh = Q) hoặc highpass, đúng hai loại web dùng.
            let b0: Double, b1: Double, b2: Double
            if cao { b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2 }
            else   { b0 = al;           b1 = 0;         b2 = -al }
            let a0 = 1 + al, a1 = -2 * cw, a2 = 1 - al
            let x0 = Double(nhieu[i % nhieu.count])
            let y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            x2 = x1; x1 = x0; y2 = y1; y1 = y0
            // Envelope: lên đỉnh ở 25% thời lượng rồi tắt dần.
            let e: Double
            if t < dur * 0.25 { e = 0.0001 * pow(gain / 0.0001, t / (dur * 0.25)) }
            else { e = gain * pow(0.0001 / gain, (t - dur * 0.25) / (dur * 0.75)) }
            v[k] += Float(y0 * e)
        }
    }
}
