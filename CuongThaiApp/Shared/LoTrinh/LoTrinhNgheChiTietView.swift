import SwiftUI

@MainActor
final class LoTrinhNgheChiTietVM: ObservableObject {
    @Published var lt: LoTrinhChiTietNghe?
    @Published var daXong: Set<Int> = []
    @Published var dangTai = true
    @Published var loi: String?
    /// Nút đang gửi lên máy chủ — chặn bấm liên tục một nút.
    @Published var dangGui: Set<Int> = []

    func nap(_ slug: String) async {
        dangTai = true; defer { dangTai = false }
        do {
            let d: LoTrinhChiTietNghe = try await APIClient.shared.request(.loTrinhNghe(slug: slug))
            lt = d
            daXong = d.daXong
            loi = d.cacChang.isEmpty ? T("Lộ trình này chưa có bước nào.") : nil
        } catch { loi = error.localizedDescription }
    }

    /// Đánh dấu xong/chưa xong.
    ///
    /// ⚠️ Lật ở giao diện TRƯỚC rồi mới gọi máy chủ, và trả lại nếu hỏng.
    /// Đợi mạng mới đổi dấu tick thì trên 4G có thể mất cả giây — người dùng
    /// bấm lại lần nữa và thành ra lật hai lần.
    func doiXong(_ id: Int) async {
        guard !dangGui.contains(id) else { return }
        dangGui.insert(id); defer { dangGui.remove(id) }
        let truoc = daXong
        if daXong.contains(id) { daXong.remove(id) } else { daXong.insert(id) }
        do {
            let _: DapAnRongLoTrinh = try await APIClient.shared.request(.danhDauNutLoTrinhNghe(nodeId: id))
        } catch {
            daXong = truoc
            loi = T("Chưa lưu được. Đăng nhập rồi thử lại.")
        }
    }
}

/// Máy chủ trả `{ success, data }` mà `data` có thể rỗng — chỉ cần biết là
/// không ném lỗi.
struct DapAnRongLoTrinh: Codable {}

struct LoTrinhNgheChiTietView: View {
    let tom: LoTrinhNgheTom
    @StateObject private var vm = LoTrinhNgheChiTietVM()
    @State private var moChang: Set<Int> = [0]
    @State private var chiConThieu = false
    @State private var moBuocTiep = false
    /// Lộ trình đã lên tới ~280 bước / 8-13 chặng. Không có ô tìm thì muốn
    /// xem một chủ đề phải xổ từng chặng ra mò bằng mắt.
    @State private var tim = ""
    @FocusState private var dangGoTim: Bool

    private var mau: Color { vm.lt?.mau ?? tom.mau }

