import SwiftUI

// MARK: - Tin tuyển dụng

struct CVViecLamView: View {
    @ObservedObject var may: MayCV
    @State private var themMoi = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                NeoDauTrang()
                if may.viecLam.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "target").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(T("Dán một tin tuyển dụng vào đây để đo xem CV của bạn phủ được bao nhiêu yêu cầu."))
                            .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                }
                ForEach(may.viecLam) { v in
                    NavigationLink { CVDoPhuView(may: may, viec: v) } label: {
                        HStack(spacing: Spacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.title).font(.system(size: 14.5, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                if let c = v.company, !c.isEmpty {
                                    Text(c).font(.system(size: 11.5)).foregroundColor(AppColors.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(AppColors.backgroundCard))
                    }
                    .buttonStyle(.plain)
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Tin tuyển dụng"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { themMoi = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $themMoi) { CVThemViecView(may: may) }
        .task { await may.napViecLam() }
    }
}

struct CVThemViecView: View {
    @ObservedObject var may: MayCV
    @Environment(\.dismiss) private var dong
    @State private var tua = ""
    @State private var congTy = ""
    @State private var moTa = ""
    @State private var dangLuu = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    o(T("Vị trí"), $tua, goiY: "Backend Engineer")
                    o(T("Công ty"), $congTy)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Mô tả công việc (dán nguyên)").uppercased())
                            .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                            .foregroundColor(AppColors.textTertiary)
                        TextEditor(text: $moTa)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 260)
                            .padding(Spacing.sm)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundTertiary.opacity(0.6)))
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(T("Thêm tin tuyển dụng"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Huỷ")) { dong() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            dangLuu = true
                            _ = await may.gui(.cvThemViecLam(than: [
                                "title": tua, "company": congTy, "rawJobDescription": moTa,
                            ]))
                            await may.napViecLam()
                            dangLuu = false
                            dong()
                        }
                    } label: {
                        if dangLuu { ProgressView() }
                        else { Text(T("Lưu")).font(.system(size: 14, weight: .bold)) }
                    }
                    .disabled(tua.isEmpty || moTa.count < 40 || dangLuu)
                }
            }
        }
    }

    private func o(_ ten: String, _ v: Binding<String>, goiY: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ten.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                .foregroundColor(AppColors.textTertiary)
            TextField(goiY, text: v)
                .font(.system(size: 15)).textFieldStyle(.plain)
                .padding(Spacing.sm + 2)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundTertiary.opacity(0.6)))
        }
    }
}

// MARK: - Độ phủ + thư xin việc

