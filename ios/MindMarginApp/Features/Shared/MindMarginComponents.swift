import SwiftUI

struct MindMarginCard<Content: View>: View {
    var padding: CGFloat = 20
    let content: Content

    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MindMarginTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MindMarginTheme.border, lineWidth: 1)
        }
    }
}

enum MindMarginRiskBadgeSize {
    case small
    case medium
    case large

    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 10
        case .medium:
            return 12
        case .large:
            return 16
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return 6
        case .medium:
            return 8
        case .large:
            return 10
        }
    }

    var font: Font {
        switch self {
        case .small:
            return .caption.weight(.medium)
        case .medium:
            return .subheadline.weight(.medium)
        case .large:
            return .body.weight(.medium)
        }
    }
}

struct MindMarginRiskBadge: View {
    let level: StressPrediction.RiskLevel
    var size: MindMarginRiskBadgeSize = .medium

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(style.tint)
                .frame(width: 7, height: 7)

            Text(level.label)
                .font(size.font)
        }
        .foregroundStyle(style.tint)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(style.background, in: Capsule())
    }

    private var style: (tint: Color, background: Color) {
        switch level {
        case .low:
            return (MindMarginTheme.green, MindMarginTheme.lowRiskBackground)
        case .medium:
            return (MindMarginTheme.yellow, MindMarginTheme.moderateRiskBackground)
        case .high:
            return (MindMarginTheme.red, MindMarginTheme.highRiskBackground)
        }
    }
}

struct MindMarginPrimaryButton: View {
    let title: String
    var systemImage: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)

                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(disabled ? MindMarginTheme.indigo.opacity(0.35) : MindMarginTheme.indigo, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: MindMarginTheme.indigo.opacity(0.18), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct MindMarginSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MindMarginTheme.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MindMarginTheme.indigo)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MindMarginScoreRing: View {
    let score: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.06), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(min(score, 1), 0))
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int((score * 100).rounded()))")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(MindMarginTheme.textPrimary)
                Text("/ 100")
                    .font(.caption)
                    .foregroundStyle(MindMarginTheme.textSecondary)
            }
        }
        .frame(width: 112, height: 112)
    }
}

struct MindMarginFeatureCard: View {
    let symbolName: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white)
                    .frame(width: 44, height: 44)

                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MindMarginTheme.indigo)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MindMarginRecommendationCard: View {
    let recommendation: Recommendation
    let compact: Bool
    let selectedFeedback: RecommendationFeedback?
    let submittedFeedback: RecommendationFeedback?
    let canSubmit: Bool
    let onYes: () -> Void
    let onNo: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        let style = recommendationStyle(for: recommendation.category)

        MindMarginCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(style.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(style.background, in: Capsule())

                    Spacer()

                    Image(systemName: style.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MindMarginTheme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(compact ? .headline : .title3.weight(.semibold))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text(recommendation.body)
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !compact {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why this helps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MindMarginTheme.textSecondary)

                        Text(recommendation.rationale)
                            .font(.subheadline)
                            .foregroundStyle(MindMarginTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Was it helpful?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    HStack(spacing: 10) {
                        feedbackButton(title: "Yes", feedbackValue: .yes, tint: MindMarginTheme.green, action: onYes)
                        feedbackButton(title: "No", feedbackValue: .no, tint: MindMarginTheme.red, action: onNo)
                    }

                    Button(action: onSubmit) {
                        Text("Submit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(canSubmit ? Color.black.opacity(0.88) : Color.black.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)

                    if let submittedFeedback {
                        Text("Saved response: \(submittedFeedback == .yes ? "Yes" : "No")")
                            .font(.caption)
                            .foregroundStyle(MindMarginTheme.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackButton(title: String, feedbackValue: RecommendationFeedback, tint: Color, action: @escaping () -> Void) -> some View {
        let isSelected = selectedFeedback == feedbackValue

        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? tint : tint.opacity(0.1))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? tint : tint.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct MindMarginFivePointScale: View {
    let title: String
    let symbolName: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: symbolName)
                    .font(.headline)
                    .foregroundStyle(MindMarginTheme.textPrimary)
                    .labelStyle(.titleAndIcon)

                Spacer()

                Text("\(value)/5")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MindMarginTheme.indigo)
            }

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        value = rating
                    } label: {
                        Text("\(rating)")
                            .font(.headline)
                            .foregroundStyle(value >= rating ? MindMarginTheme.indigo : MindMarginTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(value >= rating ? MindMarginTheme.indigo.opacity(0.1) : .white)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(value >= rating ? MindMarginTheme.indigo : MindMarginTheme.border, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

func recommendationStyle(for category: String) -> (label: String, tint: Color, background: Color, symbolName: String) {
    switch category.lowercased() {
    case "sleep":
        return ("Sleep", Color(hex: 0x7C3AED), Color(hex: 0xEDE9FE), "moon.stars.fill")
    case "schedule":
        return ("Schedule", MindMarginTheme.blue, Color(hex: 0xDBEAFE), "calendar")
    case "movement":
        return ("Movement", MindMarginTheme.green, Color(hex: 0xD1FAE5), "figure.walk")
    case "recovery":
        return ("Recovery", MindMarginTheme.red, Color(hex: 0xFEE2E2), "heart.fill")
    default:
        return ("General", MindMarginTheme.indigo, MindMarginTheme.indigo.opacity(0.12), "sparkles")
    }
}
