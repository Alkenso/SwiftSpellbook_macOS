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

private let log = SpellbookLogger.internalLog(.client)

public protocol ESNativeClient {
    var native: OpaquePointer { get }
    
    func esRespond(_ message: UnsafePointer<es_message_t>, flags: UInt32, cache: Bool) -> es_respond_result_t
    
    func esSubscribe(_ events: [es_event_type_t]) -> es_return_t
    func esUnsubscribe(_ events: [es_event_type_t]) -> es_return_t
    func esUnsubscribeAll() -> es_return_t
    
    /// The current native subscriptions. Logs failures and returns an empty array.
    func esSubscriptions() -> [es_event_type_t]

#if compiler(>=6.4)
    /// Runs after messages preceding a native queue marker have been handled.
    /// Does not wait for work dispatched asynchronously by application handlers.
    /// Must not be called from this client's native handler. Deleting the client also runs pending callbacks.
    @available(macOS 27.0, *)
    func esSyncClient(_ completion: @escaping () -> Void) -> es_return_t

    /// The kernel policy for missed authorization deadlines, or `nil` after logging a failure.
    @available(macOS 27.0, *)
    func esGetDeadlineMissMode() -> es_deadline_miss_mode_t?

    /// Changes the kernel policy without changing the library's own timeout handling. Logs failures.
    @available(macOS 27.0, *)
    func esSetDeadlineMissMode(_ mode: es_deadline_miss_mode_t) -> es_return_t

    /// The maximum deadline for an AUTH event, or `nil` after logging a failure.
    @available(macOS 27.0, *)
    func esGetDeadlineMaxMilliseconds(_ event: es_event_type_t) -> UInt32?

    /// Sets maximum deadlines for the supplied AUTH events. Logs failures, including an empty event array.
    /// The maximum cannot exceed the system default; lowering it below the minimum also lowers the minimum.
    @available(macOS 27.0, *)
    func esSetDeadlineMaxMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) -> es_return_t
#endif

    func esClearCache() -> es_clear_cache_result_t
    func esDeleteClient() -> es_return_t
    
    func esInvertMuting(_ muteType: es_mute_inversion_type_t) -> es_return_t
    
    func esMutingInverted(_ muteType: es_mute_inversion_type_t) -> es_mute_inverted_return_t
    
    // MARK: Mute by Process
    
    func esMuteProcess(_ auditToken: audit_token_t) -> es_return_t
    func esUnmuteProcess(_ auditToken: audit_token_t) -> es_return_t
    
    func esMuteProcessEvents(_ auditToken: audit_token_t, _ events: [es_event_type_t]) -> es_return_t
    
    func esUnmuteProcessEvents(_ auditToken: audit_token_t, _ events: [es_event_type_t]) -> es_return_t
    
    func esMutedProcesses() -> [audit_token_t: [es_event_type_t]]
    
    // MARK: Mute by Path
    
    func esMutePath(_ path: String, _ type: es_mute_path_type_t) -> es_return_t
    
    func esUnmutePath(_ path: String, _ type: es_mute_path_type_t) -> es_return_t
    
    func esMutePathEvents(_ path: String, _ type: es_mute_path_type_t, _ events: [es_event_type_t]) -> es_return_t
    
    func esUnmutePathEvents(_ path: String, _ type: es_mute_path_type_t, _ events: [es_event_type_t]) -> es_return_t
    
    func esUnmuteAllPaths() -> es_return_t
    
    func esUnmuteAllTargetPaths() -> es_return_t
    
    func esMutedPaths() -> [(path: String, type: es_mute_path_type_t, events: [es_event_type_t])]
}

extension OpaquePointer: ESNativeClient {
    public var native: OpaquePointer { self }
    
    public func esRespond(_ message: UnsafePointer<es_message_t>, flags: UInt32, cache: Bool) -> es_respond_result_t {
        switch message.pointee.event_type {
        // flags requests
        case ES_EVENT_TYPE_AUTH_OPEN:
            return es_respond_flags_result(self, message, flags, cache)
            
        // rest are auth requests
        default:
            return es_respond_auth_result(self, message, flags > 0 ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY, cache)
        }
    }
    
    public func esSubscribe(_ events: [es_event_type_t]) -> es_return_t {
        withValidRawEvents(events) { es_subscribe(self, $0, $1) }
    }
    
    public func esUnsubscribe(_ events: [es_event_type_t]) -> es_return_t {
        withValidRawEvents(events) { es_unsubscribe(self, $0, $1) }
    }
    
    public func esSubscriptions() -> [es_event_type_t] {
        var count = 0
        var subscriptions = UnsafeMutablePointer<es_event_type_t>(bitPattern: 0xdeadbeef)!
        let result = es_subscriptions(self, &count, &subscriptions)
        guard result == ES_RETURN_SUCCESS else {
            log.warning("Failed to query subscriptions: \(result)")
            return []
        }
        defer { free(subscriptions) }
        return Array(UnsafeBufferPointer(start: subscriptions, count: count))
    }

#if compiler(>=6.4)
    @available(macOS 27.0, *)
    public func esSyncClient(_ completion: @escaping () -> Void) -> es_return_t {
        es_sync_client(self, completion)
    }

    @available(macOS 27.0, *)
    public func esGetDeadlineMissMode() -> es_deadline_miss_mode_t? {
        var mode = ES_DEADLINE_MISS_MODE_KILL
        let result = es_get_deadline_miss_mode(self, &mode)
        guard result == ES_RETURN_SUCCESS else {
            log.warning("Failed to query deadline miss mode: \(result)")
            return nil
        }
        return mode
    }

