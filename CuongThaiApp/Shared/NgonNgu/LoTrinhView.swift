import SwiftUI

// MARK: - Bộ nạp

@MainActor
final class LoTrinhVM: ObservableObject {
    @Published var chang: [ChangLoTrinh] = []
    @Published var xong: Set<Int> = []
    @Published var tong = 0
    @Published var dangTai = false
    @Published var loi: String?
    /// Mã chủ đề → chủ đề. Chỉ nút `vocab` mới cần, để mở đúng chủ đề thay vì
    /// đổ người học vào danh sách từ vựng chung.
    @Published var chuDe: [Int: ChuDeTu] = [:]

    func tai(_ code: String) async {
        dangTai = true; defer { dangTai = false }
        do {
            let lt: LoTrinh = try await APIClient.shared.request(.loTrinh(code: code))
            chang = lt.stages
            xong = Set(lt.doneNodeIds)
            tong = lt.total
            loi = chang.isEmpty ? "Ngôn ngữ này chưa có lộ trình." : nil
        } catch {
            loi = error.localizedDescription
        }
        // Chủ đề tải RIÊNG và không chặn lộ trình: thiếu nó thì nút từ vựng
        // mở vào danh sách chung, vẫn dùng được — còn để nó làm hỏng cả màn
        // thì mất luôn 111 nút vì một lời gọi phụ.
        if chuDe.isEmpty, let ds: [ChuDeTu] = try? await APIClient.shared.request(.chuDeTu(code: code)) {
            chuDe = Dictionary(uniqueKeysWithValues: ds.map { ($0.id, $0) })
        }
    }

    var soXong: Int { xong.count }

    func doiXong(_ nut: NutLoTrinh) async {
        // Đổi trước, gọi mạng sau: bấm xong phải thấy đổi ngay. Hỏng thì trả
        // lại đúng trạng thái cũ chứ không để nó nói dối là đã lưu.
        let truoc = xong
        if xong.contains(nut.id) { xong.remove(nut.id) } else { xong.insert(nut.id) }
        struct KetQua: Codable { let nodeId: Int; let done: Bool }
        do {
            let kq: KetQua = try await APIClient.shared.request(.doiNutLoTrinh(nodeId: nut.id))
            if kq.done { xong.insert(kq.nodeId) } else { xong.remove(kq.nodeId) }
        } catch {
            xong = truoc
            loi = "Không lưu được trạng thái. Kiểm tra kết nối rồi thử lại."
        }
    }
}

// MARK: - Bố cục

/// Một dòng trên đường đi: hoặc là đầu chặng, hoặc là một nút.
private enum MucLoTrinh: Identifiable {
    case chang(ChangLoTrinh)
    case nut(NutLoTrinh)

    var id: String {
        switch self {
        case .chang(let c): return "c\(c.stage)"
        case .nut(let n): return "n\(n.id)"
        }
    }

    /// Chiều cao CỐ ĐỊNH của dòng.
    ///
    /// Cố định là có chủ đích: biết trước chiều cao thì tính được toạ độ tâm
    /// của từng nút, nhờ đó vẽ được đường nối chính xác bằng một `Path` duy
    /// nhất. Đo chiều cao thật qua `PreferenceKey` thì đường nối luôn chậm
    /// một nhịp so với nút, và lúc cuộn nhanh sẽ thấy nó giật.
    var cao: CGFloat {
        switch self {
        case .chang: return 74
        case .nut(let n): return n.loai == .ghiChu ? 96 : 118
        }
    }
}

// MARK: - Màn hình

struct LoTrinhView: View {
    /// ⚠️ Dùng `ngonNgu` truyền vào từ màn trước, KHÔNG dùng `language` trong
    /// payload lộ trình — cái đó không mang `counts`, mà các màn đích lại dựa
    /// vào `counts` để ẩn/hiện mục.
    let ngonNgu: NgonNgu
    @StateObject private var vm = LoTrinhVM()

    private var muc: [MucLoTrinh] {
        vm.chang.flatMap { [MucLoTrinh.chang($0)] + $0.nodes.map { MucLoTrinh.nut($0) } }
    }

    /// Toạ độ tâm theo trục dọc của từng dòng.
    private var boCuc: [(muc: MucLoTrinh, y: CGFloat)] {
        var y: CGFloat = 0
        return muc.map { m in
            defer { y += m.cao }
            return (m, y + m.cao / 2)
        }
    }

    private var tongCao: CGFloat { muc.reduce(Spacing.xl) { $0 + $1.cao } }

    var body: some View {
        Group {
            if vm.dangTai && vm.chang.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.chang.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "map").font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text(vm.loi ?? "Chưa có lộ trình.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                duongDi
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Lộ trình")
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.chang.isEmpty { await vm.tai(ngonNgu.code) } }
    }

