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

/// Encodes Codable values directly into XPC objects.
///
/// Keyed containers become dictionaries and unkeyed containers become arrays.
/// Scalars use their native XPC types, including `Date`, `Data`, and `UUID`.
/// Integers preserve signedness; dates use rounded Unix-epoch nanoseconds.
/// Values outside XPC's range and strings or keys containing NUL throw
/// `EncodingError.invalidValue` with the affected coding path.
public struct XPCObjectEncoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> xpc_object_t {
        let node = XPCEncodingNode(codingPath: [])
        try XPCValueEncoder(node: node, userInfo: userInfo).encode(value)
        return try node.object()
    }
}

private final class XPCEncodingNode {
    enum Storage {
        case unset
        case value(xpc_object_t)
        case keyed(KeyedStorage)
        case unkeyed(UnkeyedStorage)
    }

    final class KeyedStorage {
        var children: [String: XPCEncodingNode] = [:]
    }

    final class UnkeyedStorage {
        var children: [XPCEncodingNode] = []
    }

    let codingPath: [CodingKey]
    var storage: Storage = .unset

    init(codingPath: [CodingKey]) {
        self.codingPath = codingPath
    }

    func prepareKeyed() {
        if case .unset = storage { storage = .keyed(KeyedStorage()) }
        guard case .keyed = storage else { preconditionFailure("Conflicting encoding containers") }
    }

    func prepareUnkeyed() {
        if case .unset = storage { storage = .unkeyed(UnkeyedStorage()) }
        guard case .unkeyed = storage else { preconditionFailure("Conflicting encoding containers") }
    }

    func set(_ child: XPCEncodingNode, forKey key: CodingKey) {
        guard case .keyed(let keyed) = storage else { preconditionFailure("Expected a keyed container") }
        keyed.children[key.stringValue] = child
    }

    func child(forKey key: CodingKey) -> XPCEncodingNode {
        guard case .keyed(let keyed) = storage else { preconditionFailure("Expected a keyed container") }
        if let child = keyed.children[key.stringValue] { return child }
        let child = XPCEncodingNode(codingPath: codingPath + [key])
        set(child, forKey: key)
        return child
    }

    var count: Int {
        guard case .unkeyed(let unkeyed) = storage else { preconditionFailure("Expected an unkeyed container") }
        return unkeyed.children.count
    }

    func append(_ child: XPCEncodingNode) {
        guard case .unkeyed(let unkeyed) = storage else { preconditionFailure("Expected an unkeyed container") }
        unkeyed.children.append(child)
    }

    func object() throws -> xpc_object_t {
        switch storage {
        case .unset: return xpc_dictionary_create(nil, nil, 0)
        case .value(let object): return object
        case .keyed(let keyed): return try dictionary(keyed.children)
        case .unkeyed(let unkeyed):
            let array = xpc_array_create(nil, 0)
            for child in unkeyed.children { xpc_array_append_value(array, try child.object()) }
            return array
        }
    }

    private func dictionary(_ children: [String: XPCEncodingNode]) throws -> xpc_object_t {
        let dictionary = xpc_dictionary_create(nil, nil, 0)
        for (key, child) in children {
            guard !key.utf8.contains(0) else {
                throw EncodingError.invalidValue(key, .init(
                    codingPath: child.codingPath,
                    debugDescription: "XPC dictionary keys cannot contain NUL"
                ))
            }
            xpc_dictionary_set_value(dictionary, key, try child.object())
        }
        return dictionary
    }
}

private struct XPCValueEncoder: Encoder {
    let node: XPCEncodingNode
    let userInfo: [CodingUserInfoKey: Any]
    var codingPath: [CodingKey] { node.codingPath }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        node.prepareKeyed()
        return KeyedEncodingContainer(XPCKeyedEncodingContainer<Key>(encoder: self))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        node.prepareUnkeyed()
        return XPCUnkeyedEncodingContainer(encoder: self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        XPCSingleValueEncodingContainer(encoder: self)
    }

    func encode<T: Encodable>(_ value: T) throws {
        switch value {
        case let value as Bool: try scalar(value)
        case let value as any BinaryInteger: try scalar(value)
        case let value as any BinaryFloatingPoint: try scalar(value)
        case let value as String: try scalar(value)
        case let value as Date: try scalar(value)
        case let value as Data: try scalar(value)
        case let value as UUID: try scalar(value)
        default: try value.encode(to: self)
        }
    }

    func scalar(_ value: Any) throws {
        precondition(isUnset, "A single-value container can only encode one value")
        do {
            node.storage = .value(try xpc_from_swift(value))
        } catch {
            throw EncodingError.invalidValue(value, .init(
                codingPath: codingPath,
                debugDescription: "Value cannot be represented as an XPC object",
                underlyingError: error
            ))
        }
    }

    private var isUnset: Bool {
        if case .unset = node.storage { return true }
        return false
    }

    func referencing(_ child: XPCEncodingNode) -> Self {
        Self(node: child, userInfo: userInfo)
    }
}

private struct XPCKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: XPCValueEncoder
    var codingPath: [CodingKey] { encoder.codingPath }

    mutating func encodeNil(forKey key: Key) throws {
        let child = XPCEncodingNode(codingPath: codingPath + [key])
        try encoder.referencing(child).scalar(NSNull())
        encoder.node.set(child, forKey: key)
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let child = XPCEncodingNode(codingPath: codingPath + [key])
        try encoder.referencing(child).encode(value)
        encoder.node.set(child, forKey: key)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        encoder.referencing(encoder.node.child(forKey: key)).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        encoder.referencing(encoder.node.child(forKey: key)).unkeyedContainer()
    }

    mutating func superEncoder() -> Encoder {
        encoder.referencing(encoder.node.child(forKey: XPCEncodingKey.super))
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        encoder.referencing(encoder.node.child(forKey: key))
    }
}

private struct XPCUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: XPCValueEncoder
    var codingPath: [CodingKey] { encoder.codingPath }
    var count: Int { encoder.node.count }

    mutating func encodeNil() throws {
        let child = nextNode()
        try encoder.referencing(child).scalar(NSNull())
        encoder.node.append(child)
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let child = nextNode()
        try encoder.referencing(child).encode(value)
        encoder.node.append(child)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        let child = nextNode()
        encoder.node.append(child)
        return encoder.referencing(child).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let child = nextNode()
        encoder.node.append(child)
        return encoder.referencing(child).unkeyedContainer()
    }

    mutating func superEncoder() -> Encoder {
        let child = nextNode()
        encoder.node.append(child)
        return encoder.referencing(child)
    }

    private func nextNode() -> XPCEncodingNode {
        XPCEncodingNode(codingPath: codingPath + [XPCEncodingKey(index: count)])
    }
}

private struct XPCSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: XPCValueEncoder
    var codingPath: [CodingKey] { encoder.codingPath }

    mutating func encodeNil() throws {
        try encoder.scalar(NSNull())
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        try encoder.encode(value)
    }
}

private struct XPCEncodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    static var `super`: Self { Self(stringValue: "super") }

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init(intValue: Int) {
        self.init(index: intValue)
    }

    init(index: Int) {
        stringValue = "Index \(index)"
        intValue = index
    }
}
