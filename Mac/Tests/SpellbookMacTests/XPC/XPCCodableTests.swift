import Foundation
import SpellbookMac
import XCTest
import XPC

final class XPCCodableTests: XCTestCase {
    private struct Message: Codable, Equatable {
        enum State: String, Codable { case ready }

        let name: String
        let count: Int
        let state: State
        let values: [Int?]
        let omitted: String?
    }

    private enum Keys: String, CodingKey {
        case base, nested, array, first, second, sibling, value
    }

    func test_scalarEncodingUsesNativeXPCValues() throws {
        let encoder = XPCObjectEncoder()
        let signed = try encoder.encode(Int8(-7))
        XCTAssertEqual(xpc_get_type(signed), XPC_TYPE_INT64)
        XCTAssertEqual(xpc_int64_get_value(signed), -7)

        let unsigned = try encoder.encode(UInt64.max)
        XCTAssertEqual(xpc_get_type(unsigned), XPC_TYPE_UINT64)
        XCTAssertEqual(xpc_uint64_get_value(unsigned), .max)

        let boolean = try encoder.encode(true)
        XCTAssertEqual(xpc_get_type(boolean), XPC_TYPE_BOOL)
        XCTAssertTrue(xpc_bool_get_value(boolean))

        let floating = try encoder.encode(Float(1.25))
        XCTAssertEqual(xpc_get_type(floating), XPC_TYPE_DOUBLE)
        XCTAssertEqual(xpc_double_get_value(floating), 1.25)

        let string = try encoder.encode("Hello, 世界")
        XCTAssertEqual(xpc_get_type(string), XPC_TYPE_STRING)
        XCTAssertEqual(String(cString: xpc_string_get_string_ptr(string)!), "Hello, 世界")
    }

