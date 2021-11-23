@testable import LunchOnUsDownloader
import XCTest

final class DownloadErrorTests: XCTestCase {

    func testErrorStrings() {
        XCTAssertEqual("\(DownloadError.httpError(error: "Failed").localizedDescription)", "An HTTP error occurred: Failed")
        XCTAssertEqual("\(DownloadError.authenticationFailed.localizedDescription)", "Login failed")
        XCTAssertEqual("\(DownloadError.noBalanceFound.localizedDescription)", "The balance was not found on the website")
        XCTAssertEqual("\(DownloadError.parsingFailure(string: "ABC").localizedDescription)", "Could not parse ABC")
    }

}
