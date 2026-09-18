import EndpointSecurity
import Foundation
import SpellbookEndpointSecurity

class MockNativeClient: ESNativeClient {
    struct MutePathKey: Hashable {
        var path: String
        var type: es_mute_path_type_t
    }
    
    var subscriptions: Set<es_event_type_t> = []
    var subscriptionsQueryFails = false
    var invertMuting: [es_mute_inversion_type_t: Bool] = [:]
    var pathMutes: [String: Set<es_event_type_t>] = [:]
    var prefixMutes: [String: Set<es_event_type_t>] = [:]
    var processMutes: [audit_token_t: Set<es_event_type_t>] = [:]
    var responses: [UInt64: ESAuthResolution] = [:]
    
    var native: OpaquePointer { OpaquePointer(bitPattern: 0xdeadbeef)! }
    
    func esRespond(_ message: UnsafePointer<es_message_t>, flags: UInt32, cache: Bool) -> es_respond_result_t {
        responses[message.pointee.global_seq_num] = ESAuthResolution(result: .flags(flags), cache: cache)
        return ES_RESPOND_RESULT_SUCCESS
    }
    
    func esSubscribe(_ events: [es_event_type_t]) -> es_return_t {
        subscriptions.formUnion(events)
        return ES_RETURN_SUCCESS
    }
    
    func esUnsubscribe(_ events: [es_event_type_t]) -> es_return_t {
        subscriptions.subtract(events)
        return ES_RETURN_SUCCESS
    }
    
    func esUnsubscribeAll() -> es_return_t {
        subscriptions.removeAll()
        return ES_RETURN_SUCCESS
    }

    func esSubscriptions() -> [es_event_type_t] {
        subscriptionsQueryFails ? [] : Array(subscriptions)
    }

#if compiler(>=6.4)
    var syncResult = ES_RETURN_SUCCESS

    var pendingSyncCompletion: (() -> Void)?

    var deadlineMissMode = ES_DEADLINE_MISS_MODE_KILL

    var deadlineMissModeGetFails = false

    var deadlineMissModeSetResult = ES_RETURN_SUCCESS

    var deadlineMaxMilliseconds: [es_event_type_t: UInt32] = [:]

    var deadlineMaxGetFails: Set<es_event_type_t> = []

    var deadlineMaxSetResult = ES_RETURN_SUCCESS

    @available(macOS 27.0, *)
    func esSyncClient(_ completion: @escaping () -> Void) -> es_return_t {
        guard syncResult == ES_RETURN_SUCCESS else { return syncResult }
        pendingSyncCompletion = completion
        return ES_RETURN_SUCCESS
    }

    @available(macOS 27.0, *)
    func esGetDeadlineMissMode() -> es_deadline_miss_mode_t? {
        deadlineMissModeGetFails ? nil : deadlineMissMode
    }

    @available(macOS 27.0, *)
    func esSetDeadlineMissMode(_ mode: es_deadline_miss_mode_t) -> es_return_t {
        guard deadlineMissModeSetResult == ES_RETURN_SUCCESS else { return deadlineMissModeSetResult }
        deadlineMissMode = mode
        return ES_RETURN_SUCCESS
    }

    @available(macOS 27.0, *)
    func esGetDeadlineMaxMilliseconds(_ event: es_event_type_t) -> UInt32? {
        guard !deadlineMaxGetFails.contains(event) else { return nil }
        return deadlineMaxMilliseconds[event]
    }

    @available(macOS 27.0, *)
    func esSetDeadlineMaxMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) -> es_return_t {
        guard !events.isEmpty, deadlineMaxSetResult == ES_RETURN_SUCCESS else { return ES_RETURN_ERROR }
        events.forEach { deadlineMaxMilliseconds[$0] = milliseconds }
        return ES_RETURN_SUCCESS
    }
