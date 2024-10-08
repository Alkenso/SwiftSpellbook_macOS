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

public struct ESMessage: Equatable, Codable {
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
    
    public enum Action: Equatable, Codable {
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

public struct ESProcess: Equatable, Codable {
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
    
    public init(auditToken: audit_token_t, ppid: pid_t, originalPpid: pid_t, groupID: pid_t, sessionID: pid_t, codesigningFlags: UInt32, isPlatformBinary: Bool, isESClient: Bool, cdHash: Data, signingID: String, teamID: String, executable: ESFile, tty: ESFile?, startTime: timeval?, responsibleAuditToken: audit_token_t?, parentAuditToken: audit_token_t?) {
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
    }
}

extension ESProcess {
    public var name: String { executable.path.lastPathComponent }
}

public struct ESFile: Equatable, Codable {
    public var path: String
    public var truncated: Bool
    public var stat: stat
    
    public init(path: String, truncated: Bool, stat: stat) {
        self.path = path
        self.truncated = truncated
        self.stat = stat
    }
}

public struct ESThread: Equatable, Codable {
    public var threadID: UInt64
    
    public init(threadID: UInt64) {
        self.threadID = threadID
    }
}

public struct ESThreadState: Equatable, Codable {
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
public struct ESSignedFileInfo: Equatable, Codable {
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

public struct ESAuthResult: Equatable, Codable, RawRepresentable {
    public static func auth(_ auth: Bool) -> ESAuthResult { .init(rawValue: auth ? .max : 0) }
    public static func flags(_ flags: UInt32) -> ESAuthResult { .init(rawValue: flags) }
    
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public struct BTMLaunchItem: Equatable, Codable {
    public var itemType: es_btm_item_type_t
    public var legacy: Bool
    public var managed: Bool
    public var uid: uid_t
    public var itemURL: String
    public var appURL: String
    
    public init(itemType: es_btm_item_type_t, legacy: Bool, managed: Bool, uid: uid_t, itemURL: String, appURL: String) {
        self.itemType = itemType
        self.legacy = legacy
        self.managed = managed
        self.uid = uid
        self.itemURL = itemURL
        self.appURL = appURL
    }
}

public struct ESProfile: Equatable, Codable {
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
public enum ESODMemberID: Equatable, Codable {
    /// Group member is a user, designated by name.
    case userName(String)
    
    /// Group member is a user, designated by UUID
    case userUUID(UUID)
    
    /// Group member is another group, designated by UUID.
    case groupUUID(UUID)
}

public enum ESEvent: Equatable, Codable {
    case access(Access)
    case authentication(Authentication)
    case authorizationJudgement(AuthorizationJudgement)
    case authorizationPetition(AuthorizationPetition)
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

public extension ESEvent {
    struct Access: Equatable, Codable {
        public var mode: Int32
        public var target: ESFile
        
        public init(mode: Int32, target: ESFile) {
            self.mode = mode
            self.target = target
        }
    }
    
    struct Authentication: Equatable, Codable {
        public var success: Bool
        public var type: AuthenticationType
        
        public init(success: Bool, type: AuthenticationType) {
            self.success = success
            self.type = type
        }
    }
    
    enum AuthenticationType: Equatable, Codable {
        case od(OD)
        case touchID(TouchID)
        case token(Token)
        case autoUnlock(AutoUnlock)
        
        public struct OD: Equatable, Codable {
            public var instigator: ESProcess?
            public var instigatorToken: audit_token_t
            public var recordType: String
            public var recordName: String
            public var nodeName: String
            public var dbPath: String
            
            public init(instigator: ESProcess?, instigatorToken: audit_token_t, recordType: String, recordName: String, nodeName: String, dbPath: String) {
                self.instigator = instigator
                self.instigatorToken = instigatorToken
                self.recordType = recordType
                self.recordName = recordName
                self.nodeName = nodeName
                self.dbPath = dbPath
            }
        }
        
        public struct TouchID: Equatable, Codable {
            public var instigator: ESProcess?
            public var instigatorToken: audit_token_t
            public var touchIDMode: es_touchid_mode_t
            public var uid: uid_t?
            
