# Architecture

GrabKit is built around a simple idea:

> meaningful UI elements publish debug descriptors; the app renders and exports those descriptors.

Do not try to reverse-engineer SwiftUI's private view tree. Treat the explicit `.grab(...)` descriptors as the source of truth, then merge accessibility and layout data around them.

## Layers

```text
SwiftUI/UIKit/AppKit views
        ↓
.grab(...) descriptors + accessibility identifiers
        ↓
GrabRegistry
        ↓
Snapshot JSON + overlay + copy actions + local/remote transport
```

The transport is explicit and off by default. Loopback mode is for same-Mac
macOS/iOS Simulator work. Local-network mode is a manual token-protected share
mode, and the optional MCP integration is a macOS sidecar that calls the app's
HTTP transport rather than embedding MCP in app binaries.

## Core concepts

### GrabDescriptor

A descriptor is the developer-authored payload:

- stable ID
- role
- component name
- source location
- accessibility summary
- design tokens
- debug state
- redacted/safe content
- copy payloads

### GrabNode

A node is the runtime representation. It adds:

- frame
- visibility
- path
- children
- render order
- update timestamp

### GrabRegistry

The registry is `@MainActor` because UI frame updates and selection should stay on the UI thread. It handles:

- `upsert(_:)`
- `updateFrame(id:frame:)`
- `select(id:)`
- `select(point:)`
- `snapshot()`
- JSON export
- listener notifications

### Overlay

The SwiftUI overlay subscribes to the registry, draws rectangles around visible nodes, and performs point selection. The starter ranks point-selection candidates by:

1. smallest containing frame
2. newest render order
3. stable ID tie-breaker

That is intentionally simple. Production versions should add z-index, window level, opacity, hit-testing, and candidate stack UI.

## Why hybrid metadata matters

Accessibility gives you labels, roles, identifiers, traits, and automation handles. It does not give you source location, design token, model ID, feature flag state, analytics event, or Figma component mapping. GrabKit stores those in a private debug graph instead of polluting user-facing accessibility fields.

## Suggested internal extensions

- screen/router context
- analytics event metadata
- Figma component keys
- design token validation
- feature flag/experiment state
- owner/team metadata
- UI-test selector generator
- remote screenshot stream
- outbound WebSocket controller
- plugin that opens selected source in Xcode
