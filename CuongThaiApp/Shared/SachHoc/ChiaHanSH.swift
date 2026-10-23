import SwiftUI

// ════════════════════════════════════════════════════════════════
// CHIA ĐỘNG TỪ (khối `chia`) và CHỮ HÁN CỦA LỚP (khối `hanlop`).
// Dữ liệu: chia.json (bảng chia tính SẴN bằng chính hàm `conjugate` của web —
// app không tự chia) và chu-han.json (thẻ chữ Hán của web). Tải chậm, chỉ khi
// mở mục có khối này.
// ════════════════════════════════════════════════════════════════

struct ChiaSH: View {
    @EnvironmentObject private var vm: SachHocVM
    @State private var tim = ""
    @State private var loai = 0      // 0 động từ · 1 tính từ
    @State private var dangMo: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let b = vm.chia {
                Picker("Loại", selection: $loai) {
                    Text("Động từ (\(b.dongTu.count))").tag(0)
                    Text("Tính từ (\(b.tinhTu.count))").tag(1)
                }
                .pickerStyle(.segmented)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                    TextField("Tìm: 行く, たべる, đi, ăn…", text: $tim)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.backgroundTertiary))
                if loai == 0 { dongTu(b) } else { tinhTu(b) }
            } else {
                HStack(spacing: 8) { ProgressView(); Text("Đang tải bảng chia…").foregroundColor(AppColors.textSecondary) }
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .task { await vm.napChia() }
    }

    private func khop(_ d: String, _ vi: String) -> Bool {
        let q = tim.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        let ds = PhanTichChuSH.tach(d)
        return [d, ds.map(\.text).joined(), ds.map { $0.ruby ?? $0.text }.joined(), vi.lowercased()].contains { $0.lowercased().contains(q) }
    }

    private func dongTu(_ b: BangChiaSH) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(b.dongTu.filter { khop($0.d, $0.vi) }) { v in
                VStack(alignment: .leading, spacing: 8) {
                    Button { withAnimation(.easeOut(duration: 0.2)) { dangMo = dangMo == v.id ? nil : v.id } } label: {
                        HStack(alignment: .center, spacing: 10) {
                            ChuSH(text: v.d, co: 21, dam: true)
                            Text(v.vi).font(.system(size: 15)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(b.tenNhom[String(v.nhom)] ?? "Nhóm \(v.nhom)").font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(mauNhom(v.nhom)).padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(mauNhom(v.nhom).opacity(0.13)))
                            Text("B\(v.bai)").font(.system(size: 11.5, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                            Image(systemName: dangMo == v.id ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if dangMo == v.id {
                        ForEach(Array(b.nhomDongTu.enumerated()), id: \.offset) { _, nh in
                            Text(nh.ten.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(0.4).foregroundColor(AppColors.textTertiary).padding(.top, 4)
                            ForEach(Array(nh.hang.enumerated()), id: \.offset) { _, h in
                                if h.count >= 2, let the = v.the[h[1]] { hang(h[0], the, phu: h.count > 2 ? h[2] : nil) }
                            }
                        }
                    }
                }
                .theKhoiSH()
            }
        }
    }

    private func tinhTu(_ b: BangChiaSH) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(b.tinhTu.filter { khop($0.d, $0.vi) }) { a in
                VStack(alignment: .leading, spacing: 8) {
                    Button { withAnimation(.easeOut(duration: 0.2)) { dangMo = dangMo == a.id ? nil : a.id } } label: {
                        HStack(spacing: 10) {
                            ChuSH(text: a.d, co: 21, dam: true)
                            Text(a.vi).font(.system(size: 15)).foregroundColor(AppColors.textSecondary).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(a.loai == "i" ? "Tính từ い" : "Tính từ な").font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(AppColors.secondary).padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(AppColors.secondary.opacity(0.13)))
                            Text("B\(a.bai)").font(.system(size: 11.5, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                            Image(systemName: dangMo == a.id ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if dangMo == a.id {
                        ForEach(Array(b.hangTinhTu.enumerated()), id: \.offset) { _, h in
                            if h.count >= 2, let the = a.the[h[1]] { hang(h[0], the, phu: nil) }
                        }
                    }
                }
                .theKhoiSH()
            }
        }
    }

    private func hang(_ nhan: String, _ the: String, phu: String?) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(nhan).font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary).frame(width: 128, alignment: .leading)
            ChuSH(text: the, co: 18).frame(maxWidth: .infinity, alignment: .leading)
            if let phu { Text(phu).font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textTertiary) }
            NutLoaSH(text: the, co: 28)
        }
    }

    private func mauNhom(_ n: Int) -> Color {
        n == 1 ? MauChuSH.mau(0x2563EB).color : n == 2 ? MauChuSH.mau(0x059669).color : MauChuSH.mau(0xDB2777).color
    }
}

// MARK: - Chữ Hán của lớp

struct HanLopSH: View {
    let bai: Int
    @EnvironmentObject private var vm: SachHocVM
    @State private var dangXem: ChuMoSH?
    private let cot = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    struct ChuMoSH: Identifiable { let id: String }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ch = vm.chuHan, let lop = ch.lop[String(bai)] {
                Text(lop.nguon == "slide" ? "Đúng slide của cô · \(lop.chars.count) chữ" : "Danh sách dự kiến · \(lop.chars.count) chữ (sẽ khớp slide khi có)")
                    .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                LazyVGrid(columns: cot, spacing: 10) {
                    ForEach(lop.chars.map(String.init), id: \.self) { c in
                        Button { dangXem = ChuMoSH(id: c) } label: { the(c, ch.han[c]) }.buttonStyle(.plain)
                    }
                }
            } else if vm.chuHan != nil {
                Text("Chưa có danh sách chữ Hán cho bài này.").foregroundColor(AppColors.textSecondary)
            } else {
                HStack(spacing: 8) { ProgressView(); Text("Đang tải chữ Hán…").foregroundColor(AppColors.textSecondary) }
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .task { await vm.napChuHan() }
        .sheet(item: $dangXem) { c in TheChuHanSH(chu: c.id, han: vm.chuHan?.han[c.id]) }
    }

    private func the(_ c: String, _ h: ChuHanSH.Han?) -> some View {
        HStack(spacing: 10) {
            Text(c).font(.system(size: 40, weight: .regular)).foregroundColor(AppColors.textPrimary)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 10).fill(MauChuSH.mau(0xB45309).color.opacity(0.10)))
            VStack(alignment: .leading, spacing: 2) {
                Text(h?.hv ?? "").font(.system(size: 14, weight: .heavy)).foregroundColor(MauChuSH.mau(0xB45309).color)
                Text(h?.nghia ?? "").font(.system(size: 13.5)).foregroundColor(AppColors.textPrimary).lineLimit(2)
                if let h, !(h.on + h.kun).isEmpty {
                    Text((h.on + h.kun).joined(separator: " · ")).font(.system(size: 12)).foregroundColor(AppColors.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundCard))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.border, lineWidth: 1))
    }
}

