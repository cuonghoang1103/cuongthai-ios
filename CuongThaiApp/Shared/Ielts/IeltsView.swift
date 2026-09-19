import SwiftUI

/// Màn IELTS — lộ trình 4 chặng và lối vào từng kỹ năng.
///
/// Trật tự trên màn: **bạn đang ở đâu → việc quan trọng nhất chặng này → vào
/// học**. Một trang khoá học mở ra bằng danh sách bài là trang bắt người học
/// tự đoán nên bắt đầu từ đâu, và phần lớn sẽ bấm bừa vào bài đầu tiên.
struct IeltsView: View {
    var coNutDong = false

    @StateObject private var vm = IeltsVM()
    @Environment(\.dismiss) private var dong
    @State private var moChiTietChang = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    if vm.loTrinh == nil && vm.dangTai {
                        ProgressView().padding(.top, Spacing.xxl)
                    } else if vm.loTrinh?.daSeed == false {
                        KhungTrongTien(bieuTuong: "tray", tieuDe: T("Chưa có nội dung IELTS"),
                                       moTa: T("Máy chủ chưa nạp khoá học. Thử lại sau ít phút."))
                    } else {
                        chonChang
                        if let b = vm.bandCuaChang { theBand(b) }
                        luoiPhan
                        nutPhongThi
                        if let b = vm.bandCuaChang { theKyNang(b) }
                    }
                }
                .padding(Spacing.md)
                .padding(.bottom, 80)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("IELTS")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if coNutDong {
                    ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
                }
            }
            .refreshable { await vm.napLoTrinh() }
            .task {
                guard !vm.daNapLanDau else { return }
                await vm.napLoTrinh()
            }
            .sheet(isPresented: $moChiTietChang) {
                if let b = vm.bandCuaChang { ChiTietChangView(band: b) }
            }
            .alert(T("Lỗi"), isPresented: Binding(get: { vm.loi != nil }, set: { if !$0 { vm.loi = nil } })) {
                Button(T("Đóng"), role: .cancel) { vm.loi = nil }
            } message: { Text(vm.loi ?? "") }
        }
    }

    // MARK: - Chọn chặng

    private var chonChang: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(vm.loTrinh?.chang ?? []) { c in
                    Button {
                        withAnimation(AppAnimations.quick) { vm.changDangXem = c.id }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(T("Chặng")) \(c.so)")
                                .font(.captionBold)
                            Text("\(c.tiLe)%")
                                .font(.caption2)
                                .opacity(0.85)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(vm.changDangXem == c.id ? AppColors.primary : AppColors.backgroundCard)
                        .foregroundStyle(vm.changDangXem == c.id ? Color.white : AppColors.textPrimary)
                        .cornerRadius(CornerRadius.full)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Thẻ band

    private func theBand(_ b: ChangBand) -> some View {
        Button { moChiTietChang = true } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Text(b.icon).font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.band).font(.captionBold).foregroundStyle(AppColors.primary)
                        Text(b.title).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColors.textTertiary)
                }

                if let c = vm.changHienTai {
                    ThanhTienDoTien(tiLe: Double(c.tiLe) / 100, mau: AppColors.success, cao: 6)
                    Text("\(c.tongXong)/\(c.tongMuc) \(T("mục")) · \(b.duration)")
                        .font(.caption2).foregroundStyle(AppColors.textTertiary)
                }

                // `keyFocus` là dòng đáng tiền nhất của cả chặng — nó nói
                // ĐỪNG làm gì, mà "đừng làm gì" mới là thứ tiết kiệm hàng
                // tháng cho người tự học.
                Text(b.keyFocus)
                    .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                    .lineLimit(3).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(AppColors.backgroundCard)
            .cornerRadius(CornerRadius.large)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lưới các phần

    private var luoiPhan: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: Spacing.sm)], spacing: Spacing.sm) {
            ForEach(vm.changHienTai?.phanTheoThuTu ?? [], id: \.kind) { p in
                NavigationLink { manPhan(p.kind) } label: { oPhan(p) }
                    .buttonStyle(.plain)
                    .disabled(p.soMuc == 0)
                    .opacity(p.soMuc == 0 ? 0.45 : 1)
            }
        }
    }

    private func oPhan(_ p: PhanChang) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: p.bieuTuong)
                    .font(.titleMedium)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.primary.opacity(0.14))
                    .cornerRadius(CornerRadius.small)
                VStack(alignment: .leading, spacing: 1) {
                    Text(T(p.ten)).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                    Text("\(p.daXong)/\(p.soMuc)").font(.caption2).foregroundStyle(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
            ThanhTienDoTien(tiLe: p.tiLe, mau: p.tiLe >= 1 ? AppColors.success : AppColors.primary, cao: 4)
        }
        .padding(Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.medium)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func manPhan(_ kind: String) -> some View {
        switch kind {
        case "readings": DanhSachDocView(vm: vm)
        case "listenings": DanhSachNgheView(vm: vm)
        case "writings": DanhSachVietView(vm: vm)
        case "speakings": DanhSachNoiView(vm: vm)
        case "vocab": TuVungIeltsView(vm: vm)
        case "units": BaiHocIeltsView(vm: vm)
        default:
            KhungTrongTien(bieuTuong: "hammer", tieuDe: T("Phần này đang làm"),
                           moTa: T("Đọc, Nghe, Viết, Nói, Từ vựng và Bài học đã dùng được."))
        }
    }

    // MARK: - Phòng thi

    private var nutPhongThi: some View {
        NavigationLink { PhongThiIeltsView(vm: vm) } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "timer")
                    .font(.titleMedium).foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(AppColors.error)
                    .cornerRadius(CornerRadius.small)
                VStack(alignment: .leading, spacing: 1) {
                    Text(T("Phòng thi")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                    Text(T("Ba phần, đồng hồ chạy thật, có band ước lượng"))
                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundCard)
            .cornerRadius(CornerRadius.large)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Kỹ năng của chặng

    private func theKyNang(_ b: ChangBand) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Mỗi ngày làm gì")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            ForEach(b.skills, id: \.skill) { s in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(s.icon)
                        Text(s.skill).font(.captionBold).foregroundStyle(AppColors.primary)
                    }
                    Text(s.daily).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("🎯 \(s.target)").font(.caption2).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("⚠️ \(s.trap)").font(.caption2).foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 3)
                if s.skill != b.skills.last?.skill { Divider() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }
}

// MARK: - Chi tiết một chặng

struct ChiTietChangView: View {
    let band: ChangBand
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    khoi(T("Bạn đang ở đâu"), band.youAre, "location.fill", AppColors.secondary)
                    khoi(T("Việc quan trọng nhất"), band.keyFocus, "star.fill", AppColors.warning)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Label(T("Qua chặng khi nào"), systemImage: "checkmark.seal.fill")
                            .font(.titleSmall).foregroundStyle(AppColors.success)
                        ForEach(band.checkpoints, id: \.self) { c in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle").font(.caption2)
                                    .foregroundStyle(AppColors.textTertiary).padding(.top, 4)
                                Text(c).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(CornerRadius.large)
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("\(band.icon) \(band.band)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } } }
        }
    }

    private func khoi(_ ten: String, _ than: String, _ bt: String, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(ten, systemImage: bt).font(.titleSmall).foregroundStyle(mau)
            Text(than).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }
}
