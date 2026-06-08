# Edgar

**A native Swift library and CLI for SEC EDGAR — company filings, financial data, insider trades, and fund holdings. Zero external dependencies, Foundation only.**

[![](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![](https://img.shields.io/badge/platform-macOS%2013%2B%20|%20iOS%2016%2B-lightgrey)](https://swift.org)
[![](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FElveanApp%2Fswift-edgar%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ElveanApp/swift-edgar)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FElveanApp%2Fswift-edgar%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ElveanApp/swift-edgar)

Built with Swift concurrency — async/await and actors throughout. The only dependency is Foundation. Parses 13F XML, N-PORT XML, and Form 4 XML using native `Foundation.XMLParser`.

```swift
let edgar = Edgar()

// Warren Buffett's latest 13F portfolio
let portfolio = try await edgar.latestPortfolio(cik: 1067983)

// Apple's revenue history (XBRL financials)
let facts = try await edgar.companyFacts(cik: 320193)
let revenue = facts.latestValue("Revenues")

// Recent insider trades
let trades = try await edgar.recentInsiderTrades(cik: 320193)
```

---

## CLI

Query SEC EDGAR from your terminal.

### Install

```bash
brew tap ElveanApp/tap
brew install edgar
```

Or build from source:

```bash
swift build -c release
cp .build/release/edgar /usr/local/bin/
```

### Usage

```bash
$ edgar portfolio BRK-B
BERKSHIRE HATHAWAY INC — 13F Portfolio
Filing: 2026-05-15
Name                           Shares   Value (k$)     Ticker     Type
AMERICAN EXPRESS CO            14906104 $4508798489       AXP      COM
COCA COLA CO                   28272272 $2150106354        KO      COM
...

$ edgar financial AAPL Revenues
$ edgar insider MSFT
$ edgar 8k GOOGL
$ edgar search NVIDIA
$ edgar fund VOO
```

---

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ElveanApp/swift-edgar.git", from: "1.0.0")
]
```

Then add `"Edgar"` to your target's dependencies and `import Edgar` in your code.

## Features

### Company Search

Look up any public company by CIK, ticker, or name.

```swift
let apple = try await edgar.company(ticker: "AAPL")
let results = try await edgar.searchCompanies("NVIDIA")
```

### Filings

Retrieve filings by form type — 13F-HR, 10-K, 10-Q, 8-K, S-1, Form 4, and more.

```swift
let annual = try await edgar.allFilings(cik: 320193, form: "10-K", limit: 5)
let eightK = try await edgar.eightKFilings(cik: 320193)
let proxies = try await edgar.proxyFilings(cik: 320193)
let registrations = try await edgar.registrationFilings(cik: 320193)
```

### 13F Portfolio Tracking

Parse hedge fund and institutional investor holdings from 13F-HR filings. Automatically resolves CUSIPs to ticker symbols via OpenFIGI.

```swift
let portfolio = try await edgar.latestPortfolio(cik: 1067983)

// Sortable holdings with CUSIP → ticker resolution
for holding in portfolio.holdings {
    print("\(holding.ticker ?? holding.cusip): $\(holding.value)")
}

// Quarter-over-quarter comparison
let diff = try await edgar.compareQuarters(cik: 1067983)
// diff.added, diff.removed, diff.increased, diff.decreased
```

### XBRL Financial Data

Query company financials — revenue, net income, assets, and every other concept reported in SEC filings — across any time period.

```swift
let facts = try await edgar.companyFacts(cik: 320193)
let revenue = facts.latestValue("Revenues")
let netIncome = facts.latestValue("NetIncomeLoss")

// All available concepts
let concepts = facts.conceptNames()

// Historical values for a single concept
let history = try await edgar.companyConcept(cik: 320193, concept: "Revenue")
for point in history.usdValues.prefix(5) {
    print("\(point.end): $\(point.val)")
}
```

### Cross-Company Comparison (Frames)

Compare a single financial metric across all reporting companies in a given period.

```swift
let frame = try await edgar.frame(concept: "Revenue", period: "CY2023")
let top10 = frame.topCompanies(10)
```

### Insider Trading (Form 4)

Track insider buying and selling with structured transaction data.

```swift
let trades = try await edgar.recentInsiderTrades(cik: 320193)
for report in trades {
    for tx in report.transactions {
        print("\(tx.code.description): \(tx.shares) shares @ \(tx.pricePerShare ?? 0)")
    }
}
```

### Fund Holdings (N-PORT)

Parse mutual fund and ETF holdings from N-PORT filings.

```swift
let fund = try await edgar.latestFundPortfolio(cik: 886982)
let topHoldings = fund.topHoldings(10)
```

### 8-K Events

Monitor material corporate events with parsed item codes and descriptions.

```swift
let events = try await edgar.eightKFilings(cik: 320193)
for event in events {
    for item in event.items {
        print("\(item.code): \(item.description)")
    }
}
```

### Ownership (13D/G)

Track beneficial ownership filings and changes in institutional stakes.

```swift
let ownership = try await edgar.ownershipFilings(cik: 320193)
```

### Filing Documents

Download the full text of any filing — HTML or plain text.

```swift
let html = try await edgar.filingHTML(cik: 320193, filing: filing)
let text = try await edgar.filingText(cik: 320193, filing: filing)
```

## Use Cases

- **Hedge fund tracking** — monitor 13F portfolios and detect quarter-over-quarter changes in institutional positions
- **Equity research** — pull financial data, insider trades, and 8-K events for any public company
- **Screening** — run cross-company comparisons using the XBRL Frames API
- **Automated alerts** — detect Form 4 insider sales, 8-K material events, and 13F portfolio changes

## AI Agent Integration

`edgar` is a single binary with no dependencies — any AI agent that can invoke CLI tools can use it to pull live SEC data. Install once:

```bash
brew tap ElveanApp/tap && brew install edgar
```

### Claude Code

Add to `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(edgar *)"
    ]
  }
}
```

Then just ask: "Pull Berkshire's latest 13F portfolio and summarize the biggest changes."

### OpenClaw / OpenCode

In your project config or prompt:

```
Tool: edgar
  Description: Query SEC EDGAR data — 13F portfolios, XBRL financials, insider trades, 8-K events, fund holdings, company search.
  Commands:
    edgar portfolio <ticker|CIK>          Latest 13F holdings
    edgar financial <ticker|CIK> [concept]  XBRL financial data
    edgar insider <ticker|CIK>            Recent insider trades
    edgar 8k <ticker|CIK>                Material events
    edgar fund <ticker|CIK>              N-PORT fund holdings
    edgar search <name>                  Company search
    edgar company <ticker|CIK>           Company info
```

### Any agent with shell access

The CLI writes plain text to stdout — no JSON parsing required. Any agent that can run `edgar portfolio AAPL` in a subprocess gets structured financial data immediately.

## SEC EDGAR Compliance

This library enforces the SEC's [fair access rules](https://www.sec.gov/privacy#website-privacy-policy):

- **User-Agent required** — provide your app name and contact email
- **Rate limiting** — automatically throttled to ~8 requests/second (SAFE margin under the 10/sec limit)

```swift
let edgar = Edgar(userAgent: "MyApp/1.0 (you@example.com)")
```

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+
- No external dependencies — Foundation only

## Powered by Edgar

This library powers financial research workflows inside [Elvean](https://elvean.app) — a native AI workspace for macOS. Elvean's equity research features use Edgar to pull SEC filings, 13F portfolios, financial data, and insider trades, then render them as interactive charts, sortable tables, and structured analysis alongside AI-powered insights.

## License

MIT — see [LICENSE](LICENSE).
