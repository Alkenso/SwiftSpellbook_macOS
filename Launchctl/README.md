# sLaunchctl - Swift API to manage daemons and user-agents

Developing for macOS often assumes interaction with root daemons and user agents. <br>
Unfortunately, Apple does not provide any actual API. (Existing SMJobXxx is deprecated)

sLaunchctl fills this gap providing convenient API that wraps up launchctl tool.

Read the article dedicated to the package: [sLaunchctl — Swift API to manage Daemons and Agents](https://medium.com/@alkenso/slaunchctl-swift-api-to-manage-daemons-and-agents-eea357f04782)

### Library family
You can also find Swift libraries for macOS / *OS development
- [SwiftSpellbook](https://github.com/Alkenso/SwiftSpellbook): Swift common extensions and utilities used in everyday development
- [sXPC](https://github.com/Alkenso/sXPC): Swift type-safe wrapper around NSXPCConnection and proxy object
- [sMock](https://github.com/Alkenso/sMock): Swift unit-test mocking framework similar to gtest/gmock
- [sEndpontSecurity](https://github.com/Alkenso/sEndpointSecurity): Swift wrapper around EndpointSecurity.framework

## Examples

#### Bootstrap
```
try Launchctl.system.bootstrap(URL(fileURLWithPath: "/path/to/com.my.daemon.plist"))
try Launchctl.gui().bootstrap(URL(fileURLWithPath: "/path/to/com.my.user_agent.plist"))
```

#### Bootout daemon
```
try Launchctl.system.bootout(URL(fileURLWithPath: "/path/to/com.my.daemon.plist"))
try Launchctl.gui().bootout(URL(fileURLWithPath: "/path/to/com.my.user_agent.plist"))
```

#### List all daemons
```
let rootDaemons = try Launchctl.system.list()
let user505Agents = try Launchctl.gui(505).list()
```

#### Inspect a service

```swift
let service = Launchctl.Service(name: "com.apple.akd", domainTarget: .system)
let info = try service.info()
print(info.type.rawValue, info.state.rawValue, info.execution.program, info.runtime.runs)
print(info.bundle?.identifier, info.management?.manager)
print(info.communication?.dynamicEndpoints, info.communication?.eventChannels)
print(info.resources.jetsam.activeMemoryLimit, info.communication?.sockets)
```

`ServiceInfo` keeps identity and status at the top level and groups the other fields:

| Group | Contents and recognition |
| --- | --- |
| `daemon` | Definition reported as `LaunchDaemon`. |
| `agent` | Plist definition reported as `LaunchAgent`. |
| `loginItem` | Program identifier/mode and parent bundle identifier/version; requires both identifiers, version and mode. |
| `bundle` | Bundle identifier/version, across daemons, agents, XPC services and submitted jobs. |
| `management` | Explicit manager, Background Task Management UUID and DriverKit check-in metadata. |
| `execution` | Executable/arguments, account, working directory, I/O paths, spawn policy and timing. |
| `runtime` | Launch/fork/exec counts, initialization/suspension flags, job state and exit details. |
| `instances` | Original service, instance names, copy count and multiple-instance support. |
| `communication` | Separate endpoint namespaces, event channels/triggers, sockets and semaphores. |
| `resources` | Jetsam limits, resource limits and coalition memberships. |

Bundle, management and login-item metadata are independent, overlapping groups.
A BTM UUID alone does not identify a login item: the captured output includes a
BTM-registered LaunchAgent without login-item identifiers. Account and execution
settings also remain shared: DriverKit submitted jobs use `username`, and working
directories, I/O settings and runtime counters occur across service types.

**Classification change:** `daemon` now means a `LaunchDaemon`, instead of every
record containing `path` and `program`. Use `execution.program` and
`execution.arguments` for executable information across all service types.
`LaunchAngel`, `XPCService`, `Submitted` and future types retain their raw `type`
and shared details without being labeled as daemons or agents. The static
`endpoints` name list remains available. `DaemonInfo` retains its required
`plistPath` and `program`; use `execution.arguments` and `bundle?.identifier`
instead of its removed optional `arguments` and `bundleID` fields.

Required fields were checked against 1,839 service dumps from two machines. For
optional nested objects, the requirement applies whenever that object exists.

| Model | Required fields | Capture evidence |
| --- | --- | --- |
| `ServiceInfo` | `serviceTarget`, `type`, `path`, `domain`, `state`, `properties`, `execution`, `environment`, `runtime`, `resources` | All 1,839 services |
| `Environment` | `generic`, `default` | Both sections in all 1,839 services; empty dictionaries are valid |
| `ExecutionInfo` | `spawnType`, `minimumRuntime`, `exitTimeout` | All 1,839 services |
| `RuntimeInfo` | `activeCount`, `runs` | All 1,839 services, including services with no running process |
| `ResourceInfo` | `jetsam` | All 1,839 services |
| `JetsamInfo` | `priority`, `category`, `activeMemoryLimit`, `inactiveMemoryLimit` | All 1,839 services |
| `EndpointInfo` | `port`, `active`, `managed`, `reset`, `hide`, `watching` | All 6,438 endpoints across five namespaces |
| `CoalitionInfo` | `id`, `name`, `type`, `state`, `activeCount` | All 2,430 resource/jetsam coalitions |
| `EventTriggerInfo` | `name`, `stream`, `service`, `keepAlive`, `descriptor` | All 4,224 triggers; `monitor` is absent in 24 |
| `BundleInfo` | `identifier` | All 131 bundle records; `version` appears in 47 |
| `LoginItemInfo` | `identifier`, `parentIdentifier`, `parentVersion`, `mode` | All 4 login-item records |
| `DaemonInfo`, `AgentInfo` | Existing required definition fields | Daemon path/program and agent path |
| `SpecialPortInfo` | `number` | Slot identity; its descriptive annotation remains optional |
| `SocketInfo` | `isSystemLogger` | Other fields remain optional because 2 of 44 entries contain only the logger marker |

No field in `ManagementInfo` or `InstanceInfo` is universal within its group.
`CommunicationInfo` remains optional because 50 services have none of its sections.
PID, executable, arguments, inherited environment, exit results, process diagnostics,
coalition bundle IDs, and additional resource limits remain conditional.
`MemoryLimit.megabytes` remains optional to represent an explicitly unlimited limit;
`enforcement` remains optional when launchctl supplies no soft/hard annotation.

Required values must be provided to the public initializers. Missing or malformed
required dump fields cause parsing to throw; they are never replaced with zero,
false, empty strings, or unlimited limits. Codable also requires these fields, so
older incomplete serialized snapshots no longer decode. This is a source and
serialized-data compatibility change. The capture counts establish the supported
format, not a guarantee about every macOS release.

Classifications use string-backed `RawRepresentable` types with named constants:
`ServiceType`, `ServiceState`, `SpawnType`, `SpawnRole`, `JobState`, `LaunchReason`,
`CoalitionType`, `CoalitionState`, `JetsamCategory`, `SocketType`, `SocketFamily`,
and `SocketProtocol`. They also conform to `Hashable`, `Codable`, and `Sendable`.
For example:

```swift
if info.type == .launchDaemon && info.state == .running {
    print(info.execution.spawnType.rawValue)
}
let futureType = Launchctl.ServiceType(rawValue: "FutureService")
```

Unknown values retain their exact text, including numeric annotations and leading
spaces such as the unnamed spawn type ` (7)`. Codable continues to encode and
decode plain strings, preserving the serialized representation of these fields.
Callers now use named constants or `init(rawValue:)` instead of assigning strings;
use `.rawValue` when the original output text is needed. Paths, identifiers,
free-form diagnostics, and publisher descriptors remain strings.

Runtime and interval values use seconds; file modes and umasks are parsed as
octal integers.

Event triggers are an ordered list because names can repeat across different event
streams. Their descriptors are publisher-specific and are retained as raw container
text. Low-level allocator diagnostics and code-signing constraint dictionaries are
not modeled. `Service.print()` remains available for the complete output.

Run the parser tests with `swift test --filter SpellbookLaunchctlTests`. When a local
`launchd/` capture folder is present at the package root, the tests additionally parse
every service snapshot and both domain listings. To verify another machine's capture
as well, pass its folder through the environment:

```sh
LAUNCHCTL_CAPTURE_DIRECTORY=/path/to/launchd-work swift test --filter SpellbookLaunchctlTests
```

Capture checks verify service classification, complete target names, argument arrays
(including empty arguments), environment values (including empty values), nested
entry names/counts, special-port metadata presence and `Codable` round trips.
Host/task special ports expose their slot number and role annotation through
`EndpointInfo.hostSpecialPort` / `taskSpecialPort`; `nonLaunching` preserves the
separate endpoint flag. Domain listing preserves service labels containing spaces.
Live tests remain disabled by default.

#### Find many more functional inside sLaunchctl!
