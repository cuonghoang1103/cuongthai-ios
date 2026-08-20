import SwiftUI

/// Từ vựng của MỘT ghi chú: xem, thêm, sửa, xoá, và vào màn học thẻ.
struct TuVungView: View {
    let ghiChuId: Int
    let tenGhiChu: String

    @Environment(\.dismiss) private var dismiss
    @State private var ds: [TuVung] = []
    @State private var dangTai = true
    @State private var loi: String?
    @State private var hienThem = false
    @State private var dangSua: TuVung?
    @State private var hienHocThe = false

    private var soThuoc: Int { ds.filter(\.daThuoc).count }

    var body: some View {
        NavigationStack {
            Group {
                if dangTai && ds.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if ds.isEmpty {
                    trong
                } else {
                    danhSach
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Từ vựng")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { dangSua = nil; hienThem = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await tai() }
            .sheet(isPresented: $hienThem) {
                SoanTuVungView(ghiChuId: ghiChuId, dangSua: dangSua) { Task { await tai() } }
            }
            .fullScreenCoverNeuCo(isPresented: $hienHocThe) {
                HocTheView(ghiChuId: ghiChuId, tenGhiChu: tenGhiChu) { Task { await tai() } }
            }
            .alert("Từ vựng", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    private var trong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
            Text("Ghi chú này chưa có từ vựng nào")
                .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
            Text("Thêm từ để học bằng thẻ ghi nhớ.")
                .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            Button("Thêm từ đầu tiên") { dangSua = nil; hienThem = true }
                .font(.buttonSmall).foregroundColor(AppColors.primary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var danhSach: some View {
        VStack(spacing: 0) {
            // Thanh tiến độ + nút học. Đặt TRÊN danh sách để nút học luôn thấy
            // được, không phải cuộn xuống đáy mới tìm ra.
            VStack(spacing: Spacing.sm) {
                HStack {
                    Text("\(soThuoc)/\(ds.count) từ đã thuộc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(ds.count - soThuoc) từ còn lại")
                        .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.backgroundTertiary)
                        Capsule().fill(AppColors.primary)
                            .frame(width: ds.isEmpty ? 0 : g.size.width * CGFloat(soThuoc) / CGFloat(ds.count))
                    }
                }
                .frame(height: 6)

                Button {
                    Haptics.cham()
                    hienHocThe = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.on.rectangle.angled")
                        Text("Học thẻ ghi nhớ")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.primary))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .background(AppColors.backgroundSecondary)

            List {
                ForEach(ds) { t in
                    Button { dangSua = t; hienThem = true } label: { hang(t) }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Xoá", role: .destructive) { Task { await xoa(t.id) } }
                        }
                        .listRowBackground(AppColors.backgroundPrimary)
                }
            }
            .listStyle(.plain)
        }
    }

    private func hang(_ t: TuVung) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: t.daThuoc ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17))
                .foregroundColor(t.daThuoc ? AppColors.success : AppColors.textTertiary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(t.term)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if let r = t.reading, !r.isEmpty {
                        Text(r).font(.system(size: 12))
                            .foregroundColor(AppColors.primary)
                    }
                }
                if let m = t.meaning, !m.isEmpty {
                    Text(m).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                if let e = t.example, !e.isEmpty {
                    Text(e).font(.system(size: 12)).italic()
                        .foregroundColor(AppColors.textTertiary).lineLimit(2)
                }
                if t.soLanOn > 0 {
                    Text("Đã ôn \(t.soLanOn) lần · chuỗi đúng \(t.chuoiDung)")
                        .font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do { ds = try await APIClient.shared.request(.layTuVung(noteId: ghiChuId)) }
        catch { loi = error.localizedDescription }
    }

    private func xoa(_ id: Int) async {
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.xoaTuVung(id: id))
            await tai()
        } catch { loi = error.localizedDescription }
    }
}

// MARK: - Soạn một từ

struct SoanTuVungView: View {
    let ghiChuId: Int
    let dangSua: TuVung?
    let xong: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tu = ""
    @State private var cachDoc = ""
    @State private var nghia = ""
    @State private var viDu = ""
    @State private var dangLuu = false
    @State private var loi: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Từ") {
                    TextField("Ví dụ: 勉強 · perseverance · 坚持", text: $tu, axis: .vertical)
                        .oKhongTuSua()
                }
                Section("Cách đọc") {
                    TextField("furigana · pinyin · phiên âm", text: $cachDoc)
                        .oKhongTuSua()
                }
                Section("Nghĩa") {
                    TextField("Nghĩa tiếng Việt", text: $nghia, axis: .vertical).lineLimit(1...4)
                }
                Section("Ví dụ") {
                    TextField("Một câu dùng từ này", text: $viDu, axis: .vertical).lineLimit(1...5)
                }
            }
            .navigationTitle(dangSua == nil ? "Thêm từ" : "Sửa từ")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await luu() } } label: {
                        if dangLuu { ProgressView() } else { Text("Lưu").fontWeight(.semibold) }
                    }
                    .disabled(dangLuu || tu.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let d = dangSua else { return }
                tu = d.term; cachDoc = d.reading ?? ""
                nghia = d.meaning ?? ""; viDu = d.example ?? ""
            }
            .alert("Từ vựng", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        let t = tu.trimmingCharacters(in: .whitespaces)
        do {
            if let d = dangSua {
                let _: TuVung = try await APIClient.shared.request(.suaTuVung(id: d.id, [
                    "term": t, "reading": cachDoc, "meaning": nghia, "example": viDu,
                ]))
            } else {
                let _: TuVung = try await APIClient.shared.request(
                    .themTuVung(noteId: ghiChuId, term: t, reading: cachDoc,
                                meaning: nghia, example: viDu))
            }
            Haptics.xong()
            xong()
            dismiss()
        } catch { loi = error.localizedDescription }
    }
}
