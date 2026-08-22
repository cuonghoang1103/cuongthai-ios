import SwiftUI

// MARK: - Bộ nạp

@MainActor
final class CodeLabVM: ObservableObject {
    @Published var nhom: [NhomCodeLab] = []
    @Published var thongKe: ThongKeCodeLab?
    @Published var ketQua: [BaiTapCode] = []
    @Published var tongTim = 0
    @Published var dangTaiNhom = false
    @Published var dangTim = false
    @Published var loi: String?
    @Published var tim = ""
    @Published var doKho: DoKho?
    @Published var chonNhom: Int?

    private var viecTim: Task<Void, Never>?

    var dangLoc: Bool { !tim.trimmingCharacters(in: .whitespaces).isEmpty || doKho != nil }
    /// ⚠️ MỖI con số phải nói đúng thứ người dùng chạm được, và ba con số
    /// này đến từ HAI nguồn khác nhau — trộn nhầm là tự mâu thuẫn:
    ///
    /// - **Bài tập** lấy từ `/stats` (12.549). Đúng, vì ô tìm kiếm tìm trên
    ///   TOÀN kho, không chỉ trong các lộ trình hiện ở dưới.
    /// - **Lộ trình / nhóm** đếm từ danh sách ĐANG HIỆN (72 / 12). Lấy
    ///   `stats.tracks` (146) thì header khoe 146 mà cuộn xuống chỉ bấm được
    ///   72 — `/stats` đếm cả lộ trình NHÁP và lộ trình chưa gán nhóm, còn
    ///   `/groups` chỉ trả `status: PUBLISHED`.
    var tongBai: Int { thongKe?.exercises ?? nhom.reduce(0) { $0 + $1.soBai } }
    var tongLoTrinh: Int { nhom.reduce(0) { $0 + $1.dsLoTrinh.count } }
    var tongNhom: Int { nhom.count }
    /// Nhóm đang hiện sau khi lọc theo chủ đề.
    var nhomHien: [NhomCodeLab] {
        guard let id = chonNhom else { return nhom }
        return nhom.filter { $0.id == id }
    }

    func taiNhom() async {
        guard nhom.isEmpty else { return }
        dangTaiNhom = true; defer { dangTaiNhom = false }
        // Số chính thức nạp RIÊNG, hỏng cũng không chặn danh sách.
        thongKe = try? await APIClient.shared.request(.thongKeCodeLab)
        do {
            let ds: [NhomCodeLab] = try await APIClient.shared.request(.nhomCodeLab)
            // Bỏ nhóm rỗng, và bỏ luôn lộ trình 0 bài — "RoadMap · coming
            // soon · 0 bài" đứng đầu danh sách thì người mở lần đầu tưởng cả
            // kho đang trống.
            nhom = ds.compactMap { n -> NhomCodeLab? in
                let co = n.dsLoTrinh.filter { $0.soBai > 0 }
                return co.isEmpty ? nil : NhomCodeLab(id: n.id, name: n.name, slug: n.slug,
                                                      description: n.description, icon: n.icon,
                                                      color: n.color, tracks: co)
            }
            loi = nhom.isEmpty ? "Chưa có lộ trình nào." : nil
        } catch { loi = error.localizedDescription }
    }

    func timLai() {
        viecTim?.cancel()
        guard dangLoc else { ketQua = []; return }
        viecTim = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.chayTim()
        }
    }

    private func chayTim() async {
        dangTim = true; defer { dangTim = false }
        do {
            let t: TrangBaiTapCode = try await APIClient.shared.request(
                .dsBaiTapCode(nhom: nil, loTrinh: nil, doKho: doKho?.rawValue, ngonNgu: nil,
                              tim: tim.trimmingCharacters(in: .whitespaces), sap: nil, trang: 1))
            ketQua = t.exercises
            tongTim = t.total
        } catch { loi = error.localizedDescription }
    }
}

// MARK: - Màn chính

struct CodeLabView: View {
    @StateObject private var vm = CodeLabVM()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                oTim
                locDoKho
                locNhom

                if vm.dangLoc {
                    ketQuaTim
                } else if vm.dangTaiNhom && vm.nhom.isEmpty {
                    ProgressView().padding(.top, Spacing.xxl)
                } else if vm.nhom.isEmpty {
                    trong(vm.loi ?? "Chưa có lộ trình nào.")
                } else {
                    bangSo
                    ForEach(vm.nhomHien) { n in phanNhom(n) }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Code Lab")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.taiNhom() }
    }

    // MARK: Tìm và lọc

