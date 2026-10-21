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

struct MemoryStatsDetailView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @State private var topProcesses: [ProcessStats] = []

    private let accent = StatsAccent.memory
    private let processLimit = 8

    var body: some View {
        let breakdown = statsManager.memoryBreakdown
        StatsOverviewSurface(accent: accent) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    StatsOverviewHeader(
                        symbol: "memorychip",
                        title: String(localized: "Memory Overview"),
                        subtitle: String(localized: "Unified Memory", defaultValue: "Unified Memory"),
                        accent: accent
                    )
                    StatsRingRow(
                        leading: (breakdown.appPercentage, String(localized: "App Memory", defaultValue: "App Memory")),
                        centerValue: StatsFormatting.percentage(breakdown.usedPercentage),
                        centerCaption: StatsOverviewMetrics.gigabytePair(used: breakdown.usedBytes, total: breakdown.totalBytes),
                        centerProgress: breakdown.usedPercentage,
                        trailing: (compressedPercentage(breakdown), String(localized: "Compressed")),
                        accent: accent
                    )
                    StatsHistoryCard(samples: statsManager.memoryHistory, accent: accent)
                    StatsPressureGauge(level: breakdown.pressure.level, accent: accent)
                    StatsLegendGrid(items: [
                        StatsLegendItem(id: "app", color: accent.start, title: String(localized: "App Memory", defaultValue: "App Memory"), value: StatsFormatting.bytes(breakdown.appBytes)),
                        StatsLegendItem(id: "wired", color: accent.end, title: String(localized: "Wired Memory", defaultValue: "Wired"), value: StatsFormatting.bytes(breakdown.wiredBytes)),
                        StatsLegendItem(id: "compressed", color: StatsPalette.compressed, title: String(localized: "Compressed"), value: StatsFormatting.bytes(breakdown.compressedBytes)),
                        StatsLegendItem(id: "cached", color: StatsPalette.idle, title: String(localized: "Cached Files", defaultValue: "Cached Files"), value: StatsFormatting.bytes(breakdown.cacheBytes))
                    ])
                    StatsDetailCard(rows: detailRows(breakdown))
                    StatsProcessSection(
                        title: String(localized: "Highest memory", defaultValue: "Highest memory"),
                        trailing: String(localized: "Usage Share", defaultValue: "Usage"),
                        rows: processRows(totalBytes: breakdown.totalBytes),
                        accent: accent
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollContentBackground(.hidden)
        }
        .onAppear(perform: refreshProcesses)
        .onReceive(statsManager.$topCPUProcesses) { _ in
            refreshProcesses()
        }
    }

    private func compressedPercentage(_ breakdown: MemoryBreakdown) -> Double {
        guard breakdown.totalBytes > 0 else { return 0 }
        return Double(breakdown.compressedBytes) / Double(breakdown.totalBytes) * 100
    }

    private func detailRows(_ breakdown: MemoryBreakdown) -> [StatsDetailRowModel] {
        let swapValue: String
        if breakdown.swap.totalBytes > 0 {
            swapValue = "\(StatsFormatting.bytes(breakdown.swap.usedBytes)) / \(StatsFormatting.bytes(breakdown.swap.totalBytes))"
        } else {
            swapValue = "—"
        }
        return [
            StatsDetailRowModel(id: "swap", label: String(localized: "Swap"), value: swapValue),
            StatsDetailRowModel(id: "physical", label: String(localized: "Physical Memory", defaultValue: "Physical Memory"), value: StatsFormatting.bytes(breakdown.totalBytes)),
            StatsDetailRowModel(id: "available", label: String(localized: "Available", defaultValue: "Available"), value: StatsFormatting.bytes(breakdown.freeBytes)),
            StatsDetailRowModel(id: "updated", label: String(localized: "Last Update"), value: StatsOverviewMetrics.timestamp(statsManager.lastUpdated))
        ]
    }

    private func processRows(totalBytes: UInt64) -> [StatsUsageRowModel] {
        topProcesses.enumerated().map { index, process in
            let percent = totalBytes > 0 ? Double(process.memoryUsage) / Double(totalBytes) * 100 : 0
            return StatsUsageRowModel(
                id: "\(process.pid)-\(index)",
                name: process.name,
                metric: process.memoryUsageString,
                share: StatsFormatting.percentage(percent),
                fraction: StatsOverviewMetrics.barFraction(percent)
            )
        }
    }

    private func refreshProcesses() {
        topProcesses = Array(statsManager.getProcessesRankedByMemory().prefix(processLimit))
    }
}
