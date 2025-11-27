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

/// RFC 6068: The 'mailto' URI Scheme
///
/// This module provides Swift types for RFC 6068 compliant mailto URIs.
/// RFC 6068 obsoletes RFC 2368 and defines the mailto URI scheme with
/// support for Internationalized Resource Identifiers (IRIs).
///
/// ## Overview
///
/// The mailto URI scheme is used to designate email addresses. It can include:
/// - One or more recipient addresses (To)
/// - Header fields (Subject, Cc, Bcc, Body, etc.)
/// - Percent-encoded UTF-8 for internationalization
///
/// ## Key Types
///
/// - ``Mailto``: A complete mailto URI
/// - ``Mailto/Header``: A header field name-value pair
///
/// ## Example
///
/// ```swift
/// // Parse a mailto URI
/// let mailto = try RFC_6068.Mailto(ascii: "mailto:user@example.com?subject=Hello".utf8)
///
/// // Create a mailto URI programmatically
/// let mailto = RFC_6068.Mailto(
///     to: [try RFC_5322.EmailAddress("user@example.com")],
///     headers: [.subject("Hello World")]
/// )
/// ```
///
/// ## RFC Reference
///
/// - [RFC 6068](https://www.rfc-editor.org/rfc/rfc6068)
/// - Obsoletes: RFC 2368
/// - References: RFC 3986 (URI), RFC 3987 (IRI), RFC 5322 (Message Format)
public enum RFC_6068 {}