    /// Bước CHƯA học đầu tiên, theo đúng thứ tự chặng → thứ tự trong chặng.
    ///
    /// Lộ trình dài tới 87 bước và mở ra là 22 chặng đóng — không có cái này
    /// thì mỗi lần vào lại phải tự nhớ hôm qua học tới đâu rồi xổ từng chặng
    /// đi tìm.
    private var buocTiep: NutLoTrinhNghe? {
        for c in (vm.lt?.cacChang ?? []).sorted(by: { $0.stage < $1.stage }) {
            for n in c.cacNut.sorted(by: { ($0.order ?? 0) < ($1.order ?? 0) })
            where !vm.daXong.contains(n.id) { return n }
        }
        return nil
    }
    private var khoaTim: String {
        tim.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Lọc theo tiêu đề + phụ đề + mô tả, bỏ dấu để gõ không dấu vẫn ra.
    private func khop(_ n: NutLoTrinhNghe) -> Bool {
        guard !khoaTim.isEmpty else { return true }
        let kho = [n.title, n.subtitle ?? "", n.description ?? ""].joined(separator: " ")
        return boDau(kho).contains(boDau(khoaTim))
    }

    private func boDau(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
    }

    private var soKhop: Int {
        (vm.lt?.cacChang ?? []).reduce(0) { $0 + $1.cacNut.filter(khop).count }
    }

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
            TextField("Tìm trong \(tong) bước…", text: $tim)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($dangGoTim)
            if !tim.isEmpty {
                Button {
                    tim = ""
                    dangGoTim = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(dangGoTim ? mau.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private var tong: Int { vm.lt?.tongNut ?? tom.soNut }
    private var xong: Int { vm.daXong.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                dauTrang
                if vm.dangTai && vm.lt == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if let l = vm.lt {
                    oTim
                    if !khoaTim.isEmpty && soKhop == 0 {
                        Text("Không có bước nào khớp “\(tim.trimmingCharacters(in: .whitespaces))”")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.lg)
                    }
                    ForEach(l.cacChang) { c in chang(c) }
                }
                if let e = vm.loi, vm.lt == nil {
                    Text(e).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(tom.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.nap(tom.slug) }
    }

    // MARK: Đầu trang

    private var dauTrang: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Image(systemName: tom.bieuTuong)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: [mau, mau.opacity(0.65)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tom.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(xong)/\(tong) \(T("bước"))")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(mau)
                }
                Spacer(minLength: 0)
            }
            if let d = vm.lt?.description ?? tom.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(mau)
                        .frame(width: g.size.width * (tong > 0 ? Double(xong) / Double(tong) : 0))
                }
            }
            .frame(height: 6)

            if let b = buocTiep {
                Button { moBuocTiep = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: xong == 0 ? "play.fill" : "arrow.turn.down.right")
                            .font(.system(size: 13, weight: .bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(xong == 0 ? T("Bắt đầu học") : T("Tiếp tục"))
                                .font(.system(size: 11, weight: .bold))
                                .opacity(0.85)
                            Text(b.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold)).opacity(0.7)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(mau))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $moBuocTiep) {
                    ChiTietNutLoTrinhView(nut: b, mau: mau, daXong: false) {
                        Task { await vm.doiXong(b.id) }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }

            HStack(spacing: Spacing.sm) {
                Toggle(isOn: $chiConThieu) {
                    Text(T("Chỉ hiện bước chưa xong"))
                        .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(mau)
            }
            .padding(.top, 2)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    // MARK: Một chặng

    @ViewBuilder private func chang(_ c: ChangLoTrinhNghe) -> some View {
        let loc = chiConThieu ? c.cacNut.filter { !vm.daXong.contains($0.id) } : c.cacNut
        let nut = loc.filter(khop)
        if !nut.isEmpty {
            // Đang tìm thì chặng nào có kết quả tự mở — không bắt người dùng
            // bấm thêm một nhịp nữa mới thấy thứ vừa tìm ra.
            let mo = !khoaTim.isEmpty || moChang.contains(c.stage)
            let xongChang = c.cacNut.filter { vm.daXong.contains($0.id) }.count
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    guard khoaTim.isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if mo { moChang.remove(c.stage) } else { moChang.insert(c.stage) }
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text("\(c.stage + 1)")
                            .font(.system(size: 11, weight: .heavy).monospacedDigit())
                            .foregroundColor(xongChang == c.cacNut.count ? .white : mau)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(xongChang == c.cacNut.count
                                                      ? mau : mau.opacity(0.16)))
                        Text(c.nhan)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text(khoaTim.isEmpty ? "\(xongChang)/\(c.cacNut.count)" : "\(nut.count) khớp")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(AppColors.textTertiary)
                        Image(systemName: khoaTim.isEmpty ? (mo ? "chevron.up" : "chevron.down") : "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(Spacing.md)
                }
                .buttonStyle(.plain)

                if mo {
                    VStack(spacing: Spacing.sm) {
                        ForEach(nut) { n in NutNgheView(nut: n, mau: mau, vm: vm) }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                }
            }
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }
}

// MARK: - Một bước

private struct NutNgheView: View {
    let nut: NutLoTrinhNghe
    let mau: Color
    @ObservedObject var vm: LoTrinhNgheChiTietVM
    @State private var moChiTiet = false

    private var xong: Bool { vm.daXong.contains(nut.id) }

    /// Bước này dẫn được tới chỗ học thật không (Code Lab / lộ trình khác /
    /// tài liệu ngoài). Đo thật: 56/225 bước có — một phần tư lộ trình.
    private var coLienKet: Bool {
        !(nut.linkRef ?? "").isEmpty && !(nut.linkType ?? "").isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Ô tick đứng RIÊNG: chạm nó là đánh dấu, chạm chỗ khác là mở chi
            // tiết. Gộp làm một thì không đánh dấu nhanh được, mà tách ra rồi
            // vẫn phải để nó đủ to để không bấm trượt sang mở tấm.
            Button { Task { await vm.doiXong(nut.id) } } label: {
                Image(systemName: xong ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(xong ? mau : AppColors.textTertiary.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ⚠️ CẢ HÀNG mở tấm chi tiết. Bản trước giấu nội dung sau một mũi
            // tên rộng 10pt ở mép phải, chạm vào tên bước thì không có gì xảy
            // ra — người dùng báo đúng thế: "ấn vào không thấy nội dung gì".
            Button { moChiTiet = true } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: nut.bieuTuong)
                            .font(.system(size: 11)).foregroundColor(mau.opacity(0.85))
                        Text(nut.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(xong ? AppColors.textTertiary : AppColors.textPrimary)
                            .strikethrough(xong, color: AppColors.textTertiary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    if let s = nut.subtitle, !s.isEmpty {
                        Text(s).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 5) {
                        Text(nut.nhanLoai)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(nhanMau)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Capsule().fill(nhanMau.opacity(0.15)))
                        // Huy hiệu "Học ngay" — dấu hiệu DUY NHẤT cho biết
                        // bước này dẫn vào bài học thật, nhìn từ ngoài danh
                        // sách. Không có nó thì phải mở từng bước mới biết.
                        if coLienKet {
                            Label(nhanLienKet, systemImage: bieuTuongLienKet)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1.5)
                                .background(Capsule().fill(mau))
                        }
                        if !nut.cacTaiNguyen.isEmpty {
                            Text("\(nut.cacTaiNguyen.count) \(T("tài nguyên"))")
                                .font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundTertiary.opacity(xong ? 0.35 : 0.7)))
        .sheet(isPresented: $moChiTiet) {
            ChiTietNutLoTrinhView(nut: nut, mau: mau, daXong: xong) {
                Task { await vm.doiXong(nut.id) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var nhanLienKet: String {
        switch (nut.linkType ?? "").lowercased() {
        case "code-lab": return T("Học ngay")
        case "roadmap":  return T("Lộ trình")
        default:         return T("Tài liệu")
        }
    }
    private var bieuTuongLienKet: String {
        switch (nut.linkType ?? "").lowercased() {
        case "code-lab": return "play.fill"
        case "roadmap":  return "map.fill"
        default:         return "arrow.up.right"
        }
    }

    private var nhanMau: Color {
        switch nut.loai {
        case .chinh: return mau
        case .thayThe: return AppColors.textSecondary
        case .thongTin: return AppColors.textTertiary
        }
    }
}
