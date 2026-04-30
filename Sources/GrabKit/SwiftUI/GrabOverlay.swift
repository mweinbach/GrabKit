#if canImport(SwiftUI)
import SwiftUI

@MainActor
private final class GrabOverlayModel: ObservableObject {
    @Published var snapshot: GrabSnapshot
    private var listenerToken: UUID?

    init() {
        snapshot = GrabRegistry.shared.snapshot()
        listenerToken = GrabRegistry.shared.addListener { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }

    deinit {
        if let listenerToken {
            Task { @MainActor in GrabRegistry.shared.removeListener(listenerToken) }
        }
    }
}

public struct GrabOverlay: View {
    @StateObject private var model = GrabOverlayModel()

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            if model.snapshot.isInspecting {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.10).ignoresSafeArea()

                    ForEach(visibleNodes) { node in
                        if let frame = node.frame {
                            GrabNodeBox(
                                node: node,
                                frame: frame,
                                rootOrigin: geometry.frame(in: .global).origin,
                                isSelected: node.id == model.snapshot.selectedID
                            )
                        }
                    }

                    GrabStatusPill(snapshot: model.snapshot)
                        .padding(12)

                    if let selectedNode {
                        GrabSelectionPanel(node: selectedNode)
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        let rootOrigin = geometry.frame(in: .global).origin
                        let point = GrabPoint(
                            x: Double(value.location.x + rootOrigin.x),
                            y: Double(value.location.y + rootOrigin.y)
                        )
                        Task { @MainActor in _ = GrabRegistry.shared.select(point: point) }
                    }
                )
            }
        }
        .allowsHitTesting(model.snapshot.isInspecting)
    }

    private var visibleNodes: [GrabNode] {
        model.snapshot.nodes.filter { $0.isVisible && $0.frame != nil }
    }

    private var selectedNode: GrabNode? {
        guard let selectedID = model.snapshot.selectedID else { return nil }
        return model.snapshot.nodes.first { $0.id == selectedID }
    }
}

private struct GrabNodeBox: View {
    let node: GrabNode
    let frame: GrabRect
    let rootOrigin: CGPoint
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.yellow : Color.cyan, lineWidth: isSelected ? 3 : 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill((isSelected ? Color.yellow : Color.cyan).opacity(isSelected ? 0.12 : 0.05))
                )

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background((isSelected ? Color.orange : Color.blue).opacity(0.90))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .offset(x: 0, y: -16)
        }
        .frame(width: max(1, frame.width), height: max(1, frame.height))
        .position(
            x: frame.x - Double(rootOrigin.x) + frame.width / 2,
            y: frame.y - Double(rootOrigin.y) + frame.height / 2
        )
    }

    private var label: String {
        if let component = node.component, !component.isEmpty {
            return "\(component) · \(node.id)"
        }
        return node.id
    }
}

private struct GrabStatusPill: View {
    let snapshot: GrabSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Text("GrabKit").fontWeight(.semibold)
            Text("\(snapshot.nodes.count) nodes")
            if let selectedID = snapshot.selectedID {
                Text("selected: \(selectedID)").lineLimit(1)
            }
            Button("Done") { Task { @MainActor in GrabRegistry.shared.setInspecting(false) } }
                .buttonStyle(.borderedProminent)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 8)
    }
}

private struct GrabSelectionPanel: View {
    let node: GrabNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(node.id)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(2)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                rolePill
                if let component = node.component {
                    Text(component)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            if let frame = node.frame {
                Text("x: \(Int(frame.x))  y: \(Int(frame.y))  w: \(Int(frame.width))  h: \(Int(frame.height))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let source = node.source {
                Text("\(source.fileID):\(source.line)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Button("Copy ID") { _ = GrabClipboard.copy(node.id) }
                Button("Copy JSON") {
                    Task { @MainActor in
                        if let json = GrabRegistry.shared.nodeJSONString(id: node.id) {
                            _ = GrabClipboard.copy(json)
                        }
                    }
                }
                if let xctest = node.copy["xctest"] {
                    Button("Copy XCTest") { _ = GrabClipboard.copy(xctest) }
                }
            }
            .buttonStyle(.bordered)
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: 460, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 10)
    }

    private var rolePill: some View {
        Text(node.role.rawValue)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }
}
#endif
