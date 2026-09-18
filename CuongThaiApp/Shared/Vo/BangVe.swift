#if os(iOS)
import PencilKit
import SwiftUI
import UIKit

// MARK: - Khung vẽ một trang vở
//
// Bọc `PKCanvasView` — bộ vẽ của chính Apple, cùng thứ Notes/Freeform dùng.
// Không tự viết engine nét: độ trễ bút của PencilKit đi thẳng qua đường ưu
// tiên của hệ điều hành (~9ms trên iPad Pro), còn nét tự vẽ bằng
// `DragGesture` + `Path` như `LuyenVietView` hiện nay trễ gấp nhiều lần và
// không có nội suy lực nhấn.

/// Cầu nối để màn SwiftUI xin được ẢNH ĐANG HIỂN THỊ của khung vẽ.
///
/// Khoanh–hỏi phải cắt từ đúng thứ người dùng đang NHÌN: họ đã phóng to tới
/// mức đọc được chữ rồi mới khoanh. Cắt từ ảnh cả trang thu nhỏ thì một chữ
/// chỉ còn vài điểm ảnh — đúng lỗi người dùng báo 18/09/2026 ("nó chỉ chụp
/// full màn hình, chọn từng chữ chi tiết không được").
@MainActor
final class CauNoiBangVe: ObservableObject {
    weak var vc: BangVeVC?
    func anhDangNhin() -> UIImage? { vc?.anhDangNhin() }
}

struct BangVe: UIViewControllerRepresentable {
    let idTrang: UUID
    let giay: LoaiGiay
    let khoTrang: CGSize
    /// Nền PDF / ảnh quét nằm dưới lớp mực.
    var nenPdfTen: String? = nil
    var nenPdfTrang: Int = 0
    var nenAnhTen: String? = nil
    /// Bật bảng công cụ của hệ thống (bút, tẩy, thước, lasso, màu).
    var hienCongCu: Bool = true
    /// Tăng lên là đưa trang về vừa bề ngang khung.
    var lanVuaKhung: Int = 0
    /// Gọi sau mỗi lần tự lưu, để màn ngoài cập nhật ảnh thu nhỏ + "đã lưu".
    var khiLuu: ((PKDrawing) -> Void)?
    /// Số nét hiện tại sau mỗi lần vẽ thêm — để gắn mốc thời gian ghi âm.
    var khiThemNet: ((Int) -> Void)?
    /// Người dùng chạm vào nét thứ mấy (khi đang ở chế độ tua theo nét).
    var khiChamNet: ((Int) -> Void)?
    /// Bật chế độ chạm-để-tua: ngón tay chạm vào nét thay vì cuộn.
    var chamDeTua: Bool = false
    /// Ngón tay để CUỘN/PHÓNG, chỉ bút mới viết.
    var nganTayCuon: Bool = false
    /// Câu ngắn hiện thoáng qua khi bóp bút — bằng chứng nhìn thấy được.
    var khiBaoBut: ((String) -> Void)?
    /// Bóp bút để GỌI TRỢ LÝ thay vì làm việc hệ thống đã gán.
    var bopGoiTroLy: Bool = false
    var khiBopGoiTroLy: (() -> Void)?
    var cauNoi: CauNoiBangVe? = nil

    func makeUIViewController(context: Context) -> BangVeVC {
        let vc = BangVeVC(idTrang: idTrang, giay: giay, khoTrang: khoTrang)
        vc.datNen(pdfTen: nenPdfTen, trang: nenPdfTrang, anhTen: nenAnhTen)
        vc.khiLuu = khiLuu
        vc.khiBaoBut = khiBaoBut
        vc.khiThemNet = khiThemNet
        vc.khiChamNet = khiChamNet
        vc.bopGoiTroLy = bopGoiTroLy
        vc.khiBopGoiTroLy = khiBopGoiTroLy
        vc.datNganTayCuon(nganTayCuon)
        vc.datChamDeTua(chamDeTua)
        cauNoi?.vc = vc
        return vc
    }

