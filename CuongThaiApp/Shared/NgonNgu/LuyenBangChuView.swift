import SwiftUI

// ════════════════════════════════════════════════════════════════
// LUYỆN TẬP BẢNG CHỮ CÁI
//
// Ba màn nối nhau: CHỌN (nhóm chữ · chặng · số câu) → LÀM BÀI → KẾT QUẢ.
// Bản iOS của `/language/ja/alphabet/practice` trên web, dùng chung đúng
// một nguồn dữ liệu: `GET /my-language/:code/alphabet`.
//
// ⚠️ Chỉ mở cho TIẾNG NHẬT, giống web — và đây là kết luận ĐO ra chứ không
// phải chép: gọi thật cả ba endpoint 18/09/2026 thì thấy trường
// `romanization` mang nghĩa khác nhau tuỳ tiếng.
//     ja → phiên âm thật:  あ = "a"
//     zh → VÍ DỤ:          b = "bā 八 (số 8)"
//     en → ví dụ/IPA:      A a = "/eɪ/"
// Bộ máy này hỏi "chữ này đọc là gì" rồi bắt gõ lại, nên với zh/en nó sẽ
// đòi người học gõ nguyên cụm "bā 八 (số 8)". Mở cho cả ba là hỏng câm.
// ════════════════════════════════════════════════════════════════

struct LuyenBangChuView: View {
    let ngonNgu: NgonNgu

    @State private var nhom: [NhomLuyen] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var caiDat = CaiDatLuyenChu(nhomIds: [], changs: [], soCau: 20)
    @State private var dangChoi: PhienDangChoi?

    /// Bọc bộ câu hỏi để `fullScreenCover(item:)` nhận diện được.
    private struct PhienDangChoi: Identifiable {
        let id = UUID()
        let cauHoi: [CauHoiChu]
        let bo: [ChuLuyen]
    }

    private var nhomDaChon: [NhomLuyen] {
        nhom.filter { caiDat.nhomIds.contains($0.id) }
    }

    private var soChuDaChon: Int { nhomDaChon.reduce(0) { $0 + $1.chu.count } }

    private var batDauDuoc: Bool {
        !nhomDaChon.isEmpty && !caiDat.changs.isEmpty
    }

    var body: some View {
        ScrollView {
            if dangTai {
                ProgressView().padding(.top, Spacing.xxl)
            } else if nhom.isEmpty {
                trangTrong
            } else {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    phanNhomChu
                    phanChang
                    phanSoCau
                    nutBatDau
                }
                .padding(Spacing.md)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Luyện tập bảng chữ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await tai() }
        .onChange(of: caiDat) { _, moi in
            guard !dangTai else { return }
            KhoCaiDatLuyenChu.ghi(moi, code: ngonNgu.code)
        }
        .fullScreenCover(item: $dangChoi) { p in
            PhienLuyenChuView(cauHoi: p.cauHoi, bo: p.bo, maNgonNgu: ngonNgu.code) {
                batDau()
            }
        }
    }

