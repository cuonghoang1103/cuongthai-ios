import SwiftUI

// ════════════════════════════════════════════════════════════════
// CHÍN CHẶNG LUYỆN BẢNG CHỮ CÁI
//
// Mỗi chặng là một View nhỏ nhận đúng một câu hỏi rồi báo đúng/sai về cho
// phiên luyện. Chặng KHÔNG tự giữ điểm, không tự sang câu — phiên giữ.
//
// Hai chặng viết tay ở đây LÀM ĐƯỢC thứ web không làm được: web không có
// dữ liệu nét nên chỉ tô mờ lên chữ rồi tự chấm, còn ở đây có đường tim
// thật (`NetChu`) nên chấm được TỪNG NÉT, đúng thứ tự và đúng chiều.
// ════════════════════════════════════════════════════════════════

// MARK: - Mảnh dùng chung

/// Thanh báo đúng/sai + nút sang câu. Luôn nằm CUỐI chặng.
struct ThanhDapAn: View {
    let dung: Bool
    var dapAn: String?
    let khiTiep: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: dung ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(dung ? AppColors.success : AppColors.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(dung ? "Chính xác!" : "Chưa đúng")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(dung ? AppColors.success : AppColors.error)
                if !dung, let d = dapAn {
                    Text("Đáp án: \(d)")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: Spacing.sm)

            Button(action: khiTiep) {
                Label("Tiếp", systemImage: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill((dung ? AppColors.success : AppColors.error).opacity(0.12)),
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

enum TrangThaiNut { case thuong, dung, sai, mo }

/// Một ô đáp án trắc nghiệm.
struct NutChonDapAn: View {
    let chu: String
    let trangThai: TrangThaiNut
    var coLon = false
    let khiCham: () -> Void

    private var mauChu: Color {
        switch trangThai {
        case .thuong: return AppColors.textPrimary
        case .dung:   return AppColors.success
        case .sai:    return AppColors.error
        case .mo:     return AppColors.textTertiary
        }
    }

    private var mauVien: Color {
        switch trangThai {
        case .thuong: return AppColors.border
        case .dung:   return AppColors.success.opacity(0.6)
        case .sai:    return AppColors.error.opacity(0.6)
        case .mo:     return AppColors.border
        }
    }

    private var mauNen: Color {
        switch trangThai {
        case .thuong: return AppColors.backgroundCard
        case .dung:   return AppColors.success.opacity(0.14)
        case .sai:    return AppColors.error.opacity(0.14)
        case .mo:     return AppColors.backgroundCard.opacity(0.5)
        }
    }

    var body: some View {
        Button(action: khiCham) {
            Text(chu)
                .font(.system(size: coLon ? 30 : 19, weight: .semibold))
                .foregroundColor(mauChu)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 60)
                .padding(.horizontal, Spacing.sm)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(mauNen))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(mauVien, lineWidth: 1),
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Ô hiển thị chữ to ở đầu câu hỏi.
struct OChuDeBai: View {
    let chu: String
    var goiY: String?
    var coLon = true

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(chu)
                .font(.system(size: coLon ? 76 : 44, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            if let g = goiY {
                Text(g)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(AppColors.border, lineWidth: 1),
        )
    }
}

/// Ô gõ phiên âm, dùng chung cho 4 chặng gõ.
struct OGoPhienAm: View {
    let dapAnDung: (String) -> Bool
    let dapAnHienThi: String
    var goiY: String = "Gõ phiên âm"
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    @State private var nhap = ""
    @State private var ketQua: Bool?
    @FocusState private var dangGo: Bool

    private func kiem() {
        guard ketQua == nil else { return }
        let sach = nhap.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sach.isEmpty else { return }
        let ok = dapAnDung(sach)
        withAnimation(.easeOut(duration: 0.2)) { ketQua = ok }
        dangGo = false
        ok ? Haptics.xong() : Haptics.hong()
        khiCham(ok)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                TextField(goiY, text: $nhap)
                    .textFieldStyle(.plain)
                    .font(.system(size: 19))
                    .foregroundColor(AppColors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($dangGo)
                    .disabled(ketQua != nil)
                    .onSubmit(kiem)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundCard),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(vienTheoKetQua, lineWidth: 1),
                    )

                if ketQua == nil {
                    Button(action: kiem) {
                        Text("Kiểm tra")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.onPrimary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(AppColors.primary),
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(nhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(nhap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
            }

            if let kq = ketQua {
                ThanhDapAn(dung: kq, dapAn: dapAnHienThi, khiTiep: khiTiep)
            }
        }
        .onAppear { dangGo = true }
    }

    private var vienTheoKetQua: Color {
        switch ketQua {
        case .some(true):  return AppColors.success.opacity(0.6)
        case .some(false): return AppColors.error.opacity(0.6)
        case nil:          return AppColors.border
        }
    }
}

// MARK: - Chặng 1: Trắc nghiệm (chữ → phiên âm)

struct ChangTracNghiemView: View {
    let cau: CauHoiChu
    let bo: [ChuLuyen]
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    @State private var dsChon: [String] = []
    @State private var daChon: String?

    private var dung: String { cau.moc.romaji }

    var body: some View {
        VStack(spacing: Spacing.md) {
            OChuDeBai(chu: cau.moc.kana, goiY: "Chữ này đọc là gì?")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm),
                                GridItem(.flexible(), spacing: Spacing.sm)],
                      spacing: Spacing.sm) {
                ForEach(dsChon, id: \.self) { o in
                    NutChonDapAn(chu: o, trangThai: trangThai(o)) { chon(o) }
                }
            }

            if let c = daChon {
                ThanhDapAn(dung: c == dung, dapAn: dung, khiTiep: khiTiep)
            }
        }
        .onAppear {
            if dsChon.isEmpty {
                dsChon = ([dung] + BoCauHoi.nhieuRomaji(bo, dung: dung, so: 3)).shuffled()
            }
        }
    }

    private func trangThai(_ o: String) -> TrangThaiNut {
        guard daChon != nil else { return .thuong }
        if ChuLuyen.chuanRomaji(o) == ChuLuyen.chuanRomaji(dung) { return .dung }
        return o == daChon ? .sai : .mo
    }

    private func chon(_ o: String) {
        guard daChon == nil else { return }
        let ok = ChuLuyen.chuanRomaji(o) == ChuLuyen.chuanRomaji(dung)
        withAnimation(.easeOut(duration: 0.2)) { daChon = o }
        ok ? Haptics.xong() : Haptics.hong()
        khiCham(ok)
    }
}

// MARK: - Chặng 2: Trắc nghiệm đảo (phiên âm → chữ)

struct ChangTracNghiemDaoView: View {
    let cau: CauHoiChu
    let bo: [ChuLuyen]
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    @State private var dsChon: [String] = []
    @State private var daChon: String?

    private var dung: String { cau.moc.kana }

    var body: some View {
        VStack(spacing: Spacing.md) {
            OChuDeBai(chu: cau.moc.romaji, goiY: "Chọn chữ đúng", coLon: false)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm),
                                GridItem(.flexible(), spacing: Spacing.sm)],
                      spacing: Spacing.sm) {
                ForEach(dsChon, id: \.self) { o in
                    NutChonDapAn(chu: o, trangThai: trangThai(o), coLon: true) { chon(o) }
                }
            }

            if let c = daChon {
                ThanhDapAn(dung: c == dung, dapAn: dung, khiTiep: khiTiep)
            }
        }
        .onAppear {
            if dsChon.isEmpty {
                dsChon = ([dung] + BoCauHoi.nhieuKana(bo, dung: dung, so: 3)).shuffled()
            }
        }
    }

    private func trangThai(_ o: String) -> TrangThaiNut {
        guard daChon != nil else { return .thuong }
        if o == dung { return .dung }
        return o == daChon ? .sai : .mo
    }

    private func chon(_ o: String) {
        guard daChon == nil else { return }
        withAnimation(.easeOut(duration: 0.2)) { daChon = o }
        (o == dung) ? Haptics.xong() : Haptics.hong()
        khiCham(o == dung)
    }
}

// MARK: - Chặng 3: Tìm cặp

struct ChangTimCapView: View {
    let bo: [ChuLuyen]
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    private struct O: Identifiable, Hashable {
        let id: String
        let nhan: String
        let chuId: Int
        let cot: Int   // 0 = chữ, 1 = phiên âm
    }

