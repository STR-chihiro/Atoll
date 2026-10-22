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

import Defaults
import SwiftUI

struct GPUStatsDetailView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @Default(.statsUpdateInterval) private var statsUpdateInterval
    @State private var topProcesses: [ProcessStats] = []

    private let accentColor = StatsPalette.coolPurple
    private let cardBackground = Color(nsColor: .windowBackgroundColor).opacity(0.65)
    private let processDisplayLimit = 8

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StatsCard(title: String(localized: "GPU Overview"), padding: 16, background: cardBackground, cornerRadius: 12) {
                    GPUUsageDashboard(
                        usage: statsManager.gpuUsage,
                        render: renderEngineUtilization,
                        tiler: tilerUtilization,
                        history: statsManager.gpuHistory,
                        sampleInterval: statsUpdateInterval,
                        averageUsage: statsManager.avgGpuUsage,
                        coreCount: statsManager.gpuDevices.first?.cores,
                        chipName: statsManager.gpuDevices.first?.formattedVendorModel,
                        processes: topProcesses,
                        accentColor: accentColor
                    )
                }

                if !statsManager.gpuDevices.isEmpty {
                    StatsCard(title: String(localized: "Devices"), padding: 16, background: cardBackground, cornerRadius: 12) {
                        GPUDeviceList(devices: statsManager.gpuDevices, accentColor: accentColor)
                    }
                }
            }
            .padding(16)
            .padding(.trailing, 28)
        }
        .frame(maxWidth: .infinity)
        .onAppear(perform: refreshProcesses)
        .onReceive(statsManager.$lastUpdated) { _ in
            refreshProcesses()
        }
    }

    private func refreshProcesses() {
        let processes = statsManager.getProcessesRankedByGPU()
        topProcesses = Array(processes.prefix(processDisplayLimit))
    }

    private var primaryDevice: GPUDeviceMetrics? {
        statsManager.gpuDevices.first
    }

    private var renderEngineUtilization: Double? {
        primaryDevice?.renderUtilization ?? statsManager.gpuBreakdown.render
    }

    private var tilerUtilization: Double? {
        primaryDevice?.tilerUtilization
    }
}

private struct GPUUsageDashboard: View {
    let usage: Double
    let render: Double?
    let tiler: Double?
    let history: [Double]
    let sampleInterval: Double
    let averageUsage: Double
    let coreCount: Int?
    let chipName: String?
    let processes: [ProcessStats]
    let accentColor: Color

    private let ringDiameter: CGFloat = 132
    private let ringLineWidth: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            GPUUsageRing(usage: usage, accentColor: accentColor, diameter: ringDiameter, lineWidth: ringLineWidth)
                .frame(maxWidth: .infinity)
            Text(engineCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            GPUPeakLineChart(values: history, sampleInterval: sampleInterval, accentColor: accentColor)
            GPUProcessSection(processes: processes, accentColor: accentColor)
            summaryCards
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(String(localized: "Live"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(accentColor.opacity(0.14)))
        }
    }

    private var subtitle: String {
        let engine = String(localized: "Engine Utilization")
        guard let chipName, !chipName.isEmpty else { return engine }
        return "\(chipName) · \(engine)"
    }

    private var engineCaption: String {
        let renderText = render.map { StatsFormatting.percentage($0) } ?? "—"
        let tilerText = tiler.map { StatsFormatting.percentage($0) } ?? "—"
        return "\(String(localized: "Render")) \(renderText)  \(String(localized: "Tiler")) \(tilerText)"
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            GPUSummaryCard(
                title: String(localized: "Session Avg"),
                value: StatsFormatting.percentage(averageUsage),
                accentColor: accentColor
            )
            GPUSummaryCard(
                title: String(localized: "Cores"),
                value: coreCount.map { String($0) } ?? "—",
                accentColor: accentColor
            )
        }
    }
}

private struct GPUUsageRing: View {
    let usage: Double
    let accentColor: Color
    var diameter: CGFloat = 132
    var lineWidth: CGFloat = 5

