@testable import SpellbookEndpointSecurity

import EndpointSecurity
import Foundation
import XCTest

final class ESClientOperationTests: XCTestCase {
    func test_subscriptionsUseNativeState() throws {
        let native = MockNativeClient()
        let client: any ESClientProtocol = try makeClient(native)
        try client.subscribe([ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_OPEN])
        XCTAssertEqual(Set(try client.subscriptions()), [ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_OPEN])
        try client.unsubscribe([ES_EVENT_TYPE_NOTIFY_OPEN])
        XCTAssertEqual(try client.subscriptions(), [ES_EVENT_TYPE_NOTIFY_EXEC])
    }

#if compiler(>=6.4)
    @available(macOS 27.0, *)
    func test_deadlinesForwardValuesAndTranslateFailures() throws {
        let native = MockNativeClient()
        let client: any ESClientProtocol = try makeClient(native)
        client.name = "deadline-test"

        try client.setDeadlineMissMode(ES_DEADLINE_MISS_MODE_FAIL_CLOSED)
        XCTAssertEqual(try client.getDeadlineMissMode(), ES_DEADLINE_MISS_MODE_FAIL_CLOSED)
        try client.setDeadlineMaxMilliseconds([ES_EVENT_TYPE_AUTH_OPEN, ES_EVENT_TYPE_AUTH_EXEC], milliseconds: 200)
        XCTAssertEqual(try client.getDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_OPEN), 200)
        XCTAssertEqual(try client.getDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_EXEC), 200)

        native.deadlineMissModeGetFails = true
        assertNativeError(try client.getDeadlineMissMode(), action: "getDeadlineMissMode")
        native.deadlineMissModeSetResult = ES_RETURN_ERROR
        assertNativeError(try client.setDeadlineMissMode(ES_DEADLINE_MISS_MODE_KILL), action: "setDeadlineMissMode")
        native.deadlineMaxGetFails.insert(ES_EVENT_TYPE_AUTH_OPEN)
        assertNativeError(try client.getDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_OPEN), action: "getDeadlineMaxMilliseconds")
        native.deadlineMaxSetResult = ES_RETURN_ERROR
        assertNativeError(
            try client.setDeadlineMaxMilliseconds([ES_EVENT_TYPE_AUTH_OPEN], milliseconds: 50),
            action: "setDeadlineMaxMilliseconds"
        )
        XCTAssertEqual(native.deadlineMaxMilliseconds[ES_EVENT_TYPE_AUTH_OPEN], 200)
    }
#endif

    private func makeClient(_ native: MockNativeClient) throws -> ESClient {
        try ESClient.test { client, _ in
            client = native
            return ES_NEW_CLIENT_RESULT_SUCCESS
        }
    }

    private func assertNativeError<T>(
        _ action: @autoclosure () throws -> T,
        action name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try action(), file: file, line: line) { error in
            let error = error as? ESError<es_return_t>
            XCTAssertEqual(error?.action, name, file: file, line: line)
            XCTAssertEqual(error?.result, ES_RETURN_ERROR, file: file, line: line)
            XCTAssertEqual(error?.client, "deadline-test", file: file, line: line)
        }
    }
}
