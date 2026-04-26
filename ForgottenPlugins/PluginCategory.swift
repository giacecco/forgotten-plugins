import Foundation

enum PluginCategory: String, Codable, CaseIterable {
    case instrument = "Instrument"
    case effect     = "Effect"      // includes analysers and MIDI effects
    case unknown    = "Unknown"

    // AU four-character type codes from AudioComponent.h
    static func fromAUType(_ fourCC: String) -> PluginCategory {
        switch fourCC {
        case "aumu", "aumi":
            return .instrument
        case "aufx", "aumf", "aupn", "auol", "augn", "aulp":
            return .effect
        default:
            return .unknown
        }
    }

    // VST3 subcategory strings from the Steinberg VST3 SDK
    static func fromVST3Subcategories(_ subcategories: [String]) -> PluginCategory {
        for sub in subcategories where sub.hasPrefix("Instrument") {
            return .instrument
        }
        for sub in subcategories where sub.hasPrefix("Fx") || sub == "Spatial" || sub == "Analyzer" {
            return .effect
        }
        return .unknown
    }

    // Read category from an AU bundle's Info.plist without loading the binary.
    static func readFromAUBundle(_ bundlePath: String) -> PluginCategory {
        let plistPath = bundlePath + "/Contents/Info.plist"
        guard
            let plist = NSDictionary(contentsOfFile: plistPath),
            let components = plist["AudioComponents"] as? [[String: Any]],
            let type = components.first?["type"] as? String
        else { return .unknown }
        return fromAUType(type)
    }

    // Read category from a VST3 bundle's moduleinfo.json (VST3 SDK 3.7+).
    // Returns .unknown for older plugins that don't ship the file.
    static func readFromVST3Bundle(_ bundlePath: String) -> PluginCategory {
        let jsonPath = bundlePath + "/Contents/moduleinfo.json"
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let classes = root["classes"] as? [[String: Any]]
        else { return .unknown }
        for cls in classes {
            let subcats = cls["subCategories"] as? [String] ?? []
            let cat = fromVST3Subcategories(subcats)
            if cat != .unknown { return cat }
        }
        return .unknown
    }
}