            public init(instigator: ESProcess?, instigatorToken: audit_token_t, touchIDMode: es_touchid_mode_t, uid: uid_t?) {
                self.instigator = instigator
                self.instigatorToken = instigatorToken
                self.touchIDMode = touchIDMode
                self.uid = uid
            }
        }
        
        public struct Token: Equatable, Codable {
            public var instigator: ESProcess?
            public var instigatorToken: audit_token_t
            public var pubkeyHash: String
            public var tokenID: String
            public var kerberosPrincipal: String
            
            public init(instigator: ESProcess?, instigatorToken: audit_token_t, pubkeyHash: String, tokenID: String, kerberosPrincipal: String) {
                self.instigator = instigator
                self.instigatorToken = instigatorToken
                self.pubkeyHash = pubkeyHash
                self.tokenID = tokenID
                self.kerberosPrincipal = kerberosPrincipal
            }
        }
        
        public struct AutoUnlock: Equatable, Codable {
            public var username: String
            public var type: es_auto_unlock_type_t
            
            public init(username: String, type: es_auto_unlock_type_t) {
                self.username = username
                self.type = type
            }
        }
    }
    
    struct BTMLaunchItemAdd: Equatable, Codable {
        public var instigator: ESProcess?
        public var app: ESProcess?
        public var item: BTMLaunchItem
        public var executablePath: String
        
        public init(instigator: ESProcess?, app: ESProcess?, item: BTMLaunchItem, executablePath: String) {
            self.instigator = instigator
            self.app = app
            self.item = item
            self.executablePath = executablePath
        }
    }
    
    struct BTMLaunchItemRemove: Equatable, Codable {
        public var instigator: ESProcess?
        public var app: ESProcess?
        public var item: BTMLaunchItem
        
        public init(instigator: ESProcess?, app: ESProcess?, item: BTMLaunchItem) {
            self.instigator = instigator
            self.app = app
            self.item = item
        }
    }
    
    struct Chdir: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct Chroot: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct Clone: Equatable, Codable {
        public var source: ESFile
        public var targetDir: ESFile
        public var targetName: String
        
        public init(source: ESFile, targetDir: ESFile, targetName: String) {
            self.source = source
            self.targetDir = targetDir
            self.targetName = targetName
        }
    }
    
    struct CopyFile: Equatable, Codable {
        public var source: ESFile
        public var targetFile: ESFile?
        public var targetDir: ESFile
        public var targetName: String
        public var mode: mode_t
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
    
    struct Close: Equatable, Codable {
        public var modified: Bool
        public var target: ESFile
        
        public init(modified: Bool, target: ESFile) {
            self.modified = modified
            self.target = target
        }
    }
    
    struct Create: Equatable, Codable {
        public var destination: Destination
        
        /// - Note: field available only if message version >= 2
        /// - Note: `acl` is present only in original message.
        /// If structure is re-encoded, this field will be lost.
        public var acl: Resource<acl_t>?
        
        public enum Destination: Equatable, Codable {
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
    
    struct DeleteExtAttr: Equatable, Codable {
        public var target: ESFile
        public var extattr: String
        
        public init(target: ESFile, extattr: String) {
            self.target = target
            self.extattr = extattr
        }
    }
    
    struct Dup: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct ExchangeData: Equatable, Codable {
        public var file1: ESFile
        public var file2: ESFile
        
        public init(file1: ESFile, file2: ESFile) {
            self.file1 = file1
            self.file2 = file2
        }
    }
    
    struct Exec: Equatable, Codable {
        public var target: ESProcess
        public var script: ESFile? /* field available only if message version >= 2 */
        public var cwd: ESFile? /* field available only if message version >= 3 */
        public var lastFD: Int32? /* field available only if message version >= 4 */
        
        public var args: [String]? // present if ESConverter.Config.execArgs == true
        public var env: [String]? // present if ESConverter.Config.execEnv == true
        
        public init(target: ESProcess, script: ESFile?, cwd: ESFile?, lastFD: Int32?) {
            self.target = target
            self.script = script
            self.cwd = cwd
            self.lastFD = lastFD
        }
    }
    
