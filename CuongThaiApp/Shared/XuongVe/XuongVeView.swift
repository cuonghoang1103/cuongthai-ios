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
        }
    }
}
