//  MIT License
//
//  Copyright (c) 2022 Alkenso (Vladimir Vashurkin)
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

import Foundation
import SpellbookFoundation

extension Launchctl {
    /// A service snapshot with required identity, launch policy, runtime counts
    /// and resource policy.
    /// Parsing and decoding reject missing required fields; conditional
    /// observations remain optional.
    public struct ServiceInfo: Equatable, Codable, Sendable {
        /// Full launchctl target, e.g. `system/com.apple.akd` or
        /// `gui/501/com.example.agent`.
        public var serviceTarget: String
        /// Reported service type. Captured values: `LaunchDaemon`,
        /// `LaunchAgent`, `LaunchAngel`, `XPCService`, and `Submitted`.
        /// Unknown values are preserved in `rawValue`.
        public var type: ServiceType
        /// Raw definition source; this is not necessarily a filesystem path.
        /// Captured forms include:
        /// - Plist: `path = /System/Library/LaunchDaemons/com.apple.akd.plist`
        ///   or `/Library/LaunchAgents/com.example.agent.plist`.
        /// - XPC bundle: `path = /System/Library/Example.xpc`.
        /// - Submitted source: `path = (submitted by smd.500)` or `path =
        ///   (submitted by smd[353])`.
        /// A non-optional value guarantees a reported source string, not a file
        /// or an existing path.
        public var path: String
        /// Reported domain and optional identifier, e.g. `system` or `gui/501
        /// [100016]`.
        public var domain: String

        /// Current process identifier, e.g. `928`; absent when no process is
        /// running.
        public var pid: pid_t?
        /// Reported service state. Captured values: `running`, `not running`,
        /// and `spawn scheduled`.
        public var state: ServiceState
        /// Last termination result, e.g. `.exitCode(0)` or `.signal(15)`.
        /// Raw examples: `last exit code = 0` → `.exitCode(0)`, `last exit code
        /// = 78: EX_CONFIG` → `.exitCode(78)`,
        /// `last terminating signal = Terminated: 15` → `.signal(15)`.
        /// Other captured signals: `last terminating signal = Killed: 9` and
        /// `last terminating signal = Hangup: 1`.
        /// `last exit code = (never exited)` represents no exit result and
        /// produces nil.
        public var lastExitReason: ExitReason?

        /// Required definition fields for a LaunchDaemon; mutually exclusive
        /// with `agent` when parsed.
        /// Raw fields include `type = LaunchDaemon`, `path =
        /// /Library/LaunchDaemons/com.example.service.plist`, and `program =
        /// /usr/libexec/example`.
        public var daemon: DaemonInfo?
        /// Required definition fields for a LaunchAgent; mutually exclusive
        /// with `daemon` when parsed.
        /// Raw fields include `type = LaunchAgent` and `path =
        /// /Library/LaunchAgents/com.example.agent.plist`.
        public var agent: AgentInfo?
        /// Program and parent registration metadata; may coexist with bundle
        /// and management metadata.
        /// Raw fields include `program identifier = com.example.helper (mode:
        /// 1)`,
        /// `parent bundle identifier = com.example.app`, and `parent bundle
        /// version = 1.2.3`.
        public var loginItem: LoginItemInfo?
        /// Bundle identity, independent of the service type.
        /// Raw fields include `bundle id = com.example.service` and `bundle
        /// version = 110`.
        public var bundle: BundleInfo?
        /// Manager and registration metadata, independent of the service type.
        /// Raw examples: `managed_by = com.apple.runningboard` or `BTM uuid =
        /// 00000000-0000-0000-0000-000000000001` (synthetic UUID).
        public var management: ManagementInfo?

        /// Executable, account, I/O and launch configuration shared across
        /// service types.
        /// Raw fields include `program = /usr/libexec/example`, `spawn type =
        /// adaptive (6)`, and `minimum runtime = 10`.
        public var execution: ExecutionInfo
        /// Service, default and inherited environment variables.
        /// Raw sections are `environment = {`, `default environment = {`, and
        /// `inherited environment = {`; entries use `XPC_SERVICE_NAME =>
        /// com.apple.akd`.
        public var environment: Environment
        /// IPC endpoints, activation events and sockets.
        /// Raw sections include `endpoints = {`, `event triggers = {`, and
        /// `sockets = {`.
        public var communication: CommunicationInfo?
        /// Memory policy, resource limits and coalition memberships.
        /// Raw fields/sections include `jetsam priority = 40`, `jetsam memory
        /// limit (active, soft) = 15 MB`, and `resource coalition = {`.
        public var resources: ResourceInfo
        /// Launch counters, process initialization and exit diagnostics.
        /// Raw fields include `active count = 1`, `runs = 3`, and `job state =
        /// running`.
        public var runtime: RuntimeInfo
        /// Template and instance relationships.
        /// Raw fields/sections include `original = com.example.service`,
        /// `multiple instances = 1`, and `instances = {`.
        public var instances: InstanceInfo?

        /// Audit session identifier, e.g. `100016`.
        public var asid: Int?
        /// Reported flags, e.g. `["supports transactions", "supports pressured
        /// exit"]`.
        /// Raw example: `properties = supports transactions | supports
        /// pressured exit`.
        public var properties: [String]

        /// Static endpoint names, e.g. `["com.apple.ak.auth.xpc"]`; retained
        /// for compatibility with `communication.endpoints`.
        /// Raw section `endpoints = {` contains named entries such as
        /// `"com.apple.ak.auth.xpc" = {`; only their names are retained here.
        public var endpoints: [String]?

        public init(
            serviceTarget: String,
            type: ServiceType,
            path: String,
            domain: String,
            state: ServiceState,
            properties: [String],
            execution: ExecutionInfo,
            environment: Environment,
            resources: ResourceInfo,
            runtime: RuntimeInfo,
            pid: pid_t? = nil,
            daemon: DaemonInfo? = nil,
            loginItem: LoginItemInfo? = nil,
            endpoints: [String]? = nil,
            lastExitReason: ExitReason? = nil
        ) {
            self.serviceTarget = serviceTarget
            self.type = type
            self.path = path
            self.domain = domain
            self.state = state
            self.properties = properties
            self.execution = execution
            self.environment = environment
            self.resources = resources
            self.runtime = runtime
            self.pid = pid
            self.daemon = daemon
            self.loginItem = loginItem
            self.endpoints = endpoints
            self.lastExitReason = lastExitReason
        }
    }
    
