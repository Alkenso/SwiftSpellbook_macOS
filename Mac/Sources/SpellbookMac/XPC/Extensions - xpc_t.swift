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

import SpellbookFoundation

import Foundation
import XPC

/// Recursively converts an XPC value to its natural Swift representation.
///
/// Scalars become `Bool`, `Int64`, `UInt64`, `Double`, `String`, `Data`, `Date`,
/// or `UUID`. Arrays become `[Any]`, dictionaries become `[String: Any]`, and
/// null values become `NSNull`, preserving null entries in collections.
/// Dates use seconds since the Unix epoch and may lose subsecond precision.
///
/// Types without a Swift value representation, including resource and error
/// objects, remain the original `xpc_object_t`, also within nested collections.
public func xpc_to_swift(_ object: xpc_object_t) -> Any {
    switch xpc_get_type(object) {
    case XPC_TYPE_NULL:
        return NSNull()
    case XPC_TYPE_BOOL:
        return xpc_bool_get_value(object)
    case XPC_TYPE_INT64:
        return xpc_int64_get_value(object)
    case XPC_TYPE_UINT64:
        return xpc_uint64_get_value(object)
    case XPC_TYPE_DOUBLE:
        return xpc_double_get_value(object)
    case XPC_TYPE_STRING:
        return String(cString: xpc_string_get_string_ptr(object)!)
    case XPC_TYPE_DATA:
        return xpcDataToSwift(object)
    case XPC_TYPE_DATE:
        return Date(timeIntervalSince1970: TimeInterval(xpc_date_get_value(object)) / 1_000_000_000)
    case XPC_TYPE_UUID:
        return UUID(uuid: UnsafeRawPointer(xpc_uuid_get_bytes(object)!).loadUnaligned(as: uuid_t.self))
    case XPC_TYPE_ARRAY:
        return xpcArrayToSwift(object)
    case XPC_TYPE_DICTIONARY:
        return xpcDictionaryToSwift(object)
    default:
        return object
    }
}

/// Recursively converts every element, preserving order and null values.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public func xpc_to_swift(_ array: XPCArray) -> [Any] {
    array.withUnsafeUnderlyingArray { xpcArrayToSwift($0) }
}

/// Recursively converts every value, preserving keys and null values.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public func xpc_to_swift(_ dictionary: XPCDictionary) -> [String: Any] {
    dictionary.withUnsafeUnderlyingDictionary { xpcDictionaryToSwift($0) }
}

/// Recursively converts Swift values to XPC objects.
///
/// Supports `Bool`, signed and unsigned integers representable in 64 bits,
/// floating-point values representable as `Double`, `String`, `Date`, `Data`,
/// `UUID`, `NSNull`, arrays, and dictionaries with string keys. Integer
/// signedness is preserved; floating-point values use XPC doubles.
/// Dates are rounded to the nearest nanosecond since the Unix epoch, subject
/// to `Date` precision and the range of `Int64` nanoseconds.
/// Existing `xpc_object_t` values pass through unchanged, including inside
/// Swift collections; their identity and contents are preserved.
///
/// Throws `CommonError` for unsupported values, out-of-range numbers or dates,
/// and strings or keys containing NUL. An invalid nested value fails the
/// entire conversion. Use `NSNull` to represent a null value.
public func xpc_from_swift(_ value: Any) throws -> xpc_object_t {
    switch value {
    case let object as xpc_object_t:
        return object
    case let bool as Bool where type(of: value) == Bool.self:
        return xpc_bool_create(bool)
    case let integer as any BinaryInteger:
        return try xpcIntegerFromSwift(integer)
    case let number as any BinaryFloatingPoint:
        return try xpcFloatingPointFromSwift(number)
    case let string as String:
        try validateXPCCString(string)
        return xpc_string_create(string)
    case let date as Date:
        return try xpcDateFromSwift(date)
    case let data as Data:
        return data.withUnsafeBytes { xpc_data_create($0.baseAddress, $0.count) }
    case let uuid as UUID:
        return withUnsafeBytes(of: uuid.uuid) { xpc_uuid_create($0.bindMemory(to: UInt8.self).baseAddress!) }
    case is NSNull: return xpc_null_create()
    case let array as [Any]:
        return try xpcArrayFromSwift(array)
    case let dictionary as [String: Any]:
        return try xpcDictionaryFromSwift(dictionary)
    default:
        throw CommonError.invalidArgument(
            arg: "value",
            invalidValue: type(of: value),
            description: "Unsupported Swift type for XPC conversion"
        )
    }
}

private func xpcIntegerFromSwift<T: BinaryInteger>(_ value: T) throws -> xpc_object_t {
    if T.isSigned {
        if let integer = Int64(exactly: value) { return xpc_int64_create(integer) }
    } else {
        if let integer = UInt64(exactly: value) { return xpc_uint64_create(integer) }
    }
    throw CommonError.invalidArgument(
        arg: "value",
        invalidValue: value,
        description: "Integer is outside the XPC 64-bit range"
    )
}

private func xpcFloatingPointFromSwift<T: BinaryFloatingPoint>(_ value: T) throws -> xpc_object_t {
    let number = Double(value)
    guard !value.isFinite || number.isFinite else {
        throw CommonError.invalidArgument(
            arg: "value",
            invalidValue: value,
            description: "Floating-point value is outside the XPC double range"
        )
    }
    return xpc_double_create(number)
}

private func xpcDateFromSwift(_ value: Date) throws -> xpc_object_t {
    let nanoseconds = (value.timeIntervalSince1970 * 1_000_000_000).rounded()
    guard let interval = Int64(exactly: nanoseconds) else {
        throw CommonError.invalidArgument(
            arg: "value",
            invalidValue: value,
            description: "Date is outside the XPC nanosecond range"
        )
    }
    return xpc_date_create(interval)
}

private func validateXPCCString(_ value: String) throws {
    guard !value.utf8.contains(0) else {
        throw CommonError.invalidArgument(
            arg: "value",
            invalidValue: value,
            description: "XPC strings and dictionary keys cannot contain NUL"
        )
    }
}

private func xpcArrayFromSwift(_ value: [Any]) throws -> xpc_object_t {
    let array = xpc_array_create(nil, 0)
    for element in value {
        xpc_array_append_value(array, try xpc_from_swift(element))
    }
    return array
}

private func xpcDictionaryFromSwift(_ value: [String: Any]) throws -> xpc_object_t {
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    for (key, element) in value {
        try validateXPCCString(key)
        xpc_dictionary_set_value(dictionary, key, try xpc_from_swift(element))
    }
    return dictionary
}

private func xpcDataToSwift(_ object: xpc_object_t) -> Data {
    let count = xpc_data_get_length(object)
    guard count > 0 else { return Data() }
    return Data(bytes: xpc_data_get_bytes_ptr(object)!, count: count)
}

private func xpcArrayToSwift(_ object: xpc_object_t) -> [Any] {
    (0..<xpc_array_get_count(object)).map {
        xpc_to_swift(xpc_array_get_value(object, $0))
    }
}

private func xpcDictionaryToSwift(_ object: xpc_object_t) -> [String: Any] {
    var result: [String: Any] = [:]
    result.reserveCapacity(xpc_dictionary_get_count(object))
    xpc_dictionary_apply(object) { key, value in
        result[String(cString: key)] = xpc_to_swift(value)
        return true
    }
    return result
}
