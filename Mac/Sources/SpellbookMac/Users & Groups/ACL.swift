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
    public var entries: [Entry]
    
    public init(entries: [Entry] = []) {
        self.entries = entries
    }
}

extension ACL {
    public init(acl: acl_t) throws {
        let entries = Native(native: acl).entries()
        self.init(entries: try entries.map(Entry.init(raw:)))
    }
    
    public func toNative() throws -> acl_t {
        var native = try Native(count: entries.count)
        try entries.forEach {
            let nativeEntry = try native.createEntry()
            try $0.apply(to: nativeEntry)
        }
        
        return native.raw
    }
}

extension ACL {
    public struct Entry: Equatable, Codable {
        public var tag: ACL.Tag
        public var permissions: ACL.Permissions
        public var qualifier: ACL.Qualifier
        public var flags: Set<ACL.Flags>
        
        public init(tag: ACL.Tag, permset: ACL.Permissions, qualifier: ACL.Qualifier, flags: Set<ACL.Flags> = []) {
            self.tag = tag
            self.permissions = permset
            self.qualifier = qualifier
            self.flags = flags
        }
    }
}

extension ACL.Entry {
    public init(raw: acl_entry_t) throws {
        let native = Native(raw: raw)
        self.tag = try native.tag()
        self.permissions = try native.permset()
        self.qualifier = try native.qualifier()
        self.flags = try native.flags()
    }
    
    public func apply(to raw: acl_entry_t) throws {
        let native = Native(raw: raw)
        try native.setTag(tag)
        try native.setPermset(permissions)
        try native.setQualifier(qualifier.id, type: qualifier.type)
        try native.setFlags(flags)
    }
}

extension ACL {
    public struct Qualifier: Equatable, Codable {
        public var id: id_t
        public var type: Membership.IDType
        
        public init(id: id_t, type: Membership.IDType) {
            self.id = id
            self.type = type
        }
    }
}

extension ACL.Qualifier {
    public static func uid(_ uid: uid_t) -> Self { .init(id: uid, type: .uid) }
    public static func gid(_ gid: gid_t) -> Self { .init(id: gid, type: .gid) }
}

extension acl_tag_t: SpellbookFoundation.BridgedCEnum {}

extension ACL {
    public struct Tag: _ACLValue, Hashable, Codable {
        public typealias ACLType = acl_tag_t
        
        public var rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        
        public static let undefined = Self(native: ACL_UNDEFINED_TAG)
        public static let extendedAllow = Self(native: ACL_EXTENDED_ALLOW)
        public static let extendedDeny = Self(native: ACL_EXTENDED_DENY)
    }
}

extension ACL.Tag: CustomStringConvertible {
    public var description: String {
        switch self {
        case .undefined: "ACL_UNDEFINED_TAG"
        case .extendedAllow: "ACL_EXTENDED_ALLOW"
        case .extendedDeny: "ACL_EXTENDED_DENY"
        default: "UNKNOWN(\(rawValue))"
        }
    }
}

extension acl_perm_t: SpellbookFoundation.BridgedCEnum {}

extension ACL {
    public struct Permissions: _ACLValue, OptionSet, Codable {
        public typealias ACLType = acl_perm_t
        
        public var rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        
        public static let readData = Self(native: ACL_READ_DATA)
        public static let listDirectory = Self(native: ACL_LIST_DIRECTORY)
        public static let writeData = Self(native: ACL_WRITE_DATA)
        public static let addFile = Self(native: ACL_ADD_FILE)
        public static let execute = Self(native: ACL_EXECUTE)
        public static let search = Self(native: ACL_SEARCH)
        public static let delete = Self(native: ACL_DELETE)
        public static let appendData = Self(native: ACL_APPEND_DATA)
        public static let addSubdirectory = Self(native: ACL_ADD_SUBDIRECTORY)
        public static let deleteChild = Self(native: ACL_DELETE_CHILD)
        public static let readAttributes = Self(native: ACL_READ_ATTRIBUTES)
        public static let writeAttributes = Self(native: ACL_WRITE_ATTRIBUTES)
        public static let readExtattributes = Self(native: ACL_READ_EXTATTRIBUTES)
        public static let writeExtattributes = Self(native: ACL_WRITE_EXTATTRIBUTES)
        public static let readSecurity = Self(native: ACL_READ_SECURITY)
        public static let writeSecurity = Self(native: ACL_WRITE_SECURITY)
        public static let changeOwner = Self(native: ACL_CHANGE_OWNER)
        public static let synchronize = Self(native: ACL_SYNCHRONIZE)
    }
}

extension acl_flag_t: SpellbookFoundation.BridgedCEnum {}

