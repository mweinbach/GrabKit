#if canImport(SwiftUI)
import SwiftUI
import GrabKit

struct GrabKitSwiftUIExample: View {
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Checkout")
                .font(.title)
                .grab("checkout.title", role: .text, component: "ScreenTitle", content: .safeText("Checkout"))

            Button(isLoading ? "Processing…" : "Pay now") {
                isLoading.toggle()
            }
            .grab(
                "checkout.payButton",
                role: .button,
                component: "PrimaryButton",
                accessibilityLabel: "Pay now",
                design: ["token": "button.primary"],
                state: ["isLoading": GrabJSONValue.from(isLoading)],
                dataSources: [
                    .observable(
                        "GrabKitSwiftUIExample",
                        values: ["isLoading": GrabJSONValue.from(isLoading)]
                    )
                ],
                content: .safeText(isLoading ? "Processing…" : "Pay now")
            )
        }
        .padding()
        .grabContainer("checkout.root", component: "CheckoutScreen")
        .grabRoot(transport: .loopback())
    }
}
#endif
