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
    @State private var selectionPanelOffset: CGSize = .zero
    @State private var selectionCandidateIDs: [String] = []
    @GestureState private var selectionPanelDrag: CGSize = .zero

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            if model.snapshot.isInspecting {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.10)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onEnded { value in
                                let rootOrigin = geometry.frame(in: .global).origin
                                let point = GrabPoint(
                                    x: Double(value.location.x + rootOrigin.x),
                                    y: Double(value.location.y + rootOrigin.y)
                                )
                                Task { @MainActor in
                                    let selection = GrabRegistry.shared.select(point: point)
                                    selectionCandidateIDs = selection.candidateIDs
                                }
                            }
                        )

                    ForEach(visibleNodes) { node in
                        if let frame = node.frame {
                            GrabNodeBox(
                                node: node,
                                frame: frame,
                                rootOrigin: geometry.frame(in: .global).origin,
                                rootSize: geometry.size,
                                topSafeInset: geometry.safeAreaInsets.top,
                                isSelected: node.id == model.snapshot.selectedID
                            )
                        }
                    }
                    .allowsHitTesting(false)

                    GrabStatusPill(snapshot: model.snapshot)
                        .padding(12)

                    if let selectedNode {
                        GrabSelectionPanel(
                            node: selectedNode,
                            snapshot: model.snapshot,
                            candidateIDs: selectionCandidateIDs
                        )
                            .id(selectedNode.id)
                            .padding(12)
                            .offset(
                                x: selectionPanelOffset.width + selectionPanelDrag.width,
                                y: selectionPanelOffset.height + selectionPanelDrag.height
                            )
                            .simultaneousGesture(selectionPanelDragGesture)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
            }
        }
        .onChange(of: model.snapshot.selectedID) { selectedID in
            guard let selectedID else {
                selectionCandidateIDs = []
                return
            }
            if !selectionCandidateIDs.contains(selectedID) {
                selectionCandidateIDs = [selectedID]
            }
        }
        .allowsHitTesting(model.snapshot.isInspecting)
    }

    private var selectionPanelDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($selectionPanelDrag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                selectionPanelOffset.width += value.translation.width
                selectionPanelOffset.height += value.translation.height
            }
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
    let rootSize: CGSize
    let topSafeInset: CGFloat
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
                .offset(x: labelOffset.width, y: labelOffset.height)
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

    private var labelOffset: CGSize {
        let localMinX = frame.x - Double(rootOrigin.x)
        let localMinY = frame.y - Double(rootOrigin.y)
        let estimatedLabelWidth = min(max(Double(label.count) * 6.4, 84), 240)
        let availableRight = Double(rootSize.width) - localMinX - frame.width

        let x: Double
        if availableRight < estimatedLabelWidth && localMinX > estimatedLabelWidth {
            x = frame.width - estimatedLabelWidth
        } else {
            x = 0
        }

        let preferredTopY = localMinY - 16
        let minimumSafeTop = Double(topSafeInset) + 4
        let y: Double = preferredTopY < minimumSafeTop ? 4 : -16

        return CGSize(width: x, height: y)
    }
}

private struct GrabStatusPill: View {
    let snapshot: GrabSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Text("GrabKit").fontWeight(.semibold)
            Text("\(snapshot.nodes.count) nodes")
            if snapshot.transport.isRunning {
                Text(transportLabel)
                    .lineLimit(1)
            }
            if let selectedID = snapshot.selectedID {
                Text("selected: \(selectedID)").lineLimit(1)
            }
            if snapshot.transport.exposure == .localNetwork {
                Button("Stop Sharing") {
                    Task { @MainActor in
                        GrabDebugServer.shared.stop()
                        GrabRegistry.shared.refresh()
                    }
                }
                .buttonStyle(.bordered)
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

    private var transportLabel: String {
        let port = snapshot.transport.port.map { ":\($0)" } ?? ""
        switch snapshot.transport.exposure {
        case .disabled:
            return "transport off"
        case .loopback:
            return "loopback\(port)"
        case .localNetwork:
            return "LAN sharing\(port)"
        }
    }
}

private struct GrabSelectionPanel: View {
    let node: GrabNode
    let snapshot: GrabSnapshot
    let candidateIDs: [String]
    @State private var promptComment = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(node.id)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(2)
                .textSelection(.enabled)
                .accessibilityIdentifier("grabkit.selection.id")

            HStack(spacing: 8) {
                rolePill
                if let component = node.component {
                    Text(component)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("grabkit.selection.component")
                }
            }

            if let frame = node.frame {
                Text("x: \(Int(frame.x))  y: \(Int(frame.y))  w: \(Int(frame.width))  h: \(Int(frame.height))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("grabkit.selection.frame")
            }

            if let source = node.source {
                Text("\(source.fileID):\(source.line)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if candidateNodes.count > 1 {
                candidateStack
            }

            HStack(spacing: 8) {
                TextField("What should change here?", text: $promptComment)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("grabkit.selection.comment")
                    .accessibilityLabel("GrabKit prompt comment")
                Button("Copy Prompt") {
                    _ = GrabClipboard.copy(
                        GrabPromptBuilder.prompt(for: node, in: snapshot, comment: promptComment)
                    )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("grabkit.selection.copyPrompt")
                .accessibilityLabel("Copy GrabKit prompt")
            }

            HStack {
                Button("Copy ID") { _ = GrabClipboard.copy(node.id) }
                    .accessibilityIdentifier("grabkit.selection.copyID")
                Button("Copy JSON") {
                    Task { @MainActor in
                        if let json = GrabRegistry.shared.nodeJSONString(id: node.id) {
                            _ = GrabClipboard.copy(json)
                        }
                    }
                }
                .accessibilityIdentifier("grabkit.selection.copyJSON")
                if let xctest = node.copy["xctest"] {
                    Button("Copy XCTest") { _ = GrabClipboard.copy(xctest) }
                        .accessibilityIdentifier("grabkit.selection.copyXCTest")
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("grabkit.selection.panel")
        .accessibilityLabel("GrabKit selection panel")
    }

    private var rolePill: some View {
        Text(node.role.rawValue)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }

    private var candidateNodes: [GrabNode] {
        candidateIDs.compactMap { id in snapshot.nodes.first { $0.id == id } }
    }

    private var candidateStack: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(candidateNodes) { candidate in
                    Button {
                        Task { @MainActor in _ = GrabRegistry.shared.select(id: candidate.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(stackLabel(for: candidate))
                                    .font(.caption.weight(.semibold))
                                if candidate.id == candidateNodes.first?.id {
                                    Text("frontmost")
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }

                            Text(stackMetadata(for: candidate))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(candidate.id == node.id)
                    .accessibilityIdentifier("grabkit.candidate.\(candidate.id)")
                    .accessibilityLabel(stackAccessibilityLabel(for: candidate))
                }
            }
        }
        .accessibilityIdentifier("grabkit.selection.candidates")
    }

    private func stackLabel(for candidate: GrabNode) -> String {
        if let component = candidate.component, !component.isEmpty {
            return component
        }
        return candidate.id
    }

    private func stackMetadata(for candidate: GrabNode) -> String {
        let depth = max(candidate.path.count - 1, 0)
        let area = Int(candidate.frame?.area ?? 0)
        return "depth \(depth) · order \(candidate.renderOrder) · area \(area)"
    }

    private func stackAccessibilityLabel(for candidate: GrabNode) -> String {
        let frontmost = candidate.id == candidateNodes.first?.id ? ", frontmost candidate" : ""
        return "\(stackLabel(for: candidate)), \(stackMetadata(for: candidate))\(frontmost)"
    }
}
#endif
