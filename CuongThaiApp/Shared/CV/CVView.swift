import SwiftUI

struct CVView: View {
    @StateObject private var may = MayCV()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                if may.dangTai && may.hoSo == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let e = may.loi, may.hoSo == nil {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.badge.gearshape").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(e).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let h = may.hoSo {
                    khoiDoDay
                    NavigationLink { CVHoSoView(may: may) } label: { the(h) }
                        .buttonStyle(.plain)
                    loi(T("Kinh nghiệm & dự án"), "briefcase.fill", Color(hex: 0x3B82F6),
                        "\(h.muc("EXPERIENCE").count + h.muc("PROJECT").count) \(T("mục")) · \(h.cacMuc.reduce(0) { $0 + $1.cacGach.count }) \(T("dòng thành tích"))") {
                        CVMucView(may: may, loai: ["EXPERIENCE", "PROJECT", "OPEN_SOURCE"],
                                  ten: T("Kinh nghiệm & dự án"))
                    }
                    loi(T("Học vấn & chứng chỉ"), "graduationcap.fill", Color(hex: 0x22C55E),
                        "\(h.muc("EDUCATION").count) \(T("mục")) · \(h.cacChungChi.count) \(T("chứng chỉ"))") {
                        CVMucView(may: may, loai: ["EDUCATION", "AWARD", "PUBLICATION", "VOLUNTEER"],
                                  ten: T("Học vấn & chứng chỉ"))
                    }
                    loi(T("Kỹ năng & ngôn ngữ"), "list.bullet.rectangle", Color(hex: 0xA855F7),
                        "\(h.cacKyNang.count) \(T("kỹ năng")) · \(h.cacNgonNgu.count) \(T("ngôn ngữ"))") {
                        CVKyNangView(may: may)
                    }
                    loi(T("Soi lỗi CV"), "checkmark.seal.fill", Color(hex: 0x06B6D4),
                        T("Chấm bằng luật, không tốn lượt AI")) { CVSoiLoiView(may: may) }
                    loi(T("Chấm CV bằng AI"), "sparkles", Color(hex: 0xEC4899),
                        may.congCham?.bat == true ? T("Nhận xét sâu, chỉ rõ chỗ phải sửa")
                                                  : (may.congCham?.reason ?? T("Cần tài khoản Pro"))) {
                        CVChamView(may: may)
                    }
                    loi(T("Tin tuyển dụng"), "target", Color(hex: 0xF59E0B),
                        "\(may.viecLam.count) \(T("tin")) · \(T("đo độ phủ, thư xin việc"))") {
                        CVViecLamView(may: may)
                    }
                    loi(T("Tài liệu CV"), "doc.richtext.fill", Color(hex: 0x0EA5E9),
                        "\(may.taiLieu.count) \(T("bản")) · \(may.mau.count) \(T("mẫu"))") {
                        CVTaiLieuView(may: may)
                    }
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("CV Builder")
        .navigationBarTitleDisplayMode(.inline)
        .task { if may.hoSo == nil { await may.nap() } }
    }

    // MARK: Độ đầy

    @ViewBuilder private var khoiDoDay: some View {
        if let d = may.doDay {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(T("Độ hoàn thiện").uppercased())
                        .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(d.percent ?? 0)%")
                        .font(.system(size: 20, weight: .heavy).monospacedDigit())
                        .foregroundColor(diemMau(Double(d.percent ?? 0)))
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.backgroundTertiary)
                        Capsule().fill(diemMau(Double(d.percent ?? 0)))
                            .frame(width: g.size.width * Double(d.percent ?? 0) / 100)
                    }
                }
                .frame(height: 6)
                // Danh sách việc còn thiếu — cụ thể hơn hẳn một con số phần trăm.
                ForEach(d.cacMuc) { m in
                    HStack(spacing: 6) {
                        Image(systemName: m.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundColor(m.done ? Color(hex: 0x22C55E) : AppColors.textTertiary)
                        Text(m.label)
                            .font(.system(size: 12.5))
                            .foregroundColor(m.done ? AppColors.textTertiary : AppColors.textPrimary)
                            .strikethrough(m.done, color: AppColors.textTertiary)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    private func the(_ h: HoSoCV) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22)).foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x6366F1), Color(hex: 0x818CF8)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 2) {
                Text(h.fullName?.isEmpty == false ? h.fullName! : T("Chưa đặt tên"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary).lineLimit(1)
                Text(h.headline?.isEmpty == false ? h.headline! : T("Chạm để điền thông tin cá nhân"))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    @ViewBuilder
    private func loi<D: View>(_ ten: String, _ hinh: String, _ mau: Color, _ phu: String,
                              @ViewBuilder _ dich: @escaping () -> D) -> some View {
        NavigationLink(destination: dich()) {
            HStack(spacing: Spacing.md) {
                Image(systemName: hinh)
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(mau)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(mau.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ten).font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(phu).font(.system(size: 11.5))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lối vào

struct CVEntryCard: View {
    var body: some View {
        NavigationLink { CVView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20)).foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x4338CA), Color(hex: 0x6366F1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("CV Builder").font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(T("Soạn CV · soi lỗi · chấm AI · thư xin việc"))
                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }
}
