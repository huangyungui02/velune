import Foundation
import Supabase

private func requiredInfoValue(_ key: String) -> String {
    let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value, !value.isEmpty else {
        fatalError("Missing required Info.plist key: \(key)")
    }
    return value
}

private let supabaseURLString = requiredInfoValue("SUPABASE_URL")
private let supabaseKey = requiredInfoValue("SUPABASE_PUBLISHABLE_KEY")
private let apiBaseURLString = requiredInfoValue("API_BASE_URL")

let supabaseURL = URL(string: supabaseURLString)!
let apiBaseURL = URL(string: apiBaseURLString)!

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )
    )
)
