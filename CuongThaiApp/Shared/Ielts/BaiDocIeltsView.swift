import SwiftUI

// MARK: - Danh sách bài đọc

struct DanhSachDocView: View {
    @ObservedObject var vm: IeltsVM

    var body: some View {
        let chang = vm.changDangXem
        List {
            ForEach(vm.baiDoc[chang] ?? []) { b in
                NavigationLink { BaiDocIeltsView(vm: vm, bai: b) } label: { dong(b, chang) }
            }
            if (vm.baiDoc[chang] ?? []).isEmpty {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Đọc"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vm.napDoc(chang) }
    }

    private func dong(_ b: BaiDocIelts, _ chang: String) -> some View {
        let xong = vm.xong(chang, "readings", b.id)
        return HStack(spacing: Spacing.sm) {
            Image(systemName: xong ? "checkmark.circle.fill" : "doc.text")
                .font(.titleMedium)
                .foregroundStyle(xong ? AppColors.success : AppColors.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.title).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                Text(b.titleVi).font(.caption).foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                Text("\(b.level) · \(b.words) \(T("từ")) · \(b.minutes) \(T("phút")) · \(b.questions.count) \(T("câu"))")
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Một bài đọc

/// Bài đọc IELTS — đọc, tô, chạm từ để hỏi, làm câu hỏi, xem bản dịch.
///
/// Ba cách tương tác với chữ, cố ý xếp theo mức "phá đọc" tăng dần:
///   1. **Chạm một từ** — nhanh nhất, không rời trang. Có trong `glossary`
///      thì hiện nghĩa ngay, không có thì hỏi AI.
///   2. **Chọn cả câu** — chạm vào số đoạn để chọn nguyên đoạn, rồi hỏi.
///   3. **Bút tô** — lớp PencilKit phủ lên, dành cho người học thích gạch
///      chân bằng Apple Pencil. Nét lưu ngay trên máy theo id bài.
///
/// ⚠️ Bản dịch nằm SAU câu hỏi, và mặc định đóng. Mở sẵn bản dịch thì người
/// học đọc tiếng Việt rồi đoán đáp án, và bài đọc mất sạch tác dụng.
struct BaiDocIeltsView: View {
    @ObservedObject var vm: IeltsVM
    let bai: BaiDocIelts

    @State private var choseWord: ChuDaChon?
    @State private var hienDich = false
    @State private var hienTuKho = false
    @State private var dangTo = false
    @State private var traLoi: [String: String] = [:]
    @State private var daNop = false
    @State private var coBut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                dauBai
                if !bai.strategy.isEmpty { khoiMeo }
                khoiChu
                if !bai.glossary.isEmpty { khoiTuKho }
                khoiCauHoi
                khoiDich
                nutXong
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(bai.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Nút bút CHỈ hiện khi máy có Apple Pencil từng chạm vào —
                // trên iPhone nó chỉ là một nút chiếm chỗ và không ai dùng.
                if coBut {
                    Button { dangTo.toggle() } label: {
                        Image(systemName: dangTo ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                            .foregroundStyle(dangTo ? AppColors.primary : AppColors.textSecondary)
                    }
                    .accessibilityLabel(T("Bút tô"))
                }
            }
        }
        .sheet(item: $choseWord) { c in
            HoiVeChuView(chu: c.chu, boiCanh: c.boiCanh, tuKho: tuKho(c.chu))
        }
        .task { coBut = LopToIelts.coBut() }
    }

    // MARK: Đầu bài

    private var dauBai: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bai.titleVi).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
            HStack(spacing: 6) {
                nhan(bai.level, AppColors.primary)
                nhan("\(bai.words) \(T("từ"))", AppColors.secondary)
                nhan("\(bai.minutes) \(T("phút"))", AppColors.accent)
            }
            Text(T("Chạm vào một từ bất kỳ để tra nghĩa hoặc hỏi AI."))
                .font(.caption2).foregroundStyle(AppColors.textTertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nhan(_ t: String, _ m: Color) -> some View {
        Text(t).font(.caption2).foregroundStyle(m)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(m.opacity(0.14)).cornerRadius(CornerRadius.full)
    }

    // MARK: Mẹo

    private var khoiMeo: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bai.strategy, id: \.self) { s in
                    HStack(alignment: .top, spacing: 7) {
                        Text("•").foregroundStyle(AppColors.primary)
                        Text(s).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            Label(T("Mẹo làm dạng đề trong bài này"), systemImage: "lightbulb.fill")
                .font(.captionBold).foregroundStyle(AppColors.warning)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Thân bài — chữ chạm được + lớp tô

    private var khoiChu: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(bai.paragraphs, id: \.label) { d in
                VStack(alignment: .leading, spacing: 5) {
                    Button {
                        choseWord = ChuDaChon(chu: d.text, boiCanh: "\(bai.title)\n\n\(d.text)")
                    } label: {
                        Text("\(T("Đoạn")) \(d.label)")
                            .font(.captionBold).foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)

                    ChuChamDuoc(chu: d.text) { tu in
                        choseWord = ChuDaChon(chu: tu, boiCanh: "\(bai.title)\n\n\(d.text)")
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
        // Lớp tô nằm TRÊN chữ và chỉ nhận chạm khi đang bật — không thì nó
        // nuốt mọi cú chạm vào từ, và người dùng tưởng tính năng tra từ hỏng.
        .overlay {
            if dangTo {
                LopToIelts(maBai: bai.id)
                    .cornerRadius(CornerRadius.large)
            }
        }
    }

    // MARK: Từ khó

    private var khoiTuKho: some View {
        DisclosureGroup(isExpanded: $hienTuKho) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(bai.glossary) { t in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.en).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                            Text(t.ipa).font(.caption2).foregroundStyle(AppColors.textTertiary)
                        }
                        .frame(width: 130, alignment: .leading)
                        Text(t.vi).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button { DocTu.shared.doc(t.en, code: "en") } label: {
                            Image(systemName: "speaker.wave.2").font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("\(T("Từ khó")) (\(bai.glossary.count))", systemImage: "character.book.closed.fill")
                .font(.captionBold).foregroundStyle(AppColors.secondary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Câu hỏi

    private var khoiCauHoi: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("\(T("Câu hỏi")) (\(bai.questions.count))")
                    .font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                Spacer()
                if daNop {
                    Text("\(soDung)/\(bai.questions.count) \(T("đúng"))")
                        .font(.captionBold)
                        .foregroundStyle(soDung == bai.questions.count ? AppColors.success : AppColors.warning)
                }
            }

            ForEach(Array(bai.questions.enumerated()), id: \.element.id) { i, c in
                MotCauHoiDoc(so: i + 1, cau: c, daNop: daNop,
                             traLoi: Binding(
                                get: { traLoi[c.id] ?? "" },
                                set: { traLoi[c.id] = $0 }))
            }

            Button {
                withAnimation { daNop.toggle() }
            } label: {
                Text(daNop ? T("Làm lại") : T("Nộp bài"))
                    .font(.buttonText).frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm + 2)
                    .background(daNop ? AppColors.backgroundTertiary : AppColors.primary)
                    .foregroundStyle(daNop ? AppColors.textPrimary : Color.white)
                    .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(.plain)
            .disabled(traLoi.isEmpty && !daNop)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var soDung: Int {
        bai.questions.filter { $0.dung(traLoi[$0.id] ?? "") }.count
    }

    // MARK: Bản dịch

    private var khoiDich: some View {
        DisclosureGroup(isExpanded: $hienDich) {
            Text(bai.translation)
                .font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        } label: {
            Label(T("Bản dịch tiếng Việt"), systemImage: "character.bubble")
                .font(.captionBold).foregroundStyle(AppColors.textSecondary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: Xong

    private var nutXong: some View {
        let xong = vm.xong(vm.changDangXem, "readings", bai.id)
        return Button {
            Task {
                await vm.doiXong(vm.changDangXem, "readings", bai.id, !xong,
                                 diem: daNop ? Int(Double(soDung) / Double(max(1, bai.questions.count)) * 100) : nil)
            }
        } label: {
            Label(xong ? T("Đã học xong bài này") : T("Đánh dấu đã học xong"),
                  systemImage: xong ? "checkmark.circle.fill" : "circle")
                .font(.buttonText).frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm + 2)
                .background(xong ? AppColors.success.opacity(0.15) : AppColors.backgroundTertiary)
                .foregroundStyle(xong ? AppColors.success : AppColors.textPrimary)
                .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private func tuKho(_ chu: String) -> TuKho? {
        let t = chu.trimmingCharacters(in: .punctuationCharacters).lowercased()
        return bai.glossary.first { $0.en.lowercased() == t }
    }
}

/// Chữ người học vừa chọn, kèm bối cảnh để AI trả lời đúng nghĩa đang dùng.
struct ChuDaChon: Identifiable {
    let id = UUID()
    let chu: String
    let boiCanh: String
}

// MARK: - Một câu hỏi đọc

private struct MotCauHoiDoc: View {
    let so: Int
    let cau: CauHoiDoc
    let daNop: Bool
    @Binding var traLoi: String

    private var dung: Bool { cau.dung(traLoi) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: 7) {
                Text("\(so).").font(.captionBold).foregroundStyle(AppColors.textTertiary)
                Text(cau.q).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if daNop {
                    Image(systemName: dung ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(dung ? AppColors.success : AppColors.error)
                }
            }

            if cau.phaiGo {
                TextField(T("Gõ đáp án lấy TỪ TRONG BÀI"), text: $traLoi)
                    .font(.bodyMedium)
                    .padding(Spacing.sm)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.medium)
                    .disabled(daNop)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif
            } else {
                // Cuộn ngang: "NOT GIVEN" cạnh hai lựa chọn nữa là tràn trên
                // iPhone, mà xuống dòng giữa chừng thì đọc ra nghĩa khác.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(cau.luaChon, id: \.self) { o in
                            Button { if !daNop { traLoi = o } } label: {
                                Text(o).font(.bodySmall)
                                    .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 7)
                                    .background(mauNen(o))
                                    .foregroundStyle(traLoi == o ? Color.white : AppColors.textPrimary)
                                    .cornerRadius(CornerRadius.full)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            if daNop {
                VStack(alignment: .leading, spacing: 4) {
                    if !dung {
                        Text("\(T("Đáp án")): \(cau.answer)")
                            .font(.captionBold).foregroundStyle(AppColors.success)
                    }
                    Text(cau.why).font(.caption).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let wn = cau.whyNot, !wn.isEmpty {
                        Text(wn).font(.caption2).foregroundStyle(AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.medium)
            }
        }
        .padding(.vertical, 4)
    }

    private func mauNen(_ o: String) -> Color {
        guard daNop else { return traLoi == o ? AppColors.primary : AppColors.backgroundTertiary }
        if o.lowercased() == cau.answer.lowercased() { return AppColors.success }
        if traLoi == o { return AppColors.error }
        return AppColors.backgroundTertiary
    }
}
