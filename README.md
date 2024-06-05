## sAdmin - Swift wrappers around POSIX and other low-level C API for macOS

# SwiftSpellbook - macOS
SwiftSpellbook - macOS is macOS-specific additions to [SwiftSpellbook](https://github.com/Alkenso/SwiftSpellbook) that makes development easier.

<p>
  <img src="https://img.shields.io/badge/swift-5.9-orange" />
  <img src="https://img.shields.io/badge/platforms-macOS 11-freshgreen" />
  <img src="https://img.shields.io/badge/Xcode-15-blue" />
  <img src="https://github.com/Alkenso/SwiftSpellbook_macOS/actions/workflows/main.yml/badge.svg" />
</p>

## Motivation
While participating in many macOS projects I use the same tools and standard types extensions.
Once I've decided stop to copy-paste code from project to project and make single library that covers lots of developer needs in utility code.

## Aggregate package
Now this package aggregates previously-independent packages for macOS:
- MacShims (useful C libraries without native Swift module)
- EndpointSecurity
- XPC
- Launchctl
- HDIUtil
