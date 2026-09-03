import AppKit
import Carbon
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var chords: [LatchHotkey: String] = [:]
    @Published var recording: LatchHotkey?
    @Published var launchAtLogin: Bool
    @Published var trusted: Bool
    @Published var loginError: String?
    @Published var bindError: String?

    private var monitor: Any?

    init() {
        launchAtLogin = LoginItem.isEnabled
        trusted = Permissions.isTrusted()
        refresh()
    }

    func refresh() {
        trusted = Permissions.isTrusted()
        launchAtLogin = LoginItem.isEnabled
        chords = [
            .hud: HotkeyCenter.describe(keyCode: Preferences.hudKeyCode, modifiers: Preferences.hudModifiers),
            .undo: HotkeyCenter.describe(keyCode: Preferences.undoKeyCode, modifiers: Preferences.undoModifiers),
        ]
    }

    func setLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            launchAtLogin = LoginItem.isEnabled
            loginError = nil
        } catch {
            launchAtLogin = LoginItem.isEnabled
            loginError = error.localizedDescription
        }
    }

    func beginRecord(_ hotkey: LatchHotkey) {
        recording = hotkey
        bindError = nil
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event)
                return nil
            }
        }
    }

    func resetHotkeys() {
        Preferences.resetHotkeys()
        HotkeyCenter.shared.reregister()
        AppDelegate.shared?.refreshMenu()
        refresh()
    }

    func stopRecording() {
        recording = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    func grant() {
        Permissions.prompt()
        if !Permissions.isTrusted() {
            Permissions.openAccessibilitySettings()
        }
        refresh()
        AppDelegate.shared?.refreshMenu()
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        let modifiers = HotkeyCenter.carbonModifiers(from: event.modifierFlags)
        let hasPrimary = modifiers & UInt32(cmdKey) != 0 || modifiers & UInt32(controlKey) != 0
        guard hasPrimary else {
            bindError = "Add ⌘ or ⌃ so it doesn’t steal typing."
            return
        }
        let key = UInt32(event.keyCode)
        guard let recording else { return }
        switch recording {
        case .hud:
            Preferences.hudKeyCode = key
            Preferences.hudModifiers = modifiers
        case .undo:
            Preferences.undoKeyCode = key
            Preferences.undoModifiers = modifiers
        }
        HotkeyCenter.shared.reregister()
        AppDelegate.shared?.refreshMenu()
        stopRecording()
        refresh()
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            section("Keyboard shortcuts") {
                ForEach(LatchHotkey.allCases, id: \.rawValue) { hotkey in
                    hotkeyRow(hotkey)
                }
                if !HotkeyCenter.shared.hudRegistered {
                    Text("Show HUD didn’t take — another app already owns that chord. Record a new one.")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                if let bindError = model.bindError {
                    Text(bindError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                HStack {
                    Spacer()
                    Button("Reset shortcuts", action: model.resetHotkeys)
                }
            }

            section("Permissions") {
                HStack {
                    Image(systemName: model.trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.trusted ? Color.green : Theme.gold)
                    Text(model.trusted ? "Accessibility allowed" : "Accessibility required to move windows")
                    Spacer()
                    Button(model.trusted ? "Open Settings" : "Grant…") {
                        if model.trusted {
                            Permissions.openAccessibilitySettings()
                        } else {
                            model.grant()
                        }
                    }
                }
            }

            section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLogin($0) }
                ))
                if let loginError = model.loginError {
                    Text(loginError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(22)
        .frame(width: 440)
        .onDisappear { model.stopRecording() }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func hotkeyRow(_ hotkey: LatchHotkey) -> some View {
        HStack {
            Text(hotkey.title)
            Spacer()
            Button(model.recording == hotkey ? "Type shortcut…" : (model.chords[hotkey] ?? "")) {
                if model.recording == hotkey {
                    model.stopRecording()
                } else {
                    model.beginRecord(hotkey)
                }
            }
            .frame(minWidth: 110)
        }
    }
}

enum SettingsWindow {
    @MainActor static var window: NSWindow?

    @MainActor
    static func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(model: SettingsModel()))
            let created = NSWindow(contentViewController: host)
            created.title = "Latch Settings"
            created.styleMask = [.titled, .closable, .fullSizeContentView]
            created.titlebarAppearsTransparent = true
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        } else if let host = window?.contentViewController as? NSHostingController<SettingsView> {
            host.rootView.model.refresh()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
