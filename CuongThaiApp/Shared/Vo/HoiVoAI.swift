#if os(iOS)
import SwiftData
import SwiftUI

// ════════════════════════════════════════════════════════════════
// HỎI AI VỀ CẢ CUỐN VỞ
//
// Hai lối vào, một màn:
//   · Tìm › "Hỏi AI"        → hỏi tự do trên MỌI trang của mọi cuốn
//   · Vở › "Tóm tắt cuốn"   → tự gửi sẵn câu xin đề cương ôn thi
//
// ⚠️ Gửi CHỮ ĐÃ ĐỌC (`chuNhanDang`), không gửi ảnh. Một cuốn 40 trang mà
// gửi ảnh là 40 lượt ảnh — vừa chậm vừa đắt, và bậc Mini còn vứt ảnh đi.
// Chữ thì đã nằm sẵn trên máy, đọc bằng Vision ngoại tuyến từ trước.
//
// ⚠️ Trang CHƯA đọc chữ thì không có gì để gửi. Phải nói ra số trang bị bỏ
// và mời đọc, chứ tóm tắt thiếu nửa cuốn mà im lặng thì người học tin vào
// một bản đề cương sót bài.
// ════════════════════════════════════════════════════════════════

enum NguonChuVo {
    /// Trần ký tự cho một lượt hỏi.
    ///
    /// Backend chặn cả thân yêu cầu, và model càng nhiều chữ vào càng dễ trả
    /// lời chung chung. 24k ký tự ≈ 40 trang vở viết tay — đủ cho một cuốn
    /// một học kỳ.
    static let tranKyTu = 24_000

    struct Gom {
        let chu: String
        /// Số trang thật sự gửi đi.
        let soTrangGui: Int
        /// Bị cắt vì chạm trần.
        let biCat: Bool

        var rong: Bool { chu.isEmpty }
    }

    /// Trang CHƯA TỪNG được quét chữ, hoặc đã sửa sau lần quét gần nhất.
    ///
    /// ⚠️ KHÔNG hỏi "chữ đọc được có rỗng không". Trang chỉ có nét gạch chân
    /// và hình vẽ thì quét xong vẫn rỗng — hỏi kiểu đó là nó nằm mãi trong
    /// danh sách "chưa đọc", người dùng bấm đọc hoài không thấy gì đổi và
    /// kết luận nút hỏng. Mốc `nhanDangLuc` mới là thứ nói "đã quét chưa".
    /// Cùng một luật với `TimTrongVoView.chuaDocXong` — hai chỗ lệch luật thì
    /// một chỗ báo còn việc, chỗ kia báo xong.
    static func chuaQuet(_ trangs: [TrangVo]) -> [TrangVo] {
        trangs.filter { t in
            // Trang chỉ có nền PDF cũng đọc được — nội dung học nằm ở đó.
            guard t.coNet || t.nenPdfTen != nil || t.nenAnhTen != nil else { return false }
            guard let luc = t.nhanDangLuc else { return true }
            return t.suaLuc > luc
        }
    }

    /// Gom chữ của các trang, kèm mốc "[trang N]" để model trích dẫn được.
    static func gom(_ trangs: [TrangVo], tran: Int = tranKyTu) -> Gom {
        var ra = ""
        var soGui = 0
        var cat = false

        for t in trangs {
            let chu = (t.chuNhanDang ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !chu.isEmpty else { continue }
            var dau = "\n\n[\(T("trang")) \(t.thuTu + 1)"
            if let ch = t.tenChuong, !ch.isEmpty { dau += " · \(ch)" }
            dau += "]\n"
            let khoi = dau + chu
            if ra.count + khoi.count > tran { cat = true; break }
            ra += khoi
            soGui += 1
        }

        return Gom(chu: ra.trimmingCharacters(in: .whitespacesAndNewlines),
                   soTrangGui: soGui, biCat: cat)
    }
}

// MARK: - Màn hỏi

struct HoiVoAIView: View {
    let tieuDe: String
    /// Phạm vi: mọi trang được phép đọc trong lượt này.
    let trangs: [TrangVo]
    /// Mô tả phạm vi cho model biết nó đang đọc gì.
    let moTaPhamVi: String
    /// Câu tự gửi ngay khi mở. `nil` = đợi người dùng gõ.
    var cauTuGui: String? = nil

    @Environment(\.dismiss) private var dong
    @Environment(\.modelContext) private var kho
    @StateObject private var vm = AIChatViewModel()
    @StateObject private var mayDoc = MayDoc()
    @State private var cauHoi = ""
    @State private var daGuiDau = false
    @State private var dangDocChu = false
    @State private var tienDo: (Int, Int) = (0, 0)
    @FocusState private var dangGo: Bool

    private var gom: NguonChuVo.Gom { NguonChuVo.gom(trangs) }