    @State private var capChon: [ChuLuyen] = []
    @State private var cotChu: [O] = []
    @State private var cotAm: [O] = []
    @State private var dangChon: O?
    @State private var daGhep: Set<Int> = []
    @State private var dangSai: Set<String> = []
    @State private var soSai = 0
    @State private var xong = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("Ghép mỗi chữ với phiên âm — \(daGhep.count)/\(capChon.count) cặp")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .top, spacing: Spacing.md) {
                cot(cotChu, coLon: true)
                cot(cotAm, coLon: false)
            }

            if xong {
                ThanhDapAn(dung: soSai == 0,
                           dapAn: soSai == 0 ? nil : "\(soSai) lần ghép sai",
                           khiTiep: khiTiep)
            }
        }
        .onAppear(perform: dungBo)
    }

    private func cot(_ ds: [O], coLon: Bool) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(ds) { o in
                NutChonDapAn(chu: o.nhan, trangThai: trangThai(o), coLon: coLon) { cham(o) }
                    .opacity(daGhep.contains(o.chuId) ? 0.4 : 1)
                    .disabled(daGhep.contains(o.chuId))
            }
        }
    }

    private func trangThai(_ o: O) -> TrangThaiNut {
        if daGhep.contains(o.chuId) { return .dung }
        if dangSai.contains(o.id) { return .sai }
        if dangChon?.id == o.id { return .mo }
        return .thuong
    }

    private func dungBo() {
        guard capChon.isEmpty else { return }
        // Chọn tối đa 5 chữ có kana VÀ phiên âm đều khác nhau — trùng một
        // trong hai thì bài có hai đáp án đúng và người học bị chấm sai oan.
        var chon: [ChuLuyen] = []
        var daKana = Set<String>(), daAm = Set<String>()
        for c in bo.shuffled() {
            let a = ChuLuyen.chuanRomaji(c.romaji)
            if daKana.contains(c.kana) || daAm.contains(a) { continue }
            daKana.insert(c.kana); daAm.insert(a); chon.append(c)
            if chon.count >= 5 { break }
        }
        capChon = chon
        cotChu = chon.map { O(id: "k\($0.id)", nhan: $0.kana, chuId: $0.id, cot: 0) }.shuffled()
        cotAm = chon.map { O(id: "r\($0.id)", nhan: $0.romaji, chuId: $0.id, cot: 1) }.shuffled()
    }

    private func cham(_ o: O) {
        guard !xong, !daGhep.contains(o.chuId), !dangSai.contains(o.id) else { return }
        guard let truoc = dangChon else { dangChon = o; Haptics.cham(); return }
        if truoc.id == o.id { dangChon = nil; return }
        if truoc.cot == o.cot { dangChon = o; return }

        if truoc.chuId == o.chuId {
            withAnimation(.easeOut(duration: 0.2)) {
                daGhep.insert(o.chuId)
                dangChon = nil
            }
            Haptics.cham()
            if daGhep.count == capChon.count {
                withAnimation(.easeOut(duration: 0.2)) { xong = true }
                Haptics.xong()
                khiCham(soSai == 0)
            }
        } else {
            soSai += 1
            Haptics.hong()
            let sai: Set<String> = [truoc.id, o.id]
            withAnimation(.easeOut(duration: 0.15)) { dangSai = sai; dangChon = nil }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeOut(duration: 0.15)) { dangSai = [] }
            }
        }
    }
}

