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
        ///
        /// Private to ensure all public construction goes through validation.
        private init(
            __unchecked: Void,
            name: String,
            value: String
        ) {
            self.name = name
            self.value = value
        }

        /// Creates a header field
        ///
        /// - Parameters:
        ///   - name: The header field name (e.g., "subject", "body")
        ///   - value: The header field value
        /// - Throws: `Error.emptyName` if the name is empty
        public init(name: String, value: String) throws(Error) {
            guard !name.isEmpty else {
                throw Error.emptyName("name cannot be empty")
            }
            self.init(
                __unchecked: (),
                name: name,
                value: value
            )
        }
    }
}

// MARK: - Common Headers

extension RFC_6068.Mailto.Header {
    /// Creates a Subject header
    public static func subject(
        _ value: String
    ) throws(Error) -> Self {
        try Self(name: "subject", value: value)
    }

    /// Creates a Body header
    public static func body(
        _ value: String
    ) throws(Error) -> Self {
        try Self(name: "body", value: value)
    }

    /// Creates a Cc header
    public static func cc(
        _ value: String
    ) throws(Error) -> Self {
        try Self(name: "cc", value: value)
    }

    /// Creates a Bcc header
    public static func bcc(
        _ value: String
    ) throws(Error) -> Self {
        try Self(name: "bcc", value: value)
    }

    /// Creates a To header (additional recipients beyond path)
    public static func to(
        _ value: String
    ) throws(Error) -> Self {
        try Self(name: "to", value: value)
    }

    /// Creates an In-Reply-To header
    public static func inReplyTo(
        _ value: String
    ) throws(Error) -> Self {
        try Self(name: "in-reply-to", value: value)
    }
}

// MARK: - Binary.ASCII.Serializable

extension RFC_6068.Mailto.Header: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii header: RFC_6068.Mailto.Header,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == UInt8 {

        // Percent-encode name
        buffer.append(
            contentsOf: RFC_3986.percentEncode(Array(header.name.utf8), allowing: .mailto.qchar)
        )

        buffer.append(UInt8.ascii.equalsSign)

        // Percent-encode value
        buffer.append(
            contentsOf: RFC_3986.percentEncode(Array(header.value.utf8), allowing: .mailto.qchar)
        )
    }

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
    public init<Bytes: Collection>(
        ascii bytes: Bytes,
        in context: Void = ()
    ) throws(Error)
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
        let decodedName = RFC_3986.percentDecode(nameBytes)
        let decodedValue = RFC_3986.percentDecode(valueBytes)

        let name = String(decoding: decodedName, as: UTF8.self)
        let value = String(decoding: decodedValue, as: UTF8.self)

        try self.init(name: name, value: value)
    }
}

// MARK: - Protocol Conformances

extension RFC_6068.Mailto.Header: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_6068.Mailto.Header: CustomStringConvertible {}

extension RFC_6068.Mailto.Header: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.lowercased())
        hasher.combine(value)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name.lowercased() == rhs.name.lowercased() && lhs.value == rhs.value
    }
}
