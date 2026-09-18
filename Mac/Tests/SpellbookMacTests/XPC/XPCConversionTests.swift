import Foundation
import SpellbookMac
import XCTest
import XPC

class XPCConversionTests: XCTestCase {
    func test_scalarValuesPreserveTheirTypes() throws {
        XCTAssertEqual(xpc_to_swift(xpc_bool_create(true)) as? Bool, true)
        XCTAssertEqual(xpc_to_swift(xpc_bool_create(false)) as? Bool, false)
        XCTAssertEqual(xpc_to_swift(xpc_int64_create(.min)) as? Int64, .min)
        XCTAssertEqual(xpc_to_swift(xpc_uint64_create(.max)) as? UInt64, .max)
        XCTAssertEqual(xpc_to_swift(xpc_double_create(1.25)) as? Double, 1.25)
        XCTAssertEqual(xpc_to_swift(xpc_string_create("Hello, 世界")) as? String, "Hello, 世界")
        XCTAssertEqual(xpc_to_swift(xpc_string_create("")) as? String, "")
        XCTAssertTrue(xpc_to_swift(xpc_null_create()) is NSNull)
    }

    func test_dataIsCopiedIncludingEmptyData() throws {
        let bytes: [UInt8] = [0, 127, 255]
        let object = bytes.withUnsafeBytes { xpc_data_create($0.baseAddress, $0.count) }
        XCTAssertEqual(xpc_to_swift(object) as? Data, Data([0, 127, 255]))
        XCTAssertEqual(xpc_to_swift(xpc_data_create(nil, 0)) as? Data, Data())
    }

    func test_datesUseSecondsSinceUnixEpoch() throws {
        XCTAssertEqual(xpc_to_swift(xpc_date_create(1_500_000_000)) as? Date,
                       Date(timeIntervalSince1970: 1.5))
        XCTAssertEqual(xpc_to_swift(xpc_date_create(-250_000_000)) as? Date,
                       Date(timeIntervalSince1970: -0.25))
    }

    func test_uuidPreservesBytes() throws {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        let object = bytes.withUnsafeBufferPointer { xpc_uuid_create($0.baseAddress!) }
        XCTAssertEqual(xpc_to_swift(object) as? UUID,
                       UUID(uuidString: "00010203-0405-0607-0809-0A0B0C0D0E0F"))
    }