    @available(macOS 27.0, *)
    public func esSetDeadlineMissMode(_ mode: es_deadline_miss_mode_t) -> es_return_t {
        let result = es_set_deadline_miss_mode(self, mode)
        if result != ES_RETURN_SUCCESS {
            log.warning("Failed to set deadline miss mode: \(result)")
        }
        return result
    }

    @available(macOS 27.0, *)
    public func esGetDeadlineMaxMilliseconds(_ event: es_event_type_t) -> UInt32? {
        var milliseconds: UInt32 = 0
        let result = es_get_deadline_max_milliseconds(self, event, &milliseconds)
        guard result == ES_RETURN_SUCCESS else {
            log.warning("Failed to query maximum deadline for \(event): \(result)")
            return nil
        }
        return milliseconds
    }

    @available(macOS 27.0, *)
    public func esSetDeadlineMaxMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) -> es_return_t {
        let result = events.withUnsafeBufferPointer { buffer in
            guard let events = buffer.baseAddress, !buffer.isEmpty else { return ES_RETURN_ERROR }
            return es_set_deadline_max_milliseconds(self, events, UInt32(buffer.count), milliseconds)
        }
        if result != ES_RETURN_SUCCESS {
            log.warning("Failed to set maximum deadline: \(result)")
        }
        return result
    }
#endif

    public func esClearCache() -> es_clear_cache_result_t {
        es_clear_cache(self)
    }
    
    public func esDeleteClient() -> es_return_t {
        es_delete_client(self)
    }
    
    public func esInvertMuting(_ muteType: es_mute_inversion_type_t) -> es_return_t {
        es_invert_muting(self, muteType)
    }
    
    public func esMutingInverted(_ muteType: es_mute_inversion_type_t) -> es_mute_inverted_return_t {
        es_muting_inverted(self, muteType)
    }
    
    public func esUnsubscribeAll() -> es_return_t {
        es_unsubscribe_all(self)
    }
    
    public func esMuteProcess(_ auditToken: audit_token_t) -> es_return_t {
        withUnsafePointer(to: auditToken) { es_mute_process(self, $0) }
    }
    
    public func esUnmuteProcess(_ auditToken: audit_token_t) -> es_return_t {
        withUnsafePointer(to: auditToken) { es_unmute_process(self, $0) }
    }
    
    public func esMuteProcessEvents(_ auditToken: audit_token_t, _ events: [es_event_type_t]) -> es_return_t {
        withValidRawEvents(events) { eventsPtr, eventsCount in
            withUnsafePointer(to: auditToken) { es_mute_process_events(self, $0, eventsPtr, eventsCount) }
        }
    }
    
    public func esUnmuteProcessEvents(_ auditToken: audit_token_t, _ events: [es_event_type_t]) -> es_return_t {
        withValidRawEvents(events) { eventsPtr, eventsCount in
            withUnsafePointer(to: auditToken) { es_unmute_process_events(self, $0, eventsPtr, eventsCount) }
        }
    }
    
    public func esMutedProcesses() -> [audit_token_t: [es_event_type_t]] {
        var processes: UnsafeMutablePointer<es_muted_processes_t>! = .init(bitPattern: 0xdeadbeef)!
        guard es_muted_processes_events(self, &processes) == ES_RETURN_SUCCESS else { return [:] }
        defer { es_release_muted_processes(processes) }
        return Array(UnsafeBufferPointer(start: processes.pointee.processes, count: processes.pointee.count))
            .reduce(into: [:]) {
                $0[$1.audit_token] = Array(UnsafeBufferPointer(start: $1.events, count: $1.event_count))
            }
    }
    
    public func esMutePath(_ path: String, _ type: es_mute_path_type_t) -> es_return_t {
        es_mute_path(self, path, type)
    }
    
    public func esUnmuteAllPaths() -> es_return_t {
        es_unmute_all_paths(self)
    }
    
    public func esUnmutePath(_ path: String, _ type: es_mute_path_type_t) -> es_return_t {
        es_unmute_path(self, path, type)
    }
    
    public func esMutePathEvents(_ path: String, _ type: es_mute_path_type_t, _ events: [es_event_type_t]) -> es_return_t {
        withValidRawEvents(events) {
            es_mute_path_events(self, path, type, $0, $1)
        }
    }
    
    public func esUnmutePathEvents(_ path: String, _ type: es_mute_path_type_t, _ events: [es_event_type_t]) -> es_return_t {
        withValidRawEvents(events) {
            es_unmute_path_events(self, path, type, $0, $1)
        }
    }
    
    public func esUnmuteAllTargetPaths() -> es_return_t {
        es_unmute_all_target_paths(self)
    }
    
    public func esMutedPaths() -> [(path: String, type: es_mute_path_type_t, events: [es_event_type_t])] {
        var paths = UnsafeMutablePointer<es_muted_paths_t>(bitPattern: 0xdeadbeef)!
        guard es_muted_paths_events(self, &paths) == ES_RETURN_SUCCESS else { return [] }
        defer { es_release_muted_paths(paths) }
        
        return Array(UnsafeBufferPointer(start: paths.pointee.paths, count: paths.pointee.count))
            .map {
                let events = Array(UnsafeBufferPointer(start: $0.events, count: $0.event_count))
                let path = $0.path.length > 0 ? String(cString: $0.path.data) : ""
                return (path, $0.type, events)
            }
    }
    
    private func withValidRawEvents<Count: BinaryInteger>(
        _ events: [es_event_type_t],
        body: (UnsafePointer<es_event_type_t>, Count) -> es_return_t
    ) -> es_return_t {
        let validEvents = Array(validESEvents(self).intersection(events))
        return validEvents.withUnsafeBufferPointer { buffer in
            if let ptr = buffer.baseAddress, !buffer.isEmpty {
                return body(ptr, Count(buffer.count))
            } else {
                return ES_RETURN_SUCCESS
            }
        }
    }
}
