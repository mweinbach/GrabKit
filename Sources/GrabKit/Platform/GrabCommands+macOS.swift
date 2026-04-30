#if os(macOS) && canImport(SwiftUI)
import SwiftUI

/// Add this to your macOS SwiftUI App scene:
///
///     .commands { GrabCommands() }
public struct GrabCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandMenu("Debug") {
            Button("Toggle GrabKit Inspector") {
                Task { @MainActor in _ = GrabRegistry.shared.toggleInspecting() }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Clear GrabKit Selection") {
                Task { @MainActor in GrabRegistry.shared.clearSelection() }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Copy GrabKit Snapshot JSON") {
                Task { @MainActor in
                    _ = GrabClipboard.copy(GrabRegistry.shared.snapshotJSONString())
                }
            }
        }
    }
}
#endif
