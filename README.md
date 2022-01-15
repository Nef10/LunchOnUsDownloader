# LunchOnUs Downloader

## This projects is deprecated as I do not longer have a Card to be able to use this downloader. It however might still work.

<details>
  <summary>Using it with SwiftBeanCountImporter</summary>
  
  
As the integration with [SwiftBeanCountImporter](https://github.com/Nef10/SwiftBeanCountImporter) was never fully finished, here is the draft of the importer code:
  
```
//
//  LunchOnUsDownloadImporter.swift
//
//
//  Created by Steffen Kötte on 2021-11-21.
//

import Foundation
import SwiftBeanCountModel
import LunchOnUsDownloader

class LunchOnUsDownloadImporter: BaseImporter, DownloadImporter {

    enum MetaDataKey {
    }

    enum MetaDataKeys {
        static let invoiceNumber = "invoice-number"
        static let customsKey = "lunch-on-us-download-importer"
        static let monthToLoad = "monthToLoad"
    }

    enum MetaDataValues {
        static let cashOut = "cash-out-"
        static let loadCard = "load-card-"
        static let cashOutAccount = "cash-out"
        static let loadCardAccount = "load-card"
    }

    enum CredentialKey: String, CaseIterable {
        case number
        case securityDigits
    }

    override class var importerName: String { "Lunch On Us Download" }
    override class var importerType: String { "lunch-on-us" }
    override class var helpText: String { //  swiftlint:disable line_length
        """
        Downloads transactions and the current balance from the LunchOnUs website.

        The importer relies on meta data in your Beancount file to find your accounts. Please add:
          importer-type: "\(importerType)"
        to your LunchOnUs Card Asset account.

        Optionally, you can add \(MetaDataKeys.customsKey): "\(MetaDataValues.loadCardAccount)" to an account to specify where the card account should be loaded from, likewise use \(MetaDataKeys.customsKey): "\(MetaDataValues.cashOutAccount)" to indicate where forfeit money should be booked to.

        By default the downloader loads the last three month of transactions. To modify this, and for example configure it to two month, add a custom option to your file: YYYY-MM-DD custom "\(MetaDataKeys.customsKey)" "\(MetaDataKeys.monthToLoad)" "2".
        """
    } //  swiftlint:enable line_length

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    override var importName: String { "Lunch On Us Download" }
    var downloaderClass: LunchOnUsCardDownloaderProvider.Type = LunchOnUsCardDownloader.self

    private var date: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: Date()))! }

    /// Results
    private var transactions = [ImportedTransaction]()
    private var balance: Balance?

    override required init(ledger: Ledger?) {
        super.init(ledger: ledger)
    }

    override func load() {
        let group = DispatchGroup()
        group.enter()

        download {
            group.leave()
        }

        group.wait()
    }

    private func download(_ completion: @escaping () -> Void) {
        getCredentials { number, pin in
            Task {
                await self.download(number: number, pin: pin)
                completion()
            }
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !transactions.isEmpty else {
            return nil
        }
        return transactions.removeFirst()
    }

    override func balancesToImport() -> [Balance] {
        if let balance = balance {
            return [balance]
        }
        return []
    }

    private func commoditySymbol() -> CommoditySymbol {
        ledger?.accounts.first { $0.name == configuredAccountName }?.commoditySymbol ?? Settings.fallbackCommodity
    }

    private func monthToLoad() -> Int {
        let monthToLoad = Int(ledger?.custom.filter { $0.name == MetaDataKeys.customsKey && $0.values.first == MetaDataKeys.monthToLoad }
                                                  .max { $0.date < $1.date }?.values[1] ?? "")
        return monthToLoad ?? 3
    }

    private func loadCardAccountName() -> AccountName? {
        ledger?.accounts.first { $0.metaData[MetaDataKeys.customsKey] == MetaDataValues.loadCardAccount }?.name
    }

    private func cashOutAccountName() -> AccountName? {
        ledger?.accounts.first { $0.metaData[MetaDataKeys.customsKey] == MetaDataValues.cashOutAccount }?.name
    }

    private func download(number: String, pin: String) async {
        if let autenticationError = await downloaderClass.authenticate(number: number, pin: pin) {
            self.removeSavedCredentails()
            self.delegate?.error(autenticationError)
            return
        }
        let balanceResult = await downloaderClass.getBalance()
        switch balanceResult {
        case let .failure(error):
            self.delegate?.error(error)
            return
        case let .success(amount):
            let (number, digits) = amount
            let balance = Balance(date: self.date,
                                  accountName: self.configuredAccountName,
                                  amount: Amount(number: number, commoditySymbol: self.commoditySymbol(), decimalDigits: digits))
            if !(self.ledger?.accounts.first(where: { $0.name == self.configuredAccountName })?.balances.contains(balance) ?? false) {
                self.balance = balance
            }
        }
        let transactionsResult = await downloaderClass.getTransactions(from: Calendar.current.date(byAdding: .month, value: -self.monthToLoad(), to: Date())!,
                                                                       to: Date())
        switch transactionsResult {
        case let .failure(error):
            self.delegate?.error(error)
            return
        case let .success(transactions):
            self.transactions = self.mapTransactions(transactions)
            return
        }
    }

    private func mapTransactions(_ transations: [LunchOnUsTransaction]) -> [ImportedTransaction] {
        transations.compactMap { self.mapTransaction($0) }
    }

    private func mapTransaction(_ transaction: LunchOnUsTransaction) -> ImportedTransaction? {
        var allowEdit = true
        var invoiceNumber = transaction.invoiceNumber
        let (number, decimalDigits) = transaction.amount
        let (savedDescription, savedPayee) = savedDescriptionAndPayeeFor(description: transaction.location)
        var savedAccount = savedAccountNameFor(payee: savedPayee ?? "")
        if transaction.type == .activate {
            invoiceNumber = "\(MetaDataValues.loadCard)\(Self.dateFormatter.string(from: transaction.date))"
            if let accountName = loadCardAccountName() {
                savedAccount = accountName
                allowEdit = false
            }
        } else if transaction.type == .cashOut {
            invoiceNumber = "\(MetaDataValues.cashOut)\(Self.dateFormatter.string(from: transaction.date))"
            if let accountName = cashOutAccountName() {
                savedAccount = accountName
                allowEdit = false
            }
        }
        guard !(ledger?.transactions.contains(where: { $0.metaData.metaData[MetaDataKeys.invoiceNumber] == invoiceNumber }) ?? false) else {
            return nil
        }
        let narration = allowEdit ? savedDescription ?? transaction.location : ""
        let amount1 = Amount(number: transaction.type == .activate ? number : -number, commoditySymbol: commoditySymbol(), decimalDigits: decimalDigits)
        let amount2 = Amount(number: transaction.type == .activate ? -number : number, commoditySymbol: commoditySymbol(), decimalDigits: decimalDigits)
        let posting1 = Posting(accountName: self.configuredAccountName, amount: amount1)
        let posting2 = Posting(accountName: try! savedAccount ?? AccountName(Settings.defaultAccountName), amount: amount2) // swiftlint:disable:this force_try
        let metaData = TransactionMetaData(date: transaction.date, payee: savedPayee ?? "", narration: narration, metaData: [MetaDataKeys.invoiceNumber: invoiceNumber])
        let modelTransaction = Transaction(metaData: metaData, postings: [posting1, posting2])
        return ImportedTransaction(modelTransaction,
                                   originalDescription: transaction.location,
                                   possibleDuplicate: getPossibleDuplicateFor(modelTransaction),
                                   shouldAllowUserToEdit: allowEdit,
                                   accountName: allowEdit ? self.configuredAccountName : nil)
    }

    private func getCredentials(callback: @escaping ((String, String) -> Void)) {
        let number = getCredential(key: .number, name: "Card Number")
        let securityDigits = getCredential(key: .securityDigits, name: "Security Digits", isSecret: true)
        callback(number, securityDigits)
    }

    private func removeSavedCredentails() {
        for key in CredentialKey.allCases {
            self.delegate?.saveCredential("", for: "\(Self.importerType)-\(key.rawValue)")
        }
    }

    private func getCredential(key: CredentialKey, name: String, isSecret: Bool = false) -> String {
        var value: String!
        if let savedValue = self.delegate?.readCredential("\(Self.importerType)-\(key.rawValue)"), !savedValue.isEmpty {
            value = savedValue
        } else {
            let group = DispatchGroup()
            group.enter()
            delegate?.requestInput(name: name, suggestions: [], isSecret: isSecret) {
                value = $0
                group.leave()
                return true
            }
            group.wait()
        }
        self.delegate?.saveCredential(value, for: "\(Self.importerType)-\(key.rawValue)")
        return value
    }

}
```
  
</details>
  
<details>
  <summary>Old Readme content</summary>

[![License: MIT](https://img.shields.io/github/license/Nef10/LunchOnUsDownloader)](https://github.com/Nef10/LunchOnUsDownloader/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/LunchOnUsDownloader?label=SemVer&sort=semver)](https://github.com/Nef10/LunchOnUsDownloader/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

## What

This is a small library to download transaction and balance data for LunchOnUs Cards (Giftcards by Eigen Development).

## How

1) Call `LunchOnUsCardDownloader.authenticate(number: "x", pin: "x,")`
2) Check that the call did not return an error
3) Now you can call either `getBalance()` or `getTransactions(from: Date, to: Date)`

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/LunchOnUsDownloader.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*
                                                              
</details>

## Copyright

While my code is licensed under the [MIT License](https://github.com/Nef10/LunchOnUsDownloader/blob/main/LICENSE), the source repository may include names or other trademarks of Eigen Development Ltd. or other entities; potential usage restrictions for these elements still apply and are not touched by the software license. Same applies for the API design. I am in no way affilliated with Eigen Development Ltd. other having using a card issues by them.
