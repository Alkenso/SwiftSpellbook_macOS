import EndpointSecurity
import Foundation
import Testing
@testable import SpellbookEndpointSecurity

private final class ESConverterFixture {
    private var cleanups: [() -> Void] = []

    deinit {
        for cleanup in cleanups.reversed() {
            cleanup()
        }
    }

    func make<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<T>.stride,
            alignment: MemoryLayout<T>.alignment
        )
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: MemoryLayout<T>.stride)
        cleanups.append { raw.deallocate() }
        return raw.bindMemory(to: T.self, capacity: 1)
    }

    func string(_ value: String) -> es_string_token_t {
        let data = strdup(value)!
        cleanups.append { free(data) }
        return es_string_token_t(length: value.utf8.count, data: data)
    }

    func bytes(_ values: [UInt8]) -> UnsafePointer<UInt8> {
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: values.count)
        data.initialize(from: values, count: values.count)
        cleanups.append {
            data.deinitialize(count: values.count)
            data.deallocate()
        }
        return UnsafePointer(data)
    }

    func array<T>(_ values: [T]) -> UnsafeMutablePointer<T> {
        let data = UnsafeMutablePointer<T>.allocate(capacity: values.count)
        data.initialize(from: values, count: values.count)
        cleanups.append {
            data.deinitialize(count: values.count)
            data.deallocate()
        }
        return data
    }

    func auditToken(_ marker: UInt8) -> audit_token_t {
        var token = make(audit_token_t.self).pointee
        withUnsafeMutableBytes(of: &token) { $0[0] = marker }
        return token
    }

    func acl() -> acl_t {
        let value = acl_init(1)!
        cleanups.append { acl_free(.init(value)) }
        return value
    }

    func file(_ path: String) -> UnsafeMutablePointer<es_file_t> {
        let value = make(es_file_t.self)
        value.pointee.path = string(path)
        value.pointee.path_truncated = true
        value.pointee.stat.st_ino = 42
        return value
    }

    func process(_ path: String) -> UnsafeMutablePointer<es_process_t> {
        let value = make(es_process_t.self)
        value.pointee.audit_token = auditToken(1)
        value.pointee.ppid = 11
        value.pointee.original_ppid = 12
        value.pointee.group_id = 13
        value.pointee.session_id = 14
        value.pointee.codesigning_flags = 15
        value.pointee.is_platform_binary = true
        value.pointee.is_es_client = true
        value.pointee.signing_id = string("signing.id")
        value.pointee.team_id = string("team.id")
        withUnsafeMutableBytes(of: &value.pointee.cdhash) { $0[0] = 0xAB }
        value.pointee.executable = file(path)
        return value
    }

    func launchItem() -> UnsafeMutablePointer<es_btm_launch_item_t> {
        let value = make(es_btm_launch_item_t.self)
        value.pointee.item_type = ES_BTM_ITEM_TYPE_APP
        value.pointee.legacy = true
        value.pointee.managed = true
        value.pointee.uid = 42
        value.pointee.item_url = string("file:///item")
        value.pointee.app_url = string("file:///app")
        return value
    }

    func profile() -> UnsafeMutablePointer<es_profile_t> {
        let value = make(es_profile_t.self)
        value.pointee.identifier = string("profile.id")
        value.pointee.uuid = string("profile-uuid")
        value.pointee.install_source = ES_PROFILE_SOURCE_MANAGED
        value.pointee.organization = string("organization")
        value.pointee.display_name = string("display name")
        value.pointee.scope = string("system")
        return value
    }

    func member() -> UnsafeMutablePointer<es_od_member_id_t> {
        let value = make(es_od_member_id_t.self)
        value.pointee.member_type = ES_OD_MEMBER_TYPE_USER_NAME
        value.pointee.member_value.name = string("member")
        return value
    }

    func members() -> UnsafeMutablePointer<es_od_member_id_array_t> {
        let value = make(es_od_member_id_array_t.self)
        value.pointee.member_type = ES_OD_MEMBER_TYPE_USER_NAME
        return value
    }
}

