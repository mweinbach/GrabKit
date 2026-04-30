#if os(macOS) && canImport(SwiftUI)
import SwiftUI
import GrabKit

@main
struct GrabKitMacExampleApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Inspector demo")
                    .grab("demo.title", role: .text, component: "ScreenTitle")
                Button("Toggle state") {}
                    .grab("demo.toggleButton", role: .button, component: "SecondaryButton")
            }
            .padding()
            .grabRoot(transport: .loopback())
        }
        .commands { GrabCommands() }
    }
}
#endif
