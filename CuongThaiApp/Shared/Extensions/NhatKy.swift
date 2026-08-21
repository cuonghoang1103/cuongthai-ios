import Foundation

/// Nhật ký chẩn đoán — ghi ra FILE trong thư mục Documents của app.
///
/// ⚠️ Vì sao không dùng console: `devicectl … --console` phải giữ kết nối
/// suốt, app tắt hay tunnel rớt là mất sạch — đã thử hai lần, cả hai lần chỉ
/// bắt được dòng khởi động rồi đứt. `os.Logger` thì console không thấy, mà
/// `log stream --device` đã bị macOS 26 bỏ.
///
/// Ghi ra file thì người dùng cứ dùng app bình thường; lấy về bằng:
///   xcrun devicectl device copy from --device <id> --domain-type appDataContainer \
///     --domain-identifier com.cuongthai.app --source Documents/nhatky.txt --destination .
enum NhatKy {
    private static let hang = DispatchQueue(label: "nhatky", qos: .utility)
    private static let dinhDang: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    private static var duong: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("nhatky.txt")
    }

    /// ⚠️ CHỈ ghi ở bản gỡ lỗi. Bản phát hành (TestFlight/App Store) không
    /// được ghi file chẩn đoán: nó phình theo thời gian và lộ nội dung tin
    /// nhắn ra một file người khác đọc được qua chia sẻ máy.
    ///
    /// Giữ nguyên toàn bộ lời gọi `NhatKy.*` rải trong mã — chúng thành lệnh
    /// rỗng ở Release, và còn đó để lần sau cần đo lại là bật ngay.
    private static func ghi(_ nhom: String, _ chu: String) {
        #if !DEBUG
        return
        #else
        let dong = "\(dinhDang.string(from: Date())) [\(nhom)] \(chu)\n"
        print(dong, terminator: "")   // vẫn ra console nếu ai đó đang nghe
        hang.async {
            guard let d = duong, let data = dong.data(using: .utf8) else { return }
            if let f = try? FileHandle(forWritingTo: d) {
                defer { try? f.close() }
                _ = try? f.seekToEnd()
                try? f.write(contentsOf: data)
            } else {
                try? data.write(to: d)
            }
        }
        #endif
    }

    struct Kenh {
        let ten: String
        func info(_ s: String) { NhatKy.ghi(ten, s) }
        func error(_ s: String) { NhatKy.ghi(ten, "LỖI — " + s) }
    }
    static let socket = Kenh(ten: "socket")
    static let tinNhan = Kenh(ten: "tin-nhan")
    static let thongBao = Kenh(ten: "thong-bao")
    static let goi = Kenh(ten: "goi")
    static let noi = Kenh(ten: "luyen-noi")

    /// Đánh dấu một lượt chạy mới — KHÔNG xoá gì.
    ///
    /// ⚠️ Bản trước xoá sạch file mỗi lần khởi động. Mà chạm thông báo lúc app
    /// đã tắt thì CHÍNH cú chạm đó khởi động app ⇒ nhật ký bị xoá ngay trước
    /// khi ghi được điều đáng ghi. Người dùng chạm thật, còn tôi đọc file
    /// trống rồi kết luận "chưa ai chạm". Bộ đo tự xoá bằng chứng của chính nó.
    ///
    /// Giữ tối đa ~200KB rồi mới cắt bớt phần đầu, để file không phình mãi.
    static func xoaCu() {
        #if !DEBUG
        return
        #else
        guard let d = duong else { return }
        if let cd = try? FileManager.default.attributesOfItem(atPath: d.path)[.size] as? Int,
           cd > 200_000,
           let noi = try? String(contentsOf: d, encoding: .utf8) {
            let giu = noi.suffix(100_000)
            try? String(giu).write(to: d, atomically: true, encoding: .utf8)
        }
        ghi("khoi-dong", "════ LƯỢT CHẠY MỚI ════")
        #endif
    }
}
