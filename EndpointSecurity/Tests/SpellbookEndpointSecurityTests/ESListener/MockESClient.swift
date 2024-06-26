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
    
    var subscriptions: Set<es_event_type_t> = []
    
    func subscribe(_ events: [es_event_type_t]) {
        subscriptions.formUnion(events)
    }
    
    func unsubscribe(_ events: [es_event_type_t]) {
        subscriptions.subtract(events)
    }
    
    func unsubscribeAll() {
        subscriptions.removeAll()
    }
    
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
