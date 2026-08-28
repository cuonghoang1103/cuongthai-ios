import SwiftUI

// MARK: - Soi lỗi (bằng luật, không tốn lượt AI)

struct CVSoiLoiView: View {
    @ObservedObject var may: MayCV
    @State private var kq: KetQuaSoiLoi?
    @State private var dangChay = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                if dangChay {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let k = kq {
                    khoiDiem(k)
                    if !k.diemManh.isEmpty {
                        khoiDanhSach(T("Điểm mạnh"), k.diemManh, "checkmark.circle.fill", Color(hex: 0x22C55E))
                    }
                    if !k.cacLoi.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("\(T("Cần sửa")) (\(k.cacLoi.count))".uppercased())
                                .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                                .foregroundColor(AppColors.textTertiary)
                            ForEach(k.cacLoi) { l in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 5) {
                                        Circle().fill(l.mau).frame(width: 6, height: 6)
                                        Text(l.problem ?? "").font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AppColors.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                    }
                                    if let f = l.suggestedFix, !f.isEmpty {
                                        Text(f).font(.system(size: 12))
                                            .foregroundColor(AppColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.leading, 11)
                                    }
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(AppColors.backgroundCard))
                    }
                    if !k.thieuKyNang.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(T("Kỹ năng chưa có bằng chứng").uppercased())
                                .font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                                .foregroundColor(AppColors.textTertiary)
                            FlowChips(items: k.thieuKyNang, mau: Color(hex: 0xF59E0B))
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(AppColors.backgroundCard))
                    }
                } else {
                    Text(T("Chưa soi được. Hồ sơ còn quá trống?"))
                        .font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Soi lỗi CV"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            dangChay = true
            kq = await may.soiLoi()
            dangChay = false
        }
    }

    private func khoiDiem(_ k: KetQuaSoiLoi) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(spacing: 0) {
                    Text("\(k.score ?? 0)")
                        .font(.system(size: 34, weight: .heavy).monospacedDigit())
                        .foregroundColor(diemMau(Double(k.score ?? 0)))
                    Text("/100").font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(k.nhanBand).font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(k.mauBand))
                    if let c = k.counts {
                        Text("\(c.bullets ?? 0) \(T("dòng")) · \(c.strongBullets ?? 0) \(T("mạnh")) · \(c.weakBullets ?? 0) \(T("yếu"))")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let s = k.sixSecondTest, !s.isEmpty {
                // "Phép thử 6 giây" — thứ nhà tuyển dụng thật sự làm.
                VStack(alignment: .leading, spacing: 3) {
                    Label(T("Nhìn 6 giây thấy gì"), systemImage: "eye")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(AppColors.textTertiary)
                    Text(s).font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func khoiDanhSach(_ ten: String, _ ds: [String], _ hinh: String, _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(ten, systemImage: hinh)
                .font(.system(size: 11, weight: .bold)).foregroundColor(mau)
            ForEach(ds, id: \.self) { t in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(mau).frame(width: 4, height: 4).padding(.top, 6)
                    Text(t).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}

// MARK: - Chấm CV bằng AI

struct CVChamView: View {
    @ObservedObject var may: MayCV
    @State private var kq: ChamCV?
    @State private var dangChay = false
    @State private var loi: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NeoDauTrang()
                if may.congCham?.bat == false {
                    // Nói RÕ vì sao không dùng được, thay vì bày nút mờ.
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "lock.circle").font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(may.congCham?.reason ?? T("Tính năng này cần tài khoản Pro."))
                            .font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl)
                } else if dangChay {
                    VStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text(T("AI đang đọc CV… mất khoảng 20–40 giây"))
                            .font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, Spacing.xl * 2)
                } else if let k = kq {
                    khoiKetLuan(k)
                    if !k.diemManh.isEmpty { danhSach(T("Điểm mạnh"), k.diemManh, Color(hex: 0x22C55E)) }
                    ForEach(k.cacVanDe) { v in theVanDe(v) }
                    if !k.ruiRo.isEmpty { khoiRuiRo(k.ruiRo) }
                } else {
                    VStack(spacing: Spacing.md) {
                        Text(T("AI đọc CV như một người tuyển dụng: chỉ ra chỗ hỏng, vì sao nó hỏng, và sửa thế nào."))
                            .font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button { Task { await cham() } } label: {
                            Text(T("Chấm CV của tôi"))
                                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: CornerRadius.large)
                                    .fill(Color(hex: 0xEC4899)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, Spacing.xl)
                }
                if let e = loi {
                    Text(e).font(.system(size: 12)).foregroundColor(Color(hex: 0xEF4444))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
        }
        .background(AppColors.backgroundPrimary)
        .navigationTitle(T("Chấm CV bằng AI"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cham() async {
        dangChay = true; loi = nil
        defer { dangChay = false }
        do { kq = try await may.chamCV(may.taiLieu.first?.id) }
        catch { loi = error.localizedDescription }
    }

    private func khoiKetLuan(_ k: ChamCV) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                if let n = k.nhanKetLuan {
                    Text(n).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(k.mauKetLuan))
                }
                Spacer(minLength: 0)
                if k.injectionAttempted == true {
                    Label(T("Phát hiện chèn lệnh"), systemImage: "exclamationmark.shield.fill")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: 0xEF4444))
                }
            }
            if let s = k.sixSecondTest, !s.isEmpty {
                Text(s).font(.system(size: 13.5)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func theVanDe(_ v: VanDeCham) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(v.severity ?? "").font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Capsule().fill(v.mau))
                if let l = v.location, !l.isEmpty {
                    Text(l).font(.system(size: 10)).foregroundColor(AppColors.textTertiary)
                }
                Spacer(minLength: 0)
            }
            Text(v.problem ?? "").font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let w = v.whyItMatters, !w.isEmpty {
                Text(w).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let f = v.suggestedFix, !f.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 10))
                        .foregroundColor(Color(hex: 0x22C55E))
                    Text(f).font(.system(size: 12.5)).foregroundColor(Color(hex: 0x22C55E))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // ⚠️ `needsUserInput` = AI KHÔNG tự bịa được con số, phải hỏi bạn.
            // Hiện rõ câu hỏi thay vì giấu — đó là cả điểm của cờ này.
            if v.needsUserInput == true, let q = v.clarifyingQuestion, !q.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "questionmark.circle.fill").font(.system(size: 10))
                        .foregroundColor(Color(hex: 0xF59E0B))
                    Text(q).font(.system(size: 12)).foregroundColor(Color(hex: 0xF59E0B))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func khoiRuiRo(_ ds: [RuiRoPhongVan]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(T("Câu người phỏng vấn sẽ hỏi"), systemImage: "person.wave.2.fill")
                .font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: 0xA855F7))
            ForEach(ds) { r in
                VStack(alignment: .leading, spacing: 2) {
                    if let c = r.claim, !c.isEmpty {
                        Text("“\(c)”").font(.system(size: 11.5).italic())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Text(r.likelyQuestion ?? "").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let a = r.canYouAnswerIt, !a.isEmpty {
                        Text(a).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 3)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }

    private func danhSach(_ ten: String, _ ds: [String], _ mau: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ten.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(0.5)
                .foregroundColor(mau)
            ForEach(ds, id: \.self) { t in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(mau).frame(width: 4, height: 4).padding(.top, 6)
                    Text(t).font(.system(size: 12.5)).foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.large).fill(AppColors.backgroundCard))
    }
}
