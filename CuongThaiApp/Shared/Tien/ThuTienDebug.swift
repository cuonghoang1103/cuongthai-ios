#if DEBUG
import SwiftUI

/// Bàn soi màn Tiền nong — CHỈ bản DEBUG, mở qua `CT_XEM_MAN` (xem `ManXemThu`).
///
///     SIMCTL_CHILD_CT_API=http://localhost:5099 \
///     SIMCTL_CHILD_CT_TOKEN_THU=<jwt của máy chủ thử> \
///     SIMCTL_CHILD_CT_XEM_MAN=tien-no xcrun simctl launch <udid> com.cuongthai.app
///
/// Chế độ: `tien` · `tien-no` · `tien-phantich` · `tien-chienluoc` ·
/// `tien-chitiet` (+ `CT_NO_ID`) · `tien-tattoan` (+ `CT_NO_ID`) · `tien-covan`.
///
/// ⛔ `CT_TOKEN_THU` GHI ĐÈ phiên trong Keychain của máy ảo. Chỉ dùng trên một
/// máy ảo TẠO RIÊNG để thử — máy ảo người dùng đã đăng nhập mà chạy cái này
/// là mất phiên thật của họ (Keychain sống qua cả gỡ app, xem CLAUDE.md C13).
struct ThuTienView: View {
    let cheDo: String
    @StateObject private var vm = TienVM()

    init(cheDo: String) {
        self.cheDo = cheDo
        let env = ProcessInfo.processInfo.environment
        if let t = env["CT_TOKEN_THU"], !t.isEmpty,
           (env["CT_API"] ?? "").contains("localhost") {
            StorageManager.shared.saveAuthToken(t)
            // Máy ảo thử không có ai bấm màn đồng ý AI — bật sẵn để soi màn AI.
            UserDefaults.standard.set(true, forKey: DongYChiaSeAI.khoa)
        }
    }

    private var noId: Int { Int(ProcessInfo.processInfo.environment["CT_NO_ID"] ?? "") ?? 1 }

    var body: some View {
        Group {
            switch cheDo {
            case "tien": TienView()
            case "tien-no": NoView(vm: vm)
            case "tien-phantich": PhanTichView(vm: vm)
            case "tien-chienluoc": ChienLuocNoView(vm: vm)
            case "tien-chitiet": ChiTietNoView(vm: vm, noId: noId)
            case "tien-tattoan": TatToanSomView(vm: vm, noId: noId, tenNo: "Khoản #\(noId)") {}
            case "tien-covan": CoVanAIView(vm: vm)
            default: Text("Không có chế độ \(cheDo)")
            }
        }
        .task {
            if cheDo != "tien" { await vm.napTatCa() }
        }
    }
}
#endif
