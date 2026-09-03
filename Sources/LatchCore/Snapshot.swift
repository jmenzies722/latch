import Foundation

public struct DeskWindow: Codable, Equatable, Sendable {
    public var bundleId: String
    public var title: String
    public var frame: LatchRect
    public var pid: Int32?

    public init(bundleId: String, title: String, frame: LatchRect, pid: Int32? = nil) {
        self.bundleId = bundleId
        self.title = title
        self.frame = frame
        self.pid = pid
    }
}

public struct DeskSnapshot: Codable, Equatable, Sendable {
    public var windows: [DeskWindow]
    public var hiddenBundleIDs: [String]

    public init(windows: [DeskWindow], hiddenBundleIDs: [String] = []) {
        self.windows = windows
        self.hiddenBundleIDs = hiddenBundleIDs
    }
}

public struct NamedPreset: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    public var snapshot: DeskSnapshot

    public init(id: Int, name: String, snapshot: DeskSnapshot) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
    }
}

public struct PresetFile: Codable, Equatable, Sendable {
    public var presets: [NamedPreset]

    public init(presets: [NamedPreset] = []) {
        self.presets = presets
    }
}

public enum SnapshotMatch: Sendable {
    /// Pair each saved window to a live window: pid+bundle, then bundle+title, then unique bundle.
    /// A live window is used at most once.
    public static func assignments<T>(
        saved: [DeskWindow],
        live: [T],
        bundleId: (T) -> String,
        title: (T) -> String,
        pid: (T) -> Int32?
    ) -> [(DeskWindow, T)] {
        var unused = live
        var pairs: [(DeskWindow, T)] = []

        for record in saved {
            if let index = unused.firstIndex(where: { item in
                if let savedPid = record.pid, let livePid = pid(item) {
                    return savedPid == livePid && bundleId(item) == record.bundleId
                }
                return false
            }) {
                pairs.append((record, unused.remove(at: index)))
                continue
            }

            if let index = unused.firstIndex(where: {
                bundleId($0) == record.bundleId && title($0) == record.title
            }) {
                pairs.append((record, unused.remove(at: index)))
                continue
            }

            let sameApp = unused.enumerated().filter { bundleId($0.element) == record.bundleId }
            if sameApp.count == 1, let only = sameApp.first {
                pairs.append((record, unused.remove(at: only.offset)))
            }
        }

        return pairs
    }
}
