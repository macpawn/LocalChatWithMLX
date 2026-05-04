import Foundation

struct HFCacheDirs {
    let blobs: URL
    let snapshot: URL

    static func prepare(base: URL, model: Model, commit: String) throws -> HFCacheDirs {
        let root     = base.appendingPathComponent(model.hubCacheDirName)
        let blobs    = root.appendingPathComponent("blobs")
        let snapshot = root.appendingPathComponent("snapshots").appendingPathComponent(commit)
        let refs     = root.appendingPathComponent("refs")
        let fm = FileManager.default
        try fm.createDirectory(at: blobs,    withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try fm.createDirectory(at: refs,     withIntermediateDirectories: true)
        let refFile = refs.appendingPathComponent("main")
        if !fm.fileExists(atPath: refFile.path) {
            try commit.write(to: refFile, atomically: true, encoding: .utf8)
        }
        return HFCacheDirs(blobs: blobs, snapshot: snapshot)
    }

    /// Creates a relative symlink at `link` pointing to the blob.
    /// Depth is derived from the number of path components in `relativePath`
    /// so subdirectory files (e.g. "subdir/weights.safetensors") are handled correctly.
    static func ensureSymlink(at link: URL, blobKey: String, relativePath: String) throws {
        let depth = relativePath.components(separatedBy: "/").count
        // depth=1 → "../../blobs/key"  (link is in snapshots/{commit}/)
        // depth=2 → "../../../blobs/key" (link is in snapshots/{commit}/subdir/)
        let prefix = String(repeating: "../", count: depth + 1)
        let target = "\(prefix)blobs/\(blobKey)"
        let parent = link.deletingLastPathComponent()
        let fm = FileManager.default
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try? fm.removeItem(at: link)
        try fm.createSymbolicLink(atPath: link.path, withDestinationPath: target)
    }
}
