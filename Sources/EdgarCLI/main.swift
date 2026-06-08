import Foundation
import Edgar

@main
struct EdgarCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard let command = args.first else {
            printUsage()
            exit(0)
        }

        let edgar = Edgar(userAgent: "edgar-cli/1.0")

        do {
            switch command {
            case "company":
                guard let query = args.element(at: 1) else { fail("Usage: edgar company <ticker|CIK>") }
                if let cik = Int(query) {
                    let company = try await edgar.company(cik: cik)
                    printCompany(company)
                } else {
                    guard let result = try await edgar.company(ticker: query.uppercased()) else {
                        fail("No company found for ticker '\(query)'")
                    }
                    let company = try await edgar.company(cik: result.cik)
                    printCompany(company)
                }

            case "search":
                guard let query = args.element(at: 1) else { fail("Usage: edgar search <name>") }
                let results = try await edgar.searchCompanies(query)
                guard !results.isEmpty else { fail("No companies found for '\(query)'") }
                for r in results.prefix(20) {
                    print("CIK \(String(format: "%010d", r.cik))  \(r.ticker.map { String(format: "%-6s", $0) } ?? "      ")  \(r.name)")
                }

            case "portfolio":
                guard let query = args.element(at: 1) else { fail("Usage: edgar portfolio <ticker|CIK>") }
                let resolveTickers = !args.contains("--no-tickers")
                let cik = try await resolveCIK(edgar, query)
                let portfolio = try await edgar.latestPortfolio(cik: cik, resolveTickers: resolveTickers)
                printPortfolio(portfolio)

            case "financial":
                guard let query = args.element(at: 1) else { fail("Usage: edgar financial <ticker|CIK> [concept]") }
                let cik = try await resolveCIK(edgar, query)
                if let concept = args.element(at: 2) {
                    let conceptData = try await edgar.companyConcept(cik: cik, concept: concept)
                    print("\(conceptData.entityName) — \(conceptData.label)")
                    print(String(repeating: "-", count: 80))
                    for point in conceptData.usdValues.prefix(8) {
                        print("\(point.end)  \(point.form.padding(toLength: 5, withPad: " ", startingAt: 0))  $\(formatNumber(point.val))")
                    }
                } else {
                    let facts = try await edgar.companyFacts(cik: cik)
                    print(facts.entityName)
                    print(String(repeating: "-", count: 80))
                    let names = facts.conceptNames()
                    print("\(names.count) financial concepts available. Top-level values:\n")
                    for name in names.sorted().prefix(30) {
                        guard let concept = facts.concept(name) else { continue }
                        if let value = facts.latestValue(name) {
                            let label = concept.label.map { String($0.prefix(60)) } ?? name
                            print("  \(String(format: "%-40s", String(String(label).prefix(40))))  $\(formatNumber(value))")
                        }
                    }
                }

            case "insider":
                guard let query = args.element(at: 1) else { fail("Usage: edgar insider <ticker|CIK>") }
                let cik = try await resolveCIK(edgar, query)
                let trades = try await edgar.recentInsiderTrades(cik: cik)
                guard !trades.isEmpty else { fail("No recent insider trades found") }
                for report in trades {
                    print("\n\(report.ownerName) (\(report.issuerTicker ?? String(report.issuerCik)))")
                    if let title = report.officerTitle { print("  Title: \(title)") }
                    for tx in report.transactions {
                        let sign = tx.acquired ? "+" : "-"
                        let price = tx.pricePerShare.map { " @ $\(formatNumber($0))" } ?? ""
                        print("  \(tx.transactionDate)  \(sign)\(formatNumber(tx.shares)) \(tx.securityTitle)\(price)  [\(tx.code.description)]")
                    }
                }

            case "8k", "events":
                guard let query = args.element(at: 1) else { fail("Usage: edgar 8k <ticker|CIK>") }
                let cik = try await resolveCIK(edgar, query)
                let events = try await edgar.eightKFilings(cik: cik)
                guard !events.isEmpty else { fail("No recent 8-K filings found") }
                for event in events {
                    print("\n\(event.filing.filingDate) — 8-K")
                    for item in event.items {
                        print("  \(item.code)  \(item.description)")
                    }
                }

            case "fund":
                guard let query = args.element(at: 1) else { fail("Usage: edgar fund <ticker|CIK>") }
                let cik = try await resolveCIK(edgar, query)
                let fund = try await edgar.latestFundPortfolio(cik: cik)
                printFund(fund)

            case "help", "-h", "--help":
                printUsage()

            default:
                fail("Unknown command '\(command)'. Run 'edgar help' for usage.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }
}

// MARK: - Helpers

private func resolveCIK(_ edgar: Edgar, _ query: String) async throws -> Int {
    if let cik = Int(query) { return cik }
    guard let result = try await edgar.company(ticker: query.uppercased()) else {
        throw EdgarError.companyNotFound(query)
    }
    return result.cik
}

private func printCompany(_ company: Company) {
    print(company.name)
    print(String(repeating: "-", count: 60))
    print("CIK:        \(String(format: "%010d", company.cik))")
    if !company.tickers.isEmpty { print("Tickers:    \(company.tickers.joined(separator: ", "))") }
    if !company.exchanges.isEmpty { print("Exchanges:  \(company.exchanges.joined(separator: ", "))") }
    if let sic = company.sic { print("SIC:        \(sic) — \(company.sicDescription ?? "")") }
    if let category = company.category { print("Category:   \(category)") }
    if let fiscal = company.fiscalYearEnd { print("FY End:     \(fiscal)") }
}

private func printPortfolio(_ portfolio: Portfolio) {
    print("\(portfolio.company.name) — 13F Portfolio")
    print("Filing: \(portfolio.filing.filingDate)")
    print(String(repeating: "-", count: 80))
    let sorted = portfolio.holdings.sorted { $0.value > $1.value }
    print(String(format: "%-30s %8s %12s  %-8s %-8s",
                  "Name", "Shares", "Value (k$)", "Ticker", "Type"))
    print(String(repeating: "-", count: 80))
    for h in sorted {
        let ticker = h.ticker ?? h.cusip
        let type = h.putCall?.rawValue ?? h.titleOfClass
        print(String(format: "%-30.30s %8d $%11d  %-8s %-8s",
                      String(h.nameOfIssuer.prefix(30)),
                      h.shares,
                      h.value,
                      String(ticker.prefix(8)),
                      String(type.prefix(8))))
    }
    print("\n\(sorted.count) holdings  |  Total value: $\(sorted.reduce(0) { $0 + $1.value })k")
}

private func printFund(_ fund: FundPortfolio) {
    print("\(fund.fundName) — Fund Portfolio")
    print("Report Date: \(fund.reportDate)")
    print(String(repeating: "-", count: 80))
    let top = fund.topHoldings(20)
    for (i, h) in top.enumerated() {
        let name = h.title ?? h.name
        print(String(format: "%3d. %-40.40s $%12s",
                      i + 1, String(name.prefix(40)), formatNumber(h.value)))
    }
    print("\n\(fund.holdingCount) total holdings  |  Total assets: \(fund.totalAssets.map { "$\(formatNumber($0))" } ?? "N/A")")
}

private func formatNumber(_ value: Int) -> String { formatNumber(Double(value)) }
private func formatNumber(_ value: Double) -> String {
    let absValue = abs(value)
    switch absValue {
    case 1_000_000_000_000...:
        return String(format: "%.2fT", value / 1_000_000_000_000)
    case 1_000_000_000...:
        return String(format: "%.2fB", value / 1_000_000_000)
    case 1_000_000...:
        return String(format: "%.2fM", value / 1_000_000)
    case 1_000...:
        return String(format: "%.0f", value)
    default:
        return String(format: "%.2f", value)
    }
}

private func printUsage() {
    print("""
    Edgar — SEC EDGAR CLI  |  github.com/ElveanApp/swift-edgar

    USAGE:
      edgar <command> <args>

    COMMANDS:
      company     <ticker|CIK>            Company info
      search      <name>                  Search companies by name
      portfolio   <ticker|CIK>            Latest 13F portfolio
      financial   <ticker|CIK> [concept]  XBRL financial data
      insider     <ticker|CIK>            Recent insider trades (Form 4)
      8k          <ticker|CIK>            Recent 8-K material events
      fund        <ticker|CIK>            Latest N-PORT fund holdings

    EXAMPLES:
      edgar portfolio AAPL
      edgar financial AAPL Revenue
      edgar insider BRK-B
      edgar 8k MSFT
    """)
}

private func fail(_ message: String) -> Never {
    fputs("edgar: \(message)\n", stderr)
    exit(1)
}

extension Array {
    func element(at index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