struct CVDoPhuView: View {
    @ObservedObject var may: MayCV
    let viec: ViecLamCV
    @State private var phu: DoPhuCV?
    @State private var dangTai = true
    @State private var thu: ThuXinViec?
    @State private var dangViet = false
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                if dangTai {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let p = phu {
                    if let s = p.summary { khoiTomTat(s) }
                    khoiDong(p.cacDong.filter { $0.required == true }, T("Yêu cầu bắt buộc"))
                    khoiDong(p.cacDong.filter { $0.required != true }, T("Ưu tiên có"))
                    khoiThu
                } else {
                    Text(T("Chưa đo được độ phủ."))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(viec.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            dangTai = true
            phu = await may.doPhu(viec.id)
            dangTai = false
        }
    }

    private func khoiTomTat(_ s: TomTatPhu) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(spacing: 0) {
                    Text("\(s.mustHaveMatched ?? 0)/\(s.mustHaveTotal ?? 0)")
                        .font(.system(size: 24, weight: .heavy).monospacedDigit())
                        .foregroundColor(s.mau)
                    Text(T("bắt buộc")).font(.system(size: 9.5))
                        .foregroundColor(AppColors.textTertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let v = s.verdict {
                        Text(v).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(s.mau))
                    }
                    // Lời kết của máy chủ viết THẲNG, không tô hồng — giữ
                    // nguyên chứ đừng diễn giải lại cho êm tai.
                    if let m = s.message, !m.isEmpty {
                        Text(m).font(.system(size: 12.5))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(s.mau).frame(width: g.size.width * s.tiLe)
                }
            }
            .frame(height: 6)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    @ViewBuilder private func khoiDong(_ ds: [DongPhu], _ ten: String) -> some View {
        if !ds.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(ten.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)
                ForEach(ds) { d in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle().fill(d.mau).frame(width: 7, height: 7)
                            Text(d.skill).font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer(minLength: 0)
                            Text(d.nhanMuc).font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(d.mau)
                        }
                        if let e = d.evidence, !e.isEmpty {
                            Text(e).font(.system(size: 11.5))
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 13)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
    }

    @ViewBuilder private var khoiThu: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(T("Thư xin việc"), systemImage: "envelope.fill")
                .font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.textTertiary)
            if let t = thu, let b = t.body, !b.isEmpty {
                Text(b).font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = b
                } label: {
                    Label(T("Chép"), systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            } else if may.congThu?.bat == false {
                Text(may.congThu?.reason ?? T("Tính năng này cần tài khoản Pro."))
                    .font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
            } else {
                HStack(spacing: Spacing.sm) {
                    ForEach(["PROFESSIONAL", "WARM", "DIRECT"], id: \.self) { g in
                        Button {
                            Task {
                                dangViet = true; loi = nil
                                do { thu = try await may.thuXinViec(viec.id, giong: g) }
                                catch { loi = error.localizedDescription }
                                dangViet = false
                            }
                        } label: {
                            Text(giongChu(g)).font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(AppColors.primary))
                        }
                        .buttonStyle(.plain)
                        .disabled(dangViet)
                    }
                    if dangViet { ProgressView() }
                    Spacer(minLength: 0)
                }
            }
            if let e = loi {
                Text(e).font(.system(size: 11.5)).foregroundColor(Color(hex: 0xEF4444))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func giongChu(_ g: String) -> String {
        switch g {
        case "WARM": return T("Thân thiện")
        case "DIRECT": return T("Thẳng thắn")
        default: return T("Chuyên nghiệp")
        }
    }
}

// MARK: - Tài liệu CV

struct CVTaiLieuView: View {
    @ObservedObject var may: MayCV

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                NeoDauTrang()
                if may.taiLieu.isEmpty {
                    Text(T("Chưa có bản CV nào. Tạo trên web rồi mở lại ở đây để xem và tải về."))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                }
                ForEach(may.taiLieu) { t in the(t) }
                if !may.mau.isEmpty {
                    Text(T("Mẫu có sẵn").uppercased())
                        .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                        .foregroundColor(AppColors.textTertiary).padding(.top, Spacing.sm)
                    ForEach(may.mau) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(m.name).font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                if m.atsSafe == true {
                                    Label("ATS", systemImage: "checkmark.seal.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color(hex: 0x22C55E))
                                }
                                Spacer(minLength: 0)
                            }
                            if let d = m.description, !d.isEmpty {
                                Text(d).font(.system(size: 11.5))
                                    .foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(AppColors.backgroundCard))
                    }
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Tài liệu CV"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await may.napTaiLieu() }
    }

    private func the(_ t: TaiLieuCV) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t.name).font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            HStack(spacing: 5) {
                ForEach([t.market, t.language, t.experienceLevel, t.cvType].compactMap { $0 }, id: \.self) { x in
                    Text(x).font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.backgroundTertiary))
                }
                Spacer(minLength: 0)
            }
            // Tải file đi qua trình duyệt: endpoint xuất trả về BYTE kèm
            // `Content-Disposition`, không phải JSON — `APIClient` không nhận
            // được, mà Safari thì mở và lưu được ngay.
            HStack(spacing: Spacing.sm) {
                ForEach(["pdf", "docx", "txt"], id: \.self) { f in
                    if let u = URL(string: "https://cuongthai.com/api/v1/cv/documents/\(t.id)/export/\(f)") {
                        Link(destination: u) {
                            Label(f.uppercased(), systemImage: "arrow.down.doc")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 7)
                                    .fill(AppColors.primary.opacity(0.12)))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}
