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

import EndpointSecurity
import Foundation
import SpellbookFoundation

public struct ESMessage: Equatable, Codable, Sendable {
    public var version: UInt32
    public var time: timespec
    public var machTime: UInt64
    public var deadline: UInt64
    public var process: ESProcess
    public var seqNum: UInt64? /* field available only if message version >= 2 */
    public var action: Action
    public var event: ESEvent
    public var eventType: es_event_type_t
    public var thread: ESThread? /* field available only if message version >= 4 */
    public var globalSeqNum: UInt64? /* field available only if message version >= 4 */
    
    public enum Action: Equatable, Codable, Sendable {
        case auth
        case notify(ESAuthResult)
    }
    
    public init(version: UInt32, time: timespec, machTime: UInt64, deadline: UInt64, process: ESProcess, seqNum: UInt64?, action: ESMessage.Action, event: ESEvent, eventType: es_event_type_t, thread: ESThread?, globalSeqNum: UInt64?) {
        self.version = version
        self.time = time
        self.machTime = machTime
        self.deadline = deadline
        self.process = process
        self.seqNum = seqNum
        self.action = action
        self.event = event
        self.eventType = eventType
        self.thread = thread
        self.globalSeqNum = globalSeqNum
    }
}

public struct ESProcess: Equatable, Codable, Sendable {
    public var auditToken: audit_token_t
    public var ppid: pid_t
    public var originalPpid: pid_t
    public var groupID: pid_t
    public var sessionID: pid_t
    public var codesigningFlags: UInt32
    public var isPlatformBinary: Bool
    public var isESClient: Bool
    public var cdHash: Data
    public var signingID: String
    public var teamID: String
    public var executable: ESFile
    public var tty: ESFile? /* field available only if message version >= 2 */
    public var startTime: timeval? /* field available only if message version >= 3 */
    public var responsibleAuditToken: audit_token_t? /* field available only if message version >= 4 */
    public var parentAuditToken: audit_token_t? /* field available only if message version >= 4 */
    
    /// The code signature validation policy that was applied to the binary.
    public var csValidationCategory: es_cs_validation_category_t? /* field available only if message version >= 10 */
    
    /// Full Code Directory Hash.
    ///
    /// `cdHash` captures only the first 20 bytes of the real CDHash of the process.
    /// This field contains the full CDHash, the length and algorithm of which is subject to change.
    public var cdHashFull: Data? /* field available only if message version >= 11 */
    
    public init(auditToken: audit_token_t, ppid: pid_t, originalPpid: pid_t, groupID: pid_t, sessionID: pid_t, codesigningFlags: UInt32, isPlatformBinary: Bool, isESClient: Bool, cdHash: Data, signingID: String, teamID: String, executable: ESFile, tty: ESFile?, startTime: timeval?, responsibleAuditToken: audit_token_t?, parentAuditToken: audit_token_t?, csValidationCategory: es_cs_validation_category_t? = nil, cdHashFull: Data? = nil) {
        self.auditToken = auditToken
        self.ppid = ppid
        self.originalPpid = originalPpid
        self.groupID = groupID
        self.sessionID = sessionID
        self.codesigningFlags = codesigningFlags
        self.isPlatformBinary = isPlatformBinary
        self.isESClient = isESClient
        self.cdHash = cdHash
        self.signingID = signingID
        self.teamID = teamID
        self.executable = executable
        self.tty = tty
        self.startTime = startTime
        self.responsibleAuditToken = responsibleAuditToken
        self.parentAuditToken = parentAuditToken
        self.csValidationCategory = csValidationCategory
        self.cdHashFull = cdHashFull
    }
}

extension ESProcess {
    public var name: String { executable.path.lastPathComponent }
}

public struct ESFile: Equatable, Codable, Sendable {
    public var path: String
    public var truncated: Bool
    public var stat: stat
    
    public init(path: String, truncated: Bool, stat: stat) {
        self.path = path
        self.truncated = truncated
        self.stat = stat
    }
}

public struct ESThread: Equatable, Codable, Sendable {
    public var threadID: UInt64
    
    public init(threadID: UInt64) {
        self.threadID = threadID
    }
}

public struct ESThreadState: Equatable, Codable, Sendable {
    public var flavor: Int32
    public var state: Data
    
    public init(flavor: Int32, state: Data) {
        self.flavor = flavor
        self.state = state
    }
}

/// Information from a signed file. If the file is a multiarchitecture binary, only the
/// signing information for the native host architecture is reported. I.e. the CDHash
/// from the AArch64 slice if the host is AArch64.
public struct ESSignedFileInfo: Equatable, Codable, Sendable {
    /// Code Directory Hash
    public var cdHash: Data
    
    /// Team Identifier, if available in the signing information.
    public var teamID: String
    
    /// Signing Identifier, if available in the signing information.
    public var signingID: String
    
    public init(cdHash: Data, teamID: String, signingID: String) {
        self.cdHash = cdHash
        self.teamID = teamID
        self.signingID = signingID
    }
}

/// Identity facts carried by a Lightweight Code Requirement (LWCR).
///
/// A LWCR need not carry every fact. A `nil` field means the LWCR did not carry
/// that fact at all, which is distinct from an empty string (the fact was carried
/// but its value was empty).
public struct ESLightweightCodeRequirement: Equatable, Codable, Sendable {
    /// Team Identifier from the LWCR.
    public var teamID: String?
    
    /// Signing Identifier from the LWCR.
    public var signingID: String?
    
    public init(teamID: String?, signingID: String?) {
        self.teamID = teamID
        self.signingID = signingID
    }
}

public struct ESAuthResult: Equatable, Codable, Sendable, RawRepresentable {
    public static func auth(_ auth: Bool) -> ESAuthResult { .init(rawValue: auth ? .max : 0) }
    public static func flags(_ flags: UInt32) -> ESAuthResult { .init(rawValue: flags) }
    
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public struct BTMLaunchItem: Equatable, Codable, Sendable {
    public var itemType: es_btm_item_type_t
    public var legacy: Bool
    public var managed: Bool
    public var uid: uid_t
    public var itemURL: String
    public var appURL: String?
    
    public init(itemType: es_btm_item_type_t, legacy: Bool, managed: Bool, uid: uid_t, itemURL: String, appURL: String?) {
        self.itemType = itemType
        self.legacy = legacy
        self.managed = managed
        self.uid = uid
        self.itemURL = itemURL
        self.appURL = appURL
    }
}

public struct ESProfile: Equatable, Codable, Sendable {
    public var identifier: String
    public var uuid: String
    public var installSource: es_profile_source_t
    public var organization: String
    public var displayName: String
    public var scope: String
    
    public init(identifier: String, uuid: String, installSource: es_profile_source_t, organization: String, displayName: String, scope: String) {
        self.identifier = identifier
        self.uuid = uuid
        self.installSource = installSource
        self.organization = organization
        self.displayName = displayName
        self.scope = scope
    }
}

/// The identity of a group member.
public enum ESODMemberID: Equatable, Codable, Sendable {
    /// Group member is a user, designated by name.
    case userName(String)
    
    /// Group member is a user, designated by UUID
    case userUUID(UUID)
    
    /// Group member is another group, designated by UUID.
    case groupUUID(UUID)
}

public enum ESEvent: Equatable, Codable, Sendable {
    case access(Access)
    case authentication(Authentication)
    case authorizationJudgement(AuthorizationJudgement)
    case authorizationPetition(AuthorizationPetition)
    case bootstrapCheckIn(BootstrapCheckIn)
    case bootstrapLookUp(BootstrapLookUp)
    case btmLaunchItemAdd(BTMLaunchItemAdd)
    case btmLaunchItemRemove(BTMLaunchItemRemove)
    case chdir(Chdir)
    case chroot(Chroot)
    case clone(Clone)
    case close(Close)
    case copyfile(CopyFile)
    case create(Create)
    case csInvalidated
    case deleteextattr(DeleteExtAttr)
    case dup(Dup)
    case exchangedata(ExchangeData)
    case exec(Exec)
    case exit(Exit)
    case fcntl(Fcntl)
    case fileProviderMaterialize(FileProviderMaterialize)
    case fileProviderUpdate(FileProviderUpdate)
    case fork(Fork)
    case fsgetpath(FsGetPath)
    case getTask(GetTask)
    case getTaskInspect(GetTaskInspect)
    case getTaskName(GetTaskName)
    case getTaskRead(GetTaskRead)
    case getattrlist(GetAttrList)
    case getextattr(GetExtAttr)
    case iokitOpen(IOKitOpen)
    case kextload(KextLoad)
    case kextunload(KextUnload)
    case link(Link)
    case listextattr(ListExtAttr)
    case loginLogin(LoginLogin)
    case loginLogout(LoginLogout)
    case lookup(Lookup)
    case lwSessionLock(LWSessionLock)
    case lwSessionLogin(LWSessionLogin)
    case lwSessionLogout(LWSessionLogout)
    case lwSessionUnlock(LWSessionUnlock)
    case mmap(MMap)
    case mount(Mount)
    case mprotect(MProtect)
    case odAttributeSet(ODAttributeSet)
    case odAttributeValueAdd(ODAttributeValueAdd)
    case odAttributeValueRemove(ODAttributeValueRemove)
    case odCreateGroup(ODCreateGroup)
    case odCreateUser(ODCreateUser)
    case odDeleteGroup(ODDeleteGroup)
    case odDeleteUser(ODDeleteUser)
    case odDisableUser(ODDisableUser)
    case odEnableUser(ODEnableUser)
    case odGroupAdd(ODGroupAdd)
    case odGroupRemove(ODGroupRemove)
    case odGroupSet(ODGroupSet)
    case odModifyPassword(ODModifyPassword)
    case open(Open)
    case opensshLogin(OpensshLogin)
    case opensshLogout(OpensshLogout)
    case procCheck(ProcCheck)
    case procSuspendResume(ProcSuspendResume)
    case profileAdd(ProfileAdd)
    case profileRemove(ProfileRemove)
    case ptyClose(PtyClose)
    case ptyGrant(PtyGrant)
    case readdir(Readdir)
    case readlink(Readlink)
    case remoteThreadCreate(RemoteThreadCreate)
    case remount(Remount)
    case rename(Rename)
    case screensharingAttach(ScreensharingAttach)
    case screensharingDetach(ScreensharingDetach)
    case searchfs(SearchFS)
    case setacl(SetACL)
    case setattrlist(SetAttrList)
    case setextattr(SetExtAttr)
    case setflags(SetFlags)
    case setmode(SetMode)
    case setowner(SetOwner)
    case setreuid(SetREUID)
    case settime
    case setuid(SetUID)
    case signal(Signal)
    case stat(Stat)
    case su(SU)
    case sudo(SUDO)
    case tccModify(TCCModify)
    case trace(Trace)
    case truncate(Truncate)
    case uipcBind(UipcBind)
    case uipcConnect(UipcConnect)
    case unlink(Unlink)
    case unmount(Unmount)
    case utimes(Utimes)
    case write(Write)
    case xpMalwareDetected(XPMalwareDetected)
    case xpMalwareRemediated(XPMalwareRemediated)
    case xpcConnect(XPCConnect)
    case gatekeeperUserOverride(GatekeeperUserOverride)
}

extension ESEvent {