    private var oTim: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            TextField("Tìm trong 12.549 bài tập", text: $vm.tim)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: vm.tim) { _, _ in vm.timLai() }
            if !vm.tim.isEmpty {
                Button { vm.tim = ""; vm.timLai() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
    }

    private var locDoKho: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(DoKho.allCases, id: \.rawValue) { k in
                Button {
                    vm.doKho = vm.doKho == k ? nil : k
                    vm.timLai()
                } label: {
                    Text(k.ten)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(vm.doKho == k ? AppColors.onPrimary : Color(hex: k.mau))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(vm.doKho == k ? Color(hex: k.mau)
                                                   : Color(hex: k.mau).opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Lọc theo CHỦ ĐỀ — đúng thứ web có (Backend, Database, CuongThai,
    /// DevOps…). Thiếu nó thì muốn xem một mảng phải cuộn qua cả 12 nhóm.
    private var locNhom: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                nutNhom("Tất cả", icon: "square.grid.2x2.fill", mau: 0x64748B,
                        chon: vm.chonNhom == nil) { vm.chonNhom = nil }
                ForEach(vm.nhom) { n in
                    nutNhom(n.name, icon: n.bieuTuong, mau: mauNhom(n),
                            chon: vm.chonNhom == n.id) {
                        vm.chonNhom = vm.chonNhom == n.id ? nil : n.id
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func nutNhom(_ ten: String, icon: String, mau: UInt32,
                         chon: Bool, _ bam: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { bam() } } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(ten).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            }
            .foregroundColor(chon ? AppColors.onPrimary : Color(hex: mau))
            .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 7)
            .background(Capsule().fill(chon ? Color(hex: mau) : Color(hex: mau).opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    private var bangSo: some View {
        HStack(spacing: 0) {
            oSo("\(vm.tongBai)", "bài tập")
            vach
            oSo("\(vm.tongLoTrinh)", "lộ trình")
            vach
            oSo("\(vm.tongNhom)", "nhóm")
        }
        .padding(.vertical, Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private var vach: some View {
        Rectangle().fill(AppColors.divider).frame(width: 1, height: 26)
    }

    private func oSo(_ so: String, _ nhan: String) -> some View {
        VStack(spacing: 2) {
            Text(so).font(.system(size: 19, weight: .black)).foregroundColor(AppColors.textPrimary)
            Text(nhan).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Nhóm và lộ trình

    private func phanNhom(_ n: NhomCodeLab) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: n.bieuTuong)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: mauNhom(n)))
                Text(n.name.uppercased())
                    .font(.system(size: 12, weight: .black)).kerning(0.6)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(n.dsLoTrinh.count) lộ trình · \(n.soBai) bài")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.top, Spacing.sm)

            ForEach(n.dsLoTrinh) { lt in
                NavigationLink { ChuongTrinhHocView(loTrinh: lt) } label: { theLoTrinh(lt) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func mauNhom(_ n: NhomCodeLab) -> UInt32 {
        let h = (n.color ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        return h.count == 6 ? (UInt32(h, radix: 16) ?? 0x64748B) : 0x64748B
    }

    private func theLoTrinh(_ lt: LoTrinhCode) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.md) {
                // Ô màu + chữ đầu thay cho logo thương hiệu: backend không trả
                // icon lẫn ảnh bìa cho lộ trình (đo: null 72/72), còn bộ logo
                // của web là tài nguyên riêng bên đó.
                Text(lt.chuDau)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: lt.mau))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(lt.ten)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let l = lt.language, !l.isEmpty {
                        Text(l).font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }

            if lt.kiemChung { huyKiemChung }

            if !lt.moTa.isEmpty {
                Text(lt.moTa)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(3).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(AppColors.divider)

            HStack(spacing: Spacing.sm) {
                Text(lt.cap.ten)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: lt.cap.mau))
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: lt.cap.mau).opacity(0.15)))
                Spacer()
                Image(systemName: "target").font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                Text("\(lt.soBai) bài")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                if lt.soChuong > 0 {
                    Text("· \(lt.soChuong) chương")
                        .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.backgroundCard)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(AppColors.border, lineWidth: 1))
        )
    }

    private var huyKiemChung: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 10))
            Text("CUONGTHAI KIỂM CHỨNG")
                .font(.system(size: 9, weight: .black)).kerning(0.5)
        }
        .foregroundColor(Color(hex: 0x2BA84A))
        .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
        .background(Capsule().strokeBorder(Color(hex: 0x2BA84A).opacity(0.5), lineWidth: 1))
    }

    // MARK: Kết quả tìm

    @ViewBuilder
    private var ketQuaTim: some View {
        if vm.dangTim && vm.ketQua.isEmpty {
            ProgressView().padding(.top, Spacing.xl)
        } else if vm.ketQua.isEmpty {
            trong("Không tìm thấy bài nào khớp.")
        } else {
            HStack {
                Text("\(vm.tongTim) bài khớp")
                    .font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                Spacer()
            }
            ForEach(vm.ketQua) { b in
                NavigationLink { BaiTapCodeView(bai: b) } label: { HangBaiTap(bai: b) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func trong(_ chu: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 36)).foregroundColor(AppColors.textTertiary)
            Text(chu).font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.xxl)
    }
}

