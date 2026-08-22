import SwiftUI

// MARK: - Bộ nạp

@MainActor
final class TuDienVM: ObservableObject {
    @Published var ketQua: [TuTuDien] = []
    @Published var dangNap = false
    @Published var tienTrinh = ""
    @Published var loi: String?
    @Published var tongTu = 0

    private var chiMuc: [DongTraCuu] = []
    private var viecTim: Task<Void, Never>?
    private let code: String

    init(code: String) { self.code = code }

    /// Kho từ nằm ở thư mục Caches — hệ điều hành được phép dọn khi máy hết
    /// chỗ, và đó là đúng: mất thì tải lại được, không phải dữ liệu của người
    /// dùng nên không đáng chiếm chỗ sao lưu iCloud.
    private var tepCache: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("tudien-\(code).json")
    }

    func nap(tailai: Bool = false) async {
        guard chiMuc.isEmpty || tailai else { return }
        dangNap = true; loi = nil
        defer { dangNap = false; tienTrinh = "" }

        var tu: [TuTuDien] = []
        if !tailai, let t = tepCache, let d = try? Data(contentsOf: t),
           let ds = try? JSONDecoder().decode([TuTuDien].self, from: d), !ds.isEmpty {
            tienTrinh = "Đang mở kho từ đã lưu…"
            tu = ds
        } else {
            tienTrinh = "Đang tải kho từ (lần đầu)…"
            do {
                tu = try await APIClient.shared.request(.tuDien(code: code))
                if let t = tepCache, let d = try? JSONEncoder().encode(tu) {
                    try? d.write(to: t, options: .atomic)
                }
            } catch {
                loi = error.localizedDescription
                return
            }
        }

        // Dựng chỉ mục ở LUỒNG NỀN: đo trên máy Mac đã mất ~0,6 giây cho
        // 13.226 từ, làm ở luồng chính là app đứng hình đúng bấy nhiêu.
        tienTrinh = "Đang dựng chỉ mục \(tu.count) từ…"
        let ds = await Task.detached(priority: .userInitiated) {
            tu.map(DongTraCuu.init)
        }.value
        chiMuc = ds
        tongTu = ds.count
    }

    func tim(_ chu: String) {
        viecTim?.cancel()
        let q = TruyVanTuDien(chu)
        guard !q.rong else { ketQua = []; return }
        let ds = chiMuc
        viecTim = Task { [weak self] in
            let kq = await Task.detached(priority: .userInitiated) { () -> [TuTuDien] in
                var thay: [(TuTuDien, Int)] = []
                thay.reserveCapacity(120)
                for r in ds {
                    if Task.isCancelled { return [] }
                    if let d = r.diem(q) { thay.append((r.tu, d)) }
                }
                // Chỉ giữ 80 dòng: không ai cuộn hết 3.000 kết quả, mà dựng
                // từng ấy hàng SwiftUI thì cuộn giật.
                return thay.sorted { $0.1 < $1.1 }.prefix(80).map(\.0)
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.ketQua = kq }
        }
    }
}

// MARK: - Màn hình

struct TuDienView: View {
    let ngonNgu: NgonNgu
    @StateObject private var vm: TuDienVM
    @State private var chu = ""
    @ObservedObject private var doc = DocTu.shared

    init(ngonNgu: NgonNgu) {
        self.ngonNgu = ngonNgu
        _vm = StateObject(wrappedValue: TuDienVM(code: ngonNgu.code))
    }

    var body: some View {
        VStack(spacing: 0) {
            oTim
            if vm.dangNap {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text(vm.tienTrinh)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let l = vm.loi {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "wifi.slash").font(.system(size: 36))
                        .foregroundColor(AppColors.textTertiary)
                    Text(l).font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Thử lại") { Task { await vm.nap(tailai: true) } }
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chu.trimmingCharacters(in: .whitespaces).isEmpty {
                goiY
            } else if vm.ketQua.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass").font(.system(size: 36))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Không tìm thấy “\(chu)”.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(vm.ketQua) { t in hang(t) }
                    }
                    .padding(Spacing.md)
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Từ điển \(ngonNgu.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.nap() }
    }

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
            TextField("Gõ từ, phiên âm, hoặc nghĩa tiếng Việt", text: $chu)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: chu) { _, m in vm.tim(m) }
            if !chu.isEmpty {
                Button { chu = ""; vm.tim("") } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard))
        .padding(Spacing.md)
    }

    private var goiY: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)
            Text("\(vm.tongTu) từ, tra ngay trên máy")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            // Nói rõ hai điều người dùng không đoán được: gõ tiếng Việt cũng
            // tra được, và không cần dấu.
            Text("Gõ được cả \(ngonNgu.name.lowercased()), phiên âm, hay tiếng Việt.\nKhông cần bỏ dấu — gõ “nuoc” vẫn ra “nước”.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hang(_ t: TuTuDien) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t.word)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let pa = t.phienAm, !pa.isEmpty {
                    Text(pa)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary)
                }
                if let pp = t.phienAmPhu, !pp.isEmpty, pp != t.phienAm {
                    Text(pp)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
                if !t.nghia.isEmpty {
                    Text(t.nghia)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if DocTu.doDuoc(ngonNgu.code) {
                Button {
                    doc.doc(t.word, code: ngonNgu.code, id: t.id)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.primary)
                        .padding(Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }
}
