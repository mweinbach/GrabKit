#if os(macOS) && canImport(AppKit)
import AppKit

@MainActor
public extension NSView {
    /// Registers an AppKit view with GrabKit.
    @discardableResult
    func grab(
        _ id: String,
        role: GrabRole = .view,
        component: String? = nil,
        parentID: String? = nil,
        design: [String: GrabJSONValue] = [:],
        state: [String: GrabJSONValue] = [:],
        dataSources: [GrabDataSource] = [],
        content: GrabContent = .omitted,
        copy: [String: String] = [:],
        fileID: StaticString = #fileID,
        line: UInt = #line,
        function: StaticString = #function
    ) -> Self {
        setAccessibilityIdentifier(id)
        let descriptor = GrabDescriptor(
            id: id,
            role: role,
            component: component,
            parentID: parentID,
            source: GrabSource(fileID: String(describing: fileID), line: line, function: String(describing: function)),
            accessibility: GrabAccessibility(
                identifier: id,
                label: accessibilityLabel(),
                value: accessibilityValue() as? String,
                hint: accessibilityHelp(),
                isEnabled: (self as? NSControl)?.isEnabled
            ),
            design: design,
            state: state,
            dataSources: dataSources,
            content: content,
            copy: copy
        )
        GrabRegistry.shared.upsert(descriptor)
        grabRefreshFrame(id: id)
        return self
    }

    func grabRefreshFrame(id explicitID: String? = nil) {
        let id = explicitID ?? accessibilityIdentifier()
        guard !id.isEmpty else { return }
        let rect = convert(bounds, to: nil)
        GrabRegistry.shared.updateFrame(
            id: id,
            frame: GrabRect(x: Double(rect.origin.x), y: Double(rect.origin.y), width: Double(rect.size.width), height: Double(rect.size.height)),
            isVisible: !isHidden && alphaValue > 0.01 && rect.width > 0 && rect.height > 0
        )
    }
}
#endif
