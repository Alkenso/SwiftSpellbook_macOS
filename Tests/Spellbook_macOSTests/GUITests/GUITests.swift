@testable import Spellbook_macOS

import XCTest

class GUITests: XCTestCase {
    func test_CGRect_invertCoordinates() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(rect.invertCoordinates(height: 1000).invertCoordinates(height: 1000), rect)
        
        XCTAssertEqual(
            CGRect(x: 100, y: 200, width: 150, height: 250).invertCoordinates(height: 1000),
            CGRect(x: 100, y: 550, width: 150, height: 250))
        XCTAssertEqual(
            CGRect(x: 100, y: -200, width: 150, height: 250).invertCoordinates(height: 1000),
            CGRect(x: 100, y: 950, width: 150, height: 250))
    }
}
