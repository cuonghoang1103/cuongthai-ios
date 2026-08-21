import SwiftUI

struct TuNgoaiNguView: View {
    let ngonNgu: NgonNgu
    let chuDe: ChuDeTu
    @StateObject private var vm: TuNgoaiNguVM
    @State private var hienThe = false

    init(ngonNgu: NgonNgu, chuDe: ChuDeTu) {
        self.ngonNgu = ngonNgu
        self.chuDe = chuDe
        _vm = StateObject(wrappedValue: TuNgoaiNguVM(code: ngonNgu.code, categoryId: chuDe.id))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(vm.tu) { t in
                    HangTu(t: t, code: ngonNgu.code,
                           thich: vm.yeuThich.contains(t.id),
                           doiThich: { Task { await vm.doiYeuThich(t) } })
                }

                if vm.conNua {
                    ProgressView()
                        .padding(.vertical, Spacing.md)
                        .onAppear { Task { await vm.tai() } }
                } else if !vm.tu.isEmpty {
                    Text("Hết \(vm.tu.count) từ")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.vertical, Spacing.md)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(chuDe.tenGon)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    hienThe = true
                } label: {
                    Label("Thẻ ghi nhớ", systemImage: "rectangle.stack")
                }
                // Chưa tải xong từ nào thì mở thẻ ra là một bộ bài rỗng.
                .disabled(vm.tu.isEmpty)
            }
        }
        .fullScreenCover(isPresented: $hienThe) {
            TheGhiNhoView(tu: vm.tu, ngonNgu: ngonNgu, chuDe: chuDe)
        }
        .task {
            if vm.tu.isEmpty { await vm.tai(lai: true) }
            await vm.taiYeuThich()
        }
        .overlay(alignment: .bottom) {
            if let loi = vm.loi {
                Text(loi)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                    .background(Capsule().fill(AppColors.error))
                    .padding(.bottom, Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: vm.loi)
    }
}

private struct HangTu: View {
    let t: TuNgoaiNgu
    let code: String
    let thich: Bool
    let doiThich: () -> Void
    @ObservedObject private var doc = DocTu.shared

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t.word)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                if let pa = t.phienAm {
                    Text(pa)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.secondary)
                }

                Text(t.nghia)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let vd = t.exampleSentence, !vd.isEmpty, vd != t.word {
                    Text(vd)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)

            VStack(spacing: Spacing.sm) {
                // Máy chưa tải giọng của ngôn ngữ này thì ẩn hẳn nút. Để lại
                // là một nút bấm KHÔNG ra tiếng và không báo gì.
                if DocTu.doDuoc(code) {
                    Button {
                        doc.doc(t.word, code: code, id: t.id)
                    } label: {
                        Image(systemName: doc.dangDoc == t.id
                              ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 36, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Nghe cách đọc")
                }

                Button(action: doiThich) {
                    Image(systemName: thich ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(thich ? AppColors.error : AppColors.textTertiary)
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(thich ? "Bỏ yêu thích" : "Thêm vào yêu thích")
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.backgroundCard)
        )
    }
}
