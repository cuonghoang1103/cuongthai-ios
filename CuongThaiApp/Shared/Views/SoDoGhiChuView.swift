import SwiftUI

/// Sơ đồ liên kết giữa các ghi chú.
///
/// Bố cục xếp VÒNG TRÒN có thứ tự cố định, không phải mô phỏng lực đẩy: mô
/// phỏng lực chạy mỗi khung hình, trên điện thoại là nóng máy và tụt pin, mà
/// với vài trăm nút thì nó cũng rối chứ không sáng ra. Vòng tròn xếp theo số
/// liên kết — nút nhiều liên kết nằm trong, nút lẻ nằm ngoài.
struct SoDoGhiChuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var soDo: SoDoGhiChu?
    @State private var dangTai = true
    @State private var loi: String?
    @State private var chon: NutSoDo?

    /// Chỉ vẽ nút CÓ liên kết. Kho ghi chú lớn thì phần lớn ghi chú chưa nối
    /// với gì; vẽ hết vào chỉ là một đám chấm rời rạc không đọc được.
    private var nutCoLienKet: [NutSoDo] {
        guard let s = soDo else { return [] }
        var noi = Set<Int>()
        for e in s.edges { noi.insert(e.sourceNoteId); noi.insert(e.targetNoteId) }
        return s.nodes.filter { noi.contains($0.id) }
            .sorted { bac($0.id) > bac($1.id) }
    }

    private func bac(_ id: Int) -> Int {
        guard let s = soDo else { return 0 }
        return s.edges.reduce(0) { $0 + (($1.sourceNoteId == id || $1.targetNoteId == id) ? 1 : 0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dangTai {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if nutCoLienKet.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Chưa có liên kết nào giữa các ghi chú")
                            .font(.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Nhắc tới một ghi chú khác bằng [[tên ghi chú]] trên web để tạo liên kết.")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ve
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Sơ đồ liên kết")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
            }
            .task { await tai() }
            .navigationDestination(item: $chon) { n in
                GhiChuChiTietView(ghiChuId: n.id)
            }
            .alert("Sơ đồ", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    private var ve: some View {
        GeometryReader { g in
            let ds = nutCoLienKet
            let tam = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let ban = min(g.size.width, g.size.height) / 2 - 54
            let viTri = Dictionary(uniqueKeysWithValues: ds.enumerated().map { i, n in
                (n.id, diem(i: i, tong: ds.count, tam: tam, ban: ban))
            })

            ZStack {
                // Cạnh vẽ TRƯỚC để nằm dưới nút.
                Path { p in
                    for e in soDo?.edges ?? [] {
                        guard let a = viTri[e.sourceNoteId], let b = viTri[e.targetNoteId] else { continue }
                        p.move(to: a); p.addLine(to: b)
                    }
                }
                .stroke(AppColors.primary.opacity(0.22), lineWidth: 1)

                ForEach(ds) { n in
                    if let v = viTri[n.id] {
                        Button { chon = n } label: {
                            VStack(spacing: 2) {
                                Circle()
                                    .fill(AppColors.primary.opacity(0.18))
                                    .overlay(Circle().stroke(AppColors.primary, lineWidth: 1.5))
                                    .frame(width: co(bac(n.id)), height: co(bac(n.id)))
                                Text(n.title.isEmpty ? "Untitled" : n.title)
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1)
                                    .frame(width: 66)
                            }
                        }
                        .buttonStyle(.plain)
                        .position(v)
                    }
                }
            }
        }
        .padding(Spacing.md)
    }

    private func co(_ bac: Int) -> CGFloat { min(14 + CGFloat(bac) * 3, 34) }

    private func diem(i: Int, tong: Int, tam: CGPoint, ban: CGFloat) -> CGPoint {
        // Hai vòng: nút nhiều liên kết ở vòng trong cho gần nhau, phần còn lại
        // ra vòng ngoài — một vòng duy nhất thì nhãn chồng lên nhau.
        let trong = min(tong, 8)
        if i < trong {
            let goc = CGFloat(i) / CGFloat(max(trong, 1)) * 2 * .pi - .pi / 2
            let r = ban * 0.45
            return CGPoint(x: tam.x + cos(goc) * r, y: tam.y + sin(goc) * r)
        }
        let j = i - trong
        let n = max(tong - trong, 1)
        let goc = CGFloat(j) / CGFloat(n) * 2 * .pi - .pi / 2
        return CGPoint(x: tam.x + cos(goc) * ban, y: tam.y + sin(goc) * ban)
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do { soDo = try await APIClient.shared.request(.laySoDoGhiChu) }
        catch { loi = error.localizedDescription }
    }
}
