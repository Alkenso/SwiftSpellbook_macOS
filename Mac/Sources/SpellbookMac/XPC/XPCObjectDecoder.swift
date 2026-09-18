//  MIT License
//
//  Copyright (c) 2026 Alkenso (Vladimir Vashurkin)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import XPC

/// Decodes `Codable` values directly from XPC objects.
///
/// XPC dates, data, and UUIDs decode as native `Date`, `Data`, and `UUID` values.
/// Integers must fit the requested Swift type; XPC doubles and integers can
/// decode as floating-point values. Invalid types and values throw
/// `DecodingError` with the path of the value being decoded.
public struct XPCObjectDecoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    public func decode<T: Decodable>(_ type: T.Type, from object: xpc_object_t) throws -> T {
        try XPCValueDecoder(object: object, codingPath: [], userInfo: userInfo).decode(type)
    }
}

private struct XPCCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = "Index \(intValue)"
        self.intValue = intValue
    }
}

private struct XPCValueDecoder: Decoder {
    let object: xpc_object_t
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        if xpc_get_type(object) == XPC_TYPE_NULL { throw missingValue([String: Any].self) }
        guard xpc_get_type(object) == XPC_TYPE_DICTIONARY else {
            throw mismatch([String: Any].self)
        }
        return KeyedDecodingContainer(XPCKeyedContainer(decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        if xpc_get_type(object) == XPC_TYPE_NULL { throw missingValue([Any].self) }
        guard xpc_get_type(object) == XPC_TYPE_ARRAY else {
            throw mismatch([Any].self)
        }
        return XPCUnkeyedContainer(decoder: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer { self }

    func child(_ object: xpc_object_t, at key: CodingKey) -> XPCValueDecoder {
        XPCValueDecoder(object: object, codingPath: codingPath + [key], userInfo: userInfo)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if type == Date.self || type == Data.self || type == UUID.self {
            if xpc_get_type(object) == XPC_TYPE_NULL { throw missingValue(type) }
            let expectedType = type == Date.self ? XPC_TYPE_DATE : type == Data.self ? XPC_TYPE_DATA : XPC_TYPE_UUID
            guard xpc_get_type(object) == expectedType, let value = xpc_to_swift(object) as? T else {
                throw mismatch(type)
            }
            return value
        }
        if type == Bool.self { return try decode(Bool.self) as! T }
        if type == String.self { return try decode(String.self) as! T }
        if let integerType = type as? any FixedWidthInteger.Type { return try integer(integerType) as! T }
        if let floatingType = type as? any BinaryFloatingPoint.Type { return try floating(floatingType) as! T }
        return try T(from: self)
    }

    func mismatch(_ type: Any.Type) -> DecodingError {
        .typeMismatch(type, .init(codingPath: codingPath, debugDescription: "Unexpected XPC type \(xpc_get_type(object)) for \(type)"))
    }

    func missingValue(_ type: Any.Type) -> DecodingError {
        .valueNotFound(type, .init(codingPath: codingPath, debugDescription: "Expected \(type), found XPC null"))
    }

    func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        if xpc_get_type(object) == XPC_TYPE_NULL { throw missingValue(type) }
        let value: T?
        switch xpc_get_type(object) {
        case XPC_TYPE_INT64: value = T(exactly: xpc_int64_get_value(object))
        case XPC_TYPE_UINT64: value = T(exactly: xpc_uint64_get_value(object))
        default: throw mismatch(type)
        }
        guard let value else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "XPC integer is outside the range of \(type)"))
        }
        return value
    }

    func floating<T: BinaryFloatingPoint>(_ type: T.Type) throws -> T {
        if xpc_get_type(object) == XPC_TYPE_NULL { throw missingValue(type) }
        let number: Double
        switch xpc_get_type(object) {
        case XPC_TYPE_DOUBLE: number = xpc_double_get_value(object)
        case XPC_TYPE_INT64: number = Double(xpc_int64_get_value(object))
        case XPC_TYPE_UINT64: number = Double(xpc_uint64_get_value(object))
        default: throw mismatch(type)
        }
        let value = T(number)
        guard !number.isFinite || value.isFinite else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "XPC number is outside the range of \(type)"))
        }
        return value
    }
}

