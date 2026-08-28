import SwiftUI

@MainActor
final class PhongVM: ObservableObject {
    @Published var phien: PhienPV
    @Published var luot = 0
    @Published var traLoi = ""
    @Published var chonMCQ: String?
    @Published var ketQua: KetQuaLuot?
    @Published var dangGui = false
    @Published var dangKetThuc = false
    @Published var loi: String?
    @Published var xongPhien = false

    private var batDauLuot = Date()

    init(_ p: PhienPV) {
        phien = p
        // Vào lại phiên dở thì nhảy tới câu chưa trả lời đầu tiên, đừng bắt
        // người dùng lướt qua những câu đã xong.
        luot = p.cacLuot.firstIndex { $0.answered != true } ?? 0
    }

    var cauHienTai: LuotPV? {
        phien.cacLuot.indices.contains(luot) ? phien.cacLuot[luot] : nil
    }
    var laCuoi: Bool { luot >= phien.cacLuot.count - 1 }

    func moLuot(_ i: Int) {
        luot = i
        traLoi = phien.cacLuot.indices.contains(i) ? (phien.cacLuot[i].userAnswer ?? "") : ""
        chonMCQ = nil
        ketQua = nil
        batDauLuot = Date()
    }

    func gui() async {
        guard let c = cauHienTai, !dangGui else { return }
        let noi = traLoi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !noi.isEmpty || chonMCQ != nil else { return }
        dangGui = true; defer { dangGui = false }
        var than: [String: Any] = [
            "answer": noi,
            "timeSpentMs": Int(Date().timeIntervalSince(batDauLuot) * 1000),
            "inputMode": "TEXT",
        ]
        if let m = chonMCQ { than["selectedOptionId"] = m }
        do {
            let kq: KetQuaLuot = try await APIClient.shared.request(
                .pvTraLoi(id: phien.id, thuTu: c.order, than: than))
            ketQua = kq
            // Tải lại trạng thái để `answered`/`userAnswer` khớp máy chủ —
            // tự sửa cục bộ là mở đường cho hai bên lệch nhau.
            if let m: PhienPV = try? await APIClient.shared.request(.pvTrangThai(id: phien.id)) {
                phien = m
            }
        } catch { loi = error.localizedDescription }
    }

    func ketThuc() async {
        guard !dangKetThuc else { return }
        dangKetThuc = true; defer { dangKetThuc = false }
        do {
            let _: NoiDungBaoCao = try await APIClient.shared.request(.pvKetThuc(id: phien.id))
            xongPhien = true
        } catch {
            // Máy chủ có thể trả về hình dạng khác — miễn không ném là xong.
            xongPhien = true
        }
    }
}

struct PhongPhongVanView: View {
    let phienBanDau: PhienPV
    @StateObject private var vm: PhongVM
    @State private var moBaoCao = false

    init(phienBanDau: PhienPV) {
        self.phienBanDau = phienBanDau
        _vm = StateObject(wrappedValue: PhongVM(phienBanDau))
    }

