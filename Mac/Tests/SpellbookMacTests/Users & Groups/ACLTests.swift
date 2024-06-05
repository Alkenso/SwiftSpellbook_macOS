import SpellbookMac

import SpellbookFoundation
import XCTest

private let fm = FileManager.default

class ACLTests: XCTestCase {
    let tmpRoot = TemporaryDirectory.bundle.directory(prefix: "ACLTests")
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try tmpRoot.setUp()
    }
    
    override func tearDownWithError() throws {
        try tmpRoot.tearDown()
        try super.tearDownWithError()
    }
    
    func test() throws {
        let path = tmpRoot.location.path
        XCTAssertThrowsError(try FileManager.default.acl(atPath: path))
        XCTAssertThrowsError(try fm.acl(atPath: "/foo/nonexistent"))
        
        let acl = ACL(entries: [
            ACL.Entry(tag: .extendedAllow, permset: .addFile, qualifier: .uid(getuid()))
        ])
        try fm.setACL(acl, atPath: path)
        XCTAssertNoThrow(try fm.acl(atPath: path))
        XCTAssertEqual(try fm.acl(atPath: path), acl)
    }
}
