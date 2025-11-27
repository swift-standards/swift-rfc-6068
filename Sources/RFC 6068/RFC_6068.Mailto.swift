// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-rfc-6068 open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

public import INCITS_4_1986

extension RFC_6068 {
    /// A mailto URI as defined in RFC 6068
    ///
    /// The mailto URI scheme designates an Internet mailing address for
    /// the purposes of composing a message.
    ///
    /// ## ABNF Grammar (RFC 6068 Section 2)
    ///
    /// ```
    /// mailtoURI = "mailto:" [ to ] [ hfields ]
    /// to        = addr-spec *("," addr-spec)
    /// hfields   = "?" hfield *("&" hfield)
    /// hfield    = hfname "=" hfvalue
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Simple mailto
    /// let mailto = try RFC_6068.Mailto(ascii: "mailto:user@example.com".utf8)
    ///
    /// // With subject and body
    /// let mailto = try RFC_6068.Mailto(
    ///     ascii: "mailto:user@example.com?subject=Hello&body=World".utf8
    /// )
    /// ```
    public struct Mailto: Sendable, Codable {
        /// The recipient email addresses (from the path component)
        public let to: [RFC_5322.EmailAddress]

        /// The header fields (from the query component)
        public let headers: [Header]

        /// Creates a mailto URI WITHOUT validation
        init(
            __unchecked: Void,
            to: [RFC_5322.EmailAddress],
            headers: [Header]
        ) {
            self.to = to
            self.headers = headers
        }

        /// Creates a new mailto URI
        ///
        /// - Parameters:
        ///   - to: The recipient email addresses
        ///   - headers: Optional header fields (subject, body, cc, etc.)
        public init(
            to: [RFC_5322.EmailAddress] = [],
            headers: [Header] = []
        ) {
            self.init(__unchecked: (), to: to, headers: headers)
        }
    }
}

// MARK: - Convenience Accessors

extension RFC_6068.Mailto {
    /// The subject header value, if present
    public var subject: String? {
        headers.first { $0.name.lowercased() == "subject" }?.value
    }

    /// The body header value, if present
    public var body: String? {
        headers.first { $0.name.lowercased() == "body" }?.value
    }

    /// Additional To addresses from headers (combined with path To addresses)
    public var allTo: [RFC_5322.EmailAddress] {
        var result = to
        for header in headers where header.name.lowercased() == "to" {
            if let addr = try? RFC_5322.EmailAddress(header.value) {
                result.append(addr)
            }
        }
        return result
    }

    /// Cc addresses from headers
    public var cc: [RFC_5322.EmailAddress] {
        headers
            .filter { $0.name.lowercased() == "cc" }
            .compactMap { try? RFC_5322.EmailAddress($0.value) }
    }

    /// Bcc addresses from headers
    public var bcc: [RFC_5322.EmailAddress] {
        headers
            .filter { $0.name.lowercased() == "bcc" }
            .compactMap { try? RFC_5322.EmailAddress($0.value) }
    }
}

// MARK: - UInt8.ASCII.Serializable

extension RFC_6068.Mailto: UInt8.ASCII.Serializable {
    public static let serialize: @Sendable (Self) -> [UInt8] = [UInt8].init

    /// Parses a mailto URI from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 6068 Section 2
    ///
    /// ```
    /// mailtoURI = "mailto:" [ to ] [ hfields ]
    /// ```
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [UInt8] (ASCII bytes)
    /// - **Codomain**: RFC_6068.Mailto (structured data)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let mailto = try RFC_6068.Mailto(ascii: "mailto:user@example.com".utf8)
    /// ```
    ///
    /// - Parameter bytes: The mailto URI as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == UInt8 {
        let byteArray = Array(bytes)
        guard !byteArray.isEmpty else { throw Error.empty }

        // Check for "mailto:" scheme (case-insensitive)
        let scheme = Array("mailto:".utf8)
        guard byteArray.count >= scheme.count else {
            throw Error.missingScheme(String(decoding: byteArray, as: UTF8.self))
        }

        let schemeBytes = Array(byteArray.prefix(scheme.count))
        let schemeString = String(decoding: schemeBytes, as: UTF8.self).lowercased()
        guard schemeString == "mailto:" else {
            throw Error.missingScheme(String(decoding: byteArray, as: UTF8.self))
        }

        // Split remaining into path (to) and query (hfields)
        let remainder = Array(byteArray.dropFirst(scheme.count))

