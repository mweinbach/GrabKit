#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Registers a meaningful SwiftUI view with the debug UI graph.
    ///
    /// This also sets `accessibilityIdentifier(id)` for UI automation. It does not
    /// mutate user-facing accessibility labels, hints, or values.
    func grab(
        _ id: String,
        role: GrabRole = .view,
        component: String? = nil,
        parentID: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityValue: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityTraits: [String] = [],
        isEnabled: Bool? = nil,
        design: [String: GrabJSONValue] = [:],
        state: [String: GrabJSONValue] = [:],
        dataSources: [GrabDataSource] = [],
        content: GrabContent = .omitted,
        copy: [String: String] = [:],
        fileID: StaticString = #fileID,
        line: UInt = #line,
        function: StaticString = #function
    ) -> some View {
        let descriptor = GrabDescriptor(
            id: id,
            role: role,
            component: component,
            parentID: parentID,
            source: GrabSource(fileID: String(describing: fileID), line: line, function: String(describing: function)),
            accessibility: GrabAccessibility(
                identifier: id,
                label: accessibilityLabel,
                value: accessibilityValue,
                hint: accessibilityHint,
                traits: accessibilityTraits,
                isEnabled: isEnabled
            ),
            design: design,
            state: state,
            dataSources: dataSources,
            content: content,
            copy: copy
        )
        return modifier(GrabViewModifier(descriptor: descriptor))
    }

    /// Convenience for visually meaningful sections/containers.
    func grabContainer(
        _ id: String,
        component: String? = nil,
        parentID: String? = nil,
        design: [String: GrabJSONValue] = [:],
        state: [String: GrabJSONValue] = [:],
        dataSources: [GrabDataSource] = [],
        fileID: StaticString = #fileID,
        line: UInt = #line,
        function: StaticString = #function
    ) -> some View {
        grab(
            id,
            role: .container,
            component: component,
            parentID: parentID,
            design: design,
            state: state,
            dataSources: dataSources,
            fileID: fileID,
            line: line,
            function: function
        )
    }
}

private struct GrabViewModifier: ViewModifier {
    let descriptor: GrabDescriptor

    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(descriptor.accessibility.identifier ?? descriptor.id)
            .background(GrabFrameReporter(id: descriptor.id))
            .onAppear { Task { @MainActor in GrabRegistry.shared.upsert(descriptor) } }
            .onChange(of: descriptor) { newDescriptor in
                Task { @MainActor in GrabRegistry.shared.upsert(newDescriptor) }
            }
            .onDisappear { Task { @MainActor in GrabRegistry.shared.unregister(id: descriptor.id) } }
    }
}

private struct GrabFrameReporter: View {
    let id: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { report(proxy.frame(in: .global)) }
                .onChange(of: proxy.frame(in: .global)) { newFrame in report(newFrame) }
        }
    }

    private func report(_ frame: CGRect) {
        let rect = GrabRect(
            x: Double(frame.origin.x),
            y: Double(frame.origin.y),
            width: Double(frame.size.width),
            height: Double(frame.size.height)
        )
        Task { @MainActor in
            GrabRegistry.shared.updateFrame(
                id: id,
                frame: rect,
                isVisible: rect.width > 0 && rect.height > 0
            )
        }
    }
}
#endif