    private var duongDi: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    thanhTienDo
                    ZStack(alignment: .topLeading) {
                        duongNoi(geo.size.width)
                        ForEach(boCuc, id: \.muc.id) { m, y in
                            veMuc(m, geo.size.width)
                                .position(x: viTriX(m, geo.size.width), y: y)
                        }
                    }
                    .frame(width: geo.size.width, height: tongCao)
                }
            }
        }
    }

    private func viTriX(_ m: MucLoTrinh, _ w: CGFloat) -> CGFloat {
        switch m {
        case .chang: return w / 2
        case .nut(let n): return n.loai == .ghiChu ? w / 2 : w * n.cot.tiLe
        }
    }

    // MARK: Thanh tiến độ

    private var thanhTienDo: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text("\(vm.soXong)/\(vm.tong) chặng")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(vm.tong > 0 ? vm.soXong * 100 / vm.tong : 0)%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.primary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(AppColors.primary)
                        .frame(width: g.size.width * CGFloat(vm.tong > 0 ? Double(vm.soXong) / Double(vm.tong) : 0))
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Đường nối

    /// Vệt chấm nối các nút TRONG CÙNG một chặng.
    ///
    /// Sang chặng mới thì ngắt: giữa hai chặng có dải tiêu đề, kéo vệt xuyên
    /// qua chữ trông như gạch ngang chữ.
    private func duongNoi(_ w: CGFloat) -> some View {
        Path { p in
            var truoc: CGPoint?
            for (m, y) in boCuc {
                switch m {
                case .chang:
                    truoc = nil
                case .nut(let n):
                    guard n.loai != .ghiChu else { truoc = nil; continue }
                    let d = n.loai.duongKinh
                    let tam = CGPoint(x: w * n.cot.tiLe, y: y)
                    if let t = truoc {
                        p.move(to: CGPoint(x: t.x, y: t.y + d / 2 - 4))
                        p.addLine(to: CGPoint(x: tam.x, y: tam.y - d / 2 + 4))
                    }
                    truoc = tam
                }
            }
        }
        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 11]))
        .foregroundColor(AppColors.textTertiary.opacity(0.55))
    }

    // MARK: Vẽ từng dòng

    @ViewBuilder
    private func veMuc(_ m: MucLoTrinh, _ w: CGFloat) -> some View {
        switch m {
        case .chang(let c):
            dauChang(c)
        case .nut(let n):
            if n.loai == .ghiChu {
                theGhiChu(n, w)
            } else {
                NavigationLink {
                    NutLoTrinhChiTietView(ngonNgu: ngonNgu, nut: n, vm: vm)
                } label: {
                    vongTron(n)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dauChang(_ c: ChangLoTrinh) -> some View {
        let soXong = c.nodes.filter { vm.xong.contains($0.id) }.count
        return VStack(spacing: 2) {
            Text(c.stageLabel.uppercased())
                .font(.system(size: 12, weight: .black))
                .kerning(0.8)
                .foregroundColor(AppColors.onPrimary)
            Text("\(soXong)/\(c.nodes.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.onPrimary.opacity(0.85))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Color(hex: 0x0E93A6), Color(hex: 0x21D4ED)],
                               startPoint: .leading, endPoint: .trailing)
            )
        )
    }

    private func vongTron(_ n: NutLoTrinh) -> some View {
        let d = n.loai.duongKinh
        let mau = Color(hex: n.mau)
        let daXong = vm.xong.contains(n.id)
        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(daXong ? mau : AppColors.backgroundCard)
                    .frame(width: d, height: d)
                    .overlay(
                        Circle().strokeBorder(
                            mau.opacity(daXong ? 0 : 0.85),
                            style: StrokeStyle(lineWidth: 3,
                                               dash: n.loai == .phu ? [5, 4] : [])
                        )
                    )
                    .shadow(color: mau.opacity(daXong ? 0.35 : 0), radius: 8, y: 3)

                Image(systemName: n.bieuTuong)
                    .font(.system(size: d * 0.36, weight: .semibold))
                    .foregroundColor(daXong ? AppColors.onPrimary : mau)

                if daXong {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.onPrimary, AppColors.success)
                        .offset(x: d * 0.36, y: d * 0.36)
                }
            }
            Text(n.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 124)
        }
    }

    /// ⚠️ Bề ngang phải CO theo màn hình. Đặt cứng 320pt thì iPhone SE (375pt)
    /// chỉ còn 27pt lề mỗi bên, và ở bất kỳ khung nào hẹp hơn 320pt là chữ bị
    /// cắt im lặng — `.position()` không kẹp con vào trong cha.
    private func theGhiChu(_ n: NutLoTrinh, _ w: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: 0xD97706))
            VStack(alignment: .leading, spacing: 3) {
                Text(n.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                if let d = n.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm + 2)
        .frame(width: min(340, w - Spacing.lg * 2), alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color(hex: 0xD97706).opacity(0.12))
        )
    }
}

// MARK: - Chi tiết một nút

struct NutLoTrinhChiTietView: View {
    let ngonNgu: NgonNgu
    let nut: NutLoTrinh
    @ObservedObject var vm: LoTrinhVM

