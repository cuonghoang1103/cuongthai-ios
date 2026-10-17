import SwiftUI

// MARK: - Đăng ký mô-đun Board (bảng kéo thả — `Shared/CTWork/CTWorkBoardView.swift`)

extension CTWModule {
    static let board = CTWModule(
        id: "board", ten: "Board", bieuTuong: "rectangle.split.3x1", nhom: .duAn,
        moTa: "Drag issues between columns", thuTu: 10, doanWeb: "board",
        man: { c in AnyView(CTWBoardView(pid: c.pid, ten: c.tenDuAn)) })
}
