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
#if os(macOS)
import AppKit
#endif

struct RankedProcessPopover: View {
    let rankingType: ProcessRankingType
    @Environment(\.dismiss) private var dismiss
    
    // Callback to notify parent about hover state
    var onHoverChange: ((Bool) -> Void)?
    
    private var configuration: (width: CGFloat, minHeight: CGFloat, padding: CGFloat) {
        switch rankingType {
        case .cpu, .memory, .gpu:
            return (StatsPopoverMetrics.popoverWidth, 360, 0)
        case .network, .disk:
            return (360, 320, 0)
        }
    }

    /// CPU, Memory, and GPU draw the close button in the shared header.
    private var pinsCloseButton: Bool {
        switch rankingType {
        case .cpu, .memory, .gpu:
            return false
        case .network, .disk:
            return true
        }
    }
    
    var body: some View {
        popoverBody
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 8)
            .overlay(alignment: .topTrailing) {
                if pinsCloseButton {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(8)
                    .accessibilityLabel(String(localized: "Close"))
                }
            }
            .overlay {
                PopoverHoverSensor { hovering in
                    onHoverChange?(hovering)
                }
                .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private var popoverBody: some View {
        if usesFittedFrame {
            FittedStatsPopover(width: configuration.width) {
                popoverContent
            }
        } else {
            popoverContent
                .padding(configuration.padding)
                .frame(width: configuration.width)
                .frame(minHeight: configuration.minHeight)
        }
    }

    private var usesFittedFrame: Bool {
        switch rankingType {
        case .cpu, .memory, .gpu:
            return true
        case .network, .disk:
            return false
        }
    }
    
    @ViewBuilder
    private var popoverContent: some View {
        switch rankingType {
        case .cpu:
            CPUStatsDetailView()
        case .memory:
            MemoryStatsDetailView()
        case .gpu:
            GPUStatsDetailView()
        case .network:
            NetworkStatsDetailView()
        case .disk:
            DiskStatsDetailView()
        }
    }
}

private struct PopoverContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Sizes the popover to its content, and scrolls only when that content is taller
/// than the visible screen. A fixed min height here previously clipped the chart,
/// and a flexible width clipped the leading title.
private struct FittedStatsPopover<Content: View>: View {
    let width: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 0

    private var maxHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        return max(560, visible - 48)
    }

    var body: some View {
        let measured = contentHeight > 1 ? contentHeight : nil
        let height = measured.map { min($0, maxHeight) }
        let scrolls = contentHeight > maxHeight + 1

        ScrollView(.vertical) {
            content()
                .frame(width: width, alignment: .topLeading)
                .fixedSize(horizontal: true, vertical: true)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: PopoverContentHeightKey.self, value: proxy.size.height)
                    }
                }
        }
        .scrollDisabled(!scrolls)
        .scrollIndicators(scrolls ? .automatic : .hidden)
        .frame(width: width, height: height, alignment: .top)
        .fixedSize(horizontal: true, vertical: true)
        .onPreferenceChange(PopoverContentHeightKey.self) { newValue in
            guard newValue > 1, abs(newValue - contentHeight) > 0.5 else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                contentHeight = newValue
            }
        }
    }
}

#if os(macOS)
private struct PopoverHoverSensor: NSViewRepresentable {
    var onHoverChange: ((Bool) -> Void)?

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onHoverChange = onHoverChange
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onHoverChange = onHoverChange
    }

    final class TrackingView: NSView {
        var onHoverChange: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
            let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            onHoverChange?(true)
        }

        override func mouseExited(with event: NSEvent) {
            onHoverChange?(false)
        }

        deinit {
            onHoverChange?(false)
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
        }
    }
}
#endif