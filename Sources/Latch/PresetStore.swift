import Foundation

@MainActor
final class PresetStore {
    static let shared = PresetStore()

    private(set) var presets: [NamedPreset] = []

    private var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = root.appendingPathComponent(ProductIdentity.supportFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("presets.json")
    }

    private init() {
        load()
    }

    func preset(id: Int) -> NamedPreset? {
        presets.first { $0.id == id }
    }

    func save(id: Int, name: String, snapshot: DeskSnapshot) {
        let preset = NamedPreset(id: id, name: name, snapshot: snapshot)
        if let index = presets.firstIndex(where: { $0.id == id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
            presets.sort { $0.id < $1.id }
        }
        persist()
    }

    func clear(id: Int) {
        presets.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        presets = (try? JSONDecoder().decode(PresetFile.self, from: data))?.presets ?? []
    }

    private func persist() {
        let file = PresetFile(presets: presets)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
