import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        Group {
            switch appModel.onboardingStep {
            case .welcome:
                WelcomeScreen()
            case .permissions:
                PermissionsScreen()
            case .personalization:
                PersonalizationScreen()
            case .complete:
                EmptyView()
            }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

private struct WelcomeScreen: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        ZStack {
            MindMarginTheme.heroGradient
                .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 20)
                .offset(x: 150, y: -180)

            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 260, height: 260)
                .blur(radius: 22)
                .offset(x: -160, y: 240)

            VStack(spacing: 0) {
                Spacer(minLength: 44)

                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.2))
                            .frame(width: 88, height: 88)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 10) {
                        Text("MindMargin")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Predict tomorrow's stress risk early and get simple, personalized actions before overload builds.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 36)

                VStack(spacing: 14) {
                    MindMarginFeatureCard(symbolName: "arrow.up.right", title: "Early prediction", description: "Know tomorrow's stress risk before it arrives.")
                    MindMarginFeatureCard(symbolName: "sparkles", title: "Clear explanations", description: "See what is driving your risk levels and where to intervene.")
                    MindMarginFeatureCard(symbolName: "lock.shield", title: "Privacy-first", description: "Your health and schedule signals stay on-device while you test the experience.")
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 24)

                VStack(spacing: 14) {
                    MindMarginPrimaryButton(title: "Get Started", action: appModel.advanceFromWelcome)

                    Button("How it works") {
                        appModel.advanceFromWelcome()
                    }
                    .buttonStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct PermissionsScreen: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                progressDots(activeIndex: 0)
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick setup")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text("MindMargin needs access to a few data sources to predict your stress risk accurately.")
                        .font(.body)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 16) {
                    PermissionCard(
                        symbolName: "heart.fill",
                        tint: MindMarginTheme.indigo,
                        title: "Apple Health",
                        description: "We analyze sleep, activity, resting heart rate, and HRV to detect early stress signals.",
                        items: ["Sleep duration & quality", "Daily activity", "Resting heart rate", "Heart rate variability"],
                        granted: appModel.isHealthAuthorized,
                        action: appModel.grantHealthAccess
                    )

                    PermissionCard(
                        symbolName: "calendar",
                        tint: MindMarginTheme.teal,
                        title: "Calendar",
                        description: "Schedule density helps us predict overload risk and suggest buffer time.",
                        items: ["Event count & duration", "Time between events", "Schedule patterns"],
                        granted: appModel.isCalendarAuthorized,
                        action: appModel.grantCalendarAccess
                    )
                }

                MindMarginCard(padding: 16) {
                    Text("MindMargin can sync daily summaries and recommendations through Supabase when configured, but the app still works locally if backend credentials are missing.")
                        .font(.footnote)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                MindMarginPrimaryButton(
                    title: "Continue",
                    systemImage: "arrow.right",
                    disabled: !appModel.permissionsReady,
                    action: appModel.continueFromPermissions
                )
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(MindMarginTheme.background.ignoresSafeArea())
    }

    private func progressDots(activeIndex: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? MindMarginTheme.indigo : MindMarginTheme.textTertiary.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PermissionCard: View {
    let symbolName: String
    let tint: Color
    let title: String
    let description: String
    let items: [String]
    let granted: Bool
    let action: () -> Void

    var body: some View {
        MindMarginCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                            .frame(width: 48, height: 48)

                        Image(systemName: symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(MindMarginTheme.textPrimary)

                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(MindMarginTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(MindMarginTheme.textTertiary)
                                .frame(width: 4, height: 4)
                            Text(item)
                                .font(.footnote)
                                .foregroundStyle(MindMarginTheme.textSecondary)
                        }
                    }
                }
                .padding(.leading, 62)

                Button(action: action) {
                    HStack(spacing: 8) {
                        if granted {
                            Image(systemName: "checkmark")
                        }
                        Text(granted ? "Granted" : "Grant Access")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(granted ? MindMarginTheme.green : Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.leading, 62)
                .disabled(granted)
            }
        }
    }
}

private struct PersonalizationScreen: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                progressDots(activeIndex: 1)
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Personalize your experience")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text("Help us tailor recommendations to your preferences and schedule.")
                        .font(.body)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 20) {
                    MindMarginCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Daily check-in reminder", systemImage: "clock")
                                .font(.headline)
                                .foregroundStyle(MindMarginTheme.textPrimary)

                            DatePicker(
                                "Reminder",
                                selection: $appModel.reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Communication style", systemImage: "message")
                            .font(.headline)
                            .foregroundStyle(MindMarginTheme.textPrimary)

                        HStack(spacing: 10) {
                            ForEach(MindMarginAppModel.CommunicationStyle.allCases) { style in
                                ChoiceButton(
                                    title: style.rawValue,
                                    isSelected: appModel.communicationStyle == style
                                ) {
                                    appModel.communicationStyle = style
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Student type", systemImage: "graduationcap")
                            .font(.headline)
                            .foregroundStyle(MindMarginTheme.textPrimary)

                        ForEach(MindMarginAppModel.StudentType.allCases) { type in
                            ChoiceRow(
                                title: type.rawValue,
                                isSelected: appModel.studentType == type
                            ) {
                                appModel.studentType = type
                            }
                        }
                    }
                }

                MindMarginPrimaryButton(
                    title: "Get Started",
                    systemImage: "arrow.right",
                    action: appModel.finishOnboarding
                )
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(MindMarginTheme.background.ignoresSafeArea())
    }

    private func progressDots(activeIndex: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? MindMarginTheme.indigo : MindMarginTheme.textTertiary.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? MindMarginTheme.indigo : MindMarginTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? MindMarginTheme.indigo.opacity(0.08) : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? MindMarginTheme.indigo : MindMarginTheme.border, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ChoiceRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(isSelected ? MindMarginTheme.indigo : MindMarginTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(isSelected ? MindMarginTheme.indigo.opacity(0.08) : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? MindMarginTheme.indigo : MindMarginTheme.border, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }
}
