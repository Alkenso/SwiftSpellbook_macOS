import Foundation
import XCTest
@testable import SpellbookLaunchctl

final class RequiredServiceInfoTests: XCTestCase {
    private let output = """
    system/com.example.service = {
        type = LaunchDaemon
        path = /Library/LaunchDaemons/com.example.service.plist
        domain = system
        state = not running
        program = /usr/bin/true
        active count = 0
        runs = 0
        minimum runtime = 10
        exit timeout = 5
        spawn type = daemon (3)
        environment = {
        }
        default environment = {
        }
        jetsam priority = 40
        jetsamproperties category = daemon
        jetsam memory limit (active, soft) = (unlimited)
        jetsam memory limit (inactive, hard) = 0 MB
        properties = supports transactions
    }
    """

    func test_missingRequiredFieldsAreRejected() throws {
        _ = try OutputParser(string: output).serviceInfo()
        let fields = [
            "type", "path", "domain", "state", "properties",
            "active count", "runs", "minimum runtime", "exit timeout", "spawn type",
            "jetsam priority", "jetsamproperties category",
            "jetsam memory limit (active, soft)", "jetsam memory limit (inactive, hard)",
        ]
        for field in fields {
            let incomplete = output.components(separatedBy: .newlines)
                .filter { !$0.hasPrefix("    \(field) = ") }.joined(separator: "\n")
            XCTAssertNotEqual(incomplete, output, field)
            XCTAssertThrowsError(try OutputParser(string: incomplete).serviceInfo(), field)
        }
        for field in ["environment", "default environment"] {
            let incomplete = output.replacingOccurrences(of: "    \(field) = {\n    }\n", with: "")
            XCTAssertNotEqual(incomplete, output, field)
            XCTAssertThrowsError(try OutputParser(string: incomplete).serviceInfo(), field)
        }
        let withoutTarget = output.components(separatedBy: .newlines).dropFirst().dropLast().joined(separator: "\n")
        XCTAssertThrowsError(try OutputParser(string: withoutTarget).serviceInfo())
    }

    func test_invalidRequiredNumbersAndMemoryLimitsAreRejected() throws {
        let replacements = [
            "active count = 0": "active count = invalid",
            "runs = 0": "runs = invalid",
            "minimum runtime = 10": "minimum runtime = invalid",
            "exit timeout = 5": "exit timeout = invalid",
            "jetsam priority = 40": "jetsam priority = invalid",
            "jetsam memory limit (active, soft) = (unlimited)": "jetsam memory limit (active, soft) = unknown",
            "jetsam memory limit (inactive, hard) = 0 MB": "jetsam memory limit (inactive, hard) = unknown",
        ]
        for (valid, invalid) in replacements {
            XCTAssertThrowsError(try OutputParser(string: output.replacingOccurrences(of: valid, with: invalid)).serviceInfo(), invalid)
        }
    }

