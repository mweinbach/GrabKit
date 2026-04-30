# GrabKit Agent Instructions

This file governs the full repository.

## Project Shape

- GrabKit is a SwiftPM library package for a debug-only UI element grabber across SwiftUI, UIKit, and AppKit.
- Keep the package small and understandable. Prefer direct SwiftPM-first changes over adding new build systems or generated project files.
- Public APIs should remain usable from app code on iOS 15+ and macOS 12+.

## Commands

- Build: `swift build`
- Test: `swift test`
- Run both before completing code changes.

## Implementation Guidance

- Keep production safety in mind: GrabKit can expose UI content, app state, source locations, and accessibility metadata. Preserve debug/internal-build guidance in docs and examples.
- Keep platform-specific code behind conditional compilation (`canImport(UIKit)`, `os(macOS) && canImport(AppKit)`, or equivalent).
- Prefer simple, local fixes. Do not add environment-variable switches, large configuration layers, or new abstractions unless the change clearly needs them.
- Keep generated and local build artifacts out of git (`.build/`, `.swiftpm/`, `DerivedData/`, `Package.resolved`).
- Update docs or examples when changing public API behavior.

## Style

- Use clear Swift names and small files grouped by domain (`Core`, `SwiftUI`, `Platform`, `Transport`).
- Keep comments useful and sparse; document behavior that is not obvious from the type or method name.
- Avoid introducing dependencies unless they materially simplify the package and are appropriate for a lightweight debug library.

