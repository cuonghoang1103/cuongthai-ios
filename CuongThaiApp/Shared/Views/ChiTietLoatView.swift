import SwiftUI

// ════════════════════════════════════════════════════════════════
// MỘT LOẠT BÀI — lưới 100 ngày + tìm kiếm
//
// Hai kiểu xem:
//   • Lưới    — 100 ô số, nhìn một phát thấy ngay đã học tới đâu, còn hổng ngày
//               nào. Ngày chưa đăng để mờ và KHÔNG bấm được (bấm vào rồi báo
//               "không có bài" thì tệ hơn là không cho bấm).
//   • Danh sách — có tên bài, để tìm theo chữ.
//
// Ô tìm nhận CẢ HAI: gõ số thì nhảy tới ngày đó, gõ chữ thì lọc theo tên bài.
// ════════════════════════════════════════════════════════════════

struct ChiTietLoatView: View {
    let loat: LoatBai
    let mucLuc: PostSeries

    @State private var tuKhoa = ""
    @State private var kieuXem: KieuXem = .luoi
    @State private var baiDangMo: SocialPost?
    @State private var dangMoNgay: Int?
    @State private var loi: String?

    enum KieuXem: String, CaseIterable {
        case luoi = "Lưới"
        case danhSach = "Danh sách"
    }

    private var mau: Color { Color(hex: loat.mau[0]) }
    private var theoNgay: [Int: PostSeries.Ky] { mucLuc.theoNgay }

    /// Số gõ vào ô tìm, nếu nó là một ngày có thật trong loạt.
    private var ngayGoVao: Int? {
        let t = tuKhoa.trimmingCharacters(in: .whitespaces)
        guard let n = Int(t), n >= 1, n <= mucLuc.total else { return nil }
        return n
    }