    private var chuaDoc: [TrangVo] { NguonChuVo.chuaQuet(trangs) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                thanhPhamVi
                Divider()
                noiDung
                Divider()
                oNhap
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle(tieuDe)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker(T("Bậc AI"), selection: $vm.bac) {
                            ForEach(BacAI.allCases) { b in
                                Label(b.ten, systemImage: b.bieuTuong).tag(b)
                            }
                        }
                        Button { vm.hoiMoi() } label: {
                            Label(T("Cuộc mới"), systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: vm.bac.bieuTuong)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Đóng")) { dong() }
                }
            }
            .task {
                guard !daGuiDau, let c = cauTuGui else { return }
                daGuiDau = true
                gui(c)
            }
        }
    }

    // ── Phạm vi ─────────────────────────────────────────────────
    private var thanhPhamVi: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "text.book.closed").font(.system(size: 12))
                Text("\(moTaPhamVi) · \(gom.soTrangGui) \(T("trang đọc được"))")
                    .font(.caption)
                Spacer(minLength: 0)
            }
            .foregroundStyle(AppColors.textSecondary)

            // ⚠️ Trang chưa đọc chữ thì KHÔNG vào bài. Nói ra, kèm nút đọc
            // ngay — tóm tắt sót nửa cuốn mà im lặng là tệ hơn không tóm tắt.
            if !chuaDoc.isEmpty {
                Button {
                    docChu()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: dangDocChu ? "hourglass" : "text.viewfinder")
                        Text(dangDocChu
                             ? "\(T("Đang đọc")) \(tienDo.0)/\(tienDo.1)"
                             : "\(chuaDoc.count) \(T("trang chưa đọc chữ nên KHÔNG được tính — chạm để đọc"))")
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
                }
                .buttonStyle(.plain)
                .disabled(dangDocChu)
            }

            if gom.biCat {
                Text(T("Vở dài quá nên chỉ gửi được phần đầu."))
                    .font(.caption2).foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundSecondary)
    }

    // ── Thân ────────────────────────────────────────────────────
    @ViewBuilder
    private var noiDung: some View {
        if vm.tin.isEmpty && !vm.dangTraLoi {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(T("Hỏi gì trong vở?")).font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    ForEach(Self.goiY, id: \.self) { c in
                        Button { gui(c) } label: {
                            HStack {
                                Text(T(c)).font(Font.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundCard))
                        }
                        .buttonStyle(.plain)
                        .disabled(gom.rong)
                    }
                    if gom.rong {
                        // Hai lý do KHÁC nhau, hai câu khác nhau. Gộp làm một
                        // là bảo người dùng đi quét lại thứ đã quét rồi.
                        Text(chuaDoc.isEmpty
                             ? T("Đã quét xong mà không thấy chữ nào — vở này đang toàn hình vẽ, nét gạch, hoặc nền PDF. AI chỉ đọc được CHỮ BẠN VIẾT TAY. Muốn hỏi về nội dung trên trang thì dùng con robot trong vở, nó gửi ảnh trang.")
                             : T("Chưa trang nào đọc được chữ. Chạm dòng vàng ở trên để máy đọc trước đã."))
                            .font(.caption).foregroundStyle(AppColors.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Spacing.md)
            }
        } else {
            ScrollViewReader { doc in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(vm.tin) { t in
                            BongBongAI(tin: t, mayDoc: mayDoc).id(t.id)
                        }
                        if let b = vm.buocHienTai, !b.isEmpty {
                            Text(b).font(.caption2).foregroundStyle(AppColors.textTertiary)
                        }
                        if let e = vm.loi {
                            Text(e).font(.caption).foregroundStyle(AppColors.error)
                        }
                    }
                    .padding(Spacing.md)
                }
                .onChange(of: vm.tin.last?.noiDung) { _, _ in
                    guard let id = vm.tin.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.15)) { doc.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private static let goiY = [
        "Mình đã ghi những gì về chủ đề nào? Liệt kê theo trang.",
        "Chỗ nào trong vở mình ghi còn thiếu hoặc sai?",
        "Ra 5 câu hỏi kiểm tra từ những gì mình đã ghi.",
    ]

    private var oNhap: some View {
        HStack(spacing: Spacing.sm) {
            TextField(T("Hỏi về nội dung trong vở…"), text: $cauHoi, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($dangGo)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(AppColors.backgroundCard))
            Button {
                let c = cauHoi.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !c.isEmpty else { return }
                cauHoi = ""
                dangGo = false
                gui(c)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
                    .foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)
            .disabled(vm.dangTraLoi || gom.rong
                      || cauHoi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundSecondary)
    }

    // ── Việc ────────────────────────────────────────────────────
    /// Gửi câu hỏi KÈM chữ trong vở.
    ///
    /// Chữ đi qua `guiKem` chứ không nối vào câu hỏi: nó KHÔNG hiện trong
    /// bong bóng và KHÔNG vào lịch sử. Nhét cả 24k ký tự vào bong bóng thì
    /// người dùng phải cuộn qua nguyên cuốn vở mới thấy câu mình vừa hỏi.
    private func gui(_ cau: String) {
        let g = gom
        guard !g.rong else {
            vm.loi = "Chưa trang nào đọc được chữ để gửi."
            return
        }
        Haptics.cham()
        vm.gui(cau, guiKem: """
        Dưới đây là chữ viết tay đã quét từ \(moTaPhamVi) của mình \
        (\(g.soTrangGui) trang). Mỗi trang mở đầu bằng mốc [\(T("trang")) N].
        Khi trả lời, hãy DẪN SỐ TRANG cho mỗi ý. Chữ quét từ nét viết tay nên \
        có thể sai vài ký tự — gặp chỗ vô nghĩa thì bỏ qua, đừng đoán bừa.

        \(g.chu)
        """)
    }

    private func docChu() {
        dangDocChu = true
        Task {
            await DocChuViet.docCaCuon(chuaDoc) { i, n in tienDo = (i, n) }
            try? kho.save()
            dangDocChu = false
        }
    }
}
#endif