    /// ⚠️ Lưới an toàn cuối cùng cho việc lưu.
    ///
    /// Đổi trang bằng `.id(...)` khiến SwiftUI THÁO bộ điều khiển cũ ra. Có
    /// đường tháo mà `viewWillDisappear` không chạy (view chưa từng vào cây
    /// hiển thị, hoặc bị gỡ trong cùng một vòng cập nhật) — và mất đúng nét
    /// vừa viết trước khi lật trang là lỗi không ai tha thứ cho một cuốn vở.
    static func dismantleUIViewController(_ vc: BangVeVC, coordinator: ()) {
        vc.luuNgay()
    }

    func updateUIViewController(_ vc: BangVeVC, context: Context) {
        vc.capNhat(giay: giay, khoTrang: khoTrang)
        vc.datNen(pdfTen: nenPdfTen, trang: nenPdfTrang, anhTen: nenAnhTen)
        vc.datHienCongCu(hienCongCu)
        vc.xinVuaKhung(lanVuaKhung)
        vc.khiLuu = khiLuu
        vc.khiBaoBut = khiBaoBut
        vc.khiThemNet = khiThemNet
        vc.khiChamNet = khiChamNet
        vc.bopGoiTroLy = bopGoiTroLy
        vc.khiBopGoiTroLy = khiBopGoiTroLy
        vc.datNganTayCuon(nganTayCuon)
        vc.datChamDeTua(chamDeTua)
        cauNoi?.vc = vc
    }
}

// MARK: - Bộ điều khiển

final class BangVeVC: UIViewController {

    // MARK: Trạng thái

    private(set) var idTrang: UUID
    private var giay: LoaiGiay
    private var khoTrang: CGSize

    var khiLuu: ((PKDrawing) -> Void)?
    /// Báo một câu ngắn lên màn khi cú bóp bút ăn — không có phản hồi nhìn
    /// thấy được thì người dùng bóp lại mấy lần rồi kết luận "hỏng".
    var khiBaoBut: ((String) -> Void)?
    var khiThemNet: ((Int) -> Void)?
    var khiChamNet: ((Int) -> Void)?
    var bopGoiTroLy = false
    var khiBopGoiTroLy: (() -> Void)?
    /// Số nét ở lần đổi trước — để phân biệt "vẽ thêm" với "vừa tẩy".
    fileprivate var soNetTruoc = 0

    let canvas = PKCanvasView()
    private let nen = GiayNenView()
    private let nenTaiLieu = NenTrangView()
    /// Giữ MẠNH: `PKToolPicker` này do chính màn hình tạo ra, không có ai
    /// khác giữ hộ. Khai `weak` là nó bị thu hồi ngay sau khi dựng xong và
    /// bảng công cụ biến mất — hoặc chớp lên rồi tắt.
    private var bangCongCu: PKToolPicker?

    /// Bộ hoàn tác RIÊNG của màn này.
    ///
    /// ⚠️ Không dựa vào `undoManager` mà responder chain tự tìm: trong
    /// SwiftUI, cây responder đổi theo từng lần dựng lại view, nên có lúc
    /// canvas nhận được bộ hoàn tác của cửa sổ, có lúc nhận `nil`. Triệu
    /// chứng là "hai ngón chạm để hoàn tác lúc ăn lúc không" — thứ người
    /// dùng báo là app lỗi vặt chứ không ai ngồi tìm được nguyên nhân.
    private let boHoanTac = UndoManager()
    override var undoManager: UndoManager? { boHoanTac }

    /// Hẹn giờ tự lưu. Lưu mỗi nét là ghi đĩa hàng trăm lần một phút; lưu
    /// quá thưa thì mất bài khi app bị hệ thống thu hồi bộ nhớ. 2 giây là
    /// chỗ đứng giữa, cộng với lưu CƯỠNG BỨC lúc rời màn và lúc app xuống nền.
    private var henLuu: Timer?
    private var choLuu = false

    private var mayPhanHoi: Any?   // UICanvasFeedbackGenerator (iOS 17.5+)

    // MARK: Vòng đời

    init(idTrang: UUID, giay: LoaiGiay, khoTrang: CGSize) {
        self.idTrang = idTrang
        self.giay = giay
        self.khoTrang = khoTrang
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) chưa dùng tới") }

    override func viewDidLoad() {
        super.viewDidLoad()
        dungKhung()
        napNet()
        ganTuongTacBut()
        theoDoiVongDoiApp()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        canvas.becomeFirstResponder()
        canhGiuaLanDau()
        datHienCongCu(muonHienCongCu)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        luuNgay()
    }

