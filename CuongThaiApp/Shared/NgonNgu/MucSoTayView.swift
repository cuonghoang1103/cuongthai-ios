import SwiftUI

// MARK: - Xem / sửa một mục

struct MucSoTayView: View {
    let ngonNgu: NgonNgu
    /// `nil` = tạo mục mới.
    let mucId: Int?
    var thuMucId: Int?
    @ObservedObject var vm: SoTayVM

    @State private var tieuDe = ""
    @State private var than = ""
    @State private var cachDoc = ""
    @State private var nghia = ""
    @State private var loai: LoaiMuc = .ghiChu
    @State private var dangSua = false
    @State private var dangTai = false
    @State private var dangLuu = false
    @State private var loi: String?
    @Environment(\.dismiss) private var dismiss

    private var laTaoMoi: Bool { mucId == nil }
    private var luuDuoc: Bool {
        !tieuDe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !than.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if dangTai {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if dangSua {
                    khungSua
                } else {
                    khungXem
                }
                if let l = loi {
                    Text(l)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(laTaoMoi ? "Mục mới" : (dangSua ? "Sửa" : ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if dangSua {
                    Button(dangLuu ? "Đang lưu…" : "Lưu") { Task { await luu() } }
                        .disabled(!luuDuoc || dangLuu)
                        .font(.system(size: 15, weight: .semibold))
                } else {
                    Button("Sửa") { dangSua = true }
                        .font(.system(size: 15))
                }
            }
        }
        .task { await nap() }
    }

    // MARK: Xem

    private var khungXem: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: loai.bieuTuong)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: loai.mau))
                Text(loai.ten)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: loai.mau))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: loai.mau).opacity(0.14)))
                Spacer()
            }

            Text(tieuDe)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !cachDoc.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Text(cachDoc)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                    if DocTu.doDuoc(ngonNgu.code) {
                        Button {
                            DocTu.shared.doc(tieuDe, code: ngonNgu.code, id: mucId)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !nghia.isEmpty {
                Text(nghia)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(AppColors.divider)

            // Thân là markdown — dùng lại bộ dựng của AI Chat thay vì hiện chữ
            // thô, vì mục lưu từ màn AI luôn có tiêu đề, gạch đầu dòng, bảng.
            NoiDungMarkdown(noiDung: than)
        }
    }

    // MARK: Sửa

    private var khungSua: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            nhan("LOẠI")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(LoaiMuc.tuTaoDuoc, id: \.rawValue) { l in
                        Button { loai = l } label: {
                            HStack(spacing: 4) {
                                Image(systemName: l.bieuTuong).font(.system(size: 11))
                                Text(l.ten).font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(loai == l ? AppColors.onPrimary : Color(hex: l.mau))
                            .padding(.horizontal, Spacing.sm + 2)
                            .padding(.vertical, Spacing.sm - 1)
                            .background(Capsule().fill(loai == l ? Color(hex: l.mau)
                                                       : Color(hex: l.mau).opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            nhan("TIÊU ĐỀ")
            TextField("Từ, mẫu câu, hoặc tên ghi chú", text: $tieuDe)
                .textFieldStyle(.plain)
                .padding(Spacing.sm + 2)
                .background(o)

            nhan("CÁCH ĐỌC (không bắt buộc)")
            TextField("Phiên âm, furigana, pinyin…", text: $cachDoc)
                .textFieldStyle(.plain)
                .padding(Spacing.sm + 2)
                .background(o)

            nhan("NGHĨA (không bắt buộc)")
            TextField("Nghĩa tiếng Việt", text: $nghia, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(Spacing.sm + 2)
                .background(o)

            nhan("NỘI DUNG — viết được markdown")
            TextEditor(text: $than)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
                .padding(Spacing.sm)
                .background(o)
        }
    }

    private func nhan(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .bold))
            .kerning(0.5)
            .foregroundColor(AppColors.textTertiary)
    }

    private var o: some View {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(AppColors.backgroundCard)
            .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(AppColors.border, lineWidth: 1))
    }

    // MARK: Nạp / lưu

    private func nap() async {
        guard let id = mucId else { dangSua = true; return }
        guard tieuDe.isEmpty else { return }
        dangTai = true; defer { dangTai = false }
        do {
            let m: MucSoTay = try await APIClient.shared.request(.mucSoTay(id: id))
            tieuDe = m.title
            than = m.body
            cachDoc = m.reading ?? ""
            nghia = m.meaning ?? ""
            loai = m.loai
        } catch {
            loi = error.localizedDescription
        }
    }

    private func luu() async {
        guard luuDuoc, !dangLuu else { return }
        dangLuu = true; defer { dangLuu = false }
        do {
            if let id = mucId {
                let _: MucSoTay = try await APIClient.shared.request(
                    .suaMucSoTay(id: id, tieuDe: tieuDe, than: than,
                                 cachDoc: cachDoc, nghia: nghia, loai: loai.rawValue))
                dangSua = false
            } else {
                let _: MucSoTay = try await APIClient.shared.request(
                    .taoMucSoTay(code: ngonNgu.code, thuMucId: thuMucId, loai: loai.rawValue,
                                 tieuDe: tieuDe, than: than, cachDoc: cachDoc, nghia: nghia))
                await vm.tai()
                dismiss()
                return
            }
            await vm.tai()
        } catch {
            loi = error.localizedDescription
        }
    }
}

// MARK: - Ôn tập sổ tay

struct OnTapSoTayView: View {
    let ngonNgu: NgonNgu
    @ObservedObject var vm: SoTayVM

    @State private var hangDoi: [MucSoTayGon] = []
    @State private var viTri = 0
    @State private var chiTiet: MucSoTay?
    @State private var daLat = false
    @State private var dangTai = false
    @Environment(\.dismiss) private var dismiss

    private var hienTai: MucSoTayGon? { viTri < hangDoi.count ? hangDoi[viTri] : nil }

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let m = hienTai {
                thanhTienDo
                the(m)
                Spacer(minLength: 0)
                if daLat { hangNut } else { nutLat }
            } else {
                Spacer()
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 54))
                        .foregroundColor(AppColors.success)
                    Text(hangDoi.isEmpty ? "Không có mục nào tới hạn."
                                         : "Xong \(hangDoi.count) mục hôm nay!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                Spacer()
                Button("Xong") { dismiss() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(AppColors.primary))
                    .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Ôn tập sổ tay")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Chốt hàng đợi MỘT lần lúc mở. Đọc thẳng `vm.mucToiHan` mỗi lần
            // vẽ thì mục vừa ôn xong rời khỏi danh sách và chỉ số nhảy lung
            // tung giữa chừng.
            if hangDoi.isEmpty { hangDoi = vm.mucToiHan }
            await napChiTiet()
        }
    }

    private var thanhTienDo: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text("\(viTri + 1)/\(hangDoi.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.backgroundTertiary)
                    Capsule().fill(AppColors.primary)
                        .frame(width: g.size.width * (Double(viTri) / Double(max(1, hangDoi.count))))
                }
            }
            .frame(height: 6)
        }
    }

    private func the(_ m: MucSoTayGon) -> some View {
        VStack(spacing: Spacing.md) {
            Text(m.loai.ten)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: m.loai.mau))
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(hex: m.loai.mau).opacity(0.14)))

            Text(m.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Cách đọc và nội dung đều GIẤU tới khi lật — thấy phiên âm là đọc
            // được ngay, mà đọc được thì phép đo "có nhớ không" mất nghĩa.
            if daLat {
                if let r = m.reading, !r.isEmpty {
                    Text(r)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                }
                if dangTai {
                    ProgressView()
                } else if let ct = chiTiet {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            if let ng = ct.meaning, !ng.isEmpty {
                                Text(ng)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            NoiDungMarkdown(noiDung: ct.body)
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(AppColors.backgroundCard))
    }

    private var nutLat: some View {
        Button {
            daLat = true
        } label: {
            Text("Xem đáp án")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(AppColors.primary))
        }
        .buttonStyle(.plain)
    }

    private var hangNut: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(MucNhoSoTay.allCases, id: \.rawValue) { m in
                Button {
                    Task { await cham(m) }
                } label: {
                    Text(m.nhan)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color(hex: m.mau)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cham(_ muc: MucNhoSoTay) async {
        guard let m = hienTai else { return }
        struct R: Codable { let id: Int; let nextReviewAt: String? }
        // Chấm xong đi tiếp NGAY, không chờ mạng: người ôn 40 thẻ mà mỗi thẻ
        // đợi một vòng gọi thì bỏ giữa chừng. Hỏng thì lần tải sau nó vẫn tới
        // hạn, không mất gì.
        Task { _ = try? await APIClient.shared.request(.onMucSoTay(id: m.id, chatLuong: muc.rawValue)) as R }
        daLat = false
        chiTiet = nil
        viTri += 1
        await napChiTiet()
        if viTri >= hangDoi.count { await vm.tai() }
    }

    private func napChiTiet() async {
        guard let m = hienTai else { return }
        dangTai = true; defer { dangTai = false }
        chiTiet = try? await APIClient.shared.request(.mucSoTay(id: m.id))
    }
}
