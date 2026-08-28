import SwiftUI

// ════════════════════════════════════════════════════════════════
// CÁC MÀN CON CỦA CV BUILDER
// ════════════════════════════════════════════════════════════════

// MARK: - Hồ sơ

struct CVHoSoView: View {
    @ObservedObject var may: MayCV
    @Environment(\.dismiss) private var dong
    @State private var ten = ""
    @State private var chucDanh = ""
    @State private var email = ""
    @State private var dienThoai = ""
    @State private var noiO = ""
    @State private var tomTat = ""
    @State private var dangLuu = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                o(T("Họ và tên"), $ten)
                o(T("Chức danh"), $chucDanh, goiY: T("VD: Backend Engineer"))
                o("Email", $email, kieu: .emailAddress)
                o(T("Điện thoại"), $dienThoai, kieu: .phonePad)
                o(T("Nơi ở"), $noiO)
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Tóm tắt").uppercased())
                        .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                        .foregroundColor(AppColors.textTertiary)
                    TextEditor(text: $tomTat)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 130)
                        .padding(Spacing.sm)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundTertiary.opacity(0.6)))
                    Text("\(tomTat.count) \(T("ký tự")) · \(T("3–4 dòng là vừa"))")
                        .font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                if let h = may.hoSo, !h.cacLink.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("Liên kết").uppercased())
                            .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                            .foregroundColor(AppColors.textTertiary)
                        ForEach(h.cacLink, id: \.0) { k, v in
                            HStack(spacing: 6) {
                                Text(k).font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                                Text(v).font(.system(size: 11.5)).foregroundColor(AppColors.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Thông tin cá nhân"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        dangLuu = true
                        let ok = await may.luuHoSo([
                            "fullName": ten, "headline": chucDanh, "email": email,
                            "phone": dienThoai, "location": noiO, "summary": tomTat,
                        ])
                        dangLuu = false
                        if ok { dong() }
                    }
                } label: {
                    if dangLuu { ProgressView() }
                    else { Text(T("Lưu")).font(.system(size: 14, weight: .bold)) }
                }
                .disabled(dangLuu)
            }
        }
        .onAppear {
            guard let h = may.hoSo else { return }
            ten = h.fullName ?? ""; chucDanh = h.headline ?? ""
            email = h.email ?? ""; dienThoai = h.phone ?? ""
            noiO = h.location ?? ""; tomTat = h.summary ?? ""
        }
    }

    private func o(_ ten: String, _ v: Binding<String>, goiY: String = "",
                   kieu: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ten.uppercased())
                .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                .foregroundColor(AppColors.textTertiary)
            TextField(goiY, text: v)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .keyboardType(kieu)
                .autocorrectionDisabled()
                .padding(Spacing.sm + 2)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundTertiary.opacity(0.6)))
        }
    }
}

// MARK: - Mục (kinh nghiệm / học vấn)

struct CVMucView: View {
    @ObservedObject var may: MayCV
    let loai: [String]
    let ten: String
    @State private var mo: Set<Int> = []

    private var ds: [MucCV] { (may.hoSo?.cacMuc ?? []).filter { loai.contains($0.kind) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                NeoDauTrang()
                if ds.isEmpty {
                    Text(T("Chưa có mục nào. Thêm trên web rồi mở lại ở đây."))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                }
                ForEach(ds) { m in the(m) }
                if loai.contains("EDUCATION"), let cc = may.hoSo?.cacChungChi, !cc.isEmpty {
                    Text(T("Chứng chỉ").uppercased())
                        .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                        .foregroundColor(AppColors.textTertiary).padding(.top, Spacing.sm)
                    ForEach(cc) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name).font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            if let i = c.issuer, !i.isEmpty {
                                Text(i).font(.system(size: 11.5)).foregroundColor(AppColors.textSecondary)
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
        .navigationTitle(ten)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func the(_ m: MucCV) -> some View {
        let dangMo = mo.contains(m.id)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    if dangMo { mo.remove(m.id) } else { mo.insert(m.id) }
                }
            } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.title).font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            if let o = m.organization, !o.isEmpty {
                                Text(o).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                            }
                            if !m.khoangThoiGian.isEmpty {
                                Text(m.khoangThoiGian).font(.system(size: 11).monospacedDigit())
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        if !m.cacGach.isEmpty {
                            Text("\(m.cacGach.count) \(T("dòng thành tích"))")
                                .font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: dangMo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if dangMo {
                if !m.congNghe.isEmpty { FlowChips(items: m.congNghe, mau: AppColors.primary) }
                ForEach(m.cacGach) { g in
                    HStack(alignment: .top, spacing: 6) {
                        // Sức mạnh của dòng do MÁY CHỦ chấm (soi lỗi ghi lại),
                        // hiện nguyên chứ đừng tự đoán lại ở client.
                        Circle().fill(g.mauLuc).frame(width: 5, height: 5).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.text).font(.system(size: 12.5))
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 5) {
                                Text(g.nhanLuc).font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(g.mauLuc)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(g.mauLuc.opacity(0.15)))
                                if g.aiGenerated == true {
                                    Label("AI", systemImage: "sparkles")
                                        .font(.system(size: 8.5)).foregroundColor(AppColors.textTertiary)
                                }
                                if g.verified == true {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 9)).foregroundColor(Color(hex: 0x22C55E))
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

// MARK: - Kỹ năng & ngôn ngữ

struct CVKyNangView: View {
    @ObservedObject var may: MayCV

    private var theoNhom: [(String, [KyNangCV])] {
        let ds = may.hoSo?.cacKyNang ?? []
        var ra: [(String, [KyNangCV])] = []
        for k in ds {
            let n = k.nhanNhom
            if let i = ra.firstIndex(where: { $0.0 == n }) { ra[i].1.append(k) }
            else { ra.append((n, [k])) }
        }
        return ra
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                ForEach(theoNhom, id: \.0) { nhom, ds in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(nhom.uppercased())
                            .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                            .foregroundColor(AppColors.textTertiary)
                        FlowChips(items: ds.map { k in
                            k.yearsUsed.map { "\(k.name) · \(so($0))\(T("n"))" } ?? k.name
                        }, mau: AppColors.primary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.backgroundCard))
                }
                if let ns = may.hoSo?.cacNgonNgu, !ns.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(T("Ngoại ngữ").uppercased())
                            .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                            .foregroundColor(AppColors.textTertiary)
                        ForEach(ns) { n in
                            HStack(spacing: 6) {
                                Text(n.language).font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                if let p = n.proficiency, !p.isEmpty {
                                    Text(p).font(.system(size: 11.5)).foregroundColor(AppColors.textSecondary)
                                }
                                Spacer(minLength: 0)
                                if let c = n.certName, !c.isEmpty {
                                    Text("\(c) \(n.certScore ?? "")")
                                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                                }
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.backgroundCard))
                }
                if (may.hoSo?.cacKyNang ?? []).isEmpty && (may.hoSo?.cacNgonNgu ?? []).isEmpty {
                    Text(T("Chưa có kỹ năng nào."))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Kỹ năng & ngôn ngữ"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
