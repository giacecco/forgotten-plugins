import Foundation

enum AnthropicClient {
    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    // Asks Claude for the manufacturer of each plugin name in a single batch request.
    // Returns a mapping of plugin name → manufacturer for the ones it recognises.
    static func resolveManufacturers(for names: [String]) async -> [String: String] {
        guard let apiKey = readAPIKey(), !names.isEmpty else { return [:] }

        let list = names.map { "- \($0)" }.joined(separator: "\n")
        let prompt = """
        For each audio plugin name below, identify the company or developer that made it.
        Return a JSON object where each key is the exact plugin name and the value is the manufacturer name.
        Use null for any you are genuinely unsure about. Respond with only valid JSON, no other text.

        \(list)
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]

        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else { return [:] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",        forHTTPHeaderField: "anthropic-version")
        request.httpBody = requestData

        guard
            let (data, _) = try? await URLSession.shared.data(for: request),
            let response  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content   = response["content"] as? [[String: Any]],
            let text      = content.first?["text"] as? String,
            let jsonData  = text.data(using: .utf8),
            let result    = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return [:] }

        return result.compactMapValues { $0 as? String }
    }

    // Reads ANTHROPIC_API_KEY from the environment or from
    // ~/Library/Application Support/ForgottenPlugins/.env
    static func readAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            return key
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let envURL = appSupport.appendingPathComponent("ForgottenPlugins/.env")
        guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else { return nil }
        return parseEnvKey("ANTHROPIC_API_KEY", from: contents)
    }

    private static func parseEnvKey(_ key: String, from contents: String) -> String? {
        for line in contents.components(separatedBy: .newlines) {
            // Strip any surrounding quotes wrapping the whole line
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: "\"' \t"))
            guard trimmed.hasPrefix(key + "=") else { continue }
            let value = String(trimmed.dropFirst(key.count + 1))
                .trimmingCharacters(in: .init(charactersIn: "\"' "))
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