// MARK: - Một hàng bài tập (dùng chung)

struct HangBaiTap: View {
    let bai: BaiTapCode

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: bai.doKho.mau))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Tên chương giúp thấy mình đang ở đâu trong lộ trình — API
                // không sắp theo chương trình học được, nên ít nhất phải nói
                // rõ bài này thuộc phần nào.
                if let ch = bai.module?.ten, !ch.isEmpty {
                    Text(ch.uppercased())
                        .font(.system(size: 9, weight: .bold)).kerning(0.4)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
                Text(bai.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.sm) {
                    Text(bai.doKho.ten)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: bai.doKho.mau))
                    if let l = bai.language, !l.isEmpty {
                        Text("· \(l)").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                    }
                    if bai.phut > 0 {
                        Text("· \(bai.phut)′").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                    }
                    if bai.diem > 0 {
                        Text("· \(bai.diem)đ").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, Spacing.md)
            .padding(.trailing, Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

// MARK: - Bài tập của một lộ trình

struct BaiTapTheoLoTrinhView: View {
    let loTrinh: LoTrinhCode

    @State private var ds: [BaiTapCode] = []
    @State private var tong = 0
    @State private var trang = 1
    @State private var het = false
    @State private var dangTai = false
    @State private var loi: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                dauTrang
                ForEach(ds) { b in
                    NavigationLink { BaiTapCodeView(bai: b) } label: { HangBaiTap(bai: b) }
                        .buttonStyle(.plain)
                        .onAppear {
                            if b.id == ds.suffix(4).first?.id { Task { await nap() } }
                        }
                }
                if dangTai { ProgressView().padding(.vertical, Spacing.md) }
                if !dangTai && ds.isEmpty {
                    Text(loi ?? "Lộ trình này chưa có bài nào.")
                        .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                        .padding(.top, Spacing.xl)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(loTrinh.ten)
        .navigationBarTitleDisplayMode(.inline)
        .task { if ds.isEmpty { await nap() } }
    }

    private var dauTrang: some View {
        HStack(spacing: Spacing.md) {
            Text(loTrinh.chuDau)
                .font(.system(size: 17, weight: .black))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(hex: loTrinh.mau)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.xs) {
                    Text(loTrinh.cap.ten)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: loTrinh.cap.mau))
                        .padding(.horizontal, Spacing.sm).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: loTrinh.cap.mau).opacity(0.15)))
                    if let l = loTrinh.language, !l.isEmpty {
                        Text(l).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)
                    }
                }
                Text("\(tong > 0 ? tong : loTrinh.soBai) bài · \(loTrinh.soChuong) chương")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, Spacing.xs)
    }

    private func nap() async {
        guard !dangTai, !het else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let t: TrangBaiTapCode = try await APIClient.shared.request(
                // ⚠️ `sort: "difficulty"` chứ KHÔNG để mặc định. Mặc định của
                // backend là `createdAt desc` — với một LỘ TRÌNH HỌC thì đó là
                // sai hẳn: soi thật thấy bài "Capstone" (tổng kết cuối khoá)
                // nằm thứ HAI, còn bài vỡ lòng thì tít dưới. Backend không có
                // kiểu sắp theo chương trình học (chỉ `popular`/`difficulty`),
                // nên dễ-trước là thứ đúng nhất lấy được.
                .dsBaiTapCode(nhom: nil, loTrinh: loTrinh.id, doKho: nil, ngonNgu: nil,
                              tim: "", sap: "difficulty", trang: trang))
            ds += t.exercises
            tong = t.total
            het = t.page >= t.totalPages
            trang += 1
        } catch { loi = error.localizedDescription }
    }
}
// MARK: - Lối vào từ tab Học

struct CodeLabEntryCard: View {
    var body: some View {
        NavigationLink { CodeLabView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x1E293B), Color(hex: 0x475569)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Code Lab")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    // Số đo thật, không phải câu quảng cáo: nói ngay kho lớn
                    // cỡ nào để người ta biết có đáng mở không.
                    Text("12.549 bài tập · 9 ngôn ngữ · lọc theo độ khó")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(AppColors.backgroundCard)
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .strokeBorder(AppColors.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