    var body: some View {
        VStack(spacing: 0) {
            thanhTien
            ScrollViewReader { cuon in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    NeoDauTrang()
                    if let c = vm.cauHienTai {
                        khoiCauHoi(c)
                        if vm.ketQua == nil { khoiTraLoi(c) } else { khoiKetQua(c) }
                    }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }
            .onChange(of: vm.luot) { _, _ in cuon.veDauTrang() }
            }
            thanhDuoi
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(vm.phien.trackName ?? T("Phỏng vấn"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(vm.dangGui)
        .onAppear { vm.moLuot(vm.luot) }
        .navigationDestination(isPresented: $moBaoCao) {
            BaoCaoPhongVanView(phienId: vm.phien.id, tua: vm.phien.trackName ?? "")
        }
        .onChange(of: vm.xongPhien) { _, m in if m { moBaoCao = true } }
    }

    // MARK: Thanh tiến độ

    private var thanhTien: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(vm.phien.cacLuot.enumerated()), id: \.element.order) { i, l in
                    Button { vm.moLuot(i) } label: {
                        Capsule()
                            .fill(i == vm.luot ? AppColors.primary
                                  : (l.answered == true ? AppColors.primary.opacity(0.45)
                                                        : AppColors.backgroundTertiary))
                            .frame(height: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text("\(T("Câu")) \(vm.luot + 1)/\(vm.phien.soCau)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(vm.phien.soDaTraLoi)/\(vm.phien.soCau) \(T("đã trả lời"))")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundSecondary)
    }

    // MARK: Câu hỏi

    private func khoiCauHoi(_ c: LuotPV) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 5) {
                Text(c.nhanLoai)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.primary.opacity(0.15)))
                if let r = c.round {
                    Text("\(T("Vòng")) \(r)")
                        .font(.system(size: 9.5)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
            Text(c.questionText)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    // MARK: Ô trả lời

    @ViewBuilder private func khoiTraLoi(_ c: LuotPV) -> some View {
        if c.laMCQ {
            VStack(spacing: Spacing.sm) {
                ForEach(c.cacLuaChon) { o in
                    Button { vm.chonMCQ = o.id; vm.traLoi = o.text } label: {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: vm.chonMCQ == o.id ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(vm.chonMCQ == o.id ? AppColors.primary : AppColors.textTertiary)
                            Text(o.text)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(vm.chonMCQ == o.id ? AppColors.primary.opacity(0.10)
                                                     : AppColors.backgroundCard))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(T("Câu trả lời của bạn").uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(0.6)
                    .foregroundColor(AppColors.textTertiary)
                TextEditor(text: $vm.traLoi)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 190)
                    .padding(Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundTertiary.opacity(0.6)))
                Text("\(vm.traLoi.count) \(T("ký tự"))")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    // MARK: Kết quả một lượt

    @ViewBuilder private func khoiKetQua(_ c: LuotPV) -> some View {
        if let kq = vm.ketQua {
            if let ai = kq.aiEvaluation { khoiChamAI(ai) }
            if let det = kq.deterministic { khoiChamMay(det, coAI: kq.aiEvaluation != nil) }
            if let r = kq.referenceAnswer, !r.isEmpty {
                khoiChu(T("Đáp án tham khảo"), r, "checkmark.seal.fill", Color(hex: 0x22C55E))
            }
            if !kq.cacTieuChi.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    nhan(T("Thang chấm"), "list.bullet.clipboard")
                    ForEach(kq.cacTieuChi) { t in
                        HStack(alignment: .top, spacing: 7) {
                            Circle().fill(AppColors.textTertiary).frame(width: 4, height: 4).padding(.top, 6)
                            Text(t.label).font(.system(size: 12.5))
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if let w = t.weight {
                                Text(String(format: "%.0f%%", w * 100))
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
            }
        }
    }

    private func khoiChamAI(_ ai: ChamAI) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                nhan(T("AI chấm"), "sparkles")
                Spacer()
                if let d = ai.diem {
                    Text(String(format: "%.0f", d))
                        .font(.system(size: 22, weight: .heavy).monospacedDigit())
                        .foregroundColor(diemMau(d))
                    if let g = ai.letterGrade {
                        Text(g).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(diemMau(d)))
                    }
                }
            }
            if let s = ai.summary, !s.isEmpty {
                Text(s).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(ai.cacTieuChi) { t in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(t.id).font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if let d = t.score {
                            Text(String(format: "%.0f", d))
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundColor(diemMau(d))
                        }
                    }
                    // `whatWasMissing` là thứ đáng đọc nhất để học — hiện rõ,
                    // đừng giấu sau một nút "xem thêm".
                    if let m = t.whatWasMissing, !m.isEmpty {
                        Text(m).font(.system(size: 11.5))
                            .foregroundColor(Color(hex: 0xF59E0B))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let e = t.evidence, !e.isEmpty {
                        Text("“\(e)”").font(.system(size: 11).italic())
                            .foregroundColor(AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 3)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    @ViewBuilder private func khoiChamMay(_ d: ChamMay, coAI: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                nhan(T("Đối chiếu từ khoá"), "text.magnifyingglass")
                Spacer()
                if d.dangTin, let s = d.score {
                    Text(String(format: "%.0f", s))
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundColor(diemMau(s))
                }
            }
            // ⚠️ Máy chủ tự nói phép đo này không đáng tin (khoá khác ngôn ngữ
            // với bài làm). Hiện một con số sai ở đây là dạy sai người học.
            if !d.dangTin {
                Text(T("Phép đo này không dùng được cho câu trả lời khác ngôn ngữ với bộ khoá — bỏ qua điểm bên trên."))
                    .font(.system(size: 11)).foregroundColor(Color(hex: 0xF59E0B))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if !d.yBatBuocDaNeu.isEmpty { hangTu(T("Đã nêu"), d.yBatBuocDaNeu, Color(hex: 0x22C55E)) }
                if !d.yBatBuocBoSot.isEmpty { hangTu(T("Còn thiếu"), d.yBatBuocBoSot, Color(hex: 0xEF4444)) }
                if !d.yNenCoBoSot.isEmpty { hangTu(T("Nên có thêm"), d.yNenCoBoSot, Color(hex: 0xF59E0B)) }
                if !d.canhBao.isEmpty { hangTu(T("Nên tránh"), d.canhBao, Color(hex: 0xEF4444)) }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func hangTu(_ ten: String, _ ds: [String], _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ten).font(.system(size: 10, weight: .bold)).foregroundColor(mau)
            FlowChips(items: ds, mau: mau)
        }
    }

    private func khoiChu(_ ten: String, _ chu: String, _ hinh: String, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(ten, systemImage: hinh)
                .font(.system(size: 11, weight: .bold)).foregroundColor(mau)
            Text(chu).font(.system(size: 13.5))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func nhan(_ ten: String, _ hinh: String) -> some View {
        Label(ten, systemImage: hinh)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColors.textTertiary)
    }

    // MARK: Thanh dưới

    private var thanhDuoi: some View {
        HStack(spacing: Spacing.sm) {
            if vm.ketQua == nil {
                Button { Task { await vm.gui() } } label: {
                    HStack {
                        if vm.dangGui { ProgressView().tint(.white) }
                        Text(vm.dangGui ? T("Đang chấm…") : T("Nộp câu trả lời"))
                            .font(.system(size: 14.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(coTheNop ? AppColors.primary : AppColors.textTertiary.opacity(0.35)))
                }
                .buttonStyle(.plain)
                .disabled(!coTheNop || vm.dangGui)
            } else if vm.laCuoi {
                Button { Task { await vm.ketThuc() } } label: {
                    HStack {
                        if vm.dangKetThuc { ProgressView().tint(.white) }
                        Text(vm.dangKetThuc ? T("Đang tạo báo cáo…") : T("Kết thúc & xem báo cáo"))
                            .font(.system(size: 14.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color(hex: 0x22C55E)))
                }
                .buttonStyle(.plain)
                .disabled(vm.dangKetThuc)
            } else {
                Button { vm.moLuot(vm.luot + 1) } label: {
                    HStack {
                        Text(T("Câu tiếp theo")).font(.system(size: 14.5, weight: .bold))
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundSecondary)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(AppColors.border), alignment: .top)
    }

    private var coTheNop: Bool {
        !vm.traLoi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.chonMCQ != nil
    }
}
