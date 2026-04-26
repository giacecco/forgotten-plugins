import Foundation

class PluginStore: ObservableObject {
    @Published private(set) var plugins: [Plugin] = []
    @Published private(set) var noAtimeDirectories: [String] = []

    private let storageURL: URL

    // Plugins whose atimes all fall within this window are treated as a DAW rescan,
    // not genuine use. See README for rationale.
    private static let rescanWindowSeconds: TimeInterval = 30
    private static let rescanMinCohortSize = 10

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ForgottenPlugins")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("plugins.json")
        load()
    }

    func refresh() {
        checkVolumes()
        let scanned = PluginScanner.scan()
        let rescanPaths = detectRescanCohort(in: scanned)
        let now = Date()
        var byPath = Dictionary(uniqueKeysWithValues: plugins.map { ($0.path, $0) })

        for s in scanned {
            let isRescan = rescanPaths.contains(s.path)
            if var known = byPath[s.path] {
                known.category = s.category
                if s.mtime > known.lastModifiedAt {
                    known.lastModifiedAt = s.mtime
                    known.lastConfirmedUsedAt = nil
                }
                known.lastAccessedAt = s.atime
                if !isRescan && PluginScanner.isGenuineUsage(atime: s.atime, mtime: s.mtime) {
                    if known.lastConfirmedUsedAt.map({ s.atime > $0 }) ?? true {
                        known.lastConfirmedUsedAt = s.atime
                        known.isDismissed = false
                    }
                }
                byPath[s.path] = known
            } else {
                let confirmedUsed: Date? =
                    !isRescan && PluginScanner.isGenuineUsage(atime: s.atime, mtime: s.mtime) ? s.atime : nil
                byPath[s.path] = Plugin(
                    id: UUID(),
                    path: s.path,
                    name: s.name,
                    format: s.format,
                    category: s.category,
                    firstSeenAt: now,
                    lastModifiedAt: s.mtime,
                    lastAccessedAt: s.atime,
                    lastConfirmedUsedAt: confirmedUsed,
                    isDismissed: false
                )
            }
        }

        plugins = Array(byPath.values).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        save()
    }

    func resetAllDismissals() {
        for i in plugins.indices { plugins[i].isDismissed = false }
        save()
    }

    // Dismisses all per-format records sharing this plugin name.
    func dismiss(_ forgotten: ForgottenPlugin) {
        let key = forgotten.id
        for i in plugins.indices where plugins[i].name.lowercased() == key {
            plugins[i].isDismissed = true
        }
        save()
    }

    // Groups by plugin name, filtered by both format and category.
    // Only enabled formats contribute to the "last used" date, so a recently-used
    // disabled format does not silently suppress a suggestion for an enabled one.
    func forgottenPlugins(
        for enabledFormats: Set<PluginFormat>,
        categories enabledCategories: Set<PluginCategory>
    ) -> [ForgottenPlugin] {
        let relevant = plugins.filter {
            !$0.isDismissed &&
            enabledFormats.contains($0.format) &&
            enabledCategories.contains($0.category)
        }
        let grouped = Dictionary(grouping: relevant) { $0.name.lowercased() }
        return grouped.compactMap { key, group -> ForgottenPlugin? in
            let maxUsed = group.compactMap(\.lastConfirmedUsedAt).max()
            let days = maxUsed.map {
                Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
            } ?? Int.max
            guard days >= 90 else { return nil }
            let formats = Array(Set(group.map(\.format))).sorted { $0.rawValue < $1.rawValue }
            let category = group.first(where: { $0.category != .unknown })?.category ?? .unknown
            return ForgottenPlugin(
                id: key,
                name: group.first!.name,
                formats: formats,
                category: category,
                lastConfirmedUsedAt: maxUsed
            )
        }
        .sorted { ($0.lastConfirmedUsedAt ?? .distantPast) < ($1.lastConfirmedUsedAt ?? .distantPast) }
    }

    // Sliding-window scan: if 10+ plugins have atimes within the same 30-second
    // window, that cohort is almost certainly a DAW rescan rather than genuine use.
    private func detectRescanCohort(in scanned: [ScannedPlugin]) -> Set<String> {
        let sorted = scanned.sorted { $0.atime < $1.atime }
        var rescanPaths = Set<String>()
        var windowStart = 0

        for i in 0..<sorted.count {
            while sorted[i].atime.timeIntervalSince(sorted[windowStart].atime) > Self.rescanWindowSeconds {
                windowStart += 1
            }
            if i - windowStart + 1 >= Self.rescanMinCohortSize {
                for j in windowStart...i {
                    rescanPaths.insert(sorted[j].path)
                }
            }
        }
        return rescanPaths
    }

    private func checkVolumes() {
        let existingPaths = PluginScanner.directories
            .map(\.path)
            .filter { FileManager.default.fileExists(atPath: $0) }
        noAtimeDirectories = VolumeChecker.noAtimePaths(among: existingPaths)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        plugins = (try? JSONDecoder().decode([Plugin].self, from: data)) ?? []
    }

    private func save() {
        let data = try? JSONEncoder().encode(plugins)
        try? data?.write(to: storageURL, options: .atomic)
    }
}
