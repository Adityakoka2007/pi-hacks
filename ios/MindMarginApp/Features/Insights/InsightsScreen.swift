import Charts
import SwiftUI

struct InsightsScreen: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Insights")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text("Live trends from your recent synced history")
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                }

                HStack(spacing: 12) {
                    MetricCard(symbolName: "waveform.path.ecg", tint: MindMarginTheme.green, label: "Avg. Stress", value: appModel.averageStressLabel, change: appModel.averageStressChangeLabel)
                    MetricCard(symbolName: "moon.stars.fill", tint: Color(hex: 0x7C3AED), label: "Avg. Sleep", value: appModel.averageSleepLabel, change: appModel.averageSleepChangeLabel)
                }

                if appModel.insightStressTrend.isEmpty {
                    emptyStateCard
                } else {
                    ChartCard(title: "Stress Level Trend", subtitle: "Recent check-ins") {
                        Chart(appModel.insightStressTrend) { point in
                            LineMark(
                                x: .value("Day", point.label),
                                y: .value("Stress", point.primary)
                            )
                            .foregroundStyle(MindMarginTheme.indigo)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                            AreaMark(
                                x: .value("Day", point.label),
                                y: .value("Stress", point.primary)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [MindMarginTheme.indigo.opacity(0.18), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .chartYScale(domain: 0...5)
                        .frame(height: 190)
                    }

                    ChartCard(title: "Sleep vs. Stress", subtitle: "Health data aligned with check-ins") {
                        Chart(appModel.insightSleepVsStress) { point in
                            LineMark(
                                x: .value("Day", point.label),
                                y: .value("Sleep", point.primary)
                            )
                            .foregroundStyle(Color(hex: 0x7C3AED))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                            if let secondary = point.secondary {
                                LineMark(
                                    x: .value("Day", point.label),
                                    y: .value("Stress", secondary)
                                )
                                .foregroundStyle(MindMarginTheme.red)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            }
                        }
                        .frame(height: 190)

                        HStack(spacing: 18) {
                            legendDot(title: "Sleep", color: Color(hex: 0x7C3AED))
                            legendDot(title: "Stress", color: MindMarginTheme.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }

                    ChartCard(title: "Schedule Density", subtitle: "Upcoming workload across recent days") {
                        Chart(appModel.insightScheduleDensity) { point in
                            BarMark(
                                x: .value("Day", point.label),
                                y: .value("Events", point.primary)
                            )
                            .foregroundStyle(MindMarginTheme.teal)
                            .cornerRadius(8)
                        }
                        .frame(height: 190)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    MindMarginSectionHeader(title: "Key Patterns")

                    ForEach(appModel.insightPatterns) { pattern in
                        InsightPatternCard(
                            symbolName: pattern.symbolName,
                            tint: pattern.tint,
                            background: pattern.background,
                            title: pattern.title,
                            description: pattern.description
                        )
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    private var emptyStateCard: some View {
        MindMarginCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Not enough history yet")
                    .font(.headline)
                    .foregroundStyle(MindMarginTheme.textPrimary)

                Text("Complete a few check-ins and run one successful sync to replace the remaining demo-like gaps with your real trend data.")
                    .font(.subheadline)
                    .foregroundStyle(MindMarginTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func legendDot(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(MindMarginTheme.textSecondary)
        }
    }
}

private struct MetricCard: View {
    let symbolName: String
    let tint: Color
    let label: String
    let value: String
    let change: String

    var body: some View {
        MindMarginCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbolName)
                        .font(.headline)
                        .foregroundStyle(tint)
                    Spacer()
                    Text(change)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MindMarginTheme.green)
                }

                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(MindMarginTheme.textPrimary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(MindMarginTheme.textSecondary)
            }
        }
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        MindMarginCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(MindMarginTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                }

                content
            }
        }
    }
}

private struct InsightPatternCard: View {
    let symbolName: String
    let tint: Color
    let background: Color
    let title: String
    let description: String

    var body: some View {
        MindMarginCard(padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(background)
                        .frame(width: 42, height: 42)

                    Image(systemName: symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(MindMarginTheme.textPrimary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(MindMarginTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