    // ── Nhóm chữ ────────────────────────────────────────────────
    private var phanNhomChu: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                tieuDePhan("Nhóm chữ")
                Spacer()
                Text("\(soChuDaChon) chữ đã chọn")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }

            FlowRow(spacing: Spacing.sm) {
                ForEach(nhom) { n in
                    let chon = caiDat.nhomIds.contains(n.id)
                    Button {
                        doiNhom(n.id)
                    } label: {
                        HStack(spacing: 6) {
                            if chon {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text("\(n.ten) · \(n.chu.count)")
                                .font(.system(size: 14, weight: chon ? .semibold : .regular))
                        }
                        .foregroundColor(chon ? AppColors.primary : AppColors.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(chon ? AppColors.primary.opacity(0.16)
                                                : AppColors.backgroundTertiary),
                        )
                        .overlay(
                            Capsule().stroke(chon ? AppColors.primary.opacity(0.5) : .clear,
                                             lineWidth: 1),
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // ── Chặng ───────────────────────────────────────────────────
    private var phanChang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                tieuDePhan("Bài luyện")
                Spacer()
                Button("Tất cả") {
                    caiDat.changs = ChangLuyen.allCases
                    Haptics.cham()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.primary)
                Button("Bỏ hết") {
                    caiDat.changs = []
                    Haptics.cham()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: Spacing.sm)],
                      spacing: Spacing.sm) {
                ForEach(ChangLuyen.allCases) { c in
                    theChang(c)
                }
            }
        }
    }

    private func theChang(_ c: ChangLuyen) -> some View {
        let bat = caiDat.changs.contains(c)
        return Button {
            doiChang(c)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: c.bieuTuong)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(c.mau)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(c.mau.opacity(0.14)))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("\(c.so).")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                        Text(c.ten)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text(c.mota)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: bat ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19))
                    .foregroundColor(bat ? AppColors.primary : AppColors.textTertiary)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(bat ? AppColors.primary.opacity(0.08) : AppColors.backgroundCard))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(bat ? AppColors.primary.opacity(0.35) : AppColors.border, lineWidth: 1),
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ── Số câu ──────────────────────────────────────────────────
    private var phanSoCau: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            tieuDePhan("Số câu")
            HStack(spacing: Spacing.sm) {
                ForEach(CaiDatLuyenChu.soCauChon, id: \.self) { n in
                    let chon = caiDat.soCau == n
                    Button {
                        caiDat.soCau = n; Haptics.cham()
                    } label: {
                        Text(n == 0 ? "Tất cả" : "\(n)")
                            .font(.system(size: 15, weight: chon ? .semibold : .regular))
                            .foregroundColor(chon ? AppColors.primary : AppColors.textSecondary)
                            .frame(minWidth: 56)
                            .padding(.vertical, 10)
                            .padding(.horizontal, Spacing.sm)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(chon ? AppColors.primary.opacity(0.16)
                                           : AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var nutBatDau: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: batDau) {
                Label("Bắt đầu", systemImage: "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.primary))
            }
            .buttonStyle(.plain)
            .disabled(!batDauDuoc)
            .opacity(batDauDuoc ? 1 : 0.45)

            // Nút mờ mà không nói vì sao thì người dùng tưởng app hỏng.
            if !batDauDuoc {
                Text(nhomDaChon.isEmpty ? "Chọn ít nhất một nhóm chữ"
                                        : "Chọn ít nhất một bài luyện")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.warning)
            }
        }
        .padding(.top, Spacing.xs)
    }

    private func tieuDePhan(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(AppColors.textPrimary)
    }

    private var trangTrong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 38))
                .foregroundColor(AppColors.textTertiary)
            Text(loi ?? "Ngôn ngữ này chưa có bảng chữ để luyện.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.lg)
    }

    // ── Việc ────────────────────────────────────────────────────
    private func doiNhom(_ id: Int) {
        if let i = caiDat.nhomIds.firstIndex(of: id) {
            caiDat.nhomIds.remove(at: i)
        } else {
            caiDat.nhomIds.append(id)
        }
        Haptics.cham()
    }

    private func doiChang(_ c: ChangLuyen) {
        if let i = caiDat.changs.firstIndex(of: c) {
            caiDat.changs.remove(at: i)
        } else {
            caiDat.changs.append(c)
        }
        Haptics.cham()
    }

    private func batDau() {
        let ds = BoCauHoi.dung(nhom: nhomDaChon, changs: caiDat.changs, soCau: caiDat.soCau)
        guard !ds.isEmpty else { return }
        dangChoi = PhienDangChoi(cauHoi: ds, bo: nhomDaChon.flatMap(\.chu))
        Haptics.cham()
    }

    private func tai() async {
        dangTai = true
        do {
            let ds: [NhomChu] = try await APIClient.shared.request(.bangChu(code: ngonNgu.code))
            nhom = nhomLuyen(tu: ds)
            caiDat = KhoCaiDatLuyenChu.doc(ngonNgu.code, nhom: nhom)
            loi = nil
        } catch {
            loi = error.localizedDescription
        }
        dangTai = false
    }
}

// MARK: - Làm bài

struct PhienLuyenChuView: View {
    let cauHoi: [CauHoiChu]
    let bo: [ChuLuyen]
    let maNgonNgu: String
    /// Làm lại: đóng phiên này rồi mở phiên mới với bộ câu hỏi khác.
    let khiLamLai: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viTri = 0
    @State private var ketQua: [KetQuaCau] = []
    @State private var daChamCau = false
    @State private var hoiThoat = false

