import Foundation

/// Парсер RSS prooren.ru/rss.xml: item → NewsItem
/// (картинка извлекается из description, дата — из pubDate).
final class RssNewsParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var inItem = false
    private var field: String?
    private var title = ""
    private var link = ""
    private var descriptionHtml = ""
    private var pubDate = ""
    private var guid = ""

    static func parse(_ data: Data) -> [NewsItem] {
        let delegate = RssNewsParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "item" {
            inItem = true
            title = ""
            link = ""
            descriptionHtml = ""
            pubDate = ""
            guid = ""
        } else if inItem {
            field = elementName
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem, let field else { return }
        switch field {
        case "title": title += string
        case "link": link += string
        case "description": descriptionHtml += string
        case "pubDate": pubDate += string
        case "guid": guid += string
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            items.append(NewsItem(
                id: guid.trimmingCharacters(in: .whitespacesAndNewlines),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                date: Self.formatDate(pubDate),
                image: firstImageUrl(in: descriptionHtml) ?? "",
                link: link.trimmingCharacters(in: .whitespacesAndNewlines),
                body: descriptionHtml
            ))
            inItem = false
            field = nil
        } else if inItem && elementName == field {
            field = nil
        }
    }

    private func firstImageUrl(in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<img[^>]+src=\"([^\"]+)\""),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }

    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    private static let outputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static func formatDate(_ pubDate: String) -> String {
        guard let date = inputFormatter.date(from: pubDate.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return ""
        }
        return outputFormatter.string(from: date)
    }
}