    /// Test file access
    ///
    /// - Note: This event type does not support caching (notify-only).
public struct Access: Equatable, Codable, Sendable {
        /// Access permission to check
        public var mode: Int32

        /// The file to check for access
        public var target: ESFile
        
        public init(mode: Int32, target: ESFile) {
            self.mode = mode
            self.target = target
        }
    }
    
    /// Notification that an authentication was performed.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Authentication: Equatable, Codable, Sendable {
        /// True iff authentication was successful.
        public var success: Bool

        /// The type of authentication.
        public var type: AuthenticationType
        
        public init(success: Bool, type: AuthenticationType) {
            self.success = success
            self.type = type
        }
    }
    
    /// Type-specific data describing the authentication.
    public enum AuthenticationType: Equatable, Codable, Sendable {
        case od(OD)
        case touchID(TouchID)
        case token(Token)
        case autoUnlock(AutoUnlock)
        
        /// OpenDirectory authentication data for type ES_AUTHENTICATION_TYPE_OD.
        public struct OD: Equatable, Codable, Sendable {
            /// Process that instigated the authentication (XPC caller that asked for authentication).
            public var instigator: ESProcess?

            /// Audit token of the process that instigated this event.
            public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */

            /// OD record type against which OD is authenticating. Typically "Users", but other record types can
            /// auth too.
            public var recordType: String

            /// OD record name against which OD is authenticating. For record type "Users", this is the username.
            public var recordName: String

            /// OD node against which OD is authenticating. Typically one of "/Local/Default", "/LDAPv3/<server>" or
            /// "/Active Directory/<domain>".
            public var nodeName: String

            /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
            /// authenticating.
            public var dbPath: String?
            
            public init(instigator: ESProcess?, instigatorToken: audit_token_t?, recordType: String, recordName: String, nodeName: String, dbPath: String?) {
                self.instigator = instigator
                self.instigatorToken = instigatorToken
                self.recordType = recordType
                self.recordName = recordName
                self.nodeName = nodeName
                self.dbPath = dbPath
            }
        }
        
        /// TouchID authentication data for type ES_AUTHENTICATION_TYPE_TOUCHID.
        public struct TouchID: Equatable, Codable, Sendable {
            /// Process that instigated the authentication (XPC caller that asked for authentication).
            public var instigator: ESProcess?

            /// Audit token of the process that instigated this event.
            public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
            /// TouchID authentication type
            public var touchIDMode: es_touchid_mode_t

            /// Union that is valid when `has_uid` is set to `true`
            public var uid: uid_t?
            
            public init(instigator: ESProcess?, instigatorToken: audit_token_t?, touchIDMode: es_touchid_mode_t, uid: uid_t?) {
                self.instigator = instigator
                self.instigatorToken = instigatorToken
                self.touchIDMode = touchIDMode
                self.uid = uid
            }
        }
        
        /// Token authentication data for type ES_AUTHENTICATION_TYPE_TOKEN.
        public struct Token: Equatable, Codable, Sendable {
            /// Process that instigated the authentication (XPC caller that asked for authentication).
            public var instigator: ESProcess?

            /// Audit token of the process that instigated this event.
            public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */

            /// Hash of the public key which CryptoTokenKit is authenticating.
            public var pubkeyHash: String

            /// Token identifier of the event which CryptoTokenKit is authenticating.
            public var tokenID: String

            /// Optional. This will be available if token is used for GSS PKINIT authentication for obtaining a
            /// kerberos TGT. NULL in all other cases.
            public var kerberosPrincipal: String?
            
            public init(instigator: ESProcess?, instigatorToken: audit_token_t?, pubkeyHash: String, tokenID: String, kerberosPrincipal: String?) {
                self.instigator = instigator
                self.instigatorToken = instigatorToken
                self.pubkeyHash = pubkeyHash
                self.tokenID = tokenID
                self.kerberosPrincipal = kerberosPrincipal
            }
        }
        
        /// Auto Unlock authentication data for type ES_AUTHENTICATION_TYPE_AUTO_UNLOCK.
        ///
        /// - Note: This kind of authentication is performed when authenticating to the local Mac using an Apple Watch for
        /// the purpose of unlocking the machine or confirming an authorization prompt. Auto Unlock is part of
        /// Continuity.
        ///
        /// - Note: This event type does not support caching (notify-only).
        public struct AutoUnlock: Equatable, Codable, Sendable {
            /// Username for which the authentication was attempted.
            public var username: String

            /// Purpose of the authentication.
            public var type: es_auto_unlock_type_t
            
            public init(username: String, type: es_auto_unlock_type_t) {
                self.username = username
                self.type = type
            }
        }
    }
    
    /// A process called `bootstrap_check_in()` to register a named service port with launchd. Subsequent
    /// `bootstrap_look_up()` calls from other processes will resolve the registered name into a send right to this
    /// port.
    ///
    /// Submitted by launchd on behalf of the instigator.
    ///
    /// Because launchd is the submitter, the enclosing message's `es_message_t.process` describes launchd, not the
    /// process that called `bootstrap_check_in()`. The actual caller is reported as `instigator` /
    /// `instigator_token` below.
    ///
    /// - Note: This event type does not support caching.
    public struct BootstrapCheckIn: Equatable, Codable, Sendable {
        /// (Optional) The process that called `bootstrap_check_in()`. Best-effort; may be null if the instigator
        /// exited before the event was constructed.
        public var instigator: ESProcess?
        
        /// Audit token of the instigator, captured by launchd at RPC time. Always present.
        public var instigatorToken: audit_token_t
        
