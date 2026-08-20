import SwiftUI

/// Sửa một dòng của bảng. Mỗi kiểu cột một ô nhập riêng.
///
/// ⚠️ Máy chủ nhận NGUYÊN bản đồ `values` chứ không nhận từng ô lẻ — gửi thiếu
/// khoá nào là ô đó bị xoá. Nên phải khởi tạo từ toàn bộ giá trị hiện có rồi
/// mới sửa lên đó.
///
/// ⚠️ Cột CREATED_TIME / LAST_EDITED_TIME / RELATION / ROLLUP / FORMULA thì máy
/// chủ **bỏ qua** khi ghi — hiện dạng chỉ-đọc thay vì cho gõ rồi lặng lẽ mất.
struct SuaDongBangView: View {
    let bang: BangDuLieu
    let dong: DongBang
    let luuXong: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var giaTri: [String: Any] = [:]
    @State private var dangLuu = false
    @State private var hoiXoa = false
    @State private var loi: String?

    init(bang: BangDuLieu, dong: DongBang, luuXong: @escaping () -> Void) {
        self.bang = bang
        self.dong = dong
        self.luuXong = luuXong
        var v: [String: Any] = [:]
        for (k, a) in dong.values ?? [:] { v[k] = a.value }
        _giaTri = State(initialValue: v)
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(bang.properties) { c in
                    Section {
                        if c.kieu.suaDuoc { oNhap(c) } else { oChiDoc(c) }
                    } header: {
                        HStack(spacing: 5) {
                            Image(systemName: c.kieu.bieuTuong).font(.system(size: 10))
                            Text(c.name)
                            if !c.kieu.suaDuoc {
                                Text("· chỉ đọc")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) { hoiXoa = true } label: {
                        Label("Xoá dòng này", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Sửa dòng")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await luu() }
                    } label: {
                        if dangLuu { ProgressView() } else { Text("Lưu").fontWeight(.semibold) }
                    }
                    .disabled(dangLuu)
                }
            }
            .alert("Xoá dòng?", isPresented: $hoiXoa) {
                Button("Xoá", role: .destructive) { Task { await xoa() } }
                Button("Huỷ", role: .cancel) { }
            }
            .alert("Bảng", isPresented: .constant(loi != nil)) {
                Button("OK") { loi = nil }
            } message: { Text(loi ?? "") }
        }
    }

    // MARK: Ô nhập theo kiểu cột

    @ViewBuilder
    private func oNhap(_ c: CotBang) -> some View {
        let k = String(c.id)
        switch c.kieu {
        case .checkbox:
            Toggle("", isOn: Binding(
                get: { giaTri[k] as? Bool ?? false },
                set: { giaTri[k] = $0 })).labelsHidden()

        case .number:
            TextField("0", text: Binding(
                get: {
                    if let d = giaTri[k] as? Double { return d == d.rounded() ? String(Int(d)) : String(d) }
                    if let i = giaTri[k] as? Int { return String(i) }
                    return giaTri[k] as? String ?? ""
                },
                set: { s in
                    // Ô rỗng phải thành `null`, KHÔNG phải 0 — 0 là một con số
                    // thật và sẽ làm sai mọi phép tính tổng ở cột đó.
                    giaTri[k] = s.isEmpty ? NSNull() : (Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0)
                }))
                .banPhimThapPhan()

        case .select, .status:
            Picker("", selection: Binding(
                get: { giaTri[k] as? String ?? "" },
                set: { giaTri[k] = $0.isEmpty ? NSNull() : $0 })) {
                    Text("— trống —").tag("")
                    ForEach(c.luaChon, id: \.self) { Text($0).tag($0) }
                }

        case .multiSelect:
            let dangCo = Set((giaTri[k] as? [Any])?.compactMap { $0 as? String } ?? [])
            ForEach(c.luaChon, id: \.self) { lc in
                Button {
                    var m = dangCo
                    if m.contains(lc) { m.remove(lc) } else { m.insert(lc) }
                    giaTri[k] = Array(m)
                } label: {
                    HStack {
                        Text(lc).foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if dangCo.contains(lc) {
                            Image(systemName: "checkmark").foregroundColor(AppColors.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

        case .date:
            DatePicker("", selection: Binding(
                get: { (giaTri[k] as? String).flatMap { Date.tuChuoiISO($0) } ?? Date() },
                set: { giaTri[k] = ISO8601DateFormatter().string(from: $0) }),
                displayedComponents: .date)
                .labelsHidden()

        default:
            TextField(c.kieu == .url ? "https://…" : (c.kieu == .email ? "ten@vidu.com" : "Nhập…"),
                      text: Binding(
                        get: { giaTri[k] as? String ?? "" },
                        set: { giaTri[k] = $0.isEmpty ? NSNull() : $0 }),
                      axis: .vertical)
                .lineLimit(1...6)
                .oKhongTuSua()
        }
    }

    private func oChiDoc(_ c: CotBang) -> some View {
        Text(dong.chu(c).isEmpty ? "—" : dong.chu(c))
            .font(.bodyMedium)
            .foregroundColor(AppColors.textSecondary)
    }

    // MARK: Việc

    private func luu() async {
        dangLuu = true
        defer { dangLuu = false }
        // Bỏ cột máy chủ tính lúc đọc: gửi lên cũng bị bỏ qua, giữ lại chỉ làm
        // gói tin to thêm.
        var gui: [String: Any] = [:]
        for c in bang.properties where c.kieu.suaDuoc {
            if let v = giaTri[String(c.id)] { gui[String(c.id)] = v }
        }
        do {
            let _: DongBang = try await APIClient.shared
                .request(.suaDongBang(rowId: dong.id, values: gui))
            Haptics.xong()
            luuXong()
            dismiss()
        } catch { loi = error.localizedDescription }
    }

    private func xoa() async {
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.xoaDongBang(rowId: dong.id))
            luuXong()
            dismiss()
        } catch { loi = error.localizedDescription }
    }
}
