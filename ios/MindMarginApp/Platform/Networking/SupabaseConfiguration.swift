import Foundation

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String

    /// Must match a URL in Supabase Auth → URL Configuration → Redirect URLs (e.g. `pihacks://auth-callback`).
    var oauthRedirectURL: String {
        ProcessInfo.processInfo.environment["SUPABASE_OAUTH_REDIRECT"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_OAUTH_REDIRECT") as? String
            ?? "pihacks://auth-callback"
    }

    var isPlaceholder: Bool {
        url.absoluteString.contains("your-project-id.supabase.co") || anonKey == "your-public-anon-key"
    }

    static func load() -> SupabaseConfiguration? {
        let environment = ProcessInfo.processInfo.environment

        let urlString = environment["SUPABASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        let anonKey = environment["SUPABASE_ANON_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String

        guard
            let urlString,
            let anonKey,
            let url = URL(string: urlString),
            !urlString.isEmpty,
            !anonKey.isEmpty
        else {
            return nil
        }

        let configuration = SupabaseConfiguration(url: url, anonKey: anonKey)
        return configuration.isPlaceholder ? nil : configuration
    }
}