struct ESConverterTests {
    @Test
    func message() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_message_t.self)
        es.pointee.version = 4
        es.pointee.time.tv_sec = 101
        es.pointee.time.tv_nsec = 102
        es.pointee.mach_time = 103
        es.pointee.deadline = 104
        es.pointee.process = fixture.process("/sender")
        es.pointee.seq_num = 105
        es.pointee.action_type = ES_ACTION_TYPE_AUTH
        es.pointee.event_type = ES_EVENT_TYPE_NOTIFY_EXIT
        es.pointee.event.exit.stat = 42
        es.pointee.thread = fixture.make(es_thread_t.self)
        es.pointee.thread?.pointee.thread_id = 106
        es.pointee.global_seq_num = 107

        let result = try ESConverter.esMessage(es.pointee, config: .default)
        #expect(result.version == 4)
        #expect(result.time.tv_sec == 101)
        #expect(result.time.tv_nsec == 102)
        #expect(result.machTime == 103)
        #expect(result.deadline == 104)
        #expect(result.process.executable.path == "/sender")
        #expect(result.seqNum == 105)
        #expect(result.action == .auth)
        #expect(result.event == .exit(.init(status: 42)))
        #expect(result.eventType == ES_EVENT_TYPE_NOTIFY_EXIT)
        #expect(result.thread?.threadID == 106)
        #expect(result.globalSeqNum == 107)
    }

    @Test
    func string() {
        let fixture = ESConverterFixture()
        let result = ESConverter(version: 1).esString(fixture.string("value"))
        #expect(result == "value")
    }

    @Test
    func optionalString() {
        let fixture = ESConverterFixture()
        let converter = ESConverter(version: 1)
        let absent = fixture.make(es_string_token_t.self).pointee
        #expect(converter.esStringOptional(absent) == nil)
        #expect(converter.esStringOptional(fixture.string("")) == "")
    }

    @Test
    func token() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_token_t.self)
        es.pointee.size = 3
        es.pointee.data = fixture.bytes([1, 2, 3])
        #expect(ESConverter(version: 1).esToken(es.pointee) == Data([1, 2, 3]))
    }

    @Test
    func file_value() {
        let fixture = ESConverterFixture()
        let file = fixture.file("/value")
        let result = ESConverter(version: 1).esFile(file.pointee)
        #expect(result.path == "/value")
        #expect(result.truncated)
        #expect(result.stat.st_ino == 42)
    }

    @Test
    func file_pointer() {
        let fixture = ESConverterFixture()
        #expect(ESConverter(version: 1).esFile(fixture.file("/pointer")).path == "/pointer")
    }

    @Test
    func process_value() {
        let fixture = ESConverterFixture()
        let process = fixture.process("/process")
        let result = ESConverter(version: 1).esProcess(process.pointee)
        #expect(withUnsafeBytes(of: result.auditToken) { $0[0] } == 1)
        #expect(result.ppid == 11)
        #expect(result.originalPpid == 12)
        #expect(result.groupID == 13)
        #expect(result.sessionID == 14)
        #expect(result.codesigningFlags == 15)
        #expect(result.isPlatformBinary)
        #expect(result.isESClient)
        #expect(result.cdHash.first == 0xAB)
        #expect(result.signingID == "signing.id")
        #expect(result.teamID == "team.id")
        #expect(result.executable.path == "/process")
        #expect(result.tty == nil)
        #expect(result.startTime == nil)
        #expect(result.responsibleAuditToken == nil)
        #expect(result.parentAuditToken == nil)
        #expect(result.csValidationCategory == nil)
        #expect(result.cdHashFull == nil)
    }

    @Test
    func process_pointer() {
        let fixture = ESConverterFixture()
        #expect(ESConverter(version: 1).esProcess(fixture.process("/pointer")).executable.path == "/pointer")
    }

    @Test
    func process_versionedFields() {
        let fixture = ESConverterFixture()
        let process = fixture.process("/process")
        process.pointee.tty = fixture.file("/tty")
        process.pointee.start_time.tv_sec = 108
        process.pointee.responsible_audit_token = fixture.auditToken(9)
        process.pointee.parent_audit_token = fixture.auditToken(10)
        process.pointee.cs_validation_category = ES_CS_VALIDATION_CATEGORY_DEVELOPER_ID
#if compiler(>=6.4)
        process.pointee.cdhash_full.size = 3
        process.pointee.cdhash_full.data = fixture.bytes([1, 2, 3])
#endif

        let result = ESConverter(version: 11).esProcess(process.pointee)
        #expect(result.tty?.path == "/tty")
        #expect(result.startTime?.tv_sec == 108)
        #expect(result.responsibleAuditToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 9)
        #expect(result.parentAuditToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 10)
        #expect(result.csValidationCategory == ES_CS_VALIDATION_CATEGORY_DEVELOPER_ID)
#if compiler(>=6.4)
        #expect(result.cdHashFull == Data([1, 2, 3]))
#endif
    }

    @Test
    func instigator() {
        let fixture = ESConverterFixture()
        let converter = ESConverter(version: 1)
        #expect(converter.esInstigator(nil) == nil)
        #expect(converter.esInstigator(fixture.process("/instigator"))?.executable.path == "/instigator")
    }

    @Test
    func thread() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_thread_t.self)
        es.pointee.thread_id = 42
        #expect(ESConverter(version: 1).esThread(es.pointee).threadID == 42)
    }

    @Test
    func threadState() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_thread_state_t.self)
        es.pointee.flavor = 42
        es.pointee.state.size = 2
        es.pointee.state.data = fixture.bytes([4, 2])
        let result = ESConverter(version: 1).esThreadState(es.pointee)
        #expect(result.flavor == 42)
        #expect(result.state == Data([4, 2]))
    }

    @Test
    func signedFileInfo() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_signed_file_info_t.self)
        es.pointee.team_id = fixture.string("team")
        es.pointee.signing_id = fixture.string("signing")
        withUnsafeMutableBytes(of: &es.pointee.cdhash) { $0[0] = 0xCD }
        let result = ESConverter(version: 1).esSignedFileInfo(es.pointee)
        #expect(result.cdHash.first == 0xCD)
        #expect(result.teamID == "team")
        #expect(result.signingID == "signing")
    }

    @Test
    func authResult() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_result_t.self)
        es.pointee.result_type = ES_RESULT_TYPE_FLAGS
        es.pointee.result.flags = 42
        #expect(try ESConverter(version: 1).esAuthResult(es.pointee) == .flags(42))
    }

    @Test
    func authResult_authorization() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_result_t.self)
        es.pointee.result_type = ES_RESULT_TYPE_AUTH
        es.pointee.result.auth = ES_AUTH_RESULT_ALLOW
        #expect(try ESConverter(version: 1).esAuthResult(es.pointee) == .auth(true))
        es.pointee.result.auth = ES_AUTH_RESULT_DENY
        #expect(try ESConverter(version: 1).esAuthResult(es.pointee) == .auth(false))
    }

    @Test
    func action() throws {
        let fixture = ESConverterFixture()
        let action = fixture.make(es_message_t.__Unnamed_union_action.self)
        #expect(try ESConverter(version: 1).esAction(ES_ACTION_TYPE_AUTH, action.pointee) == .auth)
    }

    @Test
    func action_notify() throws {
        let fixture = ESConverterFixture()
        let action = fixture.make(es_message_t.__Unnamed_union_action.self)
        action.pointee.notify.result_type = ES_RESULT_TYPE_FLAGS
        action.pointee.notify.result.flags = 7
        #expect(try ESConverter(version: 1).esAction(ES_ACTION_TYPE_NOTIFY, action.pointee) == .notify(.flags(7)))
    }

    @Test
    func launchItem() {
        let fixture = ESConverterFixture()
        let item = fixture.launchItem()
        let result = ESConverter(version: 1).esBTMLaunchItem(item)
        #expect(result.itemType == ES_BTM_ITEM_TYPE_APP)
        #expect(result.legacy)
        #expect(result.managed)
        #expect(result.uid == 42)
        #expect(result.itemURL == "file:///item")
        #expect(result.appURL == "file:///app")
        item.pointee.app_url = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 1).esBTMLaunchItem(item).appURL == nil)
    }

    @Test
    func profile() {
        let fixture = ESConverterFixture()
        let result = ESConverter(version: 1).esProfile(fixture.profile().pointee)
        #expect(result.identifier == "profile.id")
        #expect(result.uuid == "profile-uuid")
        #expect(result.installSource == ES_PROFILE_SOURCE_MANAGED)
        #expect(result.organization == "organization")
        #expect(result.displayName == "display name")
        #expect(result.scope == "system")
    }

    @Test
    func memberID() throws {
        let fixture = ESConverterFixture()
        #expect(try ESConverter(version: 1).esODMemberID(fixture.member()) == .userName("member"))
    }

    @Test
    func memberID_uuid() throws {
        let fixture = ESConverterFixture()
        let member = fixture.member()
        var uuid = fixture.make(uuid_t.self).pointee
        withUnsafeMutableBytes(of: &uuid) { $0[0] = 1 }
        member.pointee.member_value.uuid = uuid
        member.pointee.member_type = ES_OD_MEMBER_TYPE_USER_UUID
        #expect(try ESConverter(version: 1).esODMemberID(member) == .userUUID(UUID(uuidString: "01000000-0000-0000-0000-000000000000")!))
        member.pointee.member_type = ES_OD_MEMBER_TYPE_GROUP_UUID
        #expect(try ESConverter(version: 1).esODMemberID(member) == .groupUUID(UUID(uuidString: "01000000-0000-0000-0000-000000000000")!))
    }

    @Test
    func memberIDs() throws {
        let fixture = ESConverterFixture()
        let es = fixture.members()
        let names = fixture.make(es_string_token_t.self)
        names.pointee = fixture.string("member")
        es.pointee.member_count = 1
        es.pointee.member_array.names = names
        #expect(try ESConverter(version: 1).esODMemberIDs(es) == [.userName("member")])
    }

    @Test
    func memberIDs_uuid() throws {
        let fixture = ESConverterFixture()
        let members = fixture.members()
        var uuid = fixture.make(uuid_t.self).pointee
        withUnsafeMutableBytes(of: &uuid) { $0[0] = 1 }
        members.pointee.member_count = 1
        members.pointee.member_array.uuids = fixture.array([uuid])
        members.pointee.member_type = ES_OD_MEMBER_TYPE_USER_UUID
        #expect(try ESConverter(version: 1).esODMemberIDs(members) == [.userUUID(UUID(uuidString: "01000000-0000-0000-0000-000000000000")!)])
        members.pointee.member_type = ES_OD_MEMBER_TYPE_GROUP_UUID
        #expect(try ESConverter(version: 1).esODMemberIDs(members) == [.groupUUID(UUID(uuidString: "01000000-0000-0000-0000-000000000000")!)])
    }

    @Test
    func eventDispatch() throws {
        let fixture = ESConverterFixture()
        let events = fixture.make(es_events_t.self)
        events.pointee.exit.stat = 42
        #expect(try ESConverter(version: 1).esEvent(ES_EVENT_TYPE_NOTIFY_EXIT, events.pointee) == .exit(.init(status: 42)))
    }

#if compiler(>=6.4)
    @Test
    func lightweightCodeRequirement() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_lightweight_code_requirement_t.self)
        es.pointee.team_id = fixture.string("team")
        es.pointee.signing_id = fixture.string("signing")
        let result = ESConverter(version: 1).esLightweightCodeRequirement(es.pointee)
        #expect(result.teamID == "team")
        #expect(result.signingID == "signing")
    }
