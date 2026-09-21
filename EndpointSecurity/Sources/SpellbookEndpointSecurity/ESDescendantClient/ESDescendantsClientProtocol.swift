import EndpointSecurity
import Foundation

/// A client scoped to the descendants of the calling process.
///
/// The client receives NOTIFY events for the calling process and AUTH + NOTIFY events for the whole
/// subtree rooted at it, including descendants that exist when the client is created.
/// All other processes are invisible.
///
/// Muting by path and by target path works as usual. Muting by process works only for processes
/// already in the subtree: rules for any other process are rejected by the native API.
public protocol ESDescendantsClientProtocol<Message>: ESClientProtocol {
    /// The minimum deadline for the given AUTH event.
    func getDeadlineMinMilliseconds(_ event: es_event_type_t) throws -> UInt32

    /// Sets the minimum deadline for the supplied AUTH events. Empty arrays are rejected.
    /// Bootstrap check-in and look-up AUTH events are not supported.
    /// Raising a minimum above the maximum also raises the maximum, even beyond the system default.
    func setDeadlineMinMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) throws
}