#endif
    
    func esClearCache() -> es_clear_cache_result_t {
        return ES_CLEAR_CACHE_RESULT_SUCCESS
    }
    
    func esInvertMuting(_ muteType: es_mute_inversion_type_t) -> es_return_t {
        invertMuting[muteType, default: false].toggle()
        return ES_RETURN_SUCCESS
    }
    
    func esMutingInverted(_ muteType: es_mute_inversion_type_t) -> es_mute_inverted_return_t {
        return invertMuting[muteType, default: false] ? ES_MUTE_INVERTED : ES_MUTE_NOT_INVERTED
    }
    
    func esDeleteClient() -> es_return_t {
        return ES_RETURN_SUCCESS
    }
    
    func esMutePath(_ path: String, _ type: es_mute_path_type_t) -> es_return_t {
        if type == ES_MUTE_PATH_TYPE_LITERAL {
            pathMutes[path, default: []] = ESEventSet.all.events
        } else {
            prefixMutes[path, default: []] = ESEventSet.all.events
        }
        return ES_RETURN_SUCCESS
    }
    
    func esUnmutePath(_ path: String, _ type: es_mute_path_type_t) -> es_return_t {
        if type == ES_MUTE_PATH_TYPE_LITERAL {
            pathMutes.removeValue(forKey: path)
        } else {
            prefixMutes.removeValue(forKey: path)
        }
        return ES_RETURN_SUCCESS
    }
    
    func esMutePathEvents(_ path: String, _ type: es_mute_path_type_t, _ events: [es_event_type_t]) -> es_return_t {
        if type == ES_MUTE_PATH_TYPE_LITERAL {
            pathMutes[path, default: []].formUnion(events)
        } else {
            prefixMutes[path, default: []].formUnion(events)
        }
        return ES_RETURN_SUCCESS
    }
    
    func esUnmutePathEvents(_ path: String, _ type: es_mute_path_type_t, _ events: [es_event_type_t]) -> es_return_t {
        if type == ES_MUTE_PATH_TYPE_LITERAL {
            pathMutes[path, default: []].subtract(events)
        } else {
            prefixMutes[path, default: []].subtract(events)
        }
        return ES_RETURN_SUCCESS
    }
    
    func esUnmuteAllPaths() -> es_return_t {
        pathMutes.removeAll()
        return ES_RETURN_SUCCESS
    }
    
    func esMutedPaths() -> [(path: String, type: es_mute_path_type_t, events: [es_event_type_t])] {
        pathMutes.map { ($0, ES_MUTE_PATH_TYPE_LITERAL, Array($1)) } + prefixMutes.map { ($0, ES_MUTE_PATH_TYPE_PREFIX, Array($1)) }
    }
    
    func esUnmuteAllTargetPaths() -> es_return_t {
        return ES_RETURN_SUCCESS
    }
    
    func esMuteProcess(_ auditToken: audit_token_t) -> es_return_t {
        processMutes[auditToken] = ESEventSet.all.events
        return ES_RETURN_SUCCESS
    }
    
    func esUnmuteProcess(_ auditToken: audit_token_t) -> es_return_t {
        processMutes.removeValue(forKey: auditToken)
        return ES_RETURN_SUCCESS
    }
    
    func esMuteProcessEvents(_ auditToken: audit_token_t, _ events: [es_event_type_t]) -> es_return_t {
        processMutes[auditToken, default: []].formUnion(events)
        return ES_RETURN_SUCCESS
    }
    
    func esUnmuteProcessEvents(_ auditToken: audit_token_t, _ events: [es_event_type_t]) -> es_return_t {
        processMutes[auditToken]?.subtract(events)
        return ES_RETURN_SUCCESS
    }
    
    func esMutedProcesses() -> [audit_token_t: [es_event_type_t]] {
        processMutes.mapValues { Array($0) }
    }
}

#if compiler(>=6.4)
@available(macOS 27.0, *)
final class MockNativeDescendantClient: MockNativeClient, ESNativeDescendantClient {
    var deadlineMinMilliseconds: [es_event_type_t: UInt32] = [:]
    var deadlineMinGetFails: Set<es_event_type_t> = []
    var deadlineMinSetResult = ES_RETURN_SUCCESS

    func esGetDeadlineMinMilliseconds(_ event: es_event_type_t) -> UInt32? {
        guard !deadlineMinGetFails.contains(event) else { return nil }
        return deadlineMinMilliseconds[event]
    }

    func esSetDeadlineMinMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) -> es_return_t {
        guard !events.isEmpty, deadlineMinSetResult == ES_RETURN_SUCCESS else { return ES_RETURN_ERROR }
        events.forEach { deadlineMinMilliseconds[$0] = milliseconds }
        return ES_RETURN_SUCCESS
    }
}
#endif