    func test_nestedCollectionsPreserveNullsAndOrder() throws {
        let dictionary = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(dictionary, "name", "value")
        xpc_dictionary_set_value(dictionary, "null", xpc_null_create())
        let array = xpc_array_create(nil, 0)
        xpc_array_append_value(array, xpc_int64_create(-7))
        xpc_array_append_value(array, xpc_null_create())
        xpc_array_append_value(array, dictionary)
        let root = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_value(root, "items", array)

        let result = try XCTUnwrap(xpc_to_swift(root) as? [String: Any])
        let items = try XCTUnwrap(result["items"] as? [Any])
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0] as? Int64, -7)
        XCTAssertTrue(items[1] is NSNull)
        let nested = try XCTUnwrap(items[2] as? [String: Any])
        XCTAssertEqual(nested["name"] as? String, "value")
        XCTAssertTrue(nested["null"] is NSNull)
    }

    func test_emptyCollections() throws {
        XCTAssertEqual((xpc_to_swift(xpc_array_create(nil, 0)) as? [Any])?.count, 0)
        XCTAssertEqual((xpc_to_swift(xpc_dictionary_create(nil, nil, 0)) as? [String: Any])?.count, 0)
    }

    func test_swiftCollectionWrappers() throws {
        if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
            let array = xpc_array_create(nil, 0)
            xpc_array_append_value(array, xpc_string_create("value"))
            XCTAssertEqual(xpc_to_swift(XPCArray(array)) as? [String], ["value"])
            let dictionary = xpc_dictionary_create(nil, nil, 0)
            xpc_dictionary_set_bool(dictionary, "flag", true)
            XCTAssertEqual(xpc_to_swift(XPCDictionary(dictionary))["flag"] as? Bool, true)
        }
    }

    func test_fromSwiftPreservesNumericKinds() throws {
        let signed: [Any] = [Int(-7), Int8(-7), Int16(-7), Int32(-7), Int64(-7)]
        for value in signed {
            let object = try xpc_from_swift(value)
            XCTAssertEqual(xpc_get_type(object), XPC_TYPE_INT64)
            XCTAssertEqual(xpc_int64_get_value(object), -7)
        }
        let unsigned: [Any] = [UInt(7), UInt8(7), UInt16(7), UInt32(7), UInt64(7)]
        for value in unsigned {
            let object = try xpc_from_swift(value)
            XCTAssertEqual(xpc_get_type(object), XPC_TYPE_UINT64)
            XCTAssertEqual(xpc_uint64_get_value(object), 7)
        }
        XCTAssertEqual(try xpc_int64_get_value(xpc_from_swift(Int64.min)), .min)
        XCTAssertEqual(try xpc_uint64_get_value(xpc_from_swift(UInt64.max)), .max)
        for value: Any in [Float(1.25), Double(1.25)] {
            let object = try xpc_from_swift(value)
            XCTAssertEqual(xpc_get_type(object), XPC_TYPE_DOUBLE)
            XCTAssertEqual(xpc_double_get_value(object), 1.25)
        }
        for value in [false, true] {
            let object = try xpc_from_swift(value)
            XCTAssertEqual(xpc_get_type(object), XPC_TYPE_BOOL)
            XCTAssertEqual(xpc_bool_get_value(object), value)
        }
        XCTAssertEqual(try xpc_get_type(xpc_from_swift(1)), XPC_TYPE_INT64)
        XCTAssertEqual(try xpc_get_type(xpc_from_swift(1.0)), XPC_TYPE_DOUBLE)
    }

    func test_fromSwiftFoundationValues() throws {
        XCTAssertEqual(try xpc_to_swift(xpc_from_swift("Hello, 世界")) as? String, "Hello, 世界")
        XCTAssertEqual(try xpc_to_swift(xpc_from_swift("")) as? String, "")
        XCTAssertEqual(try xpc_to_swift(xpc_from_swift(Data([0, 127, 255]))) as? Data,
                       Data([0, 127, 255]))
        XCTAssertEqual(try xpc_to_swift(xpc_from_swift(Data())) as? Data, Data())
        let uuid = try XCTUnwrap(UUID(uuidString: "00010203-0405-0607-0809-0A0B0C0D0E0F"))
        XCTAssertEqual(try xpc_to_swift(xpc_from_swift(uuid)) as? UUID, uuid)
        XCTAssertEqual(try xpc_get_type(xpc_from_swift(NSNull())), XPC_TYPE_NULL)
        XCTAssertEqual(try xpc_date_get_value(xpc_from_swift(Date(timeIntervalSince1970: 1.5))),
                       1_500_000_000)
        XCTAssertEqual(try xpc_date_get_value(xpc_from_swift(Date(timeIntervalSince1970: -0.25))),
                       -250_000_000)
    }

    func test_fromSwiftNumericBoundaries() throws {
        if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) {
            XCTAssertEqual(try xpc_int64_get_value(xpc_from_swift(Int128(Int64.max))), .max)
            XCTAssertEqual(try xpc_uint64_get_value(xpc_from_swift(UInt128(UInt64.max))), .max)
            XCTAssertThrowsError(try xpc_from_swift(Int128(Int64.max) + 1))
            XCTAssertThrowsError(try xpc_from_swift(Int128(Int64.min) - 1))
            XCTAssertThrowsError(try xpc_from_swift(UInt128(UInt64.max) + 1))
        }
        XCTAssertEqual(try xpc_double_get_value(xpc_from_swift(Double.infinity)), .infinity)
        XCTAssertTrue(try xpc_double_get_value(xpc_from_swift(Double.nan)).isNaN)
    }

    func test_fromSwiftNestedCollectionsRoundTrip() throws {
        let input: [String: Any] = [
            "items": [Int64(-7), NSNull(), ["flag": true]] as [Any],
            "emptyArray": [Any](),
            "emptyDictionary": [String: Any]()
        ]
        let object = try xpc_from_swift(input)
        XCTAssertEqual(xpc_get_type(object), XPC_TYPE_DICTIONARY)
        let result = try XCTUnwrap(xpc_to_swift(object) as? [String: Any])
        let items = try XCTUnwrap(result["items"] as? [Any])
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0] as? Int64, -7)
        XCTAssertTrue(items[1] is NSNull)
        XCTAssertEqual((items[2] as? [String: Bool])?["flag"], true)
        XCTAssertEqual((result["emptyArray"] as? [Any])?.count, 0)
        XCTAssertEqual((result["emptyDictionary"] as? [String: Any])?.count, 0)
        XCTAssertEqual(try xpc_to_swift(xpc_from_swift([1, 2, 3])) as? [Int64], [1, 2, 3])
        XCTAssertEqual(try xpc_to_swift(xpc_from_swift(["number": 42])) as? [String: Int64],
                       ["number": 42])
    }

    func test_fromSwiftPreservesExistingXPCObjectsInMixedCollections() throws {
        let objects = [
            xpc_string_create("existing"),
            xpc_int64_create(42),
            xpc_null_create(),
            xpc_array_create(nil, 0),
            xpc_dictionary_create(nil, nil, 0)
        ]
        for object in objects {
            XCTAssertTrue(try xpc_from_swift(object) === object)
            let input: [String: Any] = ["items": [true, ["existing": object]] as [Any]]
            let result = try xpc_from_swift(input)
            let items = try XCTUnwrap(xpc_dictionary_get_value(result, "items"))
            XCTAssertTrue(xpc_array_get_bool(items, 0))
            let nested = xpc_array_get_value(items, 1)
            let preserved = try XCTUnwrap(xpc_dictionary_get_value(nested, "existing"))
            XCTAssertTrue(preserved === object)
            let array = try xpc_from_swift([object])
            XCTAssertTrue(xpc_array_get_value(array, 0) === object)
        }
    }

    func test_fromSwiftRejectsUnsupportedAndTruncatedValues() throws {
        struct Unsupported {}
        XCTAssertThrowsError(try xpc_from_swift(Unsupported()))
        XCTAssertThrowsError(try xpc_from_swift([Unsupported()]))
        XCTAssertThrowsError(try xpc_from_swift(["value": Unsupported()]))
        XCTAssertThrowsError(try xpc_from_swift([1: "non-string key"]))
        XCTAssertThrowsError(try xpc_from_swift("before\0after"))
        XCTAssertThrowsError(try xpc_from_swift(["before\0after": 1]))
        XCTAssertThrowsError(try xpc_from_swift(Date.distantFuture))
        XCTAssertThrowsError(try xpc_from_swift(Date.distantPast))
        XCTAssertThrowsError(try xpc_from_swift(Date(timeIntervalSince1970: .infinity)))
        XCTAssertThrowsError(try xpc_from_swift(Date(timeIntervalSince1970: .nan)))
    }

    func test_toSwiftPreservesResourceAndErrorObjectsIncludingInsideCollections() throws {
        let descriptor = open("/dev/null", O_RDONLY)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { close(descriptor) }
        let resource = try XCTUnwrap(xpc_fd_create(descriptor))
        for object in [resource, XPC_ERROR_CONNECTION_INVALID] {
            let preserved = try XCTUnwrap(xpc_to_swift(object) as? xpc_object_t)
            XCTAssertTrue(preserved === object)
            let wrapped = try xpc_from_swift(["items": [42, object] as [Any]])
            let dictionary = try XCTUnwrap(xpc_to_swift(wrapped) as? [String: Any])
            let items = try XCTUnwrap(dictionary["items"] as? [Any])
            XCTAssertEqual(items[0] as? Int64, 42)
            XCTAssertTrue(try XCTUnwrap(items[1] as? xpc_object_t) === object)
            let roundTripped = try xpc_from_swift(dictionary)
            let array = try XCTUnwrap(xpc_dictionary_get_value(roundTripped, "items"))
            XCTAssertTrue(xpc_array_get_value(array, 1) === object)
            if #available(macOS 13, *) {
                XCTAssertTrue(try XCTUnwrap(xpc_to_swift(XPCArray(array))[1] as? xpc_object_t) === object)
                let wrappedItems = try XCTUnwrap(xpc_to_swift(XPCDictionary(wrapped))["items"] as? [Any])
                XCTAssertTrue(try XCTUnwrap(wrappedItems[1] as? xpc_object_t) === object)
            }
        }
    }
}
