#if os(iOS) && canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

/// Hidden UIKit bridge that enables shake and Command-Shift-D toggles in SwiftUI apps.
public struct GrabInputBridge: UIViewControllerRepresentable {
    public init() {}

    public func makeUIViewController(context: Context) -> GrabInputViewController {
        GrabInputViewController()
    }

    public func updateUIViewController(_ uiViewController: GrabInputViewController, context: Context) {
        uiViewController.ensureFirstResponderSoon()
    }
}

public final class GrabInputViewController: UIViewController {
    public override var canBecomeFirstResponder: Bool { true }

    public override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                input: "d",
                modifierFlags: [.command, .shift],
                action: #selector(toggleGrabInspector),
                discoverabilityTitle: "Toggle GrabKit Inspector"
            )
        ]
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ensureFirstResponderSoon()
    }

    public func ensureFirstResponderSoon() {
        DispatchQueue.main.async { [weak self] in _ = self?.becomeFirstResponder() }
    }

    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        Task { @MainActor in _ = GrabRegistry.shared.toggleInspecting() }
    }

    @objc private func toggleGrabInspector() {
        Task { @MainActor in _ = GrabRegistry.shared.toggleInspecting() }
    }
}
#endif
