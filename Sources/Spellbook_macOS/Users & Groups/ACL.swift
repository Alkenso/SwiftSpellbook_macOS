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
    public var type: MBRIDType
    
    public init(id: id_t, type: MBRIDType) {
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
    public var permset: ACLPerm
    public var qualifier: ACLQualifier
    
    public init(tag: ACLTag, permset: ACLPerm, qualifier: ACLQualifier) {
        self.tag = tag
        self.permset = permset
        self.qualifier = qualifier
    }
}

extension ACLEntry {
    public init(native: acl_entry_t) throws {
        let bridge = Bridge(native: native)
        self.tag = try bridge.tag()
        self.permset = try bridge.permset()
        self.qualifier = try bridge.qualifier()
    }
    
    public func apply(to native: acl_entry_t) throws {
        let bridge = Bridge(native: native)
        try bridge.setTag(tag)
        try bridge.setPermset(permset)
        try bridge.setQualifier(qualifier.id, type: qualifier.type)
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
        
        public func permset() throws -> ACLPerm {
            var mask = acl_permset_mask_t()
            try checkStatus(acl_get_permset_mask_np(native, &mask))
            return ACLPerm(rawValue: UInt32(mask))
        }
        
        public func setPermset(_ set: ACLPerm) throws {
            try checkStatus(acl_set_permset_mask_np(native, acl_permset_mask_t(set.rawValue)))
        }
        
        public func qualifier() throws -> ACLQualifier {
            let ptr = try NSError.posix.try { acl_get_qualifier(native) }
            defer { acl_free(ptr) }
            
            let uuid = UUID(uuid: ptr.bindMemory(to: uuid_t.self, capacity: 1).pointee)
            let (id, type) = try Membership.uuidToID(uuid)
            return .init(id: id, type: type)
        }
        
        public func setQualifier(_ id: id_t, type: MBRIDType) throws {
            let uuid = switch type {
            case .uid: Membership.uidToUUID(id)
            case .gid: Membership.gidToUUID(id)
            default: throw POSIXError(.EINVAL)
            }
            
            var rawUUID = uuid.uuid
            try checkStatus(acl_set_qualifier(native, &rawUUID))
        }
    }
}

extension acl_tag_t: BridgedCEnum {}

public struct ACLTag: _ACLValue, OptionSet, Codable {
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

public struct ACLPerm: _ACLValue, OptionSet, Codable {
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

extension ACLPerm: CustomStringConvertible {
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

public struct ACLFlag: _ACLValue, OptionSet, Codable {
    public typealias ACLType = acl_flag_t
    
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    
    public static let flagDeferInherit = Self(native: ACL_FLAG_DEFER_INHERIT)
    public static let flagNoInherit = Self(native: ACL_FLAG_NO_INHERIT)
    
    public static let entryInherited = Self(native: ACL_ENTRY_INHERITED)
    public static let entryFileInherit = Self(native: ACL_ENTRY_FILE_INHERIT)
    public static let entryDirectoryInherit = Self(native: ACL_ENTRY_DIRECTORY_INHERIT)
    public static let entryLimitInherit = Self(native: ACL_ENTRY_LIMIT_INHERIT)
    public static let entryOnlyInherit = Self(native: ACL_ENTRY_ONLY_INHERIT)
}

extension ACLFlag: CustomStringConvertible {
    public var description: String {
        switch self {
        case .flagDeferInherit: "ACL_FLAG_DEFER_INHERIT"
        case .flagNoInherit: "ACL_FLAG_NO_INHERIT"
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
