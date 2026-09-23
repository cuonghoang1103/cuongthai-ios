import Foundation

// ════════════════════════════════════════════════════════════════
// HỒ SƠ NGÀNH CỦA ACADEMY — bản iOS của `hooks/useAcademyProfile.ts`
//
// Hai lớp lưu, y như web:
//  · UserDefaults — luôn có, kể cả chưa đăng nhập.
//  · `preferences.academy` trên máy chủ — khi đã đăng nhập, để lựa chọn theo
//    người dùng sang web / máy khác. Ghi máy trước, gửi máy chủ sau; gửi hỏng
//    KHÔNG được làm mất lựa chọn vừa chọn.
//
// Hai bên lệch nhau thì ai trả lời SAU (`chosenAt`) thắng.
//
// `isStudent == false` là một câu trả lời thật ("không phải SV FPTU"), không
// phải "chưa trả lời". Chỉ `isStudent == nil` mới mở màn hỏi.
// ════════════════════════════════════════════════════════════════

struct HoSoNganh: Codable, Equatable {
    var isStudent: Bool?
    /// Khối: "it" | "business" | "communication" | "language" | "cs".
    var faculty: String?
    var major: String?
    var combo: String?
    var chosenAt: String?

    static let trong = HoSoNganh()

    var thoiDiem: Date {
        guard let chosenAt else { return .distantPast }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: chosenAt) ?? ISO8601DateFormatter().date(from: chosenAt) ?? .distantPast
    }

    var thanhTuDien: [String: Any] {
        [
            "isStudent": isStudent.map { $0 as Any } ?? NSNull(),
            "faculty": faculty.map { $0 as Any } ?? NSNull(),
            "major": major.map { $0 as Any } ?? NSNull(),
            "combo": combo.map { $0 as Any } ?? NSNull(),
            "chosenAt": chosenAt.map { $0 as Any } ?? NSNull(),
        ]
    }
}

@MainActor
final class HoSoAcademy: ObservableObject {
    static let shared = HoSoAcademy()

    @Published private(set) var hoSo: HoSoNganh

    /// Cùng tên khoá với web cho dễ đối chiếu; hai nơi lưu vẫn tách biệt.
    private let khoa = "cuong-academy-profile-v1"
    private var daKeo = false

    private init() {
        if let d = UserDefaults.standard.data(forKey: khoa),
           let h = try? JSONDecoder().decode(HoSoNganh.self, from: d) {
            hoSo = h
        } else {
            hoSo = .trong
        }
    }

    /// Robot chỉ hỏi khi chưa ai trả lời.
    var canHoi: Bool { hoSo.isStudent == nil }

    /// Lưu lựa chọn.
    /// - Parameter ghiNho: `false` = chỉ áp dụng cho lần mở app này, không ghi
    ///   máy lẫn máy chủ — lần sau mở app sẽ hỏi lại (đúng như công tắc nói).
    func luu(isStudent: Bool, faculty: String?, major: String?, combo: String?, ghiNho: Bool) {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let moi = HoSoNganh(isStudent: isStudent, faculty: faculty, major: major, combo: combo,
                            chosenAt: f.string(from: Date()))
        hoSo = moi
        guard ghiNho else { return }
        ghiMay(moi)
        guard AppState.shared.isAuthenticated else { return }
        Task {
            // Hỏng thì thôi — bản trên máy vẫn đứng, lần lưu sau gửi lại.
            try? await APIClient.shared.send(.luuHoSoAcademy(hoSo: moi.thanhTuDien))
        }
    }

    /// Kéo bản trên máy chủ MỘT lần mỗi phiên, giữ bản mới hơn.
    func keoTuMayChu() async {
        guard AppState.shared.isAuthenticated, !daKeo else { return }
        daKeo = true
        struct TuyChon: Decodable {
            struct Pref: Decodable { let academy: HoSoNganh? }
            let preferences: Pref?
        }
        guard let tc: TuyChon = try? await APIClient.shared.request(.layTuyChonNguoiDung),
              var xa = tc.preferences?.academy else {
            daKeo = false   // mất mạng — cho lần mở sau thử lại
            return
        }
        // ⚠️ Bản ghi cũ trên máy chủ KHÔNG có `faculty` (allowlist của máy chủ
        // từng bỏ rơi nó). Suy khối từ ngành — mã ngành là duy nhất qua các khối.
        if xa.faculty == nil, let m = xa.major {
            xa.faculty = DanhMucNganh.shared.khoiCua(nganh: m)
        }
        if xa.thoiDiem > hoSo.thoiDiem {
            hoSo = xa
            ghiMay(xa)
        }
    }

    private func ghiMay(_ h: HoSoNganh) {
        if let d = try? JSONEncoder().encode(h) {
            UserDefaults.standard.set(d, forKey: khoa)
        }
    }
}
