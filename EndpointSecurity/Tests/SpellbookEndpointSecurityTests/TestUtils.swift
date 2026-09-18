import SpellbookEndpointSecurity

import EndpointSecurity
import Foundation
import SpellbookFoundation

extension audit_token_t {
    static func random() -> audit_token_t {
        var token = audit_token_t()
        withUnsafeMutablePointer(to: &token) {
            _ = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<audit_token_t>.size, $0)
        }
        return token
    }
}

extension ESProcess {
    static func test(_ path: String) -> ESProcess {
        test(path: path, token: nil)
    }
    
    static func test(_ token: audit_token_t) -> ESProcess {
        test(path: nil, token: token)
    }
    
    static func test(path: String? = nil, token: audit_token_t? = nil, teamID: String? = nil) -> ESProcess {
        ESProcess(
            auditToken: token ?? .random(),
            ppid: 10,
            originalPpid: 20,
            groupID: 30,
            sessionID: 40,
            codesigningFlags: 50,
            isPlatformBinary: true,
            isESClient: true,
            cdHash: Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]),
            signingID: "signing_id",
            teamID: teamID ?? "team_id",
            executable: ESFile(
                path: path ?? "/root/path/to/executable/test_process",
                truncated: false,
                stat: .init()
            ),
            tty: nil,
            startTime: nil,
            responsibleAuditToken: nil,
            parentAuditToken: nil
        )
    }
}

private nonisolated(unsafe) var nextMessageID: UInt64 = 1

func createMessage(path: String, signingID: String, teamID: String, event: es_event_type_t, isAuth: Bool) -> Resource<UnsafePointer<es_message_t>> {
    let message = UnsafeMutablePointer<es_message_t>.allocate(capacity: 1)
    message.pointee.version = 4
    message.pointee.global_seq_num = nextMessageID
    nextMessageID += 1
    
    // Fields are assigned one by one rather than via the memberwise initializer:
    // `es_process_t` gains fields with every message version, so its initializer
    // signature differs between SDKs.
    message.pointee.process = .allocate(capacity: 1)
    UnsafeMutableRawPointer(message.pointee.process)
        .initializeMemory(as: UInt8.self, repeating: 0, count: MemoryLayout<es_process_t>.size)
    message.pointee.process.pointee.audit_token = .random()
    message.pointee.process.pointee.ppid = 10
    message.pointee.process.pointee.original_ppid = 10
    message.pointee.process.pointee.group_id = 20
    message.pointee.process.pointee.session_id = 500
    message.pointee.process.pointee.codesigning_flags = 0x800
    message.pointee.process.pointee.is_platform_binary = false
    message.pointee.process.pointee.is_es_client = false
    message.pointee.process.pointee.signing_id = .init(string: signingID)
    message.pointee.process.pointee.team_id = .init(string: teamID)
    message.pointee.process.pointee.executable = .allocate(capacity: 1)
    message.pointee.process.pointee.tty = nil
    message.pointee.process.pointee.start_time = .init(tv_sec: 100, tv_usec: 500)
    message.pointee.process.pointee.responsible_audit_token = .random()
    message.pointee.process.pointee.parent_audit_token = .random()
    message.pointee.process.pointee.executable.pointee.path = .init(string: path)
    
    message.pointee.action_type = isAuth ? ES_ACTION_TYPE_AUTH : ES_ACTION_TYPE_NOTIFY
    message.pointee.event_type = event
    
    return .raii(message) { 
        $0.pointee.process.pointee.team_id.data?.deallocate()
        $0.pointee.process.pointee.signing_id.data?.deallocate()
        $0.pointee.process.pointee.executable.pointee.path.data?.deallocate()
        $0.pointee.process.pointee.executable.deallocate()
        $0.pointee.process.deallocate()
        $0.deallocate()
    }
}

private extension es_string_token_t {
    init(string: String) {
        let ptr = strdup(string)
        self.init(length: UnsafePointer(ptr).flatMap(strlen) ?? 0, data: ptr)
    }
}