    public enum ExitReason: Equatable, Codable, Sendable {
        /// Terminating signal number, e.g. `15` for SIGTERM.
        /// Raw example: `last terminating signal = Terminated: 15` →
        /// `.signal(15)`.
        case signal(Int32)
        /// Process exit status, e.g. `0` for success.
        /// Raw examples: `last exit code = 0` → `.exitCode(0)` or `last exit
        /// code = 78: EX_CONFIG` → `.exitCode(78)`.
        case exitCode(Int32)
    }
    
    public struct DaemonInfo: Equatable, Codable, Sendable {
        /// Required daemon definition path, e.g.
        /// `/System/Library/LaunchDaemons/com.apple.akd.plist`.
        public var plistPath: String
        /// Required executable path, e.g. `/usr/libexec/example`; also
        /// available in `ServiceInfo.execution`.
        public var program: String

        public init(
            plistPath: String,
            program: String
        ) {
            self.plistPath = plistPath
            self.program = program
        }
    }
    
    public struct AgentInfo: Equatable, Codable, Sendable {
        /// Required agent definition path, e.g.
        /// `/Library/LaunchAgents/com.example.agent.plist`.
        public var plistPath: String

        public init(plistPath: String) {
            self.plistPath = plistPath
        }
    }

    public struct LoginItemInfo: Equatable, Codable, Sendable {
        /// Registered program, reported as either a bundle-style identifier or
        /// a path relative to the parent bundle.
        /// Raw examples: `program identifier = com.example.helper (mode: 1)` or
        /// `program identifier =
        /// Contents/Library/LaunchAgents/com.example.agent (mode: 2)`.
        /// The `(mode: ...)` suffix is removed from this value and exposed
        /// separately as `mode`.
        public var identifier: String
        /// Parent application's bundle identifier, e.g. `com.example.app`.
        public var parentIdentifier: String
        /// Parent application's reported version, e.g. dotted `1.2.3` or build
        /// number `93002`; retained as text.
        /// Not reported by every ServiceManagement registration.
        public var parentVersion: String?
        /// Numeric registration mode from the program identifier suffix, e.g.
        /// `1` or `2`.
        /// Older output can omit the `(mode: ...)` suffix entirely.
        public var mode: Int?

        public init(identifier: String, parentIdentifier: String, parentVersion: String? = nil, mode: Int? = nil) {
            self.identifier = identifier
            self.parentIdentifier = parentIdentifier
            self.parentVersion = parentVersion
            self.mode = mode
        }
    }
    
    public struct Environment: Equatable, Codable, Sendable {
        /// Service-specific variables, e.g. `["XPC_SERVICE_NAME":
        /// "com.apple.akd"]`.
        /// Raw section `environment = {` contains entries such as
        /// `XPC_SERVICE_NAME => com.apple.akd`.
        /// The section can be empty; an entry such as `EXAMPLE_OPTION => ` has
        /// a valid empty value.
        /// Values may contain the separator, e.g. `EXAMPLE_VALUE => one => two`
        /// is stored as `one => two`.
        public var generic: [String: String]
        /// Domain default variables, e.g. `["PATH":
        /// "/usr/bin:/bin:/usr/sbin:/sbin"]`.
        /// Raw section `default environment = {` contains entries such as `PATH
        /// => /usr/bin:/bin:/usr/sbin:/sbin`.
        public var `default`: [String: String]
        /// Inherited variables, e.g. `["SSH_AUTH_SOCK":
        /// "/private/tmp/com.apple.launchd.example/Listeners"]`.
        /// Raw section `inherited environment = {` contains entries such as
        /// `SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.example/Listeners`
        /// (generic path).
        public var inherited: [String: String]?

        public init(
            generic: [String: String],
            `default`: [String: String],
            inherited: [String : String]? = nil
        ) {
            self.generic = generic
            self.default = `default`
            self.inherited = inherited
        }
    }
}

extension Launchctl {
    /// Launch settings shared by all service types, including submitted jobs
    /// and XPC services.
    public struct ExecutionInfo: Equatable, Codable, Sendable {
        /// Executable path, e.g. `/usr/libexec/example`.
        public var program: String?
        /// Ordered arguments, including any reported executable, e.g.
        /// `["/usr/libexec/example", "--verbose"]`.
        /// Raw section `arguments = {` lists one argument per line, e.g.
        /// `/usr/libexec/example` followed by `--verbose`.
        /// An indented empty line is an empty argument; spaces within an entry
        /// such as `argument with spaces` are preserved.
        public var arguments: [String]?
        /// Working directory, e.g. `/var/empty`.
        public var workingDirectory: String?

        /// Account used to execute the service, e.g. `_driverkit`.
        public var username: String?
        /// Execution group, e.g. `_mdnsresponder`.
        public var group: String?

        /// Standard input path, e.g. `/dev/null`.
        public var stdinPath: String?
        /// Standard output path, e.g. `/var/log/example.log`.
        public var stdoutPath: String?
        /// Standard error path, e.g. `/var/log/example-error.log`.
        public var stderrPath: String?
        /// File creation mask parsed as octal, e.g. `0o22` for output `022`.
        public var umask: UInt32?
        /// Scheduling niceness adjustment, e.g. `-1`.
        public var nice: Int?

        /// Reported launch policy and numeric code. Captured values: `app (1)`,
        /// `daemon (3)`,
        /// `interactive (4)`, `background (5)`, `adaptive (6)`, and ` (7)`.
        /// DriverKit captures use `spawn type =  (7)`: the policy name is empty
        /// but the numeric code remains.
        public var spawnType: SpawnType
        /// Reported process role and numeric code. Captured values: `ui (2)`,
        /// `non-ui (3)`, `ui non-focal (4)`, and `darwin bg (6)`.
        public var spawnRole: SpawnRole?
        /// Scheduled launch interval in seconds, e.g. `3600`.
        public var runInterval: Int?
        /// Minimum runtime in seconds, e.g. `10`.
        public var minimumRuntime: Int
        /// Base minimum runtime in seconds, e.g. `10`.
        public var baseMinimumRuntime: Int?
        /// Graceful exit timeout in seconds, e.g. `5`.
        public var exitTimeout: Int
        /// Reported exponential-throttling grace limit, e.g. `5`.
        public var exponentialThrottlingGraceLimit: Int?

        /// Sandbox profile name, e.g. `com.apple.dext`.
        public var sandboxProfile: String?
        /// Cryptex identifier, e.g. `com.apple.cryptex.app`.
        public var cryptex: String?
        /// Conclave identifier, e.g. `com.apple.audiomxd.conclave`; observed on
        /// daemons but not restricted to them.
        public var conclave: String?

