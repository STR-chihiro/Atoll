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

struct MemoryStatsDetailView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @Default(.statsUpdateInterval) private var statsUpdateInterval

    private let accent = Color.green
    private let processDisplayLimit = 8

    private var topProcesses: [ProcessStats] {
        Array(statsManager.getProcessesRankedByMemory().prefix(processDisplayLimit))
    }

    var body: some View {
        let breakdown = statsManager.memoryBreakdown
        StatsPopoverScaffold(
            title: String(localized: "Memory Overview"),
            subtitle: StatsPopoverCopy.subtitle(
                device: StatsPopoverCopy.chipName,
                metric: String(localized: "Physical Memory")
            ),
            accent: accent,
            ringFraction: breakdown.usedPercentage / 100,
            ringValue: StatsFormatting.percentage(breakdown.usedPercentage),
            ringCaption: String(localized: "Used"),
            heroLine: heroLine(breakdown),
            history: statsManager.memoryHistory,
            sampleInterval: statsUpdateInterval,
            detailRows: detailRows(breakdown),
            processes: topProcesses,
            summaryItems: summaryItems(breakdown),
            footer: { EmptyView() }
        )
    }

    private func heroLine(_ breakdown: MemoryBreakdown) -> String {
        "\(String(localized: "Used")) \(StatsFormatting.bytes(breakdown.usedBytes)) / \(StatsFormatting.bytes(breakdown.totalBytes))"
    }

    private func detailRows(_ breakdown: MemoryBreakdown) -> [StatsPopoverDetailRowModel] {
        [
            row(String(localized: "App"), bytes: breakdown.appBytes, total: breakdown.totalBytes),
            row(String(localized: "Cached"), bytes: breakdown.cacheBytes, total: breakdown.totalBytes),
            row(String(localized: "Wired"), bytes: breakdown.wiredBytes, total: breakdown.totalBytes),
            row(String(localized: "Compressed"), bytes: breakdown.compressedBytes, total: breakdown.totalBytes)
        ]
    }

    private func row(_ label: String, bytes: UInt64, total: UInt64) -> StatsPopoverDetailRowModel {
        let percent = total > 0 ? Double(bytes) / Double(total) * 100 : 0
        let value = "\(StatsFormatting.bytes(bytes)) · \(StatsFormatting.percentage(percent))"
        return StatsPopoverDetailRowModel(label: label, value: value)
    }

    private func summaryItems(_ breakdown: MemoryBreakdown) -> [StatsPopoverSummaryItem] {
        [
            StatsPopoverSummaryItem(
                title: String(localized: "Free"),
                value: StatsFormatting.bytes(breakdown.freeBytes),
                accent: accent
            ),
            StatsPopoverSummaryItem(
                title: String(localized: "Total"),
                value: StatsFormatting.bytes(breakdown.totalBytes),
                accent: accent
            )
        ]
    }
}
