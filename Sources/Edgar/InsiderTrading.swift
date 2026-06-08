import Foundation

// MARK: - Insider Trading Models

public struct InsiderReport: Sendable {
    public let issuerCik: Int
    public let issuerName: String
    public let issuerTicker: String?
    public let ownerCik: Int
    public let ownerName: String
    public let isDirector: Bool
    public let isOfficer: Bool
    public let isTenPercentOwner: Bool
    public let officerTitle: String?
    public var filingDate: String
    public let transactions: [InsiderTransaction]
    public let derivativeTransactions: [InsiderTransaction]
}

public struct InsiderTransaction: Sendable {
    public let securityTitle: String
    public let transactionDate: String
    public let code: TransactionCode
    public let shares: Double
    public let pricePerShare: Double?
    public let acquired: Bool // true = acquired (A), false = disposed (D)
    public let sharesAfterTransaction: Double?
    public let isDerivative: Bool
}

public enum TransactionCode: String, Codable, Sendable, CaseIterable {
    case purchase = "P"
    case sale = "S"
    case grantAward = "A"
    case exercise = "M"
    case conversion = "C"
    case expiration = "E"
    case gift = "G"
    case discretionary = "L"
    case inheritedSmall = "I"
    case fund = "F"
    case other = "X"
    case unknown = ""

