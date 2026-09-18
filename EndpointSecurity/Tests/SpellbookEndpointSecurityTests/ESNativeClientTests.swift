import EndpointSecurity
import SpellbookEndpointSecurity
import XCTest

final class ESNativeClientTests: XCTestCase {
    func test_subscriptionQueryTracksNativeOperationsAndFailure() {
        let mock = MockNativeClient()
        let client: any ESNativeClient = mock

        XCTAssertEqual(client.esSubscribe([ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_EXEC]), ES_RETURN_SUCCESS)
        XCTAssertEqual(Set(client.esSubscriptions()), [ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_EXEC])

        mock.subscriptionsQueryFails = true
        XCTAssertTrue(client.esSubscriptions().isEmpty)
        mock.subscriptionsQueryFails = false
        XCTAssertEqual(client.esUnsubscribe([ES_EVENT_TYPE_NOTIFY_EXEC]), ES_RETURN_SUCCESS)
        XCTAssertEqual(client.esSubscriptions(), [ES_EVENT_TYPE_NOTIFY_OPEN])

        XCTAssertEqual(client.esUnsubscribeAll(), ES_RETURN_SUCCESS)
        XCTAssertTrue(client.esSubscriptions().isEmpty)
    }
}

#if compiler(>=6.4)
@available(macOS 27.0, *)
final class ESNativeDeadlineMockTests: XCTestCase {
    func test_syncCallbackIsDeferredAndFailureDoesNotQueueIt() {
        let mock = MockNativeClient()
        let client: any ESNativeClient = mock
        var callbackCount = 0

        XCTAssertEqual(client.esSyncClient { callbackCount += 1 }, ES_RETURN_SUCCESS)
        XCTAssertEqual(callbackCount, 0)
        mock.pendingSyncCompletion?()
        XCTAssertEqual(callbackCount, 1)

        mock.pendingSyncCompletion = nil
        mock.syncResult = ES_RETURN_ERROR
        XCTAssertEqual(client.esSyncClient { callbackCount += 1 }, ES_RETURN_ERROR)
        XCTAssertNil(mock.pendingSyncCompletion)
        XCTAssertEqual(callbackCount, 1)
    }

    func test_deadlineMissModeReturnsFailureWithoutChangingPriorState() {
        let mock = MockNativeClient()
        let client: any ESNativeClient = mock

        XCTAssertEqual(client.esGetDeadlineMissMode(), ES_DEADLINE_MISS_MODE_KILL)
        XCTAssertEqual(client.esSetDeadlineMissMode(ES_DEADLINE_MISS_MODE_FAIL_CLOSED), ES_RETURN_SUCCESS)
        XCTAssertEqual(client.esGetDeadlineMissMode(), ES_DEADLINE_MISS_MODE_FAIL_CLOSED)

        mock.deadlineMissModeSetResult = ES_RETURN_ERROR
        XCTAssertEqual(client.esSetDeadlineMissMode(ES_DEADLINE_MISS_MODE_FAIL_OPEN), ES_RETURN_ERROR)
        XCTAssertEqual(client.esGetDeadlineMissMode(), ES_DEADLINE_MISS_MODE_FAIL_CLOSED)

        mock.deadlineMissModeGetFails = true
        XCTAssertNil(client.esGetDeadlineMissMode())
    }

    func test_maximumDeadlineUpdatesSelectedEventsAndReportsFailures() {
        let mock = MockNativeClient()
        let client: any ESNativeClient = mock
        mock.deadlineMaxMilliseconds[ES_EVENT_TYPE_AUTH_RENAME] = 800

        XCTAssertEqual(
            client.esSetDeadlineMaxMilliseconds([ES_EVENT_TYPE_AUTH_OPEN, ES_EVENT_TYPE_AUTH_EXEC], milliseconds: 250),
            ES_RETURN_SUCCESS
        )
        XCTAssertEqual(client.esGetDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_OPEN), 250)
        XCTAssertEqual(client.esGetDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_EXEC), 250)
        XCTAssertEqual(client.esGetDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_RENAME), 800)

        mock.deadlineMaxSetResult = ES_RETURN_ERROR
        XCTAssertEqual(client.esSetDeadlineMaxMilliseconds([ES_EVENT_TYPE_AUTH_OPEN], milliseconds: 100), ES_RETURN_ERROR)
        XCTAssertEqual(client.esGetDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_OPEN), 250)
        mock.deadlineMaxGetFails.insert(ES_EVENT_TYPE_AUTH_EXEC)
        XCTAssertNil(client.esGetDeadlineMaxMilliseconds(ES_EVENT_TYPE_AUTH_EXEC))
    }

    func test_minimumDeadlineIsAvailableThroughDescendantProtocol() {
        let mock = MockNativeDescendantClient()
        let client: any ESNativeDescendantClient = mock
        mock.deadlineMinMilliseconds[ES_EVENT_TYPE_AUTH_RENAME] = 80

        XCTAssertEqual(
            client.esSetDeadlineMinMilliseconds([ES_EVENT_TYPE_AUTH_OPEN, ES_EVENT_TYPE_AUTH_EXEC], milliseconds: 40),
            ES_RETURN_SUCCESS
        )
        XCTAssertEqual(client.esGetDeadlineMinMilliseconds(ES_EVENT_TYPE_AUTH_OPEN), 40)
        XCTAssertEqual(client.esGetDeadlineMinMilliseconds(ES_EVENT_TYPE_AUTH_EXEC), 40)
        XCTAssertEqual(client.esGetDeadlineMinMilliseconds(ES_EVENT_TYPE_AUTH_RENAME), 80)

        mock.deadlineMinSetResult = ES_RETURN_ERROR
        XCTAssertEqual(client.esSetDeadlineMinMilliseconds([ES_EVENT_TYPE_AUTH_OPEN], milliseconds: 20), ES_RETURN_ERROR)
        XCTAssertEqual(client.esGetDeadlineMinMilliseconds(ES_EVENT_TYPE_AUTH_OPEN), 40)
        mock.deadlineMinGetFails.insert(ES_EVENT_TYPE_AUTH_EXEC)
        XCTAssertNil(client.esGetDeadlineMinMilliseconds(ES_EVENT_TYPE_AUTH_EXEC))
    }

    func test_emptyDeadlineEventListsReturnBeforeNativeCall() {
        let pointer = OpaquePointer(bitPattern: 0xdeadbeef)!

        XCTAssertEqual(pointer.esSetDeadlineMaxMilliseconds([], milliseconds: 100), ES_RETURN_ERROR)
        XCTAssertEqual(pointer.esSetDeadlineMinMilliseconds([], milliseconds: 100), ES_RETURN_ERROR)
    }
}
#endif
