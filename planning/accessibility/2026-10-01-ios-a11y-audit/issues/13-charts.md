## Problem

PR #206 gave `PerformanceChartView` and `InteractionTrendsChart` real Audio Graphs (`accessibilityChartDescriptor`, per-point labels). The other charts did not get the same treatment.

| Chart | State |
|---|---|
| `Features/Analytics/Components/ScatterChartView.swift:58-61,104-123,138-169` | Points are `.accessibilityHidden(true)` 12 pt circles with `onTapGesture`; the card is `.accessibilityElement(children: .ignore)` and speaks only axis min/max. Individual data points are unreachable without sight and touch. **High.** |
| `Features/Analytics/Components/PieChartView.swift:30-33,84-104` (3 uses) | One element with a long value string listing every segment; no chart descriptor; slices tied to the legend by colour only. Medium. |
| `Features/Analytics/Components/FunnelChartView.swift:32-35` | Same single-blob pattern; white labels on 500-level fills (2.5–3.8:1). Medium. |
| `MiniBarChart` | Hidden; its `TrendCard` label carries trend, count and average — acceptable, but `TrendCard.swift:26-27` omits the visible min–max range. |

The chart titles' `.isHeader` trait is discarded by the card-level `.ignore` (`PieChartView.swift:13-16`, `FunnelChartView.swift:13-16`, `ScatterChartView.swift:31-34`).

Related: #207 (13 hollow chart accessibility tests that only assert `XCTAssertNotNil(view)`).

## Fix

Rebuild with Swift Charts (`PointMark`, `SectorMark`, `BarMark`) with `.accessibilityLabel` / `.accessibilityValue` per mark and an `AXChartDescriptor`, following `PerformanceChartDescriptor` and `InteractionTrendsChartDescriptor`. If the custom drawing stays, expose each point as an element labelled "<label>, <x axis> <x>, <y axis> <y>" and enlarge the tap area.

## Done when

Each chart offers the Audio Graph rotor action and per-item navigation, and #207's tests assert real behaviour.

## Evidence

Source review. The automated audit also reported 3 "element detection" items on the Performance screen. Not tested with VoiceOver.

Part of the iOS accessibility audit — tracking issue: TRACKING
