#if os(iOS) && canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

/// Optional hosting controller for UIKit lifecycle apps.
open class GrabHostingController<Content: View>: UIHostingController<Content> {
    open override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                input: "d",
                modifierFlags: [.command, .shift],
                action: #selector(toggleGrabInspector),
                discoverabilityTitle: "Toggle GrabKit Inspector"
            )
        ]
    }

    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        Task { @MainActor in _ = GrabRegistry.shared.toggleInspecting() }
    }

    @objc private func toggleGrabInspector() {
        Task { @MainActor in _ = GrabRegistry.shared.toggleInspecting() }
    }
}
#endif
