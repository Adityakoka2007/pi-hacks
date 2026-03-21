import Foundation

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String

    static let placeholder = SupabaseConfiguration(
        url: URL(string: "https://your-project-id.supabase.co")!,
        anonKey: "your-public-anon-key"
    )
}
