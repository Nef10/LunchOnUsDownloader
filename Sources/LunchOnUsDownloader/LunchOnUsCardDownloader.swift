import Foundation
import SwiftBeanCountParserUtils

/// Protocol to descibe an object which provides functions to download Lunch On Us Card data
public protocol LunchOnUsCardDownloaderProvider {

    /// Authenticate to the website
    ///
    /// Note: This function must be called before calling getTransactions or getBalance.
    /// - Parameters:
    ///   - number: Card number
    ///   - pin: Security digits of the card
    /// - Returns: An error in case the login failed.
    static func authenticate(number: String, pin: String) async -> DownloadError?

    /// Download Transactions from the website for a given time frame
    ///
    /// - Parameters:
    ///   - from: Date to download transactions from
    ///   - date: Date to downloads transactions to
    /// - Returns:A Result with LunchOnUsTransaction or a DownloadError in case the downloading failed
    static func getTransactions(from fromDate: Date, to toDate: Date) async -> Result<[LunchOnUsTransaction], DownloadError>

    /// Downloads the current balance on the card
    /// - Returns: A Result with either a tuple containing a Decimal with the current balance and an Int specifying the number of parsed decimal digits,
    ///            or a DownloadError in case the downloading failed
    static func getBalance() async -> Result<(Decimal, Int), DownloadError>

}

/// An type of transaction on the card
public enum LunchOnUsTransactionType: String {
    /// A normal purchase
    case purchase = "Purchase"
    /// When the gift card balance is set to zero
    case cashOut = "Cash Out"
    /// When the gift card is loaded with money
    case activate = "Activate Card"
}

/// A Transaction on the Card
public protocol LunchOnUsTransaction {
    /// Date and time when the transaction happend
    var date: Date { get }
    /// Type of the transaction, e.g. a purchase or loading money onto the car
    var type: LunchOnUsTransactionType { get }
    /// Dollar amount of the transaction.
    /// A tuple containing a Decimal with the Amount and an Int specifying the number of parsed decimal digits
    var amount: (Decimal, Int) { get }
    /// Internal number of the transaction
    var invoiceNumber: String { get }
    /// Location / Merchant of the transaction
    var location: String { get }
}

struct LunchOnUsTransactionImplementation: LunchOnUsTransaction {
    public let date: Date
    public let type: LunchOnUsTransactionType
    public let amount: (Decimal, Int)
    public let invoiceNumber: String
    public let location: String
}

public enum LunchOnUsCardDownloader: LunchOnUsCardDownloaderProvider {

    private static let loginURL = URL(string: "https://giftcard.eigendev.com/giftcards/signin.php")!
    private static let balanceURL = URL(string: "https://giftcard.eigendev.com/giftcards/main/CH/balance.php")!
    private static let transactionURL = URLComponents(string: "https://giftcard.eigendev.com/giftcards/main/CH/transactions.php")!