        var pathBytes: [UInt8] = []
        var queryBytes: [UInt8] = []
        var inQuery = false

        for byte in remainder {
            if byte == UInt8.ascii.questionMark && !inQuery {
                inQuery = true
            } else if inQuery {
                queryBytes.append(byte)
            } else {
                pathBytes.append(byte)
            }
        }

        // Parse To addresses from path (comma-separated, percent-encoded)
        var toAddresses: [RFC_5322.EmailAddress] = []
        if !pathBytes.isEmpty {
            let decodedPath = RFC_6068.Mailto.percentDecode(pathBytes)

            // Split on commas using byte-level parsing
            var addressStrings: [String] = []
            var current: [UInt8] = []
            for byte in decodedPath {
                if byte == UInt8.ascii.comma {
                    if !current.isEmpty {
                        addressStrings.append(String(decoding: current, as: UTF8.self))
                        current = []
                    }
                } else {
                    current.append(byte)
                }
            }
            if !current.isEmpty {
                addressStrings.append(String(decoding: current, as: UTF8.self))
            }

            for addrStr in addressStrings {
                // Trim whitespace at byte level
                var trimmed = Array(addrStr.utf8)
                while !trimmed.isEmpty && (trimmed.first == UInt8.ascii.space || trimmed.first == UInt8.ascii.htab) {
                    trimmed.removeFirst()
                }
                while !trimmed.isEmpty && (trimmed.last == UInt8.ascii.space || trimmed.last == UInt8.ascii.htab) {
                    trimmed.removeLast()
                }
                if !trimmed.isEmpty {
                    let trimmedStr = String(decoding: trimmed, as: UTF8.self)
                    if let addr = try? RFC_5322.EmailAddress(trimmedStr) {
                        toAddresses.append(addr)
                    }
                }
            }
        }

        // Parse headers from query
        var headers: [Header] = []
        if !queryBytes.isEmpty {
            // Split on & to get individual hfields
            var currentField: [UInt8] = []
            for byte in queryBytes {
                if byte == UInt8.ascii.ampersand {
                    if !currentField.isEmpty {
                        if let header = try? Header(ascii: currentField) {
                            headers.append(header)
                        }
                        currentField = []
                    }
                } else {
                    currentField.append(byte)
                }
            }
            // Handle last field
            if !currentField.isEmpty {
                if let header = try? Header(ascii: currentField) {
                    headers.append(header)
                }
            }
        }

        self.init(__unchecked: (), to: toAddresses, headers: headers)
    }

    /// Percent-decodes a byte sequence per RFC 3986
    static func percentDecode(_ bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count)

        var i = bytes.startIndex
        while i < bytes.endIndex {
            if bytes[i] == UInt8.ascii.percentSign && i + 2 < bytes.endIndex {
                let hi = bytes[i + 1]
                let lo = bytes[i + 2]
                if let value = hexValue(hi: hi, lo: lo) {
                    result.append(value)
                    i += 3
                    continue
                }
            }
            result.append(bytes[i])
            i += 1
        }
        return result
    }

    /// Converts two hex digit bytes to a value
    private static func hexValue(hi: UInt8, lo: UInt8) -> UInt8? {
        guard let hiVal = hexDigitValue(hi), let loVal = hexDigitValue(lo) else {
            return nil
        }
        return (hiVal << 4) | loVal
    }

    private static func hexDigitValue(_ byte: UInt8) -> UInt8? {
        if byte >= UInt8.ascii.`0` && byte <= UInt8.ascii.`9` {
            return byte - UInt8.ascii.`0`
        } else if byte >= UInt8.ascii.A && byte <= UInt8.ascii.F {
            return byte - UInt8.ascii.A + 10
        } else if byte >= UInt8.ascii.a && byte <= UInt8.ascii.f {
            return byte - UInt8.ascii.a + 10
        }
        return nil
    }
}

// MARK: - Protocol Conformances

extension RFC_6068.Mailto: UInt8.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_6068.Mailto: CustomStringConvertible {
    public var description: String {
        String(self)
    }
}

extension RFC_6068.Mailto: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(to)
        hasher.combine(headers)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.to == rhs.to && lhs.headers == rhs.headers
    }
}

// MARK: - [UInt8] Conversion

