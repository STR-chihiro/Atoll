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

import AppKit
import Darwin
import Defaults
import SwiftUI

struct StatsAccent: Equatable {
    let start: Color
    let end: Color

    static let cpu = StatsAccent(
        start: Color(red: 34.0 / 255.0, green: 211.0 / 255.0, blue: 238.0 / 255.0),
        end: Color(red: 59.0 / 255.0, green: 130.0 / 255.0, blue: 246.0 / 255.0)
    )
    static let memory = StatsAccent(
        start: Color(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0),
        end: Color(red: 20.0 / 255.0, green: 184.0 / 255.0, blue: 166.0 / 255.0)
    )
    static let gpu = StatsAccent(
        start: Color(red: 192.0 / 255.0, green: 132.0 / 255.0, blue: 252.0 / 255.0),
        end: Color(red: 236.0 / 255.0, green: 72.0 / 255.0, blue: 153.0 / 255.0)
    )

    var horizontal: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing)
    }

    var diagonal: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum StatsPalette {
    static let muted = Color(red: 139.0 / 255.0, green: 147.0 / 255.0, blue: 167.0 / 255.0)
    static let caption = Color(red: 148.0 / 255.0, green: 163.0 / 255.0, blue: 184.0 / 255.0)
    static let value = Color(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 249.0 / 255.0)
    static let name = Color(red: 229.0 / 255.0, green: 231.0 / 255.0, blue: 235.0 / 255.0)
    static let faint = Color(red: 100.0 / 255.0, green: 116.0 / 255.0, blue: 139.0 / 255.0)
    static let idle = Color(red: 71.0 / 255.0, green: 85.0 / 255.0, blue: 105.0 / 255.0)
    static let compressed = Color(red: 94.0 / 255.0, green: 234.0 / 255.0, blue: 212.0 / 255.0)
    static let panel = Color(red: 18.0 / 255.0, green: 20.0 / 255.0, blue: 28.0 / 255.0)
}

enum StatsOverviewMetrics {
    /// The approved layout draws each usage bar at twice the printed percent so a
    /// light load is still visible. The number beside the bar stays the real value.
    static func barFraction(_ percent: Double) -> Double {
        min(max(percent, 0) / 50.0, 1)
    }

    static func recentTitle(sampleCount: Int) -> String {
        let interval = Defaults[.statsUpdateInterval]
        let seconds = max(1, Int((Double(max(sampleCount, 1)) * interval).rounded()))
        return String(format: String(localized: "Recent %d s", defaultValue: "Recent %d s"), seconds)
    }

    static func peakTitle(_ peak: Double) -> String {
        String(format: String(localized: "Peak %@", defaultValue: "Peak %@"), StatsFormatting.percentage(peak))
    }

    static func timestamp(_ date: Date) -> String {
        guard date != .distantPast else { return "—" }
        return Self.timeFormatter.string(from: date)
    }

    static func gigabytePair(used: UInt64, total: UInt64) -> String {
        "\(gigabytes(used)) / \(gigabytes(total))"
    }

    static func gigabytes(_ bytes: UInt64) -> String {
        let value = Double(bytes) / 1_073_741_824
        let digits: Int
        if value >= 10 {
            digits = 0
        } else if value >= 1 {
            digits = 1
        } else {
            digits = 2
        }
        return String(format: "%.\(digits)f GB", value)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct StatsLegendItem: Identifiable {
    let id: String
    let color: Color
    let title: String
    let value: String
}

struct StatsDetailRowModel: Identifiable {
    let id: String
    let label: String
    let value: String
    var tint: Color?
    var showsDot: Bool = false
}

struct StatsUsageRowModel: Identifiable {
    let id: String
    let name: String
    let metric: String
    let share: String
    let fraction: Double
}

struct StatsOverviewSurface<Content: View>: View {
    let accent: StatsAccent
    let content: Content

    init(accent: StatsAccent, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            StatsFrostedBackground()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            StatsPalette.panel.opacity(0.72)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            RadialGradient(
                colors: [accent.end.opacity(0.55), accent.end.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: 160
            )
            .frame(width: 380, height: 210)
            .offset(y: -78)
            .opacity(0.5)
            .allowsHitTesting(false)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.14), Color.white.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1)
            .padding(.horizontal, 24)
            .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
    }
}

private struct StatsFrostedBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct StatsOverviewHeader: View {
    let symbol: String
    let title: String
    let subtitle: String
    let accent: StatsAccent

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.diagonal)
                    .shadow(color: accent.end.opacity(0.7), radius: 8)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(StatsPalette.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(accent.start)
                    .frame(width: 7, height: 7)
                    .shadow(color: accent.start, radius: 4)
                Text(String(localized: "Live", defaultValue: "Live"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 203.0 / 255.0, green: 213.0 / 255.0, blue: 225.0 / 255.0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.trailing, 18)
    }
}

struct StatsGradientRing: View {
    let progress: Double
    let primary: String
    let caption: String
    let accent: StatsAccent
    var diameter: CGFloat = 128
    var lineWidth: CGFloat = 11
    var primarySize: CGFloat = 26

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            if clamped > 0.004 {
                Circle()
                    .trim(from: 0, to: CGFloat(clamped))
                    .stroke(
                        accent.diagonal,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.end.opacity(0.9), radius: 6)
            }
            VStack(spacing: 3) {
                Text(primary)
                    .font(.system(size: primarySize, weight: primarySize >= 22 ? .bold : .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundColor(StatsPalette.caption)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .combine)
        .animation(.easeOut(duration: 0.35), value: clamped)
    }
}

struct StatsRingRow: View {
    let leading: (Double, String)?
    let centerValue: String
    let centerCaption: String
    let centerProgress: Double
    let trailing: (Double, String)?
    let accent: StatsAccent

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            sideSlot(leading)
            Spacer(minLength: 0)
            StatsGradientRing(
                progress: centerProgress / 100,
                primary: centerValue,
                caption: centerCaption,
                accent: accent,
                diameter: 142,
                lineWidth: 12,
                primarySize: 26
            )
            Spacer(minLength: 0)
            sideSlot(trailing)
        }
        .padding(.top, 6)
        .padding(.horizontal, 2)
    }

