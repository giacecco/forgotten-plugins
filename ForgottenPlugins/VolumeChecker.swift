import Darwin
import Foundation

struct VolumeStatus {
    let mountPoint: String
    let isNoAtime: Bool
}

enum VolumeChecker {
    static func status(for path: String) -> VolumeStatus? {
        var stats = statfs()
        guard statfs(path, &stats) == 0 else { return nil }
        let mountPoint = withUnsafeBytes(of: stats.f_mntonname) { ptr in
            String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        let noAtime = (Int32(stats.f_flags) & MNT_NOATIME) != 0
        return VolumeStatus(mountPoint: mountPoint, isNoAtime: noAtime)
    }

    // Returns the subset of paths whose underlying volume has noatime set.
    static func noAtimePaths(among paths: [String]) -> [String] {
        var seenMounts: [String: Bool] = [:]
        var affected: [String] = []
        for path in paths {
            guard let s = status(for: path) else { continue }
            if seenMounts[s.mountPoint] == nil {
                seenMounts[s.mountPoint] = s.isNoAtime
            }
            if s.isNoAtime {
                affected.append(path)
            }
        }
        return affected
    }
}
