#if os(iOS)
import PencilKit
import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// ✍️ AI VIẾT LẠI TRANG — cửa sổ chờ → xem trước → Hoàn tác / Lưu
//
// ⚠️ Cửa sổ này KHÔNG đụng vào vở cho tới khi bấm "Lưu" — cùng luật với
// "Làm gọn chữ": xem trước là ẢNH dựng riêng. "Hoàn tác / Bỏ" trước khi lưu
// là đóng cửa sổ, không có gì phải trả lại. Sau khi lưu, màn viết hiện dải
// "Hoàn tác" (xem `DaiHoanTacVietLai`).
// ════════════════════════════════════════════════════════════════

// MARK: - Trạng thái một lượt

@MainActor
final class MayVietLai: ObservableObject {
    enum Buoc: Int, CaseIterable {
        case docTrenMay, guiAnh, aiChep, dung
        var ten: String {
            switch self {
            case .docTrenMay: return T("Đọc chữ ngay trên iPad")
            case .guiAnh: return T("Gửi ảnh trang cho AI")
            case .aiChep: return T("AI chép sạch, sửa chính tả")
            case .dung: return T("Dựng bản chữ tay đẹp")
            }
        }
    }
    enum TrangThai {
        case chay(Buoc, batDau: Date)
        case xong(KetQuaVietLai, [TrangChuDep])
        case loi(String)
    }

    @Published private(set) var trangThai: TrangThai = .chay(.docTrenMay, batDau: Date())
    private var viec: Task<Void, Never>?

    var dangChay: Bool { if case .chay = trangThai { return true } else { return false } }

    struct DauVao {
        let net: PKDrawing
        let khoTrang: CGSize
        let giayGoc: LoaiGiay
        let khoDich: CGSize
        let giayDich: LoaiGiay
        let muc: UIColor
    }

    func chay(_ v: DauVao) {
        viec?.cancel()
        let batDau = Date()
        trangThai = .chay(.docTrenMay, batDau: batDau)
        viec = Task { [weak self] in
            // 1. Chữ Vision đọc trên máy — GỢI Ý cho model, không phải nguồn.
            let goiY = await DocChuViet.doc(net: v.net, khoTrang: v.khoTrang)
            guard let self, !Task.isCancelled else { return }
            self.trangThai = .chay(.guiAnh, batDau: batDau)
            guard let anh = VietLaiTrang.anhGui(v.net, khoTrang: v.khoTrang) else {
                self.trangThai = .loi(T("Trang này chưa có nét nào để viết lại."))
                return
            }
            NhatKy.vo.info("viết lại: gửi ảnh \(anh.count / 1024)KB · gợi ý \(goiY.count) ký tự")
            // Chuyển nhãn sang "AI chép" ngay khi đã gửi xong phần to nhất;
            // máy chủ trả một cục sau 20–90 giây, không có tiến độ thật.
            let doiNhan = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                if case .chay(.guiAnh, _) = self?.trangThai { self?.trangThai = .chay(.aiChep, batDau: batDau) }
            }
            do {
                let kq = try await VietLaiTrang.goi(anh: anh, goiY: goiY, giay: v.giayGoc)
                doiNhan.cancel()
                guard !Task.isCancelled else { return }
                self.trangThai = .chay(.dung, batDau: batDau)
                let trangs = DungChuDep.dan(kq.khoi ?? [], giay: v.giayDich, kho: v.khoDich, muc: v.muc)
                guard !trangs.isEmpty else {
                    self.trangThai = .loi(T("Không đọc ra chữ nào trên trang này."))
                    return
                }
                self.trangThai = .xong(kq, trangs)
                NhatKy.vo.info("viết lại: xong \(kq.khoi?.count ?? 0) khối → \(trangs.count) trang · \(kq.sua?.count ?? 0) chỗ sửa · \(Int(Date().timeIntervalSince(batDau)))s")
                Haptics.xong()
            } catch {
                doiNhan.cancel()
                guard !Task.isCancelled else { return }
                self.trangThai = .loi(VietLaiTrang.cauLoi(error))
                Haptics.hong()
            }
        }
    }

    /// Huỷ phía app. Máy chủ vẫn chạy nốt lượt đó — không có cách gọi nó dừng.
    func huy() { viec?.cancel(); viec = nil }

    #if DEBUG
    /// Bàn thử máy ảo — dựng trạng thái mà không gọi mạng.
    func gia(_ t: TrangThai) { viec?.cancel(); trangThai = t }
    #endif
}

