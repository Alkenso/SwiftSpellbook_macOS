import EndpointSecurity
import SpellbookFoundation

private let log = SpellbookLogger.internalLog(.client)

/// Native operations requiring a client created with `es_new_descendants_client`.
///
/// Conformance does not verify how the underlying pointer was created or take ownership of it.
/// Calling these methods on an ordinary client fails through the native API.
public protocol ESNativeDescendantClient: ESNativeClient {
    /// The minimum deadline for an AUTH event, or `nil` after logging a failure.
    func esGetDeadlineMinMilliseconds(_ event: es_event_type_t) -> UInt32?

    /// Sets minimum deadlines for the supplied AUTH events. Logs failures, including an empty event array.
    /// Bootstrap check-in and look-up AUTH events are not supported.
    /// Raising a minimum above the maximum also raises the maximum, even beyond the system default.
    func esSetDeadlineMinMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) -> es_return_t
}

#if compiler(>=6.4)
@available(macOS 27.0, *)
extension OpaquePointer: ESNativeDescendantClient {
    public func esGetDeadlineMinMilliseconds(_ event: es_event_type_t) -> UInt32? {
        var milliseconds: UInt32 = 0
        let result = es_get_deadline_min_milliseconds(self, event, &milliseconds)
        guard result == ES_RETURN_SUCCESS else {
            log.warning("Failed to query minimum deadline for \(event): \(result)")
            return nil
        }
        return milliseconds
    }

    public func esSetDeadlineMinMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) -> es_return_t {
        let result = events.withUnsafeBufferPointer { buffer in
            guard let events = buffer.baseAddress, !buffer.isEmpty else { return ES_RETURN_ERROR }
            return es_set_deadline_min_milliseconds(self, events, UInt32(buffer.count), milliseconds)
        }
        if result != ES_RETURN_SUCCESS {
            log.warning("Failed to set minimum deadline: \(result)")
        }
        return result
    }
}
#endif
