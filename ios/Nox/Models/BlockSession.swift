import Foundation

struct BlockSession: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endsAt: Date?
    let isActive: Bool
    let unlockMethod: String
}
