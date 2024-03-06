//  MIT License
//
//  Copyright (c) 2024 Alkenso (Vladimir Vashurkin)
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

extension FileManager {
    public func acl(
        atPath path: String,
        followSymlinks: Bool = true,
        type: acl_type_t = ACL_TYPE_EXTENDED
    ) throws -> ACL {
        try acl { followSymlinks ? acl_get_file(path, type) : acl_get_link_np(path, type) }
    }
    
    public func setACL(
        _ acl: ACL,
        atPath path: String,
        followSymlinks: Bool = true,
        type: acl_type_t = ACL_TYPE_EXTENDED
    ) throws {
        let native = try acl.toNative()
        defer { acl_free(.init(native)) }
        try checkStatus(followSymlinks ? acl_set_file(path, type, native) : acl_set_link_np(path, type, native))
    }
    
    public func acl(fd: Int32, type: acl_type_t = ACL_TYPE_EXTENDED) throws -> ACL {
        try acl { acl_get_fd_np(fd, type) }
    }
    
    public func setACL(_ acl: ACL, fd: Int32, type: acl_type_t = ACL_TYPE_EXTENDED) throws {
        let native = try acl.toNative()
        defer { acl_free(.init(native)) }
        try checkStatus(acl_set_fd_np(fd, native, type))
    }
    
    private func acl(body: () -> acl_t?) throws -> ACL {
        let native = try NSError.posix.try(body: body)
        defer { acl_free(.init(native)) }
        
        return try ACL(acl: native)
    }
}

public struct ACL: Equatable, Codable {
    public var entries: [ACLEntry]
    
    public init(entries: [ACLEntry] = []) {
        self.entries = entries
    }
}

extension ACL {
    public init(acl: acl_t) throws {
        let entries = Bridge(native: acl).entries()
        self.init(entries: try entries.map(ACLEntry.init(native:)))
    }
    
    public func toNative() throws -> acl_t {
        var bridge = try Bridge(count: entries.count)
        try entries.forEach {
            let nativeEntry = try bridge.createEntry()
            try $0.apply(to: nativeEntry)
        }
        
        return bridge.native
    }
    
    public struct Bridge {
        public var native: acl_t
        
        public init(native: acl_t) {
            self.native = native
        }
        
        public init(count: Int) throws {
            self.native = try NSError.posix.try { acl_init(Int32(count)) }
        }
        
        public func entries() -> [acl_entry_t] {
            var entries: [acl_entry_t] = []
            var entryID = ACL_FIRST_ENTRY
            var entry: acl_entry_t!
            while(acl_get_entry(native, entryID.rawValue, &entry) == 0) {
                entries.append(entry)
                entryID = ACL_NEXT_ENTRY
            }
            return entries
        }
        
        /// After inserting an ACL entry with an `index` other than
        /// `ACL_LAST_ENTRY` the behaviour of any `ACLEntry` previously obtained
        ///  from the ACL by `createEntry` or `listEntries` is undefined.
        public mutating func createEntry(index: Int? = nil) throws -> acl_entry_t {
            var acl: acl_t! = native
            var entry: acl_entry_t!
            try checkStatus(acl_create_entry_np(&acl, &entry, index.flatMap(Int32.init) ?? ACL_LAST_ENTRY.rawValue))
            native = acl
            
            return entry
        }
        
        public func removeEntry(_ entry: acl_entry_t) throws {
            try checkStatus(acl_delete_entry(native, entry))
        }
    }
}

public struct ACLQualifier: Equatable, Codable {
    public var id: id_t
    public var type: Membership.IDType
    
    public init(id: id_t, type: Membership.IDType) {
        self.id = id
        self.type = type
    }
}

extension ACLQualifier {
    public static func uid(_ uid: uid_t) -> Self { .init(id: uid, type: .uid) }
    public static func gid(_ gid: gid_t) -> Self { .init(id: gid, type: .gid) }
}

public struct ACLEntry: Equatable, Codable {
    public var tag: ACLTag
    public var permissions: ACLPermissions
    public var qualifier: ACLQualifier
    public var flags: Set<ACLFlags>
    
    public init(tag: ACLTag, permset: ACLPermissions, qualifier: ACLQualifier, flags: Set<ACLFlags> = []) {
        self.tag = tag
        self.permissions = permset
        self.qualifier = qualifier
        self.flags = flags
    }
}

extension ACLEntry {
    public init(native: acl_entry_t) throws {
        let bridge = Bridge(native: native)
        self.tag = try bridge.tag()
        self.permissions = try bridge.permset()
        self.qualifier = try bridge.qualifier()
        self.flags = try bridge.flags()
    }
    