    struct Exit: Equatable, Codable {
        public var status: Int32
        
        public init(status: Int32) {
            self.status = status
        }
    }
    
    struct FileProviderMaterialize: Equatable, Codable {
        public var instigator: ESProcess?
        public var instigatorToken: audit_token_t
        public var source: ESFile
        public var target: ESFile
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, source: ESFile, target: ESFile) {
            self.instigator = instigator
            self.source = source
            self.target = target
            self.instigatorToken = instigatorToken
        }
    }
    
    struct FileProviderUpdate: Equatable, Codable {
        public var source: ESFile
        public var targetPath: String
        
        public init(source: ESFile, targetPath: String) {
            self.source = source
            self.targetPath = targetPath
        }
    }
    
    struct Fcntl: Equatable, Codable {
        public var target: ESFile
        public var cmd: Int32
        
        public init(target: ESFile, cmd: Int32) {
            self.target = target
            self.cmd = cmd
        }
    }
    
    struct Fork: Equatable, Codable {
        public var child: ESProcess
        
        public init(child: ESProcess) {
            self.child = child
        }
    }
    
    struct FsGetPath: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct GetTask: Equatable, Codable {
        public var target: ESProcess
        
        public init(target: ESProcess) {
            self.target = target
        }
    }
    
    struct GetTaskRead: Equatable, Codable {
        public var target: ESProcess
        
        public init(target: ESProcess) {
            self.target = target
        }
    }
    
    struct GetTaskInspect: Equatable, Codable {
        public var target: ESProcess
        
        public init(target: ESProcess) {
            self.target = target
        }
    }
    
    struct GetTaskName: Equatable, Codable {
        public var target: ESProcess
        
        public init(target: ESProcess) {
            self.target = target
        }
    }
    
    struct GetAttrList: Equatable, Codable {
        public var attrlist: attrlist
        public var target: ESFile
        
        public init(attrlist: attrlist, target: ESFile) {
            self.attrlist = attrlist
            self.target = target
        }
    }
    
    struct GetExtAttr: Equatable, Codable {
        public var target: ESFile
        public var extattr: String
        
        public init(target: ESFile, extattr: String) {
            self.target = target
            self.extattr = extattr
        }
    }
    
    struct IOKitOpen: Equatable, Codable {
        public var userClientType: UInt32
        public var userClientClass: String
        
        public init(userClientType: UInt32, userClientClass: String) {
            self.userClientType = userClientType
            self.userClientClass = userClientClass
        }
    }
    
    struct KextLoad: Equatable, Codable {
        public var identifier: String
        
        public init(identifier: String) {
            self.identifier = identifier
        }
    }
    
    struct KextUnload: Equatable, Codable {
        public var identifier: String
        
        public init(identifier: String) {
            self.identifier = identifier
        }
    }
    
    struct LoginLogin: Equatable, Codable {
        public var success: Bool
        public var failureMessage: String
        public var username: String
        public var uid: uid_t?
        
        public init(success: Bool, failureMessage: String, username: String, uid: uid_t?) {
            self.success = success
            self.failureMessage = failureMessage
            self.username = username
            self.uid = uid
        }
    }
    
    struct LoginLogout: Equatable, Codable {
        public var username: String
        public var uid: uid_t
        
        public init(username: String, uid: uid_t) {
            self.username = username
            self.uid = uid
        }
    }
    
    struct Link: Equatable, Codable {
        public var source: ESFile
        public var targetDir: ESFile
        public var targetFilename: String
        
        public init(source: ESFile, targetDir: ESFile, targetFilename: String) {
            self.source = source
            self.targetDir = targetDir
            self.targetFilename = targetFilename
        }
    }
    
    struct ListExtAttr: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct Lookup: Equatable, Codable {
        public var sourceDir: ESFile
        public var relativeTarget: String
        
        public init(sourceDir: ESFile, relativeTarget: String) {
            self.sourceDir = sourceDir
            self.relativeTarget = relativeTarget
        }
    }
    
