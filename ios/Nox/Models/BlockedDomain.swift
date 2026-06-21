import Foundation

struct BlockedDomain: Codable, Identifiable {
    let id: UUID
    let domain: String
    let createdAt: Date
}
