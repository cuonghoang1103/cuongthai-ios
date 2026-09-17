#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - Màn gốc: các MÔN

/// Bản có `NavigationStack` riêng — dùng khi Vở là một mục của thanh bên
/// (iPad) hay của thanh tab.
struct VoView: View {
    var body: some View {
        NavigationStack { NoiDungVoView() }
    }
}

/// Bản KHÔNG mang stack — dùng khi Vở được ĐẨY vào một stack sẵn có (iPhone
/// mở từ toolbar Tổng quan). Lồng hai `NavigationStack` thì màn con có hai
/// thanh tiêu đề chồng nhau và nút quay lại về sai chỗ.
struct NoiDungVoView: View {
    @Environment(\.modelContext) private var kho
    @Environment(\.horizontalSizeClass) private var beRong
    // ⚠️ KHÔNG sắp theo `ghim` trong `@Query`: `SortDescriptor` không nhận
    // `order:` cho `Bool`, và lỗi báo ra là "no exact matches in call to
    // initializer" — đọc xong không ai nghĩ tới kiểu của trường. Ghim được
    // đẩy lên đầu ở `monsXepTheoGhim` bên dưới.
    @Query(sort: [SortDescriptor(\MonVo.thuTu)])
    private var mons: [MonVo]

    private var monsXepTheoGhim: [MonVo] {
        mons.sorted { a, b in
            if a.ghim != b.ghim { return a.ghim }
            return a.thuTu < b.thuTu
        }
    }

    /// ⚠️ MỘT cửa sổ, chọn bằng enum — KHÔNG dùng hai `.sheet(isPresented:)`
    /// trên cùng một view. Cái khai sau nuốt cái khai trước và cửa sổ kia
    /// không bao giờ mở ra, không lỗi nào để thấy. Đã dính đúng bẫy này ở đợt
    /// vá App Store 19/08/2026.
    @State private var cuaSo: CuaSoVo?

    private enum CuaSoVo: Identifiable {
        case taoMon
        case suaMon(MonVo)

        var id: String {
            switch self {
            case .taoMon: return "tao"
            case .suaMon(let m): return "sua-" + m.id.uuidString
            }
        }
    }

    private var soCot: Int { beRong == .regular ? 3 : 2 }

    /// Hai mục của Vở. Luyện viết nằm TRONG Vở chứ không phải một tab riêng
    /// ở thanh bên: nó cũng là viết tay bằng Pencil, cùng một thói quen và
    /// cùng một cây dữ liệu cục bộ — tách ra thành hai chỗ thì người dùng
    /// phải nhớ "viết chữ Hán thì vào đâu".
    private enum Muc: String, CaseIterable, Identifiable {
        case vo, luyenViet
        var id: String { rawValue }
        var ten: String { self == .vo ? T("Vở của tôi") : T("Luyện viết") }
    }
    @State private var muc: Muc = .vo

