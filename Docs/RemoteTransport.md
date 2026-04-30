# Remote Transport

The starter includes a tiny HTTP transport for simulator/dev usage. The long-term direction should be an outbound WebSocket broker.

## Local HTTP endpoints

Start:

```swift
RootView().grabRoot(startLocalServer: true, port: 9777)
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
```

Examples:

```bash
curl http://localhost:9777/grab/health
curl http://localhost:9777/grab/tree | jq
curl -X POST http://localhost:9777/grab/mode -H 'Content-Type: application/json' -d '{"enabled":true}'
curl -X POST http://localhost:9777/grab/select-id -H 'Content-Type: application/json' -d '{"id":"checkout.payButton"}'
curl -X POST http://localhost:9777/grab/select-point -H 'Content-Type: application/json' -d '{"x":160,"y":640}'
```

## Recommended real-device flow

Inbound LAN servers are annoying on real devices. Prefer:

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
