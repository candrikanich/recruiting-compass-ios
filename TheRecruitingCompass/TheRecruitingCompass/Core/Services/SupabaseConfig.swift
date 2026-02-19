import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SupabaseConfig")

private let placeholderURLString = "https://placeholder.supabase.co"
private let placeholderKey = "placeholder-key"

struct SupabaseConfig {
  static let url: URL = {
    let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
    if let url = URL(string: urlString), !urlString.isEmpty, !urlString.contains("placeholder") {
      return url
    }
    #if DEBUG
    logger.warning("SUPABASE_URL not configured - using placeholder (DEBUG only)")
    return URL(string: placeholderURLString)!
    #else
    fatalError("SUPABASE_URL must be set for Release builds. Configure in Scheme → Run → Environment Variables.")
    #endif
  }()

  static let anonKey: String = {
    let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    if !key.isEmpty, key != placeholderKey {
      return key
    }
    #if DEBUG
    logger.warning("SUPABASE_ANON_KEY not configured - using placeholder (DEBUG only)")
    return placeholderKey
    #else
    fatalError("SUPABASE_ANON_KEY must be set for Release builds. Configure in Scheme → Run → Environment Variables.")
    #endif
  }()
}
