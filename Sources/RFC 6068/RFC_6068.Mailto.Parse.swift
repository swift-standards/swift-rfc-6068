//
//  RFC_6068.Mailto.Parse.swift
//  swift-rfc-6068
//
//  Mailto URI: "mailto:" [to] ["?" hfields]
//

public import Parser_Primitives

extension RFC_6068.Mailto {
    /// Parses a mailto URI per RFC 6068 Section 2.
    ///
    /// `mailtoURI = "mailto:" [ to ] [ hfields ]`
    /// `to        = addr-spec *("," addr-spec)`
    /// `hfields   = "?" hfield *("&" hfield)`
    /// `hfield    = hfname "=" hfvalue`
    ///
    /// Returns the raw path (addresses) and query (headers) byte slices.
    /// Percent-decoding and addr-spec parsing are left to the caller.
    public struct Parse<Input: Collection.Slice.`Protocol`>: Sendable
    where Input: Sendable, Input.Element == UInt8 {
        @inlinable
        public init() {}
    }
}

extension RFC_6068.Mailto.Parse {
    public struct HeaderField: Sendable {
        public let name: Input
        public let value: Input

        @inlinable
        public init(name: Input, value: Input) {
            self.name = name
            self.value = value
        }
    }

    public struct Output: Sendable {
        /// Raw address segments (comma-separated in the path component)
        public let addresses: [Input]
        /// Parsed header fields from the query component
        public let headers: [HeaderField]

        @inlinable
        public init(addresses: [Input], headers: [HeaderField]) {
            self.addresses = addresses
            self.headers = headers
        }
    }

    public enum Error: Swift.Error, Sendable, Equatable {
        case expectedMailtoScheme
    }
}

extension RFC_6068.Mailto.Parse: Parser.`Protocol` {
    public typealias ParseOutput = Output
    public typealias Failure = RFC_6068.Mailto.Parse<Input>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Case-insensitive match for "mailto:" (7 bytes)
        try Self._expectScheme(&input)

        // Split remaining at '?' into path and query
        var pathEnd = input.startIndex
        var questionMark: Input.Index? = nil
        var idx = input.startIndex
        while idx < input.endIndex {
            if input[idx] == 0x3F {  // ?
                questionMark = idx
                break
            }
            input.formIndex(after: &idx)
        }
        pathEnd = questionMark ?? input.endIndex

        // Parse addresses from path (split on ',')
        var addresses: [Input] = []
        let pathSlice = input[input.startIndex..<pathEnd]
        if pathSlice.startIndex < pathSlice.endIndex {
            var segStart = pathSlice.startIndex
            var segIdx = pathSlice.startIndex
            while segIdx < pathSlice.endIndex {
                if pathSlice[segIdx] == 0x2C {  // ,
                    if segIdx > segStart {
                        addresses.append(pathSlice[segStart..<segIdx])
                    }
                    pathSlice.formIndex(after: &segIdx)
                    segStart = segIdx
                } else {
                    pathSlice.formIndex(after: &segIdx)
                }
            }
            if segIdx > segStart {
                addresses.append(pathSlice[segStart..<segIdx])
            }
        }

        // Parse headers from query (split on '&', then '=')
        var headers: [HeaderField] = []
        if let qm = questionMark {
            let queryStart = input.index(after: qm)
            let querySlice = input[queryStart..<input.endIndex]

            var fieldStart = querySlice.startIndex
            var fieldIdx = querySlice.startIndex
            while fieldIdx <= querySlice.endIndex {
                let atEnd = fieldIdx == querySlice.endIndex
                let atAmpersand = !atEnd && querySlice[fieldIdx] == 0x26  // &

                if atEnd || atAmpersand {
                    let fieldSlice = querySlice[fieldStart..<fieldIdx]
                    // Split field at '='
                    var eqIdx = fieldSlice.startIndex
                    while eqIdx < fieldSlice.endIndex && fieldSlice[eqIdx] != 0x3D {
                        fieldSlice.formIndex(after: &eqIdx)
                    }
                    if eqIdx < fieldSlice.endIndex {
                        let name = fieldSlice[fieldSlice.startIndex..<eqIdx]
                        let valueStart = fieldSlice.index(after: eqIdx)
                        let value = fieldSlice[valueStart..<fieldSlice.endIndex]
                        headers.append(HeaderField(name: name, value: value))
                    }
                    if atAmpersand {
                        querySlice.formIndex(after: &fieldIdx)
                    }
                    fieldStart = fieldIdx
                }
                if !atEnd { querySlice.formIndex(after: &fieldIdx) }
                if atEnd { break }
            }
        }

        input = input[input.endIndex...]
        return Output(addresses: addresses, headers: headers)
    }

    @inlinable
    static func _expectScheme(_ input: inout Input) throws(Failure) {
        // "mailto:" — 7 bytes, case-insensitive
        let expected: [UInt8] = [0x6D, 0x61, 0x69, 0x6C, 0x74, 0x6F, 0x3A]
        var idx = input.startIndex
        for exp in expected {
            guard idx < input.endIndex else { throw .expectedMailtoScheme }
            let byte = input[idx]
            // Case-insensitive for letters (0x3A is colon, not a letter)
            let lower = (byte >= 0x41 && byte <= 0x5A) ? (byte | 0x20) : byte
            guard lower == exp else { throw .expectedMailtoScheme }
            input.formIndex(after: &idx)
        }
        input = input[idx...]
    }
}
