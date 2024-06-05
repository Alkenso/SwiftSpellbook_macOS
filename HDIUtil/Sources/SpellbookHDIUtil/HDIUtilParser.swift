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

private let log = SpellbookLogger.default.with(subsystem: "HDIUtil", category: "Parser")

public struct HDIUtilParser {
    public var options: Options
    
    public init(options: Options) {
        self.options = options
    }
}

extension HDIUtilParser {
    public struct Options {
        public var log: SpellbookLogLevel? = .warning
        public var `throw` = false
        
        public init() {}
    }
}

extension HDIUtilParser {
    public func image(_ dict: [String: Any]) throws -> HDIUtil.Image {
        let reader = dict.reader
        return try .init(
            blockCount: reader.read(key: "blockcount", as: Int.self),
            blockSize: reader.read(key: "blocksize", as: Int.self),
            imageEncrypted: reader.read(key: "image-encrypted", as: Bool.self),
            imagePath: reader.read(key: "image-path", as: String.self),
            imageType: reader.read(key: "image-type", as: String.self),
            removable: reader.read(key: "removable", as: Bool.self),
            systemEntities: array(dict, key: "system-entities", parse: systemEntity),
            writeable: reader.read(key: "writeable", as: Bool.self),
            autodiskmount: dict["autodiskmount"] as? Bool,
            diskImages2: dict["diskimages2"] as? Bool,
            hdidPID: dict["hdid-pid"] as? pid_t,
            ownerUID: dict["owner-uid"] as? uid_t,
            iconPath: dict["icon-path"] as? String
        )
    }

    public func systemEntity(_ dict: [String: Any]) throws -> HDIUtil.Image.SystemEntity {
        let reader = dict.reader
        return try .init(
            contentHint: reader.read(key: "content-hint", as: String.self),
            devEntry: reader.read(key: "dev-entry", as: String.self),
            mountPoint: dict["mount-point"] as? String
        )
    }
}

extension HDIUtilParser {
    internal func array<T, U>(_ dict: [String: Any], key: String, parse: (T) throws -> U) throws -> [U] {
        guard let array = dict[key] else { return [] }
        guard let array = array as? [T] else {
            try handleError(CommonError.cast(name: "value for \(key)", array, to: [T].self))
            return []
        }
        return try array.compactMap {
            do {
                return try parse($0)
            } catch {
                try handleError(error)
                return nil
            }
        }
    }
    
    private func handleError(_ error: Error) throws {
        if let level = options.log {
            log.custom(level: level, message: error, assert: false)
        }
        if options.throw {
            throw error
        }
    }
}
