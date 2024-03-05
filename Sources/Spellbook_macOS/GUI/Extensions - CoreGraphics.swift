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

import AppKit

extension CGRect {
    /// Converts rect between bottom-left and upper-left coordinate systems.
    ///
    /// macOS usually operates in two coordinate systems: Cocoa (0;0 at bottom-left) and
    /// Quartz/CoreGraphics (0;0 at upper-left).
    /// This method converts the coordinates between these coordinate systems using NSScreen.screens.first
    /// as the coordinate system basis.
    /// - Note: the method makes no coversion if there is no available displays in the system (all monitors disconnected).
    public var invertedCoordinates: CGRect {
        guard let screen = NSScreen.screens.first else { return self }
        return invertCoordinates(height: screen.frame.height)
    }
    
    internal func invertCoordinates(height: CGFloat) -> CGRect {
        CGRect(x: origin.x, y: height - (origin.y + size.height), width: size.width, height: size.height)
    }
}