    deinit {
        henLuu?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Dựng khung

    private func dungKhung() {
        view.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.04, alpha: 1)
                                          : UIColor(white: 0.88, alpha: 1)
        }

        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = self
        canvas.alwaysBounceVertical = true
        canvas.minimumZoomScale = 0.4
        canvas.maximumZoomScale = 5.0
        canvas.contentSize = khoTrang
        // ⚠️ `.default`, KHÔNG phải `.pencilOnly`.
        //
        // `.pencilOnly` đúng với ý muốn — tỳ cả bàn tay lên màn mà trang
        // không bị kéo đi — nhưng trên máy CHƯA từng thấy Apple Pencil (mọi
        // iPhone, máy mô phỏng, iPad khi bút hết pin) thì ngón tay chỉ cuộn
        // và không có nét nào ra. Đo thật trên iPad mô phỏng 17/09/2026:
        // chạm khắp trang, không một nét. Trông y hệt "khung vẽ chết".
        //
        // `.default` làm đúng cả hai: vẽ được bằng ngón tay cho tới khi hệ
        // thống thấy Pencil lần đầu, từ đó ngón tay quay về vai trò cuộn.
        canvas.drawingPolicy = .default
        canvas.contentInsetAdjustmentBehavior = .never

        nen.giay = giay
        nen.khoTrang = khoTrang
        nen.frame = CGRect(origin: .zero, size: khoTrang)

