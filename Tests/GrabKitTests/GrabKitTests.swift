import XCTest
@testable import GrabKit

final class GrabKitTests: XCTestCase {
    func testSelectionChoosesSmallestVisibleContainingNode() async throws {
        await MainActor.run {
            let registry = GrabRegistry()
            registry.upsert(GrabDescriptor(id: "screen", role: .container))
            registry.updateFrame(id: "screen", frame: GrabRect(x: 0, y: 0, width: 300, height: 600))

            registry.upsert(GrabDescriptor(id: "screen.payButton", role: .button, parentID: "screen"))
            registry.updateFrame(id: "screen.payButton", frame: GrabRect(x: 20, y: 500, width: 260, height: 52))

            let selection = registry.select(point: GrabPoint(x: 40, y: 520))
            XCTAssertEqual(selection.selectedID, "screen.payButton")
            XCTAssertEqual(selection.candidateIDs.first, "screen.payButton")
        }
    }

    func testSnapshotJSONIncludesMetadata() async throws {
        let json = await MainActor.run { () -> String in
            let registry = GrabRegistry()
            registry.upsert(
                GrabDescriptor(
                    id: "checkout.payButton",
                    role: .button,
                    component: "PrimaryButton",
                    accessibility: GrabAccessibility(label: "Pay now"),
                    state: ["isLoading": false],
                    content: .safeText("Pay now")
                )
            )
            return registry.snapshotJSONString()
        }

        XCTAssertTrue(json.contains("checkout.payButton"))
        XCTAssertTrue(json.contains("PrimaryButton"))
        XCTAssertTrue(json.contains("Pay now"))
    }