// MARK: - Cửa sổ

struct VietLaiView: View {
    let goc: TrangVo
    let net: PKDrawing
    let muc: UIColor
    /// Trả `false` nếu không lưu được — cửa sổ ở lại, báo lỗi.
    let luu: (CachLuuVietLai, [TrangChuDep]) -> Bool

    @Environment(\.dismiss) private var dong
    @Environment(\.colorScheme) private var cheDoMau
    @StateObject private var may = MayVietLai()
    @AppStorage("vo.vietlai.cach") private var cachLuu: String = CachLuuVietLai.thayTrang.rawValue
    @State private var tab: Tab = .banDep
    @State private var anhDep: [UIImage] = []
    @State private var anhGoc: UIImage?
    @State private var loiLuu: String?

    enum Tab: Hashable { case banDep, sua, goc }

    private var khoDich: CGSize { LuuVietLai.khoDich(cho: goc) }
    private var giayDich: LoaiGiay { LuuVietLai.giayDich(cho: goc) }
    private var cach: CachLuuVietLai { CachLuuVietLai(rawValue: cachLuu) ?? .thayTrang }

    /// Màn đọc/viết tập trung ⇒ chủ đề mùa đứng yên khi màn này hiện (Shared/ChuDe).
    var body: some View { thanManYen.nenMuaYen() }

