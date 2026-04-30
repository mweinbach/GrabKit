# Implementation Guide

This guide shows the fastest path for adding GrabKit to an app with the least repeated work.

## The short answer

Yes, you can install GrabKit once near the app root:

```swift
WindowGroup {
    ContentView()
        .grabRoot()
}
```

That single root install adds the inspect overlay, platform toggles, and selection handling for everything under `ContentView`. The local debug server stays off unless you explicitly pass a transport mode.

What it cannot fully do by itself is infer rich, stable metadata for every SwiftUI element. SwiftUI does not expose a public, complete runtime view tree with component names, source locations, design tokens, app state, or safe content labels. GrabKit gets high-quality results when meaningful UI publishes explicit `.grab(...)` descriptors.

The easiest practical setup is:

1. Add `.grabRoot(...)` once at the root.
2. Annotate reusable design-system components once.
3. Add screen/container IDs at route boundaries.
4. Add explicit `.grab(...)` only for one-off important UI.

That makes GrabKit feel close to automatic without relying on private SwiftUI internals.

## Add the package

In Xcode:

1. Open the app project.
2. Choose `File > Add Package Dependencies...`.
3. Enter the GrabKit repository URL.
4. Add the `GrabKit` product to the app target.

For a SwiftPM app package, add GrabKit as a dependency and include it in the app target dependencies.

## Install once in SwiftUI

For most SwiftUI apps, attach `.grabRoot(...)` to the view at the top of the scene:

```swift
import SwiftUI
import GrabKit

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .grabRoot(transport: .loopback())
        }
        #if os(macOS)
        .commands { GrabCommands() }
        #endif
    }
}
```

If your app already has an app shell, router, or root coordinator, putting `.grabRoot(...)` there is usually better than adding it to each screen:

```swift
WindowGroup {
    AppShell()
        .grabRoot(transport: .loopback())
}
```

## Keep it out of production

Wrap the root install with your internal build flag:

```swift
extension View {
    @ViewBuilder
    func debugGrabRoot() -> some View {
        #if DEBUG || INTERNAL_BUILD
        self.grabRoot(transport: .loopback())
        #else
        self
        #endif
    }
}
```

Then use:

```swift
WindowGroup {
    ContentView()
        .debugGrabRoot()
}
```

Use the same gate around `import GrabKit` in files that only compile for internal builds.

## Make coverage easy with component-level annotations

Do not annotate every call site if your app has shared components. Put `.grab(...)` inside the reusable component once:

```swift
struct PrimaryButton: View {
    let id: String
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .grab(
            id,
            role: .button,
            component: "PrimaryButton",
            accessibilityLabel: title,
            state: ["isLoading": GrabJSONValue.from(isLoading)],
            design: ["token": "button.primary"],
            content: .safeText(title)
        )
    }
}
```

Now every `PrimaryButton` gets GrabKit metadata by passing a stable ID:

```swift
PrimaryButton(
    id: "checkout.payButton",
    title: "Pay now",
    isLoading: isSubmitting,
    action: submitOrder
)
```

Use the same pattern for rows, cards, form fields, navigation items, empty states, and other design-system components.

## Add screen and container boundaries

Screen-level containers make the exported graph easier to understand:

```swift
struct CheckoutScreen: View {
    var body: some View {
        VStack {
            CheckoutSummary()
            PaymentForm()
            SubmitSection()
        }
        .grabContainer("checkout.screen", component: "CheckoutScreen")
    }
}
```

For lists, include the domain ID in the GrabKit ID:

```swift
ForEach(products) { product in
    ProductRow(product: product)
        .grabContainer(
            "product.\(product.id).row",
            component: "ProductRow",
            parentID: "product.list",
            state: ["isAvailable": GrabJSONValue.from(product.isAvailable)]
        )
}
```

For card-in-card screens, keep the parent chain explicit with `parentID`, then
add observable/model snapshots where the component already has the data:

```swift
RecoveryCard(day: store.currentDay)
    .grabContainer(
        "dashboard.recoveryCard",
        component: "RecoveryCard",
        parentID: "screen.dashboard",
        dataSources: [
            .observable(
                "DashboardStore",
                values: [
                    "currentDay": GrabJSONValue.from(store.currentDay.name),
                    "nextWorkout": GrabJSONValue.from(store.nextWorkout.name)
                ]
            )
        ]
    )
```

GrabKit records the file and line for `.observable(...)`, so copied prompts show
where the exported data came from. It still does not scrape arbitrary
`@Observable` or `@State` values automatically; pass the values that are safe
and useful for debugging.

When multiple annotated nodes overlap, GrabKit prefers the frontmost node first
and then falls back to deeper child context before frame-area heuristics. That
usually gives the expected result for sheets, popovers, and overlaid cards while
still letting you switch candidates in the inspector panel.

## Annotate one-off important UI

Use direct `.grab(...)` calls for important UI that does not come from a shared component:

```swift
Text("Checkout")
    .grab(
        "checkout.title",
        role: .text,
        component: "ScreenTitle",
        content: .safeText("Checkout")
    )
```

Prefer stable, product-level IDs:

```swift
.grab("checkout.payButton", role: .button)
.grab("settings.notificationsToggle", role: .toggle)
.grab("product.\(product.id).favoriteButton", role: .button)
```

Avoid IDs tied to layout position:

```swift
.grab("button")
.grab("row3")
.grab("leftCard")
```

## UIKit and AppKit

UIKit and AppKit views can be registered directly:

```swift
payButton.grab(
    "checkout.payButton",
    role: .button,
    component: "PrimaryButton",
    state: ["isLoading": false]
)
```

Refresh frames after layout changes:

```swift
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    payButton.grabRefreshFrame()
}
```

For pure UIKit/AppKit apps, the current package does not install a full automatic hierarchy scraper. The roadmap includes an automatic tree scrape fallback, but the best current results still come from registering meaningful controls and containers explicitly.

## Use the local debug server

The transport is off by default. For same-Mac macOS apps and iOS Simulator sessions, enable loopback explicitly:

```swift
RootView()
    .grabRoot(transport: .loopback(port: 9777))
```

Then query the graph from the development machine:

```bash
curl http://localhost:9777/grab/health
curl http://localhost:9777/grab/tree
curl -X POST http://localhost:9777/grab/mode -d '{"enabled":true}'
```

For same-LAN physical-device sessions, use manual local-network sharing with a short-lived token:

```swift
RootView()
    .grabRoot(transport: .localNetwork(port: 9777, token: "short-lived-token"))
```

```bash
GRABKIT_TOKEN=short-lived-token Tools/grabctl.sh tree
```

Only enable network exposure for internal builds. See `Docs/Security.md` before using GrabKit with real user data.