        view.addSubview(canvas)
        // Nền là subview CỦA canvas ở lớp dưới cùng: nhờ vậy nó cuộn cùng
        // nội dung mà không phải đồng bộ `contentOffset` bằng tay.
        // Thứ tự: giấy kẻ (dưới cùng) → trang tài liệu → mực.
        canvas.insertSubview(nen, at: 0)
        canvas.insertSubview(nenTaiLieu, aboveSubview: nen)

        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        if #available(iOS 17.5, *) {
            mayPhanHoi = UICanvasFeedbackGenerator(view: canvas)
        }
    }

    /// Bảng công cụ của hệ thống. Từ iOS 14 nó là một cửa sổ nổi do
    /// `PKToolPicker` quản lý; muốn nó hiện thì canvas phải là first responder.
    /// ⚠️ Gọi từ `viewDidAppear`, KHÔNG phải `viewDidLoad`.
    ///
    /// `PKToolPicker` là một cửa sổ nổi của hệ thống; nó chỉ gắn được khi
    /// khung vẽ đã nằm trong một cửa sổ thật VÀ đang là first responder. Gọi
    /// sớm thì lệnh trôi đi không lỗi, và người dùng mở vở ra thấy trang
    /// giấy mà không có bút, không có màu, không có tẩy — đo thật trên iPad
    /// mô phỏng 17/09/2026, bảng công cụ không hề xuất hiện.
    func datHienCongCu(_ hien: Bool) {
        muonHienCongCu = hien
        guard view.window != nil else { return }   // chưa vào cửa sổ: để `viewDidAppear` lo
        let picker: PKToolPicker
        if let sang = bangCongCu {
            picker = sang
        } else {
            picker = PKToolPicker()
            picker.addObserver(canvas)
            picker.addObserver(self)
            bangCongCu = picker
        }
        if hien { canvas.becomeFirstResponder() }
        picker.setVisible(hien, forFirstResponder: canvas)
    }
    private var muonHienCongCu = true

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        theoBeRongMoi()
        capNhatNenVaLe()
    }

    /// Khung hẹp đi (mở dải trang, vào Split View, xoay máy) thì trang phải
    /// vừa lại bề ngang MỚI.
    ///
    /// ⚠️ Chỉ chỉnh khi người dùng CHƯA tự phóng to. Đo trên iPad mô phỏng
    /// 17/09/2026: mở dải trang xong trang giấy tràn hẳn ra mép phải và phải
    /// chụm hai ngón mới đọc lại được — nhưng nếu chỉnh vô điều kiện thì mỗi
    /// lần bật/tắt dải trang lại ném người đang phóng to xem chi tiết về mức
    /// toàn trang, còn khó chịu hơn.
    private func theoBeRongMoi() {
        let rong = canvas.bounds.width
        guard rong > 0, khoTrang.width > 0 else { return }
        let vuaMoi = min(max((rong - 32) / khoTrang.width, canvas.minimumZoomScale),
                         canvas.maximumZoomScale)
        defer { zoomVua = vuaMoi }
        guard let cu = zoomVua, abs(vuaMoi - cu) > 0.001 else { return }
        // Đang ở đúng mức "vừa khung" của bề rộng CŨ ⇒ người dùng chưa đụng
        // vào mức phóng, cứ đưa sang mức vừa khung mới.
        guard abs(canvas.zoomScale - cu) < cu * 0.01 else { return }
        canvas.zoomScale = vuaMoi
    }
    private var zoomVua: CGFloat?

    /// Giữ trang nằm GIỮA khung khi nó nhỏ hơn màn hình, và cập nhật nền theo
    /// mức phóng hiện tại.
    private func capNhatNenVaLe() {
        let z = canvas.zoomScale
        let khoPhong = CGSize(width: khoTrang.width * z, height: khoTrang.height * z)
        nen.frame = CGRect(origin: .zero, size: khoPhong)
        nen.tyLe = z
        nenTaiLieu.frame = CGRect(origin: .zero, size: khoPhong)
        nenTaiLieu.dat(pdfTen: pdfTen, trang: pdfTrang, anhTen: anhTen, khoTrang: khoTrang)
        canvas.contentSize = khoPhong

        let duThua = max(0, (canvas.bounds.width - khoPhong.width) / 2)
        let duThuaDoc = max(0, (canvas.bounds.height - khoPhong.height) / 2)
        // ⚠️ Bảng công cụ NỔI LÊN TRÊN trang, không đẩy trang lên. Không chừa
        // chỗ cho nó thì mấy dòng cuối mỗi trang nằm vĩnh viễn dưới gầm bảng
        // — người dùng báo 18/09/2026 "bị che bên dưới rồi không thấy nội
        // dung". `frameObscured(in:)` là số ĐO THẬT của phần bị che, không
        // phải hằng số đoán bừa: bảng đổi cỡ theo máy và theo chỗ người dùng
        // kéo nó tới.
        canvas.contentInset = UIEdgeInsets(top: duThuaDoc, left: duThua,
                                           bottom: max(duThuaDoc, cheDuoi()), right: duThua)
    }

    /// Phần đáy khung bị bảng công cụ che, tính theo số đo thật.
    private func cheDuoi() -> CGFloat {
        guard let bang = bangCongCu else { return 0 }
        let che = bang.frameObscured(in: view)
        guard !che.isNull, che.height > 0 else { return 0 }
        return max(0, view.bounds.maxY - che.minY) + 12
    }

    private var daCanhGiua = false
    private func canhGiuaLanDau() {
        guard !daCanhGiua, canvas.bounds.width > 0 else { return }
        daCanhGiua = true
        // Mở trang ra là thấy vừa bề ngang — không ai muốn mở vở ra đã phải
        // chụm hai ngón thu nhỏ trước khi viết được chữ nào.
        let vua = min(max((canvas.bounds.width - 32) / khoTrang.width,
                          canvas.minimumZoomScale), canvas.maximumZoomScale)
        canvas.zoomScale = vua
        zoomVua = vua
        capNhatNenVaLe()
        canvas.contentOffset = CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
    }

    /// Đưa trang về đúng mức vừa bề ngang. Nhận một BỘ ĐẾM chứ không phải
    /// cờ bật/tắt: người dùng có thể xin lại nhiều lần liên tiếp, mà một cờ
    /// `true` thì lần thứ hai không có gì đổi để SwiftUI nhận ra.
    func xinVuaKhung(_ lan: Int) {
        guard lan != lanVuaKhungDaLam else { return }
        lanVuaKhungDaLam = lan
        guard canvas.bounds.width > 0, khoTrang.width > 0 else { return }
        let vua = min(max((canvas.bounds.width - 32) / khoTrang.width,
                          canvas.minimumZoomScale), canvas.maximumZoomScale)
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self else { return }
            canvas.zoomScale = vua
            zoomVua = vua
            capNhatNenVaLe()
            canvas.contentOffset = CGPoint(x: -canvas.contentInset.left,
                                           y: canvas.contentOffset.y)
        }
    }
    private var lanVuaKhungDaLam = 0

    private var pdfTen: String?
    private var pdfTrang = 0
    private var anhTen: String?

    func datNen(pdfTen: String?, trang: Int, anhTen: String?) {
        guard pdfTen != self.pdfTen || trang != pdfTrang || anhTen != self.anhTen else { return }
        self.pdfTen = pdfTen
        self.pdfTrang = trang
        self.anhTen = anhTen
        nenTaiLieu.dat(pdfTen: pdfTen, trang: trang, anhTen: anhTen, khoTrang: khoTrang)
    }

    func capNhat(giay moi: LoaiGiay, khoTrang khoMoi: CGSize) {
        var doi = false
        if moi != giay { giay = moi; nen.giay = moi; doi = true }
        if khoMoi != khoTrang { khoTrang = khoMoi; nen.khoTrang = khoMoi; doi = true }
        if doi { capNhatNenVaLe() }
    }

    // MARK: Nạp / lưu

    private func napNet() {
        let drawing = KhoVo.nap(idTrang)
        canvas.drawing = drawing
        // Nạp xong mới gắn hẹn giờ — gán `drawing` cũng phát
        // `canvasViewDrawingDidChange`, và nếu coi đó là "người dùng vừa
        // viết" thì mọi trang mở ra đều bị đánh dấu bẩn rồi ghi lại y nguyên.
        choLuu = false
    }

    private func henGioLuu() {
        choLuu = true
        henLuu?.invalidate()
        henLuu = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.luuNgay() }
        }
    }

    func luuNgay() {
        guard choLuu else { return }
        choLuu = false
        henLuu?.invalidate()
        let drawing = canvas.drawing
        let kho = khoTrang
        let id = idTrang
        // Chộp con trỏ nền TRÊN luồng chính rồi mới rời đi — `Task.detached`
        // bên dưới không được đụng vào thuộc tính của bộ điều khiển.
        let pdfT = pdfTen, pdfTr = pdfTrang, anhT = anhTen
        KhoVo.ghi(drawing, cho: id)
        khiLuu?(drawing)
        // Ảnh thu nhỏ dựng ở luồng nền: với trang viết dày nó mất vài chục
        // mili giây, đủ để nét bút khựng nếu làm ngay trên luồng chính.
        Task.detached(priority: .utility) {
            KhoVo.dungAnhNho(drawing, kho: kho, cho: id,
                             nenPdfTen: pdfT, nenPdfTrang: pdfTr, nenAnhTen: anhT)
        }
    }

    private func theoDoiVongDoiApp() {
        // App bị thu hồi lúc đang ở nền thì không có lần chạy nào nữa để lưu.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.luuNgay() }
            }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.luuNgay() }
            }
    }

    // MARK: Apple Pencil Pro

    /// Chạm vào một nét để nhảy tới đoạn ghi âm lúc viết nét đó.
    ///
    /// ⚠️ Chỉ bật khi người dùng xin. Bật thường trực thì cú chạm để cuộn
    /// trang cũng thành lệnh tua, và bản ghi nhảy lung tung mỗi lần lật vở.
    private var nganTayCuon = false

    /// Ngón tay để CUỘN thay vì vẽ.
    ///
    /// ⚠️ Đây là lỗi người dùng báo 18/09/2026: nhập PDF vào, trang dài hơn
    /// màn hình, vuốt một ngón để đọc tiếp thì nó VẼ một vệt mực chứ không
    /// cuộn — trang đứng im, người dùng tưởng app treo. `.default` của
    /// PencilKit cho ngón tay vẽ cho tới khi nó thấy Apple Pencil, mà lúc
    /// đang đọc thì bút nằm trên bàn.
    ///
    /// Hai ngón thì cuộn được ở cả hai chế độ — nhưng không ai đoán ra điều
    /// đó, nên phải có một nút NHÌN THẤY ĐƯỢC ở thanh trên.
    func datNganTayCuon(_ bat: Bool) {
        guard bat != nganTayCuon else { return }
        nganTayCuon = bat
        capNhatChinhSachVe()
    }

    /// Một chỗ duy nhất quyết định ngón tay làm gì. Hai cờ cùng đòi đổi
    /// `drawingPolicy` mà mỗi chỗ tự đặt thì cái sau xoá cái trước.
    private func capNhatChinhSachVe() {
        canvas.drawingPolicy = (nganTayCuon || chamTua != nil) ? .pencilOnly : .default
    }

    func datChamDeTua(_ bat: Bool) {
        guard bat != (chamTua != nil) else { return }
        // ⚠️ Ở chế độ tua, NGÓN TAY không được vẽ nữa — nếu không thì mỗi cú
        // chạm để nghe lại để lại một chấm mực trên trang. Đo thật trên máy
        // mô phỏng 17/09/2026: chạm vào nét xong thấy một chấm đen mới.
        // Bút vẫn viết được bình thường, nên đang nghe vẫn ghi chú thêm được.
        if bat {
            let g = UITapGestureRecognizer(target: self, action: #selector(chamVaoNet(_:)))
            canvas.addGestureRecognizer(g)
            chamTua = g
            capNhatChinhSachVe()
        } else if let g = chamTua {
            canvas.removeGestureRecognizer(g)
            chamTua = nil
            capNhatChinhSachVe()
        }
    }
    private var chamTua: UITapGestureRecognizer?

    @objc private func chamVaoNet(_ g: UITapGestureRecognizer) {
        let diem = g.location(in: canvas)
        // Quy về toạ độ TRANG: cú chạm đọc theo khung đang phóng, còn nét
        // lưu theo toạ độ trang gốc.
        let z = max(canvas.zoomScale, 0.01)
        let tai = CGPoint(x: diem.x / z, y: diem.y / z)
        var ganNhat: (chiSo: Int, kc: CGFloat)?
        for (i, net) in canvas.drawing.strokes.enumerated() {
            for d in net.path.interpolatedPoints(by: .distance(8)) {
                let p = d.location.applying(net.transform)
                let kc = hypot(p.x - tai.x, p.y - tai.y)
                if ganNhat == nil || kc < ganNhat!.kc { ganNhat = (i, kc) }
            }
        }
        // 44pt: nhỏ hơn thì chạm trượt hoài, lớn hơn thì chạm vào chỗ trống
        // giữa trang cũng nhảy tới một nét ở tận đâu.
        if let g = ganNhat, g.kc < 44 { khiChamNet?(g.chiSo) }
    }

    /// Ảnh của đúng vùng đang hiển thị: nền tài liệu + giấy + nét bút, ở
    /// mức phóng hiện tại.
    ///
    /// ⚠️ `afterScreenUpdates: false`. Đặt `true` thì UIKit chạy một vòng
    /// cập nhật màn hình ngay giữa lúc lớp phủ khoanh đang hiện, và ảnh chụp
    /// dính luôn cả lớp phủ đó vào — người dùng gửi cho AI một tấm ảnh có
    /// vòng khoanh của chính mình đè lên chữ.
    func anhDangNhin() -> UIImage? {
        let khung = canvas.bounds
        guard khung.width > 1, khung.height > 1 else { return nil }
        let r = UIGraphicsImageRenderer(bounds: khung)
        return r.image { _ in
            canvas.drawHierarchy(in: khung, afterScreenUpdates: false)
        }
    }

    private func ganTuongTacBut() {
        guard #available(iOS 17.5, *) else {
            NhatKy.vo.info("bút: iOS < 17.5, không có API bóp")
            return
        }
        let tuongTac = UIPencilInteraction()
        tuongTac.delegate = self
        // ⚠️ Gắn vào CHÍNH khung vẽ, không phải view gốc.
        //
        // `UIPencilInteraction` chỉ bắn khi view mang nó đang hiển thị VÀ là
        // nơi cây trách nhiệm đi qua. Gắn ở view gốc thì `PKCanvasView` nằm
        // đè lên nhận trước và nuốt cú bóp — bóp bút không ra gì, không lỗi,
        // không log. Đo trên iPad Pro M5 thật 17/09/2026.
        canvas.addInteraction(tuongTac)
        NhatKy.vo.info("bút: đã gắn tương tác · hành động bóp hệ thống đang đặt = \(UIPencilInteraction.preferredSqueezeAction.rawValue) · bóp-được-theo-máy = \(UIPencilInteraction.prefersHoverToolPreview)")
    }

    /// Đổi qua lại giữa bút đang dùng và tẩy.
    fileprivate func daoButTay() {
        if canvas.tool is PKEraserTool {
            canvas.tool = butTruocDo ?? PKInkingTool(.pen, color: .label, width: 4)
        } else {
            butTruocDo = canvas.tool as? PKInkingTool
            canvas.tool = PKEraserTool(.bitmap)
        }
    }
    private var butTruocDo: PKInkingTool?

    @available(iOS 17.5, *)
    fileprivate func rungPhanHoi(tai diem: CGPoint) {
        (mayPhanHoi as? UICanvasFeedbackGenerator)?.alignmentOccurred(at: diem)
    }
}

