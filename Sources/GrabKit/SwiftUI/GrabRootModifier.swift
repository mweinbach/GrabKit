#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Installs the debug overlay and optional local transport near the app root.
    func grabRoot(
        enableOverlay: Bool = true,
        enablePlatformToggles: Bool = true,
        startLocalServer: Bool = false,
        port: UInt16 = 9777
    ) -> some View {
        modifier(
            GrabRootModifier(
                enableOverlay: enableOverlay,
                enablePlatformToggles: enablePlatformToggles,
                startLocalServer: startLocalServer,
                port: port
            )
        )
    }
}

public struct GrabRootModifier: ViewModifier {
    let enableOverlay: Bool
    let enablePlatformToggles: Bool
    let startLocalServer: Bool
    let port: UInt16

    public func body(content: Content) -> some View {
        content
            .modifier(GrabOverlayInstaller(enabled: enableOverlay))
            .background(GrabPlatformInputBridge(enabled: enablePlatformToggles))
            .onAppear {
                guard startLocalServer else { return }
                do { try GrabDebugServer.shared.start(port: port) }
                catch { assertionFailure("GrabKit failed to start local server: \(error)") }
            }
            .onDisappear {
                if startLocalServer { GrabDebugServer.shared.stop() }
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
