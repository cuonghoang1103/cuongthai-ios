import SwiftUI

// MARK: - Đăng ký mô-đun Assets & licenses — `/work/<ws>/<KEY>/assets[/<n>]`
// Ẩn với khách cổng (máy chủ trả 404 cho người bị giới hạn phạm vi khách).

extension CTWModule {
    static let assets = CTWModule(
        id: "assets", ten: "Assets & licenses", bieuTuong: "archivebox", nhom: .taiLieu,
        moTa: "Software, fonts and media with license expiry", thuTu: 40, doanWeb: "assets",
        hien: { cfg in cfg?.role != "CLIENT" },
        man: { c in AnyView(ManAssetsCTW(nguCanh: c)) },
        dichDen: { v in
            AnyView(v.navigationDestination(for: RouteTaiSanCTW.self) { r in TaiSanChiTietCTW(r: r) })
        })
}

/// Bọc để nhận deep link `/assets/<n>` (mở thẳng chi tiết).
private struct ManAssetsCTW: View {
    let nguCanh: CTWNguCanh
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var nganXep: NganXepCTW
    var body: some View {
        AssetsCTW(nguCanh: nguCanh)
            .task(id: app.dichCho) {
                guard let d = app.dichCho, d.moDun == "assets" else { return }
                defer { app.dichCho = nil }
                if let so = d.duongDan.phanCon.first.flatMap(Int.init) {
                    nganXep.duong.append(RouteTaiSanCTW(pid: nguCanh.pid, so: so, ten: String(localized: "Asset")))
                }
            }
    }
}