extension ACL {
    public struct Flags: _ACLValue, Hashable, Codable {
        public typealias ACLType = acl_flag_t
        
        public var rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        
        public static let entryInherited = Self(native: ACL_ENTRY_INHERITED)
        public static let entryFileInherit = Self(native: ACL_ENTRY_FILE_INHERIT)
        public static let entryDirectoryInherit = Self(native: ACL_ENTRY_DIRECTORY_INHERIT)
        public static let entryLimitInherit = Self(native: ACL_ENTRY_LIMIT_INHERIT)
        public static let entryOnlyInherit = Self(native: ACL_ENTRY_ONLY_INHERIT)
    }
}

extension ACL.Flags {
    public static func create(native: acl_flagset_t) -> Set<Self> {
        let allCases: [Self] = [
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

extension ACL.Flags: CustomStringConvertible {
    public var description: String {
        switch self {
        case .entryInherited: "ACL_ENTRY_INHERITED"
        case .entryFileInherit: "ACL_ENTRY_FILE_INHERIT"
        case .entryDirectoryInherit: "ACL_ENTRY_DIRECTORY_INHERIT"
        case .entryLimitInherit: "ACL_ENTRY_LIMIT_INHERIT"
        case .entryOnlyInherit: "ACL_ENTRY_ONLY_INHERIT"
        default: "UNKNOWN(\(rawValue))"
        }
    }
}

// MARK: - Native

extension ACL {
    public struct Native {
        public var raw: acl_t
        
        public init(native: acl_t) {
            self.raw = native
        }
        
        public init(count: Int) throws {
            self.raw = try NSError.posix.try { acl_init(Int32(count)) }
        }
        
        public func entries() -> [acl_entry_t] {
            var entries: [acl_entry_t] = []
            var entryID = ACL_FIRST_ENTRY
            var entry: acl_entry_t!
            while(acl_get_entry(raw, entryID.rawValue, &entry) == 0) {
                entries.append(entry)
                entryID = ACL_NEXT_ENTRY
            }
            return entries
        }
        
        /// After inserting an ACL entry with an `index` other than
        /// `ACL_LAST_ENTRY` the behaviour of any `ACLEntry` previously obtained
        ///  from the ACL by `createEntry` or `listEntries` is undefined.
        public mutating func createEntry(index: Int? = nil) throws -> acl_entry_t {
            var acl: acl_t! = raw
            var entry: acl_entry_t!
            try checkStatus(acl_create_entry_np(&acl, &entry, index.flatMap(Int32.init) ?? ACL_LAST_ENTRY.rawValue))
            raw = acl
            
            return entry
        }
        
        public func removeEntry(_ entry: acl_entry_t) throws {
            try checkStatus(acl_delete_entry(raw, entry))
        }
    }
}

extension ACL.Entry {
    public struct Native {
        public let raw: acl_entry_t
        public init(raw: acl_entry_t) { self.raw = raw }
        
        public func tag() throws -> ACL.Tag {
            var tag = ACL_UNDEFINED_TAG
            try checkStatus(acl_get_tag_type(raw, &tag))
            return .init(native: tag)
        }
        
        public func setTag(_ tag: ACL.Tag) throws {
            try checkStatus(acl_set_tag_type(raw, tag.native))
        }
        
        public func permset() throws -> ACL.Permissions {
            var mask = acl_permset_mask_t()
            try checkStatus(acl_get_permset_mask_np(raw, &mask))
            return ACL.Permissions(rawValue: UInt32(mask))
        }
        
        public func setPermset(_ set: ACL.Permissions) throws {
            try checkStatus(acl_set_permset_mask_np(raw, acl_permset_mask_t(set.rawValue)))
        }
        
        public func qualifier() throws -> ACL.Qualifier {
            let ptr = try NSError.posix.try { acl_get_qualifier(raw) }
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
            try checkStatus(acl_set_qualifier(raw, &rawUUID))
        }
        
        public func flags() throws -> Set<ACL.Flags> {
            var flags: acl_flagset_t!
            try checkStatus(acl_get_flagset_np(.init(raw), &flags))
            return ACL.Flags.create(native: flags)
        }
        
        public func setFlags(_ flags: Set<ACL.Flags>) throws {
            var flagset: acl_flagset_t!
            try checkStatus(acl_get_flagset_np(.init(raw), &flagset))
            try checkStatus(acl_clear_flags_np(flagset))
            
            flags.forEach { acl_add_flag_np(flagset, $0.native) }
            
            try checkStatus(acl_set_flagset_np(.init(raw), flagset))
        }
    }
}

// MARK: - Private

public protocol _ACLValue: RawRepresentable, Sendable where ACLType.RawValue == RawValue {
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