struct TheChuHanSH: View {
    let chu: String
    let han: ChuHanSH.Han?
    @Environment(\.dismiss) private var dong

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 16) {
                        Text(chu).font(.system(size: 88)).frame(width: 120, height: 120)
                            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.backgroundTertiary))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(han?.hv ?? "").font(.system(size: 22, weight: .heavy)).foregroundColor(MauChuSH.mau(0xB45309).color)
                            Text(han?.nghia ?? "").font(.system(size: 17))
                            NutLoaSH(text: chu, co: 34)
                        }
                    }
                    if let h = han {
                        if !h.on.isEmpty { hangTT("On (âm Hán)", h.on.joined(separator: "・")) }
                        if !h.kun.isEmpty { hangTT("Kun (âm Nhật)", h.kun.joined(separator: "・")) }
                        if let nho = h.nho, !nho.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("💡 CÁCH NHỚ").font(.system(size: 11, weight: .heavy)).foregroundColor(AppColors.accent)
                                ChuSH(text: nho, co: 16)
                            }
                            .theKhoiSH(vien: AppColors.accent.opacity(0.35), nen: AppColors.accent.opacity(0.07))
                        }
                        if let tu = h.tu, !tu.isEmpty {
                            Text("TỪ ĐI CHUNG").font(.system(size: 11, weight: .heavy)).foregroundColor(AppColors.textTertiary)
                            ForEach(tu, id: \.self) { t in
                                HStack(spacing: 10) {
                                    NutLoaSH(text: t.w, co: 30)
                                    VStack(alignment: .leading, spacing: 1) {
                                        ChuSH(text: t.w, co: 19)
                                        if let ro = t.ro { Text(ro).font(.system(size: 12.5).italic()).foregroundColor(AppColors.textTertiary) }
                                        if let vi = t.vi { Text(vi).font(.system(size: 14)).foregroundColor(AppColors.textSecondary) }
                                    }
                                    Spacer()
                                }
                            }
                        }
                        Text("Hoạt hình thứ tự nét + ô tập viết: đợt 2 của app.").font(.system(size: 12.5)).foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(20)
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Chữ \(chu)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dong() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func hangTT(_ nhan: String, _ gt: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(nhan).font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary).frame(width: 110, alignment: .leading)
            Text(gt).font(.system(size: 18, weight: .medium))
        }
    }
}
