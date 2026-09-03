import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var permissionItem: NSMenuItem?
    private var hudItem: NSMenuItem?
    private var undoItem: NSMenuItem?
    private var presetMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        HotkeyCenter.shared.start()
        _ = PresetStore.shared
        buildStatusItem()
        refreshMenu()
    }

    func refreshMenu() {
        let trusted = Permissions.isTrusted()
        permissionItem?.isHidden = trusted
        label(hudItem, base: "Show HUD", key: Preferences.hudKeyCode, modifiers: Preferences.hudModifiers)
        label(undoItem, base: "Undo Last Layout", key: Preferences.undoKeyCode, modifiers: Preferences.undoModifiers)
        rebuildPresets()
        statusItem?.button?.toolTip = trusted
            ? "\(ProductIdentity.displayName) — \(HotkeyCenter.describe(keyCode: Preferences.hudKeyCode, modifiers: Preferences.hudModifiers))"
            : "\(ProductIdentity.displayName) — Accessibility required"
    }

    func menuWillOpen(_ menu: NSMenu) {
        FrontMemory.capture()
        refreshMenu()
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: ProductIdentity.displayName)
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self

        let permission = NSMenuItem(
            title: "Grant Accessibility…",
            action: #selector(grantAccess),
            keyEquivalent: ""
        )
        permissionItem = permission
        menu.addItem(permission)

        let hud = NSMenuItem(title: "Show HUD", action: #selector(showHUD), keyEquivalent: " ")
        hudItem = hud
        menu.addItem(hud)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Coding", action: #selector(coding), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Research", action: #selector(research), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Focus", action: #selector(focusDesk), keyEquivalent: "f"))

        let snaps = NSMenu()
        snaps.addItem(menuItem("Left Half", #selector(snapLeft), "←"))
        snaps.addItem(menuItem("Right Half", #selector(snapRight), "→"))
        snaps.addItem(menuItem("Left Two-Thirds", #selector(snapLeftTwo), ""))
        snaps.addItem(menuItem("Right Two-Thirds", #selector(snapRightTwo), ""))
        snaps.addItem(menuItem("Left Third", #selector(snapLeftThird), "4"))
        snaps.addItem(menuItem("Center Third", #selector(snapCenterThird), "5"))
        snaps.addItem(menuItem("Right Third", #selector(snapRightThird), "6"))
        snaps.addItem(menuItem("Maximize", #selector(snapMax), "m"))
        snaps.addItem(.separator())
        snaps.addItem(menuItem("Top Left", #selector(snapTL), "u"))
        snaps.addItem(menuItem("Top Right", #selector(snapTR), "i"))
        snaps.addItem(menuItem("Bottom Left", #selector(snapBL), "j"))
        snaps.addItem(menuItem("Bottom Right", #selector(snapBR), "k"))
        snaps.items.forEach { $0.target = self }
        let snapRoot = NSMenuItem(title: "Snap", action: nil, keyEquivalent: "")
        snapRoot.submenu = snaps
        menu.addItem(snapRoot)

        let undo = NSMenuItem(title: "Undo Last Layout", action: #selector(undoLayout), keyEquivalent: "z")
        undoItem = undo
        menu.addItem(undo)

        menu.addItem(.separator())
        let presets = NSMenu()
        presetMenu = presets
        let presetRoot = NSMenuItem(title: "Desks", action: nil, keyEquivalent: "")
        presetRoot.submenu = presets
        menu.addItem(presetRoot)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(ProductIdentity.displayName)", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func rebuildPresets() {
        guard let presetMenu else { return }
        presetMenu.removeAllItems()
        for slot in 1...3 {
            let preset = PresetStore.shared.preset(id: slot)
            let title = preset.map { "\($0.id). \($0.name)" } ?? "\(slot). Empty"
            let restore = NSMenuItem(title: title, action: #selector(restorePreset(_:)), keyEquivalent: "\(slot)")
            restore.tag = slot
            restore.target = self
            restore.isEnabled = preset != nil
            presetMenu.addItem(restore)
        }
        presetMenu.addItem(.separator())
        for slot in 1...3 {
            let save = NSMenuItem(title: "Save as Desk \(slot)", action: #selector(savePreset(_:)), keyEquivalent: "")
            save.tag = slot
            save.target = self
            presetMenu.addItem(save)
        }
    }

    private func menuItem(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }

    private func label(_ item: NSMenuItem?, base: String, key: UInt32, modifiers: UInt32) {
        item?.title = "\(base)  \(HotkeyCenter.describe(keyCode: key, modifiers: modifiers))"
        item?.keyEquivalent = ""
    }

    @objc private func grantAccess() {
        Permissions.prompt()
        if !Permissions.isTrusted() {
            Permissions.openAccessibilitySettings()
        }
        refreshMenu()
    }

    @objc private func showHUD() { HUDController.shared.toggle() }
    @objc private func coding() { LayoutService.shared.perform(.mode(.coding)) }
    @objc private func research() { LayoutService.shared.perform(.mode(.research)) }
    @objc private func focusDesk() { LayoutService.shared.perform(.mode(.focus)) }
    @objc private func undoLayout() { LayoutService.shared.perform(.undo) }
    @objc private func snapLeft() { LayoutService.shared.perform(.snap(.leftHalf)) }
    @objc private func snapRight() { LayoutService.shared.perform(.snap(.rightHalf)) }
    @objc private func snapLeftTwo() { LayoutService.shared.perform(.snap(.leftTwoThirds)) }
    @objc private func snapRightTwo() { LayoutService.shared.perform(.snap(.rightTwoThirds)) }
    @objc private func snapLeftThird() { LayoutService.shared.perform(.snap(.leftThird)) }
    @objc private func snapCenterThird() { LayoutService.shared.perform(.snap(.centerThird)) }
    @objc private func snapRightThird() { LayoutService.shared.perform(.snap(.rightThird)) }
    @objc private func snapMax() { LayoutService.shared.perform(.snap(.maximize)) }
    @objc private func snapTL() { LayoutService.shared.perform(.snap(.topLeft)) }
    @objc private func snapTR() { LayoutService.shared.perform(.snap(.topRight)) }
    @objc private func snapBL() { LayoutService.shared.perform(.snap(.bottomLeft)) }
    @objc private func snapBR() { LayoutService.shared.perform(.snap(.bottomRight)) }
    @objc private func showSettings() { SettingsWindow.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func restorePreset(_ sender: NSMenuItem) {
        LayoutService.shared.perform(.restorePreset(sender.tag))
    }

    @objc private func savePreset(_ sender: NSMenuItem) {
        LayoutService.shared.perform(.savePreset(sender.tag))
    }
}
