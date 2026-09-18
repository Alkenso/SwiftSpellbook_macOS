import SpellbookMac

import SpellbookFoundation
import XCTest

class SysctlTests: XCTestCase {
    func test() throws {
        let (path, _) = try Sysctl.procArgs(for: getpid())
        XCTAssertEqual(path.lastPathComponent, "xctest")
    }
}
