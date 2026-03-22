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

    /// Loads credentials in order: Xcode scheme env → Info.plist → `SupabaseSecrets.plist` in the app bundle.
    /// Note: `backend/supabase/.env` is **not** read on iOS; use scheme variables, Info keys, or the plist.
    static func load() -> SupabaseConfiguration? {
        let env = ProcessInfo.processInfo.environment

        var urlString = trimmed(env["SUPABASE_URL"])
        var anonKey = trimmed(env["SUPABASE_ANON_KEY"])

        if urlString == nil {
            urlString = trimmed(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
        }
        if anonKey == nil {
            anonKey = trimmed(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)
        }

        if let secrets = loadSupabaseSecretsPlist() {
            if urlString == nil {
                urlString = trimmed(secrets.url)
            }
            if anonKey == nil {
                anonKey = trimmed(secrets.anonKey)
            }
        }

        if var u = urlString, !u.isEmpty, !u.contains("://") {
            u = "https://" + u
            urlString = u
        }

        guard
            let urlString,
            let anonKey,
            !urlString.isEmpty,
            !anonKey.isEmpty,
            let url = URL(string: urlString)
        else {
            return nil
        }

        guard url.scheme == "https" || url.scheme == "http" else {
            return nil
        }

        let configuration = SupabaseConfiguration(url: url, anonKey: anonKey)
        return configuration.isPlaceholder ? nil : configuration
    }

    private static func trimmed(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func loadSupabaseSecretsPlist() -> (url: String?, anonKey: String?)? {
        guard let plistURL = Bundle.main.url(forResource: "SupabaseSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            return nil
        }
        let u = dict["SUPABASE_URL"] as? String
        let k = dict["SUPABASE_ANON_KEY"] as? String
        if u == nil && k == nil { return nil }
        return (u, k)
    }
}
