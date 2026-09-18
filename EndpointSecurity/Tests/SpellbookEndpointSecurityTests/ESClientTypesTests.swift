@testable import SpellbookEndpointSecurity

import EndpointSecurity
import Foundation
import SpellbookFoundation
import SpellbookTestUtils
import XCTest

class ESClientTypesTests: XCTestCase {
    func test_ESAuthResult_flags() {
        XCTAssertEqual(ESAuthResult.auth(true), .flags(.max))
        XCTAssertEqual(ESAuthResult.auth(false), .flags(0))
    }
    
    func test_ESAuthResult_equal() {
        XCTAssertEqual(ESAuthResult.flags(0), .auth(false))
        XCTAssertEqual(ESAuthResult.flags(.max), .auth(true))
    }
    
    func test_ESAuthResolution_combine() {
        XCTAssertEqual(
            ESAuthResolution.combine([]),
            ESAuthResolution(result: .auth(true), cache: false)
        )
        XCTAssertEqual(
            ESAuthResolution.combine([
                ESAuthResolution(result: .flags(123), cache: true),
            ]),
            ESAuthResolution(result: .flags(123), cache: true)
        )
        XCTAssertEqual(
            ESAuthResolution.combine([
                ESAuthResolution(result: .auth(true), cache: false),
                ESAuthResolution(result: .flags(123), cache: true),
            ]),
            ESAuthResolution(result: .flags(123), cache: false)
        )
        XCTAssertEqual(
            ESAuthResolution.combine([
                ESAuthResolution(result: .auth(false), cache: false),
                ESAuthResolution(result: .flags(123), cache: true),
            ]),
            ESAuthResolution(result: .auth(false), cache: false)
        )
        XCTAssertEqual(
            ESAuthResolution.combine([
                ESAuthResolution(result: .auth(true), cache: false),
                ESAuthResolution(result: .flags(0), cache: true),
            ]),
            ESAuthResolution(result: .auth(false), cache: false)
        )
    }
    
    func test_ESEventSet_all_coversWholeRange() {
        let all = ESEventSet.all.events
        XCTAssertEqual(all.count, Int(ES_EVENT_TYPE_LAST.rawValue))
        XCTAssertTrue(all.contains(ES_EVENT_TYPE_AUTH_EXEC))
        XCTAssertTrue(all.contains(es_event_type_t(rawValue: ES_EVENT_TYPE_LAST.rawValue - 1)))
        XCTAssertFalse(all.contains(ES_EVENT_TYPE_LAST))
        
        XCTAssertEqual(ESEventSet.all.inverted(), .empty)
        XCTAssertEqual(ESEventSet.empty.inverted(), .all)
    }
    
    /// Guards against SDK updates that add event types the library does not know about yet.
    ///
    /// Every `es_event_type_t` declared by the SDK being compiled against must be named,
    /// reserved slots included. A failure here means a newer SDK introduced event types
    /// that still have to be adopted.
    func test_ESEventType_allHaveNames() {
        let unnamed = (0..<ES_EVENT_TYPE_LAST.rawValue)
            .map(es_event_type_t.init(rawValue:))
            .filter { $0.description.hasPrefix("unknown") }
        XCTAssertEqual(unnamed.map(\.rawValue), [], "es_event_type_t values missing a name")
    }
    
    func test_ESInterest() {
        XCTAssertEqual(ESInterest.listen(), ESInterest(events: ESEventSet.all.events))
        XCTAssertEqual(ESInterest.listen([ES_EVENT_TYPE_NOTIFY_OPEN]), ESInterest(events: [ES_EVENT_TYPE_NOTIFY_OPEN]))
        
        XCTAssertEqual(ESInterest.ignore(), ESInterest(events: []))
        XCTAssertEqual(
            ESInterest.ignore([ES_EVENT_TYPE_NOTIFY_OPEN]),
            ESInterest(events: ESEventSet(events: [ES_EVENT_TYPE_NOTIFY_OPEN]).inverted().events)
        )
    }
    
    func test_ESInterest_combine() {
        XCTAssertEqual(ESInterest.combine(.permissive, []), nil)
        XCTAssertEqual(ESInterest.combine(.restrictive, []), nil)
        
        XCTAssertEqual(ESInterest.combine(.permissive, [.listen()]), ESInterest(events: ESEventSet.all.events))
        XCTAssertEqual(ESInterest.combine(.restrictive, [.listen()]), ESInterest(events: ESEventSet.all.events))
        
        XCTAssertEqual(ESInterest.combine(.permissive, [.ignore()]), ESInterest(events: []))
        XCTAssertEqual(ESInterest.combine(.restrictive, [.ignore()]), ESInterest(events: []))
        
        XCTAssertEqual(
            ESInterest.combine(.permissive, [
                .listen([ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_CLOSE]),
                .listen([ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_EXEC]),
            ]),
            ESInterest(events: [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_CLOSE, ES_EVENT_TYPE_NOTIFY_EXEC])
        )
        XCTAssertEqual(
            ESInterest.combine(.restrictive, [
                .listen([ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_CLOSE]),
                .listen([ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_EXEC]),
            ]),
            ESInterest(events: [ES_EVENT_TYPE_NOTIFY_OPEN])
        )
    }
    
    func test_ESMultipleResolution() {
        let count = 3
        let exp = expectation(description: "")
        let group = ESMultipleResolution(count: count) {
            XCTAssertEqual($0, .allowOnce)
            exp.fulfill()
        }
        (0..<count).forEach { group.resolve(.allowOnce, by: $0, name: "") }
        
        waitForExpectations()
    }
}
