import Foundation

struct SupabaseConfig {
  static let url = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://your-project.supabase.co")!
  static let anonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
}
