import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

// MARK: - Danh sách bản vẽ

/// Xưởng vẽ — chỗ vẽ tự do và dựng bố cục giao diện.
///
/// Hai tầng chồng lên nhau, cố ý:
///   · **nét tay** (PencilKit) — phác, ghi chú, gạch xoá
///   · **hình khối** — chữ nhật, elip, đường, chữ; kéo được, đổi màu được
///
/// Vì sao không chỉ một tầng: nét tay không sửa được sau khi vẽ (muốn dịch
/// một ô sang phải 20pt thì phải tẩy đi vẽ lại), còn hình khối thì không
/// phác nhanh được. Một bản thiết kế thật luôn cần cả hai.
struct XuongVeView: View {
    var coNutDong = false

    @StateObject private var kho = KhoBanVe.chung
    @Environment(\.dismiss) private var dong
    @State private var moTao = false
    @State private var tenMoi = ""
    @State private var khoMoi: KhoVe = .tuDo
    @State private var hoiXoa: BanVe?

    var body: some View {
        NavigationStack {
            Group {
                if kho.danhSach.isEmpty { khungTrong } else { luoi }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Xưởng vẽ"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if coNutDong {
                    ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { tenMoi = ""; khoMoi = .tuDo; moTao = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $moTao) { manTao }
            .alert(T("Xoá bản vẽ này?"), isPresented: Binding(
                get: { hoiXoa != nil }, set: { if !$0 { hoiXoa = nil } })) {
                Button(T("Huỷ"), role: .cancel) { hoiXoa = nil }
                Button(T("Xoá"), role: .destructive) {
                    if let b = hoiXoa { kho.xoa(b) }
                    hoiXoa = nil
                }
            } message: { Text(T("Cả nét vẽ lẫn hình khối đều mất. Không khôi phục được.")) }
            .task { kho.nap() }
        }
    }

    private var khungTrong: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 52)).foregroundStyle(AppColors.textTertiary.opacity(0.6))
            Text(T("Chưa có bản vẽ nào")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            Text(T("Vẽ tự do, phác bố cục giao diện, hay dựng sơ đồ — chọn khổ giấy rồi bắt đầu."))
                .font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button(T("Tạo bản vẽ")) { tenMoi = ""; moTao = true }
                .font(.buttonText)
                .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm + 2)
                .background(AppColors.primary).foregroundStyle(Color.white)
                .cornerRadius(CornerRadius.full)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var luoi: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: Spacing.md)], spacing: Spacing.md) {
                ForEach(kho.danhSach) { b in
                    NavigationLink { KhungVeView(banVe: b) } label: { the(b) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { hoiXoa = b } label: {
                                Label(T("Xoá"), systemImage: "trash")
                            }
                        }
                }
            }
            .padding(Spacing.md)
        }
    }

    private func the(_ b: BanVe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color(maHex: b.nen))
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(AppColors.border, lineWidth: 1))
                // Xem trước bằng chính hình khối của bản vẽ, thu nhỏ lại. Rẻ
                // hơn hẳn dựng ảnh thu nhỏ rồi phải nhớ cập nhật mỗi lần sửa —
                // mà quên cập nhật thì thẻ hiện một bản vẽ đã cũ.
                GeometryReader { g in
                    let ti = min(g.size.width / b.coKhung.width, g.size.height / b.coKhung.height)
                    ZStack(alignment: .topLeading) {
                        ForEach(b.hinh) { h in VeMotHinh(hinh: h).frame(width: h.rong, height: h.cao)
                            .offset(x: h.x, y: h.y) }
                    }
                    .frame(width: b.coKhung.width, height: b.coKhung.height, alignment: .topLeading)
                    .scaleEffect(ti, anchor: .topLeading)
                }
                .clipped()
            }
            .frame(height: 118)

            Text(b.ten).font(.bodyMedium).foregroundStyle(AppColors.textPrimary).lineLimit(1)
            Text("\(b.kho.ten) · \(b.hinh.count) \(T("hình"))")
                .font(.caption2).foregroundStyle(AppColors.textTertiary)
        }
        .padding(Spacing.sm)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var manTao: some View {
        NavigationStack {
            Form {
                Section { TextField(T("Tên bản vẽ"), text: $tenMoi) }
                Section(T("Khổ giấy")) {
                    ForEach(KhoVe.allCases) { k in
                        Button { khoMoi = k } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(k.ten).foregroundStyle(AppColors.textPrimary)
                                    Text(k.moTa).font(.caption2).foregroundStyle(AppColors.textTertiary)
                                }
                                Spacer()
                                if khoMoi == k { Image(systemName: "checkmark").foregroundStyle(AppColors.primary) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(T("Bản vẽ mới"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Huỷ")) { moTao = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Tạo")) { _ = kho.moi(ten: tenMoi, kho: khoMoi); moTao = false }
                }
            }
        }
    }
}

