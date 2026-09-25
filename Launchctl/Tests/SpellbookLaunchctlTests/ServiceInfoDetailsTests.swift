@testable import SpellbookLaunchctl

import Foundation
import XCTest

class ServiceInfoDetailsTests: XCTestCase {
    func test_additionalTerminatingSignals() throws {
        struct SignalSample {
            var text: String
            var number: Int32
        }
        for sample in [SignalSample(text: "Hangup: 1", number: 1), SignalSample(text: "Terminated: 15", number: 15)] {
            let info = try parseServiceInfo("""
            gui/501/com.example.submitted = {
                path = (submitted by smd[353])
                type = Submitted
                program = /usr/bin/example
                last terminating signal = \(sample.text)
            }
            """)
            XCTAssertEqual(info.path, "(submitted by smd[353])")
            XCTAssertEqual(info.lastExitReason, .signal(sample.number))
        }
    }

    func test_endpointSpecialPortsAndNonLaunchingFlag() throws {
        let info = try parseServiceInfo("""
        system/com.example.service = {
            path = /Library/LaunchDaemons/com.example.service.plist
            type = LaunchDaemon
            program = /usr/bin/example
            endpoints = {
                "host" = {
                    port = 0x123
                    active = 1
                    managed = 1
                    reset = 0
                    hide = 0
                    watching = 0
                    host-special port = 35 (doubleagentd)
                }
                "task" = {
                    port = 0x456
                    active = 1
                    managed = 1
                    reset = 0
                    hide = 0
                    watching = 0
                    task-special port = 9 (access)
                    non-launching = 1
                }
                "notification" = {
                    port = 0x789
                    active = 0
                    managed = 1
                    reset = 0
                    hide = 0
                    watching = 0
                    host-special port = 23 (sysdiagnose notification)
                    non-launching = 0
                }
            }
        }
        """)
        XCTAssertEqual(info.communication?.endpoints?["host"]?.hostSpecialPort?.number, 35)
        XCTAssertEqual(info.communication?.endpoints?["host"]?.hostSpecialPort?.name, "doubleagentd")
        XCTAssertNil(info.communication?.endpoints?["host"]?.taskSpecialPort)
        XCTAssertNil(info.communication?.endpoints?["host"]?.nonLaunching)
        XCTAssertEqual(info.communication?.endpoints?["task"]?.taskSpecialPort?.number, 9)
        XCTAssertEqual(info.communication?.endpoints?["task"]?.taskSpecialPort?.name, "access")
        XCTAssertEqual(info.communication?.endpoints?["task"]?.nonLaunching, true)
        XCTAssertEqual(info.communication?.endpoints?["notification"]?.hostSpecialPort?.name, "sysdiagnose notification")
        XCTAssertEqual(info.communication?.endpoints?["notification"]?.nonLaunching, false)
        XCTAssertEqual(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info)), info)
    }

    func test_daemonMetadataAndResourceLimits() throws {
        let info = try parseServiceInfo("""
        system/com.example.daemon = {
            active count = 2
            copy count = 1
            path = /Library/LaunchDaemons/com.example.daemon.plist
            type = LaunchDaemon
            state = running
            program = /usr/bin/example
            arguments = {
                /usr/bin/example
                argument with spaces
            }
            bundle id = com.example.daemon
            bundle version = 1.2
            working directory = /tmp
            stdin path = /dev/null
            stdout path = /tmp/output
            stderr path = /tmp/error
            domain = system
            username = _example
            group = _example
            umask = 27
            nice = -1
            minimum runtime = 10
            base minimum runtime = 5
            exit timeout = 60
            runs = 3
            pid = 42
            immediate reason = ipc (mach)
            forks = 2
            execs = 1
            initialized = 1
            trampolined = 1
            started suspended = 0
            proxy started suspended = 0
            run interval = 3600 seconds
            last exit code = 78: EX_CONFIG
            spawn type = adaptive (6)
            spawn role = darwin bg (6)
            jetsam priority = 40
            jetsam memory limit (active, soft) = 15 MB
            jetsam memory limit (inactive, hard) = 30 MB
            jetsamproperties category = daemon
            jetsam thread limit = 32
            jetsam soft port limit = 2500
            jetsam hard port limit = 25000
            jetsam soft file descriptor limit = 1000
            jetsam hard file descriptor limit = 10000
            jetsam conclave memory limit = 5
            resource limits = {
                core (soft) => (infinity)
                maxfiles (hard) => 2048
            }
            resource coalition = {
                ID = 511
                type = resource
                state = active
                active count = 1
                name = com.example.daemon
            }
            jetsam coalition = {
                ID = 512
                type = jetsam
                state = active
                active count = 1
                name = com.example.daemon
                bundle ID = com.example.daemon
            }
            exponential throttling grace limit = 3
            multiple instances = 1
            original = com.example.original
            instances = {
                com.example.daemon.instance,
            }
            job state = running
            cryptex = com.apple.cryptex.app
            conclave = com.example.conclave
            sandbox profile = example
            properties = keepalive | runatload | system service
        }
        """)

        XCTAssertEqual(info.serviceTarget, "system/com.example.daemon")
        XCTAssertEqual(info.type, .launchDaemon)
        XCTAssertEqual(info.state, .running)
        XCTAssertEqual(info.path, "/Library/LaunchDaemons/com.example.daemon.plist")
        XCTAssertEqual(info.execution.program, "/usr/bin/example")
        XCTAssertEqual(info.execution.arguments, ["/usr/bin/example", "argument with spaces"])
        XCTAssertEqual(info.bundle?.identifier, "com.example.daemon")
        XCTAssertEqual(info.bundle?.version, "1.2")
        XCTAssertEqual(info.domain, "system")
        XCTAssertEqual(info.runtime.activeCount, 2)
        XCTAssertEqual(info.execution.username, "_example")
        XCTAssertEqual(info.execution.group, "_example")
        XCTAssertEqual(info.execution.workingDirectory, "/tmp")
        XCTAssertEqual(info.execution.stdinPath, "/dev/null")
        XCTAssertEqual(info.execution.stdoutPath, "/tmp/output")
        XCTAssertEqual(info.execution.stderrPath, "/tmp/error")
        XCTAssertEqual(info.execution.umask, 0o27)
        XCTAssertEqual(info.execution.nice, -1)
        XCTAssertEqual(info.execution.minimumRuntime, 10)
        XCTAssertEqual(info.execution.baseMinimumRuntime, 5)
        XCTAssertEqual(info.execution.exitTimeout, 60)
        XCTAssertEqual(info.runtime.runs, 3)
        XCTAssertEqual(info.runtime.immediateReason, .ipcMach)
        XCTAssertEqual(info.runtime.forks, 2)
        XCTAssertEqual(info.runtime.execs, 1)
        XCTAssertEqual(info.runtime.initialized, true)
        XCTAssertEqual(info.runtime.trampolined, true)
        XCTAssertEqual(info.runtime.startedSuspended, false)
        XCTAssertEqual(info.runtime.proxyStartedSuspended, false)
        XCTAssertEqual(info.execution.runInterval, 3600)
        XCTAssertEqual(info.lastExitReason, .exitCode(78))
        XCTAssertEqual(info.execution.spawnType, .adaptive)
        XCTAssertEqual(info.execution.spawnRole, .darwinBackground)
        XCTAssertEqual(info.resources.jetsam.priority, 40)
        XCTAssertEqual(info.resources.jetsam.activeMemoryLimit.megabytes, 15)
        XCTAssertEqual(info.resources.jetsam.activeMemoryLimit.enforcement, .soft)
        XCTAssertEqual(info.resources.jetsam.inactiveMemoryLimit.megabytes, 30)
        XCTAssertEqual(info.resources.jetsam.inactiveMemoryLimit.enforcement, .hard)
        XCTAssertEqual(info.resources.jetsam.category, .daemon)
        XCTAssertEqual(info.resources.jetsam.threadLimit, 32)
        XCTAssertEqual(info.resources.jetsam.softPortLimit, 2500)
        XCTAssertEqual(info.resources.jetsam.hardPortLimit, 25000)
        XCTAssertEqual(info.resources.jetsam.softFileDescriptorLimit, 1000)
        XCTAssertEqual(info.resources.jetsam.hardFileDescriptorLimit, 10000)
        XCTAssertEqual(info.resources.jetsam.conclaveMemoryLimit, 5)
        XCTAssertEqual(info.resources.resourceLimits, ["core (soft)": "(infinity)", "maxfiles (hard)": "2048"])
        XCTAssertEqual(info.resources.resourceCoalition?.id, 511)
        XCTAssertEqual(info.resources.resourceCoalition?.type, .resource)
        XCTAssertEqual(info.resources.resourceCoalition?.state, .active)
        XCTAssertEqual(info.resources.resourceCoalition?.activeCount, 1)
        XCTAssertEqual(info.resources.resourceCoalition?.name, "com.example.daemon")
        XCTAssertEqual(info.resources.jetsamCoalition?.id, 512)
        XCTAssertEqual(info.resources.jetsamCoalition?.bundleID, "com.example.daemon")
        XCTAssertEqual(info.execution.exponentialThrottlingGraceLimit, 3)
        XCTAssertEqual(info.instances?.multipleInstances, true)
        XCTAssertEqual(info.instances?.copyCount, 1)
        XCTAssertEqual(info.instances?.original, "com.example.original")
        XCTAssertEqual(info.instances?.names, ["com.example.daemon.instance"])
        XCTAssertEqual(info.runtime.jobState, .running)
        XCTAssertEqual(info.execution.cryptex, "com.apple.cryptex.app")
        XCTAssertEqual(info.execution.conclave, "com.example.conclave")
        XCTAssertEqual(info.execution.sandboxProfile, "example")
        XCTAssertEqual(info.properties, ["keepalive", "runatload", "system service"])
        XCTAssertEqual(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info)), info)
    }

    func test_loginItemRegistrationMetadata() throws {
        let info = try parseServiceInfo("""
        gui/501/com.example.agent = {
            path = (submitted by smd.538)
            type = Submitted
            managed_by = com.apple.xpc.ServiceManagement
            state = running
            program identifier = Contents/Library/LaunchAgents/com.example.agent (mode: 2)
            parent bundle identifier = com.example.app
            parent bundle version = 1.2.3
            BTM uuid = 00000000-0000-0000-0000-000000000001
            domain = gui/501 [100016]
            asid = 100016
            jetsam memory limit (active) = (unlimited)
            jetsam memory limit (inactive) = (unlimited)
        }
        """)
        XCTAssertNil(info.daemon)
        XCTAssertNil(info.execution.program)
        XCTAssertEqual(info.path, "(submitted by smd.538)")
        XCTAssertEqual(info.type, .submitted)
        XCTAssertEqual(info.management?.manager, "com.apple.xpc.ServiceManagement")
        XCTAssertEqual(info.asid, 100016)
        XCTAssertEqual(info.loginItem?.identifier, "Contents/Library/LaunchAgents/com.example.agent")
        XCTAssertEqual(info.loginItem?.mode, 2)
        XCTAssertEqual(info.loginItem?.parentVersion, "1.2.3")
        XCTAssertEqual(info.management?.backgroundTaskManagementUUID, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertTrue(info.resources.jetsam.activeMemoryLimit.isUnlimited)
        XCTAssertNil(info.resources.jetsam.activeMemoryLimit.megabytes)
        XCTAssertNil(info.resources.jetsam.activeMemoryLimit.enforcement)
    }

    func test_endpointNamespacesSocketsAndTriggers() throws {
        let info = try parseServiceInfo("""
        system/com.example.daemon = {
            path = /Library/LaunchDaemons/com.example.daemon.plist
            program = /usr/bin/example
            dynamic endpoints = {
                "dynamic" = {
                    port = 0xa03
                    active = 1
                    managed = 0
                    reset = 0
                    hide = 1
                    watching = 0
                }
            }
            endpoints = {
                "static" = {
                    port = 0x0
                    active = 0
                    managed = 1
                    reset = 1
                    hide = 0
                    watching = 1
                }
            }
            pid-local endpoints = {
                "local" = {
                    port = 0x12
                    active = 1
                    managed = 1
                    reset = 0
                    hide = 0
                    watching = 0
                }
            }
            instance-specific endpoints = {
                "instance" = {
                    port = 0x13
                    active = 1
                    managed = 1
                    reset = 0
                    hide = 0
                    watching = 0
                }
            }
            event channels = {
                "channel" = {
                    port = 0x14
                    active = 1
                    managed = 1
                    reset = 0
                    hide = 0
                    watching = 0
                }
            }
            event triggers = {
                com.example.trigger => {
                    keepalive = 0
                    service = com.example.daemon
                    stream = com.apple.fsevents.matching
                    monitor = com.apple.UserEventAgent-System
                    descriptor = {
                        "PathState" => {
                            "/tmp/example" => true
                        }
                    }
                }
            }
            sockets = {
                "Listeners" = {
                    type = stream
                    path = /var/run/example.socket
                    mode = 644
                    owner uid = 501
                    group id = 0
                    secure key = SSH_AUTH_SOCK
                    sockets = {
                        19 (no bytes to read)
                    }
                    active = 0
                    passive = 1
                    bonjour = 0
                    ipv4v6 = 0
                    receive_packet_info = 0
                    needs_rename = 0
                }
                "Network" = {
                    type = datagram
                    node name = 0.0.0.0
                    service name = netbios-dgm
                    family = ipv4
                    protocol = udp
                }
                "BSDSystemLogger" = {
                    (system logger socket)
                }
            }
            semaphores = {
                successful exit => 0
            }
        }
        """)
        XCTAssertEqual(info.endpoints, ["static"])
        XCTAssertEqual(info.communication?.endpoints?["static"]?.port, 0)
        XCTAssertEqual(info.communication?.endpoints?["static"]?.reset, true)
        XCTAssertEqual(info.communication?.endpoints?["static"]?.watching, true)
        let dynamic = try XCTUnwrap(info.communication?.dynamicEndpoints?["dynamic"])
        XCTAssertEqual(dynamic.port, 0xa03)
        XCTAssertEqual(dynamic.active, true)
        XCTAssertEqual(dynamic.managed, false)
        XCTAssertEqual(dynamic.reset, false)
        XCTAssertEqual(dynamic.hide, true)
        XCTAssertEqual(dynamic.watching, false)
        XCTAssertEqual(info.communication?.pidLocalEndpoints?["local"]?.port, 0x12)
        XCTAssertEqual(info.communication?.instanceSpecificEndpoints?["instance"]?.port, 0x13)
        XCTAssertEqual(info.communication?.eventChannels?["channel"]?.port, 0x14)
        let trigger = try XCTUnwrap(info.communication?.eventTriggers?.first)
        XCTAssertEqual(trigger.name, "com.example.trigger")
        XCTAssertEqual(trigger.keepAlive, false)
        XCTAssertEqual(trigger.service, "com.example.daemon")
        XCTAssertEqual(trigger.stream, "com.apple.fsevents.matching")
        XCTAssertEqual(trigger.monitor, "com.apple.UserEventAgent-System")
        XCTAssertTrue(try XCTUnwrap(trigger.descriptor).contains("\"/tmp/example\" => true"))
        let socket = try XCTUnwrap(info.communication?.sockets?["Listeners"])
        XCTAssertEqual(socket.type, .stream)
        XCTAssertEqual(socket.path, "/var/run/example.socket")
        XCTAssertEqual(socket.mode, 0o644)
        XCTAssertEqual(socket.ownerUID, 501)
        XCTAssertEqual(socket.groupID, 0)
        XCTAssertEqual(socket.secureKey, "SSH_AUTH_SOCK")
        XCTAssertEqual(socket.descriptors, ["19 (no bytes to read)"])
        XCTAssertEqual(socket.active, false)
        XCTAssertEqual(socket.passive, true)
        XCTAssertEqual(socket.bonjour, false)
        XCTAssertEqual(socket.ipv4v6, false)
        XCTAssertEqual(socket.receivePacketInfo, false)
        XCTAssertEqual(socket.needsRename, false)
        XCTAssertEqual(info.communication?.sockets?["Network"]?.nodeName, "0.0.0.0")
        XCTAssertEqual(info.communication?.sockets?["Network"]?.serviceName, "netbios-dgm")
        XCTAssertEqual(info.communication?.sockets?["Network"]?.family, .ipv4)
        XCTAssertEqual(info.communication?.sockets?["Network"]?.protocolName, .udp)
        XCTAssertEqual(info.communication?.sockets?["BSDSystemLogger"]?.isSystemLogger, true)
        XCTAssertEqual(info.communication?.semaphores, ["successful exit": "0"])
    }

    func test_serviceTypesAndExitReasons() throws {
        for type in ["LaunchAgent", "LaunchAngel", "XPCService", "Submitted", "FutureType"] {
            let info = try parseServiceInfo("""
            gui/501/com.example.service = {
                path = (submitted by example.42)
                type = \(type)
                state = spawn scheduled
                program = /usr/bin/example
                managed_by = com.apple.kernelmanagerd
                dext checkin port = 0x3bd03 [type 27, object 0]
                last exit reason = JETSAM_REASON_MEMORY_PERPROCESSLIMIT
                last jetsam exit details = JETSAM_REASON_MEMORY_PERPROCESSLIMIT
                last terminating signal = Killed: 9
            }
            """)
            XCTAssertEqual(info.type.rawValue, type)
            XCTAssertEqual(info.state, .spawnScheduled)
            XCTAssertEqual(info.management?.manager, "com.apple.kernelmanagerd")
            XCTAssertEqual(info.management?.dextCheckinPort, "0x3bd03 [type 27, object 0]")
            XCTAssertEqual(info.lastExitReason, .signal(9))
            XCTAssertEqual(info.runtime.lastExitDescription, "JETSAM_REASON_MEMORY_PERPROCESSLIMIT")
            XCTAssertEqual(info.runtime.lastJetsamExitDetails, "JETSAM_REASON_MEMORY_PERPROCESSLIMIT")
            XCTAssertNil(info.communication?.endpoints)
            XCTAssertEqual(info.resources.jetsam.priority, 40)
            XCTAssertNil(info.runtime.initialized)
        }
    }

    func test_repeatedEventTriggerNames() throws {
        let info = try parseServiceInfo("""
        gui/501/test = {
            path = /tmp/test.plist
            program = /usr/bin/true
            event triggers = {
                com.example.task => {
                    keepalive = 0
                    service = com.example.service
                    stream = com.apple.bg.system.task
                    monitor = com.apple.dasd
                    descriptor = {
                        "Interval" => 60
                    }
                }
                com.example.task => {
                    keepalive = 1
                    service = com.example.service
                    stream = com.apple.notifyd.matching
                    monitor = com.apple.notifyd
                    descriptor = {
                        "Name" => com.example.notification
                    }
                }
            }
        }
        """)
        let triggers = try XCTUnwrap(info.communication?.eventTriggers)
        XCTAssertEqual(triggers.map(\.name), ["com.example.task", "com.example.task"])
        XCTAssertEqual(triggers.map(\.keepAlive), [false, true])
        XCTAssertEqual(triggers.map(\.service), ["com.example.service", "com.example.service"])
        XCTAssertEqual(triggers.map(\.stream), ["com.apple.bg.system.task", "com.apple.notifyd.matching"])
        XCTAssertEqual(triggers.map(\.monitor), ["com.apple.dasd", "com.apple.notifyd"])
        XCTAssertTrue(triggers.allSatisfy { !$0.descriptor.isEmpty })
    }

    func test_categoriesAreIndependent() throws {
        let submitted = try parseServiceInfo("""
        system/com.example.driver = {
            path = (submitted by kernelmanagerd.567)
            type = Submitted
            managed_by = com.apple.kernelmanagerd
            bundle id = com.example.driver
            program = /Library/DriverExtensions/Example.dext/Example
            username = _driverkit
            dext checkin port = 0x3bd03 [type 27, object 0]
        }
        """)
        XCTAssertNil(submitted.daemon)
        XCTAssertNil(submitted.agent)
        XCTAssertNil(submitted.loginItem)
        XCTAssertEqual(submitted.execution.username, "_driverkit")
        XCTAssertEqual(submitted.bundle?.identifier, "com.example.driver")
        XCTAssertEqual(submitted.management?.manager, "com.apple.kernelmanagerd")
        XCTAssertEqual(submitted.management?.dextCheckinPort, "0x3bd03 [type 27, object 0]")

        let agent = try parseServiceInfo("""
        gui/501/com.example.agent = {
            path = /Library/LaunchAgents/com.example.agent.plist
            type = LaunchAgent
            program = /usr/bin/example
            bundle id = com.example.agent
            BTM uuid = 00000000-0000-0000-0000-000000000001
        }
        """)
        XCTAssertNil(agent.daemon)
        XCTAssertEqual(agent.agent?.plistPath, "/Library/LaunchAgents/com.example.agent.plist")
        XCTAssertNil(agent.loginItem)
        XCTAssertEqual(agent.bundle?.identifier, "com.example.agent")
        XCTAssertNil(agent.management?.manager)
        XCTAssertNotNil(agent.management?.backgroundTaskManagementUUID)

        let xpc = try parseServiceInfo("""
        system/com.example.xpc = {
            path = /System/Library/Example.xpc
            type = XPCService
            program = /System/Library/Example.xpc/Contents/MacOS/Example
            bundle id = com.example.xpc
            bundle version = 110
        }
        """)
        XCTAssertNil(xpc.daemon)
        XCTAssertNil(xpc.agent)
        XCTAssertNil(xpc.management)
        XCTAssertEqual(xpc.execution.program, "/System/Library/Example.xpc/Contents/MacOS/Example")
        XCTAssertEqual(xpc.bundle?.identifier, "com.example.xpc")
        XCTAssertEqual(xpc.bundle?.version, "110")

        let angel = try parseServiceInfo("""
        gui/501/com.example.angel = {
            path = /Library/Example/ExampleAngel
            type = LaunchAngel
            managed_by = com.apple.runningboard
            program = /Library/Example/ExampleAngel
        }
        """)
        XCTAssertNil(angel.daemon)
        XCTAssertNil(angel.agent)
        XCTAssertNotNil(angel.management)
        XCTAssertEqual(angel.execution.program, "/Library/Example/ExampleAngel")
    }

    func test_rejectsIncompleteLegacyServiceInfo() throws {
        let data = Data("""
        {"pid":42,"daemon":{"plistPath":"/tmp/test.plist","program":"/usr/bin/true"},"environment":{}}
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: data))
    }

    func test_invalidOptionalFieldsDoNotBecomeZeroOrUnlimited() throws {
        let info = try OutputParser(string: """
        system/test = {
            type = XPCService
            path = /tmp/test.plist
            state = not running
            program = /usr/bin/true
            environment = {
            }
            default environment = {
            }
            domain = system
            active count = 0
            runs = 0
            minimum runtime = 10
            exit timeout = 5
            spawn type = adaptive (6)
            initialized = 2
            umask = 89
            BTM uuid = invalid
            last exit code = (never exited)
            jetsam priority = 0
            jetsam memory limit (active) = (unlimited)
            jetsam memory limit (inactive, hard) = 0 MB
            jetsamproperties category = daemon
            dynamic endpoints = {
                "dynamic" = {
                    port = 0x0
                    active = 0
                    managed = 0
                    reset = 0
                    hide = 0
                    watching = 0
                }
            }
            properties = inferred program
        }
        """).serviceInfo()
        XCTAssertEqual(info.runtime.activeCount, 0)
        XCTAssertNil(info.runtime.initialized)
        XCTAssertNil(info.execution.umask)
        XCTAssertNil(info.management?.backgroundTaskManagementUUID)
        XCTAssertNil(info.lastExitReason)
        XCTAssertNil(info.endpoints)
        XCTAssertNil(info.communication?.endpoints)
        XCTAssertEqual(info.communication?.dynamicEndpoints?["dynamic"]?.port, 0)
        XCTAssertEqual(info.resources.jetsam.priority, 0)
        XCTAssertTrue(info.resources.jetsam.activeMemoryLimit.isUnlimited)
        XCTAssertEqual(info.resources.jetsam.inactiveMemoryLimit.megabytes, 0)
        XCTAssertFalse(info.resources.jetsam.inactiveMemoryLimit.isUnlimited)
    }

    /// Adds the fields present in every captured service so focused parser fixtures can omit unrelated details.
    private func parseServiceInfo(_ output: String) throws -> Launchctl.ServiceInfo {
        let requiredEntries = [
            ("type", "type = XPCService"),
            ("path", "path = /System/Library/Example.xpc"),
            ("state", "state = not running"),
            ("domain", "domain = system"),
            ("active count", "active count = 0"),
            ("runs", "runs = 0"),
            ("minimum runtime", "minimum runtime = 10"),
            ("exit timeout", "exit timeout = 5"),
            ("spawn type", "spawn type = adaptive (6)"),
            ("jetsam priority", "jetsam priority = 40"),
            ("jetsam memory limit (active)", "jetsam memory limit (active) = (unlimited)"),
            ("jetsam memory limit (inactive)", "jetsam memory limit (inactive) = (unlimited)"),
            ("jetsamproperties category", "jetsamproperties category = daemon"),
            ("properties", "properties = inferred program"),
            ("environment", "environment = {\n    }"),
            ("default environment", "default environment = {\n    }"),
        ]
        let lines = output.components(separatedBy: .newlines)
        let existingKeys = Set(lines.compactMap { line -> String? in
            guard line.hasPrefix("    "), !line.hasPrefix("        "),
                  let separator = line.range(of: " = ") else { return nil }
            let key = String(line[line.index(line.startIndex, offsetBy: 4)..<separator.lowerBound])
            if key.hasPrefix("jetsam memory limit (active") {
                return "jetsam memory limit (active)"
            }
            if key.hasPrefix("jetsam memory limit (inactive") {
                return "jetsam memory limit (inactive)"
            }
            return key
        })
        let additions = requiredEntries.compactMap { key, entry in
            existingKeys.contains(key) ? nil : "    \(entry)"
        }
        guard let closingBrace = output.range(of: "\n}", options: .backwards) else {
            throw NSError(domain: "ServiceInfoDetailsTests", code: 1)
        }
        var completeOutput = output
        completeOutput.insert(contentsOf: "\n" + additions.joined(separator: "\n"), at: closingBrace.lowerBound)
        return try OutputParser(string: completeOutput).serviceInfo()
    }

    func test_capturedServices() throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("launchd")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: directory.path), "Local launchd capture is not present")
        try checkCapturedServices(in: directory)
    }

    func test_externalCapturedServices() throws {
        let path = ProcessInfo.processInfo.environment["LAUNCHCTL_CAPTURE_DIRECTORY"]
        try XCTSkipIf(path == nil, "Set LAUNCHCTL_CAPTURE_DIRECTORY to verify an external capture")
        try checkCapturedServices(in: URL(fileURLWithPath: XCTUnwrap(path)))
    }

    private func checkCapturedServices(in directory: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "txt" }.sorted { $0.path < $1.path }
        XCTAssertFalse(files.isEmpty)
        var serviceCount = 0
        var domainCount = 0
        for file in files {
            let output = try String(contentsOf: file, encoding: .utf8)
            let parser = OutputParser(string: output)
            if parser.rootName == "system" || parser.rootName?.range(of: #"^gui/\d+$"#, options: .regularExpression) != nil {
                let services = try parser.services()
                XCTAssertFalse(services.isEmpty, file.lastPathComponent)
                domainCount += 1
                continue
            }
            let info: Launchctl.ServiceInfo
            do {
                info = try parser.serviceInfo()
            } catch {
                XCTFail("Failed to parse \(file.lastPathComponent): \((error as NSError).domain) code \((error as NSError).code)")
                continue
            }
            serviceCount += 1
            XCTAssertEqual(info.type.rawValue, try parser.string(forKey: "type"), file.lastPathComponent)
            XCTAssertEqual(info.daemon != nil, info.type == .launchDaemon, file.lastPathComponent)
            XCTAssertEqual(info.agent != nil, info.type == .launchAgent, file.lastPathComponent)
            XCTAssertEqual(info.bundle != nil, output.contains("\n\tbundle id = "), file.lastPathComponent)
            XCTAssertEqual(info.management?.manager != nil, output.contains("\n\tmanaged_by = "), file.lastPathComponent)
            XCTAssertEqual(info.management?.backgroundTaskManagementUUID != nil, output.contains("\n\tBTM uuid = "), file.lastPathComponent)
            XCTAssertEqual(info.execution.program != nil, output.contains("\n\tprogram = "), file.lastPathComponent)
            XCTAssertEqual(info.state.rawValue, try parser.string(forKey: "state"), file.lastPathComponent)
            XCTAssertEqual(info.path, try parser.string(forKey: "path"), file.lastPathComponent)
            XCTAssertEqual(info.domain, try parser.string(forKey: "domain"), file.lastPathComponent)
            XCTAssertEqual(info.properties, try parser.string(forKey: "properties").components(separatedBy: " | "), file.lastPathComponent)
            XCTAssertEqual(info.execution.spawnType.rawValue, try parser.string(forKey: "spawn type"), file.lastPathComponent)
            XCTAssertEqual(info.execution.minimumRuntime, Int(try parser.string(forKey: "minimum runtime")), file.lastPathComponent)
            XCTAssertEqual(info.execution.exitTimeout, Int(try parser.string(forKey: "exit timeout")), file.lastPathComponent)
            XCTAssertEqual(info.runtime.activeCount, Int(try parser.string(forKey: "active count")), file.lastPathComponent)
            XCTAssertEqual(info.runtime.runs, Int(try parser.string(forKey: "runs")), file.lastPathComponent)
            XCTAssertEqual(info.resources.jetsam.priority, Int(try parser.string(forKey: "jetsam priority")), file.lastPathComponent)
            XCTAssertEqual(info.resources.jetsam.category.rawValue, try parser.string(forKey: "jetsamproperties category"), file.lastPathComponent)
            XCTAssertEqual(info.serviceTarget, output.components(separatedBy: .newlines).first.map { String($0.dropLast(4)) }, file.lastPathComponent)
            checkCapturedSections(info, output: output, filename: file.lastPathComponent)
            let decoded = try JSONDecoder().decode(Launchctl.ServiceInfo.self, from: JSONEncoder().encode(info))
            XCTAssertTrue(decoded == info, "\(file.lastPathComponent): Codable round trip differs")
        }
        print("Verified \(serviceCount) service dumps and \(domainCount) domain dumps in \(directory.lastPathComponent)")
    }

    private struct CapturedSection {
        var name: String
        var keys: [String]?
        var separator = " = "
    }

    private struct CapturedEnvironment {
        var name: String
        var values: [String: String]?
    }

    private func checkCapturedSections(_ info: Launchctl.ServiceInfo, output: String, filename: String) {
        let arguments = capturedLines("arguments", in: output)?
            .filter { !$0.isEmpty }.map { String($0.dropFirst(2)) }
        // Arguments can contain private values, so do not print them in assertion failures.
        XCTAssertTrue(info.execution.arguments == arguments, "\(filename): arguments differ")
        let sections = [
            CapturedSection(name: "endpoints", keys: info.communication?.endpoints.map { Array($0.keys) }),
            CapturedSection(name: "dynamic endpoints", keys: info.communication?.dynamicEndpoints.map { Array($0.keys) }),
            CapturedSection(name: "pid-local endpoints", keys: info.communication?.pidLocalEndpoints.map { Array($0.keys) }),
            CapturedSection(name: "instance-specific endpoints", keys: info.communication?.instanceSpecificEndpoints.map { Array($0.keys) }),
            CapturedSection(name: "event channels", keys: info.communication?.eventChannels.map { Array($0.keys) }),
            CapturedSection(name: "event triggers", keys: info.communication?.eventTriggers?.map(\.name), separator: " => "),
            CapturedSection(name: "sockets", keys: info.communication?.sockets.map { Array($0.keys) }),
        ]
        for section in sections {
            let suffix = section.separator + "{"
            let keys = capturedLines(section.name, in: output)?.compactMap { line -> String? in
                guard line.hasPrefix("\t\t"), !line.hasPrefix("\t\t\t"), line.hasSuffix(suffix) else { return nil }
                let key = String(line.dropFirst(2).dropLast(suffix.count))
                return key.hasPrefix("\"") && key.hasSuffix("\"") ? String(key.dropFirst().dropLast()) : key
            }
            XCTAssertEqual(section.keys?.sorted(), keys?.sorted(), "\(filename): \(section.name)")
        }

        let endpoints = [
            info.communication?.endpoints, info.communication?.dynamicEndpoints,
            info.communication?.pidLocalEndpoints, info.communication?.instanceSpecificEndpoints,
            info.communication?.eventChannels,
        ].compactMap { $0 }.flatMap { $0.values }
        let lines = output.components(separatedBy: .newlines)
        XCTAssertEqual(endpoints.compactMap(\.watching).count, lines.filter { $0.hasPrefix("\t\t\twatching = ") }.count, filename)
        XCTAssertEqual(endpoints.compactMap(\.hostSpecialPort).count, lines.filter { $0.hasPrefix("\t\t\thost-special port = ") }.count, filename)
        XCTAssertEqual(endpoints.compactMap(\.taskSpecialPort).count, lines.filter { $0.hasPrefix("\t\t\ttask-special port = ") }.count, filename)
        XCTAssertEqual(endpoints.compactMap(\.nonLaunching).count, lines.filter { $0.hasPrefix("\t\t\tnon-launching = ") }.count, filename)

        let environments = [
            CapturedEnvironment(name: "environment", values: info.environment.generic),
            CapturedEnvironment(name: "default environment", values: info.environment.default),
            CapturedEnvironment(name: "inherited environment", values: info.environment.inherited),
        ]
        for environment in environments {
            let lines = capturedLines(environment.name, in: output)
            XCTAssertEqual(environment.values != nil, lines != nil, "\(filename): \(environment.name)")
            guard let lines else { continue }
            var expected: [String: String] = [:]
            for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                guard line.hasPrefix("\t\t"), let separator = line.range(of: " => ") else {
                    XCTFail("Unexpected environment entry format: \(filename)")
                    continue
                }
                let key = String(line[line.index(line.startIndex, offsetBy: 2)..<separator.lowerBound])
                let value = String(line[separator.upperBound...])
                expected[key] = value
            }
            // Compare values without disclosing captured environment contents in failures.
            XCTAssertTrue(environment.values == expected, "\(filename): \(environment.name) entry mismatch")
            XCTAssertEqual(environment.values?.count, expected.count, "\(filename): \(environment.name) unique key count")
        }
    }

    /// Independent expectations from the literal tab-indented capture format.
    private func capturedLines(_ section: String, in output: String) -> [String]? {
        guard let range = output.range(of: "\n\t\(section) = {\n") else { return nil }
        let body = output[range.upperBound...].components(separatedBy: "\n\t}")[0]
        return body.components(separatedBy: .newlines)
    }

}
