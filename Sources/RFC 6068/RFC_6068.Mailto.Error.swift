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

extension RFC_6068.Mailto {
    /// Errors during mailto URI parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingScheme(_ value: String)
        case invalidEmailAddress(_ value: String)
        case invalidHeader(_ value: String)
        case invalidPercentEncoding(_ value: String)

        public var description: String {
            switch self {
            case .empty:
                return "mailto URI cannot be empty"
            case .missingScheme(let value):
                return "mailto URI must start with 'mailto:': '\(value)'"
            case .invalidEmailAddress(let value):
                return "Invalid email address in mailto URI: '\(value)'"
            case .invalidHeader(let value):
                return "Invalid header in mailto URI: '\(value)'"
            case .invalidPercentEncoding(let value):
                return "Invalid percent encoding in mailto URI: '\(value)'"
            }
        }
    }
}