        /// The name registered by the instigator.
        public var serviceName: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, serviceName: String) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.serviceName = serviceName
        }
    }
    
    /// A process called `bootstrap_look_up()` to resolve a named service port registered with launchd. launchd
    /// returns a send right to that port; subsequent `mach_msg()` calls to it are delivered to the owner of the
    /// corresponding receive right.
    ///
    /// Submitted by launchd on behalf of the instigator.
    ///
    /// Because launchd is the submitter, the enclosing message's `es_message_t.process` describes launchd, not the
    /// process that called `bootstrap_look_up()`. The actual caller is reported as `instigator` /
    /// `instigator_token` below.
    ///
    /// - Note: This event type does not support caching.
    public struct BootstrapLookUp: Equatable, Codable, Sendable {
        /// (Optional) The process that called `bootstrap_look_up()`. Best-effort; may be null if the instigator
        /// exited before the event was constructed.
        public var instigator: ESProcess?
        
        /// Audit token of the instigator, captured by launchd at RPC time. Always present.
        public var instigatorToken: audit_token_t
        
        /// The name the instigator asked launchd to resolve.
        public var serviceName: String
        
        /// Identity of the entity that would receive messages sent to the returned port if the lookup is allowed.
        ///
        /// On the PROCESS arm, `target` (es_process_t) carries the live owner's full process info including code-
        /// signing identity (target->signing_id, target->team_id) sourced from the kernel. No identity from
        /// launchd's cached Lightweight Code Requirement (LWCR) is reported on this arm — read it from the
        /// es_process_t.
        ///
        /// On the JOB arm there is no live process, so the only available identity is the LWCR launchd had
        /// configured (if any). `lwcr` is a nullable pointer: NULL when no LWCR was cached for this service.
        public var target: Target
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, serviceName: String, target: Target) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.serviceName = serviceName
            self.target = target
        }
        
        /// Selects between a running owner (`process`) and a lazy-launched owner (`job`).
        public enum Target: Equatable, Codable, Sendable {
            /// The live owner of the service.
            ///
            /// `target` carries the full process info including the code-signing identity
            /// (`signingID`, `teamID`) sourced from the kernel. No identity from launchd's
            /// cached Lightweight Code Requirement is reported here: read it from the process.
            case process(target: ESProcess?, targetToken: audit_token_t, jobLabel: String)
            
            /// A lazy-launched owner. There is no live process, so the only available identity
            /// is the Lightweight Code Requirement launchd had configured, if any.
            case job(jobLabel: String, lwcr: ESLightweightCodeRequirement?)
        }
    }
    
    /// Notification for launch item being made known to background task management. This includes launch agents and
    /// daemons as well as login items added by the user, via MDM or by an app.
    ///
    /// - Note: May be emitted for items where an add was already seen previously, with or without the item having changed.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct BTMLaunchItemAdd: Equatable, Codable, Sendable {
        /// Optional. Process that instigated the BTM operation (XPC caller that asked for the item to be added).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// Optional. App process that registered the item.
        public var app: ESProcess?
        
        /// Audit token of the app process that registered the item.
        public var appToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// BTM launch item.
        public var item: BTMLaunchItem

        /// Optional. If available and applicable, the POSIX executable path from the launchd plist. If the path is
        /// relative, it is relative to item->app_url.
        public var executablePath: String?
        
        public init(instigator: ESProcess?, app: ESProcess?, item: BTMLaunchItem, executablePath: String?, instigatorToken: audit_token_t? = nil, appToken: audit_token_t? = nil) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.app = app
            self.appToken = appToken
            self.item = item
            self.executablePath = executablePath
        }
    }
    
    /// Notification for launch item being removed from background task management. This includes launch agents and
    /// daemons as well as login items added by the user, via MDM or by an app.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct BTMLaunchItemRemove: Equatable, Codable, Sendable {
        /// Optional. Process that instigated the BTM operation (XPC caller that asked for the item to be removed).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// Optional. App process that registered the item.
        public var app: ESProcess?
        
        /// Audit token of the app process that removed the item.
        public var appToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// BTM launch item.
        public var item: BTMLaunchItem
        
        public init(instigator: ESProcess?, app: ESProcess?, item: BTMLaunchItem, instigatorToken: audit_token_t? = nil, appToken: audit_token_t? = nil) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.app = app
            self.appToken = appToken
            self.item = item
        }
    }
    
    /// Change directories
    ///
    /// - Note: Cache key for this event type: (process executable file, target directory)
    public struct Chdir: Equatable, Codable, Sendable {
        /// The desired new current working directory
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Change the root directory for a process
    ///
    /// - Note: Cache key for this event type: (process executable file, target directory)
    public struct Chroot: Equatable, Codable, Sendable {
        /// The directory which will be the new root
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Clone a file
    ///
    /// - Note: This event type does not support caching.
    public struct Clone: Equatable, Codable, Sendable {
        /// The file that will be cloned
        public var source: ESFile

        /// The directory into which the `source` file will be cloned
        public var targetDir: ESFile

        /// The name of the new file to which `source` will be cloned
        public var targetName: String
        
        public init(source: ESFile, targetDir: ESFile, targetName: String) {
            self.source = source
            self.targetDir = targetDir
            self.targetName = targetName
        }
    }
    
    /// Copy a file using the copyfile syscall
    ///
    /// - Note: Not to be confused with copyfile(3).
    ///
    /// - Note: Prior to macOS 12.0, the copyfile syscall fired open, unlink and auth create events, but no notify create,
    /// nor write or close events.
    ///
    /// - Note: This event type does not support caching.
    public struct CopyFile: Equatable, Codable, Sendable {
        /// The file that will be cloned
        public var source: ESFile

        /// The file existing at the target path that will be overwritten by the copyfile operation. NULL if no such
        /// file exists.
        public var targetFile: ESFile?

        /// The directory into which the `source` file will be copied
        public var targetDir: ESFile

        /// The name of the new file to which `source` will be copied
        public var targetName: String

        /// Corresponds to mode argument of the copyfile syscall
        public var mode: mode_t

        /// Corresponds to flags argument of the copyfile syscall
        public var flags: Int32
        
        public init(source: ESFile, targetFile: ESFile?, targetDir: ESFile, targetName: String, mode: mode_t, flags: Int32) {
            self.source = source
            self.targetFile = targetFile
            self.targetDir = targetDir
            self.targetName = targetName
            self.mode = mode
            self.flags = flags
        }
    }
    
    /// Close a file descriptor
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// `was_mapped_writable` only indicates whether the target file was mapped into writable memory or not for the
    /// lifetime of the vnode. It does not indicate whether the file has actually been written to by way of writing
    /// to mapped memory, and it does not indicate whether the file is currently still mapped writable. Correct
    /// interpretation requires consideration of vnode lifetimes in the kernel.
    ///
    /// The `modified` flag only reflects that a file was or was not modified by filesystem syscall. If a file was
    /// only modifed though a memory mapping this flag will be false, but was_mapped_writable will be true.
    public struct Close: Equatable, Codable, Sendable {
        /// Set to TRUE if the target file being closed has been modified
        public var modified: Bool

        /// The file that is being closed
        public var target: ESFile
        
        /// Indicates that at some point in the lifetime of the target file vnode it was mapped into a process as
        /// writable.
        /// - Note: It does not indicate whether the file has actually been written to
        /// by way of writing to mapped memory, nor whether the file is currently still mapped writable.
        public var wasMappedWritable: Bool? /* field available only if message version >= 6 */
        
        public init(modified: Bool, target: ESFile, wasMappedWritable: Bool? = nil) {
            self.modified = modified
            self.target = target
            self.wasMappedWritable = wasMappedWritable
        }
    }
    
    /// Create a file system object
    ///
    /// - Note: If an object is being created but has not yet been created, the `destination_type` will be
    /// `ES_DESTINATION_TYPE_NEW_PATH`.
    ///
    /// - Note: Typically `ES_EVENT_TYPE_NOTIFY_CREATE` events are fired after the object has been created and the
    /// `destination_type` will be `ES_DESTINATION_TYPE_EXISTING_FILE`. The exception to this is for notifications
    /// that occur if an ES client responds to an `ES_EVENT_TYPE_AUTH_CREATE` event with `ES_AUTH_RESULT_DENY`.
    ///
    /// - Note: This event can fire multiple times for a single syscall, for example when the syscall has to be retried due
    /// to racing VFS operations.
    ///
    /// - Note: This event type does not support caching.
    public struct Create: Equatable, Codable, Sendable {
        /// Information about the destination of the new file (see note)
        public var destination: Destination
        
        /// The ACL that the new file system object got or gets created with. May be NULL if the file system object
        /// gets created without ACL.
        ///
        /// - Note: The acl provided cannot be directly used by functions within
        /// the <sys/acl.h> header. These functions can mutate the struct passed
        /// into them, which is not compatible with the immutable nature of
        /// es_message_t. Additionally, because this field is minimally constructed,
        /// you must not use `acl_dup(3)` to get a mutable copy, as this can lead to
        /// out of bounds memory access. To obtain a acl_t struct that is able to be
        /// used with all functions within <sys/acl.h>, please use a combination of
        /// `acl_copy_ext(3)` followed by `acl_copy_int(3)`.
        /// - Note: field available only if message version >= 2
        /// - Note: `acl` is present only in original message.
        /// If structure is re-encoded, this field will be lost.
        public nonisolated(unsafe) var acl: Resource<acl_t>?
        
        /// Whether or not the destination refers to an existing file.
        public enum Destination: Equatable, Codable, Sendable {
            case existingFile(ESFile)
            case newPath(dir: ESFile, filename: String, mode: mode_t)
        }
        
        public init(destination: ESEvent.Create.Destination, acl: acl_t?) {
            self.destination = destination
            if let acl = acl, let dup = acl_dup(acl) {
                self.acl = .raii(dup) { acl_free(.init($0)) }
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case destination
        }
    }
    
    /// Delete an extended attribute
    ///
    /// - Note: This event type does not support caching.
    public struct DeleteExtAttr: Equatable, Codable, Sendable {
        /// The file for which the extended attribute will be deleted
        public var target: ESFile

        /// The extended attribute which will be deleted
        public var extattr: String
        
        public init(target: ESFile, extattr: String) {
            self.target = target
            self.extattr = extattr
        }
    }
    
    /// Duplicate a file descriptor
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Dup: Equatable, Codable, Sendable {
        /// Describes the file the duplicated file descriptor points to
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Exchange data atomically between two files
    ///
    /// - Note: This event type does not support caching.
    public struct ExchangeData: Equatable, Codable, Sendable {
        /// The first file to be exchanged
        public var file1: ESFile

        /// The second file to be exchanged
        public var file2: ESFile
        
        public init(file1: ESFile, file2: ESFile) {
            self.file1 = file1
            self.file2 = file2
        }
    }
    
    /// Execute a new process
    ///
    /// - Note: Process arguments, environment variables and file descriptors are packed, use API functions to access them:
    /// `es_exec_arg`, `es_exec_arg_count`, `es_exec_env`, `es_exec_env_count`, `es_exec_fd` and `es_exec_fd_count`.
    ///
    /// - Note: The API may only return descriptions for a subset of open file descriptors; how many and which file
    /// descriptors are available as part of exec events is not considered API and can change in future releases.
    ///
    /// - Note: The CPU type and subtype correspond to CPU_TYPE_* and CPU_SUBTYPE_* macros defined in `<mach/machine.h>`.
    ///
    /// - Note: Fields related to code signing in `target` represent kernel state for the process at the point in time the
    /// exec has completed, but the binary has not started running yet. Because code pages are not validated until
    /// they are paged in, this means that modifications to code pages would not have been detected yet at this
    /// point. For a more thorough explanation, please see the documentation for `es_process_t`.
    ///
    /// - Note: There are two `es_process_t` fields that are represented in an `es_message_t` that contains an
    /// `es_event_exec_t`. The `es_process_t` within the `es_message_t` struct (named "process") contains
    /// information about the program that calls execve(2) (or posix_spawn(2)). This information is gathered prior
    /// to the program being replaced. The other `es_process_t`, within the `es_event_exec_t` struct (named
    /// "target"), contains information about the program after the image has been replaced by execve(2) (or
    /// posix_spawn(2)). This means that both `es_process_t` structs refer to the same process (as identified by
    /// pid), but not necessarily the same program, and definitely not the same program execution (as identified by
    /// pid, pidversion tuple). The `audit_token_t` structs contained in the two different `es_process_t` structs
    /// will not be identical: the pidversion field will be updated, and the uid/gid values may be different if the
    /// new program had setuid/setgid permission bits set.
    ///
    /// - Note: Cache key for this event type: (process executable file, target executable file)
    ///
    /// - Note: Caching is not supported when `script` is nonnull
    public struct Exec: Equatable, Codable, Sendable {
        /// The new process that is being executed
        public var target: ESProcess

        /// Script being executed by interpreter. This field is only valid if a script was executed directly and not
        /// as an argument to the interpreter (e.g. `./foo.sh` not `/bin/sh ./foo.sh`)
        public var script: ESFile? /* field available only if message version >= 2 */

        /// Current working directory at exec time.
        public var cwd: ESFile? /* field available only if message version >= 3 */

        /// Highest open file descriptor after the exec completed. This number is equal to or larger than the
        /// highest number of file descriptors available via `es_exec_fd_count` and `es_exec_fd`, in which case
        /// EndpointSecurity has capped the number of file descriptors available in the message. File descriptors
        /// for open files are not necessarily contiguous. The exact number of open file descriptors is not
        /// available.
        public var lastFD: Int32? /* field available only if message version >= 4 */

        /// The CPU type of the executable image which is being executed. In case of translation, this may be a
        /// different architecture than the one of the system.
        public var imageCPUType: cpu_type_t? /* field available only if message version >= 6 */

        /// The CPU subtype of the executable image.
        public var imageCPUSubtype: cpu_subtype_t? /* field available only if message version >= 6 */
        
        /// The exec path passed up to dyld, before symlink resolution. This is the path argument to execve(2) or
        /// posix_spawn(2), or the interpreter from the shebang line for scripts run through the shell script image
        /// activator.
        public var dyldExecPath: String? /* field available only if message version >= 7 */
        
        /// Process arguments. Packed in the native message and unpacked via `es_exec_arg`.
        /// - Note: Present only if `ESConverter.Config.execArgs` is `true`.
        public var args: [String]?
        
        /// Environment variables. Packed in the native message and unpacked via `es_exec_env`.
        /// - Note: Present only if `ESConverter.Config.execEnv` is `true`.
        public var env: [String]?
        
        public init(target: ESProcess, script: ESFile?, cwd: ESFile?, lastFD: Int32?, imageCPUType: cpu_type_t? = nil, imageCPUSubtype: cpu_subtype_t? = nil, dyldExecPath: String? = nil) {
            self.target = target
            self.script = script
            self.cwd = cwd
            self.lastFD = lastFD
            self.imageCPUType = imageCPUType
            self.imageCPUSubtype = imageCPUSubtype
            self.dyldExecPath = dyldExecPath
        }
    }
    
    /// Terminate a process
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Exit: Equatable, Codable, Sendable {
        /// The exit status of a process (same format as wait(2))
        public var status: Int32
        
        public init(status: Int32) {
            self.status = status
        }
    }
    
    /// Materialize a file via the FileProvider framework
    ///
    /// - Note: This event type does not support caching.
    public struct FileProviderMaterialize: Equatable, Codable, Sendable {
        /// The process that instigated the materialize operation.
        public var instigator: ESProcess?

        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */

        /// The staged file that has been materialized
        public var source: ESFile

        /// The destination of the staged `source` file
        public var target: ESFile
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, source: ESFile, target: ESFile) {
            self.instigator = instigator
            self.source = source
            self.target = target
            self.instigatorToken = instigatorToken
        }
    }
    
    /// Update file contents via the FileProvider framework
    ///
    /// - Note: This event type does not support caching.
    public struct FileProviderUpdate: Equatable, Codable, Sendable {
        /// The staged file that has had its contents updated
        public var source: ESFile

        /// The destination that the staged `source` file will be moved to
        public var targetPath: String
        
        public init(source: ESFile, targetPath: String) {
            self.source = source
            self.targetPath = targetPath
        }
    }
    
    /// File control
    ///
    /// - Note: This event type does not support caching.
    public struct Fcntl: Equatable, Codable, Sendable {
        /// The target file on which the file control command will be performed
        public var target: ESFile

        /// The `cmd` argument given to fcntl(2)
        public var cmd: Int32
        
        public init(target: ESFile, cmd: Int32) {
            self.target = target
            self.cmd = cmd
        }
    }
    
    /// Fork a new process
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Fork: Equatable, Codable, Sendable {
        /// The child process that was created
        public var child: ESProcess
        
        public init(child: ESProcess) {
            self.child = child
        }
    }
    
    /// Retrieve file system path based on FSID
    ///
    /// - Note: This event can fire multiple times for a single syscall, for example when the syscall has to be retried due
    /// to racing VFS operations.
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct FsGetPath: Equatable, Codable, Sendable {
        /// Describes the file system path that will be retrieved
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Get a process's task control port
    ///
    /// - Note: Task control ports were formerly known as simply "task ports".
    ///
    /// - Note: There are many legitimate reasons why a process might need to obtain a send right to a task control port of
    /// another process, not limited to intending to debug or suspend the target process. For instance, frameworks
    /// and their daemons may need to obtain a task control port to fulfill requests made by the target process.
    /// Obtaining a task control port is in itself not indicative of malicious activity. Denying system processes
    /// acquiring task control ports may result in breaking system functionality in potentially fatal ways.
    ///
    /// - Note: Cache key for this event type: (process executable file, target executable file)
    public struct GetTask: Equatable, Codable, Sendable {
        /// The process for which the task control port will be retrieved.
        public var target: ESProcess
        
        /// Type indicating how the process is obtaining the task port for the target process.
        ///
        /// This event is fired when a process obtains a send right to a task control port (e.g. task_for_pid(),
        /// task_identity_token_get_task_port(), processor_set_tasks() and other means).
        public var type: es_get_task_type_t? /* field available only if message version >= 5 */
        
        public init(target: ESProcess, type: es_get_task_type_t? = nil) {
            self.target = target
            self.type = type
        }
    }
    
    /// Get a process's task read port
    ///
    /// - Note: Cache key for this event type: (process executable file, target executable file)
    public struct GetTaskRead: Equatable, Codable, Sendable {
        /// The process for which the task read port will be retrieved.
        public var target: ESProcess
        
        /// Type indicating how the process is obtaining the task port for the target process.
        ///
        /// This event is fired when a process obtains a send right to a task read port (e.g. task_read_for_pid(),
        /// task_identity_token_get_task_port()).
        public var type: es_get_task_type_t? /* field available only if message version >= 5 */
        
        public init(target: ESProcess, type: es_get_task_type_t? = nil) {
            self.target = target
            self.type = type
        }
    }
    
    /// Get a process's task inspect port
    ///
    /// - Note: This event type does not support caching.
    public struct GetTaskInspect: Equatable, Codable, Sendable {
        /// The process for which the task inspect port will be retrieved.
        public var target: ESProcess
        
        /// Type indicating how the process is obtaining the task port for the target process.
        ///
        /// This event is fired when a process obtains a send right to a task inspect port (e.g.
        /// task_inspect_for_pid(), task_identity_token_get_task_port()).
        public var type: es_get_task_type_t? /* field available only if message version >= 5 */
        
        public init(target: ESProcess, type: es_get_task_type_t? = nil) {
            self.target = target
            self.type = type
        }
    }
    
    /// Get a process's task name port
    ///
    /// - Note: This event type does not support caching.
    public struct GetTaskName: Equatable, Codable, Sendable {
        /// The process for which the task name port will be retrieved.
        public var target: ESProcess
        
        /// Type indicating how the process is obtaining the task port for the target process.
        ///
        /// This event is fired when a process obtains a send right to a task name port (e.g. task_name_for_pid(),
        /// task_identity_token_get_task_port()).
        public var type: es_get_task_type_t? /* field available only if message version >= 5 */
        
        public init(target: ESProcess, type: es_get_task_type_t? = nil) {
            self.target = target
            self.type = type
        }
    }
    
    /// Retrieve file system attributes
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct GetAttrList: Equatable, Codable, Sendable {
        /// The attributes that will be retrieved
        public var attrlist: attrlist

        /// The file for which attributes will be retrieved
        public var target: ESFile
        
        public init(attrlist: attrlist, target: ESFile) {
            self.attrlist = attrlist
            self.target = target
        }
    }
    
    /// Retrieve an extended attribute
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct GetExtAttr: Equatable, Codable, Sendable {
        /// The file for which the extended attribute will be retrieved
        public var target: ESFile

        /// The extended attribute which will be retrieved
        public var extattr: String
        
        public init(target: ESFile, extattr: String) {
            self.target = target
            self.extattr = extattr
        }
    }
    
    /// Open a connection to an I/O Kit IOService
    ///
    /// - Note: This event type does not support caching.
    public struct IOKitOpen: Equatable, Codable, Sendable {
        /// A constant specifying the type of connection to be created, interpreted only by the IOService's family.
        /// This field corresponds to the type argument to IOServiceOpen().
        public var userClientType: UInt32

        /// Meta class name of the user client instance.
        public var userClientClass: String
        
        /// The IOKit registry ID of the parent of the user class. Conceptually this is what the user class is
        /// connecting to. It can be resolved to a an `io_service_t` with by calling `IORegistryEntryIDMatching`
        /// then `IOServiceGetMatchingService`
        public var parentRegistryID: UInt64? /* field available only if message version >= 10 */
        
        /// The path in the IOKit device tree to the class being opened. It can be resolved to an
        /// `io_registry_entry_t` by calling `IORegistryEntryFromPath`
        ///
        /// This event is fired when a process calls IOServiceOpen() in order to open a communications channel with
        /// an I/O Kit driver. The event does not correspond to driver <-> device communication and is neither
        /// providing visibility nor access control into devices being attached.
        public var parentPath: String? /* field available only if message version >= 10 */
        
        public init(userClientType: UInt32, userClientClass: String, parentRegistryID: UInt64? = nil, parentPath: String? = nil) {
            self.userClientType = userClientType
            self.userClientClass = userClientClass
            self.parentRegistryID = parentRegistryID
            self.parentPath = parentPath
        }
    }
    
    /// Load a kernel extension
    ///
    /// - Note: This event type does not support caching.
    ///
    /// - Note: Not all AUTH_KEXTLOAD events can be delivered. In rare circumstances when kextloading is blocking all
    /// userspace execution it will be automatically allowed. NOTIFY_KEXTLOAD will still be (eventually) delivered.
    public struct KextLoad: Equatable, Codable, Sendable {
        /// The signing identifier of the kext being loaded
        public var identifier: String
        
        public init(identifier: String) {
            self.identifier = identifier
        }
    }
    
    /// Unload a kernel extension
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct KextUnload: Equatable, Codable, Sendable {
        /// The signing identifier of the kext being unloaded
        public var identifier: String
        
        public init(identifier: String) {
            self.identifier = identifier
        }
    }
    
    /// Notification for authenticated login event from /usr/bin/login.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct LoginLogin: Equatable, Codable, Sendable {
        /// True iff login was successful.
        public var success: Bool

        /// Optional. Failure message generated.
        public var failureMessage: String?

        /// Username used for login.
        public var username: String

        /// Describes whether or not the uid of the user logged in is available or not.
        public var uid: uid_t?
        
        public init(success: Bool, failureMessage: String?, username: String, uid: uid_t?) {
            self.success = success
            self.failureMessage = failureMessage
            self.username = username
            self.uid = uid
        }
    }
    
    /// Notification for authenticated logout event from /usr/bin/login.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct LoginLogout: Equatable, Codable, Sendable {
        /// Username used for login.
        public var username: String

        /// uid of user that was logged in.
        public var uid: uid_t
        
        public init(username: String, uid: uid_t) {
            self.username = username
            self.uid = uid
        }
    }
    
    /// Link to a file
    ///
    /// - Note: This event type does not support caching.
    public struct Link: Equatable, Codable, Sendable {
        /// The existing object to which a hard link will be created
        public var source: ESFile

        /// The directory in which the link will be created
        public var targetDir: ESFile

        /// The name of the new object linked to `source`
        public var targetFilename: String
        
        public init(source: ESFile, targetDir: ESFile, targetFilename: String) {
            self.source = source
            self.targetDir = targetDir
            self.targetFilename = targetFilename
        }
    }
    
    /// List extended attributes of a file
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct ListExtAttr: Equatable, Codable, Sendable {
        /// The file for which extended attributes are being retrieved
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Lookup a file system object
    ///
    /// - Note: The `relative_target` data may contain untrusted user input.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Lookup: Equatable, Codable, Sendable {
        /// The current directory
        public var sourceDir: ESFile

        /// The path to lookup relative to the `source_dir`
        public var relativeTarget: String
        
        public init(sourceDir: ESFile, relativeTarget: String) {
            self.sourceDir = sourceDir
            self.relativeTarget = relativeTarget
        }
    }
    
    /// es_graphical_session_id_t is a session identifier identifying a on-console or off-console graphical session.
    /// A graphical session exists and can potentially be attached to via Screen Sharing before a user is logged in.
    /// EndpointSecurity clients should treat the `graphical_session_id` as an opaque identifier and not assign
    /// special meaning to it beyond correlating events pertaining to the same graphical session. Not to be confused
    /// with the audit session ID. / typedef uint32_t es_graphical_session_id_t;
    ///
    /// /** Notification that LoginWindow has logged in a user.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct LWSessionLogin: Equatable, Codable, Sendable {
        /// Short username of the user.
        public var username: String

        /// Graphical session id of the session.
        public var graphicalSessionID: es_graphical_session_id_t
        
        public init(username: String, graphicalSessionID: es_graphical_session_id_t) {
            self.username = username
            self.graphicalSessionID = graphicalSessionID
        }
    }
    
    public typealias LWSessionLogout = LWSessionLogin
    public typealias LWSessionLock = LWSessionLogin
    public typealias LWSessionUnlock = LWSessionLogin
    
    /// Memory map a file
    ///
    /// - Note: Cache key for this event type: (process executable file, source file)
    public struct MMap: Equatable, Codable, Sendable {
        /// The protection (region accessibility) value
        public var protection: Int32

        /// The maximum allowed protection value the operating system will respect
        public var maxProtection: Int32

        /// The type and attributes of the mapped file
        public var flags: Int32

        /// The offset into `source` that will be mapped
        public var filePos: UInt64

        /// The file system object being mapped
        public var source: ESFile
        
        public init(protection: Int32, maxProtection: Int32, flags: Int32, filePos: UInt64, source: ESFile) {
            self.protection = protection
            self.maxProtection = maxProtection
            self.flags = flags
            self.filePos = filePos
            self.source = source
        }
    }
    
    /// Mount a file system
    ///
    /// - Note: Cache key for this event type: (process executable file, mount point)
    public struct Mount: Equatable, Codable, Sendable {
        /// The file system stats for the file system being mounted
        public var statfs: statfs
        
        /// The device disposition of the f_mntfromname
        public var disposition: es_mount_disposition_t? /* field available only if message version >= 8 */
        
        public init(statfs: statfs, disposition: es_mount_disposition_t? = nil) {
            self.statfs = statfs
            self.disposition = disposition
        }
    }
    
    /// Control protection of pages
    ///
    /// - Note: This event type does not support caching.
    public struct MProtect: Equatable, Codable, Sendable {
        /// The desired new protection value
        public var protection: Int32

        /// The base address to which the protection value will apply
        public var address: user_addr_t

        /// The size of the memory region the protection value will apply
        public var size: user_size_t
        
        public init(protection: Int32, address: user_addr_t, size: user_size_t) {
            self.protection = protection
            self.address = address
            self.size = size
        }
    }
    
    /// Open a file system object
    ///
    /// - Note: : The `fflag` field represents the mask as applied by the kernel, not as represented by typical open(2)
    /// `oflag` values. When responding to `ES_EVENT_TYPE_AUTH_OPEN` events using es_respond_flags_result(), ensure
    /// that the same FFLAG values are used (e.g. FREAD, FWRITE instead of O_RDONLY, O_RDWR, etc...).
    ///
    /// - Note: Cache key for this event type: (process executable file, file that will be opened)
    ///
    /// - Note: fcntl.h
    public struct Open: Equatable, Codable, Sendable {
        /// The desired flags to be used when opening `file` (see note)
        public var fflag: Int32

        /// The file that will be opened
        public var file: ESFile
        
        public init(fflag: Int32, file: ESFile) {
            self.fflag = fflag
            self.file = file
        }
    }
    
    /// Notification for OpenSSH login event.
    ///
    /// - Note: This is a connection-level event. An SSH connection that is used for multiple interactive sessions and/or
    /// non-interactive commands will emit only a single successful login event.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct OpensshLogin: Equatable, Codable, Sendable {
        /// True iff login was successful.
        public var success: Bool

        /// Result type for the login attempt.
        public var resultType: es_openssh_login_result_type_t

        /// Type of source address.
        public var sourceAddressType: es_address_type_t

        /// Source address of connection.
        public var sourceAddress: String

        /// Username used for login.
        public var username: String

        /// Describes whether or not the uid of the user logged in is available
        public var uid: uid_t?
        
        public init(success: Bool, resultType: es_openssh_login_result_type_t, sourceAddressType: es_address_type_t, sourceAddress: String, username: String, uid: uid_t?) {
            self.success = success
            self.resultType = resultType
            self.sourceAddressType = sourceAddressType
            self.sourceAddress = sourceAddress
            self.username = username
            self.uid = uid
        }
    }
    
    /// Notification for OpenSSH logout event.
    ///
    /// - Note: This is a connection-level event. An SSH connection that is used for multiple interactive sessions and/or
    /// non-interactive commands will emit only a single logout event.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct OpensshLogout: Equatable, Codable, Sendable {
        /// Type of address used in the connection.
        public var sourceAddressType: es_address_type_t

        /// Source address of the connection.
        public var sourceAddress: String

        /// Username which got logged out.
        public var username: String

        /// uid of user that was logged out.
        public var uid: uid_t
        
        public init(sourceAddressType: es_address_type_t, sourceAddress: String, username: String, uid: uid_t) {
            self.sourceAddressType = sourceAddressType
            self.sourceAddress = sourceAddress
            self.username = username
            self.uid = uid
        }
    }
    
    /// Access control check for retrieving process information.
    ///
    /// - Note: Cache key for this event type: (process executable file, target process executable file, type)
    public struct ProcCheck: Equatable, Codable, Sendable {
        /// The process for which the access will be checked
        public var target: ESProcess?

        /// The type of call number used to check the access on the target process
        public var type: es_proc_check_type_t

        /// The flavor used to check the access on the target process
        public var flavor: Int32
        
        public init(target: ESProcess?, type: es_proc_check_type_t, flavor: Int32) {
            self.target = target
            self.type = type
            self.flavor = flavor
        }
    }
    
    /// Fired when one of pid_suspend, pid_resume or pid_shutdown_sockets is called on a process.
    ///
    /// - Note: This event type does not support caching.
    public struct ProcSuspendResume: Equatable, Codable, Sendable {
        /// The process that is being suspended, resumed, or is the object of a pid_shutdown_sockets call.
        public var target: ESProcess?

        /// The type of operation that was called on the target process.
        public var type: es_proc_suspend_resume_type_t
        
        public init(target: ESProcess?, type: es_proc_suspend_resume_type_t) {
            self.target = target
            self.type = type
        }
    }
    
    /// Notification for Profiles installed on the system.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ProfileAdd: Equatable, Codable, Sendable {
        /// Process that instigated the Profile install or update.
        public var instigator: ESProcess?

        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */

        /// Indicates if the profile is an update to an already installed profile.
        public var isUpdate: Bool

        /// Profile install item.
        public var profile: ESProfile
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, isUpdate: Bool, profile: ESProfile) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.isUpdate = isUpdate
            self.profile = profile
        }
    }
    
    /// Notification for Profiles removed on the system.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ProfileRemove: Equatable, Codable, Sendable {
        /// Process that instigated the Profile removal.
        public var instigator: ESProcess?

        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */

        /// Profile being removed.
        public var profile: ESProfile
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, profile: ESProfile) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.profile = profile
        }
    }
    
    /// Fired when a pseudoterminal control device is closed
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct PtyClose: Equatable, Codable, Sendable {
        /// Major and minor numbers of device
        public var dev: dev_t
        
        public init(dev: dev_t) {
            self.dev = dev
        }
    }
    
    /// Fired when a pseudoterminal control device is granted
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct PtyGrant: Equatable, Codable, Sendable {
        /// Major and minor numbers of device
        public var dev: dev_t
        
        public init(dev: dev_t) {
            self.dev = dev
        }
    }
    
    /// Read directory entries
    ///
    /// - Note: Cache key for this event type: (process executable file, target directory)
    public struct Readdir: Equatable, Codable, Sendable {
        /// The directory whose contents will be read
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Resolve a symbolic link
    ///
    /// - Note: This is not limited only to readlink(2). Other operations such as path lookups can also cause this event to
    /// be fired.
    public struct Readlink: Equatable, Codable, Sendable {
        /// The symbolic link that is attempting to be resolved
        public var source: ESFile
        
        public init(source: ESFile) {
            self.source = source
        }
    }
    
    /// Notification that a process has attempted to create a thread in another process by calling one of the
    /// thread_create or thread_create_running MIG routines.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct RemoteThreadCreate: Equatable, Codable, Sendable {
        /// The process in which a new thread was created
        public var target: ESProcess

        /// The new thread state in case of thread_create_running, NULL in case of thread_create.
        public var threadState: ESThreadState?
        
        public init(target: ESProcess, threadState: ESThreadState?) {
            self.target = target
            self.threadState = threadState
        }
    }
    
    /// Remount a file system
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Remount: Equatable, Codable, Sendable {
        /// The file system stats for the file system being remounted
        public var statfs: statfs
        
        /// The provided remount flags
        public var remountFlags: UInt64? /* field available only if message version >= 8 */
        
        /// The device disposition of the f_mntfromname
        public var disposition: es_mount_disposition_t? /* field available only if message version >= 8 */
        
        public init(statfs: statfs, remountFlags: UInt64? = nil, disposition: es_mount_disposition_t? = nil) {
            self.statfs = statfs
            self.remountFlags = remountFlags
            self.disposition = disposition
        }
    }
    
    /// Rename a file system object
    ///
    /// - Note: The `destination_type` field describes which member in the `destination` union should accessed.
    /// `ES_DESTINATION_TYPE_EXISTING_FILE` means that `existing_file` should be used,
    /// `ES_DESTINATION_TYPE_NEW_PATH` means that the `new_path` struct should be used.
    ///
    /// - Note: This event can fire multiple times for a single syscall, for example when the syscall has to be retried due
    /// to racing VFS operations.
    ///
    /// - Note: This event type does not support caching.
    public struct Rename: Equatable, Codable, Sendable {
        /// The source file that is being renamed
        public var source: ESFile

        /// Information about the destination of the renamed file (see note)
        public var destination: Destination
        
        /// Whether or not the destination refers to an existing or new file.
        public enum Destination: Equatable, Codable, Sendable {
            case existingFile(ESFile)
            case newPath(dir: ESFile, filename: String)
        }
        
        public init(source: ESFile, destination: ESEvent.Rename.Destination) {
            self.source = source
            self.destination = destination
        }
    }
    
    /// Notification that Screen Sharing has attached to a graphical session.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: This event is not emitted when a screensharing session has the same source and destination address. For
    /// example if device A is acting as a NAT gateway for device B, then a screensharing session from B -> A would
    /// not emit an event.
    public struct ScreensharingAttach: Equatable, Codable, Sendable {
        /// True iff Screen Sharing successfully attached.
        public var success: Bool

        /// Type of source address.
        public var sourceAddressType: es_address_type_t

        /// Optional. Source address of connection, or NULL. Depending on the transport used, the source address may
        /// or may not be available.
        public var sourceAddress: String?

        /// Optional. For screen sharing initiated using an Apple ID (e.g., from Messages or FaceTime), this is the
        /// viewer's (client's) Apple ID. It is not necessarily the Apple ID that invited the screen sharing. NULL
        /// if unavailable.
        public var viewerAppleID: String?

        /// Type of authentication.
        public var authenticationType: String

        /// Optional. Username used for authentication to Screen Sharing. NULL if authentication type doesn't use an
        /// username (e.g. simple VNC password).
        public var authenticationUsername: String?

        /// Optional. Username of the loginwindow session if available, NULL otherwise.
        public var sessionUsername: String?

        /// True iff there was an existing user session.
        public var existingSession: Bool

        /// Graphical session id of the screen shared.
        public var graphicalSessionID: es_graphical_session_id_t
        
        public init(success: Bool, sourceAddressType: es_address_type_t, sourceAddress: String?, viewerAppleID: String?, authenticationType: String, authenticationUsername: String?, sessionUsername: String?, existingSession: Bool, graphicalSessionID: es_graphical_session_id_t) {
            self.success = success
            self.sourceAddressType = sourceAddressType
            self.sourceAddress = sourceAddress
            self.viewerAppleID = viewerAppleID
            self.authenticationType = authenticationType
            self.authenticationUsername = authenticationUsername
            self.sessionUsername = sessionUsername
            self.existingSession = existingSession
            self.graphicalSessionID = graphicalSessionID
        }
    }
    
    /// Notification that Screen Sharing has detached from a graphical session.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: This event is not emitted when a screensharing session has the same source and destination address.
    public struct ScreensharingDetach: Equatable, Codable, Sendable {
        /// Type of source address.
        public var sourceAddressType: es_address_type_t

        /// Optional. Source address of connection, or NULL. Depending on the transport used, the source address may
        /// or may not be available.
        public var sourceAddress: String?

        /// Optional. For screen sharing initiated using an Apple ID (e.g., from Messages or FaceTime), this is the
        /// viewer's (client's) Apple ID. It is not necessarily the Apple ID that invited the screen sharing. NULL
        /// if unavailable.
        public var viewerAppleID: String?

        /// Graphical session id of the screen shared.
        public var graphicalSessionID: es_graphical_session_id_t
        
        public init(sourceAddressType: es_address_type_t, sourceAddress: String?, viewerAppleID: String?, graphicalSessionID: es_graphical_session_id_t) {
            self.sourceAddressType = sourceAddressType
            self.sourceAddress = sourceAddress
            self.viewerAppleID = viewerAppleID
            self.graphicalSessionID = graphicalSessionID
        }
    }
    
    /// Access control check for searching a volume or a mounted file system
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct SearchFS: Equatable, Codable, Sendable {
        /// The attributes that will be used to do the search
        public var attrlist: attrlist

        /// The volume whose contents will be searched
        public var target: ESFile
        
        public init(attrlist: attrlist, target: ESFile) {
            self.attrlist = attrlist
            self.target = target
        }
    }
    
    /// Set a file ACL.
    ///
    /// - Note: This event type does not support caching.
    public struct SetACL: Equatable, Codable, Sendable {
        /// Describes the file whose ACL is being set.
        public var target: ESFile

        /// Describes whether or not the ACL on the `target` is being set or cleared
        public var setOrClear: es_set_or_clear_t
        
        /// Union that is valid when `set_or_clear` is set to `ES_SET`
        /// - Note: `acl` is present only in original message.
        /// If structure is re-encoded, this field will be lost.
        public nonisolated(unsafe) var acl: Resource<acl_t>?
        
        public init(target: ESFile, setOrClear: es_set_or_clear_t, acl: acl_t?) {
            self.target = target
            self.setOrClear = setOrClear
            if let acl = acl, let dup = acl_dup(acl) {
                self.acl = .raii(dup) { acl_free(.init($0)) }
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case target
            case setOrClear
        }
    }
    
    /// Set file system attributes
    ///
    /// - Note: This event type does not support caching.
    public struct SetAttrList: Equatable, Codable, Sendable {
        /// The attributes that will be modified
        public var attrlist: attrlist

        /// The file for which attributes will be modified
        public var target: ESFile
        
        public init(attrlist: attrlist, target: ESFile) {
            self.attrlist = attrlist
            self.target = target
        }
    }
    
    /// Set an extended attribute
    ///
    /// - Note: This event type does not support caching.
    public struct SetExtAttr: Equatable, Codable, Sendable {
        /// The file for which the extended attribute will be set
        public var target: ESFile

        /// The extended attribute which will be set
        public var extattr: String
        
        public init(target: ESFile, extattr: String) {
            self.target = target
            self.extattr = extattr
        }
    }
    
    /// Modify file flags information
    ///
    /// - Note: The `flags` member is the desired set of new flags. The `target` member's `stat` information contains the
    /// current set of flags.
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct SetFlags: Equatable, Codable, Sendable {
        /// The desired new flags
        public var flags: UInt32

        /// The file for which flags information will be modified
        public var target: ESFile
        
        public init(flags: UInt32, target: ESFile) {
            self.flags = flags
            self.target = target
        }
    }
    
    /// Modify file mode
    ///
    /// - Note: The `mode` member is the desired new mode. The `target` member's `stat` information contains the current
    /// mode.
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct SetMode: Equatable, Codable, Sendable {
        /// The desired new mode
        public var mode: mode_t

        /// The file for which mode information will be modified
        public var target: ESFile
        
        public init(mode: mode_t, target: ESFile) {
            self.mode = mode
            self.target = target
        }
    }
    
    /// Modify file owner information
    ///
    /// - Note: The `uid` and `gid` members are the desired new values. The `target` member's `stat` information contains
    /// the current uid and gid values.
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct SetOwner: Equatable, Codable, Sendable {
        /// The desired new UID
        public var uid: uid_t

        /// The desired new GID
        public var gid: gid_t

        /// The file for which owner information will be modified
        public var target: ESFile
        
        public init(uid: uid_t, gid: gid_t, target: ESFile) {
            self.uid = uid
            self.gid = gid
            self.target = target
        }
    }
    
    /// Notification that a process has called setegid().
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct SetUID: Equatable, Codable, Sendable {
        /// The egid argument to the setegid() syscall.
        public var uid: uid_t
        
        public init(uid: uid_t) {
            self.uid = uid
        }
    }
    
    /// Notification that a process has called setregid().
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct SetREUID: Equatable, Codable, Sendable {
        /// The rgid argument to the setregid() syscall.
        public var ruid: uid_t

        /// The egid argument to the setregid() syscall.
        public var euid: uid_t
        
        public init(ruid: uid_t, euid: uid_t) {
            self.ruid = ruid
            self.euid = euid
        }
    }
    
    /// Send a signal to a process
    ///
    /// Signals may be sent on behalf of another process or directly. Notably launchd often sends signals on behalf
    /// of another process for service start/stop operations. If this is the case an instigator will be provided.
    /// The relationship between each process is illustrated below:
    ///
    /// Delegated Signal:
    ///
    /// Instigator Process -> IPC to Sender Process (launchd) -> Target Process
    ///
    /// Direct Signal:
    ///
    /// Sender Process -> Target Process
    ///
    /// Clients may wish to block delegated signals from launchd for non-authorized instigators, while still
    /// allowing direct signals initiated by launchd for shutdown/reboot/restart.
    ///
    /// - Note: This event will not fire if a process sends a signal to itself.
    ///
    /// - Note: This event type does not support caching.
    ///
    /// - Note: Be aware of the nullablity of some of the fields. The instigator may not be applicable.
    public struct Signal: Equatable, Codable, Sendable {
        /// The signal number to be delivered
        public var sig: Int32

        /// The process that will receive the signal
        public var target: ESProcess
        
        /// Process information for the instigator (if applicable).
        public var instigator: ESProcess? /* field available only if message version >= 9 */
        
        public init(sig: Int32, target: ESProcess, instigator: ESProcess? = nil) {
            self.sig = sig
            self.target = target
            self.instigator = instigator
        }
    }
    
    /// View stat information of a file
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Stat: Equatable, Codable, Sendable {
        /// The file for which stat information will be retrieved
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// TCC Modification Event. Occurs when a TCC permission is granted or revoked.
    ///
    /// - Note: This event type does not support caching.
    public struct TCCModify: Equatable, Codable, Sendable {
        /// The TCC service for which permissions are being modified.
        public var service: String
        
        /// The identity of the application that is the subject of the permission.
        public var identity: String
        
        /// The identity type of the application string (Bundle ID, path, etc).
        public var identityType: es_tcc_identity_type_t
        
        /// The type of TCC modification event (Grant/Revoke etc)
        public var updateType: es_tcc_event_type_t
        
        /// Audit token of the instigator of the modification.
        public var instigatorToken: audit_token_t
        
        /// (Optional) The process information for the instigator.
        public var instigator: ESProcess?
        
        /// (Optional) Audit token of the responsible process for the modification.
        public var responsibleToken: audit_token_t?
        
        /// (Optional) The process information for the responsible process.
        public var responsible: ESProcess?
        
        /// The resulting TCC permission of the operation/modification.
        public var right: es_tcc_authorization_right_t
        
        /// The reason the TCC permissions were updated.
        public var reason: es_tcc_authorization_reason_t
        
        public init(service: String, identity: String, identityType: es_tcc_identity_type_t, updateType: es_tcc_event_type_t, instigatorToken: audit_token_t, instigator: ESProcess?, responsibleToken: audit_token_t?, responsible: ESProcess?, right: es_tcc_authorization_right_t, reason: es_tcc_authorization_reason_t) {
            self.service = service
            self.identity = identity
            self.identityType = identityType
            self.updateType = updateType
            self.instigatorToken = instigatorToken
            self.instigator = instigator
            self.responsibleToken = responsibleToken
            self.responsible = responsible
            self.right = right
            self.reason = reason
        }
    }
    
    /// Fired when one process attempts to attach to another process
    ///
    /// - Note: This event can fire multiple times for a single trace attempt, for example when the processes to which is
    /// being attached is reparented during the operation
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Trace: Equatable, Codable, Sendable {
        /// The process that will be attached to by the process that instigated the event
        public var target: ESProcess
        
        public init(target: ESProcess) {
            self.target = target
        }
    }
    
    /// Truncate a file
    ///
    /// - Note: This event type does not support caching.
    public struct Truncate: Equatable, Codable, Sendable {
        /// The file that is being truncated
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Fired when a UNIX-domain socket is about to be bound to a path.
    ///
    /// - Note: This event type does not support caching.
    public struct UipcBind: Equatable, Codable, Sendable {
        /// Describes the directory the socket file is created in.
        public var dir: ESFile

        /// The filename of the socket file.
        public var filename: String

        /// The mode of the socket file.
        public var mode: mode_t
        
        public init(dir: ESFile, filename: String, mode: mode_t) {
            self.dir = dir
            self.filename = filename
            self.mode = mode
        }
    }
    
    /// Fired when a UNIX-domain socket is about to be connected.
    ///
    /// - Note: Cache key for this event type: (process executable file, socket file)
    public struct UipcConnect: Equatable, Codable, Sendable {
        /// Describes the socket file that the socket is bound to.
        public var file: ESFile

        /// The communications domain of the socket (see socket(2)).
        public var domain: Int32

        /// The type of the socket (see socket(2)).
        public var type: Int32
        public var `protocol`: Int32
        
        public init(file: ESFile, domain: Int32, type: Int32, protocol: Int32) {
            self.file = file
            self.domain = domain
            self.type = type
            self.protocol = `protocol`
        }
    }
    
    /// Unlink a file system object
    ///
    /// - Note: This event can fire multiple times for a single syscall, for example when the syscall has to be retried due
    /// to racing VFS operations.
    ///
    /// - Note: This event type does not support caching.
    public struct Unlink: Equatable, Codable, Sendable {
        /// The object that will be removed
        public var target: ESFile

        /// The parent directory of the `target` file system object
        public var parentDir: ESFile
        
        public init(target: ESFile, parentDir: ESFile) {
            self.target = target
            self.parentDir = parentDir
        }
    }
    
    /// Unmount a file system
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Unmount: Equatable, Codable, Sendable {
        /// The file system stats for the file system being unmounted
        public var statfs: statfs
        
        public init(statfs: statfs) {
            self.statfs = statfs
        }
    }
    
    /// Change file access and modification times (e.g. via utimes(2))
    ///
    /// - Note: Cache key for this event type: (process executable file, target file)
    public struct Utimes: Equatable, Codable, Sendable {
        /// The path which will have its times modified
        public var target: ESFile

        /// The desired new access time
        public var aTime: timespec

        /// The desired new modification time
        public var mTime: timespec
        
        public init(target: ESFile, aTime: timespec, mTime: timespec) {
            self.target = target
            self.aTime = aTime
            self.mTime = mTime
        }
    }
    
    /// Write to a file
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct Write: Equatable, Codable, Sendable {
        /// The file being written to
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    /// Notification that XProtect detected malware.
    ///
    /// - Note: For any given malware incident, XProtect may emit zero or more xp_malware_detected events, and zero or more
    /// xp_malware_remediated events.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct XPMalwareDetected: Equatable, Codable, Sendable {
        /// Version of the signatures used for detection. Currently corresponds to XProtect version.
        public var signatureVersion: String

        /// String identifying the malware that was detected.
        public var malwareIdentifier: String

        /// String identifying the incident, intended for linking multiple malware detected and remediated events.
        public var incidentIdentifier: String

        /// Path where malware was detected. This path is not necessarily a malicious binary, it can also be a
        /// legitimate file containing a malicious portion.
        public var detectedPath: String
        
        /// Path to malicious binary. This can differ from detected_path when the detected path is an app bundle.
        public var detectedExecutable: String? /* field available only if message version >= 10 */
        
        public init(signatureVersion: String, malwareIdentifier: String, incidentIdentifier: String, detectedPath: String, detectedExecutable: String? = nil) {
            self.signatureVersion = signatureVersion
            self.malwareIdentifier = malwareIdentifier
            self.incidentIdentifier = incidentIdentifier
            self.detectedPath = detectedPath
            self.detectedExecutable = detectedExecutable
        }
    }
    
    /// Notification that XProtect remediated malware.
    ///
    /// - Note: For any given malware incident, XProtect may emit zero or more xp_malware_detected events, and zero or more
    /// xp_malware_remediated events.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct XPMalwareRemediated: Equatable, Codable, Sendable {
        /// Version of the signatures used for remediation. Currently corresponds to XProtect version.
        public var signatureVersion: String

        /// String identifying the malware that was detected.
        public var malwareIdentifier: String

        /// String identifying the incident, intended for linking multiple malware detected and remediated events.
        public var incidentIdentifier: String

        /// String indicating the type of action that was taken, e.g. "path_delete".
        public var actionType: String

        /// True iff remediation was successful.
        public var success: Bool

        /// String describing specific reasons for failure or success.
        public var resultDescription: String

        /// Optional. Path that was subject to remediation, if any. This path is not necessarily a malicious binary,
        /// it can also be a legitimate file containing a malicious portion. Specifically, the file at this path may
        /// still exist after successful remediation.
        public var remediatedPath: String?

        /// Audit token of process that was subject to remediation, if any.
        public var remediatedProcessAuditToken: audit_token_t?
        
        public init(signatureVersion: String, malwareIdentifier: String, incidentIdentifier: String, actionType: String, success: Bool, resultDescription: String, remediatedPath: String?, remediatedProcessAuditToken: audit_token_t?) {
            self.signatureVersion = signatureVersion
            self.malwareIdentifier = malwareIdentifier
            self.incidentIdentifier = incidentIdentifier
            self.actionType = actionType
            self.success = success
            self.resultDescription = resultDescription
            self.remediatedPath = remediatedPath
            self.remediatedProcessAuditToken = remediatedProcessAuditToken
        }
    }
    
    /// Notification for a su policy decisions events.
    ///
    /// - Note: This event type does not support caching (notify-only). Should always emit on success but will only emit on
    /// security relevant failures. For example, Endpoint Security clients will not get an event for su being passed
    /// invalid command line arguments.
    public struct SU: Equatable, Codable, Sendable {
        /// True iff su was successful.
        public var success: Bool

        /// Optional. If success is false, a failure message is contained in this field
        public var failureMessage: String?

        /// The uid of the user who initiated the su
        public var fromUID: uid_t

        /// The username of the user who initiated the su
        public var fromUsername: String

        /// True iff su was successful, Describes whether or not the to_uid is interpretable
        public var toUID: uid_t?

        /// Optional. If success, the user name that is going to be substituted
        public var toUsername: String?

        /// Optional. If success, the shell is going to execute
        public var shell: String?

        /// If success, the arguments are passed into to the shell
        public var args: [String]

        /// If success, list of environment variables that is going to be substituted
        public var env: [String]
        
        public init(success: Bool, failureMessage: String?, fromUID: uid_t, fromUsername: String, toUID: uid_t? = nil, toUsername: String?, shell: String?, args: [String], env: [String]) {
            self.success = success
            self.failureMessage = failureMessage
            self.fromUID = fromUID
            self.fromUsername = fromUsername
            self.toUID = toUID
            self.toUsername = toUsername
            self.shell = shell
            self.args = args
            self.env = env
        }
    }
    
    /// Notification for a sudo event.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct SUDO: Equatable, Codable, Sendable {
        /// True iff sudo was successful
        public var success: Bool

        /// Optional. When success is false, describes why sudo was rejected
        public var rejectInfo: RejectInfo?

        /// Describes whether or not the from_uid is interpretable
        public var fromUID: uid_t?

        /// Optional. The username of the user who initiated the sudo
        public var fromUsername: String?

        /// Describes whether or not the to_uid is interpretable
        public var toUID: uid_t?

        /// Optional. If success, the user name that is going to be substituted
        public var toUsername: String?

        /// Optional. The command to be run
        public var command: String?
        
        public init(success: Bool, rejectInfo: RejectInfo? = nil, fromUID: uid_t? = nil, fromUsername: String?, toUID: uid_t? = nil, toUsername: String?, command: String?) {
            self.success = success
            self.rejectInfo = rejectInfo
            self.fromUID = fromUID
            self.fromUsername = fromUsername
            self.toUID = toUID
            self.toUsername = toUsername
            self.command = command
        }
        
        /// Provides context about failures in es_event_sudo_t.
        public struct RejectInfo: Equatable, Codable, Sendable {
            /// The sudo plugin that initiated the reject
            public var pluginName: String

            /// The sudo plugin type that initiated the reject
            public var pluginType: es_sudo_plugin_type_t

            /// A reason represented by a string for the failure
            public var failureMessage: String
            
            public init(pluginName: String, pluginType: es_sudo_plugin_type_t, failureMessage: String) {
                self.pluginName = pluginName
                self.pluginType = pluginType
                self.failureMessage = failureMessage
            }
        }
    }
    
    /// Notification that a process peititioned for certain authorization rights
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct AuthorizationPetition: Equatable, Codable, Sendable {
        /// Process that submitted the petition (XPC caller)
        public var instigator: ESProcess?
        
        /// Audit token of the process that submitted the petition.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// Process that created the petition
        public var petitioner: ESProcess?
        
        /// Audit token of the process that created the petition.
        public var petitionerToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// Flags associated with the petition. Defined Security framework "Authorization/Authorizatioh.h"
        public var flags: UInt32
        
        /// Array of string tokens, each token is the name of a right being requested
        public var rights: [String]
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, petitioner: ESProcess? = nil, petitionerToken: audit_token_t? = nil, flags: UInt32, rights: [String]) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.petitioner = petitioner
            self.petitionerToken = petitionerToken
            self.flags = flags
            self.rights = rights
        }
    }
    
    /// Notification that a process had it's right petition judged
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct AuthorizationJudgement: Equatable, Codable, Sendable {
        /// Process that submitted the petition (XPC caller)
        public var instigator: ESProcess?
        
        /// Audit token of the process that submitted the petition.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// Process that created the petition
        public var petitioner: ESProcess?
        
        /// Audit token of the process that created the petition.
        public var petitionerToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// The overall result of the petition. 0 indicates success. Possible return codes are defined Security
        /// framework "Authorization/Authorizatioh.h"
        public var returnCode: Int32
        
        /// Array of results. One for each right that was peititioned
        public var results: [AuthorizationResult]
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, petitioner: ESProcess? = nil, petitionerToken: audit_token_t? = nil, returnCode: Int32, results: [AuthorizationResult]) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.petitioner = petitioner
            self.petitionerToken = petitionerToken
            self.returnCode = returnCode
            self.results = results
        }
        
        /// Describes, for a single right, the class of that right and if it was granted
        public struct AuthorizationResult: Equatable, Codable, Sendable {
            /// The name of the right being considered
            public var rightName: String
            
            /// The class of the right being considered The rule class determines how the operating system
            /// determines if it should be granted or not
            public var ruleClass: es_authorization_rule_class_t
            
            /// Indicates if the right was granted or not
            public var granted: Bool
            
            public init(rightName: String, ruleClass: es_authorization_rule_class_t, granted: Bool) {
                self.rightName = rightName
                self.ruleClass = ruleClass
                self.granted = granted
            }
        }
    }
    
    /// Notification that a member was added to a group.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: This event does not indicate that a member was actually added. For example when adding a user to a group
    /// they are already a member of.
    public struct ODGroupAdd: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The group to which the member was added.
        public var groupName: String
        
        /// The identity of the member added.
        public var member: ESODMemberID
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, groupName: String, member: ESODMemberID, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.groupName = groupName
            self.member = member
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a member was removed from a group.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: This event does not indicate that a member was actually removed. For example when removing a user from a
    /// group they are not a member of.
    public struct ODGroupRemove: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The group from which the member was removed.
        public var groupName: String
        
        /// The identity of the member removed.
        public var member: ESODMemberID
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, groupName: String, member: ESODMemberID, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.groupName = groupName
            self.member = member
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a group had it's members initialised or replaced.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: This event does not indicate that a member was actually removed. For example when removing a user from a
    /// group they are not a member of.
    public struct ODGroupSet: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The group for which members were set.
        public var groupName: String
        
        /// Array of new members.
        public var members: [ESODMemberID]
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, groupName: String, members: [ESODMemberID], nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.groupName = groupName
            self.members = members
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that an account had its password modified.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ODModifyPassword: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The type of the account for which the password was modified.
        public var accountType: es_od_account_type_t
        
        /// The name of the account for which the password was modified.
        public var accountName: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, accountType: es_od_account_type_t, accountName: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.accountType = accountType
            self.accountName = accountName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a user account was disabled.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ODDisableUser: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was disabled.
        public var userName: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, userName: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.userName = userName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a user account was enabled.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ODEnableUser: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was enabled.
        public var userName: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, userName: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.userName = userName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that an attribute value was added to a record.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: Attributes conceptually have the type `Map String (Set String)`. Each OD record has a Map of attribute name
    /// to Set of attribute value. When an attribute value is added, it is inserted into the set of values for that
    /// name.
    public struct ODAttributeValueAdd: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The type of the record to which the attribute value was added.
        public var recordType: es_od_record_type_t
        
        /// The name of the record to which the attribute value was added.
        public var recordName: String
        
        /// The name of the attribute to which the value was added.
        public var attributeName: String
        
        /// The value that was added.
        public var attributeValue: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, recordType: es_od_record_type_t, recordName: String, attributeName: String, attributeValue: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.recordType = recordType
            self.recordName = recordName
            self.attributeName = attributeName
            self.attributeValue = attributeValue
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that an attribute value was removed from a record.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: Attributes conceptually have the type `Map String (Set String)`. Each OD record has a Map of attribute name
    /// to Set of attribute value. When an attribute value is removed, it is subtraced from the set of values for
    /// that name.
    ///
    /// - Note: Removing a value that was never added is a no-op.
    public struct ODAttributeValueRemove: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The type of the record from which the attribute value was removed.
        public var recordType: es_od_record_type_t
        
        /// The name of the record from which the attribute value was removed.
        public var recordName: String
        
        /// The name of the attribute from which the value was removed.
        public var attributeName: String
        
        /// The value that was removed.
        public var attributeValue: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, recordType: es_od_record_type_t, recordName: String, attributeName: String, attributeValue: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.recordType = recordType
            self.recordName = recordName
            self.attributeName = attributeName
            self.attributeValue = attributeValue
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that an attribute is being set.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: Attributes conceptually have the type `Map String (Set String)`. Each OD record has a Map of attribute name
    /// to Set of attribute value. An attribute set operation indicates the entire set of attribute values was
    /// replaced.
    ///
    /// - Note: The new set of attribute values may be empty.
    public struct ODAttributeSet: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The type of the record for which the attribute is being set.
        public var recordType: es_od_record_type_t
        
        /// The name of the record for which the attribute is being set.
        public var recordName: String
        
        /// The name of the attribute that was set.
        public var attributeName: String
        
        /// Array of attribute values that were set.
        public var attributeValues: [String]
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, recordType: es_od_record_type_t, recordName: String, attributeName: String, attributeValues: [String], nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.recordType = recordType
            self.recordName = recordName
            self.attributeName = attributeName
            self.attributeValues = attributeValues
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a user account was created.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ODCreateUser: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was created.
        public var userName: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, userName: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.userName = userName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a group was created.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ODCreateGroup: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The name of the group that was created.
        public var groupName: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, groupName: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.groupName = groupName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a user account was deleted.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ODDeleteUser: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was deleted.
        public var userName: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, userName: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.userName = userName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a group was deleted.
    ///
    /// - Note: This event type does not support caching (notify-only).
    public struct ODDeleteGroup: Equatable, Codable, Sendable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t? /* field available only if message version >= 8 */
        
        /// 0 indicates the operation succeeded. Values indicating specific failure reasons are defined in
        /// odconstants.h.
        public var errorCode: Int32
        
        /// The name of the group that was deleted.
        public var groupName: String
        
        /// OD node being mutated. Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active
        /// Directory/<domain>".
        public var nodeName: String
        
        /// Optional. If node_name is "/Local/Default", this is the path of the database against which OD is
        /// authenticating.
        public var dbPath: String?
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t?, errorCode: Int32, groupName: String, nodeName: String, dbPath: String?) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.groupName = groupName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification for an XPC connection being established to a named service.
    ///
    /// - Note: This event type does not support caching.
    public struct XPCConnect: Equatable, Codable, Sendable {
        /// Service name of the named service.
        public var serviceName: String
        
        /// The type of XPC domain in which the service resides in.
        public var serviceDomainType: es_xpc_domain_type_t
        
        public init(serviceName: String, serviceDomainType: es_xpc_domain_type_t) {
            self.serviceName = serviceName
            self.serviceDomainType = serviceDomainType
        }
    }
    
    /// Notification for a gatekeeper_user_override events.
    ///
    /// - Note: This event type does not support caching (notify-only).
    ///
    /// - Note: Hashes are calculated in usermode by Gatekeeper. There is no guarantee that any other program including the
    /// kernel will observe the same file at the reported path. Furthermore there is no guarantee that the CDHash is
    /// valid or that it matches the containing binary.
    public struct GatekeeperUserOverride: Equatable, Codable, Sendable {
        /// Describes the target file that is being overridden by the user
        public var file: File
        
        /// SHA256 of the file. Provided if the filesize is less than 100MB.
        public var sha256: Data?
        
        /// Signing Information, available if the file has been signed.
        public var signing_info: ESSignedFileInfo?
        
        /// The type of the file field.
        /// If Endpoint security can't lookup the file at event submission
        /// it will emit a path instead of an `es_file_t`.
        public enum File: Equatable, Codable, Sendable {
            case path(String)
            case file(ESFile)
        }
        
        public init(file: File, sha256: Data?, signing_info: ESSignedFileInfo?) {
            self.file = file
            self.sha256 = sha256
            self.signing_info = signing_info
        }
    }
}

extension ESEvent.Create.Destination {
    public var path: String {
        switch self {
        case .existingFile(let file):
            return file.path
        case .newPath(let dir, let filename, _):
            return dir.path.appendingPathComponent(filename)
        }
    }
    
    public var mode: mode_t {
        switch self {
        case .existingFile(let file):
            return file.stat.st_mode
        case .newPath(_, _, let mode):
            return mode
        }
    }
}

extension ESEvent.Rename.Destination {
    public var path: String {
        switch self {
        case .existingFile(let file):
            return file.path
        case .newPath(let dir, let filename):
            return dir.path.appendingPathComponent(filename)
        }
    }
}
