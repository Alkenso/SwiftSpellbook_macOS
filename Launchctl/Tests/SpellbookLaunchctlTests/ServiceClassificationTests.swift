import Foundation
import XCTest
@testable import SpellbookLaunchctl

final class ServiceClassificationTests: XCTestCase {
    func test_knownClassificationsUseRawStrings() throws {
        try checkValues([Launchctl.ServiceType.launchDaemon, .launchAgent, .launchAngel, .xpcService, .submitted],
                        rawValues: ["LaunchDaemon", "LaunchAgent", "LaunchAngel", "XPCService", "Submitted"])
        try checkValues([Launchctl.ServiceState.running, .notRunning, .spawnScheduled],
                        rawValues: ["running", "not running", "spawn scheduled"])
        try checkValues([Launchctl.SpawnType.app, .daemon, .interactive, .background, .adaptive],
                        rawValues: ["app (1)", "daemon (3)", "interactive (4)", "background (5)", "adaptive (6)"])
        try checkValues([Launchctl.SpawnRole.ui, .nonUI, .uiNonFocal, .darwinBackground],
                        rawValues: ["ui (2)", "non-ui (3)", "ui non-focal (4)", "darwin bg (6)"])
        try checkValues([Launchctl.JobState.running, .exited, .spawnFailed, .uninitialized],
                        rawValues: ["running", "exited", "spawn failed", "uninitialized"])
        try checkValues([Launchctl.LaunchReason.ipcMach, .ipcSocket, .xpcEvent, .speculative, .systemSupport,
                         .launchJobDemand, .semaphore, .eventPublisher, .nonIPCDemand, .inefficient],
                        rawValues: ["ipc (mach)", "ipc (socket)", "xpc event", "speculative", "system support",
                                    "launch job demand", "semaphore", "event publisher", "non-ipc demand", "inefficient"])
        try checkValues([Launchctl.CoalitionType.resource, .jetsam], rawValues: ["resource", "jetsam"])
        try checkValues([Launchctl.CoalitionState.active], rawValues: ["active"])
        try checkValues([Launchctl.JetsamCategory.daemon, .app, .systemXPCService, .driverKit],
                        rawValues: ["daemon", "app", "system xpcservice", "DriverKit"])
        try checkValues([Launchctl.SocketType.stream, .datagram], rawValues: ["stream", "datagram"])
        try checkValues([Launchctl.SocketFamily.ipv4], rawValues: ["ipv4"])
        try checkValues([Launchctl.SocketProtocol.udp], rawValues: ["udp"])
    }

    func test_unknownClassificationsRoundTripAsStrings() throws {
        try checkUnknown(Launchctl.ServiceType.self)
        try checkUnknown(Launchctl.ServiceState.self)
        try checkUnknown(Launchctl.SpawnType.self, rawValue: " (7)")
        try checkUnknown(Launchctl.SpawnRole.self)
        try checkUnknown(Launchctl.JobState.self)
        try checkUnknown(Launchctl.LaunchReason.self)
        try checkUnknown(Launchctl.CoalitionType.self)
        try checkUnknown(Launchctl.CoalitionState.self)
        try checkUnknown(Launchctl.JetsamCategory.self)
        try checkUnknown(Launchctl.SocketType.self)
        try checkUnknown(Launchctl.SocketFamily.self)
        try checkUnknown(Launchctl.SocketProtocol.self)
    }

