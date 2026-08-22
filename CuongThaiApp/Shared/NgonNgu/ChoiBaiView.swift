import SwiftUI

// MARK: - Chơi một bài luyện tập

@MainActor
final class ChoiBaiVM: ObservableObject {
    @Published var cauHoi: [CauHoi] = []
    @Published var viTri = 0
    @Published var daChon: String?
    @Published var dangTai = true
    @Published var loi: String?
    @Published var ketQua: KetQuaBai?
    @Published var dangNop = false

    private(set) var idDung: [Int] = []
    private(set) var idSai: [Int] = []
    private(set) var soDung = 0
    private(set) var soSai = 0

    /// 10 câu mỗi bài. Chủ đề ở đây có tới 220 từ — hỏi hết thì không ai chơi
    /// xong, mà XP lại tính theo số câu ĐÚNG nên bài dài không hề "lời" hơn.
    private let soCau = 10

    var cauHienTai: CauHoi? { viTri < cauHoi.count ? cauHoi[viTri] : nil }
    var xong: Bool { viTri >= cauHoi.count }
    var tienDo: Double { cauHoi.isEmpty ? 0 : Double(viTri) / Double(cauHoi.count) }

    func tai(code: String, chuDe: Int) async {
        dangTai = true; defer { dangTai = false }
        do {
            // Lấy rộng hơn số câu cần: cần từ dư để làm phương án nhiễu, và
            // từ không có nghĩa tiếng Việt sẽ bị loại bớt.
            let tu: [TuNgoaiNgu] = try await APIClient.shared.request(
                .tuVung(code: code, categoryId: chuDe, page: 1, limit: 60))
            cauHoi = CauHoi.dung(tu: tu, soCau: soCau)
            if cauHoi.isEmpty {
                loi = tu.count < 4
                    ? "Chủ đề này chưa đủ từ để luyện tập."
                    : "Chủ đề này thiếu nghĩa tiếng Việt nên chưa dựng được câu hỏi."
            }
        } catch {
            loi = error.localizedDescription
        }
    }

    func chon(_ dapAn: String) {
        guard daChon == nil, let c = cauHienTai else { return }
        daChon = dapAn
        if dapAn == c.dapAn { soDung += 1; idDung.append(c.id) }
        else { soSai += 1; idSai.append(c.id) }
    }

    func tiep() {
        daChon = nil
        viTri += 1
    }

    func nop(code: String, lessonKey: String) async {
        guard !dangNop, ketQua == nil else { return }
        dangNop = true; defer { dangNop = false }
        do {
            ketQua = try await APIClient.shared.request(
                .nopBaiLuyen(code: code, lessonKey: lessonKey, dung: soDung,
                             tong: cauHoi.count, sai: soSai,
                             idSai: idSai, idDung: idDung))
        } catch {
            loi = "Không gửi được kết quả: \(error.localizedDescription)"
        }
    }
}

struct ChoiBaiView: View {
    let ngonNgu: NgonNgu
    let bai: BaiLuyen
    /// Gọi khi bài kết thúc để màn trước nạp lại trạng thái từ máy chủ.
    var khiXong: (() -> Void)?

