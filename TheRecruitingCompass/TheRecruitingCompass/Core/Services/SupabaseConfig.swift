import Foundation

struct SupabaseConfig {
  static let url: URL = {
    if let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
       let url = URL(string: urlString) {
      return url
    }

    // Fallback for missing env vars (useful for previews/tests)
    print("⚠️ SUPABASE_URL not configured - using placeholder")
    return URL(string: "https://placeholder.supabase.co")!
  }()

  static let anonKey: String = {
    if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !key.isEmpty {
      return key
    }

    // Fallback for missing env vars (useful for previews/tests)
    print("⚠️ SUPABASE_ANON_KEY not configured - using placeholder")
    return "placeholder-key"
  }()
}
