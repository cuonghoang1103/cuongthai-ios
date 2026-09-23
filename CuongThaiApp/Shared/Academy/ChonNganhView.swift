import SwiftUI

// ════════════════════════════════════════════════════════════════
// CHỌN NGÀNH — bản iOS của `components/academy/AcademyOnboarding.tsx`
//
//   1. hỏi     — "Bạn có phải sinh viên FPT University không?"
//                Không → lưu {isStudent:false} rồi trả người dùng về khu khoá học tự do.
//   2. khối    — 5 khối ngành.
//   3. ngành   — ngành trong khối. Không có ngành hẹp → xong luôn.
//   4. ngành hẹp — kèm lối "Tôi chưa chọn — gợi ý giúp tôi" (Phòng tư vấn)
//                và "Để sau" (chỉ khối CNTT: có khung nền nên chưa chọn vẫn lọc được).
//   5. xong    — Sơ đồ môn học hoặc Vào học ngay.
//
// Đóng giữa chừng (vuốt xuống / nút ✕) KHÔNG lưu gì — lần sau còn hỏi lại.
// ════════════════════════════════════════════════════════════════

enum BuocChonNganh: Hashable { case hoi, khoi, nganh, nganhHep, xong }

struct ChonNganhView: View {
    let batDau: BuocChonNganh
    var khoiSan: String? = nil
    var nganhSan: String? = nil
    /// "Không, mình học tự do".
    var khiKhongPhaiSV: () -> Void = {}
    /// "Chưa chọn ngành hẹp — gợi ý giúp tôi".
    var khiCanTuVan: (_ khoi: String, _ nganh: String) -> Void = { _, _ in }
    var khiXemSoDo: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var hoSo = HoSoAcademy.shared
    @State private var buoc: BuocChonNganh = .hoi
    @State private var khoiId: String?
    @State private var nganhId: String?
    @State private var hepId: String?
    @State private var ghiNho = true
    @State private var daNap = false

