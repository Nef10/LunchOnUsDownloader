# LunchOnUs Downloader

[![CI Status](https://github.com/Nef10/LunchOnUsDownloader/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/LunchOnUsDownloader/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/LunchOnUsDownloader/badge.svg)](https://nef10.github.io/LunchOnUsDownloader/) [![License: MIT](https://img.shields.io/github/license/Nef10/LunchOnUsDownloader)](https://github.com/Nef10/LunchOnUsDownloader/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/LunchOnUsDownloader?label=SemVer&sort=semver)](https://github.com/Nef10/LunchOnUsDownloader/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

## What

This is a small library to download transaction and balance data for LunchOnUs Cards (Giftcards by Eigen Development).

## How

1) Call `LunchOnUsCardDownloader.authenticate(number: "x", pin: "x,")`
2) Check that the call did not return an error
3) Now you can call either `getBalance()` or `getTransactions(from: Date, to: Date)`

Please also check out the complete documentation [here](https://nef10.github.io/LunchOnUsDownloader/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/LunchOnUsDownloader.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*

## Copyright

While my code is licensed under the [MIT License](https://github.com/Nef10/LunchOnUsDownloader/blob/main/LICENSE), the source repository may include names or other trademarks of Eigen Development Ltd. or other entities; potential usage restrictions for these elements still apply and are not touched by the software license. Same applies for the API design. I am in no way affilliated with Eigen Development Ltd. other having using a card issues by them.
