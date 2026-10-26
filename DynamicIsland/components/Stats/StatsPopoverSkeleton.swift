/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import SwiftUI

/// Shared chrome for the CPU, Memory, and GPU stat popovers.
/// Metric views supply copy, the ring fraction, and accent colors. Spacing,
/// type, corner radius, and grayscale all live here so the three panels match.
enum StatsPopoverMetrics {
    static let ringDiameter: CGFloat = 168
    static let ringLineWidth: CGFloat = 6
    static let sectionSpacing: CGFloat = 16
    static let contentPadding: CGFloat = 20
    /// Shared popover width. Kept on the scaffold so the card cannot lay out
    /// wider than the window and get clipped on the leading edge.
    static let popoverWidth: CGFloat = 420
    static let closeButtonSize: CGFloat = 32
    static let chartHeight: CGFloat = 72
    static let progressHeight: CGFloat = 3
    static let cardCornerRadius: CGFloat = 10
    static let cardSpacing: CGFloat = 10
    static let detailValueWidth: CGFloat = 164
    static let processMemoryWidth: CGFloat = 76
    static let processShareWidth: CGFloat = 64
    static let rowSpacing: CGFloat = 8
}

enum StatsPopoverCopy {
    static var chipName: String? {
        let name = AppleHardwareInfo.shared.cpuName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }
        return name
    }

    static func subtitle(device: String?, metric: String) -> String {
        let trimmed = device?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return metric }
        return "\(trimmed) · \(metric)"
    }
}

struct StatsPopoverDetailRowModel: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

struct StatsPopoverSummaryItem: Identifiable {
    let title: String
    let value: String
    let accent: Color
    var id: String { title }
}

struct StatsPopoverScaffold<Footer: View>: View {
    let title: String
    let subtitle: String
    let accent: Color
    let ringFraction: Double
    let ringValue: String
    let ringCaption: String
    let heroLine: String
    let history: [Double]
    let sampleInterval: Double
    let detailRows: [StatsPopoverDetailRowModel]
    let processes: [ProcessStats]
    let summaryItems: [StatsPopoverSummaryItem]
    private let footer: Footer

    init(
        title: String,
        subtitle: String,
        accent: Color,
        ringFraction: Double,
        ringValue: String,
        ringCaption: String,
        heroLine: String,
        history: [Double],
        sampleInterval: Double,
        detailRows: [StatsPopoverDetailRowModel] = [],
        processes: [ProcessStats],
        summaryItems: [StatsPopoverSummaryItem],
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.ringFraction = ringFraction
        self.ringValue = ringValue
        self.ringCaption = ringCaption
        self.heroLine = heroLine
        self.history = history
        self.sampleInterval = sampleInterval
        self.detailRows = detailRows
        self.processes = processes
        self.summaryItems = summaryItems
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StatsPopoverMetrics.sectionSpacing) {
            StatsPopoverHeader(title: title, subtitle: subtitle, accent: accent)

            StatsPopoverRing(
                fraction: ringFraction,
                value: ringValue,
                caption: ringCaption,
                accent: accent
            )
            .frame(maxWidth: .infinity)

            Text(heroLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            StatsPopoverPeakChart(
                values: history,
                sampleInterval: sampleInterval,
                accent: accent
            )

            if !detailRows.isEmpty {
                StatsPopoverDetailSection(rows: detailRows)
            }

            StatsPopoverProcessSection(processes: processes, accent: accent)
            StatsPopoverSummaryRow(items: summaryItems)
            footer
        }
        .padding(StatsPopoverMetrics.contentPadding)
        .frame(width: StatsPopoverMetrics.popoverWidth, alignment: .topLeading)
        .fixedSize(horizontal: true, vertical: true)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

private struct StatsPopoverHeader: View {
    let title: String
    let subtitle: String
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Text(String(localized: "Live"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(accent.opacity(0.14)))
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: StatsPopoverMetrics.closeButtonSize, height: StatsPopoverMetrics.closeButtonSize)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Close"))
        }
    }
}

private struct StatsPopoverRing: View {
    let fraction: Double
    let value: String
    let caption: String
    let accent: Color

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        ZStack {
            Circle()
                .stroke(
                    accent.opacity(0.18),
                    style: StrokeStyle(lineWidth: StatsPopoverMetrics.ringLineWidth, lineCap: .round)
                )
            if clamped > 0 {
                RingArc(
                    start: 0,
                    end: clamped,
                    color: accent,
                    lineWidth: StatsPopoverMetrics.ringLineWidth
                )
            }
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: StatsPopoverMetrics.ringDiameter, height: StatsPopoverMetrics.ringDiameter)
    }
}