    private var reservesSideSlots: Bool {
        leading != nil || trailing != nil
    }

    @ViewBuilder
    private func sideSlot(_ value: (Double, String)?) -> some View {
        if let value {
            StatsGradientRing(
                progress: value.0 / 100,
                primary: StatsFormatting.percentage(value.0),
                caption: value.1,
                accent: accent,
                diameter: 104,
                lineWidth: 9,
                primarySize: 16
            )
        } else if reservesSideSlots {
            Color.clear.frame(width: 104, height: 104)
        }
    }
}

struct StatsHistoryCard: View {
    let samples: [Double]
    let accent: StatsAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(StatsOverviewMetrics.recentTitle(sampleCount: samples.count))
                Spacer()
                Text(StatsOverviewMetrics.peakTitle(samples.max() ?? 0))
            }
            .font(.system(size: 12))
            .foregroundColor(StatsPalette.muted)

            StatsSparkline(values: samples, accent: accent)
                .frame(height: 46)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(StatsCardChrome())
    }
}

struct StatsCoreBars: View {
    let bars: [CPUCoreLayout.Bar]
    let accent: StatsAccent

    var body: some View {
        Group {
            if bars.count > 12 {
                ScrollView(.horizontal) {
                    barRow
                }
                .scrollIndicators(.never)
            } else {
                barRow
            }
        }
    }

    private var barRow: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(bars) { bar in
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accent.end, accent.start],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: barHeight(bar.usage))
                            .shadow(color: accent.start.opacity(0.45), radius: 4)
                    }
                    .frame(height: 44)
                    Text(bar.label)
                        .font(.system(size: 10.5))
                        .foregroundColor(StatsPalette.muted)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(bar.label) \(StatsFormatting.percentage(bar.usage))")
                .frame(maxWidth: bars.count > 12 ? 32 : .infinity)
                .frame(width: bars.count > 12 ? 32 : nil)
            }
        }
    }

    private func barHeight(_ usage: Double) -> CGFloat {
        let ratio = min(max(usage, 0), 100) / 100
        guard ratio > 0 else { return 0 }
        return CGFloat(max(2.0, 44 * ratio))
    }
}

struct StatsLegendGrid: View {
    let items: [StatsLegendItem]

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    Text(item.title)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 203.0 / 255.0, green: 213.0 / 255.0, blue: 225.0 / 255.0))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(item.value)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 2)
    }
}

struct StatsDetailCard: View {
    let rows: [StatsDetailRowModel]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.label)
                        .font(.system(size: 13))
                        .foregroundColor(StatsPalette.muted)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        if row.showsDot, let tint = row.tint {
                            Circle()
                                .fill(tint)
                                .frame(width: 7, height: 7)
                        }
                        Text(row.value)
                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            .foregroundColor(row.tint ?? StatsPalette.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(.vertical, 6)
                if index < rows.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(StatsCardChrome())
    }
}

