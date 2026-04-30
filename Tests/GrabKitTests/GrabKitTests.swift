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
}
