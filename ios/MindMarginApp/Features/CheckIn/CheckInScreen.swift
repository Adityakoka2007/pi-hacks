import SwiftUI

struct CheckInScreen: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Check-In")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text("How are you feeling today?")
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                }

                if let message = appModel.lastSavedCheckInMessage {
                    MindMarginCard(padding: 16) {
                        HStack {
                            Label(message, systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MindMarginTheme.green)
                            Spacer()
                            Button {
                                appModel.dismissSavedMessage()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MindMarginTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                MindMarginCard {
                    VStack(alignment: .leading, spacing: 22) {
                        MindMarginFivePointScale(title: "Stress level", symbolName: "face.smiling.inverse", value: $appModel.stressLevel)
                        MindMarginFivePointScale(title: "Energy level", symbolName: "bolt.fill", value: $appModel.energyLevel)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Caffeine servings", systemImage: "cup.and.saucer.fill")
                                .font(.headline)
                                .foregroundStyle(MindMarginTheme.textPrimary)

                            HStack {
                                stepperButton(symbol: "minus") {
                                    appModel.caffeineServings = max(0, appModel.caffeineServings - 1)
                                }

                                Spacer()

                                VStack(spacing: 2) {
                                    Text("\(appModel.caffeineServings)")
                                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MindMarginTheme.textPrimary)
                                    Text("servings")
                                        .font(.caption)
                                        .foregroundStyle(MindMarginTheme.textSecondary)
                                }

                                Spacer()

                                stepperButton(symbol: "plus") {
                                    appModel.caffeineServings += 1
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Did yesterday's suggestions help?")
                                .font(.headline)
                                .foregroundStyle(MindMarginTheme.textPrimary)

                            HStack(spacing: 12) {
                                responseButton(title: "Yes, helpful", selected: appModel.helpfulYesterday == true, tint: MindMarginTheme.green) {
                                    appModel.helpfulYesterday = true
                                }

                                responseButton(title: "Not really", selected: appModel.helpfulYesterday == false, tint: MindMarginTheme.orange) {
                                    appModel.helpfulYesterday = false
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Anything else?")
                                .font(.headline)
                                .foregroundStyle(MindMarginTheme.textPrimary)

                            Text("Optional")
                                .font(.caption)
                                .foregroundStyle(MindMarginTheme.textSecondary)

                            TextEditor(text: $appModel.notes)
                                .frame(height: 120)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(MindMarginTheme.border, lineWidth: 1)
                                }
                        }
                    }
                }

                MindMarginCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("You're on a \(appModel.checkInStreak)-day check-in streak!", systemImage: "checkmark")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(MindMarginTheme.textPrimary)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.white)

                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(MindMarginTheme.indigo)
                                    .frame(width: geometry.size.width * appModel.checkInProgress)
                            }
                        }
                        .frame(height: 10)
                    }
                    .padding(18)
                    .background(MindMarginTheme.cardGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                MindMarginPrimaryButton(
                    title: appModel.isSubmittingCheckIn ? "Saving..." : "Complete Check-In",
                    disabled: appModel.isSubmittingCheckIn,
                    action: appModel.saveCheckIn
                )
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(MindMarginTheme.textPrimary)
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MindMarginTheme.border, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private func responseButton(title: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? tint : MindMarginTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? tint.opacity(0.1) : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(selected ? tint : MindMarginTheme.border, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }
}
