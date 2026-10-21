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

struct GPUStatsDetailView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @State private var topProcesses: [ProcessStats] = []

    private let accent = StatsAccent.gpu
    private let processLimit = 8

    var body: some View {
        let device = statsManager.gpuDevices.first
        let render = device?.renderUtilization
        let tiler = device?.tilerUtilization
        StatsOverviewSurface(accent: accent) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    StatsOverviewHeader(
                        symbol: "display",
                        title: String(localized: "GPU Overview"),
                        subtitle: String(localized: "Engine Utilization"),
                        accent: accent
                    )
                    StatsRingRow(
                        leading: render.map { ($0, String(localized: "Render")) },
                        centerValue: StatsFormatting.percentage(statsManager.gpuUsage),
                        centerCaption: String(localized: "stats_resource_active", defaultValue: "Active"),
                        centerProgress: statsManager.gpuUsage,
                        trailing: tiler.map { ($0, String(localized: "Tiler")) },
                        accent: accent
                    )
                    StatsHistoryCard(samples: statsManager.gpuHistory, accent: accent)
                    if !legendItems(render: render, tiler: tiler, device: device).isEmpty {
                        StatsLegendGrid(items: legendItems(render: render, tiler: tiler, device: device))
                    }
                    StatsDetailCard(rows: detailRows(device: device))
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
        .onAppear(perform: refreshProcesses)
        .onReceive(statsManager.$topCPUProcesses) { _ in
            refreshProcesses()
        }
    }

    /// Render and tiler come from the accelerator's performance statistics.
    /// Compute / video are not separate counters here, so they are not shown.
    /// "Other" is only the measured gap between device utilization and those two engines.
    private func legendItems(render: Double?, tiler: Double?, device: GPUDeviceMetrics?) -> [StatsLegendItem] {
        var items: [StatsLegendItem] = []
        if let render {
            items.append(StatsLegendItem(id: "render", color: accent.start, title: String(localized: "Render"), value: StatsFormatting.percentage(render)))
        }
        if let tiler {
            items.append(StatsLegendItem(id: "tiler", color: accent.end, title: String(localized: "Tiler"), value: StatsFormatting.percentage(tiler)))
        }
        if let render {
            let total = device?.utilization ?? statsManager.gpuUsage
            let residual = max(0, min(100, total - render - (tiler ?? 0)))
            items.append(StatsLegendItem(id: "other", color: StatsPalette.idle, title: String(localized: "Other"), value: StatsFormatting.percentage(residual)))
        }
        return items
    }

    private func detailRows(device: GPUDeviceMetrics?) -> [StatsDetailRowModel] {
        var rows: [StatsDetailRowModel] = [
            StatsDetailRowModel(
                id: "average",
                label: String(localized: "Session Avg"),
                value: StatsFormatting.percentage(statsManager.avgGpuUsage)
            )
        ]
        if let device {
            let active = device.isActive
            rows.append(StatsDetailRowModel(id: "device", label: String(localized: "Devices"), value: device.formattedVendorModel))
            rows.append(StatsDetailRowModel(
                id: "status",
                label: String(localized: "Status"),
                value: active ? String(localized: "stats_resource_active", defaultValue: "Active") : String(localized: "Idle"),
                tint: active ? accent.end : StatsPalette.muted,
                showsDot: true
            ))
            rows.append(StatsDetailRowModel(id: "temperature", label: String(localized: "Temperature"), value: device.temperatureText))
            if let cores = device.cores {
                rows.append(StatsDetailRowModel(id: "cores", label: String(localized: "Cores"), value: "\(cores)"))
            }
            if let fan = device.fanSpeed {
                rows.append(StatsDetailRowModel(id: "fan", label: String(localized: "Fan Speed"), value: "\(fan)%"))
            }
            if let clock = device.coreClock {
                rows.append(StatsDetailRowModel(id: "core-clock", label: String(localized: "Core Clock"), value: "\(clock) MHz"))
            }
            if let memoryClock = device.memoryClock {
                rows.append(StatsDetailRowModel(id: "memory-clock", label: String(localized: "Memory Clock"), value: "\(memoryClock) MHz"))
            }
        }
        if statsManager.gpuDevices.count > 1 {
            for device in statsManager.gpuDevices.dropFirst() {
                rows.append(StatsDetailRowModel(
                    id: "extra-\(device.id)",
                    label: device.formattedVendorModel,
                    value: device.utilizationText
                ))
            }
        }
        rows.append(StatsDetailRowModel(
            id: "updated",
            label: String(localized: "Last Update"),
            value: StatsOverviewMetrics.timestamp(statsManager.lastUpdated)
        ))
        return rows
    }

    /// Per-process GPU utilization is not measured. These rows keep the CPU share
    /// and resident memory the process list already collects.
    private var processRows: [StatsUsageRowModel] {
        topProcesses.enumerated().map { index, process in
            StatsUsageRowModel(
                id: "\(process.pid)-\(index)",
                name: process.name,
                metric: process.memoryUsage > 0 ? process.memoryUsageString : "",
                share: StatsFormatting.percentage(process.cpuUsage),
                fraction: StatsOverviewMetrics.barFraction(process.cpuUsage)
            )
        }
    }

    private func refreshProcesses() {
        topProcesses = Array(statsManager.getProcessesRankedByGPU().prefix(processLimit))
    }
}
