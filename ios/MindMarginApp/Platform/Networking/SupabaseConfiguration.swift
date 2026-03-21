import Foundation

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String

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