    struct LWSessionLogin: Equatable, Codable {
        public var username: String
        public var graphicalSessionID: es_graphical_session_id_t
        
        public init(username: String, graphicalSessionID: es_graphical_session_id_t) {
            self.username = username
            self.graphicalSessionID = graphicalSessionID
        }
    }
    
    typealias LWSessionLogout = LWSessionLogin
    typealias LWSessionLock = LWSessionLogin
    typealias LWSessionUnlock = LWSessionLogin
    
    struct MMap: Equatable, Codable {
        public var protection: Int32
        public var maxProtection: Int32
        public var flags: Int32
        public var filePos: UInt64
        public var source: ESFile
        
        public init(protection: Int32, maxProtection: Int32, flags: Int32, filePos: UInt64, source: ESFile) {
            self.protection = protection
            self.maxProtection = maxProtection
            self.flags = flags
            self.filePos = filePos
            self.source = source
        }
    }
    
    struct Mount: Equatable, Codable {
        public var statfs: statfs
        
        public init(statfs: statfs) {
            self.statfs = statfs
        }
    }
    
    struct MProtect: Equatable, Codable {
        public var protection: Int32
        public var address: user_addr_t
        public var size: user_size_t
        
        public init(protection: Int32, address: user_addr_t, size: user_size_t) {
            self.protection = protection
            self.address = address
            self.size = size
        }
    }
    
    struct Open: Equatable, Codable {
        public var fflag: Int32
        public var file: ESFile
        
        public init(fflag: Int32, file: ESFile) {
            self.fflag = fflag
            self.file = file
        }
    }
    
    struct OpensshLogin: Equatable, Codable {
        public var success: Bool
        public var resultType: es_openssh_login_result_type_t
        public var sourceAddressType: es_address_type_t
        public var sourceAddress: String
        public var username: String
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
    
    struct OpensshLogout: Equatable, Codable {
        public var sourceAddressType: es_address_type_t
        public var sourceAddress: String
        public var username: String
        public var uid: uid_t
        
        public init(sourceAddressType: es_address_type_t, sourceAddress: String, username: String, uid: uid_t) {
            self.sourceAddressType = sourceAddressType
            self.sourceAddress = sourceAddress
            self.username = username
            self.uid = uid
        }
    }
    
    struct ProcCheck: Equatable, Codable {
        public var target: ESProcess?
        public var type: es_proc_check_type_t
        public var flavor: Int32
        
        public init(target: ESProcess?, type: es_proc_check_type_t, flavor: Int32) {
            self.target = target
            self.type = type
            self.flavor = flavor
        }
    }
    
    struct ProcSuspendResume: Equatable, Codable {
        public var target: ESProcess?
        public var type: es_proc_suspend_resume_type_t
        
        public init(target: ESProcess?, type: es_proc_suspend_resume_type_t) {
            self.target = target
            self.type = type
        }
    }
    
    struct ProfileAdd: Equatable, Codable {
        public var instigator: ESProcess?
        public var instigatorToken: audit_token_t
        public var isUpdate: Bool
        public var profile: ESProfile
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, isUpdate: Bool, profile: ESProfile) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.isUpdate = isUpdate
            self.profile = profile
        }
    }
    
    struct ProfileRemove: Equatable, Codable {
        public var instigator: ESProcess?
        public var instigatorToken: audit_token_t
        public var profile: ESProfile
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, profile: ESProfile) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.profile = profile
        }
    }
    
    struct PtyClose: Equatable, Codable {
        public var dev: dev_t
        
        public init(dev: dev_t) {
            self.dev = dev
        }
    }
    
    struct PtyGrant: Equatable, Codable {
        public var dev: dev_t
        
        public init(dev: dev_t) {
            self.dev = dev
        }
    }
    
    struct Readdir: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct Readlink: Equatable, Codable {
        public var source: ESFile
        
        public init(source: ESFile) {
            self.source = source
        }
    }
    
    struct RemoteThreadCreate: Equatable, Codable {
        public var target: ESProcess
        public var threadState: ESThreadState?
        
        public init(target: ESProcess, threadState: ESThreadState?) {
            self.target = target
            self.threadState = threadState
        }
    }
    
