import EndpointSecurity
import Foundation
import SpellbookFoundation

#if compiler(>=6.4)

/// `ESClient` scoped to the descendants of the calling process.
///
/// Unlike `ESClient`, it requires neither root privileges nor TCC approval,
/// but the `com.apple.developer.endpoint-security.client` entitlement is still needed.
///
/// - Note: See `ESDescendantClientProtocol` for the scoping rules.
@available(macOS 27.0, *)
public final class ESDescendantsClient: ESClient, ESDescendantsClientProtocol, @unchecked Sendable {
    internal override class var esNew: (
        name: String,
        create: (
            UnsafeMutablePointer<OpaquePointer?>,
            @escaping es_handler_block_t
        ) -> es_new_client_result_t
    ) {
        ("es_new_descendants_client", es_new_descendants_client)
    }

    public func getDeadlineMinMilliseconds(_ event: es_event_type_t) throws -> UInt32 {
        guard let milliseconds = client.esGetDeadlineMinMilliseconds(event) else {
            throw ESError("getDeadlineMinMilliseconds", result: ES_RETURN_ERROR, client: name)
        }
        return milliseconds
    }

    public func setDeadlineMinMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) throws {
        try tryAction("setDeadlineMinMilliseconds", success: ES_RETURN_SUCCESS) {
            client.esSetDeadlineMinMilliseconds(events, milliseconds: milliseconds)
        }
    }

    // MARK: Private
    private var client: ESNativeDescendantClient { unsafeNativeClient }
}

#endif
