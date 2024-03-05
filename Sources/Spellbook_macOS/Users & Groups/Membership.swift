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
@_implementationOnly import Spellbook_macOS.ObjC

public enum Membership {
    /// Convert a UID to a corresponding UUID.
    /// This call will always succeed and may return a synthesized
    /// UUID with the prefix FFFFEEEE-DDDD-CCCC-BBBB-AAAAxxxxxxxx,
    /// where 'xxxxxxxx' is a hex conversion of the UID. The returned
    /// UUID can be used for any operation including ACL and SACL
    /// memberships, even if a UUID is later assigned to the user
    /// record.
    
    public static func uidToUUID(_ uid: uid_t) -> UUID {
        var uuid = UUID.zero.uuid
        mbr_uid_to_uuid(uid, &uuid)
        return UUID(uuid: uuid)
    }
    
    /// Convert a GID to a corresponding UUID.
    /// This call will always succeed and may return a synthesized
    /// UUID with the prefix AAAABBBB-CCCC-DDDD-EEEE-FFFFxxxxxxxx,
    /// where 'xxxxxxxx' is a hex conversion of the UID. The returned
    /// UUID can be used for any operation including ACL and SACL
    /// memberships, even if a UUID is later assigned to the group
    /// record.
    public static func gidToUUID(_ gid: gid_t) -> UUID {
        var uuid = UUID.zero.uuid
        mbr_gid_to_uuid(gid, &uuid)
        return UUID(uuid: uuid)
    }
    
    /// Convert a SID to a corresponding UUID.
    /// This call can fail for records that do not have a valid SID or RID.
    public static func  sidToUUID(_ sid: nt_sid_t) throws -> UUID {
        var uuid = UUID.zero.uuid
        var sid = sid
        try checkStatus(mbr_sid_to_uuid(&sid, &uuid))
        return UUID(uuid: uuid)
    }

    /// Resolves a UUID to a corresponding ID and type.
    /// It will resolve a UUID to a corresponding GID or UID and return
    /// the type of ID (`ID_TYPE_UID` or `ID_TYPE_GID`).
    /// Synthesized UUID values will be directly translated to corresponding ID.
    /// A UID will always be returned even if the UUID is not found.
    /// The returned ID is not persistent, but can be used to map back to the UUID during runtime.
    public static func uuidToID(_ uuid: UUID) throws -> (id_t, type: MBRIDType) {
        var id = id_t()
        var idType = Int32()
        var uuid = uuid.uuid
        try checkStatus(mbr_uuid_to_id(&uuid, &id, &idType))
        return (id, .init(rawValue: idType))
    }

    /// Resolves a UUID to a corresponding SID.
    public static func uuidToSID(_ uuid: UUID) throws -> nt_sid_t {
        var sid = nt_sid_t()
        var uuid = uuid.uuid
        try checkStatus(mbr_uuid_to_sid(&uuid, &sid))
        return sid
    }

    /// Convert a SID to a corresponding character string representation.
    /// For use in situations where an external representation of a SID is required.
    public static func sidToString(_ sid: nt_sid_t) throws -> String {
        try withUnsafeTemporaryAllocation(of: CChar.self, capacity: 256) {
            guard let ptr = $0.baseAddress else { return "" }
            var sid = sid
            try checkStatus(mbr_sid_to_string(&sid, $0.baseAddress))
            return String(cString: ptr)
        }
    }

    /// Convert a character string representation of a sid to an `nt_sid_t` value.
        /// For converting an external representation of a sid.
    public static func stringToSID(_ string: String) throws -> nt_sid_t {
        var sid = nt_sid_t()
        try checkStatus(string.withCString { mbr_string_to_sid($0, &sid) })
        return sid
    }

    /// Checks if a user is a member of a group.
    /// Will check if a user is a member of a group either through
    /// direct membership or via nested group membership.
    public static func checkMembership(user: UUID, group: UUID) throws -> Bool {
        var user = user.uuid
        var group = group.uuid
        var isMember = Int32()
        try checkStatus(mbr_check_membership(&user, &group, &isMember))
        return isMember == 1 ? true : false
    }
    
    /// Checks if a user is a member of a group.
    /// Will check if a user is a member of a group either through
    /// direct membership or via nested group membership.
    public static func checkMembership(user: uid_t, group: uid_t) throws -> Bool {
        try checkMembership(user: uidToUUID(user), group: gidToUUID(group))
    }

    /// Checks if a user is part of a service group.
    /// Will check if a user is a member of a service access group.
    /// The servicename provided will be automatically prefixed with
    /// `"com.apple.access_"` (e.g., `"afp"` becomes `"com.apple.access_afp"`).
    /// In addition a special service group `"com.apple.access_all_services"`
    /// will be checked in addition to the specific service.
    public static func checkServiceMembership(user: UUID, service: String) throws -> Bool {
        var user = user.uuid
        var isMember = Int32()
        try checkStatus(service.withCString { mbr_check_service_membership(&user, $0, &isMember) })
        return isMember == 1 ? true : false
    }
    
    private static func checkStatus(_ status: Int32) throws {
        if let code = POSIXErrorCode(rawValue: status) {
            throw POSIXError(code)
        }
    }
}

public struct MBRIDType: RawRepresentable, Hashable {
    public var rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// Of type uid_t.
    public static let uid = Self(rawValue: ID_TYPE_UID)
    
    /// Of type gid_t.
    public static let gid = Self(rawValue: ID_TYPE_GID)
    
    /// Of type ntsid_t.
    public static let sid = Self(rawValue: ID_TYPE_SID)
    
    /// A NULL terminated UTF8 string.
    public static let username = Self(rawValue: ID_TYPE_USERNAME)
    
    /// A NULL terminated UTF8 string.
    public static let groupName = Self(rawValue: ID_TYPE_GROUPNAME)
    
    /// is of type uuid_t.
    public static let uuid = Self(rawValue: ID_TYPE_UUID)
    
    /// A NULL terminated UTF8 string.
    public static let groupNFS = Self(rawValue: ID_TYPE_GROUP_NFS)
    
    /// A NULL terminated UTF8 string.
    public static let userNFS = Self(rawValue: ID_TYPE_USER_NFS)
    
    /// A gss exported name.
    public static let gssExportName = Self(rawValue: ID_TYPE_GSS_EXPORT_NAME)
    
    /// A NULL terminated string representation of the X.509 certificate identity
    /// with the format of: `<I>DN of the Certificate authority<S>DN of the holder`.
    /// Example: `<I>DC=com,DC=example,CN=CertificatAuthority<S>DC=com,DC=example,CN=username`.
    public static let x509DN = Self(rawValue: ID_TYPE_X509_DN)
    
    /// A NULL terminated string representation of a Kerberos principal
    /// in the form of `user\@REALM` representing a typical Kerberos principal.
    public static let kerberos = Self(rawValue: ID_TYPE_KERBEROS)
}

extension MBRIDType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .uid: "ID_TYPE_UID"
        case .gid: "ID_TYPE_GID"
        case .sid: "ID_TYPE_SID"
        case .username: "ID_TYPE_USERNAME"
        case .groupName: "ID_TYPE_GROUPNAME"
        case .uuid: "ID_TYPE_UUID"
        case .groupNFS: "ID_TYPE_GROUP_NFS"
        case .userNFS: "ID_TYPE_USER_NFS"
        case .gssExportName: "ID_TYPE_GSS_EXPORT_NAME"
        case .x509DN: "ID_TYPE_X509_DN"
        case .kerberos: "ID_TYPE_KERBEROS"
        default: "ID_UNKNOWN (\(rawValue))"
        }
    }
}
