# SwiftSpellbook - macOS
SwiftSpellbook - macOS is macOS-specific additions to [SwiftSpellbook](https://github.com/Alkenso/SwiftSpellbook) that makes development easier.

<p>
  <img src="https://img.shields.io/badge/swift-6.3 | 6.4-orange" />
  <img src="https://img.shields.io/badge/platforms-macOS 13-freshgreen" />
  <img src="https://img.shields.io/badge/Xcode-26 | 27-blue" />
  <img src="https://github.com/Alkenso/SwiftSpellbook_macOS/actions/workflows/main.yml/badge.svg" />
</p>

If you've found this or other my libraries helpful, share some beer with me :D
<br>
[![Buy Me a Beer 🍺](https://img.shields.io/badge/Buy%20Me%20a%20Beer-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/alkenso)


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
