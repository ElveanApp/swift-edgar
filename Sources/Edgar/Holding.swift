import Foundation

// MARK: - Holding

public struct Holding: Codable, Sendable {
    public let nameOfIssuer: String
    public let titleOfClass: String
    public let cusip: String
    public let value: Int          // in thousands of USD
    public let shares: Int
    public let shareType: ShareType
    public let putCall: PutCall?
    public let investmentDiscretion: InvestmentDiscretion
    public let votingSole: Int
    public let votingShared: Int
    public let votingNone: Int
    public var ticker: String?

    public enum ShareType: String, Codable, Sendable {
        case shares = "SH"
        case principal = "PRN"
    }

    public enum PutCall: String, Codable, Sendable {
        case put = "PUT"
        case call = "CALL"
    }

    public enum InvestmentDiscretion: String, Codable, Sendable {
        case sole = "SOLE"
        case defined = "DFND"
        case other = "OTR"
    }

    /// Ticker if resolved, otherwise CUSIP.
    public var label: String { ticker ?? cusip }

    /// Value in actual dollars (not thousands).
    public var marketValue: Int { value * 1000 }

    public init(nameOfIssuer: String, titleOfClass: String, cusip: String,
                value: Int, shares: Int, shareType: ShareType,
                putCall: PutCall? = nil,
                investmentDiscretion: InvestmentDiscretion,
                votingSole: Int, votingShared: Int, votingNone: Int,
                ticker: String? = nil) {
        self.nameOfIssuer = nameOfIssuer
        self.titleOfClass = titleOfClass
        self.cusip = cusip
        self.value = value
        self.shares = shares
        self.shareType = shareType
        self.putCall = putCall
        self.investmentDiscretion = investmentDiscretion
        self.votingSole = votingSole
        self.votingShared = votingShared
        self.votingNone = votingNone
        self.ticker = ticker
    }
}

// MARK: - Portfolio

public struct Portfolio: Codable, Sendable {
    public let company: Company
    public let filing: Filing
    public let holdings: [Holding]

    /// Total portfolio value in thousands of USD.
    public var totalValue: Int {
        holdings.reduce(0) { $0 + $1.value }
    }

    /// Total portfolio value in dollars.
    public var totalMarketValue: Int {
        holdings.reduce(0) { $0 + $1.marketValue }
    }

    /// Number of distinct positions.
    public var positionCount: Int { holdings.count }

    /// Holdings sorted by value descending, limited to top N.
    public func topHoldings(_ count: Int = 10) -> [Holding] {
        Array(holdings.sorted { $0.value > $1.value }.prefix(count))
    }

    /// Portfolio weight of a holding as a percentage (0–100).
    public func weight(of holding: Holding) -> Double {
        guard totalValue > 0 else { return 0 }
        return Double(holding.value) / Double(totalValue) * 100
    }

    /// Find a holding by CUSIP.
    public func holding(forCUSIP cusip: String) -> Holding? {
        holdings.first { $0.cusip == cusip }
    }

    /// Find a holding by ticker.
    public func holding(forTicker ticker: String) -> Holding? {
        holdings.first { $0.ticker?.uppercased() == ticker.uppercased() }
    }
}

// MARK: - Portfolio Comparison

public struct PositionChange: Sendable {
    public let cusip: String
    public let nameOfIssuer: String
    public let ticker: String?
    public let currentShares: Int
    public let previousShares: Int
    public let currentValue: Int
    public let previousValue: Int

    public var shareChange: Int { currentShares - previousShares }
    public var valueChange: Int { currentValue - previousValue }

    public var percentChange: Double {
        guard previousShares > 0 else { return currentShares > 0 ? .infinity : 0 }
        return Double(shareChange) / Double(previousShares) * 100
    }
}

public struct PortfolioComparison: Sendable {
    public let current: Portfolio
    public let previous: Portfolio
    public let newPositions: [Holding]
    public let closedPositions: [Holding]
    public let increasedPositions: [PositionChange]
    public let decreasedPositions: [PositionChange]
    public let unchangedPositions: [PositionChange]

    public static func compare(current: Portfolio, previous: Portfolio) -> PortfolioComparison {
        let currentByCUSIP = Dictionary(
            current.holdings.map { ($0.cusip, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let previousByCUSIP = Dictionary(
            previous.holdings.map { ($0.cusip, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let currentCUSIPs = Set(currentByCUSIP.keys)
        let previousCUSIPs = Set(previousByCUSIP.keys)

        let newPositions = currentCUSIPs.subtracting(previousCUSIPs)
            .compactMap { currentByCUSIP[$0] }
            .sorted { $0.value > $1.value }

        let closedPositions = previousCUSIPs.subtracting(currentCUSIPs)
            .compactMap { previousByCUSIP[$0] }
            .sorted { $0.value > $1.value }

        var increased: [PositionChange] = []
        var decreased: [PositionChange] = []
        var unchanged: [PositionChange] = []

        for cusip in currentCUSIPs.intersection(previousCUSIPs) {
            guard let curr = currentByCUSIP[cusip],
                  let prev = previousByCUSIP[cusip] else { continue }

            let change = PositionChange(
                cusip: cusip,
                nameOfIssuer: curr.nameOfIssuer,
                ticker: curr.ticker,
                currentShares: curr.shares,
                previousShares: prev.shares,
                currentValue: curr.value,
                previousValue: prev.value
            )

            if curr.shares > prev.shares {
                increased.append(change)
            } else if curr.shares < prev.shares {
                decreased.append(change)
            } else {
                unchanged.append(change)
            }
        }

        increased.sort { abs($0.shareChange) > abs($1.shareChange) }
        decreased.sort { abs($0.shareChange) > abs($1.shareChange) }

        return PortfolioComparison(
            current: current,
            previous: previous,
            newPositions: newPositions,
            closedPositions: closedPositions,
            increasedPositions: increased,
            decreasedPositions: decreased,
            unchangedPositions: unchanged
        )
    }
}
