import SwiftUI

@MainActor
final class DuAnVM: ObservableObject {
    @Published var ds: [DuAn] = []
    @Published var danhMuc: String?
    @Published var tim = ""
    @Published var dangTai = false
    @Published var loi: String?

    private var trang = 1
    private var het = false
    private var viecTim: Task<Void, Never>?
    /// ⚠️ Máy chủ CHỐT ở 12 — gửi to hơn cũng vô ích. Suy "hết trang" bằng
    /// "trang này trả về ít hơn 12" vì `pagination` nằm ngoài `data`.
    private let moiTrang = 12

    func nap(lai: Bool) async {
        if lai { trang = 1; het = false }
        guard !dangTai, !(het && !lai) else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let t: [DuAn] = try await APIClient.shared.request(
                .dsDuAn(danhMuc: danhMuc, tim: tim.trimmingCharacters(in: .whitespaces), trang: trang))
            if lai { ds = t } else { ds += t }
            het = t.count < moiTrang
            trang += 1
            loi = ds.isEmpty ? T("Không tìm thấy dự án nào.") : nil
        } catch { loi = error.localizedDescription }
    }

    func timLai() {
        viecTim?.cancel()
        viecTim = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.nap(lai: true)
        }
    }
}

struct DuAnView: View {
    @StateObject private var vm = DuAnVM()
    @AppStorage("duan.tiengAnh") private var tiengAnh = false

    /// Đo thật 28/08: Web 18 · Backend 11 · AI 6 · Mobile 5 · DevOps 1.
    private let cacDanhMuc = ["Web", "Backend", "AI", "Mobile", "DevOps"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                TextField(T("Tìm dự án…"), text: $vm.tim)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: vm.tim) { _, _ in vm.timLai() }
                if !vm.tim.isEmpty {
                    Button { vm.tim = ""; vm.timLai() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(Spacing.sm + 2)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    the(T("Tất cả"), chon: vm.danhMuc == nil) {
                        vm.danhMuc = nil; Task { await vm.nap(lai: true) }
                    }
                    ForEach(cacDanhMuc, id: \.self) { d in
                        the(d, chon: vm.danhMuc == d) {
                            vm.danhMuc = vm.danhMuc == d ? nil : d
                            Task { await vm.nap(lai: true) }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.sm)

            if vm.dangTai && vm.ds.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.ds.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "hammer").font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text(vm.loi ?? T("Chưa có dự án nào."))
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { cuon in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        NeoDauTrang()
                        ForEach(vm.ds) { d in
                            NavigationLink { DuAnChiTietView(duAn: d, tiengAnh: $tiengAnh) } label: { the(d) }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if d.id == vm.ds.suffix(3).first?.id {
                                        Task { await vm.nap(lai: false) }
                                    }
                                }
                        }
                        if vm.dangTai { ProgressView().padding(.vertical, Spacing.md) }
                        Color.clear.frame(height: 72)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                }
                .onChange(of: vm.ds.first?.id) { _, _ in cuon.veDauTrang() }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Dự án"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { tiengAnh.toggle() } label: {
                    Text(tiengAnh ? "EN" : "VI").font(.system(size: 13, weight: .bold))
                }
            }
        }
        .task { if vm.ds.isEmpty { await vm.nap(lai: true) } }
    }

    private func the(_ nhan: String, chon: Bool, lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Text(nhan)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(chon ? AppColors.onPrimary : AppColors.textSecondary)
                .padding(.horizontal, Spacing.sm + 4).padding(.vertical, 6)
                .background(Capsule().fill(chon ? AppColors.primary : AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }

    private func the(_ d: DuAn) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let u = d.thumbnailUrl, let url = URL(string: u) {
                AsyncImage(url: url) { pha in
                    switch pha {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: Rectangle().fill(d.mauDanhMuc.opacity(0.15))
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Label(d.category ?? "—", systemImage: d.bieuTuongDanhMuc)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(d.mauDanhMuc)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(d.mauDanhMuc.opacity(0.15)))
                    if let k = d.nhanDoKho {
                        Text(k)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(d.mauDoKho)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(d.mauDoKho.opacity(0.15)))
                    }
                    Spacer(minLength: 0)
                    if let v = d.viewCount, v > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "eye").font(.system(size: 9))
                            Text("\(v)").font(.system(size: 10).monospacedDigit())
                        }
                        .foregroundColor(AppColors.textTertiary)
                    }
                }
                Text(d.tua(tiengAnh))
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let m = d.moTa(tiengAnh), !m.isEmpty {
                    Text(m)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                if !d.cacCongNghe.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(d.cacCongNghe.prefix(4), id: \.self) { t in
                            Text(t)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 5).fill(AppColors.backgroundTertiary))
                        }
                        if d.cacCongNghe.count > 4 {
                            Text("+\(d.cacCongNghe.count - 4)")
                                .font(.system(size: 9.5)).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(.top, 2)
                }
                HStack(spacing: 10) {
                    if !d.cacMoc.isEmpty { nhanNho("flag", "\(d.cacMoc.count) \(T("mốc"))") }
                    if !d.cacTinhNang.isEmpty { nhanNho("star", "\(d.cacTinhNang.count) \(T("tính năng"))") }
                    if !d.cacTaiNguyen.isEmpty { nhanNho("link", "\(d.cacTaiNguyen.count)") }
                }
                .padding(.top, 3)
            }
            .padding(Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private func nhanNho(_ hinh: String, _ chu: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: hinh).font(.system(size: 9))
            Text(chu).font(.system(size: 10))
        }
        .foregroundColor(AppColors.textTertiary)
    }
}

// MARK: - Lối vào từ tab Học

struct DuAnEntryCard: View {
    var body: some View {
        NavigationLink { DuAnView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 21))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x0EA5E9), Color(hex: 0x38BDF8)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Dự án"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("41 \(T("dự án")) · \(T("mốc, tính năng, schema")) · \(T("song ngữ"))")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
        }
        .buttonStyle(.plain)
    }
}