    public func apply(to native: acl_entry_t) throws {
        let bridge = Bridge(native: native)
        try bridge.setTag(tag)
        try bridge.setPermset(permissions)
        try bridge.setQualifier(qualifier.id, type: qualifier.type)
        try bridge.setFlags(flags)
    }
    
    public struct Bridge {
        public let native: acl_entry_t
        public init(native: acl_entry_t) { self.native = native }
        
        public func tag() throws -> ACLTag {
            var tag = ACL_UNDEFINED_TAG
            try checkStatus(acl_get_tag_type(native, &tag))
            return .init(native: tag)
        }
        
        public func setTag(_ tag: ACLTag) throws {
            try checkStatus(acl_set_tag_type(native, tag.native))
        }
        
        public func permset() throws -> ACLPermissions {
            var mask = acl_permset_mask_t()
            try checkStatus(acl_get_permset_mask_np(native, &mask))
            return ACLPermissions(rawValue: UInt32(mask))
        }
        
        public func setPermset(_ set: ACLPermissions) throws {
            try checkStatus(acl_set_permset_mask_np(native, acl_permset_mask_t(set.rawValue)))
        }
        
        public func qualifier() throws -> ACLQualifier {
            let ptr = try NSError.posix.try { acl_get_qualifier(native) }
            defer { acl_free(ptr) }
            
            let uuid = UUID(uuid: ptr.bindMemory(to: uuid_t.self, capacity: 1).pointee)
            let (id, type) = try Membership.uuidToID(uuid)
            return .init(id: id, type: type)
        }
        
        public func setQualifier(_ id: id_t, type: Membership.IDType) throws {
            let uuid = switch type {
            case .uid: Membership.uidToUUID(id)
            case .gid: Membership.gidToUUID(id)
            default: throw POSIXError(.EINVAL)
            }
            
            var rawUUID = uuid.uuid
            try checkStatus(acl_set_qualifier(native, &rawUUID))
        }
        
        public func flags() throws -> Set<ACLFlags> {
            var flags: acl_flagset_t!
            try checkStatus(acl_get_flagset_np(.init(native), &flags))
            return ACLFlags.create(native: flags)
        }
        
        public func setFlags(_ flags: Set<ACLFlags>) throws {
            var flagset: acl_flagset_t!
            try checkStatus(acl_get_flagset_np(.init(native), &flagset))
            try checkStatus(acl_clear_flags_np(flagset))
            
            flags.forEach { acl_add_flag_np(flagset, $0.native) }
            
            try checkStatus(acl_set_flagset_np(.init(native), flagset))
        }
    }
}

extension acl_tag_t: BridgedCEnum {}

public struct ACLTag: _ACLValue, Hashable, Codable {
    public typealias ACLType = acl_tag_t
    
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let undefined = Self(native: ACL_UNDEFINED_TAG)
    public static let extendedAllow = Self(native: ACL_EXTENDED_ALLOW)
    public static let extendedDeny = Self(native: ACL_EXTENDED_DENY)
}

extension ACLTag: CustomStringConvertible {
    public var description: String {
        switch self {
        case .undefined: "ACL_UNDEFINED_TAG"
        case .extendedAllow: "ACL_EXTENDED_ALLOW"
        case .extendedDeny: "ACL_EXTENDED_DENY"
        default: "UNKNOWN(\(rawValue)"
        }
    }
}

extension acl_perm_t: BridgedCEnum {}

public struct ACLPermissions: _ACLValue, OptionSet, Codable {
    public typealias ACLType = acl_perm_t
    
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let readData = ACLPermissions(native: ACL_READ_DATA)
    public static let listDirectory = ACLPermissions(native: ACL_LIST_DIRECTORY)
    public static let writeData = ACLPermissions(native: ACL_WRITE_DATA)
    public static let addFile = ACLPermissions(native: ACL_ADD_FILE)
    public static let execute = ACLPermissions(native: ACL_EXECUTE)
    public static let search = ACLPermissions(native: ACL_SEARCH)
    public static let delete = ACLPermissions(native: ACL_DELETE)
    public static let appendData = ACLPermissions(native: ACL_APPEND_DATA)
    public static let addSubdirectory = ACLPermissions(native: ACL_ADD_SUBDIRECTORY)
    public static let deleteChild = ACLPermissions(native: ACL_DELETE_CHILD)
    public static let readAttributes = ACLPermissions(native: ACL_READ_ATTRIBUTES)
    public static let writeAttributes = ACLPermissions(native: ACL_WRITE_ATTRIBUTES)
    public static let readExtattributes = ACLPermissions(native: ACL_READ_EXTATTRIBUTES)
    public static let writeExtattributes = ACLPermissions(native: ACL_WRITE_EXTATTRIBUTES)
    public static let readSecurity = ACLPermissions(native: ACL_READ_SECURITY)
    public static let writeSecurity = ACLPermissions(native: ACL_WRITE_SECURITY)
    public static let changeOwner = ACLPermissions(native: ACL_CHANGE_OWNER)
    public static let synchronize = ACLPermissions(native: ACL_SYNCHRONIZE)
}

