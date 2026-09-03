import SwiftUI

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if model.needsPermission {
                permissionCard
            } else {
                modes
                snaps
                presets
            }
            footer
        }
        .padding(20)
        .frame(width: 560)
        .latchGlass()
        .padding(8)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LATCH")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Theme.gold)
            Spacer()
            Text(model.status.isEmpty ? "Lock the desk" : model.status)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .lineLimit(1)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accessibility is required")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text("Latch moves windows that are already open. Grant Accessibility, then hit a chord again. Nothing leaves this Mac.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mist)
                .fixedSize(horizontal: false, vertical: true)
            Button("Grant Accessibility…") {
                Permissions.prompt()
                Permissions.openAccessibilitySettings()
                model.refreshPermission()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.goldDeep)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var modes: some View {
        HStack(spacing: 10) {
            modeTile("Coding", key: "C", subtitle: "Editor + browser + term", kind: .coding) {
                MiniDesk(style: .coding)
            }
            modeTile("Research", key: "R", subtitle: "Browser large, editor", kind: .research) {
                MiniDesk(style: .research)
            }
            modeTile("Focus", key: "F", subtitle: "One window, hide rest", kind: .focus) {
                MiniDesk(style: .focus)
            }
        }
    }

    private func modeTile<Preview: View>(
        _ title: String,
        key: String,
        subtitle: String,
        kind: WorkMode,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        Button {
            model.apply(.mode(kind))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                    KeyCap(key)
                }
                preview()
                    .frame(height: 54)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mist)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var snaps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SNAP")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Theme.mist)
            HStack(spacing: 6) {
                snap("←", .leftHalf)
                snap("→", .rightHalf)
                snap("⌥←", .leftTwoThirds)
                snap("⌥→", .rightTwoThirds)
                snap("4", .leftThird)
                snap("5", .centerThird)
                snap("6", .rightThird)
                snap("M", .maximize)
            }
            HStack(spacing: 6) {
                snap("U", .topLeft)
                snap("I", .topRight)
                snap("J", .bottomLeft)
                snap("K", .bottomRight)
                Spacer()
            }
        }
    }

    private func snap(_ key: String, _ kind: SnapKind) -> some View {
        Button {
            model.apply(.snap(kind))
        } label: {
            VStack(spacing: 4) {
                SnapGlyph(kind: kind)
                    .frame(width: 36, height: 22)
                Text(key)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.mist)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var presets: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { slot in
                let preset = model.preset(slot)
                Button {
                    model.apply(.restorePreset(slot))
                } label: {
                    HStack {
                        KeyCap("\(slot)")
                        Text(preset?.name ?? "Empty")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(preset == nil ? Theme.mist.opacity(0.55) : .white)
                        Spacer()
                    }
                    .padding(10)
                    .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("⇧1–3 save desk")
            Text("Z undo")
            Text("Esc dismiss")
            Spacer()
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(Theme.mist.opacity(0.8))
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

struct MiniDesk: View {
    enum Style { case coding, research, focus }
    let style: Style

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 3
            let w = geo.size.width
            let h = geo.size.height
            let mainW = w * 0.62
            let sideW = w - mainW - gap
            switch style {
            case .coding:
                pane(CGRect(x: 0, y: 0, width: mainW, height: h), fill: Theme.gold.opacity(0.85))
                pane(CGRect(x: mainW + gap, y: 0, width: sideW, height: (h - gap) / 2), fill: Theme.gold.opacity(0.45))
                pane(CGRect(x: mainW + gap, y: (h + gap) / 2, width: sideW, height: (h - gap) / 2), fill: Theme.gold.opacity(0.28))
            case .research:
                pane(CGRect(x: 0, y: 0, width: mainW, height: h), fill: Theme.gold.opacity(0.7))
                pane(CGRect(x: mainW + gap, y: 0, width: sideW, height: h), fill: Theme.gold.opacity(0.35))
            case .focus:
                pane(CGRect(x: 0, y: 0, width: w, height: h), fill: Theme.gold.opacity(0.8))
            }
        }
    }

    @ViewBuilder
    private func pane(_ rect: CGRect, fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(fill)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

struct SnapGlyph: View {
    let kind: SnapKind

    var body: some View {
        Canvas { context, size in
            let box = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            context.stroke(
                Path(roundedRect: box, cornerRadius: 2),
                with: .color(Theme.mist.opacity(0.45)),
                lineWidth: 1
            )
            let fill = LayoutGeometry.snap(kind, on: box)
            context.fill(
                Path(roundedRect: fill.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 1.5),
                with: .color(Theme.gold.opacity(0.85))
            )
        }
    }
}
