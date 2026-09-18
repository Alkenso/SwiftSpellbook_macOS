import SpellbookEndpointSecurity

import EndpointSecurity
import Foundation

class MockESClient: ESClientProtocol {
    var name: String = "MockESClient"
    
    var config = ESClient.Config()
    var queue: DispatchQueue?
    
    var authMessageHandler: ((ESMessagePtr, @escaping (ESAuthResolution) -> Void) -> Void)?
    var postAuthMessageHandler: ((ESMessagePtr, ESClient.ResponseInfo) -> Void)?
    var notifyMessageHandler: ((ESMessagePtr) -> Void)?
    
    enum MockError: Error {
        case requestedFailure
    }

    var subscribedEvents: Set<es_event_type_t> = []
    var subscriptionsError: Error?
    
    func subscribe(_ events: [es_event_type_t]) {
        subscribedEvents.formUnion(events)
    }
    
    func unsubscribe(_ events: [es_event_type_t]) {
        subscribedEvents.subtract(events)
    }
    
    func unsubscribeAll() {
        subscribedEvents.removeAll()
    }

    func subscriptions() throws -> [es_event_type_t] {
        if let subscriptionsError { throw subscriptionsError }
        return Array(subscribedEvents)
    }

#if compiler(>=6.4)
    var pendingSyncCompletion: ((Result<Void, Error>) -> Void)?
    var deadlineMissMode = ES_DEADLINE_MISS_MODE_KILL
    var deadlineMissModeError: Error?
    var deadlineMaxMilliseconds: [es_event_type_t: UInt32] = [:]
    var deadlineMaxError: Error?

    @available(macOS 27.0, *)
    func sync(_ completion: @escaping (Result<Void, Error>) -> Void) {
        pendingSyncCompletion = completion
    }

    @available(macOS 27.0, *)
    func getDeadlineMissMode() throws -> es_deadline_miss_mode_t {
        if let deadlineMissModeError { throw deadlineMissModeError }
        return deadlineMissMode
    }

    @available(macOS 27.0, *)
    func setDeadlineMissMode(_ mode: es_deadline_miss_mode_t) throws {
        if let deadlineMissModeError { throw deadlineMissModeError }
        deadlineMissMode = mode
    }

    @available(macOS 27.0, *)
    func getDeadlineMaxMilliseconds(_ event: es_event_type_t) throws -> UInt32 {
        if let deadlineMaxError { throw deadlineMaxError }
        guard let milliseconds = deadlineMaxMilliseconds[event] else { throw MockError.requestedFailure }
        return milliseconds
    }

    @available(macOS 27.0, *)
    func setDeadlineMaxMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) throws {
        if let deadlineMaxError { throw deadlineMaxError }
        for event in events {
            deadlineMaxMilliseconds[event] = milliseconds
        }
    }
#endif
    
    func clearCache() {}
    
    var pathInterestHandler: ((ESProcess) -> ESInterest)?
    
    func clearPathInterestCache() {}
    
    func mute(process rule: ESMuteProcessRule, events: ESEventSet) {}
    
    func unmute(process rule: ESMuteProcessRule, events: ESEventSet) {}
    
    func unmuteAllProcesses() {}
    
    func mute(path: String, type: es_mute_path_type_t, events: ESEventSet) {}
    
    func unmute(path: String, type: es_mute_path_type_t, events: ESEventSet) {}
    
    func unmuteAllPaths() {}
    
    func unmuteAllTargetPaths() {}
    
    func invertMuting(_ muteType: es_mute_inversion_type_t) {}
    
    func mutingInverted(_ muteType: es_mute_inversion_type_t) -> Bool {
        false
    }
}