    private var cau: CauHoiChu? { viTri < cauHoi.count ? cauHoi[viTri] : nil }
    private var diem: Int { ketQua.filter(\.dung).count }
    private var xong: Bool { viTri >= cauHoi.count }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if xong {
                    KetQuaLuyenChuView(ketQua: ketQua,
                                       khiLamLai: { dismiss(); khiLamLai() },
                                       khiDong: { dismiss() })
                } else {
                    thanhDau
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            if let c = cau { manChang(c) }
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: 620)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .alert("Thoát bài luyện?", isPresented: $hoiThoat) {
            Button("Ở lại", role: .cancel) {}
            Button("Thoát", role: .destructive) { dismiss() }
        } message: {
            Text("Kết quả của phiên này sẽ không được lưu.")
        }
    }

    @ViewBuilder
    private func manChang(_ c: CauHoiChu) -> some View {
        // `.id` PHẢI có: thiếu nó thì SwiftUI dùng lại đúng View cũ cho câu
        // kế tiếp, mang theo cả `@State` — đáp án đã chọn của câu trước vẫn
        // còn nguyên trên màn hình câu sau.
        Group {
            switch c.chang {
            case .tracNghiem:
                ChangTracNghiemView(cau: c, bo: bo, khiCham: cham, khiTiep: tiep)
            case .tracNghiemDao:
                ChangTracNghiemDaoView(cau: c, bo: bo, khiCham: cham, khiTiep: tiep)
            case .timCap:
                ChangTimCapView(bo: bo, khiCham: cham, khiTiep: tiep)
            case .vietDapAn, .vietTu, .vietDoan:
                ChangVietView(cau: c, khiCham: cham, khiTiep: tiep)
            case .nghe:
                ChangNgheView(cau: c, maNgonNgu: maNgonNgu, khiCham: cham, khiTiep: tiep)
            case .tapViet:
                ChangTapVietView(cau: c, maNgonNgu: maNgonNgu, khiCham: cham, khiTiep: tiep)
            case .veChu:
                ChangVeChuView(cau: c, maNgonNgu: maNgonNgu, khiCham: cham, khiTiep: tiep)
            }
        }
        .id(c.id)
    }

    private var thanhDau: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                if let c = cau {
                    HStack(spacing: 5) {
                        Image(systemName: c.chang.bieuTuong)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(c.chang.mau)
                        Text(c.chang.ten)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.backgroundTertiary))
                }

                Spacer(minLength: Spacing.xs)

                Text("\(min(viTri + 1, cauHoi.count)) / \(cauHoi.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(diem)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppColors.success)

                Button {
                    hoiThoat = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Thoát bài luyện")
            }

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(AppColors.primary)
                        .frame(width: g.size.width * tiLe)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private var tiLe: CGFloat {
        guard !cauHoi.isEmpty else { return 0 }
        return CGFloat(viTri) / CGFloat(cauHoi.count)
    }

    /// Chặng báo kết quả. Khoá một lần mỗi câu — chặng Tìm cặp gọi lúc ghép
    /// xong, nếu người dùng chạm thêm thì không được cộng điểm lần hai.
    private func cham(_ dung: Bool) {
        guard !daChamCau, let c = cau else { return }
        daChamCau = true
        ketQua.append(KetQuaCau(chang: c.chang, dung: dung))
    }

    private func tiep() {
        daChamCau = false
        withAnimation(.easeOut(duration: 0.2)) { viTri += 1 }
    }
}

// MARK: - Kết quả

struct KetQuaLuyenChuView: View {
    let ketQua: [KetQuaCau]
    let khiLamLai: () -> Void
    let khiDong: () -> Void

    private var dung: Int { ketQua.filter(\.dung).count }
    private var tong: Int { ketQua.count }
    private var phanTram: Int { tong == 0 ? 0 : Int((Double(dung) / Double(tong) * 100).rounded()) }

    private var loiKhen: String {
        switch phanTram {
        case 90...: return "Xuất sắc!"
        case 70..<90: return "Tốt lắm!"
        case 50..<70: return "Khá rồi — luyện thêm chút nữa."
        default: return "Cần ôn lại bộ chữ này."
        }
    }

    private var theoChang: [(ChangLuyen, Int, Int)] {
        ChangLuyen.allCases.compactMap { c in
            let ds = ketQua.filter { $0.chang == c }
            guard !ds.isEmpty else { return nil }
            return (c, ds.filter(\.dung).count, ds.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: phanTram >= 70 ? "trophy.fill" : "arrow.clockwise.circle")
                        .font(.system(size: 52))
                        .foregroundColor(phanTram >= 70 ? AppColors.warning : AppColors.primary)
                    Text("\(dung)/\(tong)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(phanTram)% · \(loiKhen)")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                VStack(spacing: Spacing.sm) {
                    ForEach(theoChang, id: \.0) { c, d, t in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: c.bieuTuong)
                                .font(.system(size: 14))
                                .foregroundColor(c.mau)
                                .frame(width: 26)
                            Text(c.ten)
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer(minLength: Spacing.sm)
                            Text("\(d)/\(t)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(d == t ? AppColors.success : AppColors.textSecondary)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundCard))
                    }
                }

                VStack(spacing: Spacing.sm) {
                    Button(action: khiLamLai) {
                        Label("Luyện tiếp", systemImage: "arrow.clockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(AppColors.primary))
                    }
                    .buttonStyle(.plain)

                    Button(action: khiDong) {
                        Text("Đổi cài đặt")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}
