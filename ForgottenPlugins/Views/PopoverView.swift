import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: PluginStore
    @ObservedObject var preferences: Preferences
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if showingSettings {
                settingsPanel
                Divider()
            }
            if !store.noAtimeDirectories.isEmpty {
                noAtimeWarning
                Divider()
            }
            contentArea
        }
        .frame(width: 320, height: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("Forgotten Plugins")
                .font(.headline)
            Spacer()
            if !visibleForgottenPlugins.isEmpty {
                Text("\(visibleForgottenPlugins.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "gearshape.fill" : "gearshape")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Format preferences")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            settingsSection(label: "Formats") {
                ForEach(PluginFormat.allCases, id: \.self) { format in
                    toggleFor(format.rawValue,
                              isOn: preferences.enabledFormats.contains(format)) { enabled in
                        if enabled { preferences.enabledFormats.insert(format) }
                        else       { preferences.enabledFormats.remove(format) }
                    }
                }
            }
            Divider()
            settingsSection(label: "Types") {
                ForEach(PluginCategory.allCases, id: \.self) { category in
                    toggleFor(category.rawValue,
                              isOn: preferences.enabledCategories.contains(category)) { enabled in
                        if enabled { preferences.enabledCategories.insert(category) }
                        else       { preferences.enabledCategories.remove(category) }
                    }
                }
            }
            Divider()
            toggleFor("Hide never used", isOn: preferences.hideNeverUsed) {
                preferences.hideNeverUsed = $0
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Threshold")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    TextField("", value: $preferences.forgottenThresholdDays, formatter: {
                        let f = NumberFormatter()
                        f.minimum = 1
                        f.allowsFloats = false
                        return f
                    }())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)
                    Text("days without use")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func settingsSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                content()
            }
        }
    }

    private func toggleFor(_ label: String, isOn: Bool, onChange: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: onChange)) {
            Text(label).font(.caption).lineLimit(1)
        }
        .toggleStyle(.checkbox)
    }

    private var noAtimeWarning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.callout)
            Text("Access timestamps are disabled on some plugin volumes. Usage tracking is unavailable for those directories.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.08))
    }

    @ViewBuilder
    private var contentArea: some View {
        if visibleForgottenPlugins.isEmpty {
            emptyState
        } else {
            pluginList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No forgotten plugins")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pluginList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleForgottenPlugins) { plugin in
                    PluginRowView(plugin: plugin) {
                        store.dismiss(plugin)
                    }
                    Divider()
                        .padding(.leading, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var visibleForgottenPlugins: [ForgottenPlugin] {
        var result = store.forgottenPlugins(for: preferences.enabledFormats, categories: preferences.enabledCategories, thresholdDays: preferences.forgottenThresholdDays)
        if preferences.hideNeverUsed {
            result = result.filter { $0.lastConfirmedUsedAt != nil }
        }
        return result
    }
}

struct PluginRowView: View {
    let plugin: ForgottenPlugin
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(plugin.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    ForEach(plugin.formats, id: \.self) { format in
                        Text(format.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Text(lastUsedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Ignore this plugin")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var lastUsedLabel: String {
        guard let days = plugin.daysSinceLastUse else { return "never confirmed used" }
        if days == 0 { return "used today" }
        if days == 1 { return "1 day ago" }
        return "\(days) days ago"
    }
}
