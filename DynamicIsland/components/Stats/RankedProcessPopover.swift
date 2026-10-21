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
    
    private var usesGlassStyle: Bool {
        switch rankingType {
        case .cpu, .memory, .gpu:
            return true
        case .network, .disk:
            return false
        }
    }

    private var configuration: (width: CGFloat, minHeight: CGFloat, maxHeight: CGFloat?, padding: CGFloat) {
        switch rankingType {
        case .cpu, .memory, .gpu:
            return (460, 680, 680, 0)
        case .network, .disk:
            return (360, 320, nil, 0)
        }
    }
    
    var body: some View {
        popoverContent
            .padding(configuration.padding)
            .frame(width: configuration.width)
            .frame(minHeight: configuration.minHeight, maxHeight: configuration.maxHeight)
            .background(usesGlassStyle ? Color.clear : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: usesGlassStyle ? 24 : 14, style: .continuous))
            .shadow(
                color: .black.opacity(usesGlassStyle ? 0.55 : 0.28),
                radius: usesGlassStyle ? 30 : 12,
                x: 0,
                y: usesGlassStyle ? 16 : 8
            )
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(usesGlassStyle ? Font.system(size: 16, weight: .semibold) : Font.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(usesGlassStyle ? Color.white.opacity(0.55) : Color.secondary)
                        .padding(usesGlassStyle ? 14 : 10)
                }
                .buttonStyle(.plain)
            }
            .modifier(StatsPopoverChrome(glass: usesGlassStyle))
            .overlay(alignment: .center) {
                PopoverHoverSensor { hovering in
                    onHoverChange?(hovering)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
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

private struct StatsPopoverChrome: ViewModifier {
    let glass: Bool

    func body(content: Content) -> some View {
        if glass {
            content
                .presentationBackground(.clear)
                .presentationCornerRadius(24)
        } else {
            content
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