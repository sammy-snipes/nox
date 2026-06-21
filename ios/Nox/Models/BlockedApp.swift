import Foundation

struct BlockedApp: Codable, Identifiable {
    let id: UUID
    let bundleId: String
    let displayName: String
    let createdAt: Date
}
