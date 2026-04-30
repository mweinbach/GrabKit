import Foundation

@MainActor
public final class GrabRegistry {
    public typealias Listener = (GrabSnapshot) -> Void
    public static let shared = GrabRegistry()

    private var nodesByID: [String: GrabNode] = [:]
    private var listeners: [UUID: Listener] = [:]
    private var sequence: Int = 0

    public private(set) var isInspecting: Bool = false
    public private(set) var selectedID: String?

    public init() {}

    @discardableResult
    public func addListener(_ listener: @escaping Listener) -> UUID {
        let token = UUID()
        listeners[token] = listener
        listener(snapshot())
        return token
    }

    public func removeListener(_ token: UUID) { listeners.removeValue(forKey: token) }

    public func upsert(_ descriptor: GrabDescriptor) {
        var accessibility = descriptor.accessibility
        if accessibility.identifier == nil { accessibility.identifier = descriptor.id }
        let existing = nodesByID[descriptor.id]
        sequence += 1

        var copy = descriptor.copy
        copy["id"] = descriptor.id
        if let identifier = accessibility.identifier {
            copy["xctest"] = "app.descendants(matching: .any)[\"\(identifier)\"]"
        }
        if let source = descriptor.source {
            copy["source"] = "\(source.fileID):\(source.line)"
        }

        nodesByID[descriptor.id] = GrabNode(
            id: descriptor.id,
            role: descriptor.role,
            component: descriptor.component,
            parentID: descriptor.parentID,
            children: existing?.children ?? [],
            path: existing?.path ?? [descriptor.id],
            frame: existing?.frame,
            accessibility: accessibility,
            source: descriptor.source,
            design: descriptor.design,
            state: descriptor.state,
            content: descriptor.content,
            copy: copy,
            isVisible: existing?.isVisible ?? true,
            renderOrder: existing?.renderOrder ?? sequence,
            updatedAt: Date()
        )
        rebuildRelationships()
        emit()
    }

    public func updateFrame(id: String, frame: GrabRect?, isVisible: Bool = true) {
        if var node = nodesByID[id] {
            guard node.frame != frame || node.isVisible != isVisible else { return }
            node.frame = frame
            node.isVisible = isVisible
            node.updatedAt = Date()
            nodesByID[id] = node
        } else {
            sequence += 1
            nodesByID[id] = GrabNode(
                id: id,
                role: .view,
                frame: frame,
                accessibility: GrabAccessibility(identifier: id),
                isVisible: isVisible,
                renderOrder: sequence
            )
        }
        rebuildRelationships()
        emit()
    }

    public func unregister(id: String) {
        nodesByID.removeValue(forKey: id)
        if selectedID == id { selectedID = nil }
        rebuildRelationships()
        emit()
    }

    public func setInspecting(_ enabled: Bool) {
        guard isInspecting != enabled else { return }
        isInspecting = enabled
        emit()
    }

    @discardableResult
    public func toggleInspecting() -> Bool {
        isInspecting.toggle()
        emit()
        return isInspecting
    }

    public func clearSelection() {
        guard selectedID != nil else { return }
        selectedID = nil
        emit()
    }

    @discardableResult
    public func select(id: String?) -> GrabSelection {
        if let id, nodesByID[id] == nil {
            selectedID = nil
            emit()
            return GrabSelection(selectedID: nil, candidateIDs: [])
        }
        selectedID = id
        emit()
        return GrabSelection(selectedID: id, candidateIDs: id.map { [$0] } ?? [])
    }

    @discardableResult
    public func select(point: GrabPoint) -> GrabSelection {
        let candidates = nodesByID.values
            .filter { node in
                guard node.isVisible, let frame = node.frame else { return false }
                return frame.contains(point)
            }
            .sorted(by: selectionSort)
        let selected = candidates.first?.id
        selectedID = selected
        emit()
        return GrabSelection(selectedID: selected, candidateIDs: candidates.map(\.id))
    }

    public func node(id: String) -> GrabNode? { nodesByID[id] }
    public func selectedNode() -> GrabNode? { selectedID.flatMap { nodesByID[$0] } }

    public func snapshot() -> GrabSnapshot {
        GrabSnapshot(
            isInspecting: isInspecting,
            selectedID: selectedID,
            nodes: nodesByID.values.sorted { lhs, rhs in
                lhs.renderOrder == rhs.renderOrder ? lhs.id < rhs.id : lhs.renderOrder < rhs.renderOrder
            }
        )
    }

    public func exportSnapshotJSON(prettyPrinted: Bool = true) throws -> Data {
        try makeJSONEncoder(prettyPrinted: prettyPrinted).encode(snapshot())
    }

    public func snapshotJSONString(prettyPrinted: Bool = true) -> String {
        do {
            let data = try exportSnapshotJSON(prettyPrinted: prettyPrinted)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\":\"\(String(describing: error))\"}"
        }
    }

    public func nodeJSONString(id: String, prettyPrinted: Bool = true) -> String? {
        guard let node = nodesByID[id] else { return nil }
        do {
            let data = try makeJSONEncoder(prettyPrinted: prettyPrinted).encode(node)
            return String(data: data, encoding: .utf8)
        } catch {
            return "{\"error\":\"\(String(describing: error))\"}"
        }
    }

    public func selectedNodeJSONString(prettyPrinted: Bool = true) -> String? {
        guard let selectedID else { return nil }
        return nodeJSONString(id: selectedID, prettyPrinted: prettyPrinted)
    }

    public func removeAll() {
        nodesByID.removeAll()
        selectedID = nil
        isInspecting = false
        emit()
    }

    public func refresh() {
        emit()
    }

    private func rebuildRelationships() {
        let keys = Array(nodesByID.keys)
        for id in keys {
            let computedPath = path(for: id)
            nodesByID[id]?.children = []
            nodesByID[id]?.path = computedPath
        }

        let currentNodes = Array(nodesByID.values)
        for node in currentNodes {
            guard let parentID = node.parentID, nodesByID[parentID] != nil else { continue }
            nodesByID[parentID]?.children.append(node.id)
        }

        for id in keys {
            nodesByID[id]?.children.sort()
        }
    }

    private func path(for id: String) -> [String] {
        var result: [String] = []
        var currentID: String? = id
        var visited = Set<String>()
        while let unwrappedID = currentID, !visited.contains(unwrappedID) {
            visited.insert(unwrappedID)
            result.append(unwrappedID)
            currentID = nodesByID[unwrappedID]?.parentID
        }
        return result.reversed()
    }

    private func selectionSort(lhs: GrabNode, rhs: GrabNode) -> Bool {
        let leftArea = lhs.frame?.area ?? Double.greatestFiniteMagnitude
        let rightArea = rhs.frame?.area ?? Double.greatestFiniteMagnitude
        if abs(leftArea - rightArea) > 1.0 { return leftArea < rightArea }
        if lhs.renderOrder == rhs.renderOrder { return lhs.id < rhs.id }
        return lhs.renderOrder > rhs.renderOrder
    }

    private func emit() {
        let currentSnapshot = snapshot()
        for listener in listeners.values { listener(currentSnapshot) }
    }

    private func makeJSONEncoder(prettyPrinted: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return encoder
    }
}