        public init(spawnType: SpawnType, minimumRuntime: Int, exitTimeout: Int) {
            self.spawnType = spawnType
            self.minimumRuntime = minimumRuntime
            self.exitTimeout = exitTimeout
        }
    }

    /// Runtime observations shared across service types; absent values were not
    /// reported.
    public struct RuntimeInfo: Equatable, Codable, Sendable {
        /// Reported job state. Captured values: `running`, `exited`, `spawn
        /// failed`, and `uninitialized`.
        public var jobState: JobState?
        /// Current active count, e.g. `1`.
        public var activeCount: Int
        /// Number of launches, e.g. `3`.
        public var runs: Int
        /// Reported immediate launch reason. Captured values: `ipc (mach)`,
        /// `ipc (socket)`, `xpc event`,
        /// `speculative`, `system support`, `launch job demand`, `semaphore`,
        /// `event publisher`, `non-ipc demand`, and `inefficient`.
        public var immediateReason: LaunchReason?
        /// Raw exit-reason annotation, e.g.
        /// `JETSAM_REASON_MEMORY_PERPROCESSLIMIT`.
        public var lastExitDescription: String?
        /// Raw jetsam exit details, e.g.
        /// `JETSAM_REASON_MEMORY_PERPROCESSLIMIT`.
        public var lastJetsamExitDetails: String?

        /// Reported fork count, e.g. `1`.
        public var forks: Int?
        /// Reported exec count, e.g. `1`.
        public var execs: Int?
        /// Whether initialization completed, e.g. `true` for output `1`.
        public var initialized: Bool?
        /// Whether the process passed through the launch trampoline, e.g.
        /// `true`.
        public var trampolined: Bool?
        /// Whether the process started suspended, e.g. `false`.
        public var startedSuspended: Bool?
        /// Whether its proxy started suspended, e.g. `false`.
        public var proxyStartedSuspended: Bool?

        public init(activeCount: Int, runs: Int) {
            self.activeCount = activeCount
            self.runs = runs
        }
    }

    /// Template and instance relationships reported by launchd.
    public struct InstanceInfo: Equatable, Codable, Sendable {
        /// Original service label, e.g. `com.example.service`.
        public var original: String?
        /// Reported instance labels, e.g. `["com.example.service.instance"]`.
        /// Raw section `instances = {` lists entries such as
        /// `com.example.service.instance,`; the trailing comma is removed.
        public var names: [String]?
        /// Whether multiple instances are enabled, e.g. `true`.
        public var multipleInstances: Bool?
        /// Reported copy count, e.g. `1`.
        public var copyCount: Int?

        public init() {}
    }

    /// Separate IPC namespaces, activation events, sockets and keepalive
    /// conditions.
    public struct CommunicationInfo: Equatable, Codable, Sendable {
        /// Static endpoints keyed by name, e.g. `com.apple.ak.auth.xpc` with
        /// port and activity details.
        /// Raw section `endpoints = {` contains entries such as
        /// `"com.apple.ak.auth.xpc" = {`, with fields including `port = 0x303`
        /// and `active = 1`.
        public var endpoints: [String: EndpointInfo]?
        /// Dynamic endpoints keyed by name, e.g. `com.example.dynamic` with
        /// port details.
        /// Raw section `dynamic endpoints = {` contains entries such as
        /// `"com.example.dynamic" = {`, with fields including `port = 0x303`.
        public var dynamicEndpoints: [String: EndpointInfo]?
        /// Process-local endpoints keyed by name, e.g. `com.example.local` with
        /// port details.
        /// Raw section `pid-local endpoints = {` contains entries such as
        /// `"com.example.local" = {`, with fields including `port = 0x303`.
        public var pidLocalEndpoints: [String: EndpointInfo]?
        /// Instance endpoints keyed by name, e.g. `com.example.instance` with
        /// port details.
        /// Raw section `instance-specific endpoints = {` contains entries such
        /// as `"com.example.instance" = {`, with fields including `port =
        /// 0x303`.
        public var instanceSpecificEndpoints: [String: EndpointInfo]?
        /// Sockets keyed by definition name, e.g. `Listeners` with socket path
        /// and descriptor details.
        /// Raw section `sockets = {` contains entries such as `"Listeners" =
        /// {`.
        /// Unix-domain entries report `path = /var/run/example.sock`; network
        /// entries can report
        /// `node name = 0.0.0.0` and `service name = netbios-dgm`.
        /// A special entry contains only `(system logger socket)`, with no
        /// normal socket fields.
        public var sockets: [String: SocketInfo]?
        /// Ordered triggers, e.g. one named `com.example.activity`; names may
        /// repeat across event streams.
        /// Raw section `event triggers = {` contains entries such as
        /// `"com.example.activity" => {`, with fields including `stream =
        /// com.apple.xpc.activity` and `keepalive = 1`.
        public var eventTriggers: [EventTriggerInfo]?
        /// Event endpoints keyed by stream name, e.g. `com.apple.xpc.activity`
        /// with port details.
        /// Raw section `event channels = {` contains entries such as
        /// `"com.apple.xpc.activity" = {`, with fields including `port =
        /// 0x303`.
        public var eventChannels: [String: EndpointInfo]?
        /// Keepalive conditions keyed by name, e.g. `["successful exit": "0"]`.
        /// Raw section `semaphores = {` contains entries such as `successful
        /// exit => 0`.
        public var semaphores: [String: String]?

        public init() {}
    }

    /// Resource policy and coalition memberships shared across service types.
    public struct ResourceInfo: Equatable, Codable, Sendable {
        /// Jetsam priority, category and memory/resource limits.
        /// Raw fields include `jetsam priority = 40`, `jetsamproperties
        /// category = daemon`, and `jetsam memory limit (active, soft) = 15
        /// MB`.
        public var jetsam: JetsamInfo
        /// Reported limits keyed by resource and enforcement, e.g. `["core
        /// (soft)": "(infinity)"]`.
        /// Raw section `resource limits = {` contains numeric or unlimited
        /// values, e.g.
        /// `maxfiles (hard) => 2048` or `core (soft) => (infinity)`; both
        /// remain strings.
        public var resourceLimits: [String: String]?
        /// Resource-accounting coalition membership.
        /// Raw section `resource coalition = {` contains fields such as `ID =
        /// 511`, `type = resource`, `state = active`, and `name =
        /// com.example.service`.
        public var resourceCoalition: CoalitionInfo?
        /// Jetsam coalition membership, distinct from the service's own bundle
        /// identity.
        /// Raw section `jetsam coalition = {` contains fields such as `ID =
        /// 512`, `type = jetsam`, and `bundle ID = com.example.app`.
        public var jetsamCoalition: CoalitionInfo?