    private var daXong: Bool { vm.xong.contains(nut.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                dauTrang

                if let d = nut.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let nd = nut.noiDung {
                    if nd.coManHinh {
                        NavigationLink { manDich(nd) } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Học \(nd.ten.lowercased())")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(AppColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.large)
                                    .fill(Color(hex: nut.mau))
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Nói thẳng là chưa có, thay vì đẩy người học vào một
                        // màn hình trống rồi để họ tưởng app hỏng.
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: "hourglass")
                            Text("Phần \(nd.ten.lowercased()) chưa có trong app. Mục này đã có trên web.")
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundColor(AppColors.textTertiary)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundSecondary)
                        )
                    }
                }

                Button {
                    Task { await vm.doiXong(nut) }
                } label: {
                    HStack {
                        Image(systemName: daXong ? "checkmark.circle.fill" : "circle")
                        Text(daXong ? "Đã học xong" : "Đánh dấu đã học")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(daXong ? AppColors.success : AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .strokeBorder(daXong ? AppColors.success : AppColors.border, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: Spacing.xl)
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(nut.stageLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dauTrang: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: nut.mau).opacity(0.15))
                    .frame(width: 62, height: 62)
                Image(systemName: nut.bieuTuong)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(hex: nut.mau))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(nut.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let s = nut.subtitle, !s.isEmpty {
                    Text(s)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                HStack(spacing: Spacing.xs) {
                    if let lv = nut.level, !lv.isEmpty { nhan(lv, AppColors.primary) }
                    if nut.loai == .phu { nhan("Học thêm", AppColors.textTertiary) }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func nhan(_ chu: String, _ mau: Color) -> some View {
        Text(chu)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(mau)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(Capsule().fill(mau.opacity(0.15)))
    }

    /// Nút `vocab` mang theo mã chủ đề nên mở được ĐÚNG chủ đề. Tám loại còn
    /// lại `linkRef` đều null, chỉ mở được danh sách chung của loại đó.
    @ViewBuilder
    private func manDich(_ nd: LoaiNoiDung) -> some View {
        switch nd {
        case .bangChu: BangChuView(ngonNgu: ngonNgu)
        case .nguPhap: NguPhapView(ngonNgu: ngonNgu)
        case .hoiThoai: HoiThoaiView(ngonNgu: ngonNgu)
        case .baiDoc: BaiDocView(ngonNgu: ngonNgu)
        case .hoiDap: HoiDapView(ngonNgu: ngonNgu)
        case .dongVai: ChonChuDeNoiView(ngonNgu: ngonNgu)
        case .tuVung:
            if let ma = nut.maChuDe, let cd = vm.chuDe[ma] {
                TuNgoaiNguView(ngonNgu: ngonNgu, chuDe: cd)
            } else {
                ChuDeTheoCapView(ngonNgu: ngonNgu, cap: nut.level, tenNut: nut.title, vm: vm)
            }
        case .nghe, .tapViet, .ngoai:
            EmptyView()
        }
    }
}


// MARK: - Chủ đề theo cấp

/// Màn rơi về cho nút từ vựng KHÔNG có mã chủ đề.
///
/// Đo thật 22/08/2026: chỉ **6 trong 32** nút từ vựng mang `linkRef`, 26 nút
/// còn lại để trống (admin có công cụ `roadmap/auto-assign` nhưng chưa chạy
/// hết). Trước đó tôi cho rơi về `NgonNguHomeView` — sai, vì đó chính là màn
/// vừa đi ra, người dùng bấm "học từ vựng" rồi thấy mình quay về chỗ cũ.
///
/// May là **30/32 nút có `level`**, và cấp đó trùng khít với cấp của chủ đề
/// (A1–C2 · N1–N5 · HSK1–HSK6). Nên lọc theo cấp là mở đúng vùng cần học,
/// giữa 278–346 chủ đề mỗi thứ tiếng.
struct ChuDeTheoCapView: View {
    let ngonNgu: NgonNgu
    let cap: String?
    let tenNut: String
    @ObservedObject var vm: LoTrinhVM

    private var ds: [ChuDeTu] {
        let tatCa = vm.chuDe.values.sorted { ($0.order ?? 999) < ($1.order ?? 999) }
        guard let cap else { return tatCa }
        let loc = tatCa.filter { $0.level == cap }
        // Cấp không khớp chủ đề nào thì hiện TẤT CẢ còn hơn một màn trắng.
        return loc.isEmpty ? tatCa : loc
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if let cap, !cap.isEmpty {
                    Text("Chủ đề trình độ \(cap) — \(ds.count) mục")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Spacing.xs)
                }
                ForEach(ds) { c in
                    NavigationLink(destination: TuNgoaiNguView(ngonNgu: ngonNgu, chuDe: c)) {
                        HangChuDe(c: c)
                    }
                    .buttonStyle(.plain)
                }
                if ds.isEmpty {
                    Text("Chưa có chủ đề nào cho phần này.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, Spacing.xl)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(tenNut)
        .navigationBarTitleDisplayMode(.inline)
        .task { if vm.chuDe.isEmpty { await vm.tai(ngonNgu.code) } }
    }
}