// MARK: - Chặng 4-6: Gõ phiên âm

struct ChangVietView: View {
    let cau: CauHoiChu
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    private var motChu: Bool { cau.chuoi.count == 1 }

    private var goiY: String {
        switch cau.chang {
        case .vietTu:   return "Gõ phiên âm của cả chuỗi"
        case .vietDoan: return "Gõ phiên âm cả đoạn — có thể cách giữa các âm"
        default:        return "Gõ phiên âm của chữ này"
        }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            OChuDeBai(chu: cau.kanaGhep, goiY: goiY, coLon: motChu)
            OGoPhienAm(dapAnDung: { cau.dungChuoi($0) },
                       dapAnHienThi: cau.romajiGhep,
                       goiY: motChu ? "Ví dụ: ka" : "Gõ phiên âm",
                       khiCham: khiCham,
                       khiTiep: khiTiep)
        }
    }
}

// MARK: - Chặng 7: Nghe

struct ChangNgheView: View {
    let cau: CauHoiChu
    let maNgonNgu: String
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    @ObservedObject private var doc = DocTu.shared
    @State private var daTuDoc = false

    private var doDuoc: Bool { DocTu.doDuoc(maNgonNgu) }

    var body: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.sm) {
                Button {
                    phat()
                } label: {
                    Label("Nghe", systemImage: "speaker.wave.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(Capsule().fill(AppColors.primary.opacity(0.14)))
                        .overlay(Capsule().stroke(AppColors.primary.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!doDuoc)

                if doDuoc {
                    Text("Nghe rồi gõ phiên âm bạn nghe được")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                } else {
                    // Không có giọng thì nói thẳng, kèm cách sửa. Để nút chết
                    // câm là người dùng tưởng app hỏng.
                    Text("Máy chưa cài giọng tiếng Nhật.\nCài đặt → Trợ năng → Nội dung đọc → Giọng nói → Thêm tiếng Nhật.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.warning)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(AppColors.border, lineWidth: 1),
            )

            OGoPhienAm(dapAnDung: { cau.moc.dung($0) },
                       dapAnHienThi: "\(cau.moc.kana) = \(cau.moc.romaji)",
                       khiCham: khiCham,
                       khiTiep: khiTiep)
        }
        .onAppear {
            // Tự đọc MỘT lần khi câu hiện ra. `onAppear` chạy lại khi cuộn
            // hoặc khi bàn phím đẩy layout, nên phải có cờ chặn.
            guard !daTuDoc else { return }
            daTuDoc = true
            phat()
        }
    }

    private func phat() {
        guard doDuoc else { return }
        doc.doc(cau.moc.kana, code: maNgonNgu, chamHon: true)
    }
}

// MARK: - Ô vẽ tay

/// Khung vuông để viết bằng ngón tay hoặc Apple Pencil.
///
/// Cố ý KHÔNG dùng PencilKit ở đây: `BangVe` gắn với một trang vở (lưu file,
/// bảng công cụ, thu phóng) — mang cả bộ đó vào một câu hỏi là thừa, và
/// bảng công cụ nổi sẽ che mất nút "Tiếp". Ở đây chỉ cần toạ độ nét.
struct OVeTay: View {
    let canh: CGFloat
    @Binding var cacNet: [[CGPoint]]
    @Binding var netDang: [CGPoint]
    var mauNet: Color = AppColors.textPrimary
    var khiXongNet: (([CGPoint]) -> Void)?

    var body: some View {
        Canvas { ctx, _ in
            for n in cacNet + (netDang.count > 1 ? [netDang] : []) {
                guard n.count > 1 else { continue }
                var p = Path()
                p.move(to: n[0])
                for q in n.dropFirst() { p.addLine(to: q) }
                ctx.stroke(p, with: .color(mauNet),
                           style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: canh, height: canh)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in netDang.append(g.location) }
                .onEnded { _ in
                    let n = netDang
                    netDang = []
                    guard n.count > 1 else { return }
                    if let f = khiXongNet { f(n) } else { cacNet.append(n) }
                },
        )
    }
}

/// Khung vở: nền, viền, đường kẻ chia tư.
struct KhungOViet<NoiDung: View>: View {
    let canh: CGFloat
    @ViewBuilder var noiDung: NoiDung

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
            Path { p in
                p.move(to: CGPoint(x: canh / 2, y: 0)); p.addLine(to: CGPoint(x: canh / 2, y: canh))
                p.move(to: CGPoint(x: 0, y: canh / 2)); p.addLine(to: CGPoint(x: canh, y: canh / 2))
            }
            .stroke(AppColors.divider, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            noiDung
        }
        .frame(width: canh, height: canh)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(AppColors.border, lineWidth: 1),
        )
    }
}

