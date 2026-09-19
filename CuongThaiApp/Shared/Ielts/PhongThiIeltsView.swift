import SwiftUI

// MARK: - Mô hình đề thi

struct PhanNgheDe: Decodable { let phut: Int; let bai: [BaiNgheIelts]; let soCau: Int }
struct PhanDocDe: Decodable { let phut: Int; let bai: [BaiDocIelts]; let soCau: Int }
struct PhanVietDe: Decodable { let phut: Int; let de: [DeVietIelts] }
struct BaPhanDe: Decodable { let nghe: PhanNgheDe; let doc: PhanDocDe; let viet: PhanVietDe }

struct DeThiIelts: Decodable {
    let chang: String
    let hat: Int
    let phan: BaPhanDe
    let canhBao: String
}

struct KetQuaNop: Decodable {
    let bandDoc: Double?
    let bandNghe: Double?
    let bandTong: Double?
}

struct LuotThiIelts: Decodable, Identifiable {
    let stage: String
    let muc: String
    let band: Double?
    let luc: String
    var id: String { muc }
}

struct GoiLichSuThi: Decodable { let items: [LuotThiIelts] }

// MARK: - Phòng thi

/// Phòng thi IELTS — ba phần, đúng thứ tự và đúng đồng hồ của kỳ thi thật.
///
/// ⚠️ Đồng hồ CHẠY THẬT và không tạm dừng được. Đó là điểm khác biệt duy
/// nhất giữa "làm bài luyện" và "thi thử": ai cũng làm đúng nhiều hơn khi
/// được dừng lại tra từ, nên một phòng thi cho tạm dừng thì con số nó trả về
/// không nói lên điều gì.
struct PhongThiIeltsView: View {
    @ObservedObject var vm: IeltsVM

    @State private var de: DeThiIelts?
    @State private var chang = "stage1"
    @State private var giaiDoan: GiaiDoan = .chon
    @State private var dangTai = false
    @State private var loi: String?

    // Bài làm
    @State private var traLoiNghe: [String: String] = [:]
    @State private var traLoiDoc: [String: String] = [:]
    @State private var baiViet: [String: String] = [:]

    // Đồng hồ
    @State private var conLai = 0
    @State private var dongHo: Timer?
    @State private var ketQua: KetQuaNop?
    @State private var lichSu: [LuotThiIelts] = []

    enum GiaiDoan: Equatable { case chon, nghe, doc, viet, ketQua }

