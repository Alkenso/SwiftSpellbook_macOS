# SwiftSpellbook - macOS
SwiftSpellbook - macOS is macOS-specific additions to [SwiftSpellbook](https://github.com/Alkenso/SwiftSpellbook) that makes development easier.

<p>
  <img src="https://img.shields.io/badge/swift-5.10 | 6.2-orange" />
  <img src="https://img.shields.io/badge/platforms-macOS 11-freshgreen" />
  <img src="https://img.shields.io/badge/Xcode-16 | 26-blue" />
  <img src="https://github.com/Alkenso/SwiftSpellbook_macOS/actions/workflows/main.yml/badge.svg" />
</p>

If you've found this or other my libraries helpful, please buy me some pizza

<a href="https://www.buymeacoffee.com/alkenso"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a pizza&emoji=🍕&slug=alkenso&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" /></a>


## Motivation
While participating in many macOS projects I use the same tools and standard types extensions.
Once I've decided stop to copy-paste code from project to project and make single library that covers lots of developer needs in utility code.

## Aggregate package
Now this package aggregates previously-independent packages for macOS:
- Mac: Swift wrappers around POSIX and other low-level C API for macOS
- MacShims: (useful C libraries without native Swift module)
- EndpointSecurity: Swift wrapper around EndpointSecurity framework
- XPC: XPC powered by Swift type system
- Launchctl: Swift API that mirrors `launchctl` utility
- HDIUtil: Swift API that mirrors `hdiutil` utility