#endif

    @Test
    func access() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_access_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.mode = 7
        let result = ESConverter(version: 1).esEvent(access: es.pointee)
        #expect(result.mode == 7)
        #expect(result.target.path == "/target")
    }

    @Test
    func chdir() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_chdir_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(chdir: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func chroot() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_chroot_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(chroot: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func clone() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_clone_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.target_dir = fixture.file("/target_dir")
        es.pointee.target_name = fixture.string("clone-value")
        let result = ESConverter(version: 1).esEvent(clone: es.pointee)
        #expect(result.source.path == "/source")
        #expect(result.targetDir.path == "/target_dir")
        #expect(result.targetName == "clone-value")
    }

    @Test
    func copyfile() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_copyfile_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.target_dir = fixture.file("/target_dir")
        es.pointee.target_name = fixture.string("copyfile-value")
        es.pointee.target_file = fixture.file("/existing")
        es.pointee.mode = 0o640
        es.pointee.flags = 7
        let result = ESConverter(version: 1).esEvent(copyfile: es.pointee)
        #expect(result.source.path == "/source")
        #expect(result.targetFile?.path == "/existing")
        #expect(result.targetDir.path == "/target_dir")
        #expect(result.targetName == "copyfile-value")
        #expect(result.mode == 0o640)
        #expect(result.flags == 7)
        es.pointee.target_file = nil
        #expect(ESConverter(version: 1).esEvent(copyfile: es.pointee).targetFile == nil)
    }

    @Test
    func close() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_close_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.modified = true
        let result = ESConverter(version: 1).esEvent(close: es.pointee)
        #expect(result.modified)
        #expect(result.target.path == "/target")
        #expect(result.wasMappedWritable == nil)
    }

    @Test
    func close_versionedFields() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_close_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.was_mapped_writable = true
        let result = ESConverter(version: 6).esEvent(close: es.pointee)
        #expect(result.wasMappedWritable == true)
    }

    @Test
    func create() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_create_t.self)
        es.pointee.destination_type = ES_DESTINATION_TYPE_NEW_PATH
        es.pointee.destination.new_path.dir = fixture.file("/directory")
        es.pointee.destination.new_path.filename = fixture.string("created")
        es.pointee.destination.new_path.mode = 0o640
        let result = try ESConverter(version: 1).esEvent(create: es.pointee)
        if case let .newPath(dir, filename, mode) = result.destination {
            #expect(dir.path == "/directory")
            #expect(filename == "created")
            #expect(mode == 0o640)
        } else {
            Issue.record("Expected a new-path destination")
        }
        #expect(result.acl == nil)
    }

    @Test
    func create_existingFileAndACL() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_create_t.self)
        es.pointee.destination_type = ES_DESTINATION_TYPE_EXISTING_FILE
        es.pointee.destination.existing_file = fixture.file("/existing")
        es.pointee.acl = fixture.acl()
        let result = try ESConverter(version: 2).esEvent(create: es.pointee)
        if case let .existingFile(file) = result.destination {
            #expect(file.path == "/existing")
        } else {
            Issue.record("Expected an existing-file destination")
        }
        #expect(result.acl != nil)
    }

    @Test
    func deleteextattr() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_deleteextattr_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.extattr = fixture.string("deleteextattr-value")
        let result = ESConverter(version: 1).esEvent(deleteextattr: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.extattr == "deleteextattr-value")
    }

    @Test
    func dup() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_dup_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(dup: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func exchangedata() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_exchangedata_t.self)
        es.pointee.file1 = fixture.file("/file1")
        es.pointee.file2 = fixture.file("/file2")
        let result = ESConverter(version: 1).esEvent(exchangedata: es.pointee)
        #expect(result.file1.path == "/file1")
        #expect(result.file2.path == "/file2")
    }

    @Test
    func exec() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_exec_t.self)
        es.pointee.target = fixture.process("/target")
        let result = ESConverter(version: 1).esEvent(exec: es.pointee)
        #expect(result.target.executable.path == "/target")
        #expect(result.script == nil)
        #expect(result.cwd == nil)
        #expect(result.lastFD == nil)
        #expect(result.imageCPUType == nil)
        #expect(result.imageCPUSubtype == nil)
        #expect(result.dyldExecPath == nil)
        #expect(result.args == nil)
        #expect(result.env == nil)
    }

    @Test
    func exec_versionedFields() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_exec_t.self)
        es.pointee.target = fixture.process("/target")
        es.pointee.script = fixture.file("/script")
        es.pointee.cwd = fixture.file("/cwd")
        es.pointee.last_fd = 40
        es.pointee.image_cputype = 41
        es.pointee.image_cpusubtype = 42
        es.pointee.dyld_exec_path = fixture.string("/dyld")
        let result = ESConverter(version: 7).esEvent(exec: es.pointee)
        #expect(result.script?.path == "/script")
        #expect(result.cwd?.path == "/cwd")
        #expect(result.lastFD == 40)
        #expect(result.imageCPUType == 41)
        #expect(result.imageCPUSubtype == 42)
        #expect(result.dyldExecPath == "/dyld")
    }

    @Test
    func exec_configuredArrays() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_exec_t.self)
        es.pointee.target = fixture.process("/target")
        let result = ESConverter(version: 1, config: .full).esEvent(exec: es.pointee)
        #expect(result.args == [])
        #expect(result.env == [])
    }

    @Test
    func exit() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_exit_t.self)
        es.pointee.stat = 42
        let result = ESConverter(version: 1).esEvent(exit: es.pointee)
        #expect(result.status == 42)
    }

    @Test
    func file_provider_materialize() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_file_provider_materialize_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.target = fixture.file("/target")
        es.pointee.instigator = fixture.process("/instigator")
        let result = ESConverter(version: 1).esEvent(file_provider_materialize: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken == nil)
        #expect(result.source.path == "/source")
        #expect(result.target.path == "/target")
    }

    @Test
    func file_provider_materialize_versionedToken() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_file_provider_materialize_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.target = fixture.file("/target")
        es.pointee.instigator_token = fixture.auditToken(19)
        let result = ESConverter(version: 8).esEvent(file_provider_materialize: es.pointee)
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 19)
    }

    @Test
    func file_provider_update() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_file_provider_update_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.target_path = fixture.string("file_provider_update-value")
        let result = ESConverter(version: 1).esEvent(file_provider_update: es.pointee)
        #expect(result.source.path == "/source")
        #expect(result.targetPath == "file_provider_update-value")
    }

    @Test
    func fcntl() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_fcntl_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.cmd = 7
        let result = ESConverter(version: 1).esEvent(fcntl: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.cmd == 7)
    }

    @Test
    func fork() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_fork_t.self)
        es.pointee.child = fixture.process("/child")
        let result = ESConverter(version: 1).esEvent(fork: es.pointee)
        #expect(result.child.executable.path == "/child")
    }

    @Test
    func fsgetpath() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_fsgetpath_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(fsgetpath: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func get_task() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_get_task_t.self)
        es.pointee.target = fixture.process("/target")
        es.pointee.type = ES_GET_TASK_TYPE_TASK_FOR_PID
        let result = ESConverter(version: 5).esEvent(get_task: es.pointee)
        #expect(result.target.executable.path == "/target")
        #expect(result.type == ES_GET_TASK_TYPE_TASK_FOR_PID)
    }

    @Test
    func get_task_read() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_get_task_read_t.self)
        es.pointee.target = fixture.process("/target")
        es.pointee.type = ES_GET_TASK_TYPE_EXPOSE_TASK
        let result = ESConverter(version: 5).esEvent(get_task_read: es.pointee)
        #expect(result.target.executable.path == "/target")
        #expect(result.type == ES_GET_TASK_TYPE_EXPOSE_TASK)
    }

    @Test
    func get_task_inspect() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_get_task_inspect_t.self)
        es.pointee.target = fixture.process("/target")
        es.pointee.type = ES_GET_TASK_TYPE_IDENTITY_TOKEN
        let result = ESConverter(version: 5).esEvent(get_task_inspect: es.pointee)
        #expect(result.target.executable.path == "/target")
        #expect(result.type == ES_GET_TASK_TYPE_IDENTITY_TOKEN)
    }

    @Test
    func get_task_name() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_get_task_name_t.self)
        es.pointee.target = fixture.process("/target")
        es.pointee.type = ES_GET_TASK_TYPE_TASK_FOR_PID
        let result = ESConverter(version: 5).esEvent(get_task_name: es.pointee)
        #expect(result.target.executable.path == "/target")
        #expect(result.type == ES_GET_TASK_TYPE_TASK_FOR_PID)
    }

    @Test
    func getattrlist() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_getattrlist_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.attrlist.commonattr = 7
        let result = ESConverter(version: 1).esEvent(getattrlist: es.pointee)
        #expect(result.attrlist.commonattr == 7)
        #expect(result.target.path == "/target")
    }

    @Test
    func getextattr() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_getextattr_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.extattr = fixture.string("getextattr-value")
        let result = ESConverter(version: 1).esEvent(getextattr: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.extattr == "getextattr-value")
    }

    @Test
    func iokit_open() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_iokit_open_t.self)
        es.pointee.user_client_class = fixture.string("iokit_open-value")
        es.pointee.user_client_type = 7
        let result = ESConverter(version: 1).esEvent(iokit_open: es.pointee)
        #expect(result.userClientType == 7)
        #expect(result.userClientClass == "iokit_open-value")
        #expect(result.parentRegistryID == nil)
        #expect(result.parentPath == nil)
    }

    @Test
    func iokit_open_versionedFields() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_iokit_open_t.self)
        es.pointee.parent_registry_id = 54
        es.pointee.parent_path = fixture.string("/IORegistry/parent")
        let result = ESConverter(version: 10).esEvent(iokit_open: es.pointee)
        #expect(result.parentRegistryID == 54)
        #expect(result.parentPath == "/IORegistry/parent")
    }

    @Test
    func kextload() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_kextload_t.self)
        es.pointee.identifier = fixture.string("kextload-value")
        let result = ESConverter(version: 1).esEvent(kextload: es.pointee)
        #expect(result.identifier == "kextload-value")
    }

    @Test
    func kextunload() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_kextunload_t.self)
        es.pointee.identifier = fixture.string("kextunload-value")
        let result = ESConverter(version: 1).esEvent(kextunload: es.pointee)
        #expect(result.identifier == "kextunload-value")
    }

    @Test
    func link() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_link_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.target_dir = fixture.file("/target_dir")
        es.pointee.target_filename = fixture.string("link-value")
        let result = ESConverter(version: 1).esEvent(link: es.pointee)
        #expect(result.source.path == "/source")
        #expect(result.targetDir.path == "/target_dir")
        #expect(result.targetFilename == "link-value")
    }

    @Test
    func listextattr() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_listextattr_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(listextattr: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func lookup() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_lookup_t.self)
        es.pointee.source_dir = fixture.file("/source_dir")
        es.pointee.relative_target = fixture.string("lookup-value")
        let result = ESConverter(version: 1).esEvent(lookup: es.pointee)
        #expect(result.sourceDir.path == "/source_dir")
        #expect(result.relativeTarget == "lookup-value")
    }

    @Test
    func mmap() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_mmap_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.protection = 1
        es.pointee.max_protection = 2
        es.pointee.flags = 3
        es.pointee.file_pos = 4
        let result = ESConverter(version: 1).esEvent(mmap: es.pointee)
        #expect(result.protection == 1)
        #expect(result.maxProtection == 2)
        #expect(result.flags == 3)
        #expect(result.filePos == 4)
        #expect(result.source.path == "/source")
    }

    @Test
    func mount() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_mount_t.self)
        es.pointee.statfs = fixture.make(statfs.self)
        es.pointee.statfs.pointee.f_flags = 42
        let result = ESConverter(version: 1).esEvent(mount: es.pointee)
        #expect(result.statfs.f_flags == 42)
        #expect(result.disposition == nil)
    }

    @Test
    func mount_versionedDisposition() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_mount_t.self)
        es.pointee.statfs = fixture.make(statfs.self)
        es.pointee.disposition = ES_MOUNT_DISPOSITION_NETWORK
        let result = ESConverter(version: 8).esEvent(mount: es.pointee)
        #expect(result.disposition == ES_MOUNT_DISPOSITION_NETWORK)
    }

    @Test
    func mprotect() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_mprotect_t.self)
        es.pointee.protection = 42
        es.pointee.address = 0x1000
        es.pointee.size = 4096
        let result = ESConverter(version: 1).esEvent(mprotect: es.pointee)
        #expect(result.protection == 42)
        #expect(result.address == 0x1000)
        #expect(result.size == 4096)
    }

    @Test
    func open() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_open_t.self)
        es.pointee.file = fixture.file("/file")
        es.pointee.fflag = 7
        let result = ESConverter(version: 1).esEvent(open: es.pointee)
        #expect(result.fflag == 7)
        #expect(result.file.path == "/file")
    }

    @Test
    func proc_check() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_proc_check_t.self)
        es.pointee.flavor = 42
        es.pointee.target = fixture.process("/target")
        es.pointee.type = ES_PROC_CHECK_TYPE_PIDINFO
        let result = ESConverter(version: 1).esEvent(proc_check: es.pointee)
        #expect(result.target?.executable.path == "/target")
        #expect(result.type == ES_PROC_CHECK_TYPE_PIDINFO)
        #expect(result.flavor == 42)
        es.pointee.target = nil
        #expect(ESConverter(version: 1).esEvent(proc_check: es.pointee).target == nil)
    }

    @Test
    func proc_suspend_resume() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_proc_suspend_resume_t.self)
        es.pointee.target = fixture.process("/target-process")
        es.pointee.type = ES_PROC_SUSPEND_RESUME_TYPE_SUSPEND
        let result = ESConverter(version: 1).esEvent(proc_suspend_resume: es.pointee)
        #expect(result.target?.executable.path == "/target-process")
        #expect(result.type == ES_PROC_SUSPEND_RESUME_TYPE_SUSPEND)
        es.pointee.target = nil
        #expect(ESConverter(version: 1).esEvent(proc_suspend_resume: es.pointee).target == nil)
    }

    @Test
    func pty_close() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_pty_close_t.self)
        es.pointee.dev = 42
        let result = ESConverter(version: 1).esEvent(pty_close: es.pointee)
        #expect(result.dev == 42)
    }

    @Test
    func pty_grant() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_pty_grant_t.self)
        es.pointee.dev = 42
        let result = ESConverter(version: 1).esEvent(pty_grant: es.pointee)
        #expect(result.dev == 42)
    }

    @Test
    func readdir() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_readdir_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(readdir: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func readlink() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_readlink_t.self)
        es.pointee.source = fixture.file("/source")
        let result = ESConverter(version: 1).esEvent(readlink: es.pointee)
        #expect(result.source.path == "/source")
    }

    @Test
    func remote_thread_create() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_remote_thread_create_t.self)
        es.pointee.target = fixture.process("/target")
        let threadState = fixture.make(es_thread_state_t.self)
        threadState.pointee.flavor = 7
        es.pointee.thread_state = threadState
        let result = ESConverter(version: 1).esEvent(remote_thread_create: es.pointee)
        #expect(result.target.executable.path == "/target")
        #expect(result.threadState?.flavor == 7)
        #expect(result.threadState?.state == Data())
        es.pointee.thread_state = nil
        #expect(ESConverter(version: 1).esEvent(remote_thread_create: es.pointee).threadState == nil)
    }

    @Test
    func remount() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_remount_t.self)
        es.pointee.statfs = fixture.make(statfs.self)
        es.pointee.statfs.pointee.f_flags = 42
        let result = ESConverter(version: 1).esEvent(remount: es.pointee)
        #expect(result.statfs.f_flags == 42)
        #expect(result.remountFlags == nil)
        #expect(result.disposition == nil)
    }

    @Test
    func remount_versionedFields() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_remount_t.self)
        es.pointee.statfs = fixture.make(statfs.self)
        es.pointee.remount_flags = 0x1234
        es.pointee.disposition = ES_MOUNT_DISPOSITION_VIRTUAL
        let result = ESConverter(version: 8).esEvent(remount: es.pointee)
        #expect(result.remountFlags == 0x1234)
        #expect(result.disposition == ES_MOUNT_DISPOSITION_VIRTUAL)
    }

    @Test
    func rename() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_rename_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.destination_type = ES_DESTINATION_TYPE_NEW_PATH
        es.pointee.destination.new_path.dir = fixture.file("/directory")
        es.pointee.destination.new_path.filename = fixture.string("renamed")
        let result = try ESConverter(version: 1).esEvent(rename: es.pointee)
        #expect(result.source.path == "/source")
        if case let .newPath(dir, filename) = result.destination {
            #expect(dir.path == "/directory")
            #expect(filename == "renamed")
        } else {
            Issue.record("Expected a new-path destination")
        }
    }

    @Test
    func rename_existingFile() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_rename_t.self)
        es.pointee.source = fixture.file("/source")
        es.pointee.destination_type = ES_DESTINATION_TYPE_EXISTING_FILE
        es.pointee.destination.existing_file = fixture.file("/existing")
        let result = try ESConverter(version: 1).esEvent(rename: es.pointee)
        if case let .existingFile(file) = result.destination {
            #expect(file.path == "/existing")
        } else {
            Issue.record("Expected an existing-file destination")
        }
    }

    @Test
    func searchfs() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_searchfs_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.attrlist.fileattr = 7
        let result = ESConverter(version: 1).esEvent(searchfs: es.pointee)
        #expect(result.attrlist.fileattr == 7)
        #expect(result.target.path == "/target")
    }

    @Test
    func setacl() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setacl_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.set_or_clear = ES_CLEAR
        let result = ESConverter(version: 1).esEvent(setacl: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.setOrClear == ES_CLEAR)
        #expect(result.acl == nil)
    }

    @Test
    func setacl_withACL() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setacl_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.set_or_clear = ES_SET
        es.pointee.acl.set = fixture.acl()
        let result = ESConverter(version: 1).esEvent(setacl: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.setOrClear == ES_SET)
        #expect(result.acl != nil)
    }

    @Test
    func setattrlist() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setattrlist_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.attrlist.dirattr = 7
        let result = ESConverter(version: 1).esEvent(setattrlist: es.pointee)
        #expect(result.attrlist.dirattr == 7)
        #expect(result.target.path == "/target")
    }

    @Test
    func setextattr() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setextattr_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.extattr = fixture.string("setextattr-value")
        let result = ESConverter(version: 1).esEvent(setextattr: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.extattr == "setextattr-value")
    }

    @Test
    func setflags() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setflags_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.flags = 7
        let result = ESConverter(version: 1).esEvent(setflags: es.pointee)
        #expect(result.flags == 7)
        #expect(result.target.path == "/target")
    }

    @Test
    func setmode() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setmode_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.mode = 0o640
        let result = ESConverter(version: 1).esEvent(setmode: es.pointee)
        #expect(result.mode == 0o640)
        #expect(result.target.path == "/target")
    }

    @Test
    func setowner() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setowner_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.uid = 41
        es.pointee.gid = 42
        let result = ESConverter(version: 1).esEvent(setowner: es.pointee)
        #expect(result.uid == 41)
        #expect(result.gid == 42)
        #expect(result.target.path == "/target")
    }

    @Test
    func setuid() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setuid_t.self)
        es.pointee.uid = 42
        let result = ESConverter(version: 1).esEvent(setuid: es.pointee)
        #expect(result.uid == 42)
    }

    @Test
    func setgid() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setgid_t.self)
        es.pointee.gid = 42
        let result = ESConverter(version: 1).esEvent(setgid: es.pointee)
        #expect(result.uid == 42)
    }

    @Test
    func seteuid() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_seteuid_t.self)
        es.pointee.euid = 42
        let result = ESConverter(version: 1).esEvent(seteuid: es.pointee)
        #expect(result.uid == 42)
    }

    @Test
    func setegid() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setegid_t.self)
        es.pointee.egid = 42
        let result = ESConverter(version: 1).esEvent(setegid: es.pointee)
        #expect(result.uid == 42)
    }

    @Test
    func setreuid() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setreuid_t.self)
        es.pointee.ruid = 42
        es.pointee.euid = 43
        let result = ESConverter(version: 1).esEvent(setreuid: es.pointee)
        #expect(result.ruid == 42)
        #expect(result.euid == 43)
    }

    @Test
    func setregid() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_setregid_t.self)
        es.pointee.rgid = 42
        es.pointee.egid = 43
        let result = ESConverter(version: 1).esEvent(setregid: es.pointee)
        #expect(result.ruid == 42)
        #expect(result.euid == 43)
    }

    @Test
    func signal() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_signal_t.self)
        es.pointee.target = fixture.process("/target")
        es.pointee.sig = 9
        let result = ESConverter(version: 1).esEvent(signal: es.pointee)
        #expect(result.sig == 9)
        #expect(result.target.executable.path == "/target")
        #expect(result.instigator == nil)
    }

    @Test
    func signal_versionedInstigator() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_signal_t.self)
        es.pointee.target = fixture.process("/target")
        es.pointee.instigator = fixture.process("/instigator")
        let result = ESConverter(version: 9).esEvent(signal: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
    }

    @Test
    func stat() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_stat_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(stat: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func trace() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_trace_t.self)
        es.pointee.target = fixture.process("/target")
        let result = ESConverter(version: 1).esEvent(trace: es.pointee)
        #expect(result.target.executable.path == "/target")
    }

    @Test
    func truncate() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_truncate_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(truncate: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func uipc_bind() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_uipc_bind_t.self)
        es.pointee.dir = fixture.file("/dir")
        es.pointee.filename = fixture.string("uipc_bind-value")
        es.pointee.mode = 0o640
        let result = ESConverter(version: 1).esEvent(uipc_bind: es.pointee)
        #expect(result.dir.path == "/dir")
        #expect(result.filename == "uipc_bind-value")
        #expect(result.mode == 0o640)
    }

    @Test
    func uipc_connect() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_uipc_connect_t.self)
        es.pointee.file = fixture.file("/file")
        es.pointee.domain = 1
        es.pointee.type = 2
        es.pointee.protocol = 3
        let result = ESConverter(version: 1).esEvent(uipc_connect: es.pointee)
        #expect(result.file.path == "/file")
        #expect(result.domain == 1)
        #expect(result.type == 2)
        #expect(result.protocol == 3)
    }

    @Test
    func unlink() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_unlink_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.parent_dir = fixture.file("/parent_dir")
        let result = ESConverter(version: 1).esEvent(unlink: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.parentDir.path == "/parent_dir")
    }

    @Test
    func unmount() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_unmount_t.self)
        es.pointee.statfs = fixture.make(statfs.self)
        es.pointee.statfs.pointee.f_flags = 42
        let result = ESConverter(version: 1).esEvent(unmount: es.pointee)
        #expect(result.statfs.f_flags == 42)
    }

    @Test
    func utimes() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_utimes_t.self)
        es.pointee.target = fixture.file("/target")
        es.pointee.atime.tv_sec = 41
        es.pointee.mtime.tv_sec = 42
        let result = ESConverter(version: 1).esEvent(utimes: es.pointee)
        #expect(result.target.path == "/target")
        #expect(result.aTime.tv_sec == 41)
        #expect(result.mTime.tv_sec == 42)
    }

    @Test
    func write() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_write_t.self)
        es.pointee.target = fixture.file("/target")
        let result = ESConverter(version: 1).esEvent(write: es.pointee)
        #expect(result.target.path == "/target")
    }

    @Test
    func authentication() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_authentication_t.self)
        es.pointee.type = ES_AUTHENTICATION_TYPE_AUTO_UNLOCK
        es.pointee.success = true
        es.pointee.data.auto_unlock = fixture.make(es_event_authentication_auto_unlock_t.self)
        es.pointee.data.auto_unlock.pointee.username = fixture.string("authenticated")
        es.pointee.data.auto_unlock.pointee.type = ES_AUTO_UNLOCK_AUTH_PROMPT
        let result = try ESConverter(version: 1).esEvent(authentication: es)
        #expect(result.success)
        if case let .autoUnlock(value) = result.type {
            #expect(value.username == "authenticated")
            #expect(value.type == ES_AUTO_UNLOCK_AUTH_PROMPT)
        } else {
            Issue.record("Expected auto-unlock authentication")
        }
    }

    @Test
    func authentication_od() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_authentication_t.self)
        es.pointee.type = ES_AUTHENTICATION_TYPE_OD
        let od = fixture.make(es_event_authentication_od_t.self)
        od.pointee.instigator = fixture.process("/instigator")
        od.pointee.instigator_token = fixture.auditToken(24)
        od.pointee.record_type = fixture.string("Users")
        od.pointee.record_name = fixture.string("alice")
        od.pointee.node_name = fixture.string("/Local/Default")
        od.pointee.db_path = fixture.string("/database")
        es.pointee.data.od = od
        let result = try ESConverter(version: 8).esEvent(authentication: es)
        #expect(!result.success)
        if case let .od(value) = result.type {
            #expect(value.instigator?.executable.path == "/instigator")
            #expect(value.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 24)
            #expect(value.recordType == "Users")
            #expect(value.recordName == "alice")
            #expect(value.nodeName == "/Local/Default")
            #expect(value.dbPath == "/database")
        } else {
            Issue.record("Expected OpenDirectory authentication")
        }
        od.pointee.instigator = nil
        od.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        let absent = try ESConverter(version: 1).esEvent(authentication: es)
        if case let .od(value) = absent.type {
            #expect(value.instigator == nil)
            #expect(value.instigatorToken == nil)
            #expect(value.dbPath == nil)
        } else {
            Issue.record("Expected OpenDirectory authentication")
        }
    }

    @Test
    func authentication_touchID() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_authentication_t.self)
        es.pointee.type = ES_AUTHENTICATION_TYPE_TOUCHID
        let touchID = fixture.make(es_event_authentication_touchid_t.self)
        touchID.pointee.instigator = fixture.process("/instigator")
        touchID.pointee.instigator_token = fixture.auditToken(25)
        touchID.pointee.touchid_mode = ES_TOUCHID_MODE_IDENTIFICATION
        touchID.pointee.has_uid = true
        touchID.pointee.uid.uid = 55
        es.pointee.data.touchid = touchID
        let result = try ESConverter(version: 8).esEvent(authentication: es)
        if case let .touchID(value) = result.type {
            #expect(value.instigator?.executable.path == "/instigator")
            #expect(value.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 25)
            #expect(value.touchIDMode == ES_TOUCHID_MODE_IDENTIFICATION)
            #expect(value.uid == 55)
        } else {
            Issue.record("Expected TouchID authentication")
        }
        touchID.pointee.has_uid = false
        let absent = try ESConverter(version: 1).esEvent(authentication: es)
        if case let .touchID(value) = absent.type {
            #expect(value.instigatorToken == nil)
            #expect(value.uid == nil)
        } else {
            Issue.record("Expected TouchID authentication")
        }
    }

    @Test
    func authentication_token() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_authentication_t.self)
        es.pointee.type = ES_AUTHENTICATION_TYPE_TOKEN
        let token = fixture.make(es_event_authentication_token_t.self)
        token.pointee.instigator = fixture.process("/instigator")
        token.pointee.instigator_token = fixture.auditToken(26)
        token.pointee.pubkey_hash = fixture.string("public-key-hash")
        token.pointee.token_id = fixture.string("token-id")
        token.pointee.kerberos_principal = fixture.string("principal")
        es.pointee.data.token = token
        let result = try ESConverter(version: 8).esEvent(authentication: es)
        if case let .token(value) = result.type {
            #expect(value.instigator?.executable.path == "/instigator")
            #expect(value.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 26)
            #expect(value.pubkeyHash == "public-key-hash")
            #expect(value.tokenID == "token-id")
            #expect(value.kerberosPrincipal == "principal")
        } else {
            Issue.record("Expected token authentication")
        }
        token.pointee.kerberos_principal = fixture.make(es_string_token_t.self).pointee
        let absent = try ESConverter(version: 1).esEvent(authentication: es)
        if case let .token(value) = absent.type {
            #expect(value.instigatorToken == nil)
            #expect(value.kerberosPrincipal == nil)
        } else {
            Issue.record("Expected token authentication")
        }
    }

    @Test
    func xpMalwareDetected() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_xp_malware_detected_t.self)
        es.pointee.signature_version = fixture.string("xpMalwareDetected-value")
        es.pointee.malware_identifier = fixture.string("malware")
        es.pointee.incident_identifier = fixture.string("incident")
        es.pointee.detected_path = fixture.string("/detected")
        let result = ESConverter(version: 1).esEvent(xpMalwareDetected: es)
        #expect(result.signatureVersion == "xpMalwareDetected-value")
        #expect(result.malwareIdentifier == "malware")
        #expect(result.incidentIdentifier == "incident")
        #expect(result.detectedPath == "/detected")
        #expect(result.detectedExecutable == nil)
    }

    @Test
    func xpMalwareDetected_versionedExecutable() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_xp_malware_detected_t.self)
        es.pointee.detected_executable = fixture.string("/executable")
        let result = ESConverter(version: 10).esEvent(xpMalwareDetected: es)
        #expect(result.detectedExecutable == "/executable")
    }

    @Test
    func xpMalwareRemediated() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_xp_malware_remediated_t.self)
        es.pointee.signature_version = fixture.string("xpMalwareRemediated-value")
        es.pointee.malware_identifier = fixture.string("malware")
        es.pointee.incident_identifier = fixture.string("incident")
        es.pointee.action_type = fixture.string("removed")
        es.pointee.success = true
        es.pointee.result_description = fixture.string("complete")
        es.pointee.remediated_path = fixture.string("/remediated")
        es.pointee.remediated_process_audit_token = fixture.make(audit_token_t.self)
        es.pointee.remediated_process_audit_token?.pointee = fixture.auditToken(7)
        let result = ESConverter(version: 1).esEvent(xpMalwareRemediated: es)
        #expect(result.signatureVersion == "xpMalwareRemediated-value")
        #expect(result.malwareIdentifier == "malware")
        #expect(result.incidentIdentifier == "incident")
        #expect(result.actionType == "removed")
        #expect(result.success)
        #expect(result.resultDescription == "complete")
        #expect(result.remediatedPath == "/remediated")
        #expect(result.remediatedProcessAuditToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 7)
        es.pointee.remediated_path = fixture.make(es_string_token_t.self).pointee
        es.pointee.remediated_process_audit_token = nil
        let absent = ESConverter(version: 1).esEvent(xpMalwareRemediated: es)
        #expect(absent.remediatedPath == nil)
        #expect(absent.remediatedProcessAuditToken == nil)
    }

    @Test
    func lwSessionLogin() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_lw_session_login_t.self)
        es.pointee.username = fixture.string("lwSessionLogin-value")
        es.pointee.graphical_session_id = 41
        let result = ESConverter(version: 1).esEvent(lwSessionLogin: es)
        #expect(result.username == "lwSessionLogin-value")
        #expect(result.graphicalSessionID == 41)
    }

    @Test
    func lwSessionLogout() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_lw_session_logout_t.self)
        es.pointee.username = fixture.string("lwSessionLogout-value")
        es.pointee.graphical_session_id = 42
        let result = ESConverter(version: 1).esEvent(lwSessionLogout: es)
        #expect(result.username == "lwSessionLogout-value")
        #expect(result.graphicalSessionID == 42)
    }

    @Test
    func lwSessionLock() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_lw_session_lock_t.self)
        es.pointee.username = fixture.string("lwSessionLock-value")
        es.pointee.graphical_session_id = 43
        let result = ESConverter(version: 1).esEvent(lwSessionLock: es)
        #expect(result.username == "lwSessionLock-value")
        #expect(result.graphicalSessionID == 43)
    }

    @Test
    func lwSessionUnlock() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_lw_session_unlock_t.self)
        es.pointee.username = fixture.string("lwSessionUnlock-value")
        es.pointee.graphical_session_id = 44
        let result = ESConverter(version: 1).esEvent(lwSessionUnlock: es)
        #expect(result.username == "lwSessionUnlock-value")
        #expect(result.graphicalSessionID == 44)
    }

    @Test
    func screensharingAttach() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_screensharing_attach_t.self)
        es.pointee.source_address = fixture.string("screensharingAttach-value")
        es.pointee.success = true
        es.pointee.source_address_type = ES_ADDRESS_TYPE_IPV4
        es.pointee.viewer_appleid = fixture.string("viewer@example.com")
        es.pointee.authentication_type = fixture.string("password")
        es.pointee.authentication_username = fixture.string("auth-user")
        es.pointee.session_username = fixture.string("session-user")
        es.pointee.existing_session = true
        es.pointee.graphical_session_id = 45
        let result = ESConverter(version: 1).esEvent(screensharingAttach: es)
        #expect(result.success)
        #expect(result.sourceAddressType == ES_ADDRESS_TYPE_IPV4)
        #expect(result.sourceAddress == "screensharingAttach-value")
        #expect(result.viewerAppleID == "viewer@example.com")
        #expect(result.authenticationType == "password")
        #expect(result.authenticationUsername == "auth-user")
        #expect(result.sessionUsername == "session-user")
        #expect(result.existingSession)
        #expect(result.graphicalSessionID == 45)
        let empty = fixture.make(es_string_token_t.self).pointee
        es.pointee.source_address = empty
        es.pointee.viewer_appleid = empty
        es.pointee.authentication_username = empty
        es.pointee.session_username = empty
        let absent = ESConverter(version: 1).esEvent(screensharingAttach: es)
        #expect(absent.sourceAddress == nil)
        #expect(absent.viewerAppleID == nil)
        #expect(absent.authenticationUsername == nil)
        #expect(absent.sessionUsername == nil)
    }

    @Test
    func screensharingDetach() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_screensharing_detach_t.self)
        es.pointee.source_address = fixture.string("screensharingDetach-value")
        es.pointee.source_address_type = ES_ADDRESS_TYPE_IPV6
        es.pointee.viewer_appleid = fixture.string("viewer@example.com")
        es.pointee.graphical_session_id = 46
        let result = ESConverter(version: 1).esEvent(screensharingDetach: es)
        #expect(result.sourceAddressType == ES_ADDRESS_TYPE_IPV6)
        #expect(result.sourceAddress == "screensharingDetach-value")
        #expect(result.viewerAppleID == "viewer@example.com")
        #expect(result.graphicalSessionID == 46)
        let empty = fixture.make(es_string_token_t.self).pointee
        es.pointee.source_address = empty
        es.pointee.viewer_appleid = empty
        let absent = ESConverter(version: 1).esEvent(screensharingDetach: es)
        #expect(absent.sourceAddress == nil)
        #expect(absent.viewerAppleID == nil)
    }

    @Test
    func opensshLogin() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_openssh_login_t.self)
        es.pointee.source_address = fixture.string("opensshLogin-value")
        es.pointee.success = true
        es.pointee.result_type = ES_OPENSSH_LOGIN_ROOT_DENIED
        es.pointee.source_address_type = ES_ADDRESS_TYPE_IPV4
        es.pointee.username = fixture.string("ssh-user")
        es.pointee.has_uid = true
        es.pointee.uid.uid = 47
        let result = ESConverter(version: 1).esEvent(opensshLogin: es)
        #expect(result.success)
        #expect(result.resultType == ES_OPENSSH_LOGIN_ROOT_DENIED)
        #expect(result.sourceAddressType == ES_ADDRESS_TYPE_IPV4)
        #expect(result.sourceAddress == "opensshLogin-value")
        #expect(result.username == "ssh-user")
        #expect(result.uid == 47)
        es.pointee.has_uid = false
        #expect(ESConverter(version: 1).esEvent(opensshLogin: es).uid == nil)
    }

    @Test
    func opensshLogout() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_openssh_logout_t.self)
        es.pointee.source_address = fixture.string("opensshLogout-value")
        es.pointee.source_address_type = ES_ADDRESS_TYPE_IPV6
        es.pointee.username = fixture.string("ssh-user")
        es.pointee.uid = 48
        let result = ESConverter(version: 1).esEvent(opensshLogout: es)
        #expect(result.sourceAddressType == ES_ADDRESS_TYPE_IPV6)
        #expect(result.sourceAddress == "opensshLogout-value")
        #expect(result.username == "ssh-user")
        #expect(result.uid == 48)
    }

    @Test
    func loginLogin() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_login_login_t.self)
        es.pointee.failure_message = fixture.string("loginLogin-value")
        es.pointee.success = true
        es.pointee.username = fixture.string("login-user")
        es.pointee.has_uid = true
        es.pointee.uid.uid = 49
        let result = ESConverter(version: 1).esEvent(loginLogin: es)
        #expect(result.success)
        #expect(result.failureMessage == "loginLogin-value")
        #expect(result.username == "login-user")
        #expect(result.uid == 49)
        es.pointee.failure_message = fixture.make(es_string_token_t.self).pointee
        es.pointee.has_uid = false
        let absent = ESConverter(version: 1).esEvent(loginLogin: es)
        #expect(absent.failureMessage == nil)
        #expect(absent.uid == nil)
    }

    @Test
    func loginLogout() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_login_logout_t.self)
        es.pointee.username = fixture.string("loginLogout-value")
        es.pointee.uid = 50
        let result = ESConverter(version: 1).esEvent(loginLogout: es)
        #expect(result.username == "loginLogout-value")
        #expect(result.uid == 50)
    }

    @Test
    func btmLaunchItemAdd() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_btm_launch_item_add_t.self)
        es.pointee.item = fixture.launchItem()
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.app = fixture.process("/app")
        es.pointee.executable_path = fixture.string("btmLaunchItemAdd-value")
        let result = ESConverter(version: 1).esEvent(btmLaunchItemAdd: es)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.app?.executable.path == "/app")
        #expect(result.item.itemURL == "file:///item")
        #expect(result.executablePath == "btmLaunchItemAdd-value")
        #expect(result.instigatorToken == nil)
        #expect(result.appToken == nil)
        es.pointee.instigator = nil
        es.pointee.app = nil
        es.pointee.executable_path = fixture.make(es_string_token_t.self).pointee
        let absent = ESConverter(version: 1).esEvent(btmLaunchItemAdd: es)
        #expect(absent.instigator == nil)
        #expect(absent.app == nil)
        #expect(absent.executablePath == nil)
    }

    @Test
    func btmLaunchItemAdd_versionedTokens() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_btm_launch_item_add_t.self)
        es.pointee.item = fixture.launchItem()
        es.pointee.instigator_token = fixture.make(audit_token_t.self)
        es.pointee.instigator_token?.pointee = fixture.auditToken(20)
        es.pointee.app_token = fixture.make(audit_token_t.self)
        es.pointee.app_token?.pointee = fixture.auditToken(21)
        let result = ESConverter(version: 8).esEvent(btmLaunchItemAdd: es)
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 20)
        #expect(result.appToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 21)
    }

    @Test
    func btmLaunchItemRemove() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_btm_launch_item_remove_t.self)
        es.pointee.item = fixture.launchItem()
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.app = fixture.process("/app")
        let result = ESConverter(version: 1).esEvent(btmLaunchItemRemove: es)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.app?.executable.path == "/app")
        #expect(result.item.itemURL == "file:///item")
        #expect(result.instigatorToken == nil)
        #expect(result.appToken == nil)
        es.pointee.instigator = nil
        es.pointee.app = nil
        let absent = ESConverter(version: 1).esEvent(btmLaunchItemRemove: es)
        #expect(absent.instigator == nil)
        #expect(absent.app == nil)
    }

    @Test
    func btmLaunchItemRemove_versionedTokens() {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_btm_launch_item_remove_t.self)
        es.pointee.item = fixture.launchItem()
        es.pointee.instigator_token = fixture.make(audit_token_t.self)
        es.pointee.instigator_token?.pointee = fixture.auditToken(22)
        es.pointee.app_token = fixture.make(audit_token_t.self)
        es.pointee.app_token?.pointee = fixture.auditToken(23)
        let result = ESConverter(version: 8).esEvent(btmLaunchItemRemove: es)
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 22)
        #expect(result.appToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 23)
    }

    @Test
    func profileAdd() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_profile_add_t.self)
        es.pointee.profile = fixture.profile()
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.is_update = true
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(profileAdd: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.isUpdate)
        #expect(result.profile.identifier == "profile.id")
    }

    @Test
    func profileRemove() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_profile_remove_t.self)
        es.pointee.profile = fixture.profile()
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(profileRemove: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.profile.identifier == "profile.id")
    }

    @Test
    func su() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_su_t.self)
        es.pointee.failure_message = fixture.string("su-value")
        es.pointee.success = true
        es.pointee.from_uid = 51
        es.pointee.from_username = fixture.string("from-user")
        es.pointee.has_to_uid = true
        es.pointee.to_uid.uid = 52
        es.pointee.to_username = fixture.string("to-user")
        es.pointee.shell = fixture.string("/bin/zsh")
        es.pointee.argc = 2
        es.pointee.argv = fixture.array([fixture.string("-l"), fixture.string("-c")])
        es.pointee.env_count = 1
        es.pointee.env = fixture.array([fixture.string("KEY=value")])
        let result = ESConverter(version: 1).esEvent(su: es.pointee)
        #expect(result.success)
        #expect(result.failureMessage == "su-value")
        #expect(result.fromUID == 51)
        #expect(result.fromUsername == "from-user")
        #expect(result.toUID == 52)
        #expect(result.toUsername == "to-user")
        #expect(result.shell == "/bin/zsh")
        #expect(result.args == ["-l", "-c"])
        #expect(result.env == ["KEY=value"])
        let empty = fixture.make(es_string_token_t.self).pointee
        es.pointee.failure_message = empty
        es.pointee.has_to_uid = false
        es.pointee.to_username = empty
        es.pointee.shell = empty
        let absent = ESConverter(version: 1).esEvent(su: es.pointee)
        #expect(absent.failureMessage == nil)
        #expect(absent.toUID == nil)
        #expect(absent.toUsername == nil)
        #expect(absent.shell == nil)
    }

    @Test
    func authorizationPetition() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_authorization_petition_t.self)
        es.pointee.flags = 42
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.petitioner = fixture.process("/petitioner")
        es.pointee.right_count = 2
        es.pointee.rights = fixture.array([fixture.string("right.one"), fixture.string("right.two")])
        es.pointee.instigator_token = fixture.auditToken(17)
        es.pointee.petitioner_token = fixture.auditToken(18)
        let result = ESConverter(version: 8).esEvent(authorizationPetition: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.petitioner?.executable.path == "/petitioner")
        #expect(result.petitionerToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 18)
        #expect(result.flags == 42)
        #expect(result.rights == ["right.one", "right.two"])
    }

    @Test
    func authorizationJudgement() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_authorization_judgement_t.self)
        es.pointee.return_code = 42
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.petitioner = fixture.process("/petitioner")
        let right = fixture.make(es_authorization_result_t.self)
        right.pointee.right_name = fixture.string("right.one")
        right.pointee.rule_class = ES_AUTHORIZATION_RULE_CLASS_ALLOW
        right.pointee.granted = true
        es.pointee.result_count = 1
        es.pointee.results = right
        es.pointee.instigator_token = fixture.auditToken(17)
        es.pointee.petitioner_token = fixture.auditToken(18)
        let result = ESConverter(version: 8).esEvent(authorizationJudgement: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.petitioner?.executable.path == "/petitioner")
        #expect(result.petitionerToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 18)
        #expect(result.returnCode == 42)
        #expect(result.results.count == 1)
        #expect(result.results.first?.rightName == "right.one")
        #expect(result.results.first?.ruleClass == ES_AUTHORIZATION_RULE_CLASS_ALLOW)
        #expect(result.results.first?.granted == true)
    }

    @Test
    func sudo() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_sudo_t.self)
        es.pointee.from_username = fixture.string("sudo-value")
        es.pointee.success = true
        let reject = fixture.make(es_sudo_reject_info_t.self)
        reject.pointee.plugin_name = fixture.string("policy")
        reject.pointee.plugin_type = ES_SUDO_PLUGIN_TYPE_POLICY
        reject.pointee.failure_message = fixture.string("rejected")
        es.pointee.reject_info = reject
        es.pointee.has_from_uid = true
        es.pointee.from_uid.uid = 53
        es.pointee.has_to_uid = true
        es.pointee.to_uid.uid = 54
        es.pointee.to_username = fixture.string("root")
        es.pointee.command = fixture.string("/usr/bin/id")
        let result = ESConverter(version: 1).esEvent(sudo: es.pointee)
        #expect(result.success)
        #expect(result.rejectInfo?.pluginName == "policy")
        #expect(result.rejectInfo?.pluginType == ES_SUDO_PLUGIN_TYPE_POLICY)
        #expect(result.rejectInfo?.failureMessage == "rejected")
        #expect(result.fromUID == 53)
        #expect(result.fromUsername == "sudo-value")
        #expect(result.toUID == 54)
        #expect(result.toUsername == "root")
        #expect(result.command == "/usr/bin/id")
        es.pointee.reject_info = nil
        es.pointee.has_from_uid = false
        es.pointee.has_to_uid = false
        let empty = fixture.make(es_string_token_t.self).pointee
        es.pointee.from_username = empty
        es.pointee.to_username = empty
        es.pointee.command = empty
        let absent = ESConverter(version: 1).esEvent(sudo: es.pointee)
        #expect(absent.rejectInfo == nil)
        #expect(absent.fromUID == nil)
        #expect(absent.fromUsername == nil)
        #expect(absent.toUID == nil)
        #expect(absent.toUsername == nil)
        #expect(absent.command == nil)
    }

    @Test
    func odGroupAdd() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_group_add_t.self)
        es.pointee.member = fixture.member()
        es.pointee.group_name = fixture.string("odGroupAdd-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 61
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = try ESConverter(version: 8).esEvent(odGroupAdd: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 61)
        #expect(result.groupName == "odGroupAdd-value")
        #expect(result.member == .userName("member"))
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(try ESConverter(version: 8).esEvent(odGroupAdd: es.pointee).dbPath == nil)
    }

    @Test
    func odGroupRemove() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_group_remove_t.self)
        es.pointee.member = fixture.member()
        es.pointee.group_name = fixture.string("odGroupRemove-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 62
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = try ESConverter(version: 8).esEvent(odGroupRemove: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 62)
        #expect(result.groupName == "odGroupRemove-value")
        #expect(result.member == .userName("member"))
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(try ESConverter(version: 8).esEvent(odGroupRemove: es.pointee).dbPath == nil)
    }

    @Test
    func odGroupSet() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_group_set_t.self)
        es.pointee.members = fixture.members()
        es.pointee.members.pointee.member_count = 1
        es.pointee.members.pointee.member_array.names = fixture.array([fixture.string("group-member")])
        es.pointee.group_name = fixture.string("odGroupSet-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 63
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = try ESConverter(version: 8).esEvent(odGroupSet: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 63)
        #expect(result.groupName == "odGroupSet-value")
        #expect(result.members == [.userName("group-member")])
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(try ESConverter(version: 8).esEvent(odGroupSet: es.pointee).dbPath == nil)
    }

    @Test
    func odModifyPassword() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_modify_password_t.self)
        es.pointee.account_name = fixture.string("odModifyPassword-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 64
        es.pointee.account_type = ES_OD_ACCOUNT_TYPE_COMPUTER
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odModifyPassword: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 64)
        #expect(result.accountType == ES_OD_ACCOUNT_TYPE_COMPUTER)
        #expect(result.accountName == "odModifyPassword-value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odModifyPassword: es.pointee).dbPath == nil)
    }

    @Test
    func odDisableUser() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_disable_user_t.self)
        es.pointee.user_name = fixture.string("odDisableUser-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 65
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odDisableUser: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 65)
        #expect(result.userName == "odDisableUser-value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odDisableUser: es.pointee).dbPath == nil)
    }

    @Test
    func odEnableUser() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_enable_user_t.self)
        es.pointee.user_name = fixture.string("odEnableUser-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 66
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odEnableUser: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 66)
        #expect(result.userName == "odEnableUser-value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odEnableUser: es.pointee).dbPath == nil)
    }

    @Test
    func odAttributeValueAdd() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_attribute_value_add_t.self)
        es.pointee.record_name = fixture.string("odAttributeValueAdd-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 67
        es.pointee.record_type = ES_OD_RECORD_TYPE_GROUP
        es.pointee.attribute_name = fixture.string("attribute")
        es.pointee.attribute_value = fixture.string("value")
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odAttributeValueAdd: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 67)
        #expect(result.recordType == ES_OD_RECORD_TYPE_GROUP)
        #expect(result.recordName == "odAttributeValueAdd-value")
        #expect(result.attributeName == "attribute")
        #expect(result.attributeValue == "value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odAttributeValueAdd: es.pointee).dbPath == nil)
    }

    @Test
    func odAttributeValueRemove() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_attribute_value_remove_t.self)
        es.pointee.record_name = fixture.string("odAttributeValueRemove-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 68
        es.pointee.record_type = ES_OD_RECORD_TYPE_GROUP
        es.pointee.attribute_name = fixture.string("attribute")
        es.pointee.attribute_value = fixture.string("value")
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odAttributeValueRemove: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 68)
        #expect(result.recordType == ES_OD_RECORD_TYPE_GROUP)
        #expect(result.recordName == "odAttributeValueRemove-value")
        #expect(result.attributeName == "attribute")
        #expect(result.attributeValue == "value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odAttributeValueRemove: es.pointee).dbPath == nil)
    }

    @Test
    func odAttributeSet() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_attribute_set_t.self)
        es.pointee.record_name = fixture.string("odAttributeSet-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 69
        es.pointee.record_type = ES_OD_RECORD_TYPE_GROUP
        es.pointee.attribute_name = fixture.string("attribute")
        es.pointee.attribute_value_count = 2
        es.pointee.attribute_values = fixture.array([fixture.string("one"), fixture.string("two")])
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odAttributeSet: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 69)
        #expect(result.recordType == ES_OD_RECORD_TYPE_GROUP)
        #expect(result.recordName == "odAttributeSet-value")
        #expect(result.attributeName == "attribute")
        #expect(result.attributeValues == ["one", "two"])
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odAttributeSet: es.pointee).dbPath == nil)
    }

    @Test
    func odCreateUser() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_create_user_t.self)
        es.pointee.user_name = fixture.string("odCreateUser-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 70
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odCreateUser: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 70)
        #expect(result.userName == "odCreateUser-value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odCreateUser: es.pointee).dbPath == nil)
    }

    @Test
    func odCreateGroup() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_create_group_t.self)
        es.pointee.group_name = fixture.string("odCreateGroup-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 71
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odCreateGroup: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 71)
        #expect(result.groupName == "odCreateGroup-value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odCreateGroup: es.pointee).dbPath == nil)
    }

    @Test
    func odDeleteUser() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_delete_user_t.self)
        es.pointee.user_name = fixture.string("odDeleteUser-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 72
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odDeleteUser: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 72)
        #expect(result.userName == "odDeleteUser-value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odDeleteUser: es.pointee).dbPath == nil)
    }

    @Test
    func odDeleteGroup() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_od_delete_group_t.self)
        es.pointee.group_name = fixture.string("odDeleteGroup-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.error_code = 73
        es.pointee.node_name = fixture.string("node")
        es.pointee.db_path = fixture.string("/database")
        es.pointee.instigator_token = fixture.auditToken(17)
        let result = ESConverter(version: 8).esEvent(odDeleteGroup: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.instigatorToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 17)
        #expect(result.errorCode == 73)
        #expect(result.groupName == "odDeleteGroup-value")
        #expect(result.nodeName == "node")
        #expect(result.dbPath == "/database")
        es.pointee.db_path = fixture.make(es_string_token_t.self).pointee
        #expect(ESConverter(version: 8).esEvent(odDeleteGroup: es.pointee).dbPath == nil)
    }

    @Test
    func xpcConnect() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_xpc_connect_t.self)
        es.pointee.service_name = fixture.string("xpcConnect-value")
        es.pointee.service_domain_type = ES_XPC_DOMAIN_TYPE_SYSTEM
        let result = ESConverter(version: 1).esEvent(xpcConnect: es.pointee)
        #expect(result.serviceName == "xpcConnect-value")
        #expect(result.serviceDomainType == ES_XPC_DOMAIN_TYPE_SYSTEM)
    }

    @Test
    func gatekeeperUserOverride() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_gatekeeper_user_override_t.self)
        es.pointee.file_type = ES_GATEKEEPER_USER_OVERRIDE_FILE_TYPE_PATH
        es.pointee.file.file_path = fixture.string("/override")
        es.pointee.sha256 = fixture.make(es_sha256_t.self)
        withUnsafeMutableBytes(of: &es.pointee.sha256!.pointee) { $0[0] = 0xAB }
        es.pointee.signing_info = fixture.make(es_signed_file_info_t.self)
        es.pointee.signing_info?.pointee.team_id = fixture.string("team")
        es.pointee.signing_info?.pointee.signing_id = fixture.string("signing")
        let result = try ESConverter(version: 1).esEvent(gatekeeperUserOverride: es.pointee)
        #expect(result.file == .path("/override"))
        #expect(result.sha256?.first == 0xAB)
        #expect(result.signing_info?.teamID == "team")
        #expect(result.signing_info?.signingID == "signing")
    }

    @Test
    func gatekeeperUserOverride_file() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_gatekeeper_user_override_t.self)
        es.pointee.file_type = ES_GATEKEEPER_USER_OVERRIDE_FILE_TYPE_FILE
        es.pointee.file.file = fixture.file("/override")
        let result = try ESConverter(version: 1).esEvent(gatekeeperUserOverride: es.pointee)
        if case let .file(file) = result.file {
            #expect(file.path == "/override")
        } else {
            Issue.record("Expected a file-based Gatekeeper override")
        }
        #expect(result.sha256 == nil)
        #expect(result.signing_info == nil)
    }

    @Test
    func tccModify() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_tcc_modify_t.self)
        es.pointee.service = fixture.string("tccModify-value")
        es.pointee.identity = fixture.string("bundle.id")
        es.pointee.identity_type = ES_TCC_IDENTITY_TYPE_BUNDLE_ID
        es.pointee.update_type = ES_TCC_EVENT_TYPE_CREATE
        es.pointee.instigator_token = fixture.auditToken(11)
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.responsible_token = fixture.make(audit_token_t.self)
        es.pointee.responsible_token?.pointee = fixture.auditToken(12)
        es.pointee.responsible = fixture.process("/responsible")
        es.pointee.right = ES_TCC_AUTHORIZATION_RIGHT_ALLOWED
        es.pointee.reason = ES_TCC_AUTHORIZATION_REASON_USER_CONSENT
        let result = ESConverter(version: 1).esEvent(tccModify: es.pointee)
        #expect(result.service == "tccModify-value")
        #expect(result.identity == "bundle.id")
        #expect(result.identityType == ES_TCC_IDENTITY_TYPE_BUNDLE_ID)
        #expect(result.updateType == ES_TCC_EVENT_TYPE_CREATE)
        #expect(withUnsafeBytes(of: result.instigatorToken) { $0[0] } == 11)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(result.responsibleToken.map { withUnsafeBytes(of: $0) { $0[0] } } == 12)
        #expect(result.responsible?.executable.path == "/responsible")
        #expect(result.right == ES_TCC_AUTHORIZATION_RIGHT_ALLOWED)
        #expect(result.reason == ES_TCC_AUTHORIZATION_REASON_USER_CONSENT)
    }