        public init(jetsam: JetsamInfo) {
            self.jetsam = jetsam
        }
    }

    /// Bundle metadata independent of whether the service is a daemon, agent,
    /// XPC or submitted job.
    public struct BundleInfo: Equatable, Codable, Sendable {
        /// Service bundle identifier, e.g. `com.example.service`.
        public var identifier: String
        /// Service bundle version, e.g. `110`.
        public var version: String?

        public init(identifier: String) {
            self.identifier = identifier
        }
    }

    /// Management and registration metadata. A BTM registration need not have a
    /// manager or be a login item.
    public struct ManagementInfo: Equatable, Codable, Sendable {
        /// Explicit `managed_by` value, e.g. `com.apple.runningboard`; absence
        /// does not rule out BTM registration.
        public var manager: String?
        /// BTM registration UUID, e.g. `00000000-0000-0000-0000-000000000001`
        /// (synthetic).
        /// Raw example: `BTM uuid = 00000000-0000-0000-0000-000000000001`
        /// (synthetic).
        public var backgroundTaskManagementUUID: UUID?
        /// Raw DriverKit check-in port description, e.g. `0x3bd03 [type 27,
        /// object 0]`.
        public var dextCheckinPort: String?

        public init() {}
    }

    public struct EndpointInfo: Equatable, Codable, Sendable {
        /// Mach port value parsed from hexadecimal, e.g. `port = 0x303`; `port
        /// = 0x0` is a valid reported zero value.
        public var port: UInt64
        /// Whether the endpoint is active, e.g. `true`.
        public var active: Bool
        /// Whether launchd reports the endpoint as managed, e.g. `true`.
        public var managed: Bool
        /// Reported non-launching flag, e.g. `true` for output `1`.
        public var nonLaunching: Bool?
        /// Host special-port slot and optional annotation, e.g. slot `35` named
        /// `doubleagentd`.
        /// Raw example: `host-special port = 35 (doubleagentd)` →
        /// `.init(number: 35, name: "doubleagentd")`.
        public var hostSpecialPort: SpecialPortInfo?
        /// Task special-port slot and optional annotation, e.g. slot `9` named
        /// `access`.
        /// Raw example: `task-special port = 9 (access)` → `.init(number: 9,
        /// name: "access")`.
        public var taskSpecialPort: SpecialPortInfo?
        /// Reported reset flag, e.g. `false`.
        public var reset: Bool
        /// Reported hide flag, e.g. `false`.
        public var hide: Bool
        /// Reported watching flag, e.g. `false`.
        /// Older endpoint output can omit this flag; nil is not false.
        public var watching: Bool?

        public init(port: UInt64, active: Bool, managed: Bool, reset: Bool, hide: Bool, watching: Bool? = nil) {
            self.port = port
            self.active = active
            self.managed = managed
            self.reset = reset
            self.hide = hide
            self.watching = watching
        }
    }

    /// A special-port slot number and launchctl's optional role annotation.
    public struct SpecialPortInfo: Equatable, Codable, Sendable {
        /// Special-port slot number, e.g. `35`.
        public var number: Int
        /// Optional role annotation, e.g. `doubleagentd` or `sysdiagnose
        /// notification`.
        public var name: String?

        public init(number: Int, name: String? = nil) {
            self.number = number
            self.name = name
        }
    }

    public struct CoalitionInfo: Equatable, Codable, Sendable {
        /// Coalition identifier, e.g. `511`.
        public var id: Int
        /// Coalition name, e.g. `com.example.service`.
        public var name: String
        /// Coalition type, e.g. `resource` or `jetsam`.
        public var type: CoalitionType
        /// Coalition bundle identifier, e.g. `com.example.app`; distinct from
        /// the service's bundle identifier.
        public var bundleID: String?
        /// Reported coalition state, e.g. `active`.
        public var state: CoalitionState
        /// Coalition active count, e.g. `1`.
        public var activeCount: Int

        public init(id: Int, name: String, type: CoalitionType, state: CoalitionState, activeCount: Int) {
            self.id = id
            self.name = name
            self.type = type
            self.state = state
            self.activeCount = activeCount
        }
    }

    public struct MemoryLimit: Equatable, Codable, Sendable {
        public enum Enforcement: String, Codable, Sendable {
            /// Raw key annotation, e.g. `jetsam memory limit (active, soft) =
            /// 15 MB`.
            case soft
            /// Raw key annotation, e.g. `jetsam memory limit (inactive, hard) =
            /// (unlimited)`.
            case hard
        }

        /// Memory limit in megabytes. Raw values `15 MB` and `0 MB` become `15`
        /// and `0`;
        /// `(unlimited)` becomes nil. Zero and unlimited are distinct; nil does
        /// not mean a missing field.
        public var megabytes: Int?
        /// Optional enforcement annotation, e.g. `.soft` or `.hard`.
        /// Raw examples: `jetsam memory limit (active, soft) = 15 MB` →
        /// `.soft`,
        /// `jetsam memory limit (inactive, hard) = (unlimited)` → `.hard`;
        /// `jetsam memory limit (active) = 15 MB` has no enforcement
        /// annotation.
        public var enforcement: Enforcement?
        /// Whether the reported limit is unlimited, e.g. `true` for
        /// `(unlimited)`.
        public var isUnlimited: Bool { megabytes == nil }

        public init(megabytes: Int?, enforcement: Enforcement? = nil) {
            self.megabytes = megabytes
            self.enforcement = enforcement
        }
    }

    public struct JetsamInfo: Equatable, Codable, Sendable {
        /// Jetsam priority, e.g. `40`.
        public var priority: Int
        /// Jetsam properties category. Captured values: `daemon`, `app`,
        /// `system xpcservice`, and `DriverKit`.
        public var category: JetsamCategory
        /// Memory limit while active, e.g. `15` MB with soft enforcement.
        /// Raw example: `jetsam memory limit (active, soft) = 15 MB` →
        /// `.init(megabytes: 15, enforcement: .soft)`.
        /// Also reported as `jetsam memory limit (active) = (unlimited)` →
        /// `.init(megabytes: nil)`;
        /// numeric and unlimited values are independent of whether an
        /// enforcement annotation is present.
        public var activeMemoryLimit: MemoryLimit
        /// Memory limit while inactive, e.g. unlimited with hard enforcement.
        /// Raw example: `jetsam memory limit (inactive, hard) = (unlimited)` →
        /// `.init(megabytes: nil, enforcement: .hard)`.
        /// Other key forms: `jetsam memory limit (inactive, soft) = 15 MB` and
        /// `jetsam memory limit (inactive) = 0 MB`.
        /// Each form can contain a numeric limit or `(unlimited)`.
        public var inactiveMemoryLimit: MemoryLimit
        /// Reported thread limit, e.g. `32`.
        public var threadLimit: Int?
        /// Soft Mach-port limit, e.g. `2500`.
        public var softPortLimit: Int?
        /// Hard Mach-port limit, e.g. `25000`.
        public var hardPortLimit: Int?
        /// Soft file-descriptor limit, e.g. `1000`.
        public var softFileDescriptorLimit: Int?
        /// Hard file-descriptor limit, e.g. `10000`.
        public var hardFileDescriptorLimit: Int?
        /// Raw conclave memory limit, e.g. `5`; launchctl does not print a
        /// unit.
        public var conclaveMemoryLimit: Int?

