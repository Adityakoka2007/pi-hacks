import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text("Manage your preferences and privacy")
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                }

                SettingsSection(title: "Data Sources") {
                    SettingsRow(symbolName: "heart.fill", tint: MindMarginTheme.red, label: "Apple Health", value: appModel.isHealthAuthorized ? "Connected" : "Not connected")
                    SettingsRow(symbolName: "calendar", tint: MindMarginTheme.blue, label: "Calendar", value: appModel.isCalendarAuthorized ? "Connected" : "Not connected")
                    SettingsRow(symbolName: appModel.backendStatus.isConnected ? "link.circle.fill" : "externaldrive.badge.exclamationmark", tint: appModel.backendStatus.isConnected ? MindMarginTheme.green : MindMarginTheme.orange, label: "Supabase", value: appModel.backendStatus.label)
                }

                SettingsSection(title: "Preferences") {
                    SettingsRow(symbolName: "bell.fill", tint: MindMarginTheme.orange, label: "Check-in reminder", value: appModel.reminderTimeLabel)
                    SettingsRow(symbolName: "message.fill", tint: Color(hex: 0x7C3AED), label: "Communication style", value: appModel.communicationStyle.rawValue)
                    SettingsRow(symbolName: "graduationcap.fill", tint: MindMarginTheme.indigo, label: "Student type", value: appModel.studentType.rawValue)
                }

                SettingsSection(title: "Privacy & Data") {
                    MindMarginCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(MindMarginTheme.green.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "lock.shield.fill")
                                        .font(.headline)
                                        .foregroundStyle(MindMarginTheme.green)
                                }

                                Text("Privacy-first design")
                                    .font(.headline)
                                    .foregroundStyle(MindMarginTheme.textPrimary)
                            }

                            Text(appModel.backendStatus.detail)
                                .font(.subheadline)
                                .foregroundStyle(MindMarginTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    SettingsRow(symbolName: "square.and.arrow.up", tint: MindMarginTheme.textSecondary, label: "Export your data")
                    SettingsRow(symbolName: "trash.fill", tint: MindMarginTheme.red, label: "Delete all data", danger: true)
                }

                SettingsSection(title: "About") {
                    MindMarginCard(padding: 18) {
                        VStack(spacing: 8) {
                            Text("MindMargin")
                                .font(.headline)
                                .foregroundStyle(MindMarginTheme.textPrimary)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundStyle(MindMarginTheme.textSecondary)

                            HStack(spacing: 16) {
                                Button("Privacy Policy") {}
                                Button("Terms") {}
                                Button("Support") {}
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(MindMarginTheme.indigo)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MindMarginTheme.textPrimary)

            content
        }
    }
}

private struct SettingsRow: View {
    let symbolName: String
    let tint: Color
    let label: String
    var value: String?
    var danger = false

    var body: some View {
        Button {
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                        .frame(width: 38, height: 38)

                    Image(systemName: symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }

                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(danger ? MindMarginTheme.red : MindMarginTheme.textPrimary)

                Spacer()

                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MindMarginTheme.textTertiary)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MindMarginTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