/// Bọc một ô vuông co theo bề ngang thật của khung chứa.
///
/// ⚠️ KHÔNG dùng `UIScreen.main.bounds`: trên iPad chia đôi màn hình nó vẫn
/// trả bề ngang CẢ MÀN, nên ô vẽ tràn ra ngoài cửa sổ. `GeometryReader`
/// nằm trong một khung đã cố định tỉ lệ thì đọc ra đúng kích thước thật.
struct OVuongVua<NoiDung: View>: View {
    var toiDa: CGFloat = 400
    @ViewBuilder var noiDung: (CGFloat) -> NoiDung

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: toiDa)
            .overlay {
                GeometryReader { g in
                    let canh = min(g.size.width, g.size.height)
                    noiDung(canh)
                        .frame(width: g.size.width, height: g.size.height)
                }
            }
    }
}

// MARK: - Chặng 8: Tập viết (chấm từng nét)

struct ChangTapVietView: View {
    let cau: CauHoiChu
    let maNgonNgu: String
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    /// Một chữ trong chuỗi, kèm dữ liệu nét nếu tải được.
    private struct MatXich {
        let chu: String
        let net: NetChu?
    }

    @State private var chuoi: [MatXich] = []
    @State private var dangTai = true
    @State private var viTri = 0          // chữ thứ mấy trong chuỗi
    @State private var netHienTai = 0     // nét thứ mấy trong chữ
    @State private var netDang: [CGPoint] = []
    @State private var daVe: [[CGPoint]] = []
    @State private var soLanSai = 0
    @State private var hienGoiY = false
    @State private var rung: CGFloat = 0
    @State private var xong = false
    @State private var coSai = false

