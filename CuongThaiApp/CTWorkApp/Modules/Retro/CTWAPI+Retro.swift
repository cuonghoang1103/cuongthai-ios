import Foundation

// MARK: - CTWAPI — Retrospectives (`work.ctw7a.routes.ts:102-121`). AI summary KHÔNG gọi từ app (5.1.2).

extension CTWAPI {
    static func dsRetro(pid: Int) -> APIEndpoint { get("/projects/\(pid)/retros") }
    static func taoRetro(pid: Int, ten: String, template: String, sprintId: Int?, anDanh: Bool, phieuMoiNguoi: Int) -> APIEndpoint {
        var t: [String: Any] = ["title": String(ten.prefix(120)), "template": template, "anonymous": anDanh,
                                "votesPerPerson": min(max(phieuMoiNguoi, 1), 20)]
        if let sprintId { t["sprintId"] = sprintId }
        return goi("/projects/\(pid)/retros", "POST", t)
    }
    static func retro(pid: Int, rid: Int) -> APIEndpoint { get("/projects/\(pid)/retros/\(rid)") }
    static func khoaRetro(pid: Int, rid: Int, khoa: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/retros/\(rid)", "PATCH", ["locked": khoa])
    }
    static func themTheRetro(pid: Int, rid: Int, cot: String, noiDung: String) -> APIEndpoint {
        goi("/projects/\(pid)/retros/\(rid)/cards", "POST", ["column": cot, "body": String(noiDung.prefix(1000))])
    }
    static func suaTheRetro(pid: Int, rid: Int, cid: Int, noiDung: String) -> APIEndpoint {
        goi("/projects/\(pid)/retros/\(rid)/cards/\(cid)", "PATCH", ["body": String(noiDung.prefix(1000))])
    }
    static func xoaTheRetro(pid: Int, rid: Int, cid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/retros/\(rid)/cards/\(cid)", "DELETE")
    }
    static func phieuRetro(pid: Int, rid: Int, cid: Int, them: Bool) -> APIEndpoint {
        goi("/projects/\(pid)/retros/\(rid)/cards/\(cid)/vote", "POST", ["delta": them ? 1 : -1])
    }
    static func themViecRetro(pid: Int, rid: Int, ten: String, cardId: Int?, taoThe: Bool) -> APIEndpoint {
        var t: [String: Any] = ["title": String(ten.prefix(255)), "createIssue": taoThe]
        if let cardId { t["cardId"] = cardId }
        return goi("/projects/\(pid)/retros/\(rid)/actions", "POST", t)
    }
    static func xoaViecRetro(pid: Int, rid: Int, aid: Int) -> APIEndpoint {
        goi("/projects/\(pid)/retros/\(rid)/actions/\(aid)", "DELETE")
    }
}
