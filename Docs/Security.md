# Security and Privacy

GrabKit is inherently powerful. Treat it like an internal developer tool that can expose source locations, app state, identifiers, UI text, and potentially user data.

## Non-negotiables

1. Compile it out of public production builds.
2. Do not expose unauthenticated LAN endpoints.
3. Redact sensitive content by default.
4. Do not put debug metadata into user-facing accessibility labels/hints.
5. Treat screenshots as sensitive.
6. Rotate or randomize remote session tokens.

## Build guards

```swift
#if DEBUG || INTERNAL_BUILD
RootView().grabRoot(startLocalServer: true)
#else
RootView()
#endif
```

## Content redaction

Good:

```swift
Text(user.email)
    .grab("profile.email", role: .text, content: .redacted(reason: "PII"))
```

Risky:

```swift
Text(user.email)
    .grab("profile.email", role: .text, content: .safeText(user.email))
```

## Transport hardening checklist

For local HTTP:

- bind only when explicitly enabled
- display active status in overlay
- require a random session token
- prefer loopback for simulator work
- avoid enabling in shared QA builds without controls

For WebSocket broker:

- TLS only
- per-session tokens
- expiration
- viewer authentication
- audit logs
- allow app-side kill switch
- redaction before transmission

## Accessibility boundary

Keep user-facing accessibility clean. Use accessibility identifiers for automation identity, but keep debug metadata in GrabKit's private graph.
