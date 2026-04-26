import Darwin
import Foundation

struct DirectorySpec {
    let path: String
    let format: PluginFormat
    let bundleExtension: String
}

struct ScannedPlugin {
    let name: String
    let path: String
    let format: PluginFormat
    let category: PluginCategory
    let atime: Date
    let mtime: Date
}

enum PluginScanner {
    // Access more than this many seconds after modification is treated as genuine DAW usage,
    // not a side-effect of installation. See README for full rationale.
    static let genuineUsageMargin: TimeInterval = 300

    static let directories: [DirectorySpec] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            DirectorySpec(path: "/Library/Audio/Plug-Ins/Components",                   format: .au,   bundleExtension: "component"),
            DirectorySpec(path: "\(home)/Library/Audio/Plug-Ins/Components",            format: .au,   bundleExtension: "component"),
            DirectorySpec(path: "/Library/Audio/Plug-Ins/VST",                          format: .vst2, bundleExtension: "vst"),
            DirectorySpec(path: "\(home)/Library/Audio/Plug-Ins/VST",                   format: .vst2, bundleExtension: "vst"),
            DirectorySpec(path: "/Library/Audio/Plug-Ins/VST3",                         format: .vst3, bundleExtension: "vst3"),
            DirectorySpec(path: "\(home)/Library/Audio/Plug-Ins/VST3",                  format: .vst3, bundleExtension: "vst3"),
            DirectorySpec(path: "/Library/Audio/Plug-Ins/CLAP",                         format: .clap, bundleExtension: "clap"),
            DirectorySpec(path: "\(home)/Library/Audio/Plug-Ins/CLAP",                  format: .clap, bundleExtension: "clap"),
            DirectorySpec(path: "/Library/Application Support/Avid/Audio/Plug-Ins",     format: .aax,  bundleExtension: "aaxplugin"),
            DirectorySpec(path: "\(home)/Documents/Avid/Audio/Plug-Ins",                format: .aax,  bundleExtension: "aaxplugin"),
        ]
    }()

    static func scan() -> [ScannedPlugin] {
        let fm = FileManager.default
        var results: [ScannedPlugin] = []

        for spec in directories {
            guard fm.fileExists(atPath: spec.path) else { continue }
            let items = (try? fm.contentsOfDirectory(atPath: spec.path)) ?? []
            for item in items {
                guard item.hasSuffix("." + spec.bundleExtension) else { continue }
                let bundlePath = spec.path + "/" + item
                let name = String(item.dropLast(spec.bundleExtension.count + 1))
                guard let (atime, mtime) = readTimestamps(bundlePath: bundlePath, name: name) else { continue }
                let category = readCategory(bundlePath: bundlePath, format: spec.format)
                results.append(ScannedPlugin(name: name, path: bundlePath, format: spec.format, category: category, atime: atime, mtime: mtime))
            }
        }
        return results
    }

    static func readCategory(bundlePath: String, format: PluginFormat) -> PluginCategory {
        switch format {
        case .au:   return PluginCategory.readFromAUBundle(bundlePath)
        case .vst3: return PluginCategory.readFromVST3Bundle(bundlePath)
        case .vst2, .clap, .aax: return .unknown
        }
    }

    static func isGenuineUsage(atime: Date, mtime: Date) -> Bool {
        atime.timeIntervalSince(mtime) > genuineUsageMargin
    }

    private static func readTimestamps(bundlePath: String, name: String) -> (atime: Date, mtime: Date)? {
        let candidates = [
            bundlePath + "/Contents/MacOS/" + name,
            bundlePath,
        ]
        var st = stat()
        for path in candidates {
            if stat(path, &st) == 0 {
                let atime = Date(timeIntervalSince1970: TimeInterval(st.st_atimespec.tv_sec))
                let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                return (atime, mtime)
            }
        }
        return nil
    }
}
