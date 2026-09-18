@testable import SpellbookEndpointSecurity

import EndpointSecurity
import Foundation
import SpellbookFoundation
import SpellbookTestUtils
import XCTest

class ESServiceTests: XCTestCase, @unchecked Sendable {
    static let emitQueue = DispatchQueue(label: "ESClientTest.es_native_queue")
    var es: MockESClient!
    var service = ESService()
    
    override func setUp() {
        es = MockESClient()
        service.setClientFactory { [es] _ in try es.get() }
    }
    
    func test() {
        var controls: [ESSubscriptionControl] = []
        
        var s1 = ESSubscription()
        s1.events = [ES_EVENT_TYPE_NOTIFY_PTY_GRANT, ES_EVENT_TYPE_NOTIFY_SETUID]
        let q1 = DispatchQueue(label: "")
        s1.queue = q1
        let s1Exp = expectation(description: "s1 notify called")
        s1Exp.expectedFulfillmentCount = 2
        s1.notifyMessageHandler = { _ in
            dispatchPrecondition(condition: .onQueue(q1))
            s1Exp.fulfill()
        }
        controls.append(service.register(s1))
        
        var s2 = ESSubscription()
        s2.events = [ES_EVENT_TYPE_NOTIFY_PTY_GRANT, ES_EVENT_TYPE_NOTIFY_EXIT]
        let q2 = DispatchQueue(label: "")
        s2.queue = q2
        let s2Exp = expectation(description: "s2 notify called")
        s2Exp.expectedFulfillmentCount = 2
        s2.notifyMessageHandler = { _ in
            dispatchPrecondition(condition: .onQueue(q2))
            s2Exp.fulfill()
        }
        controls.append(service.register(s2))
        
        XCTAssertNoThrow(try controls.forEach { try $0.subscribe() })
        XCTAssertNoThrow(try service.activate())
        
        XCTAssertNotNil(service.unsafeClient as? MockESClient)
        XCTAssertTrue(service.unsafeClient === es)
        
        for event in [ES_EVENT_TYPE_NOTIFY_PTY_GRANT, ES_EVENT_TYPE_NOTIFY_SETUID, ES_EVENT_TYPE_NOTIFY_EXIT, ES_EVENT_TYPE_NOTIFY_PTY_CLOSE] {
            emitMessage(path: "test1", signingID: "", teamID: "", event: event)
        }
        
        waitForExpectations()
    }
    
    func test_subscribe_unsubscribe() throws {
        var s = ESSubscription()
        s.events = [ES_EVENT_TYPE_NOTIFY_PTY_GRANT, ES_EVENT_TYPE_NOTIFY_SETUID]
        @Atomic var exp = expectation(description: "notify should not called")
        exp.isInverted = true
        s.notifyMessageHandler = { _ in $exp.wrappedValue.fulfill() }
        let c = service.register(s)
        
        XCTAssertNoThrow(try service.activate())
        
        for event in [ES_EVENT_TYPE_NOTIFY_PTY_GRANT, ES_EVENT_TYPE_NOTIFY_SETUID] {
            emitMessage(path: "test1", signingID: "", teamID: "", event: event)
        }
        waitForExpectations()
        
        exp = expectation(description: "notify called")
        exp.expectedFulfillmentCount = 2
        try c.subscribe()
        for event in [ES_EVENT_TYPE_NOTIFY_PTY_GRANT, ES_EVENT_TYPE_NOTIFY_SETUID] {
            emitMessage(path: "test1", signingID: "", teamID: "", event: event)
        }
        waitForExpectations()
        
        exp = expectation(description: "notify should not called")
        exp.isInverted = true
        try c.unsubscribe()
        for event in [ES_EVENT_TYPE_NOTIFY_PTY_GRANT, ES_EVENT_TYPE_NOTIFY_SETUID] {
            emitMessage(path: "test1", signingID: "", teamID: "", event: event)
        }
        waitForExpectations()
    }
    
    func test_subscribe_unsubscribe_multiclient() throws {
        var s1 = ESSubscription()
        s1.events = [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_CLOSE]
        let c1 = service.register(s1)
        
        var s2 = ESSubscription()
        s2.events = [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_EXIT]
        let c2 = service.register(s2)
        
        try service.activate()
        
        XCTAssertEqual(es.subscribedEvents, [])
        
        try c1.subscribe()
        XCTAssertEqual(es.subscribedEvents, [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_CLOSE])
        
        try c2.subscribe()
        XCTAssertEqual(es.subscribedEvents, [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_CLOSE, ES_EVENT_TYPE_NOTIFY_EXIT])
        
        try c1.unsubscribe()
        XCTAssertEqual(es.subscribedEvents, [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_EXIT])
        
        try c2.unsubscribe()
        XCTAssertEqual(es.subscribedEvents, [])
    }

