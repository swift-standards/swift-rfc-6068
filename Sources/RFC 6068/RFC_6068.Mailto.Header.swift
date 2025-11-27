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

extension RFC_6068.Mailto {
    /// A header field in a mailto URI
    ///
    /// Per RFC 6068 Section 2:
    /// ```
    /// hfield  = hfname "=" hfvalue
    /// hfname  = *qchar
    /// hfvalue = *qchar
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let header = try RFC_6068.Mailto.Header(ascii: "subject=Hello%20World".utf8)
    /// print(header.name)   // "subject"
    /// print(header.value)  // "Hello World"
    /// ```
    public struct Header: Sendable, Codable {
        /// The header field name (e.g., "subject", "body", "cc")
        public let name: String

        /// The header field value (percent-decoded)
        public let value: String

        /// Creates a header WITHOUT validation
        init(__unchecked: Void, name: String, value: String) {
            self.name = name
            self.value = value
        }

        /// Creates a new header field
        ///
        /// - Parameters:
        ///   - name: The header field name
        ///   - value: The header field value
        public init(name: String, value: String) {
            self.init(__unchecked: (), name: name, value: value)
        }
    }
}

// MARK: - Common Headers

extension RFC_6068.Mailto.Header {
    /// Creates a Subject header
    public static func subject(_ value: String) -> Self {
        Self(__unchecked: (), name: "subject", value: value)
    }

    /// Creates a Body header
    public static func body(_ value: String) -> Self {
        Self(__unchecked: (), name: "body", value: value)
    }

    /// Creates a Cc header
    public static func cc(_ value: String) -> Self {
        Self(__unchecked: (), name: "cc", value: value)
    }

    /// Creates a Bcc header
    public static func bcc(_ value: String) -> Self {
        Self(__unchecked: (), name: "bcc", value: value)
    }

    /// Creates a To header (additional recipients beyond path)
    public static func to(_ value: String) -> Self {
        Self(__unchecked: (), name: "to", value: value)
    }

    /// Creates an In-Reply-To header
    public static func inReplyTo(_ value: String) -> Self {
        Self(__unchecked: (), name: "in-reply-to", value: value)
    }
}

// MARK: - UInt8.ASCII.Serializable

extension RFC_6068.Mailto.Header: UInt8.ASCII.Serializable {
    public static let serialize: @Sendable (Self) -> [UInt8] = [UInt8].init

    /// Parses a header field from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 6068 Section 2
    ///
    /// ```
    /// hfield  = hfname "=" hfvalue
    /// ```
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [UInt8] (ASCII bytes, percent-encoded)
    /// - **Codomain**: RFC_6068.Mailto.Header (structured data)
    ///
    /// - Parameter bytes: The header field as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == UInt8 {
        let byteArray = Array(bytes)
        guard !byteArray.isEmpty else { throw Error.empty }

        // Find the '=' separator
        guard let equalsIndex = byteArray.firstIndex(of: UInt8.ascii.equalsSign) else {
            throw Error.missingEquals(String(decoding: byteArray, as: UTF8.self))
        }

        let nameBytes = Array(byteArray[..<equalsIndex])
        let valueBytes = Array(byteArray[(equalsIndex + 1)...])

        guard !nameBytes.isEmpty else {
            throw Error.emptyName(String(decoding: byteArray, as: UTF8.self))
        }

        // Percent-decode both name and value
        let decodedName = RFC_6068.Mailto.percentDecode(nameBytes)
        let decodedValue = RFC_6068.Mailto.percentDecode(valueBytes)

        let name = String(decoding: decodedName, as: UTF8.self)
        let value = String(decoding: decodedValue, as: UTF8.self)

        self.init(__unchecked: (), name: name, value: value)
    }
}

// MARK: - Protocol Conformances

extension RFC_6068.Mailto.Header: UInt8.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_6068.Mailto.Header: CustomStringConvertible {
    public var description: String {
        String(self)
    }
}

extension RFC_6068.Mailto.Header: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.lowercased())
        hasher.combine(value)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name.lowercased() == rhs.name.lowercased() && lhs.value == rhs.value
    }
}

// MARK: - [UInt8] Conversion

extension [UInt8] {
    /// Creates ASCII bytes from RFC 6068 Mailto Header
    ///
    /// ## Category Theory
    ///
    /// Serialization (natural transformation):
    /// - **Domain**: RFC_6068.Mailto.Header (structured data)
    /// - **Codomain**: [UInt8] (ASCII bytes, percent-encoded)
    ///
    /// - Parameter header: The header to serialize
    public init(_ header: RFC_6068.Mailto.Header) {
        self = []

        // Percent-encode name
        self.append(contentsOf: RFC_6068.Mailto.percentEncodeHeaderValue(Array(header.name.utf8)))

        self.append(UInt8.ascii.equalsSign)

        // Percent-encode value
        self.append(contentsOf: RFC_6068.Mailto.percentEncodeHeaderValue(Array(header.value.utf8)))
    }
}

// MARK: - StringProtocol Conversion

extension StringProtocol {
    /// Create a string from an RFC 6068 Mailto Header
    ///
    /// - Parameter header: The header to convert
    public init(_ header: RFC_6068.Mailto.Header) {
        self = Self(decoding: header.bytes, as: UTF8.self)
    }
}
