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
                body: extractBody(from: descriptionHtml)
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

    /// Текст новости из RSS-description: только содержимое абзацев <p> —
    /// авторство, дата, теги, категория и <img> отбрасываются,
    /// строки без лишних пробелов и отступов.
    private func extractBody(from html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<p[^>]*>(.*?)</p>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else { return html }
        let stripTags = try? NSRegularExpression(pattern: "<[^>]+>")
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            .compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: html) else { return nil }
                var text = String(html[range])
                if let stripTags {
                    text = stripTags.stringByReplacingMatches(
                        in: text,
                        range: NSRange(text.startIndex..., in: text),
                        withTemplate: ""
                    )
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: "\n\n")
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
