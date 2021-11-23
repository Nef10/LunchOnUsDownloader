import Foundation

/// Errors which can happen when getting a downloading data
public enum DownloadError: Error {
    /// When an HTTP error occurs while downloading
    case httpError(error: String)
    /// In case the login failed
    case authenticationFailed
    /// In case the balance was not found on the website
    case noBalanceFound
    /// In case some content of the website could not be parsed into the right format
    case parsingFailure(string: String)
}

extension DownloadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .httpError(error):
            return "An HTTP error occurred: \(error)"
        case .authenticationFailed:
            return "Login failed"
        case .noBalanceFound:
            return "The balance was not found on the website"
        case let .parsingFailure(string):
            return "Could not parse \(string)"
        }

    }
}
