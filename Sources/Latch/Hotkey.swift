import AppKit
import Carbon

enum LatchHotkey: UInt32, CaseIterable {
    case hud = 1
    case undo = 2

    var title: String {
        switch self {
        case .hud: return "Show HUD"
        case .undo: return "Undo last layout"
        }
    }
}

private func latchHotkeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return noErr }
    DispatchQueue.main.async {
        switch hotKeyID.id {
        case LatchHotkey.hud.rawValue:
            HUDController.shared.toggle()
        case LatchHotkey.undo.rawValue:
            LayoutService.shared.undo()
        default:
            break
        }
    }
    return noErr
}

final class HotkeyCenter {
    static let shared = HotkeyCenter()
    static let signature = OSType(0x4C544348) // "LTCH"

    private var handler: EventHandlerRef?
    private var refs: [EventHotKeyRef?] = [nil, nil]
    private(set) var hudRegistered = false
    private(set) var undoRegistered = false

    private init() {}

    func start() {
        installHandler()
        reregister()
    }

    func reregister() {
        for i in refs.indices {
            if let ref = refs[i] {
                UnregisterEventHotKey(ref)
                refs[i] = nil
            }
        }
        refs[0] = register(key: Preferences.hudKeyCode, modifiers: Preferences.hudModifiers, id: LatchHotkey.hud.rawValue)
        refs[1] = register(key: Preferences.undoKeyCode, modifiers: Preferences.undoModifiers, id: LatchHotkey.undo.rawValue)
        hudRegistered = refs[0] != nil
        undoRegistered = refs[1] != nil
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            latchHotkeyCallback,
            1,
            &spec,
            nil,
            &ref
        )
        if status != noErr {
            NSLog("Latch: could not install hotkey listener (%d)", status)
            return
        }
        handler = ref
    }

    private func register(key: UInt32, modifiers: UInt32, id: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            key,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status != noErr {
            NSLog("Latch: could not take hotkey id %u (%d)", id, status)
            return nil
        }
        return ref
    }

    static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(keyCode))
        return parts.joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    static func cocoaModifiers(from carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbon & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbon & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbon & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    static func menuEquivalent(keyCode: UInt32) -> String {
        let name = keyName(keyCode)
        if name.count == 1 { return name.lowercased() }
        switch name {
        case "Space": return " "
        default: return ""
        }
    }

    static func keyName(_ code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space: return "Space"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Escape: return "⎋"
        default: return String(format: "key %d", code)
        }
    }
}
