# GrabKit Starter

GrabKit is a SwiftPM starter package for building a **debug-only UI element grabber** for SwiftUI, UIKit, and AppKit apps.

It is meant to feel like a native-app version of React element picking:

- add `.grabRoot()` near your app root
- annotate important UI with `.grab("stable.id")`
- toggle inspect mode with shake or Command-Shift-D
- tap/click highlighted elements
- copy element ID, JSON, XCTest selector, source location, frame, accessibility metadata, state, and design metadata
- optionally query the graph over a local debug HTTP bridge

This is a starting point, not a finished internal platform. The skeleton deliberately keeps the implementation small and hackable.

## Package contents

```text
Sources/GrabKit/Core       Registry, node model, JSON metadata, selection logic
Sources/GrabKit/SwiftUI    SwiftUI modifiers, overlay, frame collection
Sources/GrabKit/Platform   iOS/macOS toggles, clipboard, UIKit/AppKit helpers
Sources/GrabKit/Transport  Tiny debug HTTP server starter
Docs/                      Architecture, integration, remote, security, roadmap
Examples/                  SwiftUI/UIKit/AppKit usage snippets
Tools/                     curl CLI and tiny browser viewer
Tests/                     Core registry tests
```

Start with [Docs/ImplementationGuide.md](Docs/ImplementationGuide.md) if you want the easiest way to add GrabKit to an app. In short: install `.grabRoot(...)` once at `ContentView` or your app shell, then annotate reusable components so coverage spreads through the app without touching every screen.

## Quick start: SwiftUI

```swift
import SwiftUI
import GrabKit

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            CheckoutScreen()
                .grabRoot(transport: .loopback())
        }
        #if os(macOS)
        .commands { GrabCommands() }
        #endif
    }
}

struct CheckoutScreen: View {
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Checkout")
                .grab(
                    "checkout.title",
                    role: .text,
                    component: "ScreenTitle",
                    content: .safeText("Checkout")
                )

            Button("Pay now") {
                isLoading = true
            }
            .grab(
                "checkout.payButton",
                role: .button,
                component: "PrimaryButton",
                accessibilityLabel: "Pay now",
                state: ["isLoading": GrabJSONValue.from(isLoading)],
                design: ["token": "button.primary"],
                content: .safeText("Pay now")
            )
        }
        .padding()
        .grabContainer("checkout.root", component: "CheckoutScreen")
    }
}
```

## Quick start: UIKit

```swift
let button = UIButton(type: .system)
button.setTitle("Pay now", for: .normal)
button.grab(
    "checkout.payButton",
    role: .button,
    component: "PrimaryButton",
    state: ["isLoading": false]
)
```

If the view moves after layout, refresh the frame:

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    payButton.grabRefreshFrame()
}
```

## Toggle inspect mode

- iOS/iPadOS: shake gesture through `GrabInputBridge`
- iOS/iPadOS with hardware keyboard/simulator: Command-Shift-D
- macOS SwiftUI: add `.commands { GrabCommands() }` and use Command-Shift-D
- Programmatic: `GrabRegistry.shared.toggleInspecting()` on the main actor

## Query from the development machine

The starter includes a small HTTP bridge. It is off by default. For same-Mac
macOS apps and iOS Simulator work, enable loopback explicitly:

```swift
RootView()
    .grabRoot(transport: .loopback(port: 9777))
```

Then try:

```bash
curl http://localhost:9777/grab/health
curl http://localhost:9777/grab/tree
curl -X POST http://localhost:9777/grab/mode -d '{"enabled":true}'
curl -X POST http://localhost:9777/grab/select-point \
  -H 'Content-Type: application/json' \
  -d '{"x":100,"y":200}'
```

For same-LAN physical devices, local-network sharing must be enabled manually and
protected with a session token:

```swift
RootView()
    .grabRoot(transport: .localNetwork(port: 9777, token: "short-lived-token"))
```

Then pass the token with `Authorization: Bearer short-lived-token` or
`X-GrabKit-Token`. For off-LAN real-device workflows, the recommended next step
is an **outbound WebSocket broker**: the app connects to your controller, and your
remote viewer connects to the same session. That avoids inbound firewall,
local-network, and device-discovery pain.

## Optional MCP sidecar

GrabKit also includes a macOS-only stdio MCP sidecar that talks to an already
enabled GrabKit transport:

```bash
swift run grabkit-mcp --base-url http://127.0.0.1:9777
GRABKIT_TOKEN=short-lived-token swift run grabkit-mcp --base-url http://iphone.local:9777
```

The sidecar exposes `grab_health`, `grab_tree`, `grab_selected`,
`grab_set_mode`, `grab_select_id`, and `grab_select_point`. It does not make the
app speak MCP and it does not auto-discover devices.

## Important safety rule

Do not ship this in production. Compile it out:

```swift
#if DEBUG || INTERNAL_BUILD
import GrabKit
#endif
```

The tool can expose real user content, app state, experiment flags, internal IDs, and source locations. Use `GrabContent.redacted(reason:)` by default for sensitive text.

## Current validation

This starter was validated with `swift test` in this environment. Apple-specific files are conditionally compiled and are intended to be opened/tested in Xcode against iOS/macOS targets.
