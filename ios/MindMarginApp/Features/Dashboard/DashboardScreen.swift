import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject private var appModel: MindMarginAppModel
    @State private var isScheduleExpanded = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(MindMarginTheme.textPrimary)

                        Text(appModel.dashboardDateLabel)
                            .font(.subheadline)
                            .foregroundStyle(MindMarginTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            await appModel.refreshForecast()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: appModel.isRefreshingForecast ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                            Text(appModel.isRefreshingForecast ? "Syncing" : "Refresh")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MindMarginTheme.indigo)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(MindMarginTheme.indigo.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                forecastCard

                VStack(alignment: .leading, spacing: 12) {
                    MindMarginSectionHeader(title: "Top Factors")

                    ForEach(appModel.dashboardFactors) { factor in
                        factorCard(factor)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    MindMarginSectionHeader(title: "Action Plan", actionTitle: "View all") {
                        appModel.openActionPlan()
                    }

                    ForEach(appModel.recommendations.prefix(3)) { recommendation in
                        MindMarginRecommendationCard(
                            recommendation: recommendation,
                            compact: true,
                            selectedFeedback: appModel.recommendationFeedbackDraft(for: recommendation),
                            submittedFeedback: appModel.submittedRecommendationFeedback(for: recommendation),
                            canSubmit: appModel.canSubmitRecommendationFeedback(for: recommendation),
                            onYes: {
                                appModel.selectRecommendationFeedback(.yes, for: recommendation)
                            },
                            onNo: {
                                appModel.selectRecommendationFeedback(.no, for: recommendation)
                            },
                            onSubmit: {
                                appModel.submitRecommendationFeedback(for: recommendation)
                            }
                        )
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    private var forecastCard: some View {
        MindMarginCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MindMarginTheme.cardGradient)
                    .frame(height: 0)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tomorrow's Stress Forecast")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MindMarginTheme.textSecondary)

                            MindMarginRiskBadge(level: appModel.prediction.riskLevel)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                            Text("Rising")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MindMarginTheme.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(MindMarginTheme.orange.opacity(0.12), in: Capsule())
                    }

                    HStack(spacing: 18) {
                        MindMarginScoreRing(score: appModel.prediction.score, tint: riskTint)

                        Text(appModel.forecastSummary)
                            .font(.subheadline)
                            .foregroundStyle(MindMarginTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
            }
        }
    }

    private var statusCard: some View {
        MindMarginCard(padding: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(statusTint.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: statusSymbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusTint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.backendStatus.label)
                        .font(.headline)
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text(appModel.backendStatus.detail)
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }

    private var riskTint: Color {
        switch appModel.prediction.riskLevel {
        case .low:
            return MindMarginTheme.green
        case .medium:
            return MindMarginTheme.yellow
        case .high:
            return MindMarginTheme.red
        }
    }

    private var statusTint: Color {
        if appModel.backendStatus.isConnected {
            return MindMarginTheme.green
        }

        switch appModel.backendStatus {
        case .connecting:
            return MindMarginTheme.indigo
        case .notConfigured:
            return MindMarginTheme.orange
        case .localOnly:
            return MindMarginTheme.orange
        case .connected:
            return MindMarginTheme.green
        }
    }

    private var statusSymbolName: String {
        if appModel.backendStatus.isConnected {
            return "link.circle.fill"
        }

        switch appModel.backendStatus {
        case .connecting:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .notConfigured:
            return "externaldrive.badge.exclamationmark"
        case .localOnly:
            return "wifi.slash"
        case .connected:
            return "link.circle.fill"
        }
    }

    private func factorCard(_ factor: MindMarginAppModel.DashboardFactor) -> some View {
        let isDenseSchedule = factor.title == "Dense schedule" || factor.title == "Schedule pressure"

        return VStack(alignment: .leading, spacing: 14) {
            Button {
                if isDenseSchedule, !appModel.scheduleDisplayBlocks.isEmpty {
                    withAnimation(.smooth(duration: 0.25)) {
                        isScheduleExpanded.toggle()
                    }
                }
            } label: {
                HStack {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(factor.tint.opacity(0.12))
                                .frame(width: 42, height: 42)

                            Image(systemName: factor.symbolName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(factor.tint)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(factor.title)
                                .font(.headline)
                                .foregroundStyle(MindMarginTheme.textPrimary)

                            Text(factor.value)
                                .font(.subheadline)
                                .foregroundStyle(MindMarginTheme.textSecondary)
                        }
                    }

                    Spacer()

                    if isDenseSchedule, !appModel.scheduleDisplayBlocks.isEmpty {
                        Image(systemName: isScheduleExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MindMarginTheme.textTertiary)
                    }

                    Text(factor.impact.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(factor.impact == .high ? MindMarginTheme.red : factor.impact == .low ? .secondary : MindMarginTheme.yellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((factor.impact == .high ? MindMarginTheme.highRiskBackground : factor.impact == .low ? Color(.systemGray5) : MindMarginTheme.moderateRiskBackground), in: Capsule())
                }
            }
            .buttonStyle(.plain)

            if isDenseSchedule, isScheduleExpanded, !appModel.scheduleDisplayBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Schedule overview")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    ForEach(appModel.scheduleDisplayBlocks) { block in
                        scheduleBlockRow(block)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MindMarginTheme.border, lineWidth: 1)
        }
    }

    private func scheduleBlockRow(_ block: MindMarginAppModel.ScheduleDisplayBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(block.startLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MindMarginTheme.textPrimary)
                Text(block.endLabel)
                    .font(.caption2)
                    .foregroundStyle(MindMarginTheme.textTertiary)
            }
            .frame(width: 54, alignment: .leading)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(block.tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(block.kind == .event ? "Schedule block" : "Recovery block")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(block.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(block.tint.opacity(0.12), in: Capsule())

                    Spacer()
                }

                Text(block.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MindMarginTheme.textPrimary)

                Text(block.subtitle)
                    .font(.caption)
                    .foregroundStyle(MindMarginTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(block.tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func errorCard(_ message: String) -> some View {
        MindMarginCard(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(MindMarginTheme.red)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sync issue")
                        .font(.headline)
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    appModel.dismissError()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MindMarginTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ActionPlanScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    dismiss()
                } label: {
                    Label("Dashboard", systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MindMarginTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Action Plan")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text("\(appModel.recommendations.count) personalized recommendations for tomorrow")
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                }

                ForEach(appModel.recommendations) { recommendation in
                    MindMarginRecommendationCard(
                        recommendation: recommendation,
                        compact: false,
                        selectedFeedback: appModel.recommendationFeedbackDraft(for: recommendation),
                        submittedFeedback: appModel.submittedRecommendationFeedback(for: recommendation),
                        canSubmit: appModel.canSubmitRecommendationFeedback(for: recommendation),
                        onYes: {
                            appModel.selectRecommendationFeedback(.yes, for: recommendation)
                        },
                        onNo: {
                            appModel.selectRecommendationFeedback(.no, for: recommendation)
                        },
                        onSubmit: {
                            appModel.submitRecommendationFeedback(for: recommendation)
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(MindMarginTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
