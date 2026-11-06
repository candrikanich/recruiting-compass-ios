import Foundation

/// Single source of truth for whose `player_profiles` row the public-profile editor targets.
/// Every entry point routes through here so a parent can never be pointed at their own row.
enum PublicProfileTarget {
    /// Parent with a selected athlete → that athlete; parent with none → nil (the editor shows the
    /// select-an-athlete notice); anyone else → their own id.
    static func userId(user: User?, selectedAthleteUserId: String?) -> String? {
        user?.role == .parent ? selectedAthleteUserId : user?.id
    }
}