// MARK: - Vẽ một hình

struct VeMotHinh: View {
    let hinh: HinhVe

    var body: some View {
        switch hinh.loai {
        case .chuNhat, .bo:
            RoundedRectangle(cornerRadius: hinh.loai == .bo ? hinh.goc : 0)
                .fill(Color(maHex: hinh.mauNen).opacity(hinh.doMo))
                .overlay {
                    if hinh.dayVien > 0 {
                        RoundedRectangle(cornerRadius: hinh.loai == .bo ? hinh.goc : 0)
                            .stroke(Color(maHex: hinh.mauVien), lineWidth: hinh.dayVien)
                    }
                }
        case .elip:
            Ellipse()
                .fill(Color(maHex: hinh.mauNen).opacity(hinh.doMo))
                .overlay {
                    if hinh.dayVien > 0 {
                        Ellipse().stroke(Color(maHex: hinh.mauVien), lineWidth: hinh.dayVien)
                    }
                }
        case .duong:
            // Vẽ bằng `Path` chứ không dùng `Rectangle` dẹt: một hình chữ nhật
            // cao 2pt trông giống đường thẳng cho tới lúc người dùng xoay nó.
            Path { p in
                p.move(to: CGPoint(x: 0, y: hinh.cao / 2))
                p.addLine(to: CGPoint(x: hinh.rong, y: hinh.cao / 2))
            }
            .stroke(Color(maHex: hinh.mauNen).opacity(hinh.doMo),
                    style: StrokeStyle(lineWidth: max(1, hinh.dayVien > 0 ? hinh.dayVien : 3), lineCap: .round))
        case .muiTen:
            Path { p in
                let y = hinh.cao / 2
                let mui = min(14, hinh.rong * 0.3)
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: hinh.rong, y: y))
                p.move(to: CGPoint(x: hinh.rong - mui, y: y - mui * 0.7))
                p.addLine(to: CGPoint(x: hinh.rong, y: y))
                p.addLine(to: CGPoint(x: hinh.rong - mui, y: y + mui * 0.7))
            }
            .stroke(Color(maHex: hinh.mauNen).opacity(hinh.doMo),
                    style: StrokeStyle(lineWidth: max(1, hinh.dayVien > 0 ? hinh.dayVien : 3),
                                       lineCap: .round, lineJoin: .round))
        case .chu:
            Text(hinh.chu.isEmpty ? T("Chữ") : hinh.chu)
                .font(.system(size: hinh.coChu, weight: .semibold))
                .foregroundStyle(Color(maHex: hinh.mauChu))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        // ─── Hình cho sơ đồ giảng dạy ───────────────────────────────

        case .tamGiac:
            daGiac([(0.5, 0), (1, 1), (0, 1)])
        case .thoi:
            daGiac([(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)])
        case .saoNam:
            daGiac(saoNamCanh())

        case .trUong:
            // Hình trụ đứng — ký hiệu CƠ SỞ DỮ LIỆU trong mọi sơ đồ kiến
            // trúc. Vẽ tay mỗi lần là việc ai dạy hệ thống cũng phải làm.
            ZStack {
                Path { p in
                    let n = min(hinh.cao * 0.18, hinh.rong * 0.5)
                    p.move(to: CGPoint(x: 0, y: n))
                    p.addLine(to: CGPoint(x: 0, y: hinh.cao - n))
                    p.addCurve(to: CGPoint(x: hinh.rong, y: hinh.cao - n),
                               control1: CGPoint(x: 0, y: hinh.cao + n * 0.6),
                               control2: CGPoint(x: hinh.rong, y: hinh.cao + n * 0.6))
                    p.addLine(to: CGPoint(x: hinh.rong, y: n))
                    p.addCurve(to: CGPoint(x: 0, y: n),
                               control1: CGPoint(x: hinh.rong, y: -n * 0.6),
                               control2: CGPoint(x: 0, y: -n * 0.6))
                }
                .fill(Color(maHex: hinh.mauNen).opacity(hinh.doMo))
                Path { p in
                    let n = min(hinh.cao * 0.18, hinh.rong * 0.5)
                    p.move(to: CGPoint(x: 0, y: n))
                    p.addCurve(to: CGPoint(x: hinh.rong, y: n),
                               control1: CGPoint(x: 0, y: n * 2.2),
                               control2: CGPoint(x: hinh.rong, y: n * 2.2))
                }
                .stroke(Color(maHex: hinh.mauVien.isEmpty ? "#00000055" : hinh.mauVien),
                        lineWidth: max(1, hinh.dayVien))
            }

