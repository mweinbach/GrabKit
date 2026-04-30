#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Installs the debug overlay and optional local transport near the app root.
    func grabRoot(
        enableOverlay: Bool = true,
        enablePlatformToggles: Bool = true,
        transport: GrabTransportMode = .disabled
    ) -> some View {
        modifier(
            GrabRootModifier(
                enableOverlay: enableOverlay,
                enablePlatformToggles: enablePlatformToggles,
                transport: transport
            )
        )
    }

    @available(*, deprecated, message: "Use grabRoot(transport:) with .disabled, .loopback(port:), or .localNetwork(port:token:).")
    func grabRoot(startLocalServer: Bool, port: UInt16 = 9777) -> some View {
        grabRoot(transport: startLocalServer ? .loopback(port: port) : .disabled)
    }
}

public struct GrabRootModifier: ViewModifier {
    let enableOverlay: Bool
    let enablePlatformToggles: Bool
    let transport: GrabTransportMode

    public func body(content: Content) -> some View {
        content
            .modifier(GrabOverlayInstaller(enabled: enableOverlay))
            .background(GrabPlatformInputBridge(enabled: enablePlatformToggles))
            .onAppear {
                guard transport.isEnabled else { return }
                do {
                    try GrabDebugServer.shared.start(transport)
                    GrabRegistry.shared.refresh()
                }
                catch { assertionFailure("GrabKit failed to start local server: \(error)") }
            }
            .onDisappear {
                if transport.isEnabled {
                    GrabDebugServer.shared.stop()
                    GrabRegistry.shared.refresh()
                }
            }
    }
}

private struct GrabOverlayInstaller: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled { content.overlay(GrabOverlay()) } else { content }
    }
}

private struct GrabPlatformInputBridge: View {
    let enabled: Bool

    @ViewBuilder
    var body: some View {
        if enabled {
            #if os(iOS) && canImport(UIKit)
            GrabInputBridge().frame(width: 0, height: 0)
            #else
            EmptyView()
            #endif
        } else {
            EmptyView()
        }
    }
}
#endif
