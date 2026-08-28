import SwiftUI

// MARK: - Danh sách kịch bản

struct MoPhongView: View {
    @StateObject private var may = MayMoPhong()
    @State private var tim = ""
    @State private var nhom: String?
    @AppStorage("mophong.tiengAnh") private var anh = false

    private var ds: [KichBan] {
        let k = tim.trimmingCharacters(in: .whitespaces).chuanHoaTim
        return may.kichBan.filter { s in
            (nhom == nil || s.group == nhom)
            && (k.isEmpty
                || (s.name?.chu(anh) ?? "").chuanHoaTim.contains(k)
                || (s.tagline?.chu(anh) ?? "").chuanHoaTim.contains(k))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
                TextField(T("Tìm kịch bản…"), text: $tim)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                if !tim.isEmpty {
                    Button { tim = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textTertiary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(Spacing.sm + 2)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(AppColors.backgroundCard))
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    the(T("Tất cả"), mau: AppColors.primary, chon: nhom == nil) { nhom = nil }
                    ForEach(may.nhom) { n in
                        the(n.name?.chu(anh) ?? n.id, mau: n.mau, chon: nhom == n.id) {
                            nhom = nhom == n.id ? nil : n.id
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.sm)

            if may.dangTai {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { cuon in
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        NeoDauTrang()
                        if let n = nhom, let g = may.nhom.first(where: { $0.id == n }),
                           let b = g.blurb?.chu(anh), !b.isEmpty {
                            Text(b).font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 2)
                        }
                        ForEach(ds) { s in
                            NavigationLink { ChayMoPhongView(kb: s, may: may, anh: $anh) } label: { hang(s) }
                                .buttonStyle(.plain)
                        }
                        if ds.isEmpty {
                            Text(may.loi ?? T("Không có kịch bản nào khớp."))
                                .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                                .padding(.top, Spacing.xl * 2)
                        }
                        Color.clear.frame(height: 72)
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .onChange(of: nhom) { _, _ in cuon.veDauTrang() }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle("\(T("Mô phỏng")) (\(may.kichBan.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { anh.toggle() } label: {
                    Text(anh ? "EN" : "VI").font(.system(size: 13, weight: .bold))
                }
            }
        }
        .task { may.napDanhMuc() }
    }

    private func the(_ n: String, mau: Color, chon: Bool, lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Text(n).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                .foregroundColor(chon ? AppColors.onPrimary : AppColors.textSecondary)
                .padding(.horizontal, Spacing.sm + 4).padding(.vertical, 6)
                .background(Capsule().fill(chon ? mau : AppColors.backgroundTertiary))
        }
        .buttonStyle(.plain)
    }

    private func hang(_ s: KichBan) -> some View {
        HStack(spacing: Spacing.sm + 2) {
            Image(systemName: s.bieuTuong)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(s.mau)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(s.mau.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name?.chu(anh) ?? s.id)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                if let t = s.tagline?.chu(anh), !t.isEmpty {
                    Text(t).font(.system(size: 11.5))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "play.circle.fill")
                .font(.system(size: 18)).foregroundColor(s.mau.opacity(0.8))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

// MARK: - Chạy một kịch bản

struct ChayMoPhongView: View {
    let kb: KichBan
    @ObservedObject var may: MayMoPhong
    @Binding var anh: Bool

    @State private var chon: [String: String] = [:]
    @State private var buoc = 0
    @State private var tien: Double = 1
    @State private var dangPhat = false
    @State private var viec: Task<Void, Never>?
    @State private var phong: CGFloat = 1
    @State private var mocPhong: CGFloat = 1
    @State private var coAm = AmMoPhong.bat

    private var b: BuocMP? { may.buoc.indices.contains(buoc) ? may.buoc[buoc] : nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    NeoDauTrang()
                    if !kb.cacTuyChon.isEmpty { khoiTuyChon }
                    if let e = may.loi { khoiLoi(e) }
                    else if kb.laSoDo {
                        VeSoDo(kb: kb, buoc: b, tien: tien, anh: anh)
                            .padding(Spacing.sm)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(AppColors.backgroundCard))
                    } else {
                        let tt = may.trangThai(toi: buoc)
                        ForEach(may.panel) { p in
                            VePanel(p: p, tt: tt[p.id] ?? TrangThaiPanel(), anh: anh)
                        }
                    }
                    if let s = b { khoiGiang(s) }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }
            if !may.buoc.isEmpty { thanhDieuKhien }
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(kb.name?.chu(anh) ?? kb.id)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    coAm.toggle()
                    AmMoPhong.bat = coAm
                    if coAm { AmMoPhong.shared.phat(.click) }
                } label: {
                    Image(systemName: coAm ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 13))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { anh.toggle() } label: {
                    Text(anh ? "EN" : "VI").font(.system(size: 13, weight: .bold))
                }
            }
        }
        // Mỗi bước tự khai `sfx` — phát đúng thứ kịch bản chọn, không tự đặt.
        .onChange(of: buoc) { _, m in
            guard may.buoc.indices.contains(m) else { return }
            AmMoPhong.shared.phat(may.buoc[m].sfx)
        }
        .task {
            if chon.isEmpty {
                for o in kb.cacTuyChon { chon[o.id] = o.defaultValue ?? o.cacLuaChon.first?.value }
            }
            dungLai()
        }
        .onDisappear { viec?.cancel() }
    }

    // MARK: Tuỳ chọn

    private var khoiTuyChon: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(kb.cacTuyChon) { o in
                VStack(alignment: .leading, spacing: 4) {
                    Text((o.label?.chu(anh) ?? o.id).uppercased())
                        .font(.system(size: 9, weight: .bold)).tracking(0.5)
                        .foregroundColor(AppColors.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(o.cacLuaChon) { c in
                                let dc = chon[o.id] == c.value
                                Button {
                                    chon[o.id] = c.value
                                    // Đổi tuỳ chọn ⇒ dựng lại TỪ ĐẦU. `build`
                                    // là hàm thuần nên không có trạng thái ẩn
                                    // nào sót lại giữa hai lần chạy.
                                    dungLai()
                                } label: {
                                    Text(c.label ?? c.value)
                                        .font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
                                        .foregroundColor(dc ? .white : AppColors.textSecondary)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Capsule().fill(dc ? (c.mau ?? kb.mau)
                                                                      : AppColors.backgroundTertiary))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let h = o.cacLuaChon.first(where: { $0.value == chon[o.id] })?.hint?.chu(anh),
                       !h.isEmpty {
                        Text(h).font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    // MARK: Lời giảng

    private func khoiGiang(_ s: BuocMP) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let k = s.kind, !k.isEmpty {
                    Text(k).font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(s.mauLuong))
                }
                if let st = s.status {
                    Text("\(st)").font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundColor(st >= 400 ? Color(hex: 0xEF4444) : Color(hex: 0x22C55E))
                }
                if let l = s.latencyMs, l > 0 {
                    Text("\(so(l)) ms").font(.system(size: 9).monospacedDigit())
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
            Text(s.title?.chu(anh) ?? "")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.detail?.chu(anh) ?? "")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let n = s.teachingNote?.chu(anh), !n.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10)).foregroundColor(Color(hex: 0xF59E0B))
                    Text(n).font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: 0xF59E0B).opacity(0.10)))
            }
            if let h = s.headers, !h.isEmpty { bangKV(T("Header"), h) }
            if let q = s.query, !q.isEmpty { bangKV("Query", q) }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func bangKV(_ ten: String, _ m: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ten.uppercased())
                .font(.system(size: 8.5, weight: .bold)).tracking(0.5)
                .foregroundColor(AppColors.textTertiary)
            ForEach(m.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                HStack(alignment: .top, spacing: 5) {
                    Text(k).font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.textTertiary)
                    Text(v).font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 2)
    }

    private func khoiLoi(_ e: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(T("Kịch bản lỗi"), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: 0xEF4444))
            Text(e).font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(Color(hex: 0xEF4444).opacity(0.10)))
    }

    // MARK: Thanh điều khiển

    private var thanhDieuKhien: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                ForEach(Array(may.buoc.enumerated()), id: \.element.id) { i, _ in
                    Button { dung(); buoc = i; tien = 1 } label: {
                        Capsule()
                            .fill(i == buoc ? kb.mau
                                  : (i < buoc ? kb.mau.opacity(0.4) : AppColors.backgroundTertiary))
                            .frame(height: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: Spacing.md) {
                Text("\(buoc + 1)/\(may.buoc.count)")
                    .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 48, alignment: .leading)
                nut("backward.fill") { dung(); if buoc > 0 { buoc -= 1 }; tien = 1 }
                Button { dangPhat ? dung() : phat() } label: {
                    Image(systemName: dangPhat ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 32)
                        .background(RoundedRectangle(cornerRadius: 9).fill(kb.mau))
                }
                .buttonStyle(.plain)
                nut("forward.fill") { dung(); if buoc < may.buoc.count - 1 { buoc += 1 }; tien = 1 }
                nut("arrow.counterclockwise") { dung(); buoc = 0; tien = 1 }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.backgroundSecondary)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(AppColors.border), alignment: .top)
    }

    private func nut(_ h: String, _ lam: @escaping () -> Void) -> some View {
        Button(action: lam) {
            Image(systemName: h).font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 32, height: 30)
        }
        .buttonStyle(.plain)
    }

    // MARK: Việc

    private func dungLai() {
        dung()
        may.dung(kb.id, tuyChon: chon)
        buoc = 0
        tien = 1
    }

    private func phat() {
        guard !may.buoc.isEmpty else { return }
        if buoc >= may.buoc.count - 1 { buoc = 0 }
        dangPhat = true
        viec?.cancel()
        viec = Task {
            while !Task.isCancelled, buoc < may.buoc.count - 1 {
                // Mỗi bước tự khai `duration` — kịch bản đã chọn nhịp cho từng
                // đoạn (một truy vấn CSDL chậm hơn một lần đọc cache), tôn
                // trọng nó thay vì áp một nhịp đều.
                let ms = may.buoc[buoc].duration ?? 900
                let khung = 26
                for k in 1...khung {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(nanoseconds: UInt64(ms * 1_000_000 / Double(khung)))
                    await MainActor.run { tien = Double(k) / Double(khung) }
                }
                await MainActor.run { if buoc < may.buoc.count - 1 { buoc += 1; tien = 0 } }
            }
            await MainActor.run { dangPhat = false; tien = 1 }
        }
    }

    private func dung() { viec?.cancel(); dangPhat = false }
}

// MARK: - Lối vào

struct MoPhongEntryCard: View {
    var body: some View {
        NavigationLink { MoPhongView() } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x0284C7), Color(hex: 0x38BDF8)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("Mô phỏng"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("62 \(T("kịch bản")) · \(T("chạy từng bước")) · \(T("song ngữ"))")
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
