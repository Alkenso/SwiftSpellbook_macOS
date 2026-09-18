//  MIT License
//
//  Copyright (c) 2023 Alkenso (Vladimir Vashurkin)
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

import Combine
import EndpointSecurity
import Foundation

public protocol ESClientProtocol<Message>: AnyObject {
    associatedtype Message
    
    var name: String { get set }
    var queue: DispatchQueue? { get set }
    
    var authMessageHandler: ((Message, @escaping (ESAuthResolution) -> Void) -> Void)? { get set }
    var notifyMessageHandler: ((Message) -> Void)? { get set }
    
    func subscribe(_ events: [es_event_type_t]) throws
    func unsubscribe(_ events: [es_event_type_t]) throws
    func unsubscribeAll() throws
    func subscriptions() throws -> [es_event_type_t]
    func clearCache() throws
    
    var pathInterestHandler: ((ESProcess) -> ESInterest)? { get set }
    func clearPathInterestCache() throws
    
    func mute(process rule: ESMuteProcessRule, events: ESEventSet) throws
    func unmute(process rule: ESMuteProcessRule, events: ESEventSet) throws
    func unmuteAllProcesses() throws
    func mute(path: String, type: es_mute_path_type_t, events: ESEventSet) throws
    func unmute(path: String, type: es_mute_path_type_t, events: ESEventSet) throws
    func unmuteAllPaths() throws
    func unmuteAllTargetPaths() throws
    
    func invertMuting(_ muteType: es_mute_inversion_type_t) throws
    func mutingInverted(_ muteType: es_mute_inversion_type_t) throws -> Bool
    
#if compiler(>=6.4)
    @available(macOS 27.0, *)
    func getDeadlineMissMode() throws -> es_deadline_miss_mode_t

    /// Changes the kernel policy without changing the library's own timeout handling.
    @available(macOS 27.0, *)
    func setDeadlineMissMode(_ mode: es_deadline_miss_mode_t) throws

    @available(macOS 27.0, *)
    func getDeadlineMaxMilliseconds(_ event: es_event_type_t) throws -> UInt32

    /// Sets the maximum deadline for the supplied AUTH events. Empty arrays are rejected.
    /// Lowering a maximum below its minimum also lowers the minimum.
    @available(macOS 27.0, *)
    func setDeadlineMaxMilliseconds(_ events: [es_event_type_t], milliseconds: UInt32) throws
#endif
}

extension ESClientProtocol {
    internal func tryAction<T: RawRepresentable & Equatable & Codable & Sendable>(
        _ action: String,
        success: T,
        body: () throws -> T
    ) throws {
        let result = try body()
        if result != success {
            throw ESError<T>(action, result: result, client: name)
        }
    }
}
