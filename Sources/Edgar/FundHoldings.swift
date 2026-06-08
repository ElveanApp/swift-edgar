import Foundation

// MARK: - N-PORT Fund Holdings Models

public struct FundPortfolio: Sendable {
    public let fundName: String
    public let cik: Int
    public let filing: Filing
    public let reportDate: String
    public let totalAssets: Double?
    public let netAssets: Double?
    public let holdings: [FundHolding]

    public var holdingCount: Int { holdings.count }

    public func topHoldings(_ count: Int = 10) -> [FundHolding] {
        Array(holdings.sorted { $0.value > $1.value }.prefix(count))
    }
}

public struct FundHolding: Sendable {
    public let name: String
    public let title: String?
    public let cusip: String?
    public let lei: String?
    public let isin: String?
    public let balance: Double
    public let units: String       // NS (number of shares), PA (principal amount)
    public let value: Double       // in USD
    public let percentage: Double? // % of net assets
    public let assetCategory: String?
    public let issuerCategory: String?
    public let country: String?
    public let currency: String
    public let payoffProfile: String? // Long, Short, N/A
    public var ticker: String?
}

// MARK: - N-PORT XML Parser

public enum NPortParser {

    public static func parse(data: Data, filing: Filing, cik: Int) throws -> FundPortfolio {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true

        let delegate = NPortParserDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "Unknown"
            throw EdgarError.xmlParsingError("N-PORT parse error: \(detail)")
        }

        return FundPortfolio(
            fundName: delegate.fundName,
            cik: cik,
            filing: filing,
            reportDate: delegate.reportDate,
            totalAssets: delegate.totalAssets,
            netAssets: delegate.netAssets,
            holdings: delegate.holdings
        )
    }
}

// MARK: - N-PORT Parser Delegate

private final class NPortParserDelegate: NSObject, XMLParserDelegate {
    var fundName = ""
    var reportDate = ""
    var totalAssets: Double?
    var netAssets: Double?
    var holdings: [FundHolding] = []

    private var inHolding = false
    private var characterBuffer = ""
    private var currentPath: [String] = []

    // Current holding fields
    private var hName = ""
    private var hTitle: String?
    private var hCusip: String?
    private var hLei: String?
    private var hIsin: String?
    private var hBalance: Double = 0
    private var hUnits = "NS"
    private var hValue: Double = 0
    private var hPercentage: Double?
    private var hAssetCat: String?
    private var hIssuerCat: String?
    private var hCountry: String?
    private var hCurrency = "USD"
    private var hPayoff: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        let name = elementName.lowercased()
        currentPath.append(name)
        characterBuffer = ""

        if name == "invstorsec" {
            inHolding = true
            resetHoldingFields()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let name = elementName.lowercased()
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fund-level fields
        if !inHolding {
            switch name {
            case "seriesnm", "seriesname": fundName = text
            case "reppddate", "reportdate": reportDate = text
            case "totassets", "totalassets": totalAssets = Double(text)
            case "netassets": netAssets = Double(text)
            default: break
            }
        }

        // Holding-level fields
        if inHolding {
            switch name {
            case "name": hName = text
            case "title": hTitle = text.isEmpty ? nil : text
            case "cusip": hCusip = text.isEmpty ? nil : text
            case "lei": hLei = text.isEmpty ? nil : text
            case "isin": hIsin = text.isEmpty ? nil : text
            case "balance": hBalance = Double(text) ?? 0
            case "units": hUnits = text
            case "valusd", "valueusd": hValue = Double(text) ?? 0
            case "pctval": hPercentage = Double(text)
            case "assetcat": hAssetCat = text.isEmpty ? nil : text
            case "issuercat": hIssuerCat = text.isEmpty ? nil : text
            case "invcountry": hCountry = text.isEmpty ? nil : text
            case "curcd": hCurrency = text.isEmpty ? "USD" : text
            case "payoffprofile": hPayoff = text.isEmpty ? nil : text
            case "invstorsec":
                let holding = FundHolding(
                    name: hName,
                    title: hTitle,
                    cusip: hCusip,
                    lei: hLei,
                    isin: hIsin,
                    balance: hBalance,
                    units: hUnits,
                    value: hValue,
                    percentage: hPercentage,
                    assetCategory: hAssetCat,
                    issuerCategory: hIssuerCat,
                    country: hCountry,
                    currency: hCurrency,
                    payoffProfile: hPayoff
                )
                holdings.append(holding)
                inHolding = false
            default: break
            }
        }

        currentPath.removeLast()
    }

    private func resetHoldingFields() {
        hName = ""
        hTitle = nil
        hCusip = nil
        hLei = nil
        hIsin = nil
        hBalance = 0
        hUnits = "NS"
        hValue = 0
        hPercentage = nil
        hAssetCat = nil
        hIssuerCat = nil
        hCountry = nil
        hCurrency = "USD"
        hPayoff = nil
    }
}

// MARK: - Fund Holdings Service

extension EdgarClient {

    /// Get recent N-PORT filings for a fund.
    public func getFundFilings(cik: Int, limit: Int = 10) async throws -> [Filing] {
        let filings = try await getFilings(cik: cik, form: "NPORT-P")
        return Array(filings.prefix(limit))
    }

    /// Parse an N-PORT filing into structured fund portfolio data.
    public func parseFundFiling(cik: Int, filing: Filing) async throws -> FundPortfolio {
        // N-PORT primary document is the XML
        let url = try filing.primaryDocumentURL(cik: cik)
        let data = try await getRawData(from: url)
        return try NPortParser.parse(data: data, filing: filing, cik: cik)
    }

    /// Get the latest fund portfolio from N-PORT filings.
    public func getLatestFundPortfolio(cik: Int) async throws -> FundPortfolio {
        let filings = try await getFundFilings(cik: cik, limit: 1)
        guard let filing = filings.first else {
            throw EdgarError.noFilingsFound(cik: cik, form: "NPORT-P")
        }
        return try await parseFundFiling(cik: cik, filing: filing)
    }
}
