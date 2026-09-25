@testable import SpellbookLaunchctl

import XCTest

class OutputParserTests: XCTestCase {
    func test_exactKeysAndDirectChildren() throws {
        let parser = OutputParser(string: """
        system/test = {
            nested = {
                state = nested
                pid = 123
                endpoints = {
                    wrong = {
                    }
                }
            }
            base minimum runtime = 20
            minimum runtime = 10
            job state = exited
            state = not running
            jetsam memory limit (active, soft) = 15 MB
            dynamic endpoints = {
                dynamic = {
                }
            }
            endpoints = {
                "literal.name[1]" = {
                    active = 1
                }
            }
        }
        """)

        XCTAssertEqual(try parser.string(forKey: "state"), "not running")
        XCTAssertEqual(try parser.string(forKey: "minimum runtime"), "10")
        XCTAssertEqual(try parser.string(forKey: "jetsam memory limit (active, soft)"), "15 MB")
        XCTAssertThrowsError(try parser.string(forKey: "pid"))
        let endpoints = OutputParser(string: try parser.container(forKey: "endpoints"))
        XCTAssertEqual(Set(try endpoints.containers().keys), ["literal.name[1]"])
        XCTAssertEqual(try OutputParser(string: endpoints.container(forKey: "literal.name[1]")).string(forKey: "active"), "1")
    }

    func test_environmentDoesNotMatchInheritedOrDefaultEnvironment() throws {
        let parser = OutputParser(string: """
        gui/501/test = {
            inherited environment = {
                INHERITED => yes
            }
            default environment = {
                DEFAULT => yes
            }
        }
        """)
        XCTAssertThrowsError(try parser.stringDictionary(forKey: "environment"))
        XCTAssertEqual(try parser.stringDictionary(forKey: "default environment"), ["DEFAULT": "yes"])
    }

    func test_annotatedExitCode() throws {
        let parser = OutputParser(string: """
        system/test = {
            path = /Library/LaunchDaemons/test.plist
            type = LaunchDaemon
            domain = system
            state = not running
            program = /usr/bin/true
            active count = 0
            runs = 1
            minimum runtime = 10
            exit timeout = 5
            spawn type = daemon (3)
            environment = {
            }
            default environment = {
            }
            jetsam priority = 40
            jetsamproperties category = daemon
            jetsam memory limit (active) = (unlimited)
            jetsam memory limit (inactive) = (unlimited)
            properties = inferred program
            last exit code = 78: EX_CONFIG
        }
        """)
        XCTAssertEqual(try parser.serviceInfo().lastExitReason, .exitCode(78))
    }

    func test_environmentAllowsEmptyValuesAndRepeatedKeys() throws {
        let parser = OutputParser(string: """
        system/example = {
            path = /tmp/example.plist
            program = /usr/bin/example
            environment = {
                OSLogRateLimit => 64
                PRODUCT_INFO_FILTER_DISABLE => \("")
                VALUE_WITH_SEPARATOR => one => two
                OSLogRateLimit => 64
            }
        }
        """)
        XCTAssertEqual(try parser.stringDictionary(forKey: "environment"), [
            "OSLogRateLimit": "64",
            "PRODUCT_INFO_FILTER_DISABLE": "",
            "VALUE_WITH_SEPARATOR": "one => two",
        ])
    }

    func test_argumentsPreserveEmptyEntries() throws {
        let parser = OutputParser(string: """
        gui/501/example = {
            path = /tmp/example.plist
            program = /usr/bin/example
            arguments = {
                /usr/bin/example
                \("")
                --flag
            }
        }
        """)
        XCTAssertEqual(try parser.stringArray(forKey: "arguments"), ["/usr/bin/example", "", "--flag"])
    }
}
