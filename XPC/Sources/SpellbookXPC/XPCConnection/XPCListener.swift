/*
 * MIT License
 *
 * Copyright (c) 2020 Alkenso (Vladimir Vashurkin)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import Foundation
import SpellbookFoundation

extension XPCListener {
    public convenience init<ExportedInterfaceXPC, RemoteInterfaceXPC>(
        _ type: XPCListenerInit,
        exportedInterface: XPCInterface<ExportedInterface, ExportedInterfaceXPC>,
        remoteInterface: XPCInterface<RemoteInterface, RemoteInterfaceXPC>
    ) {
        self.init(type) {
            XPCConnection(.connection($0), remoteInterface: remoteInterface, exportedInterface: exportedInterface)
        }
    }
    
    public convenience init<ExportedInterfaceXPC>(
        _ type: XPCListenerInit,
        exportedInterface: XPCInterface<ExportedInterface, ExportedInterfaceXPC>
    ) where RemoteInterface == Never {
        self.init(type) {
            XPCConnection(.connection($0), exportedInterface: exportedInterface)
        }
    }
}

open class XPCListener<ExportedInterface, RemoteInterface>: XPCListenerProtocol {
    public let native: NSXPCListener
    
    public var newConnectionHandler: ((XPCConnection<RemoteInterface, ExportedInterface>) -> Bool)?
    
    public var verifyConnectionHandler: ((audit_token_t) -> Bool)?
    
    public func resume() {
        native.resume()
    }
    
    public func suspend() {
        native.suspend()
    }
    
    public func invalidate() {
        native.invalidate()
    }
    
    public var endpoint: NSXPCListenerEndpoint {
        native.endpoint
    }
    
    // MARK: Private
    
    private let listenerDelegate = ListenerDelegate()
    private let createConnection: (NSXPCConnection) -> XPCConnection<RemoteInterface, ExportedInterface>
    
    private init(
        _ type: XPCListenerInit,
        createConnection: @escaping (NSXPCConnection) -> XPCConnection<RemoteInterface, ExportedInterface>
    ) {
        self.native = type.native
        self.createConnection = createConnection
        
        listenerDelegate.parent = self
        native.delegate = listenerDelegate
    }
}

extension XPCListener {
    private class ListenerDelegate: NSObject, NSXPCListenerDelegate {
        weak var parent: XPCListener?
        
        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
            guard let parent = parent else {
                return false
            }
            guard parent.verifyConnectionHandler?(newConnection.auditToken) != false else {
                return false
            }
            guard let newConnectionHandler = parent.newConnectionHandler else {
                return false
            }
            
            let accepted = newConnectionHandler(parent.createConnection(newConnection))
            return accepted
        }
    }
}

public enum XPCListenerInit {
    case service
    case machService(_ name: String)
    case anonymous
    case listener(NSXPCListener)
}

public protocol XPCListenerProtocol: AnyObject {
    associatedtype ExportedInterface
    associatedtype RemoteInterface
    
    var newConnectionHandler: ((XPCConnection<ExportedInterface, RemoteInterface>) -> Bool)? { get set }
    var verifyConnectionHandler: ((audit_token_t) -> Bool)? { get set }
    
    func resume()
    func suspend()
    func invalidate()
}

extension XPCListenerInit {
    public var native: NSXPCListener {
        switch self {
        case .service:
            return .service()
        case .machService(let name):
            return .init(machServiceName: name)
        case .anonymous:
            return .anonymous()
        case .listener(let listener):
            return listener
        }
    }
}
