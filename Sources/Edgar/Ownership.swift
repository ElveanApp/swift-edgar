import Foundation

// MARK: - Beneficial Ownership (13D/G), Proxy (DEF 14A), S-1, Form D

/// These filing types are primarily unstructured HTML/text.
/// We provide filing discovery + text extraction. The LLM in Elvean
/// handles interpretation of the content.

extension EdgarClient {

    /// Get beneficial ownership filings (Schedule 13D and 13G).
    public func getOwnershipFilings(cik: Int, limit: Int = 10) async throws -> [Filing] {
        let all = try await getFilings(cik: cik)
        let filtered = all.filter {
            $0.form.hasPrefix("SC 13D") || $0.form.hasPrefix("SC 13G")
        }
        return Array(filtered.prefix(limit))
    }

    /// Get proxy statement filings (DEF 14A).
    public func getProxyFilings(cik: Int, limit: Int = 5) async throws -> [Filing] {
        let all = try await getFilings(cik: cik)
        let filtered = all.filter {
            $0.form == "DEF 14A" || $0.form == "DEFA14A"
        }
        return Array(filtered.prefix(limit))
    }

    /// Get registration statement filings (S-1, S-3, etc.).
    public func getRegistrationFilings(cik: Int, limit: Int = 5) async throws -> [Filing] {
        let all = try await getFilings(cik: cik)
        let filtered = all.filter {
            $0.form.hasPrefix("S-1") || $0.form.hasPrefix("S-3") || $0.form.hasPrefix("S-4")
        }
        return Array(filtered.prefix(limit))
    }

    /// Get Form D (private offering) filings.
    public func getFormDFilings(cik: Int, limit: Int = 10) async throws -> [Filing] {
        let filings = try await getFilings(cik: cik, form: "D")
        return Array(filings.prefix(limit))
    }
}

// MARK: - Form D Structured Data

/// Form D filings have structured XML. This parser extracts key offering details.
public struct FormDOffering: Sendable {
    public let entityName: String
    public let entityCik: Int
    public let entityType: String?
    public let industryGroup: String?
    public let revenueRange: String?
    public let federalExemptions: [String]
    public let dateOfFirstSale: String?
    public let totalOfferingAmount: Double?
    public let totalAmountSold: Double?
    public let totalRemaining: Double?
    public let numberOfInvestorsAccredited: Int?
    public let numberOfInvestorsNonAccredited: Int?
}

public enum FormDParser {

    public static func parse(data: Data) throws -> FormDOffering {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true

        let delegate = FormDDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "Unknown"
            throw EdgarError.xmlParsingError("Form D parse error: \(detail)")
        }

        return delegate.build()
    }
}

private final class FormDDelegate: NSObject, XMLParserDelegate {
    var entityName = ""
    var entityCik = 0
    var entityType: String?
    var industryGroup: String?
    var revenueRange: String?
    var exemptions: [String] = []
    var dateOfFirstSale: String?
    var totalOffering: Double?
    var totalSold: Double?
    var totalRemaining: Double?
    var accreditedInvestors: Int?
    var nonAccreditedInvestors: Int?

    private var characterBuffer = ""
    private var currentPath: [String] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentPath.append(elementName.lowercased())
        characterBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let name = elementName.lowercased()
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "entityname": entityName = text
        case "cik": entityCik = Int(text) ?? 0
        case "entitytype": entityType = text.isEmpty ? nil : text
        case "industrygrouptype": industryGroup = text.isEmpty ? nil : text
        case "revenuerange": revenueRange = text.isEmpty ? nil : text
        case "item": if !text.isEmpty { exemptions.append(text) }
        case "dateoffirstsale": dateOfFirstSale = text.isEmpty ? nil : text
        case "totalofferingamount": totalOffering = Double(text)
        case "totalamountsold": totalSold = Double(text)
        case "totalremaining": totalRemaining = Double(text)
        case "numberalreadyinvested":
            accreditedInvestors = Int(text)
        case "numbernon-accreditedinvestors", "numbernonaccreditedinvestors":
            nonAccreditedInvestors = Int(text)
        default: break
        }

        currentPath.removeLast()
    }

    func build() -> FormDOffering {
        FormDOffering(
            entityName: entityName,
            entityCik: entityCik,
            entityType: entityType,
            industryGroup: industryGroup,
            revenueRange: revenueRange,
            federalExemptions: exemptions,
            dateOfFirstSale: dateOfFirstSale,
            totalOfferingAmount: totalOffering,
            totalAmountSold: totalSold,
            totalRemaining: totalRemaining,
            numberOfInvestorsAccredited: accreditedInvestors,
            numberOfInvestorsNonAccredited: nonAccreditedInvestors
        )
    }
}