extension XPCValueDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool { xpc_get_type(object) == XPC_TYPE_NULL }

    func decode(_ type: Bool.Type) throws -> Bool {
        if decodeNil() { throw missingValue(type) }
        guard xpc_get_type(object) == XPC_TYPE_BOOL else { throw mismatch(type) }
        return xpc_bool_get_value(object)
    }

    func decode(_ type: String.Type) throws -> String {
        if decodeNil() { throw missingValue(type) }
        guard xpc_get_type(object) == XPC_TYPE_STRING else { throw mismatch(type) }
        return String(cString: xpc_string_get_string_ptr(object)!)
    }

    func decode(_ type: Double.Type) throws -> Double { try floating(type) }
    func decode(_ type: Float.Type) throws -> Float { try floating(type) }
    func decode(_ type: Int.Type) throws -> Int { try integer(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try integer(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try integer(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try integer(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try integer(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try integer(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try integer(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try integer(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try integer(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try integer(type) }
}

private struct XPCKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: XPCValueDecoder
    var codingPath: [CodingKey] { decoder.codingPath }

    var allKeys: [Key] {
        var keys: [Key] = []
        xpc_dictionary_apply(decoder.object) { name, _ in
            if let key = Key(stringValue: String(cString: name)) { keys.append(key) }
            return true
        }
        return keys
    }

    func contains(_ key: Key) -> Bool {
        !key.stringValue.utf8.contains(0) && xpc_dictionary_get_value(decoder.object, key.stringValue) != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try object(forKey: key)
        return xpc_get_type(value) == XPC_TYPE_NULL
    }

    private func object(forKey key: Key) throws -> xpc_object_t {
        guard !key.stringValue.utf8.contains(0), let value = xpc_dictionary_get_value(decoder.object, key.stringValue) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing XPC dictionary key \(key.stringValue)"))
        }
        return value
    }

    private func decodeValue<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try decoder.child(object(forKey: key), at: key).decode(type)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try decodeValue(type, forKey: key) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try decodeValue(type, forKey: key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try decodeValue(type, forKey: key) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try decodeValue(type, forKey: key) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try decodeValue(type, forKey: key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try decodeValue(type, forKey: key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try decodeValue(type, forKey: key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try decodeValue(type, forKey: key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try decodeValue(type, forKey: key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try decodeValue(type, forKey: key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try decodeValue(type, forKey: key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try decodeValue(type, forKey: key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try decodeValue(type, forKey: key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try decodeValue(type, forKey: key) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T { try decodeValue(type, forKey: key) }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        try decoder.child(object(forKey: key), at: key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try decoder.child(object(forKey: key), at: key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        let key = XPCCodingKey(stringValue: "super")
        guard let value = xpc_dictionary_get_value(decoder.object, key.stringValue) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing XPC dictionary key super"))
        }
        return decoder.child(value, at: key)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        try decoder.child(object(forKey: key), at: key)
    }
}

private struct XPCUnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: XPCValueDecoder
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { xpc_array_get_count(decoder.object) }
    var isAtEnd: Bool { currentIndex >= xpc_array_get_count(decoder.object) }
    var currentIndex = 0

    private func next() throws -> XPCValueDecoder {
        let key = XPCCodingKey(intValue: currentIndex)
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(Any.self, .init(codingPath: codingPath + [key], debugDescription: "XPC array ended at index \(currentIndex)"))
        }
        return decoder.child(xpc_array_get_value(decoder.object, currentIndex), at: key)
    }

    mutating func decodeNil() throws -> Bool {
        let isNil = try next().decodeNil()
        if isNil { currentIndex += 1 }
        return isNil
    }

    private mutating func decodeValue<T: Decodable>(_ type: T.Type) throws -> T {
        let value = try next().decode(type)
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { try decodeValue(type) }
    mutating func decode(_ type: String.Type) throws -> String { try decodeValue(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try decodeValue(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try decodeValue(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try decodeValue(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try decodeValue(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try decodeValue(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try decodeValue(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try decodeValue(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try decodeValue(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try decodeValue(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try decodeValue(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try decodeValue(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try decodeValue(type) }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try decodeValue(type) }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let container = try next().container(keyedBy: type)
        currentIndex += 1
        return container
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let container = try next().unkeyedContainer()
        currentIndex += 1
        return container
    }

    mutating func superDecoder() throws -> Decoder {
        let value = try next()
        currentIndex += 1
        return value
    }
}
