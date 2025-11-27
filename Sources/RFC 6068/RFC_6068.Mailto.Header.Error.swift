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

extension RFC_6068.Mailto.Header {
    /// Errors during header parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingEquals(_ value: String)
        case emptyName(_ value: String)
        case invalidPercentEncoding(_ value: String)

        public var description: String {
            switch self {
            case .empty:
                return "Header field cannot be empty"
            case .missingEquals(let value):
                return "Header field must contain '=': '\(value)'"
            case .emptyName(let value):
                return "Header field name cannot be empty: '\(value)'"
            case .invalidPercentEncoding(let value):
                return "Invalid percent encoding in header: '\(value)'"
            }
        }
    }
}
