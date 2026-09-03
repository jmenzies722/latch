import Carbon
import Foundation

enum PrefKey {
    static let hudKeyCode = "hudKeyCode"
    static let hudModifiers = "hudModifiers"
    static let undoKeyCode = "undoKeyCode"
    static let undoModifiers = "undoModifiers"
}

enum HotkeyDefaults {
    static let hudKey: UInt32 = UInt32(kVK_Space)
    static let hudModifiers: UInt32 = UInt32(controlKey | optionKey)
    static let undoKey: UInt32 = UInt32(kVK_ANSI_Z)
    static let undoModifiers: UInt32 = UInt32(controlKey | optionKey)
}

enum Preferences {
    private static var defaults: UserDefaults { .standard }

    static var hudKeyCode: UInt32 {
        get { uint(PrefKey.hudKeyCode, HotkeyDefaults.hudKey) }
        set { defaults.set(Int(newValue), forKey: PrefKey.hudKeyCode) }
    }

    static var hudModifiers: UInt32 {
        get { uint(PrefKey.hudModifiers, HotkeyDefaults.hudModifiers) }
        set { defaults.set(Int(newValue), forKey: PrefKey.hudModifiers) }
    }

    static var undoKeyCode: UInt32 {
        get { uint(PrefKey.undoKeyCode, HotkeyDefaults.undoKey) }
        set { defaults.set(Int(newValue), forKey: PrefKey.undoKeyCode) }
    }

    static var undoModifiers: UInt32 {
        get { uint(PrefKey.undoModifiers, HotkeyDefaults.undoModifiers) }
        set { defaults.set(Int(newValue), forKey: PrefKey.undoModifiers) }
    }

    static func resetHotkeys() {
        hudKeyCode = HotkeyDefaults.hudKey
        hudModifiers = HotkeyDefaults.hudModifiers
        undoKeyCode = HotkeyDefaults.undoKey
        undoModifiers = HotkeyDefaults.undoModifiers
    }

    private static func uint(_ key: String, _ fallback: UInt32) -> UInt32 {
        guard let stored = defaults.object(forKey: key) as? Int else { return fallback }
        return UInt32(stored)
    }
}
