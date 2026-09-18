//  MIT License
//
//  Copyright (c) 2022 Alkenso (Vladimir Vashurkin)
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

import EndpointSecurity
import Foundation
import SpellbookFoundation

extension es_event_exec_t {
    public var args: [String] {
        parse(valueFn: es_exec_arg, countFn: es_exec_arg_count).map(Self.dummyConverter.esString)
    }
    
    public var env: [String] {
        parse(valueFn: es_exec_env, countFn: es_exec_env_count).map(Self.dummyConverter.esString)
    }
    
    /// Open file descriptors of the process being executed.
    ///
    /// The API may only return descriptions for a subset of open file descriptors; how many and
    /// which file descriptors are available as part of exec events is not considered API and can
    /// change between releases.
    ///
    /// - Note: `es_fd_t` values are copied out of the message, so they remain valid after
    /// the originating message is released.
    public var fds: [es_fd_t] {
        parse(valueFn: es_exec_fd, countFn: es_exec_fd_count).map(\.pointee)
    }

#if compiler(>=6.4)
    /// The entitlements of the process being executed, or `nil` if there are no entitlements.
    ///
    /// The underlying XPC dictionary is bridged to Swift values:
    /// `Bool`, `Int64`, `UInt64`, `Double`, `String`, `Data`, `Date`, `UUID`,
    /// `[Any]` and `[String: Any]`. An XPC null is bridged to `NSNull`.
    /// Values with no Swift counterpart (file descriptors, shared memory, connections,
    /// errors) are passed through as the underlying `xpc_object_t`.
    @available(macOS 27.0, *)
    public var entitlements: [String: Any]? {
        withUnsafePointer(to: self) { es_exec_entitlements($0) }
            .flatMap { xpc_get_type($0) == XPC_TYPE_DICTIONARY ? xpcDictionary($0) : nil }
    }
#endif
    
    private static let dummyConverter = ESConverter(version: 0)
    
    private func parse<T>(
        valueFn: (UnsafePointer<es_event_exec_t>, UInt32) -> T,
        countFn: (UnsafePointer<es_event_exec_t>) -> UInt32
    ) -> [T] {
        withUnsafePointer(to: self) {
            var values: [T] = []
            let count = countFn($0)
            for i in 0..<count {
                let value = valueFn($0, i)
                values.append(value)
            }
            return values
        }
    }
}

/// Bridges an XPC dictionary to its Swift representation.
///
/// Internal rather than private so the bridging rules can be unit-tested directly;
/// reaching them through `entitlements` would need a live `es_message_t`.
///
/// `xpc_array_apply` / `xpc_dictionary_apply` are `XPC_NOESCAPE`, so the accumulator
/// can safely be captured and mutated here.
internal func xpcDictionary(_ xpc: xpc_object_t) -> [String: Any] {
    var result: [String: Any] = [:]
    xpc_dictionary_apply(xpc) { key, value in
        result[String(cString: key)] = xpcValue(value)
        return true
    }
    return result
}

internal func xpcArray(_ xpc: xpc_object_t) -> [Any] {
    var result: [Any] = []
    xpc_array_apply(xpc) { _, value in
        result.append(xpcValue(value))
        return true
    }
    return result
}

/// Anything without a Swift counterpart is returned as the underlying `xpc_object_t`,
/// so no value is ever silently dropped.
internal func xpcValue(_ xpc: xpc_object_t) -> Any {
    switch xpc_get_type(xpc) {
    case XPC_TYPE_BOOL: return xpc_bool_get_value(xpc)
    case XPC_TYPE_INT64: return xpc_int64_get_value(xpc)
    case XPC_TYPE_UINT64: return xpc_uint64_get_value(xpc)
    case XPC_TYPE_DOUBLE: return xpc_double_get_value(xpc)
    case XPC_TYPE_STRING: return xpc_string_get_string_ptr(xpc).map { String(cString: $0) } ?? xpc
    case XPC_TYPE_UUID: return xpc_uuid_get_bytes(xpc).map { UUID(uuid: $0.withMemoryRebound(to: uuid_t.self, capacity: 1) { $0.pointee }) } ?? xpc
    case XPC_TYPE_DICTIONARY: return xpcDictionary(xpc)
    case XPC_TYPE_ARRAY: return xpcArray(xpc)
    case XPC_TYPE_NULL: return NSNull()
    case XPC_TYPE_DATA:
        guard let bytes = xpc_data_get_bytes_ptr(xpc) else { return Data() }
        return Data(bytes: bytes, count: xpc_data_get_length(xpc))
    case XPC_TYPE_DATE:
        /* xpc_date_get_value returns nanoseconds since the Unix epoch. */
        return Date(timeIntervalSince1970: Double(xpc_date_get_value(xpc)) / 1_000_000_000)
    default:
        return xpc
    }
}

internal func validESEvents(_ client: ESNativeClient) -> Set<es_event_type_t> {
    validESEventsCacheLock.withLock {
        if let validESEventsCache { return validESEventsCache }
        
        let dummyPath = "/dummy_\(UUID())"
        guard client.esMutePath(dummyPath, ES_MUTE_PATH_TYPE_LITERAL) == ES_RETURN_SUCCESS else {
            return fallbackESEvents
        }
        defer { _ = client.esUnmutePath(dummyPath, ES_MUTE_PATH_TYPE_LITERAL) }
        
        guard let allMutes = client.esMutedPaths().first(where: { $0.path == dummyPath })?.events,
              !allMutes.isEmpty
        else {
            return fallbackESEvents
        }
        
        validESEventsCache = Set(allMutes)
        
        return validESEventsCache!
    }
}

private nonisolated(unsafe) var validESEventsCache: Set<es_event_type_t>?
private let validESEventsCacheLock = UnfairLock()

private let fallbackESEvents: Set<es_event_type_t> = {
    Set((0..<fallbackLastESEvent).map(es_event_type_t.init(rawValue:)))
}()

/// Exclusive upper bound of `es_event_type_t` raw values the running OS is expected to support.
///
/// `es_event_type_t` is append-only, so the last event introduced by an OS version
/// (plus one) is the number of events that version knows about.
private var fallbackLastESEvent: UInt32 {
    if #available(macOS 27.0, *) { return ES_EVENT_TYPE_LAST.rawValue }
    if #available(macOS 26.5, *) { return ES_EVENT_TYPE_RESERVED_8.rawValue + 1 }
    if #available(macOS 26.4, *) { return ES_EVENT_TYPE_RESERVED_6.rawValue + 1 }
    if #available(macOS 26.3, *) { return ES_EVENT_TYPE_RESERVED_2.rawValue + 1 }
    if #available(macOS 15.4, *) { return ES_EVENT_TYPE_NOTIFY_TCC_MODIFY.rawValue + 1 }
    if #available(macOS 15.0, *) { return ES_EVENT_TYPE_NOTIFY_GATEKEEPER_USER_OVERRIDE.rawValue + 1 }
    if #available(macOS 14.0, *) { return ES_EVENT_TYPE_NOTIFY_XPC_CONNECT.rawValue + 1 }
    return ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_REMOVE.rawValue + 1
}
