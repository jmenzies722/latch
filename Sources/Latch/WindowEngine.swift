@preconcurrency import ApplicationServices
import AppKit
import CoreGraphics

struct LiveWindow {
    var element: AXUIElement
    var pid: pid_t
    var title: String
    var appName: String
    var bundleId: String
    var frame: CGRect
    var focused: Bool
    var minimized: Bool
}

enum WindowEngine {
    static func displays() -> [DisplayBox] {
        NSScreen.screens.enumerated().map { index, screen in
            DisplayBox(id: index, frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }

    static func pointerDisplay() -> DisplayBox? {
        LayoutGeometry.pointerDisplay(at: NSEvent.mouseLocation, in: displays())
    }

    static func pointerScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    static func enumerate() -> [LiveWindow] {
        guard Permissions.isTrusted() else { return [] }
        let focused = focusedWindow()
        var listed: [LiveWindow] = []
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = copyList(axApp, kAXWindowsAttribute as CFString) else { continue }
            for window in windows {
                guard isStandard(window) else { continue }
                guard let frame = try? frame(of: window) else { continue }
                listed.append(
                    LiveWindow(
                        element: window,
                        pid: app.processIdentifier,
                        title: copyString(window, kAXTitleAttribute as CFString) ?? "",
                        appName: app.localizedName ?? "App",
                        bundleId: app.bundleIdentifier ?? "",
                        frame: frame,
                        focused: focused.map { CFEqual($0, window) } ?? false,
                        minimized: copyBool(window, kAXMinimizedAttribute as CFString)
                    )
                )
            }
        }
        return listed
    }

    static func visibleOnDisplay(_ display: DisplayBox) -> [LiveWindow] {
        let all = displays()
        return enumerate().filter { !$0.minimized && LayoutGeometry.isOnDisplay($0.frame, display: display, in: all) }
    }

    static func targetOnDisplay(_ display: DisplayBox) -> LiveWindow? {
        let windows = decorate(visibleOnDisplay(display))
        return windows.first(where: \.focused) ?? windows.first
    }

    static func decorate(_ windows: [LiveWindow]) -> [LiveWindow] {
        guard let memory = FrontMemory.window else { return windows }
        return windows.map { window in
            var next = window
            next.focused =
                CFEqual(window.element, memory.element)
                || (window.pid == memory.pid && window.bundleId == memory.bundleId && window.title == memory.title)
            return next
        }
    }

    static func fitted(_ rect: CGRect) -> CGRect {
        LayoutGeometry.clampRestored(rect, displays: displays(), fallback: pointerDisplay())
    }

    static func apply(_ rect: CGRect, to window: AXUIElement) {
        let axRect = appKitToAX(fitted(rect))
        var origin = axRect.origin
        var size = axRect.size
        guard let position = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
    }

    static func raise(_ window: LiveWindow) {
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    static func hideApp(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.hide()
    }

    static func unhideApp(bundleId: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.unhide()
    }

    private static func focusedWindow() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var app: CFTypeRef?
        let appStatus = AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &app)
        guard appStatus == .success, let app, CFGetTypeID(app) == AXUIElementGetTypeID() else { return nil }
        let appElement = unsafeBitCast(app, to: AXUIElement.self)
        var window: CFTypeRef?
        let windowStatus = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &window)
        guard windowStatus == .success, let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(window, to: AXUIElement.self)
    }

    private static func frame(of window: AXUIElement) throws -> CGRect {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        let positionStatus = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        let sizeStatus = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        guard positionStatus == .success, sizeStatus == .success else {
            throw EngineError.readFailed
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        if let positionRef {
            AXValueGetValue(unsafeBitCast(positionRef, to: AXValue.self), .cgPoint, &position)
        }
        if let sizeRef {
            AXValueGetValue(unsafeBitCast(sizeRef, to: AXValue.self), .cgSize, &size)
        }
        return axToAppKit(CGRect(origin: position, size: size))
    }

    private static func isStandard(_ window: AXUIElement) -> Bool {
        let role = copyString(window, kAXRoleAttribute as CFString)
        guard role == (kAXWindowRole as String) else { return false }
        let subrole = copyString(window, kAXSubroleAttribute as CFString)
        if let subrole, !subrole.isEmpty, subrole != (kAXStandardWindowSubrole as String) {
            return false
        }
        return true
    }

    private static func primaryMaxY() -> CGFloat {
        NSScreen.screens.first { $0.frame.origin == .zero }?.frame.maxY
            ?? NSScreen.main?.frame.maxY
            ?? 0
    }

    private static func axToAppKit(_ rect: CGRect) -> CGRect {
        let maxY = primaryMaxY()
        let origin = CGPoint(x: rect.origin.x, y: maxY - (rect.origin.y + rect.height))
        return CGRect(x: origin.x, y: origin.y, width: rect.width, height: rect.height)
    }

    private static func appKitToAX(_ rect: CGRect) -> CGRect {
        let maxY = primaryMaxY()
        let topLeft = CGPoint(x: rect.origin.x, y: maxY - rect.maxY)
        return CGRect(x: topLeft.x, y: topLeft.y, width: rect.width, height: rect.height)
    }

    private static func copyList(_ element: AXUIElement, _ attribute: CFString) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let array = value as? [AnyObject]
        else { return nil }
        return array.compactMap { item in
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else { return nil }
            return (item as! AXUIElement)
        }
    }

    private static func copyString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private static func copyBool(_ element: AXUIElement, _ attribute: CFString) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private enum EngineError: Error {
        case readFailed
    }
}