    var body: some View {
        Group {
            switch giaiDoan {
            case .chon: manChon
            case .nghe, .doc, .viet: manLamBai
            case .ketQua: manKetQua
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Phòng thi"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { ToolbarItem(placement: .primaryAction) { NutGiongIelts() } }
        // Rời màn giữa chừng thì phải dừng đồng hồ, nếu không nó vẫn đếm và
        // bắn `giaiDoan` sang phần sau của một bài thi đã bỏ dở.
        .onDisappear { tatDongHo(); DocTu.shared.dung() }
        .task { await napLichSu() }
        .alert(T("Lỗi"), isPresented: Binding(get: { loi != nil }, set: { if !$0 { loi = nil } })) {
            Button(T("Đóng"), role: .cancel) { loi = nil }
        } message: { Text(loi ?? "") }
    }

    // MARK: Màn chọn

    private var manChon: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label(T("Thi thử đủ ba phần"), systemImage: "timer")
                        .font(.titleSmall).foregroundStyle(AppColors.primary)
                    hang("🎧", T("Nghe"), T("4 phần · 30 phút"))
                    hang("📖", T("Đọc"), T("3 bài · 60 phút"))
                    hang("✍️", T("Viết"), T("Task 1 + Task 2 · 60 phút"))
                    Text(T("Đồng hồ chạy thật và KHÔNG tạm dừng được — đó là thứ duy nhất làm nên khác biệt giữa làm bài luyện và thi thử."))
                        .font(.caption).foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .cornerRadius(CornerRadius.large)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(T("Chọn độ khó")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(vm.loTrinh?.chang ?? []) { c in
                                Button { chang = c.id } label: {
                                    Text("\(T("Chặng")) \(c.so)")
                                        .font(.captionBold)
                                        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                                        .background(chang == c.id ? AppColors.primary : AppColors.backgroundCard)
                                        .foregroundStyle(chang == c.id ? Color.white : AppColors.textPrimary)
                                        .cornerRadius(CornerRadius.full)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }

                Button { Task { await batDau() } } label: {
                    HStack {
                        Spacer()
                        if dangTai { ProgressView().tint(.white) } else {
                            Label(T("Bắt đầu thi"), systemImage: "play.fill")
                        }
                        Spacer()
                    }
                    .font(.buttonText)
                    .padding(.vertical, Spacing.md)
                    .background(AppColors.primary)
                    .foregroundStyle(Color.white)
                    .cornerRadius(CornerRadius.medium)
                }
                .buttonStyle(.plain)
                .disabled(dangTai)

                if !lichSu.isEmpty { khoiLichSu }
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
    }

    private func hang(_ bt: String, _ ten: String, _ phu: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(bt)
            Text(ten).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
            Spacer()
            Text(phu).font(.caption).foregroundStyle(AppColors.textTertiary)
        }
    }

    private var khoiLichSu: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Đã thi")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            ForEach(lichSu.prefix(8)) { l in
                HStack {
                    Text(l.muc.replacingOccurrences(of: "de-stage", with: "\(T("Chặng")) "))
                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if let b = l.band {
                        Text("Band \(soBand(b))")
                            .font(.captionBold)
                            .foregroundStyle(b >= 6.5 ? AppColors.success : AppColors.warning)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Màn làm bài

    private var manLamBai: some View {
        VStack(spacing: 0) {
            thanhDongHo
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    switch giaiDoan {
                    case .nghe: phanNghe
                    case .doc: phanDoc
                    case .viet: phanViet
                    default: EmptyView()
                    }
                    Button { sangPhanSau() } label: {
                        Text(giaiDoan == .viet ? T("Nộp bài") : T("Xong phần này — sang phần sau"))
                            .font(.buttonText).frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(AppColors.primary)
                            .foregroundStyle(Color.white)
                            .cornerRadius(CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .padding(.bottom, 60)
            }
        }
    }

    private var thanhDongHo: some View {
        HStack {
            Text(tenPhan).font(.captionBold).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Label(dongHoChu, systemImage: "timer")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                // Dưới 5 phút đổi đỏ: người đang cắm đầu viết không nhìn đồng
                // hồ, nên nó phải tự đập vào mắt.
                .foregroundStyle(conLai <= 300 ? AppColors.error : AppColors.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundCard)
    }

    private var tenPhan: String {
        switch giaiDoan {
        case .nghe: return "🎧 " + T("Nghe")
        case .doc: return "📖 " + T("Đọc")
        case .viet: return "✍️ " + T("Viết")
        default: return ""
        }
    }

    private var dongHoChu: String {
        String(format: "%02d:%02d", max(0, conLai) / 60, max(0, conLai) % 60)
    }

    // MARK: Phần nghe

    @ViewBuilder
    private var phanNghe: some View {
        if let d = de {
            ForEach(Array(d.phan.nghe.bai.enumerated()), id: \.element.id) { i, b in
                KhoiNgheDe(so: i + 1, bai: b, soCauDau: soCauNghe(i, 0),
                           traLoi: $traLoiNghe)
            }
        }
    }

    private func soCauNghe(_ i: Int, _ j: Int) -> Int {
        guard let d = de else { return j + 1 }
        return d.phan.nghe.bai.prefix(i).reduce(0) { $0 + $1.questions.count } + j + 1
    }

    // MARK: Phần đọc

    @ViewBuilder
    private var phanDoc: some View {
        if let d = de {
            ForEach(Array(d.phan.doc.bai.enumerated()), id: \.element.id) { i, b in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("\(T("Bài")) \(i + 1) — \(b.title)")
                        .font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                    ForEach(b.paragraphs, id: \.label) { p in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.label).font(.captionBold).foregroundStyle(AppColors.primary)
                            Text(p.text).font(.system(size: 16)).foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Divider()
                    ForEach(Array(b.questions.enumerated()), id: \.element.id) { j, c in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 7) {
                                Text("\(soCauDoc(i, j)).").font(.captionBold).foregroundStyle(AppColors.textTertiary)
                                Text(c.q).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if c.phaiGo {
                                TextField(T("Gõ đáp án"), text: Binding(
                                    get: { traLoiDoc[c.id] ?? "" }, set: { traLoiDoc[c.id] = $0 }))
                                    .font(.bodyMedium).padding(Spacing.sm)
                                    .background(AppColors.backgroundTertiary)
                                    .cornerRadius(CornerRadius.medium)
                                    #if os(iOS)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    #endif
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Spacing.sm) {
                                        ForEach(c.luaChon, id: \.self) { o in
                                            Button { traLoiDoc[c.id] = o } label: {
                                                Text(o).font(.bodySmall)
                                                    .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 7)
                                                    .background(traLoiDoc[c.id] == o ? AppColors.primary : AppColors.backgroundTertiary)
                                                    .foregroundStyle(traLoiDoc[c.id] == o ? Color.white : AppColors.textPrimary)
                                                    .cornerRadius(CornerRadius.full)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 1)
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .cornerRadius(CornerRadius.large)
            }
        }
    }

    private func soCauDoc(_ i: Int, _ j: Int) -> Int {
        guard let d = de else { return j + 1 }
        return d.phan.doc.bai.prefix(i).reduce(0) { $0 + $1.questions.count } + j + 1
    }

    // MARK: Phần viết

    @ViewBuilder
    private var phanViet: some View {
        if let d = de {
            ForEach(d.phan.viet.de) { w in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(w.task).font(.captionBold).foregroundStyle(AppColors.primary)
                    Text(w.prompt).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("\(T("Tối thiểu")) \(w.minWords) \(T("từ"))")
                            .font(.caption2).foregroundStyle(AppColors.textTertiary)
                        Spacer()
                        Text("\(demTu(baiViet[w.id] ?? "")) \(T("từ"))")
                            .font(.captionBold)
                            .foregroundStyle(demTu(baiViet[w.id] ?? "") >= w.minWords ? AppColors.success : AppColors.textTertiary)
                    }
                    TextEditor(text: Binding(get: { baiViet[w.id] ?? "" }, set: { baiViet[w.id] = $0 }))
                        .font(.bodyMedium)
                        .frame(minHeight: 200)
                        .padding(Spacing.sm)
                        .background(AppColors.backgroundTertiary)
                        .cornerRadius(CornerRadius.medium)
                        .scrollContentBackground(.hidden)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .cornerRadius(CornerRadius.large)
            }
        }
    }

    private func demTu(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    // MARK: Kết quả

    private var manKetQua: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let k = ketQua {
                    VStack(spacing: Spacing.sm) {
                        Text(T("Band ước lượng")).font(.captionBold).foregroundStyle(AppColors.textSecondary)
                        Text(k.bandTong.map { soBand($0) } ?? "—")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                        HStack(spacing: Spacing.xl) {
                            oBand("🎧 " + T("Nghe"), k.bandNghe, dungNghe, soCauNghe)
                            oBand("📖 " + T("Đọc"), k.bandDoc, dungDoc, soCauDoc)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(CornerRadius.large)
                }

                if let d = de {
                    Text(d.canhBao).font(.caption).foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                        .background(AppColors.warning.opacity(0.10))
                        .cornerRadius(CornerRadius.medium)
                }

                Text(T("Phần Viết không chấm tự động — mở từng đề ở mục Viết rồi nhờ AI chấm theo 4 tiêu chí."))
                    .font(.caption).foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let d = de { khoiSoiLoi(d) }

                Button {
                    giaiDoan = .chon
                    de = nil; ketQua = nil
                    traLoiNghe = [:]; traLoiDoc = [:]; baiViet = [:]
                    Task { await napLichSu() }
                } label: {
                    Text(T("Về phòng thi")).font(.buttonText).frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(AppColors.backgroundTertiary)
                        .foregroundStyle(AppColors.textPrimary)
                        .cornerRadius(CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .padding(.bottom, 60)
        }
    }

    private func oBand(_ ten: String, _ band: Double?, _ dung: Int, _ tong: Int) -> some View {
        VStack(spacing: 2) {
            Text(ten).font(.caption2).foregroundStyle(AppColors.textTertiary)
            Text(band.map { soBand($0) } ?? "—")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text("\(dung)/\(tong)").font(.caption2).foregroundStyle(AppColors.textTertiary)
        }
    }

    /// Soi lại từng câu sai — thứ đáng giá hơn con số band.
    private func khoiSoiLoi(_ d: DeThiIelts) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(T("Câu sai")).font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            ForEach(d.phan.doc.bai) { b in
                ForEach(b.questions.filter { !$0.dung(traLoiDoc[$0.id] ?? "") }) { c in
                    dongSai(c.q, traLoiDoc[c.id] ?? "", c.answer, c.why)
                }
            }
            ForEach(d.phan.nghe.bai) { b in
                ForEach(b.questions.filter { !$0.dung(traLoiNghe[$0.id] ?? "") }) { c in
                    dongSai(c.q, traLoiNghe[c.id] ?? "", c.answer, c.why)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private func dongSai(_ hoi: String, _ daChon: String, _ dung: String, _ vi: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(hoi).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(daChon.isEmpty ? T("(bỏ trống)") : daChon)
                    .font(.caption).foregroundStyle(AppColors.error)
                Text("→").font(.caption).foregroundStyle(AppColors.textTertiary)
                Text(dung).font(.captionBold).foregroundStyle(AppColors.success)
            }
            Text(vi).font(.caption2).foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    // MARK: Đếm đúng

    private var soCauNghe: Int { de?.phan.nghe.bai.reduce(0) { $0 + $1.questions.count } ?? 0 }
    private var soCauDoc: Int { de?.phan.doc.bai.reduce(0) { $0 + $1.questions.count } ?? 0 }
    private var dungNghe: Int {
        (de?.phan.nghe.bai ?? []).reduce(0) { s, b in
            s + b.questions.filter { $0.dung(traLoiNghe[$0.id] ?? "") }.count
        }
    }
    private var dungDoc: Int {
        (de?.phan.doc.bai ?? []).reduce(0) { s, b in
            s + b.questions.filter { $0.dung(traLoiDoc[$0.id] ?? "") }.count
        }
    }

    private func soBand(_ b: Double) -> String {
        b == b.rounded() ? String(Int(b)) : String(format: "%.1f", b)
    }

    // MARK: Luồng

    private func batDau() async {
        dangTai = true
        defer { dangTai = false }
        do {
            let g: GoiDeThi = try await APIClient.shared.request(.ieltsDeThi(chang: chang, hat: nil))
            de = g.de
            giaiDoan = .nghe
            batDongHo(g.de.phan.nghe.phut * 60)
        } catch { loi = error.localizedDescription }
    }

    private func sangPhanSau() {
        DocTu.shared.dung()
        switch giaiDoan {
        case .nghe:
            giaiDoan = .doc
            batDongHo((de?.phan.doc.phut ?? 60) * 60)
        case .doc:
            giaiDoan = .viet
            batDongHo((de?.phan.viet.phut ?? 60) * 60)
        case .viet:
            tatDongHo()
            Task { await nop() }
        default: break
        }
    }

    private func nop() async {
        giaiDoan = .ketQua
        do {
            let k: KetQuaNop = try await APIClient.shared.request(.ieltsNopDe([
                "chang": chang, "hat": de?.hat ?? 0,
                "dungDoc": dungDoc, "cauDoc": soCauDoc,
                "dungNghe": dungNghe, "cauNghe": soCauNghe,
            ]))
            ketQua = k
            await vm.napLoTrinh()
        } catch { loi = error.localizedDescription }
    }

    private func batDongHo(_ giay: Int) {
        tatDongHo()
        conLai = giay
        dongHo = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                conLai -= 1
                // Hết giờ thì TỰ sang phần sau. Đề thi thật không chờ ai, và
                // một đồng hồ về 0 rồi đứng im là đồng hồ không có tác dụng.
                if conLai <= 0 { sangPhanSau() }
            }
        }
    }

    private func tatDongHo() { dongHo?.invalidate(); dongHo = nil }

    private func napLichSu() async {
        if let g: GoiLichSuThi = try? await APIClient.shared.request(.ieltsLichSuThi) {
            lichSu = g.items
        }
    }
}

/// Máy chủ trả thẳng đề, không bọc thêm tầng nào.
struct GoiDeThi: Decodable {
    let de: DeThiIelts

    init(from decoder: Decoder) throws {
        de = try DeThiIelts(from: decoder)
    }
}


// MARK: - Một phần nghe trong đề thi

/// Tách riêng khỏi `PhongThiIeltsView` vì lý do KỸ THUẬT, không phải thẩm mỹ:
/// để nguyên trong thân view cha thì trình dịch Swift báo "unable to
/// type-check this expression in reasonable time" và bỏ cuộc. Một `ForEach`
/// lồng trong `ForEach` với `Binding` dựng tại chỗ là quá nhiều cho bộ suy
/// kiểu; chia nhỏ là cách sửa, không phải chú thích kiểu.
private struct KhoiNgheDe: View {
    let so: Int
    let bai: BaiNgheIelts
    let soCauDau: Int
    @Binding var traLoi: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("\(T("Phần")) \(so) — \(bai.title)")
                .font(.titleSmall).foregroundStyle(AppColors.textPrimary)
            Text(bai.context).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { phat() } label: {
                Label(T("Nghe phần này"), systemImage: "play.circle.fill")
                    .font(.buttonSmall)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                    .background(AppColors.primary.opacity(0.14))
                    .foregroundStyle(AppColors.primary)
                    .cornerRadius(CornerRadius.full)
            }
            .buttonStyle(.plain)

            ForEach(Array(bai.questions.enumerated()), id: \.element.id) { j, c in
                oCau(so: soCauDau + j, cau: c)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private func phat() {
        DocTu.shared.doc(bai.lines.map { "\($0.who). \($0.text)" }.joined(separator: " ... "), code: "en")
    }

    private func oCau(so: Int, cau: CauHoiNgheIelts) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 7) {
                Text("\(so).").font(.captionBold).foregroundStyle(AppColors.textTertiary)
                Text(cau.q).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(T("Gõ đáp án"), text: Binding(
                get: { traLoi[cau.id] ?? "" },
                set: { traLoi[cau.id] = $0 }))
                .font(.bodyMedium)
                .padding(Spacing.sm)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.medium)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
        }
        .padding(.vertical, 3)
    }
}