        public init(priority: Int, category: JetsamCategory, activeMemoryLimit: MemoryLimit, inactiveMemoryLimit: MemoryLimit) {
            self.priority = priority
            self.category = category
            self.activeMemoryLimit = activeMemoryLimit
            self.inactiveMemoryLimit = inactiveMemoryLimit
        }
    }

    public struct SocketInfo: Equatable, Codable, Sendable {
        /// Socket type, e.g. `stream` or `datagram`.
        public var type: SocketType?
        /// Unix-domain socket path, e.g. `/var/run/example.sock`; absent for
        /// network sockets and the system-logger marker.
        public var path: String?
        /// Network bind node, reported as an address or hostname, e.g. `node
        /// name = 0.0.0.0` or `node name = localhost`.
        public var nodeName: String?
        /// Network service, reported as a symbolic name or decimal port string.
        /// Captured examples: `service name = netbios-dgm`, `netbios-ns`,
        /// `vnc-server`, `ssh`, or `8021`.
        public var serviceName: String?
        /// Socket address family, e.g. `ipv4`.
        public var family: SocketFamily?
        /// Socket protocol, e.g. `udp`.
        public var protocolName: SocketProtocol?
        /// Descriptor numbers with readiness annotations, e.g. `["10 (no bytes
        /// to read)"]`.
        /// Raw nested section `sockets = {` lists one descriptor per line, e.g.
        /// `10 (no bytes to read)`.
        public var descriptors: [String]?
        /// Whether the socket is active, e.g. `true`.
        public var active: Bool?
        /// Whether the socket is passive, e.g. `true`.
        public var passive: Bool?

        /// Socket file mode parsed as octal, e.g. `0o666`.
        public var mode: UInt32?
        /// Socket owner user ID, e.g. `0`.
        public var ownerUID: UInt32?
        /// Socket group ID, e.g. `0`.
        public var groupID: UInt32?
        /// Environment key for a securely created socket, e.g. `SSH_AUTH_SOCK`.
        public var secureKey: String?
        /// Reported Bonjour flag, e.g. `false`.
        public var bonjour: Bool?
        /// Reported IPv4/IPv6 flag, e.g. `true`.
        public var ipv4v6: Bool?
        /// Whether packet information is requested, e.g. `false`.
        public var receivePacketInfo: Bool?
        /// Whether the socket requires renaming, e.g. `false`.
        public var needsRename: Bool?
        /// Whether the entry contains only `(system logger socket)`. This
        /// produces `true` with all other fields nil.
        /// A normal entry with fields such as `type = stream` produces `false`.
        public var isSystemLogger = false

        public init() {}
    }

    public struct EventTriggerInfo: Equatable, Codable, Sendable {
        /// Trigger name, e.g. `com.example.activity`; not necessarily unique
        /// across streams.
        public var name: String
        /// Event stream name, e.g. `com.apple.xpc.activity`.
        public var stream: String
        /// Associated service label, e.g. `com.example.service`.
        public var service: String
        /// Event monitor name, e.g. `com.apple.UserEventAgent-System`.
        public var monitor: String?
        /// Reported keepalive flag, e.g. `true`.
        public var keepAlive: Bool
        /// Unmodified publisher-specific container body from `descriptor = {`;
        /// its shape depends on the event stream.
        /// Examples include numeric `"Interval" => 3600`, Boolean `"init" =>
        /// true`,
        /// string `"Notification" =>
        /// "com.apple.networkextension.apps-changed"`, and nested `"Payload" =>
        /// {` containers.
        /// The body is retained as raw text rather than restricted to one
        /// descriptor schema.
        public var descriptor: String

        public init(name: String, stream: String, service: String, keepAlive: Bool, descriptor: String) {
            self.name = name
            self.stream = stream
            self.service = service
            self.keepAlive = keepAlive
            self.descriptor = descriptor
        }
    }
}