struct StatsPressureGauge: View {
    let level: MemoryPressureLevel
    let accent: StatsAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(String(localized: "Pressure"))
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 203.0 / 255.0, green: 213.0 / 255.0, blue: 225.0 / 255.0))
                Spacer()
                Text(statusTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0).opacity(0.18),
                                    Color(red: 250.0 / 255.0, green: 204.0 / 255.0, blue: 21.0 / 255.0).opacity(0.18),
                                    Color(red: 239.0 / 255.0, green: 68.0 / 255.0, blue: 68.0 / 255.0).opacity(0.18)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Capsule()
                        .fill(accent.horizontal)
                        .frame(width: max(8, proxy.size.width * fill))
                        .shadow(color: accent.start.opacity(0.85), radius: 5)
                }
            }
            .frame(height: 8)
            HStack {
                Text(String(localized: "Normal"))
                Spacer()
                Text(String(localized: "Warning"))
                Spacer()
                Text(String(localized: "Critical"))
            }
            .font(.system(size: 10.5))
            .foregroundColor(StatsPalette.faint)
        }
        .padding(.horizontal, 2)
    }

    private var statusTitle: String {
        switch level {
        case .normal:
            return String(localized: "Normal")
        case .warning:
            return String(localized: "Warning")
        case .critical:
            return String(localized: "Critical")
        }
    }

    private var statusColor: Color {
        switch level {
        case .normal:
            return accent.start
        case .warning:
            return Color(red: 251.0 / 255.0, green: 146.0 / 255.0, blue: 60.0 / 255.0)
        case .critical:
            return Color(red: 248.0 / 255.0, green: 113.0 / 255.0, blue: 113.0 / 255.0)
        }
    }

    /// Discrete pressure level drawn into the matching third of the track.
    /// macOS only reports normal / warning / critical, not a percentage.
    private var fill: CGFloat {
        switch level {
        case .normal:
            return 0.28
        case .warning:
            return 0.62
        case .critical:
            return 0.92
        }
    }
}

struct StatsProcessSection: View {
    let title: String
    let trailing: String
    let rows: [StatsUsageRowModel]
    let accent: StatsAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(trailing)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(StatsPalette.muted)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.bottom, 4)

            if rows.isEmpty {
                Text(String(localized: "No process data yet. Keep stats open for a moment."))
                    .font(.system(size: 12))
                    .foregroundColor(StatsPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 10) {
                            Text(row.name)
                                .font(.system(size: 13.5))
                                .foregroundColor(StatsPalette.name)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if !row.metric.isEmpty {
                                Text(row.metric)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(StatsPalette.muted)
                                    .lineLimit(1)
                            }
                            Text(row.share)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 62, alignment: .trailing)
                                .lineLimit(1)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                Capsule()
                                    .fill(accent.horizontal)
                                    .frame(width: max(0, proxy.size.width * min(max(row.fraction, 0), 1)))
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.vertical, 7)
                }
            }
        }
    }
}

private struct StatsSparkline: View {
    let values: [Double]
    let accent: StatsAccent

