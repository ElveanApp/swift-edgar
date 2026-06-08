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
                    let ticker = r.ticker.map { pad($0, to: 6) } ?? "      "
                    print("CIK \(pad(String(r.cik), to: 10, pad: "0", align: .left))  \(ticker)  \(r.name)")
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
                        print("\(point.end)  \(pad(point.form, to: 5))  $\(formatNumber(point.val))")
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
                            let label = concept.label.map { String($0.prefix(40)) } ?? name
                            print("  \(pad(label, to: 40))  $\(formatNumber(value))")
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
    print("CIK:        \(pad(String(company.cik), to: 10, pad: "0", align: .left))")
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
    print("\(pad("Name", to: 30)) \(pad("Shares", to: 8)) \(pad("Value (k$)", to: 11))  \(pad("Ticker", to: 8, align: .right)) \(pad("Type", to: 8, align: .right))")
    print(String(repeating: "-", count: 80))
    for h in sorted {
        let ticker = h.ticker ?? h.cusip
        let type = h.putCall?.rawValue ?? h.titleOfClass
        print("\(pad(String(h.nameOfIssuer.prefix(30)), to: 30)) \(pad(String(h.shares), to: 8)) \(pad("$" + String(h.value), to: 11))  \(pad(String(ticker.prefix(8)), to: 8, align: .right)) \(pad(String(type.prefix(8)), to: 8, align: .right))")
    }
    let total = sorted.reduce(0) { $0 + $1.value }
    print("\n\(sorted.count) holdings  |  Total value: $\(total)k")
}

private func printFund(_ fund: FundPortfolio) {
    print("\(fund.fundName) — Fund Portfolio")
    print("Report Date: \(fund.reportDate)")
    print(String(repeating: "-", count: 80))
    let top = fund.topHoldings(20)
    for (i, h) in top.enumerated() {
        let name = h.title ?? h.name
        print("\(pad(String(i + 1), to: 3, align: .right)). \(pad(String(name.prefix(40)), to: 40)) \(pad("$" + formatNumber(h.value), to: 14))")
    }
    let assets = fund.totalAssets.map { "$\(formatNumber($0))" } ?? "N/A"
    print("\n\(fund.holdingCount) total holdings  |  Total assets: \(assets)")
}

// MARK: - Formatting

private enum Align { case left, right }

private func pad(_ s: String, to width: Int, pad char: Character = " ", align: Align = .left) -> String {
    let diff = width - s.count
    if diff <= 0 { return String(s.prefix(width)) }
    switch align {
    case .left:  return s + String(repeating: char, count: diff)
    case .right: return String(repeating: char, count: diff) + s
    }
}

private func formatNumber(_ value: Int) -> String { formatNumber(Double(value)) }
private func formatNumber(_ value: Double) -> String {
    let absValue = abs(value)
    let n: String
    switch absValue {
    case 1_000_000_000_000...: n = String(format: "%.2f", value / 1_000_000_000_000) + "T"
    case 1_000_000_000...:     n = String(format: "%.2f", value / 1_000_000_000) + "B"
    case 1_000_000...:         n = String(format: "%.2f", value / 1_000_000) + "M"
    case 1_000...:             n = String(format: "%.0f", value)
    default:                   n = String(format: "%.2f", value)
    }
    return n
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