extension Launchctl {
    /// Service classification from `type`.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct ServiceType: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `LaunchDaemon`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `LaunchDaemon`.
        public static let launchDaemon = Self(rawValue: "LaunchDaemon")
        /// Raw value: `LaunchAgent`.
        public static let launchAgent = Self(rawValue: "LaunchAgent")
        /// Raw value: `LaunchAngel`.
        public static let launchAngel = Self(rawValue: "LaunchAngel")
        /// Raw value: `XPCService`.
        public static let xpcService = Self(rawValue: "XPCService")
        /// Raw value: `Submitted`.
        public static let submitted = Self(rawValue: "Submitted")
    }

    /// Service status from `state`.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct ServiceState: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `running`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `running`.
        public static let running = Self(rawValue: "running")
        /// Raw value: `not running`.
        public static let notRunning = Self(rawValue: "not running")
        /// Raw value: `spawn scheduled`.
        public static let spawnScheduled = Self(rawValue: "spawn scheduled")
    }

    /// Launch policy from `spawn type`, including its numeric annotation.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct SpawnType: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `app (1)`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `app (1)`.
        public static let app = Self(rawValue: "app (1)")
        /// Raw value: `daemon (3)`.
        public static let daemon = Self(rawValue: "daemon (3)")
        /// Raw value: `interactive (4)`.
        public static let interactive = Self(rawValue: "interactive (4)")
        /// Raw value: `background (5)`.
        public static let background = Self(rawValue: "background (5)")
        /// Raw value: `adaptive (6)`.
        public static let adaptive = Self(rawValue: "adaptive (6)")
    }

    /// Process role from `spawn role`, including its numeric annotation.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct SpawnRole: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `ui (2)`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `ui (2)`.
        public static let ui = Self(rawValue: "ui (2)")
        /// Raw value: `non-ui (3)`.
        public static let nonUI = Self(rawValue: "non-ui (3)")
        /// Raw value: `ui non-focal (4)`.
        public static let uiNonFocal = Self(rawValue: "ui non-focal (4)")
        /// Raw value: `darwin bg (6)`.
        public static let darwinBackground = Self(rawValue: "darwin bg (6)")
    }

    /// Process lifecycle state from `job state`.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct JobState: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `running`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `running`.
        public static let running = Self(rawValue: "running")
        /// Raw value: `exited`.
        public static let exited = Self(rawValue: "exited")
        /// Raw value: `spawn failed`.
        public static let spawnFailed = Self(rawValue: "spawn failed")
        /// Raw value: `uninitialized`.
        public static let uninitialized = Self(rawValue: "uninitialized")
    }

    /// Launch cause from `immediate reason`.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct LaunchReason: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `ipc (mach)`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `ipc (mach)`.
        public static let ipcMach = Self(rawValue: "ipc (mach)")
        /// Raw value: `ipc (socket)`.
        public static let ipcSocket = Self(rawValue: "ipc (socket)")
        /// Raw value: `xpc event`.
        public static let xpcEvent = Self(rawValue: "xpc event")
        /// Raw value: `speculative`.
        public static let speculative = Self(rawValue: "speculative")
        /// Raw value: `system support`.
        public static let systemSupport = Self(rawValue: "system support")
        /// Raw value: `launch job demand`.
        public static let launchJobDemand = Self(rawValue: "launch job demand")
        /// Raw value: `semaphore`.
        public static let semaphore = Self(rawValue: "semaphore")
        /// Raw value: `event publisher`.
        public static let eventPublisher = Self(rawValue: "event publisher")
        /// Raw value: `non-ipc demand`.
        public static let nonIPCDemand = Self(rawValue: "non-ipc demand")
        /// Raw value: `inefficient`.
        public static let inefficient = Self(rawValue: "inefficient")
    }

    /// Coalition classification from its nested `type` field.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct CoalitionType: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `resource`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `resource`.
        public static let resource = Self(rawValue: "resource")
        /// Raw value: `jetsam`.
        public static let jetsam = Self(rawValue: "jetsam")
    }

    /// Coalition status from its nested `state` field.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct CoalitionState: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `active`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `active`.
        public static let active = Self(rawValue: "active")
    }

    /// Resource-policy category from `jetsamproperties category`.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct JetsamCategory: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `daemon`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `daemon`.
        public static let daemon = Self(rawValue: "daemon")
        /// Raw value: `app`.
        public static let app = Self(rawValue: "app")
        /// Raw value: `system xpcservice`.
        public static let systemXPCService = Self(rawValue: "system xpcservice")
        /// Raw value: `DriverKit`.
        public static let driverKit = Self(rawValue: "DriverKit")
    }

    /// Socket kind from its nested `type` field.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct SocketType: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `stream`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `stream`.
        public static let stream = Self(rawValue: "stream")
        /// Raw value: `datagram`.
        public static let datagram = Self(rawValue: "datagram")
    }

    /// Socket address family from `family`.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct SocketFamily: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `ipv4`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `ipv4`.
        public static let ipv4 = Self(rawValue: "ipv4")
    }

    /// Socket transport protocol from `protocol`.
    /// Unknown values are preserved; Codable uses the raw string.
    public struct SocketProtocol: RawRepresentable, Hashable, Codable, Sendable {
        /// Unmodified tool value, e.g. `udp`.
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Raw value: `udp`.
        public static let udp = Self(rawValue: "udp")
    }
}

extension OutputParser {
    internal func serviceInfo() throws -> Launchctl.ServiceInfo {
        var value = try Launchctl.ServiceInfo(
            serviceTarget: requiredValue(rootName, forKey: "service target"),
            type: .init(rawValue: requiredString(forKey: "type")),
            path: requiredString(forKey: "path"),
            domain: requiredString(forKey: "domain"),
            state: .init(rawValue: requiredString(forKey: "state")),
            properties: requiredString(forKey: "properties").components(separatedBy: " | "),
            execution: executionInfo(),
            environment: environment(),
            resources: resourcesInfo(),
            runtime: runtimeInfo(),
            pid: (try? string(forKey: "pid")).flatMap(pid_t.init),
            daemon: daemonInfo(),
            loginItem: loginItemInfo(),
            lastExitReason: exitReason()
        )

        try parseDetails(into: &value)
        guard value.execution.program != nil || value.loginItem != nil else {
            throw NSError(launchctlExitCode: 109, stderr: "Service information has unsupported format.")
        }
        return value
    }

    private func requiredValue<Value>(_ value: Value?, forKey key: String) throws -> Value {
        guard let value else {
            throw NSError(launchctlExitCode: 109, stderr: "Service information has a missing or invalid field: \(key).")
        }
        return value
    }

    private func requiredString(forKey key: String) throws -> String {
        try requiredValue(try? string(forKey: key), forKey: key)
    }

    private func requiredInteger(forKey key: String) throws -> Int {
        try requiredValue(integer(forKey: key), forKey: key)
    }

    fileprivate func exitReason() -> Launchctl.ExitReason? {
        if let signal = (try? string(forKey: "last terminating signal"))?
            .components(separatedBy: ": ").last.flatMap(Int32.init) {
            return .signal(signal)
        } else if let code = (try? string(forKey: "last exit code"))?
            .components(separatedBy: ":").first.flatMap(Int32.init) {
            return .exitCode(code)
        } else {
            return nil
        }
    }
    
    fileprivate func daemonInfo() -> Launchctl.DaemonInfo? {
        guard (try? string(forKey: "type")).map(Launchctl.ServiceType.init(rawValue:)) == .launchDaemon else { return nil }
        do {
            return .init(
                plistPath: try string(forKey: "path"),
                program: try string(forKey: "program")
            )
        } catch {
            return nil
        }
    }
    
    func agentInfo() -> Launchctl.AgentInfo? {
        guard (try? string(forKey: "type")).map(Launchctl.ServiceType.init(rawValue:)) == .launchAgent,
              let path = try? string(forKey: "path") else { return nil }
        return .init(plistPath: path)
    }

    fileprivate func loginItemInfo() throws -> Launchctl.LoginItemInfo? {
        guard (try? string(forKey: "program identifier")) != nil
            || (try? string(forKey: "parent bundle identifier")) != nil
            || (try? string(forKey: "parent bundle version")) != nil else { return nil }
        let identifier = try requiredString(forKey: "program identifier")
        let parentIdentifier = try requiredString(forKey: "parent bundle identifier")
        let modeRange = identifier.range(of: " (mode: ", options: .backwards)
        let mode = modeRange.flatMap { range in
            identifier.hasSuffix(")") ? Int(identifier[range.upperBound...].dropLast()) : nil
        }
        return .init(
            identifier: modeRange.map { String(identifier[..<$0.lowerBound]) } ?? identifier,
            parentIdentifier: parentIdentifier,
            parentVersion: try? string(forKey: "parent bundle version"),
            mode: mode
        )
    }
    
