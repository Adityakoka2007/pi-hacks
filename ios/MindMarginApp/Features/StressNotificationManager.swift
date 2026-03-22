// StressNotificationManager.swift
//
// Manages push notifications for stress spike alerts.
//
// Responsibilities of THIS file (Swift):
//   1. Request notification permission from the user.
//   2. Receive the APNs device token from iOS and upload it to Supabase so the
//      edge function knows where to send pushes.
//   3. Subscribe to Supabase Realtime on the stress_predictions table so that
//      when a new prediction arrives while the app is open or backgrounded,
//      the in-app banner appears immediately without waiting for APNs.
//
// What this file does NOT do (moved to the edge function):
//   - HealthKit background delivery observers   ← removed
//   - BGAppRefreshTask scheduling               ← removed
//   - Spike detection logic                     ← lives in index.ts
//   - Sending push notifications                ← lives in index.ts via APNs
//
// The edge function (index.ts) handles spike detection and APNs delivery
// directly, because it is the only point in the pipeline where the new score,
// the previous score, and the device token are all available at once. It fires
// whether the app is open, backgrounded, or fully closed.
//
// ── Required setup (one-time, outside this file) ──────────────────────────────
//
// 1. Xcode — enable Push Notifications capability (Signing & Capabilities).
//
// 2. App entry point (@main struct) — register for remote notifications:
//
//    @main struct MindMarginApp: App {
//        @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
//        ...
//    }
//
//    class AppDelegate: NSObject, UIApplicationDelegate {
//        func application(_ application: UIApplication,
//                         didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//            Task {
//                await StressNotificationManager.shared.uploadDeviceToken(
//                    deviceToken,
//                    supabase: SupabaseManager.shared.client
//                )
//            }
//        }
//    }
//
// 3. AppModel.bootstrap() — after auth and HealthKit authorization:
//
//    await StressNotificationManager.shared.requestPermission()
//    // Permission grant automatically calls UIApplication.registerForRemoteNotifications()
//    // which triggers AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
//
// 4. AppModel — subscribe to Realtime once authenticated:
//
//    await StressNotificationManager.shared.subscribeToRealtimePredictions(
//        supabase:  SupabaseManager.shared.client,
//        userId:    SupabaseManager.deviceID   // or auth user ID
//    )
//
// 5. Supabase dashboard → Database → Webhooks:
//    Configure a webhook on daily_health_summaries INSERT pointing at the
//    edge function with the service role key. See 003_device_tokens.sql for
//    the exact setup instructions.
//
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
import Supabase
import UIKit
import UserNotifications

@MainActor
final class StressNotificationManager: NSObject, ObservableObject {

    static let shared = StressNotificationManager()

    // MARK: - Published state

    @Published private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Init

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    /// Request notification permission. If granted, registers for remote
    /// notifications so iOS can issue the APNs device token.
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPermissionStatus()
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
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

    // MARK: - Device token upload

    /// Convert the raw APNs token Data to a hex string and upsert it into the
    /// Supabase device_tokens table. The edge function reads from this table
    /// to know where to send push notifications.
    ///
    /// Call this from AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken.
    func uploadDeviceToken(_ tokenData: Data, supabase: SupabaseClient) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()

        guard let userId = try? await supabase.auth.session.user.id.uuidString
                         ?? SupabaseManager.deviceID.uuidString as String?
        else { return }

        do {
            try await supabase
                .from("device_tokens")
                .upsert(
                    ["user_id": userId, "token": token, "updated_at": ISO8601DateFormatter().string(from: Date())],
                    onConflict: "user_id, token"
                )
                .execute()
        } catch {
            // Non-fatal — the edge function will simply have no token to push to.
            // The user will still see updates via Realtime when the app is open.
        }
    }

    // MARK: - Supabase Realtime subscription

    /// Subscribe to INSERT events on stress_predictions for this user.
    /// When a new prediction arrives (written by the edge function after
    /// processing new health data), the app receives it immediately without
    /// needing a round-trip through APNs — useful when the app is foregrounded
    /// or backgrounded.
    ///
    /// The closure receives the new prediction's score (0–10) and risk level
    /// string so the caller can update AppModel and decide whether to show a
    /// local banner.
    func subscribeToRealtimePredictions(
        supabase: SupabaseClient,
        userId: String,
        onNewPrediction: @escaping (_ score: Double, _ riskLevel: String) -> Void
    ) async {
        let channel = await supabase.realtime.channel("stress-predictions-\(userId)")

        await channel.on(
            .postgresChanges,
            filter: PostgresChangesFilter(
                event: .insert,
                schema: "public",
                table: "stress_predictions",
                filter: "user_id=eq.\(userId)"
            )
        ) { payload in
            // Extract score and risk_level from the new row payload
            guard
                let record   = payload.record,
                let score    = record["score"]?.doubleValue,
                let riskLevel = record["risk_level"]?.stringValue
            else { return }

            Task { @MainActor in
                onNewPrediction(score, riskLevel)
            }
        }

        await channel.subscribe()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension StressNotificationManager: UNUserNotificationCenterDelegate {

    /// Show banners even when the app is foregrounded — for example while the
    /// user is looking at the Dashboard when the edge function fires.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// When the user taps a notification, post stressSpikeTapped so AppModel
    /// can open the action plan regardless of which screen is visible.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(
            name:     .stressSpikeTapped,
            object:   nil,
            userInfo: response.notification.request.content.userInfo
        )
        completionHandler()
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted when the user taps a stress spike push notification.
    /// AppModel observes this to open the action plan.
    static let stressSpikeTapped = Notification.Name("com.mindmargin.stressSpikeTapped")
}
