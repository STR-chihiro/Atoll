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
    @Default(.statsUpdateInterval) private var statsUpdateInterval
    @Default(.cpuTemperatureUnit) private var temperatureUnit
    @State private var topProcesses: [ProcessStats] = []

    private let accent = Color.blue
    private let processDisplayLimit = 8

    var body: some View {
        let breakdown = statsManager.cpuBreakdown
        StatsPopoverScaffold(
            title: String(localized: "CPU Overview"),
            subtitle: StatsPopoverCopy.subtitle(
                device: StatsPopoverCopy.chipName,
                metric: String(localized: "Overall Utilization")
            ),
            accent: accent,
            ringFraction: breakdown.activeUsage / 100,
            ringValue: StatsFormatting.percentage(breakdown.activeUsage),
            ringCaption: String(localized: "stats_resource_active", defaultValue: "Active"),
            heroLine: heroLine(breakdown),
            history: statsManager.cpuHistory,
            sampleInterval: statsUpdateInterval,
            detailRows: detailRows,
            processes: topProcesses,
            summaryItems: summaryItems,
            footer: { EmptyView() }
        )
        .onReceive(statsManager.$topCPUProcesses) { processes in
            topProcesses = Array(processes.prefix(processDisplayLimit))
        }
        .onAppear {
            topProcesses = Array(statsManager.topCPUProcesses.prefix(processDisplayLimit))
        }
    }

    private func heroLine(_ breakdown: CPULoadBreakdown) -> String {
        let system = "\(String(localized: "System")) \(StatsFormatting.percentage(breakdown.system))"
        let user = "\(String(localized: "User")) \(StatsFormatting.percentage(breakdown.user))"
        let idle = "\(String(localized: "Idle")) \(StatsFormatting.percentage(breakdown.idle))"
        return "\(system)  \(user)  \(idle)"
    }

    private var detailRows: [StatsPopoverDetailRowModel] {
        [
            StatsPopoverDetailRowModel(
                label: String(localized: "Logical cores"),
                value: "\(logicalCoreCount)"
            ),
            StatsPopoverDetailRowModel(
                label: String(localized: "Uptime"),
                value: StatsFormatting.abbreviatedDuration(statsManager.cpuUptime)
            ),
            StatsPopoverDetailRowModel(
                label: frequencyLabel,
                value: frequencyDetail
            ),
            StatsPopoverDetailRowModel(
                label: String(localized: "Load (1 / 5 / 15 min)"),
                value: loadDetail
            )
        ]
    }

    private var logicalCoreCount: Int {
        let sampled = statsManager.cpuCoreUsage.count
        if sampled > 0 { return sampled }
        return max(AppleHardwareInfo.shared.logicalCoreCount, 1)
    }

    private var frequencyLabel: String {
        let frequency = statsManager.cpuFrequency
        if frequency?.eCoreGHz != nil, frequency?.pCoreGHz != nil {
            return String(localized: "Frequency (E / P)")
        }
        return String(localized: "Frequency")
    }

    private var frequencyDetail: String {
        guard let frequency = statsManager.cpuFrequency else { return "—" }
        if let eCore = frequency.eCoreGHz, let pCore = frequency.pCoreGHz {
            return String(format: "%.1f / %.1f GHz", eCore, pCore)
        }
        if let eCore = frequency.eCoreGHz {
            return String(format: "E %.1f GHz", eCore)
        }
        if let pCore = frequency.pCoreGHz {
            return String(format: "P %.1f GHz", pCore)
        }
        return String(format: "%.1f GHz", frequency.overallGHz)
    }

    private var loadDetail: String {
        let load = statsManager.cpuLoadAverage
        return String(format: "%.2f · %.2f · %.2f", load.oneMinute, load.fiveMinutes, load.fifteenMinutes)
    }

    private var summaryItems: [StatsPopoverSummaryItem] {
        [
            StatsPopoverSummaryItem(
                title: String(localized: "Temperature"),
                value: temperatureText,
                accent: StatsPalette.temperatureOrange
            ),
            StatsPopoverSummaryItem(
                title: String(localized: "Frequency"),
                value: frequencyCardText,
                accent: accent
            )
        ]
    }

    private var temperatureText: String {
        guard let celsius = statsManager.cpuTemperature.celsius else { return "—" }
        let display = temperatureUnit == .celsius ? celsius : celsius * 9.0 / 5.0 + 32.0
        return String(format: "%.0f%@", display, temperatureUnit.symbol)
    }

    private var frequencyCardText: String {
        guard let frequency = statsManager.cpuFrequency else { return "—" }
        return String(format: "%.1f GHz", frequency.overallGHz)
    }
}
