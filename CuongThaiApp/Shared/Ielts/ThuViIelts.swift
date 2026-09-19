import SwiftUI
import UserNotifications

// ════════════════════════════════════════════════════════════════
// PHẦN "THÚ VỊ" CỦA IELTS — tim, ăn mừng, nhắc giữ chuỗi, nhân vật.
//
// Người dùng: "đối với 1 người lười học tiếng anh như tôi... tôi muốn sự
// thú vị, giống Duolingo". Nội dung đã đủ (597 mục), cái thiếu là lý do
// quay lại ngày mai.
// ════════════════════════════════════════════════════════════════

// MARK: - Tim

/// Năm tim mỗi ngày, hết thì nghỉ tới hôm sau.
///
/// ⚠️ Tim là con dao hai lưỡi. Duolingo dùng được vì hết tim thì mua được
/// hoặc chờ hồi; ở đây KHÔNG bán gì, nên tim chỉ có một việc: làm mỗi câu
/// sai có sức nặng. Vì thế nó **không chặn học** — hết tim vẫn học tiếp
/// được, chỉ là không còn được tính XP cho tới hôm sau. Chặn hẳn một người
/// vốn đã lười là đuổi họ đi.
@MainActor
final class TimIelts: ObservableObject {
    static let chung = TimIelts()

    @Published private(set) var con = 5
    private let toiDa = 5
    private let khoaNgay = "ielts.tim.ngay"
    private let khoaCon = "ielts.tim.con"

    private var lich: Calendar {
        var l = Calendar(identifier: .gregorian)
        l.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        return l
    }

    private init() { nap() }

    private func maNgay() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = lich.timeZone
        return f.string(from: Date())
    }

    private func nap() {
        let ud = UserDefaults.standard
        if ud.string(forKey: khoaNgay) == maNgay() {
            con = ud.object(forKey: khoaCon) as? Int ?? toiDa
        } else {
            con = toiDa
            ghi()
        }
    }

    private func ghi() {
        let ud = UserDefaults.standard
        ud.set(maNgay(), forKey: khoaNgay)
        ud.set(con, forKey: khoaCon)
    }

    /// Gọi khi trả lời SAI. Trả về `false` nếu vừa hết tim.
    @discardableResult
    func matMot() -> Bool {
        // Kiểm lại ngày trước khi trừ: app mở qua nửa đêm thì `con` trong bộ
        // nhớ vẫn là của hôm qua, và người dùng mất tim cho một ngày mới.
        nap()
        guard con > 0 else { return false }
        con -= 1
        ghi()
        return con > 0
    }

    func hoiDay() { con = toiDa; ghi() }
}

// MARK: - Ăn mừng

/// Lớp phủ khi xong một chặng nhỏ. Tự tắt sau 1,6 giây.
///
/// ⚠️ Tự tắt, KHÔNG bắt bấm "OK". Một hộp thoại chặn đường sau mỗi bài là
/// thứ dễ chịu ở lần thứ nhất và phiền ở lần thứ mười.
struct AnMungXongView: View {
    let xp: Int
    let chuoiNgay: Int
    @Binding var hien: Bool

    @State private var nhay = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Text("🎉").font(.system(size: 64))
                    .scaleEffect(nhay ? 1.15 : 0.7)
                Text(T("Xong rồi!")).font(.titleMedium).foregroundStyle(.white)
                Text("+\(xp) XP")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.success)
                if chuoiNgay > 0 {
                    Text("🔥 \(chuoiNgay) \(T("ngày liền"))")
                        .font(.bodyMedium).foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(Spacing.xl)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard))
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { nhay = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                withAnimation { hien = false }
            }
        }
    }
}

// MARK: - Nhắc giữ chuỗi

enum NhacChuoiIelts {
    private static let ma = "ielts-giu-chuoi"

    /// Nhắc 20h30 nếu hôm nay CHƯA học. Gọi lại mỗi lần tiến độ đổi.
    ///
    /// ⚠️ Huỷ lời nhắc cũ trước khi đặt cái mới. Không huỷ thì mỗi lần mở
    /// app lại thêm một lời nhắc trùng giờ, và tối đến máy rung năm lần —
    /// đủ để người dùng tắt hẳn thông báo của app.
    static func datLai(daHocHomNay: Bool, chuoiNgay: Int) {
        let tt = UNUserNotificationCenter.current()
        tt.removePendingNotificationRequests(withIdentifiers: [ma])
        guard !daHocHomNay else { return }

        let nd = UNMutableNotificationContent()
        nd.title = chuoiNgay > 0 ? "🔥 Đừng để đứt chuỗi \(chuoiNgay) ngày" : "Học tiếng Anh 5 phút?"
        nd.body = chuoiNgay > 0
            ? "Một bài ngắn thôi là giữ được chuỗi hôm nay."
            : "Bắt đầu chuỗi ngày đầu tiên — chỉ một bài là xong."
        nd.sound = .default

        var gio = DateComponents()
        gio.hour = 20; gio.minute = 30
        let khi = UNCalendarNotificationTrigger(dateMatching: gio, repeats: false)
        tt.add(UNNotificationRequest(identifier: ma, content: nd, trigger: khi))
    }
}


// MARK: - Mở thẳng đúng mục

/// Đọc `vm.moMuc` (dạng `"units#3"`) rồi mở đúng mục thứ N trong danh sách.
///
/// ⚠️ XOÁ `moMuc` NGAY khi đọc. Để lại thì lần sau người dùng tự mở danh
/// sách bằng tay, nó cũng nhảy vào bài cũ — và họ không hiểu vì sao app cứ
/// lôi mình về chỗ đó.
///
/// ⚠️ Chỉ số đếm từ 1 và tính TRÊN TOÀN DANH SÁCH đã phẳng hoá, khớp đúng
/// cách `DungConDuong` đánh số. Lệch một nấc ở đây là nút "Bài học 3" mở ra
/// bài 2 — sai âm thầm, và người dùng sẽ tưởng mình nhớ nhầm.
struct MoThangMuc<T>: ViewModifier {
    @ObservedObject var vm: IeltsVM
    let kind: String
    let danhSach: [T]
    let moRa: (T) -> Void

    func body(content: Content) -> some View {
        content.task(id: vm.moMuc) {
            guard let m = vm.moMuc, m.hasPrefix(kind + "-"),
                  let thu = Int(m.dropFirst(kind.count + 1)), thu >= 1 else { return }
            vm.moMuc = nil
            // Danh sách chưa nạp xong thì thôi — `.task(id:)` sẽ chạy lại khi
            // `moMuc` đổi, còn ép mở lúc mảng rỗng chỉ ra màn trắng.
            guard danhSach.count >= thu else { return }
            moRa(danhSach[thu - 1])
        }
    }
}

extension View {
    func moThangMuc<T>(_ vm: IeltsVM, kind: String, danhSach: [T],
                       moRa: @escaping (T) -> Void) -> some View {
        modifier(MoThangMuc(vm: vm, kind: kind, danhSach: danhSach, moRa: moRa))
    }
}
