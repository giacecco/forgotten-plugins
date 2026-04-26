import Foundation

class Preferences: ObservableObject {
    @Published var enabledFormats: Set<PluginFormat> {
        didSet { save() }
    }

    @Published var enabledCategories: Set<PluginCategory> {
        didSet { save() }
    }

    @Published var hideNeverUsed: Bool {
        didSet { save() }
    }

    @Published var forgottenThresholdDays: Int {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    init() {
        if let saved = defaults.array(forKey: "enabledFormats") as? [String] {
            enabledFormats = Set(saved.compactMap(PluginFormat.init(rawValue:)))
        } else {
            enabledFormats = Set(PluginFormat.allCases)
        }

        if let saved = defaults.array(forKey: "enabledCategories") as? [String] {
            enabledCategories = Set(saved.compactMap(PluginCategory.init(rawValue:)))
        } else {
            enabledCategories = Set(PluginCategory.allCases)
        }

        hideNeverUsed = defaults.bool(forKey: "hideNeverUsed")
        let saved = defaults.integer(forKey: "forgottenThresholdDays")
        forgottenThresholdDays = saved > 0 ? saved : 90
    }

    private func save() {
        defaults.set(enabledFormats.map(\.rawValue),    forKey: "enabledFormats")
        defaults.set(enabledCategories.map(\.rawValue), forKey: "enabledCategories")
        defaults.set(hideNeverUsed,                     forKey: "hideNeverUsed")
        defaults.set(forgottenThresholdDays,            forKey: "forgottenThresholdDays")
    }
}
