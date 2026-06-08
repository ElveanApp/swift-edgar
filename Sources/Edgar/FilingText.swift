import Foundation

// MARK: - Filing Text Extraction

extension EdgarClient {

    /// Download the raw HTML of a filing's primary document.
    public func getFilingHTML(cik: Int, filing: Filing) async throws -> String {
        let url = try filing.primaryDocumentURL(cik: cik)
        let data = try await getRawData(from: url)
        if let html = String(data: data, encoding: .utf8) {
            return html
        }
        if let html = String(data: data, encoding: .ascii) {
            return html
        }
        if let html = String(data: data, encoding: .isoLatin1) {
            return html
        }
        throw EdgarError.decodingError("Could not decode filing HTML as text")
    }

    /// Download a filing and strip HTML tags to get plain text.
    public func getFilingText(cik: Int, filing: Filing) async throws -> String {
        let html = try await getFilingHTML(cik: cik, filing: filing)
        return HTMLStripper.stripTags(html)
    }

    /// Get all filings across the full history (paginated).
    /// The submissions API only returns ~40 recent filings; this fetches all pages.
    public func getAllFilings(cik: Int, form: String? = nil, limit: Int? = nil) async throws -> [Filing] {
        let url = try Self.submissionsURL(cik: cik)

        let data = try await getData(from: url)
        let response = try JSONDecoder().decode(SubmissionsResponse.self, from: data)

        // Parse recent filings using the shared helper
        var allFilings = Self.parseRecentFilings(response.filings.recent, form: form)

        if let limit, allFilings.count >= limit {
            return Array(allFilings.prefix(limit))
        }

        // Fetch additional pages
        if let files = response.filings.files {
            for file in files {
                guard let pageURL = URL(string: "\(Self.baseURL)/submissions/\(file.name)") else { continue }
                do {
                    let pageData = try await getData(from: pageURL)
                    let page = try JSONDecoder().decode(SubmissionsResponse.RecentFilings.self, from: pageData)
                    allFilings.append(contentsOf: Self.parseRecentFilings(page, form: form))
                    if let limit, allFilings.count >= limit {
                        return Array(allFilings.prefix(limit))
                    }
                } catch {
                    continue
                }
            }
        }

        return allFilings
    }
}

// MARK: - HTML Tag Stripper

enum HTMLStripper {

    // Pre-compiled regexes (compiled once, reused on every call)
    private static let styleRegex = try! NSRegularExpression(pattern: "<style[^>]*>[\\s\\S]*?</style>", options: .caseInsensitive)
    private static let scriptRegex = try! NSRegularExpression(pattern: "<script[^>]*>[\\s\\S]*?</script>", options: .caseInsensitive)
    private static let blockTagRegex = try! NSRegularExpression(pattern: "<(br|p|div|tr|li|h[1-6]|td|th)[^>]*>", options: .caseInsensitive)
    private static let allTagRegex = try! NSRegularExpression(pattern: "<[^>]+>")
    private static let blankLinesRegex = try! NSRegularExpression(pattern: "\\n\\s*\\n\\s*\\n+")
    private static let numericEntityRegex = try! NSRegularExpression(pattern: "&#x?([0-9a-fA-F]+);")

    /// Remove HTML tags and decode common entities, returning plain text.
    static func stripTags(_ html: String) -> String {
        let mutable = NSMutableString(string: html)

        // Remove style and script blocks
        styleRegex.replaceMatches(in: mutable, range: NSRange(location: 0, length: mutable.length), withTemplate: "")
        scriptRegex.replaceMatches(in: mutable, range: NSRange(location: 0, length: mutable.length), withTemplate: "")

        // Replace block-level elements with newlines
        blockTagRegex.replaceMatches(in: mutable, range: NSRange(location: 0, length: mutable.length), withTemplate: "\n")

        // Strip remaining tags
        allTagRegex.replaceMatches(in: mutable, range: NSRange(location: 0, length: mutable.length), withTemplate: "")

        var text = mutable as String

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
            ("&nbsp;", " "), ("&#160;", " "),
            ("&mdash;", "\u{2014}"), ("&ndash;", "\u{2013}"),
            ("&bull;", "\u{2022}"), ("&middot;", "\u{00B7}"),
        ]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }

        // Decode numeric entities (&#NNN; / &#xHHH; → Unicode character)
        text = decodeNumericEntities(text)

        // Collapse multiple blank lines
        let collapsed = NSMutableString(string: text)
        blankLinesRegex.replaceMatches(in: collapsed, range: NSRange(location: 0, length: collapsed.length), withTemplate: "\n\n")
        text = collapsed as String

        // Trim whitespace per line
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        text = lines.joined(separator: "\n")

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeNumericEntities(_ text: String) -> String {
        let nsText = text as NSString
        let matches = numericEntityRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var lastEnd = text.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: text),
                  let codeRange = Range(match.range(at: 1), in: text) else { continue }

            result += text[lastEnd..<fullRange.lowerBound]

            let entityText = String(text[fullRange])
            let codeText = String(text[codeRange])
            let isHex = entityText.hasPrefix("&#x") || entityText.hasPrefix("&#X")

            if let codePoint = UInt32(codeText, radix: isHex ? 16 : 10),
               let scalar = Unicode.Scalar(codePoint) {
                result += String(Character(scalar))
            } else {
                result += entityText
            }

            lastEnd = fullRange.upperBound
        }

        result += text[lastEnd...]
        return result
    }
}
