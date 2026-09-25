//  MIT License
//
//  Copyright (c) 2022 Alkenso (Vladimir Vashurkin)
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

extension Launchctl {
    public struct Service: Equatable, Codable, Sendable {
        /// Service label, e.g. `com.apple.akd`.
        public var name: String
        /// Domain containing the service, e.g. `.system`.
        public var domainTarget: DomainTarget
        /// Full launchctl target, e.g. `system/com.apple.akd`.
        public var serviceTarget: String { "\(domainTarget)/\(name)" }

        public init(name: String, domainTarget: DomainTarget) {
            self.name = name
            self.domainTarget = domainTarget
        }
        
        /// Unloads the service.
        public func bootout() throws {
            try runLaunchctl(["bootout", serviceTarget])
        }
        
        /// Enables the service.
        public func enable() throws {
            try runLaunchctl(["enable", serviceTarget])
        }
        
        /// Disables the service.
        public func disable() throws {
            try runLaunchctl(["disable", serviceTarget])
        }
        
        /// Force a service to start.
        /// - Parameters:
        ///     - kill: 'true' will kill existing instances before starting.
        public func kickstart(kill: Bool = false) throws {
            var args = ["kickstart"]
            if kill {
                args.append("-k")
            }
            args.append(serviceTarget)
            try runLaunchctl(args)
        }
        
        /// Sends a signal to a service's process.
        public func kill(signum: Int32) throws {
            try runLaunchctl(["kill", String(signum), serviceTarget])
        }
        
        /// Dumps the service's definition, properties & metadata in structured
        /// way.
        public func info() throws -> ServiceInfo {
            let output = try print()
            do {
                return try OutputParser(string: output).serviceInfo()
            } catch {
                throw NSError(
                    launchctlExitCode: 109,
                    stderr: "Unsupported description of \(self).",
                    underlyingError: error
                )
            }
        }
        
        /// Dumps the service's definition, properties & metadata.
        public func print() throws -> String {
            try runLaunchctl(["print", serviceTarget])
        }
    }
}

extension Launchctl.Service: CustomStringConvertible {
    /// Full launchctl target, e.g. `system/com.apple.akd`.
    public var description: String { serviceTarget }
}