// MARK: - Nét vẽ đổi

// Bảng công cụ đổi chỗ (người dùng kéo nó, xoay máy, thu gọn) thì phần đáy
// bị che cũng đổi — phải tính lại lề, không thì lại che mất dòng cuối.
extension BangVeVC: PKToolPickerObserver {
    func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        capNhatNenVaLe()
    }
}

extension BangVeVC: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        henGioLuu()
        let n = canvasView.drawing.strokes.count
        // Chỉ báo khi nét TĂNG. Tẩy cũng gọi hàm này, và coi mọi thay đổi là
        // "vừa viết thêm" thì mỗi lần xoá lại ghi thêm một mốc thời gian.
        if n > soNetTruoc { khiThemNet?(n) }
        soNetTruoc = n
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        capNhatNenVaLe()
    }
}

// MARK: - Bóp bút (Apple Pencil Pro)

@available(iOS 17.5, *)
extension BangVeVC: UIPencilInteractionDelegate {
    func pencilInteraction(_ interaction: UIPencilInteraction,
                           didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        // Chỉ xử lý lúc NHẢ. Pha `.began` bắn ngay khi ngón vừa chạm vào thân
        // bút, nên hành động gắn vào đó sẽ chạy cả những lần cầm lại bút.
        NhatKy.vo.info("bút: NHẬN cú bóp, pha = \(squeeze.phase.rawValue)")
        guard squeeze.phase == .ended else { return }

        // Người dùng chọn "bóp để gọi trợ lý" thì CHẶN TRƯỚC mọi việc hệ
        // thống gán. Không cướp mặc định: mặc định vẫn là việc trong Cài đặt
        // › Apple Pencil (thường là Tẩy), phải tự bật trong menu của vở.
        NhatKy.vo.info("bút: pha CUỐI · bopGoiTroLy = \(bopGoiTroLy)")
        if bopGoiTroLy {
            NhatKy.vo.info("bút: → gọi TRỢ LÝ")
            khiBopGoiTroLy?()
            khiBaoBut?(T("Trợ lý trang"))
            rungPhanHoi(tai: squeeze.hoverPose?.location
                        ?? CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY))
            return
        }