    func test_requiredValuesPreserveZeroFalseEmptyAndUnlimited() throws {
        let info = try OutputParser(string: output).serviceInfo()
        XCTAssertEqual(info.serviceTarget, "system/com.example.service")
        XCTAssertEqual(info.runtime.activeCount, 0)
        XCTAssertEqual(info.runtime.runs, 0)
        XCTAssertTrue(info.environment.generic.isEmpty)
        XCTAssertTrue(info.environment.default.isEmpty)
        XCTAssertTrue(info.resources.jetsam.activeMemoryLimit.isUnlimited)
        XCTAssertEqual(info.resources.jetsam.inactiveMemoryLimit.megabytes, 0)
        XCTAssertFalse(info.resources.jetsam.inactiveMemoryLimit.isUnlimited)
        XCTAssertNil(info.pid)
        XCTAssertNil(info.environment.inherited)
        XCTAssertNil(info.communication)
        XCTAssertEqual(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info)), info)
    }

    func test_endpointRequiresPortAndCoreStatusFlags() throws {
        let section = """
        endpoints = {
            "com.example.endpoint" = {
                port = 0x0
                active = 0
                managed = 1
                reset = 0
                hide = 0
                watching = 0
            }
        }
        """
        try checkRequiredSection(section, fields: ["port", "active", "managed", "reset", "hide"])
        let info = try OutputParser(string: addingSection(section)).serviceInfo()
        let endpoint = try XCTUnwrap(info.communication?.endpoints?["com.example.endpoint"])
        XCTAssertEqual(endpoint.port, 0)
        XCTAssertFalse(endpoint.active)
        XCTAssertTrue(endpoint.managed)
        for invalid in ["active = 2", "active = invalid"] {
            XCTAssertThrowsError(try OutputParser(string: addingSection(section.replacingOccurrences(of: "active = 0", with: invalid))).serviceInfo())
        }
    }

    func test_coalitionRequiresIdentityAndState() throws {
        let section = """
        resource coalition = {
            ID = 1
            name = com.example.service
            type = resource
            state = active
            active count = 0
        }
        """
        try checkRequiredSection(section, fields: ["ID", "name", "type", "state", "active count"])
    }

    func test_triggerRequiresRoutingAndDescriptor() throws {
        let section = """
        event triggers = {
            "com.example.trigger" => {
                stream = com.apple.xpc.activity
                service = com.example.service
                keepalive = 0
                descriptor = {
                    "Interval" => 3600
                }
            }
        }
        """
        try checkRequiredSection(section, fields: ["stream", "service", "keepalive"])
        let missingDescriptor = section.replacingOccurrences(of: "descriptor = {", with: "other = {")
        XCTAssertThrowsError(try OutputParser(string: addingSection(missingDescriptor)).serviceInfo())
        let info = try OutputParser(string: addingSection(section)).serviceInfo()
        let trigger = try XCTUnwrap(info.communication?.eventTriggers?.first)
        XCTAssertNil(trigger.monitor)
        XCTAssertFalse(trigger.keepAlive)
    }

    func test_bundleRequiresIdentifierButNotVersion() throws {
        let info = try OutputParser(string: addingSection("bundle id = com.example.service")).serviceInfo()
        XCTAssertEqual(info.bundle?.identifier, "com.example.service")
        XCTAssertNil(info.bundle?.version)
        XCTAssertThrowsError(try OutputParser(string: addingSection("bundle version = 1.0")).serviceInfo())
    }

    func test_loginItemRequiresIdentifiersButToleratesUnrecognizedMode() throws {
        let section = """
        program identifier = com.example.helper (mode: 1)
        parent bundle identifier = com.example.app
        parent bundle version = 1.0
        """
        try checkRequiredSection(section, fields: ["program identifier", "parent bundle identifier"])
        for suffix in ["", " (mode: invalid)", " (mode: 1"] {
            let invalid = section.replacingOccurrences(of: " (mode: 1)", with: suffix)
            let info = try OutputParser(string: addingSection(invalid)).serviceInfo()
            XCTAssertEqual(info.loginItem?.identifier, "com.example.helper")
            XCTAssertNil(info.loginItem?.mode)
        }
    }

    // Reduced fixtures isolate historically omitted metadata without claiming
    // to represent the complete output of a particular macOS version.
    func test_endpointWatchingMayBeAbsent() throws {
        let section = """
        endpoints = {
            "com.example.endpoint" = {
                port = 0x0
                active = 0
                managed = 1
                reset = 0
                hide = 0
            }
        }
        """
        let info = try OutputParser(string: addingSection(section)).serviceInfo()
        let endpoint = try XCTUnwrap(info.communication?.endpoints?["com.example.endpoint"])
        XCTAssertNil(endpoint.watching)
        XCTAssertFalse(endpoint.active)
        XCTAssertTrue(endpoint.managed)
        XCTAssertEqual(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info)), info)
        for (raw, expected) in [("0", false), ("1", true)] {
            let present = section.replacingOccurrences(of: "hide = 0", with: "hide = 0\n        watching = \(raw)")
            let info = try OutputParser(string: addingSection(present)).serviceInfo()
            XCTAssertEqual(info.communication?.endpoints?["com.example.endpoint"]?.watching, expected)
        }
    }

    func test_loginItemVersionAndModeMayBeAbsentIndependently() throws {
        let section = """
        program identifier = com.example.helper
        parent bundle identifier = com.example.app
        """
        for includeVersion in [false, true] {
            for includeMode in [false, true] {
                var partial = section
                if includeVersion { partial += "\nparent bundle version = 1.0" }
                if includeMode { partial = partial.replacingOccurrences(of: "com.example.helper", with: "com.example.helper (mode: 1)") }
                let submitted = addingSection(partial)
                    .replacingOccurrences(of: "type = LaunchDaemon", with: "type = Submitted")
                    .replacingOccurrences(of: "    program = /usr/bin/true\n", with: "")
                let info = try OutputParser(string: submitted).serviceInfo()
                XCTAssertNil(info.execution.program)
                let loginItem = try XCTUnwrap(info.loginItem)
                XCTAssertEqual(loginItem.identifier, "com.example.helper")
                XCTAssertEqual(loginItem.parentIdentifier, "com.example.app")
                XCTAssertEqual(loginItem.parentVersion, includeVersion ? "1.0" : nil)
                XCTAssertEqual(loginItem.mode, includeMode ? 1 : nil)
                XCTAssertEqual(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info)), info)
            }
        }
    }

    private func addingSection(_ section: String) -> String {
        let indented = section.components(separatedBy: .newlines).map { "    " + $0 }.joined(separator: "\n")
        return output.replacingOccurrences(of: "\n}", with: "\n" + indented + "\n}")
    }

    private func checkRequiredSection(_ section: String, fields: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        _ = try OutputParser(string: addingSection(section)).serviceInfo()
        for field in fields {
            let incomplete = section.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("\(field) = ") }
                .joined(separator: "\n")
            XCTAssertNotEqual(incomplete, section, field, file: file, line: line)
            XCTAssertThrowsError(try OutputParser(string: addingSection(incomplete)).serviceInfo(), field, file: file, line: line)
        }
    }

}
