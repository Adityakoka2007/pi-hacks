import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await StressNotificationManager.shared.handleDeviceTokenRegistration(deviceToken, supabaseService: nil)
        }
    }
}

@main
struct pi_hacksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(MindMarginTheme.indigo)
        }
    }
}