        switch UIPencilInteraction.preferredSqueezeAction {
        case .showColorPalette, .showInkAttributes, .showContextualPalette:
            NhatKy.vo.info("bút: → MỞ BẢNG CÔNG CỤ (việc hệ thống)")
            bangCongCu?.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
            khiBaoBut?(T("Bảng công cụ"))
        case .switchEraser, .switchPrevious:
            daoButTay()
            khiBaoBut?(canvas.tool is PKEraserTool ? T("Tẩy") : T("Bút"))
        case .ignore, .runSystemShortcut:
            // `.ignore` = người dùng tắt tương tác bút trong Cài đặt. Trước
            // đây tôi `return` im lặng, và người dùng bóp mãi không thấy gì
            // mà cũng không biết vì sao — phải NÓI RA.
            NhatKy.vo.info("bút: hệ thống đặt hành động bóp là 'không làm gì' — vào Cài đặt › Apple Pencil để đổi")
            khiBaoBut?(T("Bóp bút đang tắt trong Cài đặt › Apple Pencil"))
            return
        @unknown default:
            daoButTay()
            khiBaoBut?(canvas.tool is PKEraserTool ? T("Tẩy") : T("Bút"))
        }

        // Rung nhẹ để tay biết cú bóp đã ăn: Pencil Pro có mô-tơ rung riêng,
        // và không có phản hồi thì người dùng bóp lại lần nữa rồi tưởng hỏng.
        if let diem = squeeze.hoverPose?.location {
            rungPhanHoi(tai: diem)
        } else {
            rungPhanHoi(tai: CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY))
        }
    }
}
#endif
