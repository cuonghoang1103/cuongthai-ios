#if os(iOS)
import SwiftData
import SwiftUI

/// Tìm trong vở — theo tên môn/cuốn/chương và theo CHỮ VIẾT TAY đã đọc được.
struct TimTrongVoView: View {
    @Environment(\.modelContext) private var kho
    @Environment(\.dismiss) private var dong
    @Query private var mons: [MonVo]

    @State private var tu = ""
    @State private var dangDoc = false
    @State private var tienDo: (Int, Int) = (0, 0)
    @State private var moTrang: TrangVo?
    @State private var hoiAI = false

    var body: some View {
        NavigationStack {
            List {
                // Hỏi AI đặt TRÊN CÙNG và luôn hiện: tìm theo từ khoá chỉ ra
                // đúng trang có đúng chữ đó, còn "mình đã ghi gì về đạo hàm"
                // thì từ khoá chịu — mà đó mới là câu người học hay hỏi.
                Section {
                    Button { hoiAI = true } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppColors.primary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(T("Hỏi AI về cả vở"))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(T("Hỏi bằng câu thường, AI dẫn số trang"))
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !chuaDocXong.isEmpty {
                    Section {
                        Button { docHet() } label: {
                            HStack {
                                Label(dangDoc
                                      ? "\(T("Đang đọc")) \(tienDo.0)/\(tienDo.1)"
                                      : "\(T("Đọc chữ viết tay của")) \(chuaDocXong.count) \(T("trang"))",
                                      systemImage: "text.viewfinder")
                                Spacer()
                                if dangDoc { ProgressView() }
                            }
                        }
                        .disabled(dangDoc)
                    } footer: {
                        Text(T("Đọc xong thì tìm được cả chữ bạn viết tay, không chỉ tên trang. Máy tự đọc, không gửi đi đâu."))
                    }
                }

                if tu.isEmpty {
                    Section { Text(T("Gõ để tìm trong tên môn, tên cuốn, tên chương và chữ viết tay."))
                        .font(.caption).foregroundStyle(AppColors.textTertiary) }
                } else if ketQua.isEmpty {
                    Section { Text(T("Không thấy gì khớp.")).foregroundStyle(AppColors.textSecondary) }
                } else {
                    Section("\(ketQua.count) \(T("kết quả"))") {
                        ForEach(ketQua, id: \.trang.id) { kq in
                            Button { moTrang = kq.trang } label: { dongKetQua(kq) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $tu, prompt: T("Tìm trong vở"))
            .navigationTitle(T("Tìm"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Đóng")) { dong() }
                }
            }
            .navigationDestination(item: $moTrang) { t in
                if let c = t.cuon {
                    ManVietView(cuon: c, moTrang: t.id)
                }
            }
            .sheet(isPresented: $hoiAI) {
                HoiVoAIView(tieuDe: T("Hỏi AI về vở"),
                            trangs: tatCaTrang,
                            moTaPhamVi: T("toàn bộ vở"))
            }
        }
    }

    private struct KetQua {
        let trang: TrangVo
        let duong: String
        let doan: String?
    }

    private var tatCaTrang: [TrangVo] {
        mons.flatMap { $0.cuonsTheoThuTu }.flatMap { $0.trangsTheoThuTu }
    }

    private var chuaDocXong: [TrangVo] {
        tatCaTrang.filter { t in
            // Trang chỉ có nền PDF cũng đọc được — nội dung học nằm ở đó.
            guard t.coNet || t.nenPdfTen != nil || t.nenAnhTen != nil else { return false }
            guard let luc = t.nhanDangLuc else { return true }
            return t.suaLuc > luc
        }
    }

    private var ketQua: [KetQua] {
        let k = tu.trimmingCharacters(in: .whitespaces).lowercased()
        guard !k.isEmpty else { return [] }
        var ra: [KetQua] = []
        for mon in mons {
            for cuon in mon.cuonsTheoThuTu {
                for t in cuon.trangsTheoThuTu {
                    let duong = "\(mon.emoji) \(mon.ten) › \(cuon.ten) › \(T("trang")) \(t.thuTu + 1)"
                    var doan: String?
                    var khop = mon.ten.lowercased().contains(k)
                        || cuon.ten.lowercased().contains(k)
                        || (t.tenChuong?.lowercased().contains(k) ?? false)
                    if let chu = t.chuNhanDang?.lowercased(), chu.contains(k) {
                        khop = true
                        doan = Self.trichDoan(t.chuNhanDang ?? "", quanh: k)
                    }
                    if khop { ra.append(KetQua(trang: t, duong: duong, doan: doan)) }
                }
            }
        }
        return ra
    }

    /// Cắt một đoạn ngắn quanh từ khoá — hiện cả trang chữ thì không đọc được.
    private static func trichDoan(_ chu: String, quanh k: String) -> String {
        let thap = chu.lowercased()
        guard let r = thap.range(of: k) else { return String(chu.prefix(80)) }
        let dau = thap.index(r.lowerBound, offsetBy: -40, limitedBy: thap.startIndex) ?? thap.startIndex
        let cuoi = thap.index(r.upperBound, offsetBy: 40, limitedBy: thap.endIndex) ?? thap.endIndex
        let doan = String(chu[dau..<cuoi]).replacingOccurrences(of: "\n", with: " ")
        return (dau > thap.startIndex ? "…" : "") + doan + (cuoi < thap.endIndex ? "…" : "")
    }

    private func dongKetQua(_ kq: KetQua) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(kq.duong).font(Font.bodyMedium).foregroundStyle(AppColors.textPrimary)
            if let ch = kq.trang.tenChuong, !ch.isEmpty {
                Text(ch).font(.caption).foregroundStyle(AppColors.primary)
            }
            if let d = kq.doan {
                Text(d).font(.caption).foregroundStyle(AppColors.textTertiary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func docHet() {
        dangDoc = true
        Task {
            await DocChuViet.docCaCuon(tatCaTrang) { i, n in tienDo = (i, n) }
            try? kho.save()
            dangDoc = false
        }
    }
}
#endif