private struct StatsPopoverPeakChart: View {
    let values: [Double]
    let sampleInterval: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(windowTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(localized: "Peak")) \(StatsFormatting.percentage(peakValue))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
            }
            chart
                .frame(height: StatsPopoverMetrics.chartHeight)
        }
    }

    private var windowTitle: String {
        let samples = max(values.count, 1)
        let seconds = max(1, Int((Double(samples) * sampleInterval).rounded()))
        return String(format: String(localized: "Last %d seconds"), seconds)
    }

    private var peakValue: Double {
        values.max() ?? 0
    }

    private var peakIndex: Int {
        guard let peak = values.max(), let index = values.lastIndex(of: peak) else { return 0 }
        return index
    }

    private var chart: some View {
        Canvas { context, size in
            let inset: CGFloat = 6
            let plotWidth = max(size.width - inset * 2, 1)
            let height = size.height
            let count = values.count
            let scale = max(peakValue, 1)
            let peakX = xPosition(index: peakIndex, count: count, plotWidth: plotWidth, inset: inset)
            let peakY = yPosition(
                value: values.indices.contains(peakIndex) ? values[peakIndex] : 0,
                height: height,
                scale: scale
            )

            context.stroke(
                linePath(width: plotWidth, height: height, inset: inset, scale: scale),
                with: .color(accent),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                samplePoints(width: plotWidth, height: height, inset: inset, scale: scale),
                with: .color(accent),
                lineWidth: 1
            )

            var peakLine = Path()
            peakLine.move(to: CGPoint(x: peakX, y: 0))
            peakLine.addLine(to: CGPoint(x: peakX, y: height))
            context.stroke(
                peakLine,
                with: .color(accent.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )

            let marker = CGRect(x: peakX - 4, y: peakY - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: marker), with: .color(Color(nsColor: .controlBackgroundColor)))
            context.stroke(Path(ellipseIn: marker), with: .color(accent), lineWidth: 1.5)
        }
    }

    private func samplePoints(width: CGFloat, height: CGFloat, inset: CGFloat, scale: Double) -> Path {
        var path = Path()
        let radius: CGFloat = 2.5
        for (index, value) in values.enumerated() {
            let center = CGPoint(
                x: xPosition(index: index, count: values.count, plotWidth: width, inset: inset),
                y: yPosition(value: value, height: height, scale: scale)
            )
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    private func linePath(width: CGFloat, height: CGFloat, inset: CGFloat, scale: Double) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }
        for (index, value) in values.enumerated() {
            let point = CGPoint(
                x: xPosition(index: index, count: values.count, plotWidth: width, inset: inset),
                y: yPosition(value: value, height: height, scale: scale)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func xPosition(index: Int, count: Int, plotWidth: CGFloat, inset: CGFloat) -> CGFloat {
        guard count > 1 else { return inset + plotWidth / 2 }
        return inset + CGFloat(index) / CGFloat(count - 1) * plotWidth
    }

    private func yPosition(value: Double, height: CGFloat, scale: Double) -> CGFloat {
        let normalized = min(max(value / scale, 0), 1)
        let y = height * (1 - CGFloat(normalized))
        return min(max(y, 4), height - 4)
    }
}

private struct StatsPopoverDetailSection: View {
    let rows: [StatsPopoverDetailRowModel]

    var body: some View {
        VStack(alignment: .leading, spacing: StatsPopoverMetrics.rowSpacing) {
            Text(String(localized: "Breakdown"))
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: StatsPopoverMetrics.rowSpacing) {
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        Text(row.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: StatsPopoverMetrics.detailValueWidth, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct StatsPopoverProcessSection: View {
    let processes: [ProcessStats]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: StatsPopoverMetrics.rowSpacing) {
            Text(String(localized: "Top Processes"))
                .font(.caption)
                .foregroundStyle(.secondary)

            StatsPopoverProcessColumns(
                name: String(localized: "Name"),
                memory: String(localized: "Memory"),
                share: String(localized: "stats_process_share", defaultValue: "Usage"),
                nameFont: .caption,
                memoryFont: .caption,
                shareFont: .caption,
                nameColor: .secondary,
                memoryColor: .secondary,
                shareColor: .secondary
            )

            if processes.isEmpty {
                Text(String(localized: "No process data yet. Keep stats open for a moment."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(processes) { process in
                        StatsPopoverProcessRow(process: process, accent: accent)
                    }
                }
            }
        }
    }
}

private struct StatsPopoverProcessRow: View {
    let process: ProcessStats
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatsPopoverProcessColumns(
                name: process.name,
                memory: process.memoryUsageString,
                share: process.cpuUsageString,
                nameFont: .system(size: 12, weight: .medium),
                memoryFont: .system(size: 12, weight: .regular, design: .monospaced),
                shareFont: .system(size: 12, weight: .semibold, design: .monospaced),
                nameColor: .primary,
                memoryColor: .secondary,
                shareColor: accent
            )
            progressBar
        }
    }

    private var progress: CGFloat {
        CGFloat(min(max(process.cpuUsage / 100, 0), 1))
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accent.opacity(0.16))
                Capsule()
                    .fill(accent)
                    .frame(width: max(progress * proxy.size.width, progress > 0 ? 3 : 0))
            }
        }
        .frame(height: StatsPopoverMetrics.progressHeight)
    }
}

private struct StatsPopoverProcessColumns: View {
    let name: String
    let memory: String
    let share: String
    let nameFont: Font
    let memoryFont: Font
    let shareFont: Font
    let nameColor: Color
    let memoryColor: Color
    let shareColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(nameFont)
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(memory)
                .font(memoryFont)
                .foregroundStyle(memoryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: StatsPopoverMetrics.processMemoryWidth, alignment: .trailing)
            Text(share)
                .font(shareFont)
                .foregroundStyle(shareColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: StatsPopoverMetrics.processShareWidth, alignment: .trailing)
        }
    }
}

private struct StatsPopoverSummaryRow: View {
    let items: [StatsPopoverSummaryItem]

    var body: some View {
        HStack(spacing: StatsPopoverMetrics.cardSpacing) {
            ForEach(items) { item in
                StatsPopoverSummaryCard(item: item)
            }
        }
    }
}

private struct StatsPopoverSummaryCard: View {
    let item: StatsPopoverSummaryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(item.value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(item.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: StatsPopoverMetrics.cardCornerRadius, style: .continuous)
                .fill(item.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StatsPopoverMetrics.cardCornerRadius, style: .continuous)
                .stroke(item.accent.opacity(0.35), lineWidth: 1)
        )
    }
}
