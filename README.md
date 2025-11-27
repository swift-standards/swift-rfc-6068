[![CI](https://github.com/swift-standards/swift-rfc-6068/workflows/CI/badge.svg)](https://github.com/swift-standards/swift-rfc-6068/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

# swift-rfc-6068

A Swift implementation of [RFC 6068](https://www.rfc-editor.org/rfc/rfc6068) - The 'mailto' URI Scheme.

## Overview

RFC 6068 defines the mailto URI scheme for designating email addresses. This package provides type-safe parsing and serialization of mailto URIs with full support for header fields (subject, body, cc, bcc, etc.) and percent-encoding per RFC 3986.

This RFC obsoletes RFC 2368 and adds support for Internationalized Resource Identifiers (IRIs) per RFC 3987.

## Features

- Complete mailto URI parsing from ASCII bytes
- Header field (hfield) extraction and construction
- Percent-encoding/decoding per RFC 3986
- Convenience accessors for common headers (subject, body, cc, bcc)
- Full `UInt8.ASCII.Serializable` conformance
- Sendable and Codable types

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-standards/swift-rfc-6068", from: "0.1.0")
]
```

And add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "RFC 6068", package: "swift-rfc-6068")
    ]
)
```

## Quick Start

```swift
import RFC_6068

// Parse a mailto URI
let mailto = try RFC_6068.Mailto(ascii: "mailto:user@example.com?subject=Hello".utf8)
print(mailto.to.first?.rawValue)  // "user@example.com"
print(mailto.subject)              // "Hello"

// Create a mailto URI programmatically
let addr = try RFC_5322.EmailAddress("user@example.com")
let mailto = RFC_6068.Mailto(
    to: [addr],
    headers: [.subject("Hello World"), .body("Message content")]
)
print(String(mailto))  // "mailto:user@example.com?subject=Hello%20World&body=Message%20content"
```

## Usage Examples

### Parsing mailto URIs

```swift
// Simple mailto
let mailto = try RFC_6068.Mailto(ascii: "mailto:chris@example.com".utf8)

// With multiple recipients
let mailto = try RFC_6068.Mailto(ascii: "mailto:user1@example.com,user2@example.com".utf8)
print(mailto.to.count)  // 2

// With percent-encoded values
let mailto = try RFC_6068.Mailto(ascii: "mailto:user@example.com?subject=Hello%20World".utf8)
print(mailto.subject)  // "Hello World"

// Headers-only (no recipients in path)
let mailto = try RFC_6068.Mailto(ascii: "mailto:?to=user@example.com&subject=Test".utf8)
```

### Accessing Headers

```swift
let mailto = try RFC_6068.Mailto(
    ascii: "mailto:list@example.com?subject=Subscribe&cc=admin@example.com".utf8
)

// Convenience accessors
mailto.subject  // "Subscribe"
mailto.body     // nil
mailto.cc       // [RFC_5322.EmailAddress]
mailto.bcc      // [RFC_5322.EmailAddress]

// All recipients (path + header To addresses)
mailto.allTo    // Combined list
```

### Building mailto URIs

```swift
let mailto = RFC_6068.Mailto(
    to: [try RFC_5322.EmailAddress("recipient@example.com")],
    headers: [
        .subject("Meeting Request"),
        .body("Please confirm your attendance."),
        .cc("manager@example.com")
    ]
)

// Serialize to string
let uriString = String(mailto)

// Serialize to bytes
let bytes = [UInt8](mailto)
```

## Related Packages

| Package | Description |
|---------|-------------|
| [swift-rfc-3986](https://github.com/swift-standards/swift-rfc-3986) | URI Generic Syntax |
| [swift-rfc-3987](https://github.com/swift-standards/swift-rfc-3987) | Internationalized Resource Identifiers (IRIs) |
| [swift-rfc-5322](https://github.com/swift-standards/swift-rfc-5322) | Internet Message Format |
| [swift-rfc-2369](https://github.com/swift-standards/swift-rfc-2369) | URLs for Mailing List Management |
| [swift-incits-4-1986](https://github.com/swift-standards/swift-incits-4-1986) | US-ASCII character operations |

## License

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE.md) for details.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.
