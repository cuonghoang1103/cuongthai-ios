import SwiftUI

// ════════════════════════════════════════════════════════════════
// BỐN MỤC NỘI DUNG: ngữ pháp · hội thoại · bài đọc · hỏi đáp
// ════════════════════════════════════════════════════════════════

// ── Ngữ pháp ────────────────────────────────────────────────────

struct NguPhapView: View {
    let ngonNgu: NgonNgu
    @State private var muc: [NguPhap] = []
    @State private var cap: [String] = []
    @State private var capChon: String?
    @State private var dangTai = true
    @State private var conNua = true
    @State private var trang = 1
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if !cap.isEmpty { thanhLoc }

                if dangTai && muc.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(muc) { g in
                            NavigationLink(destination: NguPhapChiTietView(g: g, code: ngonNgu.code)) {
                                hang(g)
                            }
                            .buttonStyle(.plain)
                        }
                        if conNua && !muc.isEmpty {
                            ProgressView().padding(.vertical, Spacing.md)
                                .onAppear { Task { await tai() } }
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Ngữ pháp")
        .navigationBarTitleDisplayMode(.inline)
        .task { if muc.isEmpty { await tai() } }
    }

    private var thanhLoc: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(cap, id: \.self) { c in
                    let chon = capChon == c
                    Button {
                        capChon = chon ? nil : c
                        Task { await tai(lai: true) }
                        Haptics.cham()
                    } label: {
                        Text(c)
                            .font(.system(size: 13, weight: chon ? .semibold : .regular))
                            .foregroundColor(chon ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 13).padding(.vertical, 6)
                            .background(Capsule().fill(chon ? AppColors.primary
                                                            : AppColors.backgroundTertiary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func hang(_ g: NguPhap) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let lv = g.level {
                        Text(lv)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.primary))
                    }
                    Text(g.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                }
                if let st = g.structure, !st.isEmpty {
                    Text(st)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func tai(lai: Bool = false) async {
        if lai { trang = 1; muc = []; conNua = true }
        guard conNua else { return }
        dangTai = true; defer { dangTai = false }
        do {
            // ⚠️ Ngữ pháp KHÔNG trả mảng ở `data` như ba mục kia — nó trả
            // `{ items, levels }`. Dùng `requestList` ở đây là giải mã hỏng.
            let goi: GoiNguPhap = try await APIClient.shared
                .request(.nguPhap(code: ngonNgu.code, level: capChon, page: trang, limit: 30))
            muc.append(contentsOf: goi.items)
            if cap.isEmpty { cap = goi.levels ?? [] }
            conNua = goi.items.count >= 30
            trang += 1
            loi = nil
        } catch { loi = error.localizedDescription; conNua = false }
    }
}

struct NguPhapChiTietView: View {
    let g: NguPhap
    let code: String
    @ObservedObject private var doc = DocTu.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let st = g.structure, !st.isEmpty {
                    khoi("Cấu trúc") {
                        Text(st)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let ex = g.explanation, !ex.isEmpty {
                    khoi("Giải thích") { ChuHTMLView(html: ex) }
                }

                if let vd = g.examples, !vd.isEmpty {
                    khoi("Ví dụ") {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            ForEach(Array(vd.enumerated()), id: \.offset) { i, v in
                                viDu(v, i)
                            }
                        }
                    }
                }

                if let cm = g.commonMistakes, !cm.isEmpty {
                    khoi("Lỗi hay gặp") {
                        ChuHTMLView(html: cm, mau: AppColors.warning)
                    }
                }
                if let cw = g.comparedWith, !cw.isEmpty {
                    khoi("So sánh") { ChuHTMLView(html: cw) }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(g.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func viDu(_ v: NguPhap.ViDu, _ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(v.sentence ?? "")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if DocTu.doDuoc(code), let s = v.sentence, !s.isEmpty {
                    Button {
                        doc.doc(s, code: code, id: i)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 30, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Nghe câu ví dụ")
                }
            }
            if let p = v.pronunciation, !p.isEmpty {
                Text(p).font(.system(size: 12)).foregroundColor(AppColors.secondary)
            }
            if let m = v.meaningVi, !m.isEmpty {
                Text(m).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func khoi<C: View>(_ ten: String, @ViewBuilder _ noi: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(ten.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
                .kerning(0.6)
            noi()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }
}

// ── Hội thoại ───────────────────────────────────────────────────

struct HoiThoaiView: View {
    let ngonNgu: NgonNgu
    @State private var muc: [HoiThoai] = []
    @State private var dangTai = true
    @State private var conNua = true
    @State private var trang = 1
    @State private var hienNghia: Set<Int> = []
    @ObservedObject private var doc = DocTu.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                if dangTai && muc.isEmpty {
                    ProgressView().padding(.top, Spacing.xl)
                }
                ForEach(muc) { h in the(h) }
                if conNua && !muc.isEmpty {
                    ProgressView().padding(.vertical, Spacing.md)
                        .onAppear { Task { await tai() } }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Hội thoại")
        .navigationBarTitleDisplayMode(.inline)
        .task { if muc.isEmpty { await tai() } }
    }

    private func the(_ h: HoiThoai) -> some View {
        let mo = hienNghia.contains(h.id)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            dong(h.question, h.questionPronunciation, hoi: true, id: h.id * 2)
            if let a = h.answer, !a.isEmpty {
                dong(a, h.answerPronunciation, hoi: false, id: h.id * 2 + 1)
            }

            // Nghĩa tiếng Việt ẨN cho tới khi bấm. Hiện sẵn thì mắt đọc
            // thẳng dòng tiếng Việt và bỏ qua câu đang học.
            if mo {
                if let m = h.meaningVi, !m.isEmpty {
                    Text(m)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let n = h.note, !n.isEmpty {
                    Text(n)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if mo { hienNghia.remove(h.id) } else { hienNghia.insert(h.id) }
                }
            } label: {
                Text(mo ? "Ẩn nghĩa" : "Xem nghĩa")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
    }

    private func dong(_ chu: String, _ pa: String?, hoi: Bool, id: Int) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(hoi ? AppColors.secondary : AppColors.primary)
                .frame(width: 7, height: 7)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(chu)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let p = pa, !p.isEmpty {
                    Text(p).font(.system(size: 12)).foregroundColor(AppColors.secondary)
                }
            }
            Spacer(minLength: 0)
            if DocTu.doDuoc(ngonNgu.code) {
                Button {
                    doc.doc(chu, code: ngonNgu.code, id: id)
                } label: {
                    Image(systemName: doc.dangDoc == id ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nghe câu này")
            }
        }
    }

    private func tai() async {
        guard conNua else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let (ds, _, con): ([HoiThoai], Int?, Bool) = try await APIClient.shared
                .requestList(.hoiThoai(code: ngonNgu.code, page: trang, limit: 30))
            muc.append(contentsOf: ds); conNua = con; trang += 1
        } catch { conNua = false }
    }
}

// ── Bài đọc ─────────────────────────────────────────────────────

struct BaiDocView: View {
    let ngonNgu: NgonNgu
    @State private var muc: [BaiDoc] = []
    @State private var dangTai = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if dangTai && muc.isEmpty { ProgressView().padding(.top, Spacing.xl) }
                ForEach(muc) { b in
                    NavigationLink(destination: BaiDocChiTietView(b: b, code: ngonNgu.code)) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.secondary)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                if let lv = b.level {
                                    Text(lv).font(.system(size: 11))
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundCard))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Bài đọc")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if muc.isEmpty {
                dangTai = true
                let r: ([BaiDoc], Int?, Bool)? = try? await APIClient.shared
                    .requestList(.baiDoc(code: ngonNgu.code, page: 1, limit: 50))
                muc = r?.0 ?? []
                dangTai = false
            }
        }
    }
}

struct BaiDocChiTietView: View {
    let b: BaiDoc
    let code: String
    @State private var hienDich = false
    @ObservedObject private var doc = DocTu.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let c = b.content, !c.isEmpty {
                    ChuHTMLView(html: c, co: 17)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.18)) { hienDich.toggle() }
                    Haptics.cham()
                } label: {
                    Label(hienDich ? "Ẩn bản dịch" : "Xem bản dịch",
                          systemImage: hienDich ? "eye.slash" : "character.book.closed")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
                }
                .buttonStyle(.plain)

                if hienDich, let t = b.translation, !t.isEmpty {
                    ChuHTMLView(html: t, co: 15, mau: AppColors.textSecondary)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(b.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if DocTu.doDuoc(code), let c = b.content, !c.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Đọc bản GỐC đã gỡ thẻ HTML. Đọc thẳng chuỗi HTML
                        // là máy đọc luôn cả "p", "strong" thành tiếng.
                        let sach = ChuHTML.doan(c).map { String($0.characters) }
                                                  .joined(separator: " ")
                        doc.doc(sach, code: code, id: b.id, chamHon: true)
                    } label: {
                        Image(systemName: doc.dangDoc == b.id
                              ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .foregroundColor(AppColors.primary)
                    }
                    .accessibilityLabel("Nghe bài đọc")
                }
            }
        }
    }
}

// ── Hỏi đáp ─────────────────────────────────────────────────────

struct HoiDapView: View {
    let ngonNgu: NgonNgu
    @State private var muc: [HoiDap] = []
    @State private var dangTai = true
    @State private var mo: Set<Int> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                if dangTai && muc.isEmpty { ProgressView().padding(.top, Spacing.xl) }
                ForEach(muc) { q in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button {
                            withAnimation(.easeOut(duration: 0.16)) {
                                if mo.contains(q.id) { mo.remove(q.id) } else { mo.insert(q.id) }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Text(q.question)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: mo.contains(q.id) ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        if mo.contains(q.id), let a = q.answer, !a.isEmpty {
                            Text(a)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.backgroundCard))
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Hỏi đáp")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if muc.isEmpty {
                dangTai = true
                let r: ([HoiDap], Int?, Bool)? = try? await APIClient.shared
                    .requestList(.hoiDap(code: ngonNgu.code, page: 1, limit: 60))
                muc = r?.0 ?? []
                dangTai = false
            }
        }
    }
}
