#if os(iOS)
import PencilKit
import SwiftUI

/// 📤 NỘP BÀI từ Vở làm bài sang Huấn luyện học kỳ (/hoc-tap) — 02/10/2026.
///
/// Người dùng: "viết trên iPad xong có nút gửi cả các trang đã viết, đặt tên, đỡ
/// phải chụp ảnh; vở không có AI để tránh gian lận". Nên:
///   • chỉ mở được từ cuốn `voLamBai == true` (không AI, không nhập ảnh/PDF);
///   • mỗi trang ra ẢNH đúng như trên màn (`XuatPdfVo.anhTrang`) rồi tải lên;
///   • kèm DẤU VẾT VIẾT TAY: số nét bút và khoảng thời gian các nét được viết
///     (`PKStrokePath.creationDate`) — 300 nét trong 40 phút khác hẳn một trang
///     dán vào trong 1 giây, và AI chấm/Claude đọc được dòng này.
struct NopBaiHocKyView: View {
    let cuon: CuonVo
    let trangs: [TrangVo]
    let luuTruoc: () -> Void

    @Environment(\.dismiss) private var dong
    @State private var viecs: [ViecGonHT] = []
    @State private var chonViec: Int?
    @State private var ten = ""
    @State private var ghiChu = ""
    @State private var chonTrang: Set<UUID> = []
    @State private var dangTai = false
    @State private var tienDo = ""
    @State private var loi: String?
    @State private var xong: String?

    var body: some View {
        NavigationStack {
            Form {
                if let xong {
                    Section {
                        Label(xong, systemImage: "checkmark.seal.fill").foregroundStyle(AppColors.success)
                        Text(T("Mở Học kỳ để xem AI chấm (20–60 giây), hoặc báo Claude trong phiên học."))
                            .font(.caption).foregroundStyle(AppColors.textTertiary)
                    }
                }
                Section(T("Nộp cho việc nào")) {
                    if viecs.isEmpty {
                        Text(dangTai ? T("Đang tải danh sách việc…") : T("Không có việc nào đang chờ nộp."))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    ForEach(viecs) { v in
                        Button { chonViec = v.id } label: {
                            HStack {
                                Text(HT.bieuTuong(v.loai))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.tieuDe).foregroundStyle(AppColors.textPrimary).lineLimit(2)
                                    Text("\(v.maMon) · \(HT.conLai(v.hanChot).0)").font(.caption).foregroundStyle(HT.mauMon(v.mau))
                                }
                                Spacer()
                                if chonViec == v.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.primary) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section(T("Tên bài nộp")) {
                    TextField(T("Ví dụ: Hiragana 46 chữ — bảng chép tay"), text: $ten)
                    TextField(T("Ghi chú cho người chấm (tuỳ chọn)"), text: $ghiChu, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    ForEach(Array(trangs.enumerated()), id: \.element.id) { i, t in
                        Toggle(isOn: Binding(get: { chonTrang.contains(t.id) },
                                             set: { if $0 { chonTrang.insert(t.id) } else { chonTrang.remove(t.id) } })) {
                            Text(t.tenHienThi(so: i + 1))
                        }
                    }
                } header: {
                    Text(String(format: T("Trang gửi (%d/%d)"), chonTrang.count, trangs.count))
                } footer: {
                    Text(T("Tối đa 10 trang mỗi lần nộp. Mỗi trang gửi đúng như bạn thấy trên màn."))
                }
                if let loi { Section { Text(loi).foregroundStyle(AppColors.error) } }
            }
            .navigationTitle(T("📤 Nộp bài"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Đóng")) { dong() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(dangTai && !tienDo.isEmpty ? tienDo : T("Gửi")) { Task { await gui() } }
                        .fontWeight(.semibold)
                        .disabled(dangTai || chonViec == nil || chonTrang.isEmpty || chonTrang.count > 10)
                }
            }
            .task { await napViec() }
            .onAppear {
                luuTruoc()
                // Mặc định: các trang CÓ NÉT (tối đa 10 trang cuối).
                chonTrang = Set(trangs.filter { $0.coNet }.suffix(10).map(\.id))
            }
        }
    }

    private func napViec() async {
        dangTai = true; defer { dangTai = false }
        do {
            let tq: TongQuanHT = try await APIClient.shared.request(.hocTapTongQuan)
            var thay = Set<Int>(), ds: [ViecGonHT] = []
            for v in tq.homNay + tq.quaHan + (tq.lich ?? []).flatMap(\.viec)
            where !thay.contains(v.id) && v.trangThai != "DAT" && v.trangThai != "CHO_CHAM" && v.trangThai != "VAN_DAP" {
                thay.insert(v.id); ds.append(v)
            }
            viecs = ds
            if chonViec == nil { chonViec = ds.first(where: { $0.batDauLuc != nil })?.id ?? ds.first?.id }
            if ten.isEmpty, let v = ds.first(where: { $0.id == chonViec }) { ten = v.tieuDe }
        } catch { loi = error.localizedDescription }
    }

    @MainActor
    private func gui() async {
        guard let viecId = chonViec else { return }
        dangTai = true; loi = nil
        defer { dangTai = false; tienDo = "" }
        let ds = trangs.filter { chonTrang.contains($0.id) }

        // Dấu vết viết tay: số nét + khoảng thời gian các nét được tạo.
        var soNet = 0
        var dau: Date?, cuoi: Date?
        for t in ds {
            for st in KhoVo.nap(t.id).strokes {
                soNet += 1
                let c = st.path.creationDate
                dau = min(dau ?? c, c); cuoi = max(cuoi ?? c, c)
            }
        }

        var tep: [[String: String]] = []
        for (i, t) in ds.enumerated() {
            tienDo = String(format: T("Tải %d/%d…"), i + 1, ds.count)
            guard let anh = XuatPdfVo.anhTrang(t), let jpg = anh.jpegData(compressionQuality: 0.82) else { continue }
            do {
                let f = try await APIClient.shared.upload(data: jpg, fileName: "vo-\(cuon.ten)-trang-\(i + 1).jpg",
                                                          mimeType: "image/jpeg", category: "images")
                tep.append(["url": f.url, "ten": "\(ten) — trang \(i + 1)", "loai": "image/jpeg"])
            } catch { loi = error.localizedDescription; return }
        }
        guard !tep.isEmpty else { loi = T("Không dựng được ảnh trang nào"); return }

        let f = DateFormatter(); f.dateFormat = "HH:mm dd/MM"
        var noiDung = "📓 Bài viết tay trên iPad — Vở làm bài “\(cuon.ten)” (KHÔNG có AI, không nhập ảnh/PDF)\n"
        noiDung += "Tên bài: \(ten)\n\(tep.count) trang · \(soNet) nét bút"
        if let dau, let cuoi { noiDung += " · viết từ \(f.string(from: dau)) đến \(f.string(from: cuoi))" }
        let gc = ghiChu.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gc.isEmpty { noiDung += "\nGhi chú: \(gc)" }

        tienDo = T("Đang nộp…")
        do {
            try await APIClient.shared.send(.hocTapNop(id: viecId, ["noiDung": noiDung, "tep": tep]))
            xong = String(format: T("Đã nộp %d trang — AI đang chấm"), tep.count)
            Haptics.xong()
        } catch { loi = error.localizedDescription }
    }
}
#endif
