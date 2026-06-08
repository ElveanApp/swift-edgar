import Foundation

/// Parses SEC 13F-HR information table XML into structured holdings.
public enum ThirteenFParser {

    /// Parse 13F information table XML data into an array of holdings.
    public static func parse(data: Data) throws -> [Holding] {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true

        let delegate = ParserDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "Unknown XML error"
            throw EdgarError.xmlParsingError(detail)
        }

        guard !delegate.holdings.isEmpty else {
            throw EdgarError.xmlParsingError("No holdings found in XML data")
        }

        return delegate.holdings
    }
}

// MARK: - XML Parser Delegate

private final class ParserDelegate: NSObject, XMLParserDelegate {
    var holdings: [Holding] = []

    private var inInfoTable = false
    private var characterBuffer = ""

    // Fields for the current holding being built
    private var issuer = ""
    private var titleOfClass = ""
    private var cusip = ""
    private var value = 0
    private var shares = 0
    private var shareType = ""
    private var putCall: String?
    private var investmentDiscretion = ""
    private var votingSole = 0
    private var votingShared = 0
    private var votingNone = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        characterBuffer = ""

        if elementName.lowercased() == "infotable" {
            inInfoTable = true
            resetFields()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard inInfoTable else { return }

        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName.lowercased() {
        case "nameofissuer":
            issuer = text
        case "titleofclass":
            titleOfClass = text
        case "cusip":
            cusip = text
        case "value":
            value = Int(text) ?? 0
        case "sshprnamt":
            shares = Int(text) ?? 0
        case "sshprnamttype":
            shareType = text.uppercased()
        case "putcall":
            putCall = text.isEmpty ? nil : text.uppercased()
        case "investmentdiscretion":
            investmentDiscretion = text.uppercased()
        case "sole":
            votingSole = Int(text) ?? 0
        case "shared":
            votingShared = Int(text) ?? 0
        case "none":
            votingNone = Int(text) ?? 0
        case "infotable":
            let holding = Holding(
                nameOfIssuer: issuer,
                titleOfClass: titleOfClass,
                cusip: cusip,
                value: value,
                shares: shares,
                shareType: Holding.ShareType(rawValue: shareType) ?? .shares,
                putCall: putCall.flatMap { Holding.PutCall(rawValue: $0) },
                investmentDiscretion: Holding.InvestmentDiscretion(rawValue: investmentDiscretion) ?? .sole,
                votingSole: votingSole,
                votingShared: votingShared,
                votingNone: votingNone
            )
            holdings.append(holding)
            inInfoTable = false
        default:
            break
        }
    }

    private func resetFields() {
        issuer = ""
        titleOfClass = ""
        cusip = ""
        value = 0
        shares = 0
        shareType = ""
        putCall = nil
        investmentDiscretion = ""
        votingSole = 0
        votingShared = 0
        votingNone = 0
    }
}
