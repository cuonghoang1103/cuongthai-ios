import SwiftUI

/// Học bằng thẻ lật: mặt trước là từ, chạm để lật xem nghĩa, rồi chọn
/// "Chưa thuộc" / "Đã thuộc".
///
/// Thứ tự thẻ XÁO một lần lúc mở, và **ưu tiên từ chưa thuộc lên trước**. Học
/// theo đúng thứ tự nhập thì lần nào cũng gặp mấy từ đầu, còn từ cuối chẳng
/// bao giờ tới lượt.
struct HocTheView: View {
    let ghiChuId: Int
    let tenGhiChu: String
    var xong: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var the: [TuVung] = []
    @State private var chiSo = 0
    @State private var daLat = false
    @State private var dangTai = true
    @State private var loi: String?
    @State private var demThuoc = 0
    @State private var demChua = 0

    private var hienTai: TuVung? { the.indices.contains(chiSo) ? the[chiSo] : nil }
    private var xongHet: Bool { !dangTai && !the.isEmpty && chiSo >= the.count }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if dangTai {
                ProgressView()
            } else if the.isEmpty {
                trong
            } else if xongHet {
                ketQua
            } else {
                VStack(spacing: 0) {
                    dauTrang
                    Spacer()
                    if let t = hienTai { theLat(t) }
                    Spacer()
                    nutChon
                }
            }
        }
        .task { await tai() }
        .alert("Thẻ ghi nhớ", isPresented: .constant(loi != nil)) {
            Button("OK") { loi = nil }
        } message: { Text(loi ?? "") }
    }

    private var dauTrang: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Button { thoat() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColors.backgroundTertiary))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(chiSo + 1) / \(the.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(AppColors.primary)
                        .frame(width: g.size.width * CGFloat(chiSo) / CGFloat(max(the.count, 1)))
                }
            }
            .frame(height: 5)
        }
        .padding(Spacing.md)
    }

    private func theLat(_ t: TuVung) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.backgroundSecondary)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 6)

            VStack(spacing: Spacing.md) {
                if daLat {
                    if let m = t.meaning, !m.isEmpty {
                        Text(m)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("(chưa có nghĩa)")
                            .font(.system(size: 17)).foregroundColor(AppColors.textTertiary)
                    }
                    if let e = t.example, !e.isEmpty {
                        Text(e)
                            .font(.system(size: 15)).italic()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.md)
                    }
                } else {
                    Text(t.term)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    if let r = t.reading, !r.isEmpty {
                        Text(r).font(.system(size: 17)).foregroundColor(AppColors.primary)
                    }
                    Text("Chạm để xem nghĩa")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, Spacing.sm)
                }
            }
            .padding(Spacing.lg)
        }
        .frame(height: 320)
        .padding(.horizontal, Spacing.lg)
        // Lật bằng xoay 3D quanh trục Y — cùng cử chỉ mà ai cũng quen từ
        // Anki/Quizlet.
        .rotation3DEffect(.degrees(daLat ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .overlay {
            // Nội dung mặt sau bị lật ngược theo thẻ, phải lật lại một lần nữa.
            Color.clear
        }
        .scaleEffect(x: daLat ? -1 : 1, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.cham()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { daLat.toggle() }
        }
    }

    private var nutChon: some View {
        HStack(spacing: Spacing.md) {
            nut("Chưa thuộc", "arrow.counterclockwise", AppColors.error) {
                Task { await cham(known: false) }
            }
            nut("Đã thuộc", "checkmark", AppColors.success) {
                Task { await cham(known: true) }
            }
        }
        .padding(Spacing.md)
        .padding(.bottom, Spacing.sm)
        // Chỉ cho chấm SAU KHI lật — chấm lúc chưa xem nghĩa thì con số
        // "đã thuộc" không có ý nghĩa gì.
        .opacity(daLat ? 1 : 0.4)
        .disabled(!daLat)
    }

    private func nut(_ chu: String, _ icon: String, _ mau: Color,
                     _ cham: @escaping () -> Void) -> some View {
        Button(action: cham) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(chu)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(mau))
        }
        .buttonStyle(.plain)
    }

    private var trong: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 40)).foregroundColor(AppColors.textTertiary)
            Text("Chưa có từ nào để học")
                .font(.bodyMedium).foregroundColor(AppColors.textSecondary)
            Button("Đóng") { thoat() }.font(.buttonSmall).foregroundColor(AppColors.primary)
        }
    }

    private var ketQua: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundColor(AppColors.success)
            Text("Xong \(the.count) thẻ")
                .font(.system(size: 22, weight: .bold)).foregroundColor(AppColors.textPrimary)
            HStack(spacing: Spacing.xl) {
                VStack { Text("\(demThuoc)").font(.system(size: 26, weight: .bold))
                         .foregroundColor(AppColors.success)
                         Text("đã thuộc").font(.system(size: 12))
                         .foregroundColor(AppColors.textSecondary) }
                VStack { Text("\(demChua)").font(.system(size: 26, weight: .bold))
                         .foregroundColor(AppColors.error)
                         Text("cần ôn lại").font(.system(size: 12))
                         .foregroundColor(AppColors.textSecondary) }
            }
            .padding(.top, Spacing.sm)

            Button("Học lại lượt nữa") {
                Task { await tai(); demThuoc = 0; demChua = 0 }
            }
            .font(.buttonSmall).foregroundColor(AppColors.primary).padding(.top, Spacing.md)

            Button("Xong") { thoat() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.onPrimary)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 13).fill(AppColors.primary))
                .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm)
        }
        .padding(Spacing.lg)
    }

    // MARK: Việc

    private func tai() async {
        dangTai = true
        defer { dangTai = false }
        do {
            let bo: BoTheGhiNho = try await APIClient.shared.request(.layBoThe(noteId: ghiChuId))
            // Chưa thuộc lên trước, trong mỗi nhóm thì xáo — để lượt học sau
            // không lặp y hệt lượt trước.
            the = bo.cards.filter { !$0.daThuoc }.shuffled()
                + bo.cards.filter(\.daThuoc).shuffled()
            chiSo = 0
            daLat = false
        } catch { loi = error.localizedDescription }
    }

    private func cham(known: Bool) async {
        guard let t = hienTai else { return }
        Haptics.cham()
        if known { demThuoc += 1 } else { demChua += 1 }
        // Sang thẻ kế NGAY, không đợi máy chủ — chờ mỗi thẻ vài trăm mili giây
        // thì học 30 từ mất thêm cả chục giây trống.
        withAnimation(.easeOut(duration: 0.18)) {
            daLat = false
            chiSo += 1
        }
        _ = try? await APIClient.shared.send(.chamThe(vocabId: t.id, known: known))
    }

    private func thoat() {
        xong()
        dismiss()
    }
}