    @StateObject private var vm = ChoiBaiVM()
    @ObservedObject private var doc = DocTu.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if vm.dangTai {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let l = vm.loi, vm.cauHoi.isEmpty {
                thongBaoLoi(l)
            } else if vm.xong {
                manKetThuc
            } else if let c = vm.cauHienTai {
                manCauHoi(c)
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(bai.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.tai(code: ngonNgu.code, chuDe: bai.categoryId) }
    }

    private func thongBaoLoi(_ l: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray").font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)
            Text(l)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Quay lại") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Câu hỏi

    private func manCauHoi(_ c: CauHoi) -> some View {
        VStack(spacing: Spacing.lg) {
            thanhTren

            VStack(spacing: Spacing.sm) {
                Text(c.nhac)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: Spacing.sm) {
                    Text(c.deBai)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    // Chỉ hiện loa khi máy CÓ giọng của thứ tiếng đó. Có mã
                    // giọng không nghĩa là gói giọng đã tải về — bấm vào mà
                    // im lặng hoàn toàn thì người dùng tưởng app hỏng.
                    if c.chieu == .tuSangNghia, DocTu.doDuoc(ngonNgu.code) {
                        Button {
                            doc.doc(c.tu.word, code: ngonNgu.code, id: c.tu.id)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 19))
                                .foregroundColor(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Phiên âm chỉ lộ SAU khi chọn — thấy "ohayou" là đọc được
                // ngay, mà đọc được thì phép đo "có thuộc không" mất nghĩa.
                if vm.daChon != nil, c.chieu == .tuSangNghia, let pa = c.tu.phienAm {
                    Text(pa)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)

            VStack(spacing: Spacing.sm) {
                ForEach(c.luaChon, id: \.self) { lc in
                    nutChon(lc, dapAn: c.dapAn)
                }
            }

            Spacer(minLength: 0)

            if vm.daChon != nil {
                Button {
                    vm.tiep()
                } label: {
                    Text(vm.viTri == vm.cauHoi.count - 1 ? "Xem kết quả" : "Tiếp tục")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(AppColors.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
    }

    private var thanhTren: some View {
        HStack(spacing: Spacing.md) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(AppColors.success)
                        .frame(width: g.size.width * vm.tienDo)
                }
            }
            .frame(height: 10)

            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("\(vm.soDung)")
                    .foregroundColor(AppColors.textPrimary)
            }
            .font(.system(size: 13, weight: .bold))
        }
    }

    private func nutChon(_ lc: String, dapAn: String) -> some View {
        let daChon = vm.daChon
        let laDapAn = lc == dapAn
        // Sau khi chọn: đáp án đúng LUÔN sáng lên, kể cả khi người ta chọn
        // sai — chọn sai mà không thấy đáp án đúng thì không học được gì.
        let mau: Color = daChon == nil ? AppColors.border
            : (laDapAn ? AppColors.success : (lc == daChon ? AppColors.error : AppColors.border))
        let nen: Color = daChon == nil ? AppColors.backgroundCard
            : (laDapAn ? AppColors.success.opacity(0.14)
               : (lc == daChon ? AppColors.error.opacity(0.14) : AppColors.backgroundCard))

        return Button {
            vm.chon(lc)
        } label: {
            HStack {
                Text(lc)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.sm)
                if daChon != nil, laDapAn {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.success)
                } else if daChon == lc {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.error)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(nen))
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(mau, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(daChon != nil)
    }

    // MARK: Kết thúc

    private var manKetThuc: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            if vm.dangNop {
                ProgressView()
                Text("Đang lưu kết quả…")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            } else if let kq = vm.ketQua {
                Image(systemName: kq.leveledUp ? "crown.fill" : "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: kq.leveledUp ? 0xD97706 : 0x2BA84A))

                Text(kq.leveledUp ? "Thêm một vương miện!" : "Xong bài!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("Đúng \(vm.soDung)/\(vm.cauHoi.count)")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: Spacing.lg) {
                    oSo("+\(kq.xpGained)", "XP", 0xF59E0B)
                    oSo("\(kq.crown)/5", "vương miện", 0xD97706)
                    oSo("\(kq.state.streak)", "ngày liên tiếp", 0xE5484D)
                }

                if kq.state.datMucTieu {
                    Text("Đạt mục tiêu hôm nay — tim đã đầy lại.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.success)
                        .multilineTextAlignment(.center)
                }
            } else if let l = vm.loi {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40)).foregroundColor(AppColors.warning)
                Text(l)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                khiXong?()
                dismiss()
            } label: {
                Text("Xong")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .task { await vm.nop(code: ngonNgu.code, lessonKey: bai.lessonKey) }
    }

    private func oSo(_ so: String, _ nhan: String, _ mau: UInt32) -> some View {
        VStack(spacing: 2) {
            Text(so)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(Color(hex: mau))
            Text(nhan)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
        }
    }
}