    var body: some View {
        GeometryReader { proxy in
            let points = plotPoints(in: proxy.size)
            ZStack {
                sparkFill(points, in: proxy.size)
                    .fill(
                        LinearGradient(
                            colors: [accent.end.opacity(0.35), accent.end.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                sparkStroke(points)
                    .stroke(
                        LinearGradient(colors: [accent.start, accent.end], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    private func plotPoints(in size: CGSize) -> [CGPoint] {
        let series = values.count >= 2 ? values : [values.first ?? 0, values.first ?? 0]
        let width = max(size.width, 1)
        let height = max(size.height - 4, 1)
        return series.enumerated().map { index, value in
            let x = width * CGFloat(index) / CGFloat(max(series.count - 1, 1))
            let clamped = min(max(value, 0), 100)
            let y = 2 + height * (1 - CGFloat(clamped / 100))
            return CGPoint(x: x, y: y)
        }
    }

    private func sparkStroke(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func sparkFill(_ points: [CGPoint], in size: CGSize) -> Path {
        var path = sparkStroke(points)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

private struct StatsCardChrome: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.035))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

/// Per-core bars and the performance / efficiency rings.
///
/// `host_processor_info` lists logical CPUs from the lowest performance tier to the
/// highest (efficiency cores first on M1–M4). Tier sizes come from `hw.perflevelN`,
/// which is the documented split; the IORegistry cluster counts are only a fallback
/// when that sysctl is missing and the two counts add up to the sampled cores.
struct CPUCoreLayout {
    struct Bar: Identifiable {
        let id: Int
        let label: String
        let usage: Double
    }

    struct Ring {
        let caption: String
        let percent: Double
    }

    let bars: [Bar]
    let leading: Ring?
    let trailing: Ring?
    let summary: String

    static func resolve(cores: [CPUCoreUsage]) -> CPUCoreLayout {
        guard !cores.isEmpty else {
            return CPUCoreLayout(bars: [], leading: nil, trailing: nil, summary: "—")
        }
        guard let tiers = readTiers(coreCount: cores.count) else {
            return numeric(cores)
        }

        var index = 0
        var grouped: [TierGroup] = []
        for tier in tiers.reversed() {
            var tierBars: [Bar] = []
            let prefix = badgePrefix(tier.name)
            for offset in 0..<tier.count {
                guard index < cores.count else { break }
                tierBars.append(Bar(id: cores[index].id, label: "\(prefix)\(offset + 1)", usage: cores[index].usage))
                index += 1
            }
            grouped.append(TierGroup(tier: tier, bars: tierBars))
        }
        guard index == cores.count else {
            return numeric(cores)
        }

        let display = Array(grouped.reversed())
        let bars = display.flatMap { $0.bars }
        let sideRings = display.count > 1
        return CPUCoreLayout(
            bars: bars,
            leading: sideRings ? ring(for: display.first) : nil,
            trailing: sideRings ? ring(for: display.last) : nil,
            summary: summary(for: display.map(\.tier), total: cores.count)
        )
    }

    private struct Tier {
        let name: String
        let count: Int
    }

    private struct TierGroup {
        let tier: Tier
        let bars: [Bar]
    }

    private static func ring(for group: TierGroup?) -> Ring? {
        guard let group, !group.bars.isEmpty else { return nil }
        let total = group.bars.reduce(0) { $0 + $1.usage }
        return Ring(caption: caption(group.tier.name), percent: total / Double(group.bars.count))
    }

    private static func summary(for tiers: [Tier], total: Int) -> String {
        var counts: [String: Int] = [:]
        for tier in tiers {
            counts[tier.name, default: 0] += tier.count
        }
        if counts.count == 2, let performance = counts["Performance"], let efficiency = counts["Efficiency"] {
            return String(
                format: String(localized: "%d performance + %d efficiency", defaultValue: "%d performance + %d efficiency"),
                performance,
                efficiency
            )
        }
        if counts.count == 2, let superCores = counts["Super"], let performance = counts["Performance"] {
            return String(
                format: String(localized: "%d super + %d performance", defaultValue: "%d super + %d performance"),
                superCores,
                performance
            )
        }
        return "\(total)"
    }

    private static func numeric(_ cores: [CPUCoreUsage]) -> CPUCoreLayout {
        let bars = cores.map { Bar(id: $0.id, label: "\($0.id + 1)", usage: $0.usage) }
        return CPUCoreLayout(bars: bars, leading: nil, trailing: nil, summary: "\(cores.count)")
    }

    private static func readTiers(coreCount: Int) -> [Tier]? {
        if let tiers = sysctlTiers(), tiers.reduce(0, { $0 + $1.count }) == coreCount {
            return tiers
        }
        let clusters = AppleHardwareInfo.shared.clusterCounts
        if clusters.eCores > 0, clusters.pCores > 0, clusters.eCores + clusters.pCores == coreCount {
            return [
                Tier(name: "Performance", count: clusters.pCores),
                Tier(name: "Efficiency", count: clusters.eCores)
            ]
        }
        return nil
    }

    /// `hw.perflevel0` is the fastest tier. Later levels are slower.
    private static func sysctlTiers() -> [Tier]? {
        guard let levels = sysctlInt("hw.nperflevels"), levels > 1 else { return nil }
        var tiers: [Tier] = []
        for level in 0..<levels {
            guard let count = sysctlInt("hw.perflevel\(level).logicalcpu"), count > 0 else { continue }
            let rawName = sysctlString("hw.perflevel\(level).name") ?? ""
            tiers.append(Tier(name: canonicalName(rawName, level: level, levels: levels), count: count))
        }
        return tiers.count > 1 ? tiers : nil
    }

    private static func canonicalName(_ name: String, level: Int, levels: Int) -> String {
        switch name {
        case "Performance", "Efficiency", "Super":
            return name
        case "":
            return level == levels - 1 ? "Efficiency" : "Performance"
        default:
            return name
        }
    }

    private static func badgePrefix(_ name: String) -> String {
        switch name {
        case "Efficiency":
            return "E"
        case "Performance":
            return "P"
        case "Super":
            return "S"
        default:
            return String(name.prefix(1)).uppercased()
        }
    }

    private static func caption(_ name: String) -> String {
        switch name {
        case "Performance":
            return String(localized: "Performance Cores", defaultValue: "Performance")
        case "Efficiency":
            return String(localized: "Efficiency Cores", defaultValue: "Efficiency")
        case "Super":
            return String(localized: "Super Cores", defaultValue: "Super")
        default:
            return name
        }
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