#if compiler(>=6.4)
    @Test
    func bootstrapCheckIn() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_bootstrap_check_in_t.self)
        es.pointee.service_name = fixture.string("bootstrapCheckIn-value")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.instigator_token = fixture.auditToken(13)
        let result = ESConverter(version: 1).esEvent(bootstrapCheckIn: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(withUnsafeBytes(of: result.instigatorToken) { $0[0] } == 13)
        #expect(result.serviceName == "bootstrapCheckIn-value")
    }
    
    @Test
    func bootstrapLookUp() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_bootstrap_look_up_t.self)
        es.pointee.target_type = ES_BOOTSTRAP_TARGET_TYPE_JOB
        es.pointee.target.job.job_label = fixture.string("job.label")
        es.pointee.instigator = fixture.process("/instigator")
        es.pointee.instigator_token = fixture.auditToken(14)
        es.pointee.service_name = fixture.string("service")
        let result = try ESConverter(version: 1).esEvent(bootstrapLookUp: es.pointee)
        #expect(result.instigator?.executable.path == "/instigator")
        #expect(withUnsafeBytes(of: result.instigatorToken) { $0[0] } == 14)
        #expect(result.serviceName == "service")
        #expect(result.target == .job(jobLabel: "job.label", lwcr: nil))
    }

    @Test
    func bootstrapLookUp_process() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_bootstrap_look_up_t.self)
        es.pointee.target_type = ES_BOOTSTRAP_TARGET_TYPE_PROCESS
        es.pointee.target.process.target = fixture.process("/target")
        es.pointee.target.process.target_token = fixture.auditToken(27)
        es.pointee.target.process.job_label = fixture.string("job.label")
        let result = try ESConverter(version: 1).esEvent(bootstrapLookUp: es.pointee)
        if case let .process(target, token, label) = result.target {
            #expect(target?.executable.path == "/target")
            #expect(withUnsafeBytes(of: token) { $0[0] } == 27)
            #expect(label == "job.label")
        } else {
            Issue.record("Expected a process bootstrap target")
        }
    }

    @Test
    func bootstrapLookUp_jobLWCR() throws {
        let fixture = ESConverterFixture()
        let es = fixture.make(es_event_bootstrap_look_up_t.self)
        es.pointee.target_type = ES_BOOTSTRAP_TARGET_TYPE_JOB
        es.pointee.target.job.job_label = fixture.string("job.label")
        let lwcr = fixture.make(es_lightweight_code_requirement_t.self)
        lwcr.pointee.team_id = fixture.string("team")
        lwcr.pointee.signing_id = fixture.string("signing")
        es.pointee.target.job.lwcr = lwcr
        let result = try ESConverter(version: 1).esEvent(bootstrapLookUp: es.pointee)
        #expect(result.target == .job(jobLabel: "job.label", lwcr: .init(teamID: "team", signingID: "signing")))
    }
#endif
}
