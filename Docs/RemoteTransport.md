# Remote Transport

The starter includes a tiny HTTP transport for simulator/dev usage. It is off by default and should only be enabled in debug/internal builds. The long-term real-device direction should be an outbound WebSocket broker.

## Transport modes

Disabled is the default:

```swift
RootView().grabRoot()
```

Use loopback for same-Mac macOS apps and iOS Simulator sessions:

```swift
RootView().grabRoot(transport: .loopback(port: 9777))
```

Use local-network sharing only as a manual, token-protected mode:

```swift
RootView().grabRoot(transport: .localNetwork(port: 9777, token: "short-lived-token"))
```

Local-network mode advertises `_grabkit._tcp` with Bonjour and requires the token on every non-health endpoint. Pass it with either:

```text
Authorization: Bearer short-lived-token
X-GrabKit-Token: short-lived-token
```

Endpoints:

```text
GET  /grab/health
GET  /grab/tree
GET  /grab/selected
GET  /grab/mode
POST /grab/mode
POST /grab/select-id
POST /grab/select-point
POST /grab/stop
```

Examples:

```bash
curl http://localhost:9777/grab/health
curl http://localhost:9777/grab/tree | jq
curl -X POST http://localhost:9777/grab/mode -H 'Content-Type: application/json' -d '{"enabled":true}'
curl -X POST http://localhost:9777/grab/select-id -H 'Content-Type: application/json' -d '{"id":"checkout.payButton"}'
curl -X POST http://localhost:9777/grab/select-point -H 'Content-Type: application/json' -d '{"x":160,"y":640}'
```

For local-network mode:

```bash
GRABKIT_TOKEN=short-lived-token Tools/grabctl.sh tree
curl -H 'Authorization: Bearer short-lived-token' http://device.local:9777/grab/tree
```

## Optional MCP sidecar

GrabKit includes a macOS-only stdio MCP sidecar. It runs on the developer Mac and talks to an already enabled GrabKit HTTP session:

```bash
swift run grabkit-mcp --base-url http://127.0.0.1:9777
GRABKIT_TOKEN=short-lived-token swift run grabkit-mcp --base-url http://device.local:9777
```

Tools:

```text
grab_health
grab_tree
grab_selected
grab_set_mode
grab_select_id
grab_select_point
```

The sidecar does not auto-discover apps, does not host MCP inside the iOS app, and does not expose screenshots or source-opening commands in v1.

## Recommended real-device flow

Inbound LAN servers are useful for manual same-LAN debugging but annoying for remote/CI/QA devices. Prefer:

```text
App on iPhone/iPad/Mac
        ↓ outbound WSS
Grab broker / controller service
        ↑ browser viewer / CLI / CI script
```

Benefits:

- avoids inbound firewall and NAT issues
- works across networks
- gives you one place for session auth
- easier for remote design/QA reviews
- easier to add screenshots and event streams later

## Suggested JSON-RPC shape

```json
{"method":"tree","params":{}}
{"method":"selectPoint","params":{"x":160,"y":640}}
{"method":"selectId","params":{"id":"checkout.payButton"}}
{"method":"setMode","params":{"enabled":true}}
{"method":"copyPayload","params":{"id":"checkout.payButton","format":"xctest"}}
```

## Viewer UX

A useful remote viewer should show:

- live screenshot or static preview
- overlay boxes
- searchable node tree
- selected node detail panel
- copy buttons for ID, XCTest selector, JSON, source
- candidate stack for overlapping elements
- inspect-mode toggle
- flash selected element command