    var body: some View {
        let fraction = min(max(usage / 100, 0), 1)
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            if fraction > 0 {
                RingArc(start: 0, end: fraction, color: accentColor, lineWidth: lineWidth)
            }
            VStack(spacing: 2) {
                Text(StatsFormatting.percentage(usage))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(String(localized: "Active"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct GPUPeakLineChart: View {
    let values: [Double]
    let sampleInterval: Double
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(windowTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(localized: "Peak")) \(StatsFormatting.percentage(peakValue))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
            }
            chart
                .frame(height: 72)
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
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let inset: CGFloat = 6
            let plotWidth = max(width - inset * 2, 1)
            let count = values.count
            let scale = max(peakValue, 1)
            let peakX = xPosition(index: peakIndex, count: count, plotWidth: plotWidth, inset: inset)
            let peakY = yPosition(value: values.indices.contains(peakIndex) ? values[peakIndex] : 0, height: height, scale: scale)

            ZStack {
                linePath(width: plotWidth, height: height, inset: inset, scale: scale)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                Path { path in
                    path.move(to: CGPoint(x: peakX, y: 0))
                    path.addLine(to: CGPoint(x: peakX, y: height))
                }
                .stroke(accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                Circle()
                    .stroke(accentColor, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                    .position(x: peakX, y: peakY)
            }
        }
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

private struct GPUProcessSection: View {
    let processes: [ProcessStats]
    let accentColor: Color

    private let memoryColumnWidth: CGFloat = 76
    private let percentColumnWidth: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(String(localized: "Top Processes"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(String(localized: "Usage"))
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if processes.isEmpty {
                Text("No process data yet. Keep stats open for a moment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(processes) { process in
                        GPUProcessRow(
                            process: process,
                            accentColor: accentColor,
                            memoryColumnWidth: memoryColumnWidth,
                            percentColumnWidth: percentColumnWidth
                        )
                    }
                }
            }
        }
    }
}

private struct GPUProcessRow: View {
    let process: ProcessStats
    let accentColor: Color
    let memoryColumnWidth: CGFloat
    let percentColumnWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(process.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(process.memoryUsageString)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: memoryColumnWidth, alignment: .trailing)
                Text(process.cpuUsageString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .frame(width: percentColumnWidth, alignment: .trailing)
            }
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
                    .fill(accentColor.opacity(0.16))
                Capsule()
                    .fill(accentColor)
                    .frame(width: max(progress * proxy.size.width, progress > 0 ? 3 : 0))
            }
        }
        .frame(height: 3)
    }
}

private struct GPUSummaryCard: View {
    let title: String
    let value: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accentColor.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct GPUDeviceList: View {
    let devices: [GPUDeviceMetrics]
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                GPUDeviceRow(device: device, accentColor: accentColor)
                if index < devices.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct GPUDeviceRow: View {
    let device: GPUDeviceMetrics
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(device.isActive ? accentColor : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.formattedVendorModel)
                        .font(.system(size: 13, weight: .semibold))
                    Text(device.isActive ? String(localized: "Active") : String(localized: "Idle"))
                        .font(.caption2)
                        .foregroundStyle(device.isActive ? accentColor : .secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(device.utilizationText)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(accentColor)
                    Text("Utilization")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 8) {
                if let render = device.renderUtilization {
                    DetailRow(color: accentColor, label: String(localized: "Renderer"), value: StatsFormatting.percentage(render))
                }
                if let tiler = device.tilerUtilization {
                    DetailRow(color: accentColor, label: String(localized: "Tiler"), value: StatsFormatting.percentage(tiler))
                }
                if let temp = device.temperature {
                    DetailRow(color: nil, label: String(localized: "Temperature"), value: String(format: "%.0f°C", temp))
                }
                if let fan = device.fanSpeed {
                    DetailRow(color: nil, label: String(localized: "Fan Speed"), value: "\(fan)%")
                }
                if let coreClock = device.coreClock {
                    DetailRow(color: nil, label: String(localized: "Core Clock"), value: "\(coreClock) MHz")
                }
                if let memoryClock = device.memoryClock {
                    DetailRow(color: nil, label: String(localized: "Memory Clock"), value: "\(memoryClock) MHz")
                }
                if let cores = device.cores {
                    DetailRow(color: nil, label: String(localized: "Cores"), value: "\(cores)")
                }
            }
        }
    }
}
