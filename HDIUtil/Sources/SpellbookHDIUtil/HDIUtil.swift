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
import SpellbookMac

extension HDIUtil {
    public static let errorDomain = "HDIUtilErrorDomain"
}

public struct HDIUtil {
    private var parser = HDIUtilParser(options: .init())
    
    public init() {}
    
    public var options: HDIUtilParser.Options {
        get { parser.options }
        set { parser.options = newValue }
    }
    
    public func info() throws -> [Image] {
        let (code, output, error) = Process.launch(
            tool: URL(fileURLWithPath: "/usr/bin/hdiutil"),
            arguments: ["info", "-plist"]
        )
        guard code == 0 else {
            throw NSError(
                domain: HDIUtil.errorDomain,
                code: Int(code),
                userInfo: [NSLocalizedDescriptionKey: error]
            )
        }
        
        let plist = try PropertyListSerialization.propertyList(from: output.utf8Data, format: nil)
        guard let root = plist as? [String: Any] else {
            throw CommonError.cast(name: "hdiutil info", plist, to: [String: Any].self)
        }
        return try parser.array(root, key: "images", parse: parser.image)
    }
}

extension HDIUtil {
    
}

extension HDIUtil {
    public struct Image: Codable {
        public var blockCount: Int
        public var blockSize: Int
        public var imageEncrypted: Bool
        public var imagePath: String
        public var imageType: String
        public var removable: Bool
        public var systemEntities: [SystemEntity]
        public var writeable: Bool
        public var autodiskmount: Bool?
        public var diskImages2: Bool?
        public var hdidPID: pid_t?
        public var ownerUID: uid_t?
        public var iconPath: String?
        
        public init(
            blockCount: Int,
            blockSize: Int,
            imageEncrypted: Bool,
            imagePath: String,
            imageType: String,
            removable: Bool,
            systemEntities: [SystemEntity],
            writeable: Bool,
            autodiskmount: Bool? = nil,
            diskImages2: Bool? = nil,
            hdidPID: pid_t? = nil,
            ownerUID: uid_t? = nil,
            iconPath: String? = nil
        ) {
            self.blockCount = blockCount
            self.blockSize = blockSize
            self.imageEncrypted = imageEncrypted
            self.imagePath = imagePath
            self.imageType = imageType
            self.removable = removable
            self.systemEntities = systemEntities
            self.writeable = writeable
            self.autodiskmount = autodiskmount
            self.diskImages2 = diskImages2
            self.hdidPID = hdidPID
            self.ownerUID = ownerUID
            self.iconPath = iconPath
        }
    }
}

extension HDIUtil.Image {
    public struct SystemEntity: Codable {
        public var contentHint: String
        public var devEntry: String
        public var mountPoint: String?
        
        public init(contentHint: String, devEntry: String, mountPoint: String? = nil) {
            self.contentHint = contentHint
            self.devEntry = devEntry
            self.mountPoint = mountPoint
        }
    }
}