    func test_parserUsesTypedClassificationsAndKeepsStringJSON() throws {
        let info = try OutputParser(string: output).serviceInfo()
        XCTAssertEqual(info.type, .launchDaemon)
        XCTAssertEqual(info.state, .notRunning)
        XCTAssertEqual(info.execution.spawnType, .adaptive)
        XCTAssertEqual(info.execution.spawnRole, .darwinBackground)
        XCTAssertEqual(info.runtime.jobState, .exited)
        XCTAssertEqual(info.runtime.immediateReason, .ipcMach)
        XCTAssertEqual(info.resources.jetsam.category, .daemon)
        XCTAssertEqual(info.resources.resourceCoalition?.type, .resource)
        XCTAssertEqual(info.resources.resourceCoalition?.state, .active)
        let socket = try XCTUnwrap(info.communication?.sockets?["Network"])
        XCTAssertEqual(socket.type, .datagram)
        XCTAssertEqual(socket.family, .ipv4)
        XCTAssertEqual(socket.protocolName, .udp)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(info)) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "LaunchDaemon")
        XCTAssertEqual(json["state"] as? String, "not running")
        XCTAssertEqual(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info)), info)
    }

    func test_parserPreservesUnknownClassifications() throws {
        let replacements = [
            "type = LaunchDaemon": "type = FutureService",
            "state = not running": "state = future service state",
            "spawn type = adaptive (6)": "spawn type =  (7)",
            "spawn role = darwin bg (6)": "spawn role = future role (99)",
            "job state = exited": "job state = future job state",
            "immediate reason = ipc (mach)": "immediate reason = future reason",
            "jetsamproperties category = daemon": "jetsamproperties category = future category",
            "type = resource": "type = future coalition",
            "state = active": "state = future coalition state",
            "type = datagram": "type = future socket",
            "family = ipv4": "family = future family",
            "protocol = udp": "protocol = future protocol",
        ]
        let futureOutput = replacements.reduce(output) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
        let info = try OutputParser(string: futureOutput).serviceInfo()
        XCTAssertEqual(info.type.rawValue, "FutureService")
        XCTAssertNil(info.daemon)
        XCTAssertNil(info.agent)
        XCTAssertEqual(info.state.rawValue, "future service state")
        XCTAssertEqual(info.execution.spawnType.rawValue, " (7)")
        XCTAssertEqual(info.execution.spawnRole?.rawValue, "future role (99)")
        XCTAssertEqual(info.runtime.jobState?.rawValue, "future job state")
        XCTAssertEqual(info.runtime.immediateReason?.rawValue, "future reason")
        XCTAssertEqual(info.resources.jetsam.category.rawValue, "future category")
        XCTAssertEqual(info.resources.resourceCoalition?.type.rawValue, "future coalition")
        XCTAssertEqual(info.resources.resourceCoalition?.state.rawValue, "future coalition state")
        let socket = try XCTUnwrap(info.communication?.sockets?["Network"])
        XCTAssertEqual(socket.type?.rawValue, "future socket")
        XCTAssertEqual(socket.family?.rawValue, "future family")
        XCTAssertEqual(socket.protocolName?.rawValue, "future protocol")
        XCTAssertEqual(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info)), info)
    }

    private func checkValues<Value>(_ values: [Value], rawValues: [String], file: StaticString = #filePath, line: UInt = #line) throws
    where Value: RawRepresentable & Codable & Equatable, Value.RawValue == String {
        XCTAssertEqual(values.map(\.rawValue), rawValues, file: file, line: line)
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: JSONEncoder().encode(values)), rawValues, file: file, line: line)
        XCTAssertEqual(try JSONDecoder().decode([Value].self, from: JSONEncoder().encode(rawValues)), values, file: file, line: line)
    }

    private func checkUnknown<Value>(_ type: Value.Type, rawValue: String = "future value", file: StaticString = #filePath, line: UInt = #line) throws
    where Value: RawRepresentable & Codable & Equatable, Value.RawValue == String {
        let value = try XCTUnwrap(Value(rawValue: rawValue), file: file, line: line)
        try checkValues([value], rawValues: [rawValue], file: file, line: line)
    }

    private let output = """
    system/com.example.service = {
        type = LaunchDaemon
        path = /Library/LaunchDaemons/com.example.service.plist
        domain = system
        state = not running
        program = /usr/bin/true
        active count = 0
        runs = 1
        minimum runtime = 10
        exit timeout = 5
        spawn type = adaptive (6)
        spawn role = darwin bg (6)
        job state = exited
        immediate reason = ipc (mach)
        environment = {
        }
        default environment = {
        }
        jetsam priority = 40
        jetsamproperties category = daemon
        jetsam memory limit (active) = (unlimited)
        jetsam memory limit (inactive) = (unlimited)
        resource coalition = {
            ID = 1
            name = com.example.service
            type = resource
            state = active
            active count = 0
        }
        sockets = {
            "Network" = {
                type = datagram
                family = ipv4
                protocol = udp
            }
        }
        properties = inferred program
    }
    """
}
