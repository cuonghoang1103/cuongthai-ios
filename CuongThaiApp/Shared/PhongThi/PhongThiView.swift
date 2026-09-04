import SwiftUI

// ── Danh sách đề ────────────────────────────────────────────────

struct PhongThiView: View {
    @State private var de: [DeThi] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var tuKhoa = ""
    @State private var khoaChon: String?
    /// ⚠️ Mặc định TIẾNG ANH, khớp `ExamPortalClient` của web.
    @State private var ngonNgu: NgonNguDe = .anh

    private var khoaCo: [String] {
        Array(Set(de.map(\.tenKhoa))).sorted()
    }

    private var hienThi: [DeThi] {
        var ds = de
        if let k = khoaChon { ds = ds.filter { $0.tenKhoa == k } }
        let t = tuKhoa.trimmingCharacters(in: .whitespaces).lowercased()
        if !t.isEmpty {
            ds = ds.filter {
                // Tìm trên chuỗi GỐC, tức quét cả nửa Anh lẫn nửa Việt: gõ
                // "thi lại" hay "retake" đều phải ra, bất kể đang xem tiếng
                // nào.
                $0.title.lowercased().contains(t)
                || ($0.code ?? "").lowercased().contains(t)
                || $0.tenKhoa.lowercased().contains(t)
            }
        }
        return ds
    }

    /// Gom theo khoá học. 190 đề đổ thành một danh sách phẳng thì không tìm
    /// nổi cái mình cần.
    private var theoKhoa: [(String, [DeThi])] {
        Dictionary(grouping: hienThi, by: \.tenKhoa)
            .map { ($0.key, $0.value.sorted { ($0.code ?? "") < ($1.code ?? "") }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                oTim
                if !khoaCo.isEmpty { thanhKhoa }

                if dangTai && de.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if hienThi.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 36)).foregroundColor(AppColors.textTertiary)
                        Text(loi ?? "Không tìm thấy đề nào.")
                            .font(.body).foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else {
                    ForEach(theoKhoa, id: \.0) { khoa, ds in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(khoa.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColors.textTertiary).kerning(0.6)
                            ForEach(ds) { d in
                                NavigationLink(destination: ChiTietDeView(de: d)) {
                                    hang(d)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Phòng thi")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { ngonNgu = ngonNgu.doiSang } label: {
                    Text(ngonNgu.nhanNut).font(.system(size: 13, weight: .bold))
                }
                .accessibilityLabel(ngonNgu == .viet ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink { DaLuuView() } label: {
                    Image(systemName: "bookmark")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink { LichSuThiView() } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        // Màn chi tiết đề mở ra từ đây phải nói CÙNG thứ tiếng với danh sách.
        .environment(\.ngonNguDe, ngonNgu)
        .navigationBarTitleDisplayMode(.inline)
        .task { if de.isEmpty { await tai() } }
        .refreshable { await tai() }
    }

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14)).foregroundColor(AppColors.textTertiary)
            TextField("Tìm đề, mã đề, môn…", text: $tuKhoa)
                .font(.system(size: 15))
                .oKhongTuSua()
            if !tuKhoa.isEmpty {
                Button { tuKhoa = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15)).foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private var thanhKhoa: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(khoaCo, id: \.self) { k in
                    let chon = khoaChon == k
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { khoaChon = chon ? nil : k }
                        Haptics.cham()
                    } label: {
                        Text(k)
                            .font(.system(size: 12, weight: chon ? .semibold : .regular))
                            .foregroundColor(chon ? .white : AppColors.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(chon ? AppColors.primary
                                                            : AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func hang(_ d: DeThi) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let c = d.code {
                        Text(c)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.secondary))
                    }
                    Text(d.nhanLoai)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
                Text(d.ten(ngonNgu))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text("\(d.soCau) câu · \(d.phut) phút")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func tai() async {
        dangTai = true; defer { dangTai = false }
        do {
            de = try await APIClient.shared.request(.dsDeThi)
            loi = nil
        } catch { loi = error.localizedDescription }
    }
}

// ── Trước khi vào thi ───────────────────────────────────────────

struct ChiTietDeView: View {
    @Environment(\.ngonNguDe) private var ngonNgu
    let de: DeThi
    @State private var vaoThi = false
    @State private var vaoOnTap = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(de.ten(ngonNgu))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // Dòng phụ là nửa còn lại — ở màn chi tiết có chỗ, và
                    // thấy cả hai tên giúp đối chiếu với đề giấy.
                    if let phu = de.tenPhu(ngonNgu) {
                        Text(phu)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: Spacing.sm) {
                    o("Số câu", "\(de.soCau)", "list.number")
                    o("Thời gian", "\(de.phut) phút", "clock")
                    o("Tổng điểm", nz(de.totalPoints), "star")
                    o("Điểm đạt", nz(de.passMark), "checkmark.seal")
                }

                if !de.tenKy.isEmpty || !de.tenKhoa.isEmpty {
                    Text([de.tenKhoa, de.tenKy].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                }

                Text("Đồng hồ chạy từ lúc bạn bấm Bắt đầu. Thoát ra rồi vào lại "
                   + "thì làm tiếp bài đang dở, không mất bài.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    vaoThi = true
                } label: {
                    Text("Bắt đầu làm bài")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(AppColors.primary))
                }
                .buttonStyle(.plain)

                // ── Phòng ôn tập cùng CuongMini ──────────────────────
                // Lượt RIÊNG, tách hẳn khỏi lượt thi thật: máy chủ lọc
                // `where: { …, aiAssisted }` nên bấm nút này KHÔNG bao giờ
                // nối nhầm vào bài đang chạy đồng hồ, và ngược lại.
                VStack(spacing: Spacing.sm) {
                    Button {
                        vaoOnTap = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Thi cùng CuongMini")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(
                            LinearGradient(colors: [AppColors.primary, AppColors.primaryDark],
                                           startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(.plain)

                    Text("Phòng ôn tập — KHÔNG tính giờ. Làm từng câu, hỏi AI về "
                       + "đúng câu đang mở, xem đáp án và bình luận thoải mái.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(de.code ?? "Đề thi")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $vaoThi) {
            LamBaiView(de: de)
        }
        .fullScreenCover(isPresented: $vaoOnTap) {
            LamBaiView(de: de, coAI: true)
        }
    }

    private func nz(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func o(_ ten: String, _ giaTri: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11)).foregroundColor(AppColors.primary)
                Text(ten).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
            }
            Text(giaTri)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }
}
