import SwiftUI

// MARK: - NGHE

struct DanhSachNgheView: View {
    @ObservedObject var vm: IeltsVM

    var body: some View {
        let chang = vm.changDangXem
        List {
            ForEach(vm.baiNghe[chang] ?? []) { b in
                NavigationLink { BaiNgheView(vm: vm, bai: b) } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: vm.xong(chang, "listenings", b.id) ? "checkmark.circle.fill" : "headphones")
                            .font(.titleMedium)
                            .foregroundStyle(vm.xong(chang, "listenings", b.id) ? AppColors.success : AppColors.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.title).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                            Text(b.titleVi).font(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(1)
                            Text("\(b.kind) · \(b.level) · \(b.questions.count) \(T("câu"))")
                                .font(.caption2).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if (vm.baiNghe[chang] ?? []).isEmpty {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }.listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Nghe"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vm.napNghe(chang) }
    }
}

/// Một bài nghe. Không có tệp âm thanh — máy tự đọc transcript bằng giọng hệ
/// thống, đúng cách trang web đang làm.
///
/// ⚠️ Transcript ẩn mặc định. Hiện sẵn thì người học ĐỌC chứ không nghe, và
/// bài nghe thành bài đọc có tiếng nền.
struct BaiNgheView: View {
    @ObservedObject var vm: IeltsVM
    let bai: BaiNgheIelts

    @State private var hienLoiThoai = false
    @State private var traLoi: [String: String] = [:]
    @State private var daNop = false
    @State private var dangPhat = false
    @State private var dongDangDoc: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                khoiBoiCanh
                khoiNut
                if !bai.listenFor.isEmpty { khoiTuKhoa }
                khoiCauHoi
                khoiLoiThoai
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
        .onDisappear { DocTu.shared.dung() }
    }

    private var khoiBoiCanh: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(bai.titleVi).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
            Text(bai.context).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiNut: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                if dangPhat { dung() } else { phat() }
            } label: {
                Label(dangPhat ? T("Dừng") : T("Nghe"), systemImage: dangPhat ? "stop.fill" : "play.fill")
                    .font(.buttonText).frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm + 2)
                    .background(dangPhat ? AppColors.error : AppColors.primary)
                    .foregroundStyle(Color.white)
                    .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(.plain)