    var body: some View {
        Group {
                if muc == .luyenViet {
                    LuyenVietHubView()
                } else if mons.isEmpty {
                    ManTrong()
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md),
                                           count: soCot),
                            spacing: Spacing.md
                        ) {
                            ForEach(monsXepTheoGhim) { mon in
                                NavigationLink(value: mon) {
                                    TheMon(mon: mon)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { cuaSo = .suaMon(mon) } label: {
                                        Label(T("Sửa"), systemImage: "pencil")
                                    }
                                    Button { mon.ghim.toggle(); mon.suaLuc = Date() } label: {
                                        Label(mon.ghim ? T("Bỏ ghim") : T("Ghim"),
                                              systemImage: mon.ghim ? "pin.slash" : "pin")
                                    }
                                    Button(role: .destructive) { xoaMon(mon) } label: {
                                        Label(T("Xoá môn"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .background(AppColors.backgroundPrimary)
            .safeAreaInset(edge: .top) {
                Picker("", selection: $muc) {
                    ForEach(Muc.allCases) { Text($0.ten).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
                .background(AppColors.backgroundPrimary)
            }
            .navigationTitle(muc.ten)
            .navigationDestination(for: MonVo.self) { MonVoView(mon: $0) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Spacing.md) {
                        HuyHieuDongBo()
                        if muc == .vo {
                            Button { cuaSo = .taoMon } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel(T("Thêm môn"))
                        }
                    }
                }
            }
            .task {
                DongBoVo.shared.gan(kho: kho)
                // Kéo về TRƯỚC ở lần mở màn: máy vừa cài lại, hoặc máy thứ
                // hai, phải thấy vở của mình chứ không phải màn hình trống.
                //
                // ⚠️ `batDau` (không `await`) chứ KHÔNG phải `await dongBo()`:
                // task của `.task` chết theo view, và lượt đẩy đang dở sẽ bị
                // huỷ ngay khi người dùng mở một cuốn vở.
                DongBoVo.shared.batDau(keoVeTruoc: true)
            }
            .refreshable { await DongBoVo.shared.dongBo(keoVeTruoc: true) }
            .sheet(item: $cuaSo) { cua in
                switch cua {
                case .taoMon:
                    SuaMonView(mon: nil) { ten, emoji, mau in
                        let m = MonVo(ten: ten, emoji: emoji, mauHex: mau,
                                      thuTu: (mons.map(\.thuTu).max() ?? 0) + 1)
                        kho.insert(m)
                    }
                case .suaMon(let mon):
                    SuaMonView(mon: mon) { ten, emoji, mau in
                        mon.ten = ten; mon.emoji = emoji; mon.mauHex = mau
                        mon.suaLuc = Date()
                    }
                }
            }
    }

    private func xoaMon(_ mon: MonVo) {
        // Xoá cây trước, rồi mới dọn tệp: ngược lại thì tệp mất mà bản ghi
        // còn, và mở vở ra thấy trang trắng không hiểu vì sao.
        let cuons = mon.cuonsTheoThuTu
        let idTrang = cuons.flatMap { $0.trangsTheoThuTu.map(\.id) }
        // Báo cho MÁY CHỦ biết, qua hàng đợi bền. Thiếu bước này thì lượt
        // kéo về kế tiếp mang cả môn vừa xoá quay lại.
        for cuon in cuons {
            DongBoVo.ghiNhanXoa(kho: kho, maDoiTuong: cuon.id.uuidString, loai: "cuon")
        }
        kho.delete(mon)
        try? kho.save()
        for id in idTrang { KhoVo.xoa(id) }
        DongBoVo.shared.batDau()
    }

    private struct ManTrong: View {
        var body: some View {
            VStack(spacing: Spacing.md) {
                Image(systemName: "book.closed")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.textTertiary)
                Text(T("Chưa có môn nào"))
                    .font(Font.titleMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(T("Tạo môn đầu tiên — Toán, Tiếng Nhật, Lập trình… — rồi lập vở bên trong."))
                    .font(Font.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: Thẻ môn

private struct TheMon: View {
    let mon: MonVo

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(mon.emoji).font(.system(size: 30))
                Spacer()
                if mon.ghim {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.onPrimary.opacity(0.9))
                }
            }
            Spacer(minLength: Spacing.lg)
            Text(mon.ten)
                .font(Font.titleSmall)
                .foregroundStyle(AppColors.onPrimary)
                .lineLimit(2)
            Text(soCuon)
                .font(Font.bodyMedium)
                .foregroundStyle(AppColors.onPrimary.opacity(0.8))
        }
        .padding(Spacing.md)
        .frame(height: 150, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: UInt32(mon.mauHex)),
                                    Color(hex: UInt32(mon.mauHex)).opacity(0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
    }

    private var soCuon: String {
        let n = (mon.cuons ?? []).count
        return n == 0 ? T("Chưa có vở") : "\(n) " + T("cuốn")
    }
}

// MARK: - Trong một môn: các CUỐN VỞ

struct MonVoView: View {
    @Bindable var mon: MonVo
    @Environment(\.modelContext) private var kho
    @Environment(\.horizontalSizeClass) private var beRong

    @State private var dangTaoCuon = false
    @State private var cuonDangMo: CuonVo?
    /// Cuốn vừa lập, chờ cửa sổ tạo ĐÓNG HẲN rồi mới mở ra.
    ///
    /// ⚠️ Đặt `cuonDangMo` ngay trong closure của sheet thì màn viết KHÔNG
    /// mở: SwiftUI đang chạy hiệu ứng đóng sheet, và một modal thứ hai yêu
    /// cầu giữa chừng bị nuốt im lặng. Phải đợi `onDismiss`.
    @State private var cuonVuaLap: CuonVo?

    private var soCot: Int { beRong == .regular ? 4 : 2 }

    var body: some View {
        ScrollView {
            if mon.cuonsTheoThuTu.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "book")
                        .font(.system(size: 44))
                        .foregroundStyle(AppColors.textTertiary)
                    Text(T("Môn này chưa có cuốn vở nào"))
                        .font(Font.bodyLarge)
                        .foregroundStyle(AppColors.textSecondary)
                    Button(T("Lập cuốn vở đầu tiên")) { dangTaoCuon = true }
                        .primaryButtonStyle()
                        .frame(maxWidth: 280)
                }
                .padding(.top, 80)
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md),
                                   count: soCot),
                    spacing: Spacing.lg
                ) {
                    ForEach(mon.cuonsTheoThuTu) { cuon in
                        Button { cuonDangMo = cuon } label: { BiaVo(cuon: cuon) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { cuon.ghim.toggle() } label: {
                                    Label(cuon.ghim ? T("Bỏ ghim") : T("Ghim"),
                                          systemImage: cuon.ghim ? "pin.slash" : "pin")
                                }
                                Button(role: .destructive) { xoaCuon(cuon) } label: {
                                    Label(T("Xoá cuốn vở"), systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(Spacing.md)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(mon.emoji + " " + mon.ten)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { dangTaoCuon = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(T("Lập cuốn vở"))
            }
        }
        .sheet(isPresented: $dangTaoCuon, onDismiss: {
            if let c = cuonVuaLap { cuonVuaLap = nil; cuonDangMo = c }
        }) {
            LapCuonVoView(mauGoiY: mon.mauHex) { ten, mau, giay, huong in
                let c = CuonVo(ten: ten, mon: mon, mauBiaHex: mau, giay: giay,
                               huong: huong,
                               thuTu: (mon.cuonsTheoThuTu.map(\.thuTu).max() ?? 0) + 1)
                kho.insert(c)
                // Vở mới phải có sẵn một trang: mở ra thấy "0 trang" rồi phải
                // đi tìm nút thêm trang là một bước thừa ngay ở lần dùng đầu.
                let t = TrangVo(cuon: c, thuTu: 0, giay: giay, huong: huong)
                kho.insert(t)
                try? kho.save()
                cuonVuaLap = c
            }
        }
        .fullScreenCover(item: $cuonDangMo) { cuon in
            ManVietView(cuon: cuon)
        }
    }

    private func xoaCuon(_ cuon: CuonVo) {
        let idTrang = cuon.trangsTheoThuTu.map(\.id)
        DongBoVo.ghiNhanXoa(kho: kho, maDoiTuong: cuon.id.uuidString, loai: "cuon")
        kho.delete(cuon)
        try? kho.save()
        for id in idTrang { KhoVo.xoa(id) }
        DongBoVo.shared.batDau()
    }
}

// MARK: Bìa vở

private struct BiaVo: View {
    let cuon: CuonVo

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: UInt32(cuon.mauBiaHex)),
                                 Color(hex: UInt32(cuon.mauBiaHex)).opacity(0.65)],
                        startPoint: .top, endPoint: .bottom))
                // Gáy vở — dải tối bên trái, thứ khiến hình chữ nhật màu đọc
                // ra là "cuốn vở" chứ không phải một ô màu.
                Rectangle()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: 12)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium,
                                                style: .continuous))
                if cuon.ghim {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

            Text(cuon.ten)
                .font(Font.bodyMedium.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
            Text("\(cuon.soTrang) " + T("trang"))
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
    }
}
#endif