    public static func authenticate(number: String, pin: String) async -> DownloadError? {
        let data = "fakeusernameremembered=&fakepasswordremembered=&JavaOn=&type=&requestLanguage=EN&Card_Num=\(number)&PIN=\(pin)".data(using: .utf8)

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return DownloadError.httpError(error: "No HTTPURLResponse")
            }
            guard httpResponse.statusCode == 200 else {
                return DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")
            }
            guard !(httpResponse.url?.absoluteString.contains("failed") ?? false) else {
                return DownloadError.authenticationFailed
            }
            return nil
        } catch {
           return DownloadError.httpError(error: error.localizedDescription)
        }
    }

    public static func getTransactions(from fromDate: Date, to toDate: Date) async -> Result<[LunchOnUsTransaction], DownloadError> {
        let transactionsDownloadResult = await getTransactionsHTML(from: fromDate, to: toDate)
        switch transactionsDownloadResult {
        case let .failure(error):
            return .failure(error)
        case let .success(html):
            return extractTransactions(from: html)
        }
    }

    public static func getBalance() async -> Result<(Decimal, Int), DownloadError> {
        let balanceResult = await getBalanceHTML()
        switch balanceResult {
        case let .failure(error):
            return .failure(error)
        case let .success(html):
            if let balanceString = extractBalance(from: html) {
                return .success(balanceString.amountDecimal())
            } else {
                return .failure(DownloadError.noBalanceFound)
            }
        }
    }

    private static func getTransactionsHTML(from fromDate: Date, to toDate: Date) async -> Result<String, DownloadError> {
        do {
            let calendar = Calendar(identifier: .gregorian)
            let startDate = calendar.dateComponents([.day, .year, .month], from: fromDate)
            let endDate = calendar.dateComponents([.day, .year, .month], from: toDate)
            var urlComponents = transactionURL
            urlComponents.queryItems = [
                URLQueryItem(name: "Pay_Month", value: "\(startDate.month!)"),
                URLQueryItem(name: "Pay_Day", value: "\(startDate.day!)"),
                URLQueryItem(name: "Pay_Year", value: "\(startDate.year! % 100)"),
                URLQueryItem(name: "Pay_EMonth", value: "\(endDate.month!)"),
                URLQueryItem(name: "Pay_EDay", value: "\(endDate.day!)"),
                URLQueryItem(name: "Pay_EYear", value: "\(endDate.year! % 100)"),
                URLQueryItem(name: "details", value: "1")
            ]
            let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(DownloadError.httpError(error: "No HTTPURLResponse"))
            }
            guard httpResponse.statusCode == 200 else {
                return .failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)"))
            }
            return .success(String(data: data, encoding: .utf8) ?? "")
        } catch {
           return .failure(DownloadError.httpError(error: error.localizedDescription))
        }
    }

    private static func extractTransactions(from html: String) -> Result<[LunchOnUsTransaction], DownloadError> {
        // swiftlint:disable:next force_try line_length
        let regex = try! NSRegularExpression(pattern: "<tr\\s*class=\"transactionDataApproved\"\\s*>\\s*<\\s*td[^>]*><\\s*span[^>]*>([^<]*)<\\s*/\\s*span\\s*>[^<]*<\\s*span[^>]*>([^<]*)<\\s*/\\s*span\\s*><\\s*/\\s*td\\s*>\\s*<\\s*td[^>]*>([^<]*)<\\s*/\\s*td\\s*>\\s*<\\s*td[^>]*>([^<]*)<\\s*/\\s*td\\s*>\\s*<\\s*td[^>]*>([^<]*)<\\s*/\\s*td\\s*>\\s*<\\s*td[^>]*>([^<]*)<\\s*/\\s*td\\s*>\\s*<\\s*td[^>]*>([^<]*)<\\s*/\\s*td\\s*>\\s*<\\s*/\\s*tr\\s*>", options: [])
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy HH:mm:ss"
        do {
            let transactions = try html.matchingStrings(regex: regex).map { match -> LunchOnUsTransaction in
                let dateString = "\(match[1]) \(match[2])"
                guard let date = dateFormatter.date(from: dateString) else {
                    throw DownloadError.parsingFailure(string: dateString)
                }
                guard let transactionType = LunchOnUsTransactionType(rawValue: match[3]) else {
                    throw DownloadError.parsingFailure(string: match[3])
                }
                return LunchOnUsTransactionImplementation(date: date,
                                                          type: transactionType,
                                                          amount: match[4].replacingOccurrences(of: "$", with: "").amountDecimal(),
                                                          invoiceNumber: match[5],
                                                          location: match[7])
            }
            return .success(transactions)
        } catch {
            return .failure(error as! DownloadError) // swiftlint:disable:this force_cast
        }
    }

    private static func getBalanceHTML() async -> Result<String, DownloadError> {
        do {
            let (data, response) = try await URLSession.shared.data(from: balanceURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(DownloadError.httpError(error: "No HTTPURLResponse"))
            }
            guard httpResponse.statusCode == 200 else {
                return .failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)"))
            }
            return .success(String(data: data, encoding: .utf8) ?? "")
        } catch {
           return .failure(DownloadError.httpError(error: error.localizedDescription))
        }
    }

    private static func extractBalance(from html: String) -> String? {
        // swiftlint:disable:next force_try
        let tds = html.matchingStrings(regex: try! NSRegularExpression(pattern: "<\\s*td[^>]*>([^<]*)<\\s*/\\s*td\\s*>", options: [])).compactMap { $0.last }
        let balanceTextIndex = tds.firstIndex { $0.contains("Current Balance") } // Balance is in the td after this text
        let index: Int!
        if let textIndex = balanceTextIndex, tds.count > textIndex + 1 {
            index = textIndex + 1
        } else if let textIndex = tds.firstIndex(where: { $0.contains("$") }) { // Fallback to td with $ in there
            index = textIndex
        } else {
            return nil
        }
        let balance = tds[index].replacingOccurrences(of: "$", with: "")
        return balance
    }

}
