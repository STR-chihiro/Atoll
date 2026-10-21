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

struct CPUStatsDetailView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @Default(.cpuTemperatureUnit) private var temperatureUnit

    private let accent = StatsAccent.cpu
    private let processLimit = 8

    var body: some View {
        let layout = CPUCoreLayout.resolve(cores: statsManager.cpuCoreUsage)
        let breakdown = statsManager.cpuBreakdown
        StatsOverviewSurface(accent: accent) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    StatsOverviewHeader(
                        symbol: "cpu",
                        title: String(localized: "CPU Overview"),
                        subtitle: String(localized: "Processor Load", defaultValue: "Processor Load"),
                        accent: accent
                    )
                    StatsRingRow(
                        leading: layout.leading.map { ($0.percent, $0.caption) },
                        centerValue: StatsFormatting.percentage(breakdown.activeUsage),
                        centerCaption: String(localized: "Total Usage", defaultValue: "Total Usage"),
                        centerProgress: breakdown.activeUsage,
                        trailing: layout.trailing.map { ($0.percent, $0.caption) },
                        accent: accent
                    )
                    StatsHistoryCard(samples: statsManager.cpuHistory, accent: accent)
                    if !layout.bars.isEmpty {
                        StatsCoreBars(bars: layout.bars, accent: accent)
                    }
                    StatsLegendGrid(items: [
                        StatsLegendItem(id: "user", color: accent.start, title: String(localized: "User"), value: StatsFormatting.percentage(breakdown.user)),
                        StatsLegendItem(id: "system", color: accent.end, title: String(localized: "System"), value: StatsFormatting.percentage(breakdown.system)),
                        StatsLegendItem(id: "idle", color: StatsPalette.idle, title: String(localized: "Idle"), value: StatsFormatting.percentage(breakdown.idle))
                    ])
                    StatsDetailCard(rows: detailRows(summary: layout.summary))
                    StatsProcessSection(
                        title: String(localized: "Top Processes"),
                        trailing: String(localized: "Usage Share", defaultValue: "Usage"),
                        rows: processRows,
                        accent: accent
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var processRows: [StatsUsageRowModel] {
        statsManager.topCPUProcesses.prefix(processLimit).enumerated().map { index, process in
            StatsUsageRowModel(
                id: "\(process.pid)-\(index)",
                name: process.name,
                metric: "",
                share: StatsFormatting.percentage(process.cpuUsage),
                fraction: StatsOverviewMetrics.barFraction(process.cpuUsage)
            )
        }
    }

    private func detailRows(summary: String) -> [StatsDetailRowModel] {
        let load = statsManager.cpuLoadAverage
        var rows: [StatsDetailRowModel] = [
            StatsDetailRowModel(
                id: "load",
                label: String(localized: "Load averages", defaultValue: "Load averages"),
                value: String(format: "%.2f · %.2f · %.2f", load.oneMinute, load.fiveMinutes, load.fifteenMinutes)
            )
        ]
        if let chip = AppleHardwareInfo.shared.cpuName, !chip.isEmpty {
            rows.append(StatsDetailRowModel(id: "chip", label: String(localized: "Chip", defaultValue: "Chip"), value: chip))
        }
        rows.append(StatsDetailRowModel(
            id: "cores",
            label: String(localized: "CPU Cores", defaultValue: "Cores"),
            value: summary
        ))
        if let frequency = statsManager.cpuFrequency {
            rows.append(StatsDetailRowModel(
                id: "frequency",
                label: String(localized: "Frequency"),
                value: frequencyText(frequency)
            ))
        }
        rows.append(StatsDetailRowModel(
            id: "temperature",
            label: String(localized: "Temperature"),
            value: temperatureText(statsManager.cpuTemperature.celsius)
        ))
        rows.append(StatsDetailRowModel(
            id: "uptime",
            label: String(localized: "Uptime"),
            value: StatsFormatting.abbreviatedDuration(statsManager.cpuUptime)
        ))
        rows.append(StatsDetailRowModel(
            id: "updated",
            label: String(localized: "Last Update"),
            value: StatsOverviewMetrics.timestamp(statsManager.lastUpdated)
        ))
        return rows
    }

    private func frequencyText(_ frequency: CPUFrequencyMetrics) -> String {
        var parts: [String] = []
        if let performance = frequency.pCoreGHz {
            parts.append("P " + String(format: "%.1f", performance))
        }
        if let efficiency = frequency.eCoreGHz {
            parts.append("E " + String(format: "%.1f", efficiency))
        }
        if parts.isEmpty {
            return String(format: "%.2f GHz", frequency.overallGHz)
        }
        return parts.joined(separator: " · ") + " GHz"
    }

    private func temperatureText(_ celsius: Double?) -> String {
        guard let celsius else { return "—" }
        let display = temperatureUnit == .celsius ? celsius : celsius * 9.0 / 5.0 + 32.0
        return String(format: "%.0f%@", display, temperatureUnit.symbol)
    }
}
