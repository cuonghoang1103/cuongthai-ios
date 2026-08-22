import SwiftUI

// MARK: - Bộ nạp

@MainActor
final class LuyenTapVM: ObservableObject {
    @Published var tongQuan: TongQuanLuyenTap?
    @Published var dangTai = false
    @Published var loi: String?

    var trangThai: TrangThaiChoi? { tongQuan?.state }
    var nhom: [NhomBai] { tongQuan?.units ?? [] }

    /// Bài mở khoá đầu tiên chưa đủ 5 vương miện — tức "học tiếp chỗ này".
    /// Mở khoá là TUYẾN TÍNH nên bài này luôn là duy nhất.
    var hocTiep: BaiLuyen? {
        nhom.lazy.flatMap(\.lessons).first { !$0.locked && $0.crown < 5 }
    }

    func tai(_ code: String) async {
        dangTai = true; defer { dangTai = false }
        do {
            tongQuan = try await APIClient.shared.request(.luyenTap(code: code))
            loi = nil
        } catch {
            loi = error.localizedDescription
        }
    }
}

// MARK: - Màn hình

struct LuyenTapView: View {
    let ngonNgu: NgonNgu
    @StateObject private var vm = LuyenTapVM()
    /// Các nhóm ĐANG GẬP. Gieo sẵn lúc nạp bằng những nhóm khoá hết, rồi chỉ
    /// người dùng mới đổi. Trước đó tôi suy trạng thái mở từ "tập rỗng hay
    /// không" — kết quả là vừa mở một nhóm thì mọi nhóm khác tự đóng lại.
    @State private var gap: Set<String> = []
    @State private var daGieo = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let tt = vm.trangThai {
                    theTrangThai(tt)
                    hangLienKet
                    if let b = vm.hocTiep { theHocTiep(b) }
                    danhSachNhom
                } else if vm.dangTai {
                    ProgressView().padding(.top, Spacing.xxl)
                } else {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "dumbbell").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(vm.loi ?? "Chưa có bài luyện tập nào.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xxl)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Luyện tập")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm.tongQuan == nil { await vm.tai(ngonNgu.code) }
            if !daGieo, !vm.nhom.isEmpty {
                gap = Set(vm.nhom.filter(\.khoaHet).map(\.key))
                daGieo = true
            }
        }
    }

    // MARK: Thẻ trạng thái

    private func theTrangThai(_ tt: TrangThaiChoi) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                oChiSo("flame.fill", "\(tt.streak)", "ngày", 0xE5484D)
                oChiSo("bolt.fill", "\(tt.xp)", "XP", 0xF59E0B)
                oChiSo("star.circle.fill", "\(tt.level)", "cấp", 0x8C5AF0)
                oTim(tt)
            }

            VStack(spacing: Spacing.xs) {
                HStack {
                    Text("Mục tiêu hôm nay")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(tt.dailyXp)/\(tt.dailyGoalXp) XP")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(tt.datMucTieu ? AppColors.success : AppColors.textPrimary)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.backgroundTertiary)
                        Capsule().fill(tt.datMucTieu ? AppColors.success : AppColors.primary)
                            .frame(width: g.size.width * tt.tiLeMucTieu)
                    }
                }
                .frame(height: 8)

                // Cấp XP là thang DÀI (cần 100·cấp XP để qua một cấp), nên
                // hiện luôn phần trăm chứ không bắt người ta tự đoán.
                HStack {
                    Text("Cấp \(tt.level)")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(tt.xpIntoLevel)/\(tt.xpForLevel) XP tới cấp \(tt.level + 1)")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.top, 2)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(AppColors.border, lineWidth: 1))
        )
    }

    private func oChiSo(_ icon: String, _ so: String, _ nhan: String, _ mau: UInt32) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(Color(hex: mau))
            Text(so)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(nhan)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func oTim(_ tt: TrangThaiChoi) -> some View {
        VStack(spacing: 3) {
            Image(systemName: tt.hearts > 0 ? "heart.fill" : "heart")
                .font(.system(size: 17))
                .foregroundColor(Color(hex: 0xE5484D))
            Text("\(tt.hearts)/\(tt.maxHearts)")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            // Hết tim thì nói RÕ bao giờ có lại, thay vì để người ta đoán.
            Text(tt.hearts >= tt.maxHearts ? "tim"
                 : "đầy sau \(tt.heartsFullInMin)′")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var hangLienKet: some View {
        HStack(spacing: Spacing.sm) {
            NavigationLink { BangXepHangView(ngonNgu: ngonNgu) } label: {
                nhanLienKet("Bảng xếp hạng", "trophy.fill", 0xF59E0B)
            }
            .buttonStyle(.plain)
            NavigationLink { ThanhTichView(ngonNgu: ngonNgu) } label: {
                nhanLienKet("Thành tích", "rosette", 0x8C5AF0)
            }
            .buttonStyle(.plain)
        }
    }

    private func nhanLienKet(_ ten: String, _ icon: String, _ mau: UInt32) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).foregroundColor(Color(hex: mau))
            Text(ten)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    // MARK: Học tiếp

    private func theHocTiep(_ b: BaiLuyen) -> some View {
        NavigationLink {
            ChoiBaiView(ngonNgu: ngonNgu, bai: b) {
                Task { await vm.tai(ngonNgu.code) }
            }
        } label: {
            HStack(spacing: Spacing.md) {
                Text(b.icon ?? "📘").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text("HỌC TIẾP")
                        .font(.system(size: 10, weight: .black))
                        .kerning(0.8)
                        .foregroundColor(AppColors.onPrimary.opacity(0.9))
                    Text(b.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.onPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    vuongMien(b.crown, sang: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppColors.onPrimary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(LinearGradient(colors: [Color(hex: 0x0E93A6), Color(hex: 0x21D4ED)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Danh sách nhóm

    private var danhSachNhom: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(vm.nhom) { n in
                // Nhóm khoá hết thì gập sẵn. Đo thật: phần lớn chủ đề chưa
                // được gán vào chặng nào nên dồn cả vào "Từ vựng khác" —
                // riêng tiếng Anh là hơn 300 bài, mở sẵn thì màn hình chỉ còn
                // là một dãy xám dài không bấm được.
                let mo = !gap.contains(n.key)
                VStack(spacing: Spacing.sm) {
                    Button {
                        if gap.contains(n.key) { gap.remove(n.key) } else { gap.insert(n.key) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.label)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary)
                                Text("\(n.soXong)/\(n.lessons.count) bài đã có vương miện")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Spacer()
                            Image(systemName: mo ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    if mo {
                        ForEach(n.lessons) { b in hangBai(b) }
                    }
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(AppColors.backgroundCard))
            }
        }
    }

    @ViewBuilder
    private func hangBai(_ b: BaiLuyen) -> some View {
        if b.locked {
            hinhHangBai(b)
                .opacity(0.45)
        } else {
            NavigationLink {
                ChoiBaiView(ngonNgu: ngonNgu, bai: b) {
                    Task { await vm.tai(ngonNgu.code) }
                }
            } label: {
                hinhHangBai(b)
            }
            .buttonStyle(.plain)
        }
    }

    private func hinhHangBai(_ b: BaiLuyen) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(b.icon ?? "📘").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text(b.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Spacing.sm) {
                    vuongMien(b.crown, sang: false)
                    Text("\(b.wordCount) từ")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                    if b.bestScore > 0 {
                        Text("cao nhất \(b.bestScore)%")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: b.locked ? "lock.fill" : (b.xong ? "checkmark.circle.fill" : "chevron.right"))
                .font(.system(size: b.locked || b.xong ? 14 : 12, weight: .semibold))
                .foregroundColor(b.xong ? AppColors.success : AppColors.textTertiary)
        }
        .padding(.vertical, Spacing.xs)
    }

    /// Năm vương miện, cái đã đạt thì tô vàng.
    private func vuongMien(_ so: Int, sang: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "crown.fill")
                    .font(.system(size: 9))
                    .foregroundColor(i < so ? Color(hex: 0xF59E0B)
                                     : (sang ? AppColors.onPrimary.opacity(0.35)
                                        : AppColors.textTertiary.opacity(0.3)))
            }
        }
    }
}