    func test_subscriptionsForwardedAndInactiveFails() throws {
        XCTAssertThrowsError(try service.subscriptions())

        try service.activate()
        es.subscribedEvents = [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_EXEC]
        XCTAssertEqual(Set(try service.subscriptions()), es.subscribedEvents)

        es.subscriptionsError = MockESClient.MockError.requestedFailure
        XCTAssertThrowsError(try service.subscriptions())

        service.invalidate()
        XCTAssertThrowsError(try service.subscriptions())
    }

#if compiler(>=6.4)
    @available(macOS 27.0, *)
    func test_deadlineOperationsForwardAndReportErrors() throws {
        XCTAssertThrowsError(try service.getDeadlineMissMode())
        XCTAssertThrowsError(try service.setDeadlineMissMode(ES_DEADLINE_MISS_MODE_FAIL_CLOSED))
        XCTAssertThrowsError(try service.getDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_OPEN))
        XCTAssertThrowsError(try service.setDeadlineMaxMilliseconds([ES_EVENT_TYPE_AUTH_OPEN], milliseconds: 250))

        try service.activate()
        XCTAssertEqual(try service.getDeadlineMissMode(), ES_DEADLINE_MISS_MODE_KILL)
        try service.setDeadlineMissMode(ES_DEADLINE_MISS_MODE_FAIL_CLOSED)
        XCTAssertEqual(es.deadlineMissMode, ES_DEADLINE_MISS_MODE_FAIL_CLOSED)

        let events = [ES_EVENT_TYPE_AUTH_OPEN, ES_EVENT_TYPE_AUTH_EXEC]
        try service.setDeadlineMaxMilliseconds(events, milliseconds: 250)
        XCTAssertEqual(try service.getDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_OPEN), 250)
        XCTAssertEqual(es.deadlineMaxMilliseconds[ES_EVENT_TYPE_AUTH_EXEC], 250)

        es.deadlineMissModeError = MockESClient.MockError.requestedFailure
        XCTAssertThrowsError(try service.getDeadlineMissMode())
        XCTAssertThrowsError(try service.setDeadlineMissMode(ES_DEADLINE_MISS_MODE_FAIL_OPEN))
        es.deadlineMaxError = MockESClient.MockError.requestedFailure
        XCTAssertThrowsError(try service.getDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_OPEN))
        XCTAssertThrowsError(try service.setDeadlineMaxMilliseconds(events, milliseconds: 100))
    }
#endif
    
    func test_controlDeinit() {
        var s = ESSubscription()
        s.events = [ES_EVENT_TYPE_NOTIFY_PTY_GRANT]
        @Atomic var exp = expectation(description: "notify called")
        s.notifyMessageHandler = { _ in $exp.wrappedValue.fulfill() }
        var c: ESSubscriptionControl? = service.register(s)
        XCTAssertNoThrow(try c?.subscribe())
        XCTAssertNoThrow(try service.activate())
        
        emitMessage(path: "test1", signingID: "", teamID: "", event: ES_EVENT_TYPE_NOTIFY_PTY_GRANT)
        waitForExpectations()
        
        exp = expectation(description: "notify should not called")
        exp.isInverted = true
        c = nil
        
        emitMessage(path: "test1", signingID: "", teamID: "", event: ES_EVENT_TYPE_NOTIFY_PTY_GRANT)
        waitForExpectations()
    }
    
    private func emitMessage(path: String, signingID: String, teamID: String, event: es_event_type_t) {
        let message = createMessage(path: path, signingID: signingID, teamID: teamID, event: event, isAuth: false)
        Self.emitQueue.async { [self] in
            let messagePtr = ESMessagePtr(unowned: message.wrappedValue)
            let process = try! messagePtr.converted().process
            _ = es.pathInterestHandler?(process)
            _ = es.notifyMessageHandler?(messagePtr)
            Self.emitQueue.asyncAfter(deadline: .now() + 1) { message.reset() } 
        }
    }
}