    private var ketQuaLoc: [PostSeries.Ky] {
        let t = tuKhoa.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return mucLuc.items.sorted { $0.day < $1.day } }
        if let n = ngayGoVao {
            return mucLuc.items.filter { $0.day == n }
        }
        // `localizedCaseInsensitiveContains` để "mang" khớp cả "Mảng" — so chuỗi
        // thuần thì chữ có dấu trượt hết.
        return mucLuc.items
            .filter { $0.title.localizedCaseInsensitiveContains(t) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        ScrollViewReader { cuon in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    dauTrang
                    oTim
                    boChonKieu

                    if kieuXem == .luoi {
                        luoiNgay
                    } else {
                        danhSachBai
                    }
                }
                .padding(Spacing.md)
            }
            // Gõ số tới đâu cuộn tới đó. Ngày 87 nằm dưới đáy lưới 100 ô — gõ
            // xong mà vẫn phải tự cuộn tìm thì ô tìm chẳng giúp được gì.
            .onChange(of: ngayGoVao) { _, moi in
                guard let n = moi, kieuXem == .luoi else { return }
                withAnimation(.easeOut(duration: 0.25)) { cuon.scrollTo(n, anchor: .center) }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(loat.tenNgan)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $baiDangMo) { bai in
            PostDetailView(post: bai)
        }
        .alert("Lỗi", isPresented: .constant(loi != nil)) {
            Button("OK") { loi = nil }
        } message: {
            Text(loi ?? "")
        }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: loat.mau.map { Color(hex: $0) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: loat.bieuTuong)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Đã đăng \(mucLuc.soDaDang)/\(mucLuc.total) ngày")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(loat.moTa)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.border)
                    Capsule()
                        .fill(LinearGradient(colors: [mau.opacity(0.75), mau],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, min(1, mucLuc.tiLe)) * g.size.width)
                }
            }
            .frame(height: 6)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundSecondary)
        )
    }

    // MARK: Ô tìm

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
            TextField("Nhảy tới ngày (vd. 7) hoặc tìm tên bài", text: $tuKhoa)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .banPhimSo(dangSo: Int(tuKhoa.trimmingCharacters(in: .whitespaces)) != nil)
                .oKhongTuSua()
            if !tuKhoa.isEmpty {
                Button {
                    tuKhoa = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: Bộ chọn kiểu xem

    private var boChonKieu: some View {
        Picker("", selection: $kieuXem) {
            ForEach(KieuXem.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Lưới ngày

    private var luoiNgay: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let n = ngayGoVao {
                if let ky = theoNgay[n] {
                    Button {
                        Task { await moBai(ky) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Mở Ngày \(n) — \(ky.title)")
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: loat.mau.map { Color(hex: $0) },
                                                     startPoint: .leading, endPoint: .trailing))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Ngày \(n) chưa đăng.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                      spacing: 8) {
                ForEach(1...mucLuc.total, id: \.self) { ngay in
                    let ky = theoNgay[ngay]
                    ONgay(
                        ngay: ngay,
                        coBai: ky != nil,
                        dangTai: dangMoNgay == ngay,
                        noiBat: ngayGoVao == ngay,
                        mau: mau
                    ) {
                        if let ky { Task { await moBai(ky) } }
                    }
                    .id(ngay)
                }
            }

            chuGiai
        }
    }

    private var chuGiai: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 4).fill(mau).frame(width: 12, height: 12)
                Text("Đã đăng")
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.backgroundSecondary)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.border, lineWidth: 1))
                    .frame(width: 12, height: 12)
                Text("Chưa đăng")
            }
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundColor(AppColors.textTertiary)
        .padding(.top, 4)
    }

    // MARK: Danh sách bài

    private var danhSachBai: some View {
        LazyVStack(spacing: 8) {
            if ketQuaLoc.isEmpty {
                Text(tuKhoa.isEmpty
                     ? "Loạt này chưa có bài nào."
                     : "Không có bài nào khớp “\(tuKhoa)”.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            } else {
                ForEach(ketQuaLoc) { ky in
                    Button {
                        Task { await moBai(ky) }
                    } label: {
                        HangBai(ky: ky, mau: mau, dangTai: dangMoNgay == ky.day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Mở một kỳ

    /// Mục lục chỉ có `postId`, nên phải tải bài đầy đủ rồi mới đẩy màn chi tiết
    /// — `PostDetailView` nhận cả bài chứ không nhận id.
    private func moBai(_ ky: PostSeries.Ky) async {
        guard dangMoNgay == nil else { return }
        dangMoNgay = ky.day
        defer { dangMoNgay = nil }
        do {
            let bai: SocialPost = try await APIClient.shared.request(.getPost(id: ky.postId))
            baiDangMo = bai
        } catch {
            loi = "Không mở được bài Ngày \(ky.day) — có thể nó đã bị xoá."
        }
    }
}

// MARK: - Một ô trong lưới

private struct ONgay: View {
    let ngay: Int
    let coBai: Bool
    let dangTai: Bool
    let noiBat: Bool
    let mau: Color
    let cham: () -> Void

    var body: some View {
        Button(action: cham) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(coBai
                          ? AnyShapeStyle(LinearGradient(colors: [mau.opacity(0.85), mau],
                                                         startPoint: .topLeading,
                                                         endPoint: .bottomTrailing))
                          : AnyShapeStyle(AppColors.backgroundSecondary))
                if dangTai {
                    ProgressView().scaleEffect(0.7).tint(coBai ? .white : AppColors.textSecondary)
                } else {
                    Text("\(ngay)")
                        .font(.system(size: 15, weight: coBai ? .bold : .regular))
                        .foregroundColor(coBai ? .white : AppColors.textTertiary)
                }
            }
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(noiBat ? AppColors.textPrimary : (coBai ? .clear : AppColors.border),
                            lineWidth: noiBat ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!coBai || dangTai)
        .accessibilityLabel(coBai ? "Ngày \(ngay), đã có bài" : "Ngày \(ngay), chưa đăng")
    }
}

// MARK: - Một hàng trong danh sách

private struct HangBai: View {
    let ky: PostSeries.Ky
    let mau: Color
    let dangTai: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(mau.opacity(0.15))
                if dangTai {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Text("\(ky.day)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(mau)
                }
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ngày \(ky.day)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                Text(ky.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.backgroundSecondary)
        )
    }
}