            Button { phat(chamHon: true) } label: {
                Label(T("Chậm"), systemImage: "tortoise.fill")
                    .font(.buttonSmall)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm + 2)
                    .background(AppColors.backgroundTertiary)
                    .foregroundStyle(AppColors.textPrimary)
                    .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(.plain)
        }
    }

    private var khoiTuKhoa: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(T("Cần bắt được"), systemImage: "ear.fill")
                .font(.captionBold).foregroundStyle(AppColors.secondary)
            LuongChu(dongCach: 6, tuCach: 6) {
                ForEach(bai.listenFor, id: \.self) { t in
                    Text(t).font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppColors.secondary.opacity(0.14))
                        .foregroundStyle(AppColors.textPrimary)
                        .cornerRadius(CornerRadius.full)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiCauHoi: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("\(T("Câu hỏi")) (\(bai.questions.count))")
                    .font(.titleSmall).foregroundStyle(AppColors.textPrimary)
                Spacer()
                if daNop {
                    Text("\(soDung)/\(bai.questions.count)")
                        .font(.captionBold)
                        .foregroundStyle(soDung == bai.questions.count ? AppColors.success : AppColors.warning)
                }
            }
            ForEach(Array(bai.questions.enumerated()), id: \.element.id) { i, c in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 7) {
                        Text("\(i + 1).").font(.captionBold).foregroundStyle(AppColors.textTertiary)
                        Text(c.q).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if daNop {
                            Image(systemName: c.dung(traLoi[c.id] ?? "") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(c.dung(traLoi[c.id] ?? "") ? AppColors.success : AppColors.error)
                        }
                    }
                    TextField(T("Gõ đáp án"), text: Binding(
                        get: { traLoi[c.id] ?? "" }, set: { traLoi[c.id] = $0 }))
                        .font(.bodyMedium)
                        .padding(Spacing.sm)
                        .background(AppColors.backgroundTertiary)
                        .cornerRadius(CornerRadius.medium)
                        .disabled(daNop)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        #endif
                    if daNop {
                        VStack(alignment: .leading, spacing: 3) {
                            if !c.dung(traLoi[c.id] ?? "") {
                                Text("\(T("Đáp án")): \(c.answer)")
                                    .font(.captionBold).foregroundStyle(AppColors.success)
                            }
                            Text(c.why).font(.caption).foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.backgroundTertiary)
                        .cornerRadius(CornerRadius.medium)
                    }
                }
                .padding(.vertical, 3)
            }
            Button { withAnimation { daNop.toggle() } } label: {
                Text(daNop ? T("Làm lại") : T("Nộp bài"))
                    .font(.buttonText).frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm + 2)
                    .background(daNop ? AppColors.backgroundTertiary : AppColors.primary)
                    .foregroundStyle(daNop ? AppColors.textPrimary : Color.white)
                    .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiLoiThoai: some View {
        DisclosureGroup(isExpanded: $hienLoiThoai) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(bai.lines.enumerated()), id: \.offset) { i, l in
                    HStack(alignment: .top, spacing: 7) {
                        Text(l.who).font(.captionBold).foregroundStyle(AppColors.primary)
                            .frame(width: 66, alignment: .leading)
                        Text(l.text).font(.bodySmall)
                            .foregroundStyle(dongDangDoc == i ? AppColors.primary : AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label(T("Lời thoại (mở sau khi đã làm xong)"), systemImage: "text.quote")
                .font(.captionBold).foregroundStyle(AppColors.textSecondary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var nutXong: some View {
        let xong = vm.xong(vm.changDangXem, "listenings", bai.id)
        return Button {
            Task {
                await vm.doiXong(vm.changDangXem, "listenings", bai.id, !xong,
                                 diem: daNop ? Int(Double(soDung) / Double(max(1, bai.questions.count)) * 100) : nil)
            }
        } label: {
            Label(xong ? T("Đã học xong") : T("Đánh dấu đã học xong"),
                  systemImage: xong ? "checkmark.circle.fill" : "circle")
                .font(.buttonText).frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm + 2)
                .background(xong ? AppColors.success.opacity(0.15) : AppColors.backgroundTertiary)
                .foregroundStyle(xong ? AppColors.success : AppColors.textPrimary)
                .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private var soDung: Int { bai.questions.filter { $0.dung(traLoi[$0.id] ?? "") }.count }

    private func phat(chamHon: Bool = false) {
        dung()
        dangPhat = true
        // Đọc CẢ bài một lượt, kèm tên người nói: đề thi thật cũng đọc liền
        // mạch, và cắt từng dòng cho người học bấm từng nút là luyện sai nhịp.
        let chu = bai.lines.map { "\($0.who). \($0.text)" }.joined(separator: " ... ")
        DocTu.shared.doc(chu, code: "en", chamHon: chamHon)
        // Không có tín hiệu "đọc xong" từ `DocTu`, nên nút tự trả về trạng
        // thái nghỉ theo độ dài ước lượng: ~2,6 từ mỗi giây ở tốc độ thường.
        let soTu = Double(chu.split(separator: " ").count)
        let giay = soTu / (chamHon ? 1.7 : 2.6) + 2
        DispatchQueue.main.asyncAfter(deadline: .now() + giay) { dangPhat = false }
    }

    private func dung() {
        DocTu.shared.dung()
        dangPhat = false
        dongDangDoc = nil
    }
}

// MARK: - VIẾT

struct DanhSachVietView: View {
    @ObservedObject var vm: IeltsVM

    var body: some View {
        let chang = vm.changDangXem
        List {
            ForEach(vm.deViet[chang] ?? []) { d in
                NavigationLink { DeVietView(vm: vm, de: d) } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: vm.xong(chang, "writings", d.id) ? "checkmark.circle.fill" : "pencil.and.outline")
                            .font(.titleMedium)
                            .foregroundStyle(vm.xong(chang, "writings", d.id) ? AppColors.success : AppColors.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.title).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                            Text("\(d.task) · \(d.minWords)+ \(T("từ")) · \(d.minutes) \(T("phút"))")
                                .font(.caption2).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if (vm.deViet[chang] ?? []).isEmpty {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }.listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Viết"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vm.napViet(chang) }
    }
}

/// Một đề viết: đề bài → dàn ý → cụm từ dùng được → người học viết → bài mẫu.
///
/// ⚠️ Bài mẫu đóng mặc định và nằm CUỐI. Đọc mẫu trước khi viết thì người học
/// chép ý của mẫu, và bài viết ra không phản ánh trình độ thật của họ.
struct DeVietView: View {
    @ObservedObject var vm: IeltsVM
    let de: DeVietIelts

    @State private var baiViet = ""
    @State private var hienMau = false
    @State private var hienLoi = false

    private var soTu: Int {
        baiViet.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                khoiDe
                khoiDanY
                if !de.phrases.isEmpty { khoiCumTu }
                khoiViet
                if !de.mistakes.isEmpty { khoiLoi }
                khoiMau
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(de.task)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var khoiDe: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(de.prompt).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(de.promptVi).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(T("Tối thiểu")) \(de.minWords) \(T("từ")) · \(de.minutes) \(T("phút"))")
                .font(.caption2).foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiDanY: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(T("Dàn ý từng đoạn"), systemImage: "list.number")
                .font(.captionBold).foregroundStyle(AppColors.primary)
            ForEach(de.outline, id: \.part) { o in
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.part).font(.captionBold).foregroundStyle(AppColors.textPrimary)
                    Text(o.what).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiCumTu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(T("Cụm dùng được ngay"), systemImage: "text.badge.plus")
                .font(.captionBold).foregroundStyle(AppColors.secondary)
            ForEach(de.phrases) { c in
                Button {
                    // Chèn vào đúng chỗ con trỏ là việc của `TextEditor`;
                    // nối vào cuối là hành vi đoán được và không mất chữ.
                    baiViet += (baiViet.isEmpty ? "" : " ") + c.en
                    Haptics.cham()
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.en).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                        Text(c.vi).font(.caption2).foregroundStyle(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiViet: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(T("Bài của bạn"), systemImage: "square.and.pencil")
                    .font(.captionBold).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(soTu)/\(de.minWords) \(T("từ"))")
                    .font(.captionBold)
                    .foregroundStyle(soTu >= de.minWords ? AppColors.success : AppColors.textTertiary)
            }
            TextEditor(text: $baiViet)
                .font(.bodyMedium)
                .frame(minHeight: 220)
                .padding(Spacing.sm)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.medium)
                .scrollContentBackground(.hidden)

            if soTu > 0 {
                NavigationLink {
                    ChamVietIeltsView(chu: baiViet, de: de.prompt)
                } label: {
                    Label(T("Nhờ AI chấm theo 4 tiêu chí IELTS"), systemImage: "sparkles")
                        .font(.buttonSmall).frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm + 2)
                        .background(AppColors.primary)
                        .foregroundStyle(Color.white)
                        .cornerRadius(CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiLoi: some View {
        DisclosureGroup(isExpanded: $hienLoi) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(de.mistakes) { m in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("✗ \(m.wrong)").font(.bodySmall).foregroundStyle(AppColors.error)
                        Text("✓ \(m.right)").font(.bodySmall).foregroundStyle(AppColors.success)
                        Text(m.why).font(.caption2).foregroundStyle(AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label(T("Lỗi người Việt hay mắc ở đề này"), systemImage: "exclamationmark.triangle.fill")
                .font(.captionBold).foregroundStyle(AppColors.warning)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private var khoiMau: some View {
        DisclosureGroup(isExpanded: $hienMau) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Band \(de.sample.band)").font(.captionBold).foregroundStyle(AppColors.success)
                Text(de.sample.text).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let n = de.sample.note, !n.isEmpty {
                    Text(n).font(.caption).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 8)
        } label: {
            Label(T("Bài mẫu — mở SAU khi đã tự viết"), systemImage: "doc.text.magnifyingglass")
                .font(.captionBold).foregroundStyle(AppColors.textSecondary)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }
}

// MARK: - NÓI

struct DanhSachNoiView: View {
    @ObservedObject var vm: IeltsVM

    var body: some View {
        let chang = vm.changDangXem
        let ds = vm.chuDeNoi[chang] ?? []
        List {
            ForEach(["Part 1", "Part 2", "Part 3"], id: \.self) { p in
                let trong = ds.filter { $0.part.contains(p.suffix(1)) }
                if !trong.isEmpty {
                    Section(p) {
                        ForEach(trong) { t in
                            NavigationLink { ChuDeNoiView(vm: vm, chuDe: t) } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: vm.xong(chang, "speakings", t.id) ? "checkmark.circle.fill" : "mic")
                                        .foregroundStyle(vm.xong(chang, "speakings", t.id) ? AppColors.success : AppColors.textTertiary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.title).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                                        Text("\(t.titleVi) · \(t.questions.count) \(T("câu"))")
                                            .font(.caption2).foregroundStyle(AppColors.textTertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if ds.isEmpty {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }.listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Nói"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vm.napNoi(chang) }
    }
}

/// Một chủ đề nói. Mỗi câu hỏi có **câu trả lời cụt** (band 4) đặt cạnh **câu
/// trả lời đủ ý** — nhìn cái kém mới thấy vì sao cái kia được điểm cao hơn.
struct ChuDeNoiView: View {
    @ObservedObject var vm: IeltsVM
    let chuDe: ChuDeNoiIelts
    @State private var moCau: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chuDe.part).font(.captionBold).foregroundStyle(AppColors.primary)
                    Text(chuDe.titleVi).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(AppColors.backgroundCard)
                .cornerRadius(CornerRadius.large)

                NavigationLink { LuyenNoiIeltsView(chuDe: chuDe) } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 30)).foregroundStyle(AppColors.primary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(T("Luyện nói với giám khảo")).font(.titleSmall)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(T("Robot hỏi bằng giọng nói, bạn trả lời, AI chấm theo tiêu chí Speaking"))
                                .font(.caption).foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [AppColors.primary.opacity(0.14), AppColors.secondary.opacity(0.10)],
                                               startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(CornerRadius.large)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(chuDe.questions) { c in MotCauNoi(cau: c, mo: moCau == c.id) { moCau = moCau == c.id ? nil : c.id } }

                if let ph = chuDe.phrases, !ph.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(T("Cụm nối câu"), systemImage: "link")
                            .font(.captionBold).foregroundStyle(AppColors.secondary)
                        ForEach(ph) { c in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.en).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                                Text(c.vi).font(.caption2).foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(CornerRadius.large)
                }

                nutXong
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(chuDe.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { DocTu.shared.dung() }
    }

    private var nutXong: some View {
        let xong = vm.xong(vm.changDangXem, "speakings", chuDe.id)
        return Button {
            Task { await vm.doiXong(vm.changDangXem, "speakings", chuDe.id, !xong) }
        } label: {
            Label(xong ? T("Đã luyện xong") : T("Đánh dấu đã luyện xong"),
                  systemImage: xong ? "checkmark.circle.fill" : "circle")
                .font(.buttonText).frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm + 2)
                .background(xong ? AppColors.success.opacity(0.15) : AppColors.backgroundTertiary)
                .foregroundStyle(xong ? AppColors.success : AppColors.textPrimary)
                .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }
}

private struct MotCauNoi: View {
    let cau: CauHoiNoi
    let mo: Bool
    let bam: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button(action: bam) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cau.q).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(cau.qVi).font(.caption).foregroundStyle(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: mo ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(AppColors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: Spacing.sm) {
                Button { DocTu.shared.doc(cau.q, code: "en") } label: {
                    Label(T("Nghe câu hỏi"), systemImage: "speaker.wave.2.fill").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(AppColors.primary)
                Spacer()
            }

            if mo {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    khoiTraLoi("✗ " + T("Cụt — band thấp"), cau.weak, AppColors.error, nil)
                    khoiTraLoi("✓ " + T("Đủ ý"), cau.good, AppColors.success, cau.goodVi)
                    Text(cau.why).font(.caption).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(CornerRadius.large)
    }

    private func khoiTraLoi(_ nhan: String, _ chu: String, _ mau: Color, _ dich: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(nhan).font(.captionBold).foregroundStyle(mau)
                Spacer()
                Button { DocTu.shared.doc(chu, code: "en") } label: {
                    Image(systemName: "speaker.wave.2").font(.caption2)
                }
                .buttonStyle(.plain).foregroundStyle(AppColors.textTertiary)
            }
            Text(chu).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let d = dich {
                Text(d).font(.caption2).foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mau.opacity(0.08))
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - TỪ VỰNG

struct TuVungIeltsView: View {
    @ObservedObject var vm: IeltsVM
    @State private var chuDeMo: String?

    var body: some View {
        let chang = vm.changDangXem
        List {
            ForEach(vm.tuVung[chang]?.topics ?? []) { t in
                Section {
                    if chuDeMo == t.id {
                        ForEach(t.words) { w in dongTu(w, chang) }
                    }
                } header: {
                    Button {
                        withAnimation { chuDeMo = chuDeMo == t.id ? nil : t.id }
                    } label: {
                        HStack {
                            Text("\(t.icon) \(t.title)").font(.captionBold)
                            Spacer()
                            Text("\(soXong(t, chang))/\(t.words.count)")
                                .font(.caption2).foregroundStyle(AppColors.textTertiary)
                            Image(systemName: chuDeMo == t.id ? "chevron.up" : "chevron.down").font(.caption2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if (vm.tuVung[chang]?.topics ?? []).isEmpty {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }.listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Từ vựng"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vm.napTuVung(chang) }
    }

    private func soXong(_ t: ChuDeTuIelts, _ chang: String) -> Int {
        t.words.filter { vm.xong(chang, "vocab", $0.en) }.count
    }

    private func dongTu(_ w: TuVungIelts, _ chang: String) -> some View {
        let thuoc = vm.xong(chang, "vocab", w.en)
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Button {
                Task { await vm.doiXong(chang, "vocab", w.en, !thuoc) }
            } label: {
                Image(systemName: thuoc ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(thuoc ? AppColors.success : AppColors.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(w.en).font(.bodyLarge).foregroundStyle(AppColors.textPrimary)
                    if let p = w.pos, !p.isEmpty {
                        Text(p).font(.caption2).foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(AppColors.primary.opacity(0.14)).cornerRadius(4)
                    }
                    Text(w.ipa).font(.caption2).foregroundStyle(AppColors.textTertiary)
                }
                Text(w.vi).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
                Text(w.ex).font(.caption).foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(w.exVi).font(.caption2).foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { DocTu.shared.doc(w.en, code: "en") } label: {
                Image(systemName: "speaker.wave.2").font(.caption)
            }
            .buttonStyle(.plain).foregroundStyle(AppColors.primary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - BÀI HỌC

struct BaiHocIeltsView: View {
    @ObservedObject var vm: IeltsVM

    var body: some View {
        let chang = vm.changDangXem
        List {
            ForEach(vm.chuDiem[chang] ?? []) { cd in
                Section("\(cd.icon ?? "📘") \(cd.title)") {
                    ForEach(cd.lessons) { b in
                        NavigationLink { MotBaiHocView(vm: vm, bai: b) } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: vm.xong(chang, "units", b.id) ? "checkmark.circle.fill" : "book")
                                    .foregroundStyle(vm.xong(chang, "units", b.id) ? AppColors.success : AppColors.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(b.title).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                                    if let g = b.goal, !g.isEmpty {
                                        Text(g).font(.caption2).foregroundStyle(AppColors.textTertiary).lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if (vm.chuDiem[chang] ?? []).isEmpty {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }.listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("Bài học"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await vm.napBaiHoc(chang) }
    }
}

struct MotBaiHocView: View {
    @ObservedObject var vm: IeltsVM
    let bai: BaiHocIelts

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let g = bai.goal, !g.isEmpty {
                    Text(g).font(.bodyMedium).foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                        .background(AppColors.backgroundCard)
                        .cornerRadius(CornerRadius.large)
                }

                ForEach(Array((bai.grammar ?? []).enumerated()), id: \.offset) { _, g in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if let f = g.formula, !f.isEmpty {
                            Text(f).font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppColors.primary)
                                .padding(Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.primary.opacity(0.10))
                                .cornerRadius(CornerRadius.medium)
                        }
                        Text(g.explain).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(g.examples) { e in
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(e.en).font(.bodySmall).foregroundStyle(AppColors.textPrimary)
                                    Spacer()
                                    Button { DocTu.shared.doc(e.en, code: "en") } label: {
                                        Image(systemName: "speaker.wave.2").font(.caption2)
                                    }
                                    .buttonStyle(.plain).foregroundStyle(AppColors.textTertiary)
                                }
                                Text(e.vi).font(.caption2).foregroundStyle(AppColors.textTertiary)
                            }
                        }
                        if let m = g.mistake {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("✗ \(m.wrong)").font(.caption).foregroundStyle(AppColors.error)
                                Text("✓ \(m.right)").font(.caption).foregroundStyle(AppColors.success)
                                Text(m.why).font(.caption2).foregroundStyle(AppColors.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.warning.opacity(0.10))
                            .cornerRadius(CornerRadius.medium)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(CornerRadius.large)
                }

                if let w = bai.words, !w.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(T("Từ của bài"), systemImage: "character.book.closed.fill")
                            .font(.captionBold).foregroundStyle(AppColors.secondary)
                        ForEach(w) { t in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.en).font(.bodyMedium).foregroundStyle(AppColors.textPrimary)
                                    Text(t.ipa).font(.caption2).foregroundStyle(AppColors.textTertiary)
                                }
                                .frame(width: 120, alignment: .leading)
                                Text(t.vi).font(.bodySmall).foregroundStyle(AppColors.textSecondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(CornerRadius.large)
                }

                let xong = vm.xong(vm.changDangXem, "units", bai.id)
                Button {
                    Task { await vm.doiXong(vm.changDangXem, "units", bai.id, !xong) }
                } label: {
                    Label(xong ? T("Đã học xong") : T("Đánh dấu đã học xong"),
                          systemImage: xong ? "checkmark.circle.fill" : "circle")
                        .font(.buttonText).frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm + 2)
                        .background(xong ? AppColors.success.opacity(0.15) : AppColors.backgroundTertiary)
                        .foregroundStyle(xong ? AppColors.success : AppColors.textPrimary)
                        .cornerRadius(CornerRadius.medium)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(bai.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { DocTu.shared.dung() }
    }
}