    fileprivate func environment() throws -> Launchctl.Environment {
        try .init(
            generic: requiredValue(try? stringDictionary(forKey: "environment"), forKey: "environment"),
            default: requiredValue(try? stringDictionary(forKey: "default environment"), forKey: "default environment"),
            inherited: try? stringDictionary(forKey: "inherited environment")
        )
    }
}

extension OutputParser {
    func parseDetails(into info: inout Launchctl.ServiceInfo) throws {
        info.asid = integer(forKey: "asid")
        info.agent = agentInfo()
        info.instances = instancesInfo()
        info.communication = try communicationInfo()
        info.bundle = try bundleInfo()
        info.management = managementInfo()
        info.endpoints = info.communication?.endpoints?.keys.sorted()
    }

    private func executionInfo() throws -> Launchctl.ExecutionInfo {
        var value = try Launchctl.ExecutionInfo(
            spawnType: .init(rawValue: requiredString(forKey: "spawn type")),
            minimumRuntime: requiredInteger(forKey: "minimum runtime"),
            exitTimeout: requiredInteger(forKey: "exit timeout")
        )
        value.program = try? string(forKey: "program")
        value.arguments = try? stringArray(forKey: "arguments")
        value.username = try? string(forKey: "username")
        value.group = try? string(forKey: "group")
        value.workingDirectory = try? string(forKey: "working directory")
        value.stdinPath = try? string(forKey: "stdin path")
        value.stdoutPath = try? string(forKey: "stdout path")
        value.stderrPath = try? string(forKey: "stderr path")
        value.umask = (try? string(forKey: "umask")).flatMap { UInt32($0, radix: 8) }
        value.nice = integer(forKey: "nice")
        value.baseMinimumRuntime = integer(forKey: "base minimum runtime")
        value.runInterval = (try? string(forKey: "run interval"))?.split(separator: " ").first.flatMap { Int($0) }
        value.exponentialThrottlingGraceLimit = integer(forKey: "exponential throttling grace limit")
        value.spawnRole = (try? string(forKey: "spawn role")).map(Launchctl.SpawnRole.init(rawValue:))
        value.cryptex = try? string(forKey: "cryptex")
        value.sandboxProfile = try? string(forKey: "sandbox profile")
        value.conclave = try? string(forKey: "conclave")
        return value
    }

    private func runtimeInfo() throws -> Launchctl.RuntimeInfo {
        var value = try Launchctl.RuntimeInfo(
            activeCount: requiredInteger(forKey: "active count"),
            runs: requiredInteger(forKey: "runs")
        )
        value.immediateReason = (try? string(forKey: "immediate reason")).map(Launchctl.LaunchReason.init(rawValue:))
        value.forks = integer(forKey: "forks")
        value.execs = integer(forKey: "execs")
        value.initialized = boolean(forKey: "initialized")
        value.trampolined = boolean(forKey: "trampolined")
        value.startedSuspended = boolean(forKey: "started suspended")
        value.proxyStartedSuspended = boolean(forKey: "proxy started suspended")
        value.jobState = (try? string(forKey: "job state")).map(Launchctl.JobState.init(rawValue:))
        value.lastExitDescription = try? string(forKey: "last exit reason")
        value.lastJetsamExitDetails = try? string(forKey: "last jetsam exit details")
        return value
    }

    private func instancesInfo() -> Launchctl.InstanceInfo? {
        var value = Launchctl.InstanceInfo()
        value.original = try? string(forKey: "original")
        value.copyCount = integer(forKey: "copy count")
        value.multipleInstances = boolean(forKey: "multiple instances")
        value.names = (try? stringArray(forKey: "instances"))?.map {
            $0.hasSuffix(",") ? String($0.dropLast()) : $0
        }
        return value == Launchctl.InstanceInfo() ? nil : value
    }

    private func communicationInfo() throws -> Launchctl.CommunicationInfo? {
        var value = Launchctl.CommunicationInfo()
        value.endpoints = try endpointInfo(forKey: "endpoints")
        value.dynamicEndpoints = try endpointInfo(forKey: "dynamic endpoints")
        value.pidLocalEndpoints = try endpointInfo(forKey: "pid-local endpoints")
        value.instanceSpecificEndpoints = try endpointInfo(forKey: "instance-specific endpoints")
        value.eventChannels = try endpointInfo(forKey: "event channels")
        value.eventTriggers = try eventTriggers()
        value.sockets = socketInfo()
        value.semaphores = try? stringDictionary(forKey: "semaphores")
        return value == Launchctl.CommunicationInfo() ? nil : value
    }

    private func resourcesInfo() throws -> Launchctl.ResourceInfo {
        var value = try Launchctl.ResourceInfo(
            jetsam: jetsamInfo()
        )
        value.resourceLimits = try? stringDictionary(forKey: "resource limits")
        value.resourceCoalition = try coalitionInfo(forKey: "resource coalition")
        value.jetsamCoalition = try coalitionInfo(forKey: "jetsam coalition")
        return value
    }

    private func bundleInfo() throws -> Launchctl.BundleInfo? {
        guard (try? string(forKey: "bundle id")) != nil || (try? string(forKey: "bundle version")) != nil else { return nil }
        var value = try Launchctl.BundleInfo(identifier: requiredString(forKey: "bundle id"))
        value.version = try? string(forKey: "bundle version")
        return value
    }

    private func managementInfo() -> Launchctl.ManagementInfo? {
        var value = Launchctl.ManagementInfo()
        value.manager = try? string(forKey: "managed_by")
        value.backgroundTaskManagementUUID = (try? string(forKey: "BTM uuid")).flatMap(UUID.init(uuidString:))
        value.dextCheckinPort = try? string(forKey: "dext checkin port")
        return value == Launchctl.ManagementInfo() ? nil : value
    }

    private func integer(forKey key: String) -> Int? {
        (try? string(forKey: key)).flatMap(Int.init)
    }

    private func boolean(forKey key: String) -> Bool? {
        switch try? string(forKey: key) {
        case "1": return true
        case "0": return false
        default: return nil
        }
    }

