import SwiftUI

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if model.needsPermission {
                permissionCard
            }
            liveDesks
            toolbar
        }
        .padding(16)
        .frame(minWidth: 620)
        .latchGlass(cornerRadius: 26)
        .padding(6)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LATCH")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(Theme.gold)
            Text(model.status.isEmpty ? "Return applies the gold outline" : model.status)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
            Spacer()
        }
    }

    private var permissionCard: some View {
        HStack(spacing: 10) {
            Text("Allow Accessibility and the tiles start sliding for real.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mist)
            Spacer()
            Button("Grant…") {
                Permissions.prompt()
                Permissions.openAccessibilitySettings()
                model.refreshPermission()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.goldDeep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.inkLift, in: Capsule())
    }

    private var liveDesks: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(model.screens) { screen in
                ScreenCard(
                    screen: screen,
                    ghosts: model.ghosts(for: screen),
                    ghostLabels: model.ghostLabels(for: screen)
                ) {
                    model.applyAdvice(on: screen.id)
                } onDrag: { tile, frame in
                    model.drag(tile: tile, to: frame, on: screen.id)
                } onDragEnd: {
                    model.endDrag()
                }
            }
        }
        .animation(.interpolatingSpring(stiffness: 260, damping: 28), value: model.screens.map(\.tiles))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            modeChip("C", "Coding", .coding)
            modeChip("R", "Research", .research)
            modeChip("F", "Focus", .focus)
            Divider().frame(height: 22)
            snapChip("←", .leftHalf)
            snapChip("→", .rightHalf)
            snapChip("M", .maximize)
            Spacer()
            ForEach(1...3, id: \.self) { slot in
                Button {
                    model.apply(.restorePreset(slot))
                } label: {
                    Text("\(slot)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(model.preset(slot) == nil ? Theme.mist.opacity(0.45) : .white)
                        .frame(width: 22, height: 22)
                        .background(Theme.inkLift, in: Circle())
                }
                .buttonStyle(.plain)
                .help(model.preset(slot)?.name ?? "Empty desk")
            }
        }
    }

    private func modeChip(_ key: String, _ title: String, _ mode: WorkMode) -> some View {
        let shape: AdviceShape = {
            switch mode {
            case .coding: return .coding
            case .research: return .research
            case .focus: return .focus
            }
        }()
        return Button {
            model.apply(.mode(mode), on: model.pointerDisplayId)
        } label: {
            HStack(spacing: 6) {
                KeyCap(key)
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.inkLift, in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                model.hoverShape = hovering ? shape : nil
            }
        }
    }

    private func snapChip(_ key: String, _ kind: SnapKind) -> some View {
        Button {
            model.apply(.snap(kind), on: model.pointerDisplayId)
        } label: {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.mist)
                .frame(width: 28, height: 26)
                .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ScreenCard: View {
    let screen: ScreenLive
    let ghosts: [CGRect]
    let ghostLabels: [String]
    let apply: () -> Void
    let onDrag: (PreviewTile, CGRect) -> Void
    var onDragEnd: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(screen.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.mist)
                if screen.pointed {
                    Circle()
                        .fill(Theme.gold)
                        .frame(width: 6, height: 6)
                }
                Spacer()
                Text(screen.advice.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.gold)
            }

            ScreenMap(
                visible: screen.visible,
                tiles: screen.tiles,
                ghosts: ghosts,
                ghostLabels: ghostLabels,
                onDrag: onDrag,
                onDragEnd: onDragEnd
            )
            .frame(height: mapHeight)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture(count: 2, perform: apply)

            HStack {
                Text(screen.advice.line)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mist)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button(action: apply) {
                    HStack(spacing: 6) {
                        Text(screen.advice.verb)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        if screen.pointed { KeyCap("↩") }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.gold.opacity(screen.advice.shape == .empty ? 0.2 : 0.92), in: Capsule())
                    .foregroundStyle(screen.advice.shape == .empty ? Theme.mist : Theme.ink)
                }
                .buttonStyle(.plain)
                .disabled(screen.advice.shape == .empty)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(screen.pointed ? Theme.gold.opacity(0.55) : Theme.hairline, lineWidth: 1)
        }
    }

    private var mapHeight: CGFloat {
        let aspect = screen.visible.height / max(screen.visible.width, 1)
        return min(200, max(132, 300 * aspect))
    }
}

struct ScreenMap: View {
    let visible: CGRect
    let tiles: [PreviewTile]
    var ghosts: [CGRect] = []
    var ghostLabels: [String] = []
    var onDrag: ((PreviewTile, CGRect) -> Void)?
    var onDragEnd: (() -> Void)?
    @State private var dragOrigins: [Int: CGRect] = [:]

    var body: some View {
        GeometryReader { geo in
            let canvas = CGRect(origin: .zero, size: geo.size).insetBy(dx: 7, dy: 7)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.inkLift.opacity(0.9))

                if tiles.isEmpty, ghosts.isEmpty {
                    Text("Empty")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                ForEach(Array(ghosts.enumerated()), id: \.offset) { index, ghost in
                    let projected = LayoutGeometry.project(ghost, from: visible, into: canvas)
                    if projected.width > 6, projected.height > 6 {
                        ghostBlock(
                            label: ghostLabels.indices.contains(index) ? ghostLabels[index] : "",
                            rect: projected
                        )
                    }
                }

                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                    let projected = LayoutGeometry.project(tile.frame, from: visible, into: canvas)
                    if projected.width > 4, projected.height > 4 {
                        tileBlock(tile, rect: projected, canvas: canvas, index: index)
                    }
                }
            }
        }
    }

    private func tileBlock(_ tile: PreviewTile, rect: CGRect, canvas: CGRect, index: Int) -> some View {
        let fill = fill(for: tile.role, index: index)
        return VStack(alignment: .leading, spacing: 2) {
            Text(tile.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(6)
        .frame(width: max(rect.width, 1), height: max(rect.height, 1), alignment: .topLeading)
        .background(fill.opacity(0.9), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .position(x: rect.midX, y: rect.midY)
        .animation(.interpolatingSpring(stiffness: 280, damping: 30), value: tile.frame)
        .gesture(drag(tile, canvas: canvas))
    }

    private func drag(_ tile: PreviewTile, canvas: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let origin = dragOrigins[tile.id, default: tile.frame]
                if dragOrigins[tile.id] == nil {
                    dragOrigins[tile.id] = tile.frame
                }
                let delta = Motion.displayDelta(
                    canvas: canvas.size,
                    visible: visible.size,
                    translation: value.translation
                )
                var next = origin
                next.origin.x += delta.width
                next.origin.y += delta.height
                onDrag?(tile, LayoutGeometry.clamp(next, to: visible))
            }
            .onEnded { _ in
                dragOrigins[tile.id] = nil
                onDragEnd?()
            }
    }

    private func ghostBlock(label: String, rect: CGRect) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.gold.opacity(0.08))
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.gold)
                    .padding(5)
            }
        }
        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.16), value: rect)
    }

    private func fill(for role: WindowRole?, index: Int) -> Color {
        switch role {
        case .editor: return Theme.gold.opacity(0.85)
        case .browser: return Theme.gold.opacity(0.48)
        case .terminal: return Theme.gold.opacity(0.30)
        case nil:
            let tones: [Color] = [
                Color(red: 0.28, green: 0.34, blue: 0.42),
                Color(red: 0.22, green: 0.30, blue: 0.38),
                Color(red: 0.32, green: 0.28, blue: 0.36),
            ]
            return tones[index % tones.count]
        }
    }
}

struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.gold, in: Capsule())
    }
}