    struct Remount: Equatable, Codable {
        public var statfs: statfs
        
        public init(statfs: statfs) {
            self.statfs = statfs
        }
    }
    
    struct Rename: Equatable, Codable {
        public var source: ESFile
        public var destination: Destination
        
        public enum Destination: Equatable, Codable {
            case existingFile(ESFile)
            case newPath(dir: ESFile, filename: String)
        }
        
        public init(source: ESFile, destination: ESEvent.Rename.Destination) {
            self.source = source
            self.destination = destination
        }
    }
    
    struct ScreensharingAttach: Equatable, Codable {
        public var success: Bool
        public var sourceAddressType: es_address_type_t
        public var sourceAddress: String
        public var viewerAppleID: String
        public var authenticationType: String
        public var authenticationUsername: String
        public var sessionUsername: String
        public var existingSession: Bool
        public var graphicalSessionID: es_graphical_session_id_t
        
        public init(success: Bool, sourceAddressType: es_address_type_t, sourceAddress: String, viewerAppleID: String, authenticationType: String, authenticationUsername: String, sessionUsername: String, existingSession: Bool, graphicalSessionID: es_graphical_session_id_t) {
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
    
    struct ScreensharingDetach: Equatable, Codable {
        public var sourceAddressType: es_address_type_t
        public var sourceAddress: String
        public var viewerAppleID: String
        public var graphicalSessionID: es_graphical_session_id_t
        
        public init(sourceAddressType: es_address_type_t, sourceAddress: String, viewerAppleID: String, graphicalSessionID: es_graphical_session_id_t) {
            self.sourceAddressType = sourceAddressType
            self.sourceAddress = sourceAddress
            self.viewerAppleID = viewerAppleID
            self.graphicalSessionID = graphicalSessionID
        }
    }
    
    struct SearchFS: Equatable, Codable {
        public var attrlist: attrlist
        public var target: ESFile
        
        public init(attrlist: attrlist, target: ESFile) {
            self.attrlist = attrlist
            self.target = target
        }
    }
    
    struct SetACL: Equatable, Codable {
        public var target: ESFile
        public var setOrClear: es_set_or_clear_t
        
        /// - Note: `acl` is present only in original message.
        /// If structure is re-encoded, this field will be lost.
        public var acl: Resource<acl_t>?
        
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
    
    struct SetAttrList: Equatable, Codable {
        public var attrlist: attrlist
        public var target: ESFile
        
        public init(attrlist: attrlist, target: ESFile) {
            self.attrlist = attrlist
            self.target = target
        }
    }
    
    struct SetExtAttr: Equatable, Codable {
        public var target: ESFile
        public var extattr: String
        
        public init(target: ESFile, extattr: String) {
            self.target = target
            self.extattr = extattr
        }
    }
    
    struct SetFlags: Equatable, Codable {
        public var flags: UInt32
        public var target: ESFile
        
        public init(flags: UInt32, target: ESFile) {
            self.flags = flags
            self.target = target
        }
    }
    
    struct SetMode: Equatable, Codable {
        public var mode: mode_t
        public var target: ESFile
        
        public init(mode: mode_t, target: ESFile) {
            self.mode = mode
            self.target = target
        }
    }
    
    struct SetOwner: Equatable, Codable {
        public var uid: uid_t
        public var gid: gid_t
        public var target: ESFile
        
        public init(uid: uid_t, gid: gid_t, target: ESFile) {
            self.uid = uid
            self.gid = gid
            self.target = target
        }
    }
    
    struct SetUID: Equatable, Codable {
        public var uid: uid_t
        
        public init(uid: uid_t) {
            self.uid = uid
        }
    }
    
    struct SetREUID: Equatable, Codable {
        public var ruid: uid_t
        public var euid: uid_t
        
        public init(ruid: uid_t, euid: uid_t) {
            self.ruid = ruid
            self.euid = euid
        }
    }
    
    struct Signal: Equatable, Codable {
        public var sig: Int32
        public var target: ESProcess
        
        public init(sig: Int32, target: ESProcess) {
            self.sig = sig
            self.target = target
        }
    }
    
    struct Stat: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct Trace: Equatable, Codable {
        public var target: ESProcess
        
        public init(target: ESProcess) {
            self.target = target
        }
    }
    
    struct Truncate: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct UipcBind: Equatable, Codable {
        public var dir: ESFile
        public var filename: String
        public var mode: mode_t
        
        public init(dir: ESFile, filename: String, mode: mode_t) {
            self.dir = dir
            self.filename = filename
            self.mode = mode
        }
    }
    
    struct UipcConnect: Equatable, Codable {
        public var file: ESFile
        public var domain: Int32
        public var type: Int32
        public var `protocol`: Int32
        
        public init(file: ESFile, domain: Int32, type: Int32, protocol: Int32) {
            self.file = file
            self.domain = domain
            self.type = type
            self.protocol = `protocol`
        }
    }
    
    struct Unlink: Equatable, Codable {
        public var target: ESFile
        public var parentDir: ESFile
        
        public init(target: ESFile, parentDir: ESFile) {
            self.target = target
            self.parentDir = parentDir
        }
    }
    
    struct Unmount: Equatable, Codable {
        public var statfs: statfs
        
        public init(statfs: statfs) {
            self.statfs = statfs
        }
    }
    
    struct Utimes: Equatable, Codable {
        public var target: ESFile
        public var aTime: timespec
        public var mTime: timespec
        
        public init(target: ESFile, aTime: timespec, mTime: timespec) {
            self.target = target
            self.aTime = aTime
            self.mTime = mTime
        }
    }
    
    struct Write: Equatable, Codable {
        public var target: ESFile
        
        public init(target: ESFile) {
            self.target = target
        }
    }
    
    struct XPMalwareDetected: Equatable, Codable {
        public var signatureVersion: String
        public var malwareIdentifier: String
        public var incidentIdentifier: String
        public var detectedPath: String
        
        public init(signatureVersion: String, malwareIdentifier: String, incidentIdentifier: String, detectedPath: String) {
            self.signatureVersion = signatureVersion
            self.malwareIdentifier = malwareIdentifier
            self.incidentIdentifier = incidentIdentifier
            self.detectedPath = detectedPath
        }
    }
    
    struct XPMalwareRemediated: Equatable, Codable {
        public var signatureVersion: String
        public var malwareIdentifier: String
        public var incidentIdentifier: String
        public var actionType: String
        public var success: Bool
        public var resultDescription: String
        public var remediatedPath: String
        public var remediatedProcessAuditToken: audit_token_t?
        
        public init(signatureVersion: String, malwareIdentifier: String, incidentIdentifier: String, actionType: String, success: Bool, resultDescription: String, remediatedPath: String, remediatedProcessAuditToken: audit_token_t?) {
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
    
    struct SU: Equatable, Codable {
        public var success: Bool
        public var failureMessage: String
        public var fromUID: uid_t
        public var fromUsername: String
        public var toUID: uid_t?
        public var toUsername: String
        public var shell: String
        public var args: [String]
        public var env: [String]
        
        public init(success: Bool, failureMessage: String, fromUID: uid_t, fromUsername: String, toUID: uid_t? = nil, toUsername: String, shell: String, args: [String], env: [String]) {
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
    
    struct SUDO: Equatable, Codable {
        public var success: Bool
        public var rejectInfo: RejectInfo?
        public var fromUID: uid_t?
        public var fromUsername: String
        public var toUID: uid_t?
        public var toUsername: String
        public var command: String
        
        public init(success: Bool, rejectInfo: RejectInfo? = nil, fromUID: uid_t? = nil, fromUsername: String, toUID: uid_t? = nil, toUsername: String, command: String) {
            self.success = success
            self.rejectInfo = rejectInfo
            self.fromUID = fromUID
            self.fromUsername = fromUsername
            self.toUID = toUID
            self.toUsername = toUsername
            self.command = command
        }
        
        public struct RejectInfo: Equatable, Codable {
            public var pluginName: String
            public var pluginType: es_sudo_plugin_type_t
            public var failureMessage: String
            
            public init(pluginName: String, pluginType: es_sudo_plugin_type_t, failureMessage: String) {
                self.pluginName = pluginName
                self.pluginType = pluginType
                self.failureMessage = failureMessage
            }
        }
    }
    
    /// Notification that a process peititioned for certain authorization rights.
    struct AuthorizationPetition: Equatable, Codable {
        /// Process that submitted the petition (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// Process that created the petition.
        public var petitioner: ESProcess?
        
        /// Flags associated with the petition. Defined Security framework "Authorization/Authorizatioh.h".
        public var flags: UInt32
        
        /// Array of string tokens, each token is the name of a right being requested.
        public var rights: [String]
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, petitioner: ESProcess? = nil, flags: UInt32, rights: [String]) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.petitioner = petitioner
            self.flags = flags
            self.rights = rights
        }
    }
    
    /// Notification that a process had it's right petition judged.
    struct AuthorizationJudgement: Equatable, Codable {
        /// Process that submitted the petition (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// Process that created the petition.
        public var petitioner: ESProcess?
        
        /// The overall result of the petition. 0 indicates success.
        /// Possible return codes are defined Security framework "Authorization/Authorizatioh.h".
        public var returnCode: Int32
        
        /// Array of results. One for each right that was peititioned.
        public var results: [AuthorizationResult]
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, petitioner: ESProcess? = nil, returnCode: Int32, results: [AuthorizationResult]) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.petitioner = petitioner
            self.returnCode = returnCode
            self.results = results
        }
        
        /// Describes, for a single right, the class of that right and if it was granted.
        public struct AuthorizationResult: Equatable, Codable {
            /// The name of the right being considered.
            public var rightName: String
            
            /// The class of the right being considered.
            /// The rule class determines how the operating system determines
            /// if it should be granted or not.
            public var ruleClass: es_authorization_rule_class_t
            
            /// Indicates if the right was granted or not.
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
    /// - Note: This event does not indicate that a member was actually added.
    /// For example when adding a user to a group they are already a member of.
    struct ODGroupAdd: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The group to which the member was added.
        public var groupName: String
        
        /// The identity of the member added.
        public var member: ESODMemberID
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, groupName: String, member: ESODMemberID, nodeName: String, dbPath: String) {
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
    /// - Note: This event does not indicate that a member was actually removed.
    /// For example when removing a user from a group they are not a member of.
    struct ODGroupRemove: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The group from which the member was removed.
        public var groupName: String
        
        /// The identity of the member removed.
        public var member: ESODMemberID
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, groupName: String, member: ESODMemberID, nodeName: String, dbPath: String) {
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
    /// - Note: This event does not indicate that a member was actually removed.
    /// For example when removing a user from a group they are not a member of.
    struct ODGroupSet: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The group for which members were set.
        public var groupName: String
        
        public var members: [ESODMemberID]
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, groupName: String, members: [ESODMemberID], nodeName: String, dbPath: String) {
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
    struct ODModifyPassword: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The type of the account for which the password was modified.
        public var accountType: es_od_account_type_t
        
        /// The name of the account for which the password was modified.
        public var accountName: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, accountType: es_od_account_type_t, accountName: String, nodeName: String, dbPath: String) {
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
    struct ODDisableUser: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was created.
        public var userName: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, userName: String, nodeName: String, dbPath: String) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.userName = userName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a user account was enabled.
    struct ODEnableUser: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was created.
        public var userName: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, userName: String, nodeName: String, dbPath: String) {
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
    /// - Note: Attributes conceptually have the type `Map String (Set String)`.
    /// Each OD record has a Map of attribute name to Set of attribute value.
    /// When an attribute value is added, it is inserted into the set of values for that name.
    struct ODAttributeValueAdd: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The type of the record to which the attribute value was added.
        public var recordType: es_od_record_type_t
        
        /// The name of the record to which the attribute value was added.
        public var recordName: String
        
        /// The name of the attribute to which the value was added.
        public var attributeName: String
        
        /// The value that was added.
        public var attributeValue: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, recordType: es_od_record_type_t, recordName: String, attributeName: String, attributeValue: String, nodeName: String, dbPath: String) {
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
    /// - Note: Attributes conceptually have the type `Map String (Set String)`.
    /// Each OD record has a Map of attribute name to Set of attribute value.
    /// When an attribute value is removed, it is subtraced from the set of values for that name.
    ///
    /// - Note: Removing a value that was never added is a no-op.
    struct ODAttributeValueRemove: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The type of the record from which the attribute value was removed.
        public var recordType: es_od_record_type_t
        
        /// The name of the record from which the attribute value was removed.
        public var recordName: String
        
        /// The name of the attribute from which the value was removed.
        public var attributeName: String
        
        /// The value that was removed.
        public var attributeValue: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, recordType: es_od_record_type_t, recordName: String, attributeName: String, attributeValue: String, nodeName: String, dbPath: String) {
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
    
    /// brief Notification that an attribute is being set.
    ///
    /// - Note: Attributes conceptually have the type `Map String (Set String)`.
    /// Each OD record has a Map of attribute name to Set of attribute value.
    /// An attribute set operation indicates the entire set of attribute values was replaced.
    ///
    /// - Note: The new set of attribute values may be empty.
    struct ODAttributeSet: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The type of the record for which the attribute is being set.
        public var recordType: es_od_record_type_t
        
        /// The name of the record for which the attribute is being set.
        public var recordName: String
        
        /// The name of the attribute that was set.
        public var attributeName: String
        
        /// Array of attribute values that were set.
        public var attributeValues: [String]
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, recordType: es_od_record_type_t, recordName: String, attributeName: String, attributeValues: [String], nodeName: String, dbPath: String) {
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
    struct ODCreateUser: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was created.
        public var userName: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, userName: String, nodeName: String, dbPath: String) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.userName = userName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a group was created.
    struct ODCreateGroup: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The name of the group that was created.
        public var groupName: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, groupName: String, nodeName: String, dbPath: String) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.groupName = groupName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a user account was deleted.
    struct ODDeleteUser: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The name of the user account that was deleted.
        public var userName: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, userName: String, nodeName: String, dbPath: String) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.userName = userName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification that a group was deleted.
    struct ODDeleteGroup: Equatable, Codable {
        /// Process that instigated operation (XPC caller).
        public var instigator: ESProcess?
        