        case .muiTenHai:
            Path { p in
                let y = hinh.cao / 2
                let mui = min(14, hinh.rong * 0.25)
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: hinh.rong, y: y))
                for (goc, huong) in [(0.0, 1.0), (hinh.rong, -1.0)] {
                    p.move(to: CGPoint(x: goc + mui * huong, y: y - mui * 0.7))
                    p.addLine(to: CGPoint(x: goc, y: y))
                    p.addLine(to: CGPoint(x: goc + mui * huong, y: y + mui * 0.7))
                }
            }
            .stroke(Color(maHex: hinh.mauNen).opacity(hinh.doMo),
                    style: StrokeStyle(lineWidth: max(1, hinh.dayVien > 0 ? hinh.dayVien : 3),
                                       lineCap: .round, lineJoin: .round))

        case .netDut:
            Path { p in
                p.move(to: CGPoint(x: 0, y: hinh.cao / 2))
                p.addLine(to: CGPoint(x: hinh.rong, y: hinh.cao / 2))
            }
            .stroke(Color(maHex: hinh.mauNen).opacity(hinh.doMo),
                    style: StrokeStyle(lineWidth: max(1, hinh.dayVien > 0 ? hinh.dayVien : 3),
                                       lineCap: .round, dash: [10, 8]))

        case .trucToaDo:
            // Hệ trục Oxy có mũi tên và vạch chia — thứ mở đầu mọi bài
            // hàm số, đồ thị, vật lý.
            Path { p in
                let cx = hinh.rong / 2, cy = hinh.cao / 2, m = 9.0
                p.move(to: CGPoint(x: 0, y: cy)); p.addLine(to: CGPoint(x: hinh.rong, y: cy))
                p.move(to: CGPoint(x: hinh.rong - m, y: cy - m * 0.65))
                p.addLine(to: CGPoint(x: hinh.rong, y: cy))
                p.addLine(to: CGPoint(x: hinh.rong - m, y: cy + m * 0.65))
                p.move(to: CGPoint(x: cx, y: hinh.cao)); p.addLine(to: CGPoint(x: cx, y: 0))
                p.move(to: CGPoint(x: cx - m * 0.65, y: m))
                p.addLine(to: CGPoint(x: cx, y: 0))
                p.addLine(to: CGPoint(x: cx + m * 0.65, y: m))
                let buoc = max(18.0, min(hinh.rong, hinh.cao) / 10)
                var t = buoc
                while t < max(hinh.rong, hinh.cao) / 2 {
                    if cx + t < hinh.rong { p.move(to: CGPoint(x: cx + t, y: cy - 4)); p.addLine(to: CGPoint(x: cx + t, y: cy + 4)) }
                    if cx - t > 0 { p.move(to: CGPoint(x: cx - t, y: cy - 4)); p.addLine(to: CGPoint(x: cx - t, y: cy + 4)) }
                    if cy + t < hinh.cao { p.move(to: CGPoint(x: cx - 4, y: cy + t)); p.addLine(to: CGPoint(x: cx + 4, y: cy + t)) }
                    if cy - t > 0 { p.move(to: CGPoint(x: cx - 4, y: cy - t)); p.addLine(to: CGPoint(x: cx + 4, y: cy - t)) }
                    t += buoc
                }
            }
            .stroke(Color(maHex: hinh.mauNen).opacity(hinh.doMo),
                    style: StrokeStyle(lineWidth: max(1, hinh.dayVien > 0 ? hinh.dayVien : 2),
                                       lineCap: .round, lineJoin: .round))
        }
    }

    /// Đa giác theo toạ độ TỈ LỆ (0…1) — tự co theo cỡ hình nên kéo to nhỏ
    /// không méo, khác hẳn toạ độ tuyệt đối.
    @ViewBuilder
    private func daGiac(_ diem: [(Double, Double)]) -> some View {
        let p = Path { p in
            guard let d = diem.first else { return }
            p.move(to: CGPoint(x: d.0 * hinh.rong, y: d.1 * hinh.cao))
            for t in diem.dropFirst() {
                p.addLine(to: CGPoint(x: t.0 * hinh.rong, y: t.1 * hinh.cao))
            }
            p.closeSubpath()
        }
        ZStack {
            p.fill(Color(maHex: hinh.mauNen).opacity(hinh.doMo))
            if hinh.dayVien > 0 {
                p.stroke(Color(maHex: hinh.mauVien), lineWidth: hinh.dayVien)
            }
        }
    }

    private func saoNamCanh() -> [(Double, Double)] {
        var ra: [(Double, Double)] = []
        for i in 0..<10 {
            let r = i % 2 == 0 ? 0.5 : 0.21
            let a = Double(i) * .pi / 5 - .pi / 2
            ra.append((0.5 + r * cos(a), 0.5 + r * sin(a)))
        }
        return ra
    }
}