extension ACLPermissions: CustomStringConvertible {
    public var description: String {
        switch self {
        case .readData: "ACL_READ_DATA"
        case .listDirectory: "ACL_LIST_DIRECTORY"
        case .writeData: "ACL_WRITE_DATA"
        case .addFile: "ACL_ADD_FILE"
        case .execute: "ACL_EXECUTE"
        case .search: "ACL_SEARCH"
        case .delete: "ACL_DELETE"
        case .appendData: "ACL_APPEND_DATA"
        case .addSubdirectory: "ACL_ADD_SUBDIRECTORY"
        case .deleteChild: "ACL_DELETE_CHILD"
        case .readAttributes: "ACL_READ_ATTRIBUTES"
        case .writeAttributes: "ACL_WRITE_ATTRIBUTES"
        case .readExtattributes: "ACL_READ_EXTATTRIBUTES"
        case .writeExtattributes: "ACL_WRITE_EXTATTRIBUTES"
        case .readSecurity: "ACL_READ_SECURITY"
        case .writeSecurity: "ACL_WRITE_SECURITY"
        case .changeOwner: "ACL_CHANGE_OWNER"
        case .synchronize: "ACL_SYNCHRONIZE"
        default: "UNKNOWN(\(rawValue)"
        }
    }
}

extension acl_flag_t: BridgedCEnum {}

public struct ACLFlags: _ACLValue, Hashable, Codable {
    public typealias ACLType = acl_flag_t
    
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let entryInherited = ACLFlags(native: ACL_ENTRY_INHERITED)
    public static let entryFileInherit = ACLFlags(native: ACL_ENTRY_FILE_INHERIT)
    public static let entryDirectoryInherit = ACLFlags(native: ACL_ENTRY_DIRECTORY_INHERIT)
    public static let entryLimitInherit = ACLFlags(native: ACL_ENTRY_LIMIT_INHERIT)
    public static let entryOnlyInherit = ACLFlags(native: ACL_ENTRY_ONLY_INHERIT)
}

extension ACLFlags {
    public static func create(native: acl_flagset_t) -> Set<ACLFlags> {
        let allCases: [ACLFlags] = [
            .entryInherited,
            .entryFileInherit,
            .entryDirectoryInherit,
            .entryLimitInherit,
            .entryOnlyInherit,
        ]
        return allCases.reduce(into: []) {
            if acl_get_flag_np(native, $1.native) != 0 {
                $0.insert($1)
            }
        }
    }
}

extension ACLFlags: CustomStringConvertible {
    public var description: String {
        switch self {
        case .entryInherited: "ACL_ENTRY_INHERITED"
        case .entryFileInherit: "ACL_ENTRY_FILE_INHERIT"
        case .entryDirectoryInherit: "ACL_ENTRY_DIRECTORY_INHERIT"
        case .entryLimitInherit: "ACL_ENTRY_LIMIT_INHERIT"
        case .entryOnlyInherit: "ACL_ENTRY_ONLY_INHERIT"
        default: "UNKNOWN(\(rawValue)"
        }
    }
}

public protocol BridgedCEnum: RawRepresentable where RawValue == UInt32 {
    init(_ rawValue: RawValue)
    init(rawValue: RawValue)
    var rawValue: RawValue { get set }
}

public protocol _ACLValue: RawRepresentable where ACLType.RawValue == RawValue {
    associatedtype ACLType: BridgedCEnum
    init(rawValue: RawValue)
    var rawValue: RawValue { get set }
}

extension _ACLValue {
    public init(native: ACLType) {
        self.init(rawValue: native.rawValue)
    }
    
    public var native: ACLType {
        get { .init(rawValue: rawValue) }
        set { rawValue = newValue.rawValue }
    }
}

private func checkStatus(_ status: Int32) throws {
    try NSError.posix.try(status == 0)
}