    func test_wideIntegersAtXPCBoundaries() throws {
        if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) {
            let signed = Int128(Int64.min)
            let unsigned = UInt128(UInt64.max)
            let signedObject = try XPCObjectEncoder().encode(signed)
            let unsignedObject = try XPCObjectEncoder().encode(unsigned)
            XCTAssertEqual(xpc_get_type(signedObject), XPC_TYPE_INT64)
            XCTAssertEqual(xpc_get_type(unsignedObject), XPC_TYPE_UINT64)
            XCTAssertEqual(try XPCObjectDecoder().decode(Int128.self, from: signedObject), signed)
            XCTAssertEqual(try XPCObjectDecoder().decode(UInt128.self, from: unsignedObject), unsigned)

            XCTAssertThrowsError(try XPCObjectEncoder().encode(UInt128(UInt64.max) + 1)) { error in
                guard case EncodingError.invalidValue = error else {
                    return XCTFail("Expected invalidValue, got \(error)")
                }
            }
        }
    }

    func test_nativeFoundationValuesAtRootAndNestedPaths() throws {
        struct Values: Codable {
            let date: Date
            let data: Data
            let uuid: UUID
        }

        let encoder = XPCObjectEncoder()
        let decoder = XPCObjectDecoder()
        let date = Date(timeIntervalSince1970: 1.5)
        let data = Data([0, 127, 255])
        let uuid = try XCTUnwrap(UUID(uuidString: "00010203-0405-0607-0809-0A0B0C0D0E0F"))
        for (object, expectedType) in [
            (try encoder.encode(date), XPC_TYPE_DATE),
            (try encoder.encode(data), XPC_TYPE_DATA),
            (try encoder.encode(uuid), XPC_TYPE_UUID)
        ] {
            XCTAssertEqual(xpc_get_type(object), expectedType)
        }
        XCTAssertEqual(xpc_date_get_value(try encoder.encode(date)), 1_500_000_000)
        XCTAssertEqual(try decoder.decode(Date.self, from: encoder.encode(date)), date)
        XCTAssertEqual(try decoder.decode(Data.self, from: encoder.encode(data)), data)
        XCTAssertEqual(try decoder.decode(UUID.self, from: encoder.encode(uuid)), uuid)

        let object = try encoder.encode(Values(date: date, data: data, uuid: uuid))
        XCTAssertEqual(xpc_get_type(try dictionaryValue(object, "date")), XPC_TYPE_DATE)
        XCTAssertEqual(xpc_get_type(try dictionaryValue(object, "data")), XPC_TYPE_DATA)
        XCTAssertEqual(xpc_get_type(try dictionaryValue(object, "uuid")), XPC_TYPE_UUID)
    }

    func test_structEnumsCollectionsAndOptionals() throws {
        let input = Message(name: "message", count: 42, state: .ready,
                            values: [1, nil, 3], omitted: nil)
        let object = try XPCObjectEncoder().encode(input)
        XCTAssertEqual(xpc_get_type(object), XPC_TYPE_DICTIONARY)
        XCTAssertEqual(xpc_get_type(try dictionaryValue(object, "state")), XPC_TYPE_STRING)
        XCTAssertNil(xpc_dictionary_get_value(object, "omitted"))
        let values = try XCTUnwrap(xpc_dictionary_get_value(object, "values"))
        XCTAssertEqual(xpc_get_type(values), XPC_TYPE_ARRAY)
        XCTAssertEqual(xpc_array_get_count(values), 3)
        XCTAssertEqual(xpc_get_type(xpc_array_get_value(values, 1)), XPC_TYPE_NULL)
        XCTAssertEqual(try XPCObjectDecoder().decode(Message.self, from: object), input)
    }

    func test_rootAndUnkeyedNilUseNullWhileKeyedNilIsOmitted() throws {
        struct OptionalValue: Codable { let value: Int? }

        let root = try XPCObjectEncoder().encode(Optional<Int>.none)
        XCTAssertEqual(xpc_get_type(root), XPC_TYPE_NULL)
        XCTAssertNil(try XPCObjectDecoder().decode(Int?.self, from: root))

        let array = try XPCObjectEncoder().encode([Int?](arrayLiteral: nil, 7))
        XCTAssertEqual(xpc_get_type(xpc_array_get_value(array, 0)), XPC_TYPE_NULL)
        XCTAssertEqual(xpc_int64_get_value(xpc_array_get_value(array, 1)), 7)
        XCTAssertEqual(try XPCObjectDecoder().decode([Int?].self, from: array), [nil, 7])

        let dictionary = try XPCObjectEncoder().encode(OptionalValue(value: nil))
        XCTAssertNil(xpc_dictionary_get_value(dictionary, "value"))
        XCTAssertNil(try XPCObjectDecoder().decode(OptionalValue.self, from: dictionary).value)
    }

    func test_emptyContainersRemainContainers() throws {
        XCTAssertEqual(xpc_get_type(try XPCObjectEncoder().encode([Int]())), XPC_TYPE_ARRAY)
        XCTAssertEqual(xpc_get_type(try XPCObjectEncoder().encode([String: Int]())), XPC_TYPE_DICTIONARY)
        XCTAssertEqual(try XPCObjectDecoder().decode([Int].self, from: xpc_array_create(nil, 0)), [])
        XCTAssertEqual(try XPCObjectDecoder().decode([String: Int].self,
                                               from: xpc_dictionary_create(nil, nil, 0)), [:])
    }

    func test_nestedDictionariesAndArraysDecodeFromNativeXPC() throws {
        let root = xpc_dictionary_create(nil, nil, 0)
        let nested = xpc_dictionary_create(nil, nil, 0)
        let items = xpc_array_create(nil, 0)
        xpc_array_append_value(items, xpc_uint64_create(.max))
        xpc_dictionary_set_value(nested, "items", items)
        xpc_dictionary_set_value(root, "nested", nested)

        struct Inner: Decodable { let items: [UInt64] }
        struct Outer: Decodable { let nested: Inner }
        XCTAssertEqual(try XPCObjectDecoder().decode(Outer.self, from: root).nested.items, [.max])
    }

    func test_explicitNestedDecodingContainersAndKeyInspection() throws {
        struct Manual: Decodable {
            let first: String
            let numbers: [Int]

            init(from decoder: Decoder) throws {
                let root = try decoder.container(keyedBy: Keys.self)
                XCTAssertTrue(root.contains(.nested))
                XCTAssertEqual(Set(root.allKeys.map(\.stringValue)), Set(["nested", "array"]))
                let nested = try root.nestedContainer(keyedBy: Keys.self, forKey: .nested)
                first = try nested.decode(String.self, forKey: .first)
                var array = try root.nestedUnkeyedContainer(forKey: .array)
                numbers = [try array.decode(Int.self), try array.decode(Int.self)]
                XCTAssertTrue(array.isAtEnd)
            }
        }

        let root = xpc_dictionary_create(nil, nil, 0)
        let nested = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(nested, "first", "value")
        xpc_dictionary_set_value(root, "nested", nested)
        let array = xpc_array_create(nil, 0)
        xpc_array_append_value(array, xpc_int64_create(1))
        xpc_array_append_value(array, xpc_int64_create(2))
        xpc_dictionary_set_value(root, "array", array)

        let result = try XPCObjectDecoder().decode(Manual.self, from: root)
        XCTAssertEqual(result.first, "value")
        XCTAssertEqual(result.numbers, [1, 2])
    }

    func test_nestedMismatchReportsFullCodingPath() throws {
        struct Inner: Decodable { let value: Int }
        struct Outer: Decodable { let items: [Inner] }
        let root = xpc_dictionary_create(nil, nil, 0)
        let array = xpc_array_create(nil, 0)
        let item = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(item, "value", "wrong")
        xpc_array_append_value(array, item)
        xpc_dictionary_set_value(root, "items", array)

        XCTAssertThrowsError(try XPCObjectDecoder().decode(Outer.self, from: root)) { error in
            guard case DecodingError.typeMismatch(_, let context) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(context.codingPath.first?.stringValue, "items")
            XCTAssertEqual(context.codingPath.dropFirst().first?.intValue, 0)
            XCTAssertEqual(context.codingPath.last?.stringValue, "value")
        }
    }

    func test_nullForNonOptionalValuesReportsValueNotFound() throws {
        struct Required: Decodable { let value: Int }
        let null = xpc_null_create()
        XCTAssertThrowsError(try XPCObjectDecoder().decode(Int.self, from: null)) { error in
            guard case DecodingError.valueNotFound(_, let context) = error else {
                return XCTFail("Expected valueNotFound, got \(error)")
            }
            XCTAssertTrue(context.codingPath.isEmpty)
        }
        XCTAssertThrowsError(try XPCObjectDecoder().decode(Date.self, from: null)) { error in
            guard case DecodingError.valueNotFound(_, let context) = error else {
                return XCTFail("Expected valueNotFound, got \(error)")
            }
            XCTAssertTrue(context.codingPath.isEmpty)
        }

        let array = xpc_array_create(nil, 0)
        xpc_array_append_value(array, null)
        XCTAssertThrowsError(try XPCObjectDecoder().decode([Int].self, from: array)) { error in
            guard case DecodingError.valueNotFound(_, let context) = error else {
                return XCTFail("Expected valueNotFound, got \(error)")
            }
            XCTAssertEqual(context.codingPath.last?.intValue, 0)
        }

        let dictionary = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_value(dictionary, "value", null)
        XCTAssertThrowsError(try XPCObjectDecoder().decode(Required.self, from: dictionary)) { error in
            guard case DecodingError.valueNotFound(_, let context) = error else {
                return XCTFail("Expected valueNotFound, got \(error)")
            }
            XCTAssertEqual(context.codingPath.last?.stringValue, "value")
        }
    }

    func test_nulCodingKeyCannotAliasAValidKeyPrefix() throws {
        struct InvalidKey: Decodable {
            enum CodingKeys: String, CodingKey { case value = "before\0after" }
            let value: Int

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                XCTAssertFalse(container.contains(.value))
                value = try container.decode(Int.self, forKey: .value)
            }
        }

        let dictionary = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_int64(dictionary, "before", 7)
        XCTAssertThrowsError(try XPCObjectDecoder().decode(InvalidKey.self, from: dictionary)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "before\0after")
        }
    }

    func test_explicitKeyedAndUnkeyedNestedContainersRoundTrip() throws {
        struct Manual: Codable {
            let value: String
            let numbers: [Int]

            init(value: String, numbers: [Int]) { self.value = value; self.numbers = numbers }
            init(from decoder: Decoder) throws {
                let root = try decoder.container(keyedBy: Keys.self)
                let nested = try root.nestedContainer(keyedBy: Keys.self, forKey: .nested)
                value = try nested.decode(String.self, forKey: .value)
                var outerArray = try root.nestedUnkeyedContainer(forKey: .array)
                var innerArray = try outerArray.nestedUnkeyedContainer()
                numbers = [try innerArray.decode(Int.self), try innerArray.decode(Int.self)]
                let innerDictionary = try outerArray.nestedContainer(keyedBy: Keys.self)
                XCTAssertEqual(try innerDictionary.decode(Bool.self, forKey: .sibling), true)
            }
            func encode(to encoder: Encoder) throws {
                var root = encoder.container(keyedBy: Keys.self)
                var nested = root.nestedContainer(keyedBy: Keys.self, forKey: .nested)
                var outerArray = root.nestedUnkeyedContainer(forKey: .array)
                var innerArray = outerArray.nestedUnkeyedContainer()
                var innerDictionary = outerArray.nestedContainer(keyedBy: Keys.self)
                try nested.encode(value, forKey: .value)
                for number in numbers { try innerArray.encode(number) }
                try innerDictionary.encode(true, forKey: .sibling)
            }
        }

        let input = Manual(value: "nested", numbers: [3, 4])
        let object = try XPCObjectEncoder().encode(input)
        let array = try dictionaryValue(object, "array")
        XCTAssertEqual(xpc_get_type(xpc_array_get_value(array, 0)), XPC_TYPE_ARRAY)
        XCTAssertEqual(xpc_get_type(xpc_array_get_value(array, 1)), XPC_TYPE_DICTIONARY)
        let decoded = try XPCObjectDecoder().decode(Manual.self, from: object)
        XCTAssertEqual(decoded.value, input.value)
        XCTAssertEqual(decoded.numbers, input.numbers)
    }

    func test_decodingFailuresUseDecodingErrorAndUsefulPaths() throws {
        struct Required: Decodable { let value: String }
        let missing = xpc_dictionary_create(nil, nil, 0)
        XCTAssertThrowsError(try XPCObjectDecoder().decode(Required.self, from: missing)) { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else {
                return XCTFail("Expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "value")
            XCTAssertTrue(context.codingPath.isEmpty)
        }

        let mismatch = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_int64(mismatch, "value", 4)
        XCTAssertThrowsError(try XPCObjectDecoder().decode(Required.self, from: mismatch)) { error in
            guard case DecodingError.typeMismatch(_, let context) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(context.codingPath.map(\.stringValue), ["value"])
        }

        let overflow = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_int64(overflow, "value", 300)
        struct Narrow: Decodable { let value: UInt8 }
        XCTAssertThrowsError(try XPCObjectDecoder().decode(Narrow.self, from: overflow)) { error in
            guard let path = Self.decodingPath(error) else {
                return XCTFail("Expected DecodingError, got \(error)")
            }
            XCTAssertEqual(path.map(\.stringValue), ["value"])
        }
    }

    func test_encodingFailuresCarryNestedPaths() throws {
        struct StringValue: Encodable { let items: [String] }
        struct DateValue: Encodable { let items: [Date] }
        struct InvalidKey: Encodable {
            enum CodingKeys: String, CodingKey { case bad = "bad\0key" }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(1, forKey: .bad)
            }
        }

        XCTAssertThrowsError(try XPCObjectEncoder().encode(StringValue(items: ["bad\0string"]))) { error in
            guard case EncodingError.invalidValue(_, let context) = error else {
                return XCTFail("Expected invalidValue, got \(error)")
            }
            XCTAssertEqual(context.codingPath.first?.stringValue, "items")
            XCTAssertEqual(context.codingPath.last?.intValue, 0)
        }
        XCTAssertThrowsError(try XPCObjectEncoder().encode(InvalidKey())) { error in
            guard case EncodingError.invalidValue(_, let context) = error else {
                return XCTFail("Expected invalidValue, got \(error)")
            }
            XCTAssertEqual(context.codingPath.last?.stringValue, "bad\0key")
        }
        XCTAssertThrowsError(try XPCObjectEncoder().encode(DateValue(items: [.distantFuture]))) { error in
            guard case EncodingError.invalidValue(_, let context) = error else {
                return XCTFail("Expected invalidValue, got \(error)")
            }
            XCTAssertEqual(context.codingPath.first?.stringValue, "items")
            XCTAssertEqual(context.codingPath.last?.intValue, 0)
        }
    }

    func test_userInfoReachesNestedEncodersAndDecoders() throws {
        let key = try XCTUnwrap(CodingUserInfoKey(rawValue: "probe"))
        struct Probe: Codable {
            let value: String
            init(value: String) { self.value = value }
            init(from decoder: Decoder) throws {
                value = decoder.userInfo[CodingUserInfoKey(rawValue: "probe")!] as? String ?? "missing"
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(encoder.userInfo[CodingUserInfoKey(rawValue: "probe")!] as? String ?? "missing")
            }
        }
        struct Outer: Codable { let nested: [Probe] }

        var encoder = XPCObjectEncoder()
        encoder.userInfo[key] = "encoded"
        let object = try encoder.encode(Outer(nested: [Probe(value: "ignored")]))
        let array = try XCTUnwrap(xpc_dictionary_get_value(object, "nested"))
        XCTAssertEqual(String(cString: xpc_string_get_string_ptr(xpc_array_get_value(array, 0))!), "encoded")

        var decoder = XPCObjectDecoder()
        decoder.userInfo[key] = "decoded"
        XCTAssertEqual(try decoder.decode(Outer.self, from: object).nested.first?.value, "decoded")
    }

    func test_retainedNestedContainersMaterializeAfterSiblingWrites() throws {
        struct Retained: Encodable {
            func encode(to encoder: Encoder) throws {
                var root = encoder.container(keyedBy: Keys.self)
                var nested = root.nestedContainer(keyedBy: Keys.self, forKey: .nested)
                try nested.encode("first", forKey: .first)
                var array = root.nestedUnkeyedContainer(forKey: .array)
                try array.encode(1)
                try root.encode(true, forKey: .sibling)
                try nested.encode("second", forKey: .second)
                try array.encode(2)
            }
        }

        let object = try XPCObjectEncoder().encode(Retained())
        let nested = try XCTUnwrap(xpc_dictionary_get_value(object, "nested"))
        XCTAssertEqual(String(cString: xpc_string_get_string_ptr(try dictionaryValue(nested, "first"))!), "first")
        XCTAssertEqual(String(cString: xpc_string_get_string_ptr(try dictionaryValue(nested, "second"))!), "second")
        let array = try XCTUnwrap(xpc_dictionary_get_value(object, "array"))
        XCTAssertEqual(xpc_array_get_count(array), 2)
        XCTAssertEqual(xpc_int64_get_value(xpc_array_get_value(array, 0)), 1)
        XCTAssertEqual(xpc_int64_get_value(xpc_array_get_value(array, 1)), 2)
        XCTAssertTrue(xpc_dictionary_get_bool(object, "sibling"))
    }

    func test_retainedSuperEncoderAndDecoderUseExplicitAndDefaultKeys() throws {
        struct Inherited: Codable {
            let base: Int
            let sibling: String

            init(base: Int, sibling: String) { self.base = base; self.sibling = sibling }
            init(from decoder: Decoder) throws {
                let root = try decoder.container(keyedBy: Keys.self)
                base = try Int(from: root.superDecoder(forKey: .base))
                sibling = try root.decode(String.self, forKey: .sibling)
            }
            func encode(to encoder: Encoder) throws {
                var root = encoder.container(keyedBy: Keys.self)
                let baseEncoder = root.superEncoder(forKey: .base)
                try root.encode(sibling, forKey: .sibling)
                try base.encode(to: baseEncoder)
            }
        }
        struct DefaultSuper: Codable {
            let value: Int

            init(value: Int) { self.value = value }
            init(from decoder: Decoder) throws {
                let root = try decoder.container(keyedBy: Keys.self)
                value = try Int(from: root.superDecoder())
            }
            func encode(to encoder: Encoder) throws {
                var root = encoder.container(keyedBy: Keys.self)
                let superEncoder = root.superEncoder()
                try value.encode(to: superEncoder)
            }
        }

        let input = Inherited(base: 7, sibling: "later")
        let object = try XPCObjectEncoder().encode(input)
        XCTAssertEqual(xpc_int64_get_value(try dictionaryValue(object, "base")), 7)
        XCTAssertEqual(try XPCObjectDecoder().decode(Inherited.self, from: object).sibling, input.sibling)
        XCTAssertEqual(try XPCObjectDecoder().decode(Inherited.self, from: object).base, input.base)

        let defaultObject = try XPCObjectEncoder().encode(DefaultSuper(value: 9))
        XCTAssertEqual(xpc_int64_get_value(try dictionaryValue(defaultObject, "super")), 9)
        XCTAssertEqual(try XPCObjectDecoder().decode(DefaultSuper.self, from: defaultObject).value, 9)
    }

    func test_unkeyedSuperEncoderAndDecoderPreservePosition() throws {
        struct Pair: Codable {
            let first: Int
            let second: Int

            init(first: Int, second: Int) { self.first = first; self.second = second }
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                first = try Int(from: container.superDecoder())
                second = try container.decode(Int.self)
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                let firstEncoder = container.superEncoder()
                try container.encode(second)
                try first.encode(to: firstEncoder)
            }
        }

        let object = try XPCObjectEncoder().encode(Pair(first: 1, second: 2))
        XCTAssertEqual(xpc_array_get_count(object), 2)
        XCTAssertEqual(xpc_int64_get_value(xpc_array_get_value(object, 0)), 1)
        XCTAssertEqual(xpc_int64_get_value(xpc_array_get_value(object, 1)), 2)
        let decoded = try XPCObjectDecoder().decode(Pair.self, from: object)
        XCTAssertEqual(decoded.first, 1)
        XCTAssertEqual(decoded.second, 2)
    }

    func test_unkeyedDecodeNilAndFailedDecodeDoNotConsumeElements() throws {
        struct Probe: Decodable {
            let first: Int
            let second: String

            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                guard try !container.decodeNil() else { throw ProbeError.unexpectedNil }
                do {
                    _ = try container.decode(String.self)
                    throw ProbeError.unexpectedSuccess
                } catch DecodingError.typeMismatch { }
                first = try container.decode(Int.self)
                guard try !container.decodeNil() else { throw ProbeError.unexpectedNil }
                second = try container.decode(String.self)
            }
        }

        let array = xpc_array_create(nil, 0)
        xpc_array_append_value(array, xpc_int64_create(5))
        xpc_array_append_value(array, xpc_string_create("next"))
        let decoded = try XPCObjectDecoder().decode(Probe.self, from: array)
        XCTAssertEqual(decoded.first, 5)
        XCTAssertEqual(decoded.second, "next")
    }

    private enum ProbeError: Error { case unexpectedNil, unexpectedSuccess }

    private func dictionaryValue(_ object: xpc_object_t, _ key: String) throws -> xpc_object_t {
        try XCTUnwrap(xpc_dictionary_get_value(object, key))
    }

    private static func decodingPath(_ error: Error) -> [CodingKey]? {
        switch error {
        case DecodingError.typeMismatch(_, let context): return context.codingPath
        case DecodingError.valueNotFound(_, let context): return context.codingPath
        case DecodingError.keyNotFound(_, let context): return context.codingPath
        case DecodingError.dataCorrupted(let context): return context.codingPath
        default: return nil
        }
    }
}
