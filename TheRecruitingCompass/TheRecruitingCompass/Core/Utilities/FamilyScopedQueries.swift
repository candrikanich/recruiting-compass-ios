import Foundation
import Supabase

/// Shared PostgREST reads used by multiple feature services.
///
/// Schools/coaches CRUD lives in the owning feature service. This type only
/// covers the family-scoped lookups that were copy-pasted across Offers,
/// Coaches, Interactions, Dashboard, and Schools.
enum FamilyScopedQueries {
  /// Full `schools` rows for a family unit. Matches the historical unscoped
  /// `select()` used by list screens. Pass `orderedByName: true` for the
  /// Schools tab, which sorts at the query.
  static func fetchSchools(
    from client: SupabaseClient,
    familyUnitId: String,
    orderedByName: Bool = false
  ) async throws -> [School] {
    if orderedByName {
      return try await client
        .from("schools")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .order("name")
        .execute()
        .value
    }
    return try await client
      .from("schools")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value
  }

  static func fetchSchool(from client: SupabaseClient, id: String) async throws -> School {
    try await client
      .from("schools")
      .select()
      .eq("id", value: id)
      .single()
      .execute()
      .value
  }
}
