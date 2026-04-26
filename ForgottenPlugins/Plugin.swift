import Foundation

enum PluginFormat: String, Codable, CaseIterable {
    case au   = "AU"
    case clap = "CLAP"
    case vst2 = "VST2"
    case vst3 = "VST3"
    case aax  = "AAX"
}

struct Plugin: Codable, Identifiable {
    let id: UUID
    var path: String
    var name: String
    var format: PluginFormat
    var category: PluginCategory
    var manufacturer: String?
    var productURL: String?
    var firstSeenAt: Date
    var lastModifiedAt: Date
    var lastAccessedAt: Date
    var lastConfirmedUsedAt: Date?
    var isDismissed: Bool

    // Custom decoder so existing stored records without `category` default to .unknown.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(UUID.self,          forKey: .id)
        path                = try c.decode(String.self,        forKey: .path)
        name                = try c.decode(String.self,        forKey: .name)
        format              = try c.decode(PluginFormat.self,  forKey: .format)
        category            = try c.decodeIfPresent(PluginCategory.self, forKey: .category) ?? .unknown
        manufacturer        = try c.decodeIfPresent(String.self,        forKey: .manufacturer)
        productURL          = try c.decodeIfPresent(String.self,        forKey: .productURL)
        firstSeenAt         = try c.decode(Date.self,          forKey: .firstSeenAt)
        lastModifiedAt      = try c.decode(Date.self,          forKey: .lastModifiedAt)
        lastAccessedAt      = try c.decode(Date.self,          forKey: .lastAccessedAt)
        lastConfirmedUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastConfirmedUsedAt)
        isDismissed         = try c.decode(Bool.self,          forKey: .isDismissed)
    }

    init(id: UUID, path: String, name: String, format: PluginFormat, category: PluginCategory,
         manufacturer: String?, productURL: String?, firstSeenAt: Date, lastModifiedAt: Date,
         lastAccessedAt: Date, lastConfirmedUsedAt: Date?, isDismissed: Bool) {
        self.id                  = id
        self.path                = path
        self.name                = name
        self.format              = format
        self.category            = category
        self.manufacturer        = manufacturer
        self.productURL          = productURL
        self.firstSeenAt         = firstSeenAt
        self.lastModifiedAt      = lastModifiedAt
        self.lastAccessedAt      = lastAccessedAt
        self.lastConfirmedUsedAt = lastConfirmedUsedAt
        self.isDismissed         = isDismissed
    }
}

// One entry per unique plugin name, merging all formats.
struct ForgottenPlugin: Identifiable {
    let id: String                  // lowercased name — stable across formats
    let name: String
    let formats: [PluginFormat]     // sorted, all formats found for this name
    let category: PluginCategory
    let manufacturer: String?
    let productURL: String?
    let lastConfirmedUsedAt: Date?  // max across all enabled formats

    var daysSinceLastUse: Int? {
        guard let used = lastConfirmedUsedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: used, to: Date()).day
    }
}