    func testJSONValueLiteralEncoding() throws {
        let value: GrabJSONValue = [
            "enabled": true,
            "count": 3,
            "title": "Pay now"
        ]

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(GrabJSONValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testPromptIncludesCommentAndSelectedNodeID() {
        let node = GrabNode(
            id: "checkout.payButton",
            role: .button,
            component: "PrimaryButton",
            accessibility: GrabAccessibility(identifier: "checkout.payButton"),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let prompt = GrabPromptBuilder.prompt(for: node, comment: "Make this button less visually heavy.")

        XCTAssertTrue(prompt.contains("Make this button less visually heavy."))
        XCTAssertTrue(prompt.contains("- ID: checkout.payButton"))
        XCTAssertTrue(prompt.contains("- Role: button"))
        XCTAssertTrue(prompt.contains("- Component: PrimaryButton"))
        XCTAssertTrue(prompt.contains("\"id\" : \"checkout.payButton\""))
    }

    func testPromptIncludesAvailableMetadata() {
        let node = GrabNode(
            id: "checkout.payButton",
            role: .button,
            component: "PrimaryButton",
            parentID: "checkout.root",
            children: [],
            path: ["checkout.root", "checkout.payButton"],
            frame: GrabRect(x: 20, y: 500, width: 260, height: 52),
            accessibility: GrabAccessibility(
                identifier: "checkout.payButton",
                label: "Pay now",
                value: "Ready",
                hint: "Submits checkout",
                traits: ["button"],
                isEnabled: true
            ),
            source: GrabSource(fileID: "Demo/CheckoutView.swift", line: 42, function: "body"),
            design: ["token": "button.primary"],
            state: ["isLoading": false],
            content: .safeText("Pay now"),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let prompt = GrabPromptBuilder.prompt(for: node, comment: "Fix the spacing.")

        XCTAssertTrue(prompt.contains("- Parent ID: checkout.root"))
        XCTAssertTrue(prompt.contains("- Path: checkout.root > checkout.payButton"))
        XCTAssertTrue(prompt.contains("- Frame: x 20, y 500, width 260, height 52"))
        XCTAssertTrue(prompt.contains("- Source: Demo/CheckoutView.swift:42 in body"))
        XCTAssertTrue(prompt.contains("identifier checkout.payButton"))
        XCTAssertTrue(prompt.contains("label Pay now"))
        XCTAssertTrue(prompt.contains("enabled true"))
        XCTAssertTrue(prompt.contains("- Content: Pay now"))
        XCTAssertTrue(prompt.contains("## State"))
        XCTAssertTrue(prompt.contains("\"isLoading\" : false"))
        XCTAssertTrue(prompt.contains("## Design"))
        XCTAssertTrue(prompt.contains("\"token\" : \"button.primary\""))
    }

    func testPromptWithEmptyCommentStillIncludesContext() {
        let node = GrabNode(
            id: "settings.notificationsToggle",
            role: .toggle,
            accessibility: GrabAccessibility(identifier: "settings.notificationsToggle"),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let prompt = GrabPromptBuilder.prompt(for: node, comment: "  \n ")

        XCTAssertTrue(prompt.contains("(No comment provided.)"))
        XCTAssertTrue(prompt.contains("- ID: settings.notificationsToggle"))
        XCTAssertTrue(prompt.contains("## Full Node JSON"))
    }

    func testTransportDefaultsToDisabled() {
        let mode = GrabTransportMode.disabled
        XCTAssertFalse(mode.isEnabled)
        XCTAssertNil(mode.port)
        XCTAssertEqual(mode.exposure, .disabled)
    }

    func testTransportModesDescribeExposure() {
        XCTAssertEqual(GrabTransportMode.loopback(port: 9777).port, 9777)
        XCTAssertEqual(GrabTransportMode.loopback(port: 9777).exposure, .loopback)
        XCTAssertEqual(GrabTransportMode.localNetwork(port: 9778, token: "session-token").port, 9778)
        XCTAssertEqual(GrabTransportMode.localNetwork(port: 9778, token: "session-token").exposure, .localNetwork)
    }

    func testHealthEndpointDoesNotRequireLocalNetworkToken() async throws {
        #if canImport(Network)
        let response = await MainActor.run {
            GrabDebugServer.shared.responseForTesting(
                method: "GET",
                path: "/grab/health",
                mode: .localNetwork(port: 9777, token: "session-token")
            )
        }

        XCTAssertEqual(response.statusCode, 200)
        let object = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        XCTAssertEqual(object?["ok"] as? Bool, true)
        #endif
    }

    func testLocalNetworkEndpointsRejectMissingToken() async throws {
        #if canImport(Network)
        let response = await MainActor.run {
            GrabDebugServer.shared.responseForTesting(
                method: "GET",
                path: "/grab/tree",
                mode: .localNetwork(port: 9777, token: "session-token")
            )
        }

        XCTAssertEqual(response.statusCode, 401)
        #endif
    }

    func testLocalNetworkEndpointsAcceptBearerToken() async throws {
        #if canImport(Network)
        let response = await MainActor.run {
            GrabDebugServer.shared.responseForTesting(
                method: "GET",
                path: "/grab/tree",
                headers: ["Authorization": "Bearer session-token"],
                mode: .localNetwork(port: 9777, token: "session-token")
            )
        }

        XCTAssertEqual(response.statusCode, 200)
        let object = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        XCTAssertNotNil(object?["nodes"])
        #endif
    }

    func testLoopbackServerServesHealth() async throws {
        #if canImport(Network)
        let server = GrabDebugServer.shared
        var selectedPort: UInt16?
        var lastError: Error?

        for _ in 0..<10 {
            let port = UInt16.random(in: 30000...55000)
            do {
                try server.start(.loopback(port: port))
                selectedPort = port
                break
            } catch {
                lastError = error
            }
        }

        guard let selectedPort else {
            XCTFail("Failed to start loopback server: \(String(describing: lastError))")
            return
        }
        defer { server.stop() }

        try await Task.sleep(nanoseconds: 100_000_000)
        let url = URL(string: "http://127.0.0.1:\(selectedPort)/grab/health")!
        let (data, response) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["ok"] as? Bool, true)
        #endif
    }
}
