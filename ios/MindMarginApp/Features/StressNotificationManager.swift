import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class StressNotificationManager: NSObject, ObservableObject {

    static let shared = StressNotificationManager()

    @Published private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined

    private var pendingDeviceTokenData: Data?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshPermissionStatus() }
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPermissionStatus()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            await refreshPermissionStatus()
        }
    }

    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    var isPermissionGranted: Bool {
        permissionStatus == .authorized || permissionStatus == .provisional
    }

    func handleDeviceTokenRegistration(_ tokenData: Data, supabaseService: SupabaseService?) async {
        pendingDeviceTokenData = tokenData
        await syncPendingDeviceTokenIfPossible(using: supabaseService)
    }

    func syncPendingDeviceTokenIfPossible(using supabaseService: SupabaseService?) async {
        guard let tokenData = pendingDeviceTokenData else { return }
        guard let supabaseService, supabaseService.isAuthenticated, let userId = supabaseService.userId else { return }

        let token = tokenData.map { String(format: "%02x", $0) }.joined()

        do {
            try await supabaseService.upsertDeviceToken(userId: userId, token: token)
            pendingDeviceTokenData = nil
        } catch {
            print("[MindMargin] Device token upload failed: \(error.localizedDescription)")
        }
    }

    func postLocalSpikeNotification(score: Double, riskLevel: String) {
        guard isPermissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Stress Spike Detected"
        content.body = "Your stress score jumped to \(Int(score))/10 (\(riskLevel) risk). Tap to see your action plan."
        content.sound = .default
        content.userInfo = ["score": score, "risk_level": riskLevel]

        let request = UNNotificationRequest(
            identifier: "stress-spike-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

extension StressNotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(
            name: .stressSpikeTapped,
            object: nil,
            userInfo: response.notification.request.content.userInfo
        )
        completionHandler()
    }
}

extension Notification.Name {
    static let stressSpikeTapped = Notification.Name("com.mindmargin.stressSpikeTapped")
}