    private let dm = DanhMucNganh.shared
    private var khoi: KhoiNganh? { dm.khoi(khoiId) }
    private var nganh: Nganh? { dm.nganh(khoiId, nganhId) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    dauTrang
                    noiDung
                        .id(buoc)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .opacity))
                    if buoc != .xong { oGhiNho }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(AppColors.backgroundPrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Đóng, hỏi lại lần sau")
                }
            }
        }
        .onAppear {
            guard !daNap else { return }
            daNap = true
            if let k = khoiSan, let n = nganhSan, dm.nganh(k, n) != nil {
                khoiId = k; nganhId = n; buoc = .nganhHep
            } else {
                buoc = batDau
            }
        }
    }

    // MARK: Đầu trang: robot + chỉ báo bước + câu hỏi

    private var tongBuoc: Int { nganhId != nil && (nganh?.combos.isEmpty ?? false) ? 3 : 4 }
    private var buocHienTai: Int {
        switch buoc {
        case .hoi: 1
        case .khoi: 2
        case .nganh: 3
        case .nganhHep: 4
        case .xong: tongBuoc
        }
    }

    private var tieuDe: String {
        switch buoc {
        case .hoi: "Bạn có phải sinh viên FPT University không?"
        case .khoi: "Bạn học khối ngành nào?"
        case .nganh: "Bạn học ngành nào?"
        case .nganhHep: "Chọn ngành hẹp (chuyên ngành)"
        case .xong: "Xong rồi!"
        }
    }

    private var dauTrang: some View {
        VStack(spacing: Spacing.sm) {
            RobotAcademy(camXuc: buoc == .xong ? .mung : buoc == .nganhHep ? .vui : .toMo,
                         nho: buoc == .khoi || buoc == .nganh || buoc == .nganhHep)
            HStack(spacing: 6) {
                ForEach(1...tongBuoc, id: \.self) { i in
                    Capsule()
                        .fill(i < buocHienTai ? AppColors.secondary : i == buocHienTai ? AppColors.primary : AppColors.border)
                        .frame(width: i == buocHienTai ? 30 : 22, height: 5)
                }
                Text("\(buocHienTai)/\(tongBuoc)")
                    .font(.caption).monospacedDigit()
                    .foregroundColor(AppColors.textTertiary)
            }
            .animation(.snappy, value: buoc)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bước \(buocHienTai) trên \(tongBuoc)")

            Text(tieuDe)
                .font(.titleLarge)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Từng bước

    @ViewBuilder private var noiDung: some View {
        switch buoc {
        case .hoi: buocHoi
        case .khoi: buocKhoi
        case .nganh: buocNganh
        case .nganhHep: buocNganhHep
        case .xong: buocXong
        }
    }

    private var buocHoi: some View {
        VStack(spacing: Spacing.sm) {
            loiDan("Trả lời để Academy hiện đúng môn của bạn. Không phải sinh viên FPTU thì mình đưa bạn sang khu khoá học tự do.")
            Button { chuyen(.khoi) } label: {
                Label("Đúng, mình là sinh viên FPTU", systemImage: "graduationcap.fill")
                    .font(.buttonText)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundColor(.white)
                    .background(AppColors.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            }
            .buttonStyle(.plain)
            Button {
                Haptics.cham()
                hoSo.luu(isStudent: false, faculty: nil, major: nil, combo: nil, ghiNho: ghiNho)
                dismiss()
                khiKhongPhaiSV()
            } label: {
                Text("Không, mình học tự do")
                    .font(.buttonText)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundColor(AppColors.textPrimary)
                    .background(AppColors.backgroundCard)
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var buocKhoi: some View {
        VStack(spacing: Spacing.sm) {
            loiDan("FPTU có nhiều khối ngành. Chọn khối của bạn để mình lọc đúng lộ trình:")
            ForEach(dm.khoi) { k in
                let soHep = k.majors.reduce(0) { $0 + $1.combos.count }
                oChon(icon: k.icon, ten: k.nameVi, phu: k.name,
                      nhan: (k.majors.count > 1 ? "\(k.majors.count) ngành · " : "") + "\(soHep) chuyên ngành hẹp",
                      nhanNoi: true) {
                    khoiId = k.id; nganhId = nil; hepId = nil
                    chuyen(.nganh)
                }
            }
            nutLui("Quay lại") { chuyen(.hoi) }
        }
    }

    @ViewBuilder private var buocNganh: some View {
        if let khoi {
            VStack(spacing: Spacing.sm) {
                loiDan("Khối **\(khoi.nameVi)**. Chọn ngành của bạn:")
                ForEach(khoi.majors) { m in
                    oChon(icon: m.icon, ten: m.nameVi, phu: m.name,
                          nhan: m.combos.isEmpty ? "Đủ lộ trình 9 kỳ · trường chưa công bố chuyên ngành"
                                                 : "\(m.combos.count) chuyên ngành hẹp · lộ trình 9 kỳ",
                          nhanNoi: !m.combos.isEmpty) {
                        nganhId = m.id; hepId = nil
                        if m.combos.isEmpty {
                            // Ngành không có ngành hẹp → vào thẳng.
                            hoSo.luu(isStudent: true, faculty: khoiId, major: m.id, combo: nil, ghiNho: ghiNho)
                            chuyen(.xong)
                        } else {
                            chuyen(.nganhHep)
                        }
                    }
                }
                nutLui("Chọn khối khác") { chuyen(.khoi) }
            }
        }
    }

    @ViewBuilder private var buocNganhHep: some View {
        if let nganh, let khoiId {
            VStack(spacing: Spacing.sm) {
                loiDan("Ngành **\(nganh.nameVi)** có \(nganh.combos.count) chuyên ngành hẹp. Chọn để mình hiện đúng lộ trình môn của bạn.")

                // Chưa biết chọn gì → Phòng tư vấn. Luôn ở TRÊN ĐẦU.
                Button {
                    Haptics.cham()
                    dismiss()
                    khiCanTuVan(khoiId, nganh.id)
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text("✨").font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tôi chưa chọn ngành hẹp — gợi ý giúp tôi")
                                .font(.titleSmall).foregroundColor(AppColors.textPrimary)
                            Text("Vào Phòng tư vấn AI: so sánh ngành, thị trường & lương, nối với môn bạn đã học.")
                                .font(.caption).foregroundColor(AppColors.textSecondary)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "sparkles").foregroundColor(AppColors.primary)
                    }
                    .padding(Spacing.md)
                    .background(LinearGradient(colors: [AppColors.primary.opacity(0.18), AppColors.secondary.opacity(0.10)],
                                               startPoint: .leading, endPoint: .trailing))
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.45), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(nganh.combos) { c in
                    oChon(icon: c.icon, ten: c.nameVi, phu: c.name == c.nameVi ? nil : c.name,
                          nhan: c.soMon > 0 ? "✓ \(c.soMon) môn · lộ trình 9 kỳ" : "Đang cập nhật khung",
                          nhanNoi: true) {
                        chonNganhHep(c.id)
                    }
                }

                // "Để sau" chỉ có nghĩa với khối CNTT — có khung nền nên chưa chọn vẫn thấy môn chung.
                if khoiId == "it" {
                    oChon(icon: "🕓", ten: "Chưa chọn / để sau",
                          phu: "Chưa tới kỳ chọn chuyên ngành thì chọn cái này. Đổi lại lúc nào cũng được.",
                          nhan: nil, nhanNoi: false, netDut: true) {
                        chonNganhHep(nil)
                    }
                }
                nutLui("Chọn ngành khác") { chuyen(.nganh) }
            }
        }
    }

    private var buocXong: some View {
        let hep = dm.nganhHep(khoiId, nganhId, hepId)
        return VStack(spacing: Spacing.md) {
            VStack(spacing: 6) {
                Group {
                    if let hep {
                        Text("Mình sẽ hiện môn của **\(nganh?.nameVi ?? "ngành bạn chọn")** — ngành hẹp **\(hep.nameVi)**.")
                    } else if let nganh, !nganh.combos.isEmpty {
                        Text("Mình sẽ hiện môn của **\(nganh.nameVi)** — chưa chọn ngành hẹp.")
                    } else {
                        Text("Mình sẽ hiện môn của **\(nganh?.nameVi ?? "ngành bạn chọn")**.")
                    }
                }
                .font(.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                Text(ghiNho ? "Muốn đổi thì bấm “Đổi ngành” ngay trong Academy, bất cứ lúc nào."
                            : "Bạn đã tắt lưu ghi nhớ: lựa chọn chỉ dùng cho lần mở app này.")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppColors.primary.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(AppColors.primary.opacity(0.3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))

            Button {
                Haptics.cham()
                dismiss()
                khiXemSoDo()
            } label: {
                VStack(spacing: 2) {
                    Text("🗺️ Xem sơ đồ môn học").font(.buttonText)
                    Text("Học xong làm gì, từng môn để làm gì").font(.caption).foregroundColor(AppColors.textTertiary)
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(AppColors.secondary.opacity(0.5), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            }
            .buttonStyle(.plain)

            Button { Haptics.xong(); dismiss() } label: {
                VStack(spacing: 2) {
                    Text("Vào học ngay").font(.buttonText)
                    Text("Xem lộ trình môn của tôi").font(.caption).opacity(0.85)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(AppColors.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            }
            .buttonStyle(.plain)
        }
    }

    private var oGhiNho: some View {
        Toggle(isOn: $ghiNho) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lưu ghi nhớ lựa chọn").font(.titleSmall).foregroundColor(AppColors.textPrimary)
                Text(ghiNho
                     ? "Đang đăng nhập thì lựa chọn theo bạn sang web và máy khác; chưa đăng nhập thì chỉ nằm trên máy này."
                     : "Không lưu: lựa chọn chỉ dùng cho lần mở app này, lần sau mình sẽ hỏi lại.")
                    .font(.caption).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppColors.primary)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    // MARK: Mảnh dùng chung

    private func chuyen(_ b: BuocChonNganh) {
        Haptics.cham()
        withAnimation(.snappy(duration: 0.25)) { buoc = b }
    }

    private func chonNganhHep(_ id: String?) {
        hepId = id
        hoSo.luu(isStudent: true, faculty: khoiId, major: nganhId, combo: id, ghiNho: ghiNho)
        chuyen(.xong)
    }

    private func loiDan(_ s: LocalizedStringKey) -> some View {
        Text(s)
            .font(.bodyMedium)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
    }

    private func oChon(icon: String, ten: String, phu: String?, nhan: String?, nhanNoi: Bool,
                       netDut: Bool = false, bam: @escaping () -> Void) -> some View {
        Button(action: bam) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text(icon).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 3) {
                    Text(ten).font(.titleSmall).foregroundColor(AppColors.textPrimary)
                    if let phu {
                        Text(phu).font(.caption).foregroundColor(AppColors.textTertiary)
                    }
                    if let nhan {
                        Text(nhan)
                            .font(.caption)
                            .foregroundColor(nhanNoi ? AppColors.secondary : AppColors.textTertiary)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
                    .padding(.top, 4)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(netDut ? Color.clear : AppColors.backgroundCard)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: netDut ? [5, 4] : [])))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func nutLui(_ nhan: String, bam: @escaping () -> Void) -> some View {
        Button(action: bam) {
            Label(nhan, systemImage: "arrow.left")
                .font(.buttonSmall)
                .foregroundColor(AppColors.textSecondary)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Robot

/// Robot nhỏ vẽ bằng SwiftUI — cùng dáng con robot SVG của web, ba biểu cảm.
struct RobotAcademy: View {
    enum CamXuc { case toMo, vui, mung }
    let camXuc: CamXuc
    var nho = false

    @State private var vay = false
    @State private var roi = false
    @Environment(\.accessibilityReduceMotion) private var giamChuyenDong

    var body: some View {
        let mat = camXuc == .mung ? Color(hex: 0xFACC15) : Color(hex: 0x22D3EE)
        let than = LinearGradient(colors: [Color(hex: 0x818CF8), Color(hex: 0x8B5CF6)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        ZStack {
            // ăng-ten
            Capsule().fill(Color(hex: 0xA5B4FC)).frame(width: 3, height: 14).offset(y: -44)
            Circle().fill(mat).frame(width: 10, height: 10).offset(y: -52)
                .opacity(vay || giamChuyenDong ? 1 : 0.45)
            // thân
            RoundedRectangle(cornerRadius: 13).fill(than).frame(width: 48, height: 32).offset(y: 30)
            Circle().fill(mat).frame(width: 6, height: 6).offset(y: 30)
            // tay vẫy
            Capsule().fill(Color(hex: 0x6366F1)).frame(width: 10, height: 22).offset(x: -34, y: 30)
            Capsule().fill(Color(hex: 0x6366F1)).frame(width: 10, height: 24)
                .rotationEffect(.degrees(vay && !giamChuyenDong ? -40 : 18), anchor: .bottom)
                .offset(x: 34, y: 18)
            // đầu + kính
            RoundedRectangle(cornerRadius: 17).fill(than).frame(width: 64, height: 46).offset(y: -12)
            RoundedRectangle(cornerRadius: 13)
                .fill(LinearGradient(colors: [Color(hex: 0x0F172A), Color(hex: 0x1E1B4B)], startPoint: .top, endPoint: .bottom))
                .frame(width: 48, height: 26).offset(y: -12)
            matRobot(mau: mat).offset(y: -13)
        }
        .frame(width: 108, height: 124)
        .scaleEffect(nho ? 0.62 : 0.9)
        .frame(width: nho ? 70 : 100, height: nho ? 78 : 112)
        .offset(y: roi || giamChuyenDong ? 0 : -60)
        .opacity(roi || giamChuyenDong ? 1 : 0)
        .animation(.snappy, value: nho)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { roi = true }
            guard !giamChuyenDong else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { vay = true }
        }
    }

    @ViewBuilder private func matRobot(mau: Color) -> some View {
        switch camXuc {
        case .toMo:
            HStack(spacing: 11) { Circle().fill(mau).frame(width: 11); Circle().fill(mau).frame(width: 11) }
        case .vui:
            HStack(spacing: 10) {
                Image(systemName: "chevron.up").font(.system(size: 11, weight: .heavy)).foregroundColor(mau)
                Image(systemName: "chevron.up").font(.system(size: 11, weight: .heavy)).foregroundColor(mau)
            }
        case .mung:
            HStack(spacing: 10) {
                Image(systemName: "sparkle").font(.system(size: 12, weight: .bold)).foregroundColor(mau)
                Image(systemName: "sparkle").font(.system(size: 12, weight: .bold)).foregroundColor(mau)
            }
        }
    }
}
