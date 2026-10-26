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

    private let accentColor = StatsPalette.coolPurple
    private let cardBackground = Color(nsColor: .windowBackgroundColor).opacity(0.65)
    private let processDisplayLimit = 8

    private var topProcesses: [ProcessStats] {
        Array(statsManager.getProcessesRankedByGPU().prefix(processDisplayLimit))
    }

    var body: some View {
        StatsPopoverScaffold(
            title: String(localized: "GPU Overview"),
            subtitle: StatsPopoverCopy.subtitle(
                device: statsManager.gpuDevices.first?.formattedVendorModel,
                metric: String(localized: "Engine Utilization")
            ),
            accent: accentColor,
            ringFraction: statsManager.gpuUsage / 100,
            ringValue: StatsFormatting.percentage(statsManager.gpuUsage),
            ringCaption: String(localized: "stats_resource_active", defaultValue: "Active"),
            heroLine: engineCaption,
            history: statsManager.gpuHistory,
            sampleInterval: statsUpdateInterval,
            processes: topProcesses,
            summaryItems: summaryItems
        ) {
            if !statsManager.gpuDevices.isEmpty {
                StatsCard(title: String(localized: "Devices"), padding: 16, background: cardBackground, cornerRadius: 12) {
                    GPUDeviceList(devices: statsManager.gpuDevices, accentColor: accentColor)
                }
            }
        }
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

    private var engineCaption: String {
        let renderText = renderEngineUtilization.map { StatsFormatting.percentage($0) } ?? "—"
        let tilerText = tilerUtilization.map { StatsFormatting.percentage($0) } ?? "—"
        return "\(String(localized: "Render")) \(renderText)  \(String(localized: "Tiler")) \(tilerText)"
    }

    private var summaryItems: [StatsPopoverSummaryItem] {
        [
            StatsPopoverSummaryItem(
                title: String(localized: "Session Avg"),
                value: StatsFormatting.percentage(statsManager.avgGpuUsage),
                accent: accentColor
            ),
            StatsPopoverSummaryItem(
                title: String(localized: "Cores"),
                value: statsManager.gpuDevices.first?.cores.map { String($0) } ?? "—",
                accent: accentColor
            )
        ]
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
                    Text(String(localized: "Utilization"))
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