    public var description: String {
        switch self {
        case .purchase: return "Open market purchase"
        case .sale: return "Open market sale"
        case .grantAward: return "Grant/award"
        case .exercise: return "Exercise of derivative"
        case .conversion: return "Conversion of derivative"
        case .expiration: return "Expiration"
        case .gift: return "Gift"
        case .discretionary: return "Discretionary transaction"
        case .inheritedSmall: return "Inherited (small acquisition)"
        case .fund: return "Payment to issuer for derivative"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Form 4 XML Parser

public enum Form4Parser {

    public static func parse(data: Data) throws -> InsiderReport {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true

        let delegate = Form4ParserDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "Unknown"
            throw EdgarError.xmlParsingError("Form 4 parse error: \(detail)")
        }

        return delegate.buildReport()
    }
}

// MARK: - Form 4 Parser Delegate

private final class Form4ParserDelegate: NSObject, XMLParserDelegate {
    // Issuer fields
    var issuerCik = 0
    var issuerName = ""
    var issuerTicker: String?

    // Owner fields
    var ownerCik = 0
    var ownerName = ""
    var isDirector = false
    var isOfficer = false
    var isTenPercentOwner = false
    var officerTitle: String?

    // Transactions
    var transactions: [InsiderTransaction] = []
    var derivativeTransactions: [InsiderTransaction] = []

    // Parser state
    private var currentPath: [String] = []
    private var characterBuffer = ""
    private var inNonDerivativeTransaction = false
    private var inDerivativeTransaction = false

    // Current transaction fields
    private var txSecurityTitle = ""
    private var txDate = ""
    private var txCode = ""
    private var txShares: Double = 0
    private var txPrice: Double?
    private var txAcquiredDisposed = ""
    private var txSharesAfter: Double?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        let name = elementName.lowercased()
        currentPath.append(name)
        characterBuffer = ""

        if name == "nonderivativetransaction" {
            inNonDerivativeTransaction = true
            resetTransactionFields()
        } else if name == "derivativetransaction" {
            inDerivativeTransaction = true
            resetTransactionFields()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let name = elementName.lowercased()
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = currentPath.count > 1 ? currentPath[currentPath.count - 2] : ""

        // Issuer fields
        if parent == "issuer" {
            switch name {
            case "issuercik": issuerCik = Int(text) ?? 0
            case "issuername": issuerName = text
            case "issuertradingsymbol": issuerTicker = text.isEmpty ? nil : text
            default: break
            }
        }

        // Owner fields
        if parent == "reportingownerid" {
            switch name {
            case "rptownercik": ownerCik = Int(text) ?? 0
            case "rptownername": ownerName = text
            default: break
            }
        }

        if parent == "reportingownerrelationship" {
            switch name {
            case "isdirector": isDirector = text == "1" || text.lowercased() == "true"
            case "isofficer": isOfficer = text == "1" || text.lowercased() == "true"
            case "istenpercentowner": isTenPercentOwner = text == "1" || text.lowercased() == "true"
            case "officertitle": officerTitle = text.isEmpty ? nil : text
            default: break
            }
        }

        // Transaction fields (both derivative and non-derivative)
        if inNonDerivativeTransaction || inDerivativeTransaction {
            switch name {
            case "value":
                if parent == "securitytitle" { txSecurityTitle = text }
                else if parent == "transactiondate" { txDate = text }
                else if parent == "transactionshares" { txShares = Double(text) ?? 0 }
                else if parent == "transactionpricepershare" { txPrice = Double(text) }
                else if parent == "transactionacquireddisposedcode" { txAcquiredDisposed = text }
                else if parent == "sharesownedfollowingtransaction" { txSharesAfter = Double(text) }
            case "transactioncode":
                if !text.isEmpty { txCode = text }
            case "nonderivativetransaction":
                let tx = buildTransaction(isDerivative: false)
                transactions.append(tx)
                inNonDerivativeTransaction = false
            case "derivativetransaction":
                let tx = buildTransaction(isDerivative: true)
                derivativeTransactions.append(tx)
                inDerivativeTransaction = false
            default: break
            }
        }

        currentPath.removeLast()
    }

    func buildReport() -> InsiderReport {
        InsiderReport(
            issuerCik: issuerCik,
            issuerName: issuerName,
            issuerTicker: issuerTicker,
            ownerCik: ownerCik,
            ownerName: ownerName,
            isDirector: isDirector,
            isOfficer: isOfficer,
            isTenPercentOwner: isTenPercentOwner,
            officerTitle: officerTitle,
            filingDate: "",
            transactions: transactions,
            derivativeTransactions: derivativeTransactions
        )
    }

    private func buildTransaction(isDerivative: Bool) -> InsiderTransaction {
        InsiderTransaction(
            securityTitle: txSecurityTitle,
            transactionDate: txDate,
            code: TransactionCode(rawValue: txCode) ?? .unknown,
            shares: txShares,
            pricePerShare: txPrice,
            acquired: txAcquiredDisposed.uppercased() == "A",
            sharesAfterTransaction: txSharesAfter,
            isDerivative: isDerivative
        )
    }

    private func resetTransactionFields() {
        txSecurityTitle = ""
        txDate = ""
        txCode = ""
        txShares = 0
        txPrice = nil
        txAcquiredDisposed = ""
        txSharesAfter = nil
    }
}

// MARK: - Insider Service

extension EdgarClient {

    /// Get recent Form 4 (insider trading) filings for a company.
    public func getInsiderFilings(cik: Int, limit: Int = 20) async throws -> [Filing] {
        let filings = try await getFilings(cik: cik, form: "4")
        return Array(filings.prefix(limit))
    }

    /// Parse a Form 4 filing into structured insider transaction data.
    public func parseInsiderFiling(cik: Int, filing: Filing) async throws -> InsiderReport {
        // Try primary document as XML first; fall back to filing directory
        let primaryURL = try filing.primaryDocumentURL(cik: cik)
        let primaryData = try await getRawData(from: primaryURL)

        var report: InsiderReport
        do {
            report = try Form4Parser.parse(data: primaryData)
        } catch {
            // Primary doc failed (likely HTML) — find XML in filing directory
            let dirURL = try filing.directoryURL(cik: cik)
            let indexURL = dirURL.appendingPathComponent("index.json")
            let indexData = try await getRawData(from: indexURL)
            let index = try JSONDecoder().decode(FilingIndex.self, from: indexData)

            let xmlFile = index.directory.item.first {
                $0.name.hasSuffix(".xml") && $0.name != "primary_doc.xml"
            } ?? index.directory.item.first {
                $0.name.hasSuffix(".xml")
            }

            guard let xmlFileName = xmlFile?.name else {
                throw EdgarError.xmlParsingError("No XML file found in Form 4 filing directory")
            }

            let xmlURL = dirURL.appendingPathComponent(xmlFileName)
            let xmlData = try await getRawData(from: xmlURL)
            report = try Form4Parser.parse(data: xmlData)
        }

        report.filingDate = filing.filingDate
        return report
    }

    /// Get recent insider trades for a company (convenience method).
    public func getRecentInsiderTrades(cik: Int, limit: Int = 10) async throws -> [InsiderReport] {
        let filings = try await getInsiderFilings(cik: cik, limit: limit)
        var reports: [InsiderReport] = []
        for filing in filings {
            do {
                let report = try await parseInsiderFiling(cik: cik, filing: filing)
                reports.append(report)
            } catch {
                continue // Skip filings that fail to parse
            }
        }
        return reports
    }
}
