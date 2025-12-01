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
        ///
        /// Private to ensure all public construction goes through validation.
        private init(
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
        /// - Throws: `Error` if validation fails
        public init(
            to: [RFC_5322.EmailAddress] = [],
            headers: [Header] = []
        ) throws(Error) {
            // Validation: must have at least one recipient or one header
            // (empty mailto: is technically valid per RFC 6068, so no validation needed currently)
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
    static public func serialize<Buffer>(
        ascii mailto: RFC_6068.Mailto,
        into buffer: inout Buffer
    ) where Buffer : RangeReplaceableCollection, Buffer.Element == UInt8 {
        // Scheme
        buffer.append(contentsOf: "mailto:".utf8)

        // To addresses (percent-encoded, comma-separated)
        for (index, addr) in mailto.to.enumerated() {
            if index > 0 {
                buffer.append(UInt8.ascii.comma)
            }
            buffer.append(contentsOf: RFC_6068.Mailto.percentEncode(Array(addr.rawValue.utf8)))
        }

        // Headers
        if !mailto.headers.isEmpty {
            buffer.append(UInt8.ascii.questionMark)
            for (index, header) in mailto.headers.enumerated() {
                if index > 0 {
                    buffer.append(UInt8.ascii.ampersand)
                }
                buffer.append(contentsOf: [UInt8](header))
            }
        }
    }

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

        // Validate and strip scheme
        let scheme = Array("mailto:".utf8)
        guard byteArray.count >= scheme.count else {
            throw Error.missingScheme(String(decoding: byteArray, as: UTF8.self))
        }
        let schemeString = String(decoding: byteArray.prefix(scheme.count), as: UTF8.self).lowercased()
        guard schemeString == "mailto:" else {
            throw Error.missingScheme(String(decoding: byteArray, as: UTF8.self))
        }
        let remainder = Array(byteArray.dropFirst(scheme.count))

        // Split into path and query components
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

        // Parse To addresses from path
        var toAddresses: [RFC_5322.EmailAddress] = []
        if !pathBytes.isEmpty {
            let decodedPath = RFC_3986.percentDecode(pathBytes)

            // Split on comma
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
                // Trim whitespace
                var trimmed = Array(addrStr.utf8)
                while !trimmed.isEmpty
                    && (trimmed.first == UInt8.ascii.space || trimmed.first == UInt8.ascii.htab)
                {
                    trimmed.removeFirst()
                }
                while !trimmed.isEmpty
                    && (trimmed.last == UInt8.ascii.space || trimmed.last == UInt8.ascii.htab)
                {
                    trimmed.removeLast()
                }
                guard !trimmed.isEmpty else { continue }
                if let addr = try? RFC_5322.EmailAddress(String(decoding: trimmed, as: UTF8.self)) {
                    toAddresses.append(addr)
                }
            }
        }

        // Parse headers from query
        var headers: [Header] = []
        if !queryBytes.isEmpty {
            // Split on ampersand
            var headerFields: [[UInt8]] = []
            var currentField: [UInt8] = []
            for byte in queryBytes {
                if byte == UInt8.ascii.ampersand {
                    if !currentField.isEmpty {
                        headerFields.append(currentField)
                        currentField = []
                    }
                } else {
                    currentField.append(byte)
                }
            }
            if !currentField.isEmpty {
                headerFields.append(currentField)
            }

            for fieldBytes in headerFields {
                if let header = try? Header(ascii: fieldBytes) {
                    headers.append(header)
                }
            }
        }

        try self.init(to: toAddresses, headers: headers)
    }
}

// MARK: - Protocol Conformances

extension RFC_6068.Mailto: UInt8.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_6068.Mailto: CustomStringConvertible {}

extension RFC_6068.Mailto: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(to)
        hasher.combine(headers)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.to == rhs.to && lhs.headers == rhs.headers
    }
}

// MARK: - RFC 6068 ByteSets

extension RFC_3986.ByteSet {
    /// RFC 6068 character sets namespace
    public enum Mailto {
        /// RFC 6068 some-delims: `! $ ' ( ) * + , ; : @`
        ///
        /// Per RFC 6068 Section 2:
        /// ```
        /// some-delims = "!" / "$" / "'" / "(" / ")" / "*"
        ///             / "+" / "," / ";" / ":" / "@"
        /// ```
        ///
        /// This is a subset of RFC 3986 sub-delims that excludes `&` and `=`
        /// because those are delimiters in mailto URI query strings.
        public static let someDelims = RFC_3986.ByteSet(
            ascii: "!$'()*+,;:@"
        )

        /// RFC 6068 qchar = unreserved / pct-encoded / some-delims
        ///
        /// Per RFC 6068 Section 2:
        /// ```
        /// qchar = unreserved / pct-encoded / some-delims
        /// ```
        ///
        /// Characters allowed in mailto header field names and values.
        /// Excludes `&` and `=` which are query string delimiters.
        public static let qchar = RFC_3986.ByteSet.unreserved.union(someDelims)

        /// Characters allowed in mailto addr-spec path
        ///
        /// Per RFC 6068, the path component contains addr-spec values which
        /// need unreserved characters plus `@` and `.` unencoded.
        public static let addrSpec = RFC_3986.ByteSet.unreserved.union(RFC_3986.ByteSet(ascii: "@."))
    }

    /// RFC 6068 character sets
    public static var mailto: Mailto.Type { Mailto.self }
}

// MARK: - Percent Encoding

extension RFC_6068.Mailto {
    /// Percent-encodes bytes for mailto URI path (addr-spec)
    ///
    /// Per RFC 6068 Section 2, characters not allowed in addr-spec must be encoded.
    static func percentEncode<Bytes: Collection>(
        _ bytes: Bytes
    ) -> [UInt8] where Bytes.Element == UInt8 {
        RFC_3986.percentEncode(bytes, allowing: .mailto.addrSpec)
    }
}