    private func endpointInfo(forKey key: String) throws -> [String: Launchctl.EndpointInfo]? {
        guard let body = try? container(forKey: key),
              let entries = try? OutputParser(string: body).containers() else { return nil }
        return try entries.mapValues { body in
            let parser = OutputParser(string: body)
            let port = (try? parser.string(forKey: "port")).flatMap {
                $0.hasPrefix("0x") ? UInt64($0.dropFirst(2), radix: 16) : UInt64($0)
            }
            var value = try Launchctl.EndpointInfo(
                port: requiredValue(port, forKey: "port"),
                active: requiredValue(parser.boolean(forKey: "active"), forKey: "active"),
                managed: requiredValue(parser.boolean(forKey: "managed"), forKey: "managed"),
                reset: requiredValue(parser.boolean(forKey: "reset"), forKey: "reset"),
                hide: requiredValue(parser.boolean(forKey: "hide"), forKey: "hide"),
                watching: parser.boolean(forKey: "watching")
            )
            value.hostSpecialPort = parser.specialPort(forKey: "host-special port")
            value.taskSpecialPort = parser.specialPort(forKey: "task-special port")
            value.nonLaunching = parser.boolean(forKey: "non-launching")
            return value
        }
    }

    private func specialPort(forKey key: String) -> Launchctl.SpecialPortInfo? {
        guard let text = try? string(forKey: key) else { return nil }
        let parts = text.split(separator: " ", maxSplits: 1)
        guard let first = parts.first, let number = Int(first) else { return nil }
        guard parts.count == 2 else { return .init(number: number) }
        let annotation = parts[1].trimmingCharacters(in: .whitespaces)
        guard annotation.hasPrefix("("), annotation.hasSuffix(")") else { return nil }
        return .init(number: number, name: String(annotation.dropFirst().dropLast()))
    }

    private func coalitionInfo(forKey key: String) throws -> Launchctl.CoalitionInfo? {
        guard let body = try? container(forKey: key) else { return nil }
        let parser = OutputParser(string: body)
        var value = try Launchctl.CoalitionInfo(
            id: parser.requiredInteger(forKey: "ID"),
            name: parser.requiredString(forKey: "name"),
            type: .init(rawValue: parser.requiredString(forKey: "type")),
            state: .init(rawValue: parser.requiredString(forKey: "state")),
            activeCount: parser.requiredInteger(forKey: "active count")
        )
        value.bundleID = try? parser.string(forKey: "bundle ID")
        return value
    }

    private func jetsamInfo() throws -> Launchctl.JetsamInfo {
        var value = try Launchctl.JetsamInfo(
            priority: requiredInteger(forKey: "jetsam priority"),
            category: .init(rawValue: requiredString(forKey: "jetsamproperties category")),
            activeMemoryLimit: requiredValue(memoryLimit(state: "active"), forKey: "jetsam memory limit (active)"),
            inactiveMemoryLimit: requiredValue(memoryLimit(state: "inactive"), forKey: "jetsam memory limit (inactive)")
        )
        value.threadLimit = integer(forKey: "jetsam thread limit")
        value.softPortLimit = integer(forKey: "jetsam soft port limit")
        value.hardPortLimit = integer(forKey: "jetsam hard port limit")
        value.softFileDescriptorLimit = integer(forKey: "jetsam soft file descriptor limit")
        value.hardFileDescriptorLimit = integer(forKey: "jetsam hard file descriptor limit")
        value.conclaveMemoryLimit = integer(forKey: "jetsam conclave memory limit")
        return value
    }

    private func memoryLimit(state: String) -> Launchctl.MemoryLimit? {
        let enforcements: [Launchctl.MemoryLimit.Enforcement?] = [nil, .soft, .hard]
        for enforcement in enforcements {
            let suffix = enforcement.map { ", \($0.rawValue)" } ?? ""
            guard let text = try? string(forKey: "jetsam memory limit (\(state)\(suffix))") else { continue }
            if text == "(unlimited)" {
                return .init(megabytes: nil, enforcement: enforcement)
            }
            if text.hasSuffix(" MB"), let megabytes = Int(text.dropLast(3)) {
                return .init(megabytes: megabytes, enforcement: enforcement)
            }
        }
        return nil
    }

    private func socketInfo() -> [String: Launchctl.SocketInfo]? {
        guard let body = try? container(forKey: "sockets"),
              let entries = try? OutputParser(string: body).containers() else { return nil }
        return entries.mapValues { body in
            let parser = OutputParser(string: body)
            var value = Launchctl.SocketInfo()
            value.type = (try? parser.string(forKey: "type")).map(Launchctl.SocketType.init(rawValue:))
            value.path = try? parser.string(forKey: "path")
            value.mode = (try? parser.string(forKey: "mode")).flatMap { UInt32($0, radix: 8) }
            value.ownerUID = (try? parser.string(forKey: "owner uid")).flatMap(UInt32.init)
            value.groupID = (try? parser.string(forKey: "group id")).flatMap(UInt32.init)
            value.secureKey = try? parser.string(forKey: "secure key")
            value.nodeName = try? parser.string(forKey: "node name")
            value.serviceName = try? parser.string(forKey: "service name")
            value.family = (try? parser.string(forKey: "family")).map(Launchctl.SocketFamily.init(rawValue:))
            value.protocolName = (try? parser.string(forKey: "protocol")).map(Launchctl.SocketProtocol.init(rawValue:))
            value.descriptors = try? parser.stringArray(forKey: "sockets")
            value.active = parser.boolean(forKey: "active")
            value.passive = parser.boolean(forKey: "passive")
            value.bonjour = parser.boolean(forKey: "bonjour")
            value.ipv4v6 = parser.boolean(forKey: "ipv4v6")
            value.receivePacketInfo = parser.boolean(forKey: "receive_packet_info")
            value.needsRename = parser.boolean(forKey: "needs_rename")
            value.isSystemLogger = body.trimmingCharacters(in: .whitespacesAndNewlines) == "(system logger socket)"
            return value
        }
    }

    private func eventTriggers() throws -> [Launchctl.EventTriggerInfo]? {
        guard let body = try? container(forKey: "event triggers"),
              let entries = try? OutputParser(string: body).containerEntries(separator: " => ") else { return nil }
        return try entries.map { entry in
            let parser = OutputParser(string: entry.body)
            var value = try Launchctl.EventTriggerInfo(
                name: entry.key,
                stream: parser.requiredString(forKey: "stream"),
                service: parser.requiredString(forKey: "service"),
                keepAlive: requiredValue(parser.boolean(forKey: "keepalive"), forKey: "keepalive"),
                descriptor: requiredValue(try? parser.container(forKey: "descriptor"), forKey: "descriptor")
            )
            value.monitor = try? parser.string(forKey: "monitor")
            return value
        }
    }
}
