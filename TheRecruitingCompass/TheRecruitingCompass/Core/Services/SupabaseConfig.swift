import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SupabaseConfig")

struct SupabaseConfig {
  static let url: URL = {
    if let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
       let url = URL(string: urlString) {
      return url
    }

    // Fallback for missing env vars (useful for previews/tests)
    logger.warning("SUPABASE_URL not configured - using placeholder")
    return URL(string: "https://placeholder.supabase.co")!
  }()

  static let anonKey: String = {
    if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !key.isEmpty {
      return key
    }

    // Fallback for missing env vars (useful for previews/tests)
    logger.warning("SUPABASE_ANON_KEY not configured - using placeholder")
    return "placeholder-key"
  }()
}
