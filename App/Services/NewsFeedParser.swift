import Foundation
#if canImport(FoundationXML)
import FoundationXML // Linux only; on Apple platforms XMLParser lives in Foundation.
#endif

/// RSS and Atom metadata extraction only. Does not scrape article pages or load remote media.
final class NewsFeedParser: NSObject, XMLParserDelegate {
    private let source: FeedSource
    private var inEntry = false
    private var field = ""
    private var buffer = ""
    private var title = ""
    private var link = ""
    private var summary = ""
    private var identifier = ""
    private var published = ""
    private(set) var items: [NewsItem] = []

    init(source: FeedSource) { self.source = source }

    static func parse(_ data: Data, source: FeedSource) -> [NewsItem] {
        let delegate = NewsFeedParser(source: source)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { return [] }
        return Array(delegate.items.prefix(50))
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased().components(separatedBy: ":").last ?? ""
        if name == "item" || name == "entry" {
            inEntry = true
            title = ""; link = ""; summary = ""; identifier = ""; published = ""
        }
        guard inEntry else { return }
        field = name
        buffer = ""
        if name == "link", let href = attributeDict["href"],
           attributeDict["rel"] == nil || attributeDict["rel"] == "alternate" {
            link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inEntry { buffer += string }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if inEntry, let contents = String(data: CDATABlock, encoding: .utf8) { buffer += contents }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.lowercased().components(separatedBy: ":").last ?? ""
        guard inEntry else { return }
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == field {
            switch name {
            case "title": if !value.isEmpty { title = value }
            case "link": if !value.isEmpty { link = value }
            case "description", "summary": if !value.isEmpty { summary = value }
            case "guid", "id": if !value.isEmpty { identifier = value }
            case "pubdate", "published", "updated": if !value.isEmpty { published = value }
            default: break
            }
        }
        if name == "item" || name == "entry" {
            defer { inEntry = false }
            let plainTitle = Self.plainText(title)
            guard !plainTitle.isEmpty,
                  let url = URL(string: link), url.scheme?.lowercased() == "https",
                  let host = url.host, !host.isEmpty else { return }
            let short = String(Self.plainText(summary).prefix(200))
            let key = identifier.isEmpty ? url.absoluteString : identifier
            items.append(NewsItem(id: "\(source.id):\(key)", sourceID: source.id,
                                  publisher: source.publisher, title: plainTitle,
                                  url: url, summary: short, date: Self.date(published),
                                  topics: source.topics))
        }
        field = ""
        buffer = ""
    }

    private static func plainText(_ input: String) -> String {
        let stripped = input.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
        let decoded = stripped.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return decoded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func date(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        // RFC 822 allows numeric offsets ("+0000") or zone abbreviations ("PDT", used by Apple Developer News).
        for pattern in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss Z",
                        "EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, d MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }
}