    private var matHienTai: MatXich? { viTri < chuoi.count ? chuoi[viTri] : nil }

    var body: some View {
        VStack(spacing: Spacing.md) {
            tieuDe

            if dangTai {
                OVuongVua { canh in
                    KhungOViet(canh: canh) { ProgressView() }
                }
            } else if let mat = matHienTai, let n = mat.net {
                OVuongVua { canh in
                    oChamNet(n, canh: canh).offset(x: rung)
                }
                thanhTienNet(n)
                nutCongCu(coGoiY: true)
            } else if let mat = matHienTai {
                // Không có dữ liệu nét (âm ghép, ký hiệu) → tô theo chữ mờ.
                // Nói thẳng là không chấm được, đừng giả vờ chấm.
                OVuongVua { canh in
                    KhungOViet(canh: canh) {
                        Text(mat.chu)
                            .font(.system(size: canh * 0.72, weight: .bold))
                            .foregroundColor(AppColors.textPrimary.opacity(hienGoiY ? 0.16 : 0.05))
                        OVeTay(canh: canh, cacNet: $daVe, netDang: $netDang,
                               mauNet: AppColors.secondary)
                    }
                }
                Text("Chữ này chưa có dữ liệu nét — tô theo mẫu để quen tay, không chấm điểm.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                nutCongCu(coGoiY: false)
            }

            if xong {
                ThanhDapAn(dung: !coSai,
                           dapAn: coSai ? "\(cau.kanaGhep) = \(cau.romajiGhep)" : nil,
                           khiTiep: khiTiep)
            }
        }
        .task { await tai() }
    }

    private var tieuDe: some View {
        VStack(spacing: 3) {
            Text("Viết \(cau.kanaGhep)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(chuoi.count > 1
                 ? "\(cau.romajiGhep) · chữ \(min(viTri + 1, chuoi.count))/\(chuoi.count)"
                 : cau.romajiGhep)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func oChamNet(_ n: NetChu, canh: CGFloat) -> some View {
        KhungOViet(canh: canh) {
            ForEach(0..<n.soNet, id: \.self) { i in
                let mau = i < netHienTai ? AppColors.primary : AppColors.textPrimary.opacity(0.09)
                if n.laDuongTim {
                    DuongSVG.doi(n.strokes[i], canh: canh)
                        .stroke(mau, style: StrokeStyle(lineWidth: n.beDayNet(canh: canh),
                                                        lineCap: .round, lineJoin: .round))
                } else {
                    DuongSVG.doi(n.strokes[i], canh: canh).fill(mau)
                }
            }

            if hienGoiY || soLanSai >= 2, netHienTai < n.soNet {
                let tim = n.duongTim(netHienTai, canh: canh)
                if tim.count > 1 {
                    Path { p in
                        p.move(to: tim[0])
                        for q in tim.dropFirst() { p.addLine(to: q) }
                    }
                    .stroke(AppColors.accent.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 6]))
                    Circle().fill(AppColors.accent)
                        .frame(width: 13, height: 13)
                        .position(tim[0])
                }
            }

            OVeTay(canh: canh, cacNet: .constant([]), netDang: $netDang,
                   mauNet: AppColors.secondary) { net in
                chamMotNet(net, n: n, canh: canh)
            }
        }
    }

    private func thanhTienNet(_ n: NetChu) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<n.soNet, id: \.self) { i in
                Capsule()
                    .fill(i < netHienTai ? AppColors.primary : AppColors.backgroundTertiary)
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: 400)
    }

    private func nutCongCu(coGoiY: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            if coGoiY {
                nutNho(hienGoiY ? "Ẩn gợi ý" : "Gợi ý", hienGoiY ? "eye.slash" : "eye") {
                    hienGoiY.toggle(); Haptics.cham()
                }
                nutNho("Bỏ qua nét", "forward") {
                    if let n = matHienTai?.net { sangNet(n, tinhSai: true) }
                }
            } else {
                nutNho("Xoá", "eraser") { daVe = []; Haptics.cham() }
                nutNho(hienGoiY ? "Ẩn mẫu" : "Hiện mẫu", hienGoiY ? "eye.slash" : "eye") {
                    hienGoiY.toggle(); Haptics.cham()
                }
                nutNho("Xong", "checkmark") { sangChu(tinhSai: false) }
            }
        }
        .frame(maxWidth: 400)
    }

    private func nutNho(_ nhan: String, _ icon: String, _ cham: @escaping () -> Void) -> some View {
        Button(action: cham) {
            Label(nhan, systemImage: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }

    // ── Chấm ────────────────────────────────────────────────────
    private func chamMotNet(_ net: [CGPoint], n: NetChu, canh: CGFloat) {
        guard !xong, netHienTai < n.soNet else { return }
        let tim = n.duongTim(netHienTai, canh: canh)
        guard tim.count > 1 else { sangNet(n, tinhSai: false); return }

        if ChamNet.dat(nguoiVe: net, duongTim: tim, canh: canh) {
            sangNet(n, tinhSai: false)
        } else {
            soLanSai += 1
            coSai = true
            Haptics.hong()
            Task { @MainActor in
                for (i, x) in [9.0, -9.0, 7.0, -5.0, 0.0].enumerated() {
                    withAnimation(.linear(duration: 0.05)) { rung = x }
                    try? await Task.sleep(for: .milliseconds(i == 0 ? 55 : 50))
                }
            }
        }
    }

    private func sangNet(_ n: NetChu, tinhSai: Bool) {
        if tinhSai { coSai = true }
        soLanSai = 0
        hienGoiY = false
        Haptics.cham()
        withAnimation(.easeOut(duration: 0.2)) {
            netHienTai += 1
            if netHienTai >= n.soNet { sangChu(tinhSai: false) }
        }
    }

    private func sangChu(tinhSai: Bool) {
        if tinhSai { coSai = true }
        daVe = []
        netHienTai = 0
        hienGoiY = false
        if viTri + 1 < chuoi.count {
            withAnimation(.easeOut(duration: 0.2)) { viTri += 1 }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { xong = true }
            Haptics.xong()
            khiCham(!coSai)
        }
    }

    private func tai() async {
        dangTai = true
        // Âm ghép như きゃ là HAI chữ — endpoint nét chỉ nhận một chữ, nên
        // tách ra và luyện lần lượt từng chữ trong cùng một câu.
        var ra: [MatXich] = []
        for ky in cau.kanaGhep {
            let s = String(ky)
            let n = await KhoNetChu.shared.lay(s, lang: maNgonNgu == "zh" ? "zh" : "ja")
            ra.append(MatXich(chu: s, net: n))
        }
        chuoi = ra
        dangTai = false
    }
}

// MARK: - Chặng 9: Vẽ chữ (nhớ rồi vẽ lại)

struct ChangVeChuView: View {
    let cau: CauHoiChu
    let maNgonNgu: String
    let khiCham: (Bool) -> Void
    let khiTiep: () -> Void

    @State private var cacNet: [[CGPoint]] = []
    @State private var netDang: [CGPoint] = []
    @State private var hienDapAn = false
    @State private var tuCham: Bool?

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Text("Vẽ chữ đọc là")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                Text(cau.moc.romaji)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                if DocTu.doDuoc(maNgonNgu) {
                    Button {
                        DocTu.shared.doc(cau.moc.kana, code: maNgonNgu, chamHon: true)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Phát âm")
                }
            }

            OVuongVua { canh in
                KhungOViet(canh: canh) {
                    Text(cau.moc.kana)
                        .font(.system(size: canh * 0.72, weight: .bold))
                        .foregroundColor(AppColors.textPrimary.opacity(hienDapAn ? 0.18 : 0))
                    OVeTay(canh: canh, cacNet: $cacNet, netDang: $netDang,
                           mauNet: AppColors.secondary)
                }
            }

            HStack(spacing: Spacing.sm) {
                nutNho("Xoá", "eraser") { cacNet = []; Haptics.cham() }
                nutNho(hienDapAn ? "Ẩn đáp án" : "Hiện đáp án",
                       hienDapAn ? "eye.slash" : "eye") {
                    withAnimation(.easeOut(duration: 0.15)) { hienDapAn.toggle() }
                    Haptics.cham()
                }
            }
            .frame(maxWidth: 400)

            if let kq = tuCham {
                ThanhDapAn(dung: kq, dapAn: "\(cau.moc.kana) = \(cau.moc.romaji)", khiTiep: khiTiep)
            } else {
                // Tự chấm: máy không đọc được nét vẽ tự do, nên người học tự
                // đối chiếu. Thành thật hơn là chấm bừa rồi báo sai.
                HStack(spacing: Spacing.sm) {
                    nutTuCham("Chưa đúng", "xmark", AppColors.error) { cham(false) }
                    nutTuCham("Đúng rồi", "checkmark", AppColors.success) { cham(true) }
                }
                .frame(maxWidth: 400)
            }
        }
    }

    private func cham(_ ok: Bool) {
        guard tuCham == nil else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            tuCham = ok
            hienDapAn = true
        }
        ok ? Haptics.xong() : Haptics.hong()
        khiCham(ok)
    }

    private func nutNho(_ nhan: String, _ icon: String, _ cham: @escaping () -> Void) -> some View {
        Button(action: cham) {
            Label(nhan, systemImage: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }

    private func nutTuCham(_ nhan: String, _ icon: String, _ mau: Color,
                           _ cham: @escaping () -> Void) -> some View {
        Button(action: cham) {
            Label(nhan, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(mau)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(mau.opacity(0.14)))
                .overlay(Capsule().stroke(mau.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