        /// Audit token of the process that instigated this event.
        public var instigatorToken: audit_token_t
        
        /// 0 indicates the operation succeeded.
        /// Values inidicating specific failure reasons are defined in odconstants.h.
        public var errorCode: Int32
        
        /// The name of the group that was deleted.
        public var groupName: String
        
        /// OD node being mutated.
        /// Typically one of "/Local/Default", "/LDAPv3/<server>" or "/Active Directory/<domain>".
        public var nodeName: String
        
        /// Optional.  If node_name is "/Local/Default", this is the path of the database
        /// against which OD is authenticating.
        public var dbPath: String
        
        public init(instigator: ESProcess?, instigatorToken: audit_token_t, errorCode: Int32, groupName: String, nodeName: String, dbPath: String) {
            self.instigator = instigator
            self.instigatorToken = instigatorToken
            self.errorCode = errorCode
            self.groupName = groupName
            self.nodeName = nodeName
            self.dbPath = dbPath
        }
    }
    
    /// Notification for an XPC connection being established to a named service.
    struct XPCConnect: Equatable, Codable {
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
    /// - Note: Hashes are calculated in usermode by Gatekeeper. There is no guarantee that
    /// any other program including the kernel will observe the same file at the reported path.
    /// Furthermore there is no guarantee that the CDHash is valid or that it matches the containing binary.
    struct GatekeeperUserOverride: Equatable, Codable {
        /// Describes the target file that is being overridden by the user
        public var file: File
        
        /// SHA256 of the file. Provided if the filesize is less than 100MB.
        public var sha256: Data?
        
        /// Signing Information, available if the file has been signed.
        public var signing_info: ESSignedFileInfo?
        
        /// The type of the file field.
        /// If Endpoint security can't lookup the file at event submission
        /// it will emit a path instead of an `es_file_t`.
        public enum File: Equatable, Codable {
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