extension [UInt8] {
    /// Creates ASCII bytes from RFC 6068 Mailto URI
    ///
    /// ## Category Theory
    ///
    /// Serialization (natural transformation):
    /// - **Domain**: RFC_6068.Mailto (structured data)
    /// - **Codomain**: [UInt8] (ASCII bytes)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let mailto = RFC_6068.Mailto(to: [addr], headers: [.subject("Hello")])
    /// let bytes = [UInt8](mailto)  // "mailto:user@example.com?subject=Hello"
    /// ```
    ///
    /// - Parameter mailto: The mailto URI to serialize
    public init(_ mailto: RFC_6068.Mailto) {
        self = []

        // Scheme
        self.append(contentsOf: "mailto:".utf8)

        // To addresses (percent-encoded, comma-separated)
        for (index, addr) in mailto.to.enumerated() {
            if index > 0 {
                self.append(UInt8.ascii.comma)
            }
            self.append(contentsOf: RFC_6068.Mailto.percentEncode(Array(addr.rawValue.utf8)))
        }

        // Headers
        if !mailto.headers.isEmpty {
            self.append(UInt8.ascii.questionMark)
            for (index, header) in mailto.headers.enumerated() {
                if index > 0 {
                    self.append(UInt8.ascii.ampersand)
                }
                self.append(contentsOf: [UInt8](header))
            }
        }
    }
}

// MARK: - Percent Encoding

extension RFC_6068.Mailto {
    /// Characters that are safe in mailto URI path (addr-spec)
    /// Per RFC 6068 Section 2, we need to encode characters not allowed in addr-spec
    static func percentEncode(_ bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count * 3) // worst case

        for byte in bytes {
            if isUnreservedOrAllowed(byte) {
                result.append(byte)
            } else {
                result.append(UInt8.ascii.percentSign)
                result.append(hexDigit(byte >> 4))
                result.append(hexDigit(byte & 0x0F))
            }
        }
        return result
    }

    /// Percent-encodes for header values (more restrictive)
    static func percentEncodeHeaderValue(_ bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count * 3)

        for byte in bytes {
            if isQchar(byte) {
                result.append(byte)
            } else {
                result.append(UInt8.ascii.percentSign)
                result.append(hexDigit(byte >> 4))
                result.append(hexDigit(byte & 0x0F))
            }
        }
        return result
    }

    /// RFC 6068 qchar = unreserved / pct-encoded / some-delims
    /// some-delims = "!" / "$" / "'" / "(" / ")" / "*" / "+" / "," / ";" / ":" / "@"
    private static func isQchar(_ byte: UInt8) -> Bool {
        isUnreserved(byte) || isSomeDelims(byte)
    }

    /// RFC 3986 unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
    private static func isUnreserved(_ byte: UInt8) -> Bool {
        byte.ascii.isAlphanumeric ||
            byte == UInt8.ascii.hyphen ||
            byte == UInt8.ascii.period ||
            byte == UInt8.ascii.underline ||
            byte == UInt8.ascii.tilde
    }

    /// Characters allowed in addr-spec that don't need encoding
    private static func isUnreservedOrAllowed(_ byte: UInt8) -> Bool {
        isUnreserved(byte) ||
            byte == UInt8.ascii.atSign ||
            byte == UInt8.ascii.period
    }

    /// RFC 6068 some-delims
    private static func isSomeDelims(_ byte: UInt8) -> Bool {
        byte == UInt8.ascii.exclamationPoint ||
            byte == UInt8.ascii.dollarSign ||
            byte == UInt8.ascii.apostrophe ||
            byte == UInt8.ascii.leftParenthesis ||
            byte == UInt8.ascii.rightParenthesis ||
            byte == UInt8.ascii.asterisk ||
            byte == UInt8.ascii.plusSign ||
            byte == UInt8.ascii.comma ||
            byte == UInt8.ascii.semicolon ||
            byte == UInt8.ascii.colon ||
            byte == UInt8.ascii.atSign
    }

    private static func hexDigit(_ nibble: UInt8) -> UInt8 {
        if nibble < 10 {
            return UInt8.ascii.`0` + nibble
        } else {
            return UInt8.ascii.A + nibble - 10
        }
    }
}

// MARK: - StringProtocol Conversion

extension StringProtocol {
    /// Create a string from an RFC 6068 Mailto URI
    ///
    /// - Parameter mailto: The mailto URI to convert
    public init(_ mailto: RFC_6068.Mailto) {
        self = Self(decoding: mailto.bytes, as: UTF8.self)
    }
}