    @ViewBuilder private var thanManYen: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch may.trangThai {
                case .chay(let b, let batDau): manCho(b, batDau: batDau)
                case .loi(let s): manLoi(s)
                case .xong(let kq, let trangs): manKetQua(kq, trangs)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(nen)
            .navigationTitle(T("AI viết lại trang"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(may.dangChay ? T("Huỷ") : T("Đóng")) { may.huy(); dong() }
                }
            }
        }
        .modifier(CoTrangLon())
        .interactiveDismissDisabled(isXong)
        .task { batDau() }
        .onDisappear { may.huy() }
    }

    private var isXong: Bool { if case .xong = may.trangThai { return true } else { return false } }

    private var nen: some View {
        ZStack {
            AppColors.backgroundPrimary
            LinearGradient(colors: [AppColors.primary.opacity(cheDoMau == .dark ? 0.14 : 0.07), .clear],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.3))
        }
        .ignoresSafeArea()
    }

    private func batDau() {
        #if DEBUG
        // Bàn thử máy ảo: CT_VIETLAI=mau ⇒ dùng kết quả mẫu, không gọi mạng.
        if ProcessInfo.processInfo.environment["CT_VIETLAI"] == "mau", let giaLap = MauVietLai.ketQua {
            let tr = DungChuDep.dan(giaLap.khoi ?? [], giay: giayDich, kho: khoDich, muc: muc)
            may.gia(.xong(giaLap, tr))
            if let t = ProcessInfo.processInfo.environment["CT_VIETLAI_TAB"] {
                tab = t == "sua" ? .sua : t == "goc" ? .goc : .banDep
            }
            if ProcessInfo.processInfo.environment["CT_VIETLAI_CHO"] == "1" {
                may.gia(.chay(.aiChep, batDau: Date().addingTimeInterval(-17)))
            }
            return
        }
        #endif
        may.chay(.init(net: net, khoTrang: goc.khoTrang, giayGoc: goc.giay,
                       khoDich: khoDich, giayDich: giayDich, muc: muc))
    }

    // MARK: Chờ

    private func manCho(_ b: MayVietLai.Buoc, batDau: Date) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            LoiRobot(canh: 72, dangNghi: true)
            VStack(spacing: 6) {
                Text(T("Đang chép sạch trang của bạn"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(T("Thường mất 20–60 giây. Giữ nguyên ý — chỉ sửa chữ, dấu, viết hoa, ngắt câu."))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(MayVietLai.Buoc.allCases, id: \.rawValue) { buoc in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(buoc.rawValue < b.rawValue ? AppColors.success.opacity(0.16)
                                          : buoc == b ? AppColors.primary.opacity(0.16) : AppColors.border)
                                .frame(width: 26, height: 26)
                            if buoc.rawValue < b.rawValue {
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppColors.success)
                            } else if buoc == b {
                                ProgressView().controlSize(.mini)
                            }
                        }
                        Text(buoc.ten)
                            .font(.subheadline.weight(buoc == b ? .semibold : .regular))
                            .foregroundStyle(buoc.rawValue > b.rawValue ? AppColors.textTertiary : AppColors.textPrimary)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 420, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.backgroundCard.opacity(cheDoMau == .dark ? 0.7 : 0.9)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1))

            // Tiến độ ƯỚC LƯỢNG theo thời gian (máy chủ trả một cục, không có
            // tiến độ thật) — tiệm cận 95%, không bao giờ "đầy" khi chưa xong.
            TimelineView(.periodic(from: .now, by: 0.25)) { tl in
                let giay = tl.date.timeIntervalSince(batDau)
                let p = min(0.95, 1 - exp(-giay / 28))
                VStack(spacing: 6) {
                    ProgressView(value: p)
                        .tint(AppColors.primary)
                        .frame(maxWidth: 420)
                    Text("\(Int(giay))s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Button(role: .cancel) { may.huy(); dong() } label: {
                Label(T("Huỷ"), systemImage: "xmark")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.bordered)
            Spacer(minLength: 0)
        }
        .padding(24)
    }

    // MARK: Lỗi

    private func manLoi(_ s: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.warning)
            Text(s)
                .font(.body)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button(T("Đóng")) { dong() }.buttonStyle(.bordered)
                Button { batDau() } label: { Label(T("Thử lại"), systemImage: "arrow.clockwise") }
                    .buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
    }

    // MARK: Kết quả

    private func manKetQua(_ kq: KetQuaVietLai, _ trangs: [TrangChuDep]) -> some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text(T("Bản đẹp")).tag(Tab.banDep)
                Text("\(T("Chỗ AI đã sửa")) (\(kq.sua?.count ?? 0))").tag(Tab.sua)
                Text(T("Bản gốc")).tag(Tab.goc)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 460)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let cb = kq.canhBao, !cb.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cb, id: \.self) { c in
                        Label(c, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(AppColors.warning)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.warning.opacity(0.12)))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Group {
                switch tab {
                case .banDep: xemBanDep(trangs)
                case .sua: danhSachSua(kq)
                case .goc: xemGoc
                }
            }
            .frame(maxHeight: .infinity)

            thanhDuoi(kq, trangs)
        }
        .task(id: cheDoMau) { dungAnhXem(trangs) }
    }

    private func xemBanDep(_ trangs: [TrangChuDep]) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 18) {
                    if anhDep.isEmpty { ProgressView().frame(height: 240) }
                    ForEach(Array(anhDep.enumerated()), id: \.offset) { i, a in
                        VStack(spacing: 6) {
                            Image(uiImage: a)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: min(geo.size.width - 32, 760))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .shadow(color: .black.opacity(cheDoMau == .dark ? 0.5 : 0.14), radius: 10, y: 4)
                            if anhDep.count > 1 {
                                Text("\(T("Trang")) \(i + 1)/\(anhDep.count)")
                                    .font(.caption).foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    private func danhSachSua(_ kq: KetQuaVietLai) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if (kq.sua ?? []).isEmpty {
                    Text(T("AI không phải sửa chữ nào — chỉ xếp lại bố cục."))
                        .font(.subheadline).foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array((kq.sua ?? []).enumerated()), id: \.offset) { _, s in
                    HStack(alignment: .top, spacing: 12) {
                        Text(s.nhanLoai)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                            .frame(width: 84, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.truoc?.isEmpty == false ? s.truoc! : "—")
                                .strikethrough(true, color: AppColors.error.opacity(0.7))
                                .foregroundStyle(AppColors.error.opacity(0.9))
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
                                Text(s.sau ?? "")
                                    .foregroundStyle(AppColors.success)
                                    .fontWeight(.medium)
                            }
                        }
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.backgroundCard.opacity(cheDoMau == .dark ? 0.7 : 0.95)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColors.border, lineWidth: 1))
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                    Text(T("AI chỉ sửa chính tả, dấu, viết hoa, dấu câu và viết tắt — không thêm ý. Chỗ [?] là AI không đọc được chữ, bạn tự viết lại lên trang."))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.top, 6)
                HStack {
                    Spacer()
                    NutBaoCaoTraLoiAI(nguon: "AI · Vở viết lại trang",
                                      cauHoi: T("Viết lại trang vở"),
                                      traLoi: kq.chuThuan ?? "")
                }
            }
            .frame(maxWidth: 680)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }

    private var xemGoc: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 6) {
                    if let anhGoc {
                        Image(uiImage: anhGoc)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: min(geo.size.width - 32, 760))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                    } else {
                        ProgressView().frame(height: 240)
                    }
                    Text(T("Bản viết tay của bạn — không bị đổi, kể cả khi chọn “Thay trang này”."))
                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: Thanh dưới: cách lưu + Hoàn tác / Lưu

    private func thanhDuoi(_ kq: KetQuaVietLai, _ trangs: [TrangChuDep]) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                oChonCach(.thayTrang, icon: "arrow.left.arrow.right.square",
                          ten: T("Thay trang này"),
                          phu: T("Bản viết tay dời ngay sau, tên “(bản gốc)”"))
                oChonCach(.themSau, icon: "plus.rectangle.on.rectangle",
                          ten: T("Thêm trang mới ngay sau"),
                          phu: T("Trang viết tay giữ nguyên chỗ"))
            }
            if let loiLuu {
                Text(loiLuu).font(.caption).foregroundStyle(AppColors.error)
            }
            HStack(spacing: 12) {
                Button { dong() } label: {
                    Label(T("Hoàn tác / Bỏ"), systemImage: "arrow.uturn.backward")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.textSecondary)

                Button { bamLuu(trangs) } label: {
                    Label(trangs.count > 1 ? "\(T("Lưu")) · \(trangs.count) \(T("trang"))" : T("Lưu"),
                          systemImage: "checkmark")
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            }
            Text(T("Lưu xong vẫn hoàn tác được ngay trên màn viết. Bản đẹp đồng bộ, xuất PDF và tìm kiếm được như mọi trang."))
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 680)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func oChonCach(_ c: CachLuuVietLai, icon: String, ten: String, phu: String) -> some View {
        let chon = cach == c
        return Button {
            cachLuu = c.rawValue
            Haptics.cham()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: chon ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(chon ? AppColors.primary : AppColors.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Label(ten, systemImage: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .labelStyle(.titleOnly)
                    Text(phu)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(chon ? AppColors.primary.opacity(0.10) : AppColors.backgroundCard.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(chon ? AppColors.primary.opacity(0.55) : AppColors.border, lineWidth: chon ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(NhanThe())
        .accessibilityAddTraits(chon ? .isSelected : [])
    }

    private func bamLuu(_ trangs: [TrangChuDep]) {
        if luu(cach, trangs) {
            Haptics.xong()
            dong()
        } else {
            loiLuu = T("Chưa lưu được — trang đang mở đã đổi. Đóng cửa sổ rồi thử lại.")
        }
    }

    // MARK: Dựng ảnh xem trước

    private func dungAnhXem(_ trangs: [TrangChuDep]) {
        let toi = cheDoMau == .dark
        let muc = toi ? MucToi.mau(self.muc) : self.muc
        anhDep = trangs.map { Self.anhXem($0, giay: giayDich, kho: khoDich, muc: muc, toi: toi) }
        if anhGoc == nil {
            anhGoc = LamGonView.dungAnh(net, giay: goc.giay, khoTrang: goc.khoTrang, caoGoc: goc.khoGoc.height,
                                        vung: CGRect(origin: .zero, size: goc.khoTrang), rongPx: 1400)
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["CT_VIETLAI_ANH"] == "1",
           let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            for (i, a) in anhDep.enumerated() {
                try? a.pngData()?.write(to: dir.appendingPathComponent("vietlai-xem-\(toi ? "toi" : "sang")-\(i + 1).png"))
            }
        }
        #endif
    }

    /// Giấy (theo chế độ sáng/tối đang xem) + lớp chữ đẹp, rộng ~1400px.
    static func anhXem(_ tr: TrangChuDep, giay: LoaiGiay, kho: CGSize, muc: UIColor, toi: Bool) -> UIImage {
        let s = 1400 / max(kho.width, 1)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = s
        var ra = UIImage()
        UITraitCollection(userInterfaceStyle: toi ? .dark : .light).performAsCurrent {
            let nen = GiayNenView(frame: CGRect(origin: .zero, size: kho))
            nen.giay = giay; nen.khoTrang = kho; nen.caoGoc = kho.height; nen.tyLe = 1
            ra = UIGraphicsImageRenderer(size: kho, format: fmt).image { c in
                nen.draw(CGRect(origin: .zero, size: kho))
                DungChuDep.ve(tr, vao: c.cgContext, muc: muc)
            }
        }
        return ra
    }
}

extension MucToi {
    /// Cùng phép đổi của `doi(_:)` nhưng cho MỘT màu — xem trước ở chế độ tối
    /// dựng thẳng bằng màu này, không phải đổi cả ảnh.
    static func mau(_ c: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard c.getRed(&r, green: &g, blue: &b, alpha: &a) else { return .white }
        func kep(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }
        return UIColor(red: kep(1 - (-0.574 * r + 1.430 * g + 0.144 * b)),
                       green: kep(1 - (0.426 * r + 0.430 * g + 0.144 * b)),
                       blue: kep(1 - (0.426 * r + 1.430 * g - 0.856 * b)), alpha: a)
    }
}

// MARK: - Dải "Đã lưu · Hoàn tác" trên màn viết

struct DaiHoanTacVietLai: View {
    let cau: String
    let hoanTac: () -> Void
    let dong: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(Color.white.opacity(0.9))
            Text(cau)
                .font(Font.bodyMedium.weight(.semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            Button(action: hoanTac) {
                Label(T("Hoàn tác"), systemImage: "arrow.uturn.backward")
                    .font(Font.bodyMedium.weight(.bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.22)))
            }
            .buttonStyle(.plain)
            Button(action: dong) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(T("Đóng"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Capsule().fill(LinearGradient(colors: [AppColors.primaryDark, AppColors.primary],
                                                  startPoint: .leading, endPoint: .trailing)))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        // Ở ĐỈNH màn, không ở đáy: đáy là chỗ bảng công cụ bút nổi của hệ
        // thống — đặt dưới là dải Hoàn tác bị che (đo trên máy ảo 28/09).
        .padding(.top, 58)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#if DEBUG
// MARK: - Mẫu cho bàn thử (CT_VIETLAI=mau)

enum MauVietLai {
    /// Kết quả mẫu: tiếng Việt nhiều dấu chồng, bảng, danh sách lồng, công
    /// thức, code, ghi chú, và trộn tiếng Nhật — đủ để soi phông + bố cục.
    static let json = #"""
    {"khoi":[
     {"loai":"tieuDe","cap":1,"chu":"Mạng máy tính — Bài 3: Mô hình OSI"},
     {"loai":"doan","chu":"Mô hình OSI có 7 tầng, mỗi tầng đảm nhận một việc riêng. Dữ liệu đi từ tầng trên xuống tầng dưới khi gửi. Không được nhầm tầng 3 (network) với tầng 2 (data link) — nhớ kỹ: “Người ướt đường, Ưu tiên nghỉ ngơi”."},
     {"loai":"tieuDe","cap":2,"chu":"Các tầng cần nhớ"},
     {"loai":"danhSach","kieu":"gach","muc":["Tầng 1: vật lý, truyền bit","  Cáp đồng, cáp quang, sóng vô tuyến","Tầng 3: định tuyến gói tin, địa chỉ IP","Tầng 4: TCP / UDP, đảm bảo dữ liệu tới nơi"]},
     {"loai":"bang","coTieuDe":true,"hang":[["Giao thức","Tầng","Cổng"],["HTTP","7","80"],["HTTPS","7","443"],["DNS","7","53"],["SSH","7","22"]]},
     {"loai":"ghiChu","chu":"Ghi nhớ: TCP chậm hơn UDP nhưng tin cậy hơn! Ở đây ế, ỗ, ự, ẫ, ặ, ờ, ữ đều phải hiện đủ dấu."},
     {"loai":"doan","chu":"Công thức:"},
     {"loai":"congThuc","chu":"Thời gian truyền = kích thước / băng thông","latex":"t = \\frac{S}{B}"},
     {"loai":"congThuc","chu":"f(x) = x² + 3x ⇒ f′(x) = 2x + 3","latex":"f(x)=x^2+3x"},
     {"loai":"tieuDe","cap":2,"chu":"Tiếng Nhật — Bài 4"},
     {"loai":"bang","coTieuDe":false,"hang":[["たべます","tabemasu","ăn"],["のみます","nomimasu","uống"],["学校(がっこう)","gakkō","trường học"],["先生(せんせい)","sensei","giáo viên"]]},
     {"loai":"doan","chu":"Ví dụ: パンを たべます = Tôi ăn bánh mì. Chỗ này AI không đọc được: [?]."},
     {"loai":"code","ngonNgu":"python","chu":"def tong(a, b):\n    return a + b\n\nprint(tong(2, 3))"}
    ],
    "sua":[
     {"truoc":"mo hinh osi","sau":"Mô hình OSI","loai":"dau"},
     {"truoc":"ko dc nham","sau":"Không được nhầm","loai":"vietTat"},
     {"truoc":"tang 3 vs tang 2","sau":"tầng 3 với tầng 2","loai":"vietTat"},
     {"truoc":"tcp cham hon udp !!","sau":"TCP chậm hơn UDP!","loai":"vietHoa"},
     {"truoc":"dinh tuyen goi tin","sau":"định tuyến gói tin","loai":"dau"},
     {"truoc":"thoi gian truyen","sau":"Thời gian truyền","loai":"chinhTa"}
    ],
    "chuThuan":"Mạng máy tính — Bài 3: Mô hình OSI",
    "canhBao":["Có 1 chỗ AI không đọc được, đánh dấu [?] — xem lại trước khi lưu."],
    "soKhongDoc":1,"model":"mau"}
    """#

    static var ketQua: KetQuaVietLai? {
        try? JSONDecoder().decode(KetQuaVietLai.self, from: Data(json.utf8))
    }
}
#endif
#endif
