import SwiftUI

/// Màn của MỘT tính năng, dạng NỘI DUNG (không tự mang `NavigationStack`).
///
/// Mọi nơi mở tính năng kiểu `.day` đi qua đây: lưới Đi nhanh của Hôm nay,
/// "Tất cả tính năng", cột chi tiết iPad, cửa sổ phụ. Nơi gọi lo cái stack:
///   · đẩy vào stack có sẵn ⇒ dùng thẳng;
///   · đứng một mình (cột chi tiết, cửa sổ phụ) ⇒ bọc `NavigationStack { … }`.
/// Hai stack lồng nhau là lỗi (b) của đợt rút gọn — đừng thêm stack bên trong.
///
/// `switch` @ViewBuilder nên chỉ màn được chọn mới được khởi tạo.
struct ManTinhNang: View {
    let tinhNang: TinhNang
    /// Hôm nay truyền VM của chính nó ⇒ Thời khoá biểu dùng lại lịch đã tải.
    /// `nil` ⇒ màn tự tạo và tự nạp.
    var vmTongQuan: TongQuanVM? = nil

    @ViewBuilder
    var body: some View {
        switch tinhNang {
        case .hocKy: HuanLuyenHocKyView()
        case .thoiKhoaBieu:
            if let vmTongQuan { LichTuanView(vm: vmTongQuan) } else { LichTuanDocLap() }
        case .academy: AcademyView()
        case .chuongTrinh: ChuongTrinhView()
        case .khoaHocCuaToi: MyCoursesView()
        case .ielts: IeltsView(coNganXepRieng: false)
        case .ngoaiNgu: NgonNguView()
        case .videoHoc: VideoHocView()
        case .thuVienSach: ThuVienSachView()
        case .phongThi: PhongThiView()
        case .codeLab: CodeLabView()
        case .thuatToan: ThuatToanView()
        case .moPhong: MoPhongView()
        case .snippets: SnippetsView()
        case .loTrinh: LoTrinhNgheView()
        case .duAn: DuAnView()
        case .phongVan: PhongVanView()
        case .cvBuilder: CVView()
        case .vo:
            #if os(iOS)
            NoiDungVoView()
            #else
            EmptyView()
            #endif
        case .tienNong: TienView(coNganXepRieng: false)
        case .xuongVe: XuongVeView(coNganXepRieng: false)
        case .xuongBa: XuongBaView(coNganXepRieng: false)
        // Ba loại dưới KHÔNG đi đường đẩy (`cachMo != .day`) — `AppState.moTinhNang`
        // trình bày chúng từ gốc. Nếu lỡ tới đây (vd. giá trị cửa sổ phụ cũ) thì
        // hiện một lối mở thay vì màn trắng câm.
        case .aiChat, .notes, .thongBao, .caiDat, .ctWork:
            MoTuGoc(tinhNang: tinhNang)
        }
    }
}

/// Thời khoá biểu mở NGOÀI Hôm nay (Tất cả tính năng, iPad, cửa sổ phụ): tự
/// giữ một `TongQuanVM` và tự nạp lịch.
private struct LichTuanDocLap: View {
    @StateObject private var vm = TongQuanVM()
    var body: some View {
        LichTuanView(vm: vm)
            .task {
                guard vm.buoiHoc.isEmpty else { return }
                await vm.napLich()
            }
    }
}

/// Lối mở cho tính năng trình bày từ gốc khi nó lỡ rơi vào chỗ của màn đẩy.
private struct MoTuGoc: View {
    let tinhNang: TinhNang
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: tinhNang.bieuTuong)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(tinhNang.mau)
            Text(tinhNang.ten).font(.titleMedium).foregroundColor(AppColors.textPrimary)
            Button(T("Mở")) { appState.moTinhNang(tinhNang) }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary)
    }
}
