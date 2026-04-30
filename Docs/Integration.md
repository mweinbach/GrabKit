# Integration Guide

## SwiftUI app lifecycle

```swift
import SwiftUI
import GrabKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .grabRoot(transport: .loopback())
        }
        #if os(macOS)
        .commands { GrabCommands() }
        #endif
    }
}
```

## Annotating SwiftUI views

Prefer stable IDs that map to product concepts rather than ephemeral layout concepts.

Good:

```swift
.grab("checkout.payButton", role: .button, component: "PrimaryButton")
.grab("product.\(product.id).addToCart", role: .button)
```

Bad:

```swift
.grab("button")
.grab("row3")
```

### Content safety

```swift
Text(user.email)
    .grab(
        "profile.email",
        role: .text,
        component: "ProfileEmail",
        content: .redacted(reason: "PII")
    )
```

Only mark text as safe when it is genuinely safe to export/copy:

```swift
Text("Pay now")
    .grab("checkout.payButton.copy", role: .text, content: .safeText("Pay now"))
```

## UIKit

```swift
final class CheckoutViewController: UIViewController {
    private let payButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        payButton.setTitle("Pay now", for: .normal)
        payButton.grab("checkout.payButton", role: .button, component: "PrimaryButton")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        payButton.grabRefreshFrame()
    }
}
```

## AppKit

```swift
let button = NSButton(title: "Pay now", target: self, action: #selector(pay))
button.grab("checkout.payButton", role: .button, component: "PrimaryButton")
```

Refresh after layout changes:

```swift
override func layout() {
    super.layout()
    button.grabRefreshFrame()
}
```

## Build gating

Wrap usage in your internal build flags:

```swift
#if DEBUG || INTERNAL_BUILD
import GrabKit
#endif
```

You can also make a tiny app wrapper:

```swift
extension View {
    @ViewBuilder
    func internalGrabRoot() -> some View {
        #if DEBUG || INTERNAL_BUILD
        self.grabRoot(transport: .loopback())
        #else
        self
        #endif
    }
}
```

## Info.plist for local networking

The debug server is off by default. Use `.loopback(port:)` for same-Mac macOS and iOS Simulator workflows. If you manually expose the debug server on iOS/iPadOS to other devices on the LAN with `.localNetwork(port:token:)`, expect local-network privacy requirements. Add internal-build-only Info.plist entries such as:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Used by internal debug tooling to inspect app UI.</string>
<key>NSBonjourServices</key>
<array>
    <string>_grabkit._tcp</string>
</array>
```

Do not add these to public builds unless you actually need them.
