import Foundation

// MARK: - Ответ dev.omg56.ru/omgserver

struct ServerResponse: Decodable {
    let regions: [ServerRegionInfo]
    let radios: [ServerRadio]
}

struct ServerRegionInfo: Decodable {
    let region_id: String
    let region_name: String
}

struct ServerRadio: Decodable {
    let nid: String
    let name: String
    let field_logo: String?
    let field_player_logo: String?
    let field_payer_image: String?
    let field_radio_cover: String?
    let body: String?
    let region: [ServerRadioRegion]?
}

struct ServerRadioRegion: Decodable {
    let field_radioset_rigion_id: String?
    let field_radioset_radio_wave: String?
    let field_radioset_stream_64: String?
    let field_radioset_stream_128: String?
    let field_radioset_phone: String?
    let field_radioset_site_link: String?
}

// MARK: - Модели приложения

struct StationRegion: Identifiable {
    var id: String { regionId }
    let regionId: String
    let name: String
    let wave: String
    let stream128: String
    let stream64: String
    let phone: String
    let siteLink: String
}

struct Station: Identifiable {
    var id: String { nid }
    let nid: String          // стабильный slug потока (как в Android-версии)
    let title: String
    let logo: String         // field_logo
    let playerLogo: String   // field_player_logo
    let cover: String
    let body: String
    let regions: [StationRegion]
    let localLogo: String?   // имя локального ресурса-логотипа

    var hasStream: Bool { regions.contains { !$0.stream128.isEmpty || !$0.stream64.isEmpty } }

    func streamUrl(hq: Bool, regionIndex: Int) -> String {
        guard let r = regions[safe: regionIndex] else { return "" }
        let primary = hq ? r.stream128 : r.stream64
        let fallback = hq ? r.stream64 : r.stream128
        return (primary.isEmpty ? fallback : primary).trimmingCharacters(in: .whitespaces)
    }

    func freqLabel(regionIndex: Int) -> String {
        guard let w = regions[safe: regionIndex]?.wave, !w.isEmpty else { return "" }
        return "\(w) FM"
    }

    func regionName(regionIndex: Int) -> String {
        regions[safe: regionIndex]?.name ?? regions.first?.name ?? ""
    }
}

extension ServerRadio {
    func toStation(regionNames: [String: String]) -> Station {
        let regs = (region ?? []).map { sr in
            StationRegion(
                regionId: (sr.field_radioset_rigion_id ?? "").trimmingCharacters(in: .whitespaces),
                name: regionNames[(sr.field_radioset_rigion_id ?? "").trimmingCharacters(in: .whitespaces)]
                    ?? (sr.field_radioset_rigion_id ?? "").trimmingCharacters(in: .whitespaces),
                wave: (sr.field_radioset_radio_wave ?? "").trimmingCharacters(in: .whitespaces),
                stream128: (sr.field_radioset_stream_128 ?? "").trimmingCharacters(in: .whitespaces),
                stream64: (sr.field_radioset_stream_64 ?? "").trimmingCharacters(in: .whitespaces),
                phone: (sr.field_radioset_phone ?? "").trimmingCharacters(in: .whitespaces),
                siteLink: (sr.field_radioset_site_link ?? "").trimmingCharacters(in: .whitespaces)
            )
        }
        let firstStream = (regs.first?.stream128 ?? regs.first?.stream64) ?? ""
        let slug = firstStream.components(separatedBy: "/").last.flatMap { $0.isEmpty ? nil : $0 } ?? nid
        return Station(
            nid: slug,
            title: name.trimmingCharacters(in: .whitespaces),
            logo: (field_logo ?? "").trimmingCharacters(in: .whitespaces),
            playerLogo: (field_player_logo ?? "").trimmingCharacters(in: .whitespaces),
            cover: (field_radio_cover ?? "").trimmingCharacters(in: .whitespaces),
            body: body ?? "",
            regions: regs,
            localLogo: Self.localLogoNames[slug]
        )
    }

    // Локальные логотипы высокого качества по слагу (как в Android-версии)
    private static let localLogoNames: [String: String] = [
        "Sibir_Oren": "logo_sibir_oren",
        "Europa_plus_Oren": "logo_europa_plus_oren",
        "Dacha_Oren64": "logo_dacha_oren64",
        "Monte_Carlo_Oren": "logo_monte_carlo_oren",
        "Hit_fm_Oren": "logo_hit_fm_oren",
        "Dorognoe_Oren": "logo_dorognoe_oren",
        "Russkoe_Oren": "logo_russkoe_oren",
        "Novoe_Oren": "logo_novoe_oren",
        "Chocolate_Oren": "logo_chocolate_oren",
        "Avto_Oren": "logo_avto_oren",
        "Mir_Oren": "logo_mir_oren",
        "NRJ_Oren": "logo_nrj_oren",
        "Comedy_Oren": "logo_comedy_oren",
        "Relax_FM_Oren": "logo_relax_fm_oren",
    ]
}

// MARK: - Новости (dev.omg56.ru/omgprooren)

struct NewsResponse: Decodable {
    let news: [NewsItem]
}

struct NewsItem: Decodable, Identifiable {
    let id: String
    let title: String
    let date: String
    let image: String
    let link: String
    let body: String

    private enum CodingKeys: String, CodingKey { case id, title, date, image, link, body }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        image = try c.decodeIfPresent(String.self, forKey: .image) ?? ""
        link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
    }
}

// MARK: - Токен для формы сообщения

struct TokenResponse: Decodable {
    let data: String
}

// MARK: - Утилиты

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension String {
    /// Очистка HTML-разметки из полей body
    func strippingHtml() -> String {
        var s = self.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&[a-z]+;", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
