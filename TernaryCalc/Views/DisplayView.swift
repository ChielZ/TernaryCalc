import SwiftUI

struct DisplayView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.ternaryTheme) private var theme
    @Environment(\.ternaryDisplayMode) private var displayMode

    private let visibleSlots = 5   // 3 number rows + 2 op rows
    private let widthSlots   = 6   // 6 tri-trit slot-widths across — the row
                                   // height always tracks this (one tri-trit-
                                   // wide square), so number rows stay the
                                   // same size in both modes.

    /// Stroke ratio for display operator glyphs. The op symbol frame is
    /// `slotSize/2`, so a stroke ratio of 120/1400 yields an absolute stroke
    /// width of `slotSize · 60/1400` — exactly the digit stroke. Since the
    /// op glyph is smaller, this reads as relatively bolder than the digits.
    private let opStrokeRatio: CGFloat = 120.0 / 1400.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
                .fill(theme.displayBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
                        .strokeBorder(theme.displayFrameStroke, lineWidth: metrics.panelStroke)
                )
            GeometryReader { geo in
                content(in: geo.size)
            }
            .padding(.horizontal, metrics.panelStroke * 2)
            .padding(.vertical, metrics.panelStroke * 2)
        }
        .frame(width: metrics.panelWidth, height: metrics.displayHeight)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        // Width drives the tri-trit slot size: 6 full tri-trits exactly fill
        // the content width, so a 6-tri-trit number has equal left/right
        // margins (both being the trit glyph's built-in 100/1400 slot
        // padding).
        let slotSize = size.width / CGFloat(widthSlots)

        // Top/bottom padding equal to the trit-glyph built-in padding, so the
        // visual top/bottom margins match the left/right margins.
        let verticalPadding = slotSize * (TritGlyphMetrics.yTop / TritGlyphMetrics.boxSize)

        // Whatever vertical space isn't taken by the 3 number rows is shared
        // between the 2 operator rows.
        let innerH = size.height - 2 * verticalPadding
        let opHeight = max(0, (innerH - 3 * slotSize) / 2)

        let rows = visibleRows()

        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                // Two number/error rows in a row would otherwise sit flush.
                // Insert an `opHeight` gap so number rows always get the same
                // breathing room they'd get if an operator were between them.
                if index > 0, isNonOpRow(row), isNonOpRow(rows[index - 1]) {
                    Color.clear.frame(height: opHeight)
                }
                rowView(row, slotSize: slotSize, panelWidth: size.width, opHeight: opHeight)
            }
        }
        .padding(.vertical, verticalPadding)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private func isNonOpRow(_ row: DisplayRow) -> Bool {
        if case .ops = row { return false }
        return true
    }

    @ViewBuilder
    private func rowView(_ row: DisplayRow, slotSize: CGFloat, panelWidth: CGFloat, opHeight: CGFloat) -> some View {
        switch row {
        case .number(let display):
            numberRow(display, slotSize: slotSize, panelWidth: panelWidth)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .ops(let glyphs):
            opsRow(glyphs, opHeight: opHeight, slotSize: slotSize)
                .frame(height: opHeight)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .error:
            errorRow(slotSize: slotSize, panelWidth: panelWidth)
                .frame(height: slotSize)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func numberRow(_ display: DisplayTrits, slotSize: CGFloat, panelWidth: CGFloat) -> some View {
        switch displayMode {
        case .triTrit:
            FixedNumberRow(display: display, slotSize: slotSize, color: theme.displayDigit)
        case .simple:
            SimpleNumberRow(display: display,
                            glyphSize: slotSize,
                            panelWidth: panelWidth,
                            color: theme.displayDigit,
                            maxSlots: displayMode.rowCapacity)
        }
    }

    @ViewBuilder
    private func errorRow(slotSize: CGFloat, panelWidth: CGFloat) -> some View {
        switch displayMode {
        case .triTrit:
            OverflowRow(slotSize: slotSize, color: theme.displayDigit)
        case .simple:
            SimpleOverflowRow(glyphSize: slotSize,
                              panelWidth: panelWidth,
                              color: theme.displayDigit,
                              maxSlots: displayMode.rowCapacity)
        }
    }

    private func opsRow(_ glyphs: [OperatorGlyph], opHeight: CGFloat, slotSize: CGFloat) -> some View {
        // Op symbols are sized to half the digit (number) symbol height,
        // independent of the row height — the row may be taller and the
        // symbol gets vertically centered inside it.
        //
        // Right-margin alignment: the op glyph's design box runs to x=1300
        // (= 100/1400 padding from its frame right), but trits don't extend
        // to the design-box edge — a single `/` reaches design x=900, leaving
        // a 500/1400 right margin in its slot. To match that, we trail-shift
        // the op so its ink right-edge sits at the same column. With op frame
        // = slotSize/2, the inside-frame padding of 100/1400 contributes
        // (slotSize/2)·100/1400 = slotSize·50/1400; the remaining shift to
        // hit slotSize·500/1400 from the row's right edge is slotSize·
        // 450/1400.
        let opSymbolSize = slotSize / 2
        let trailingShift = slotSize * (50.0 / 1400.0)
        return HStack(spacing: opSymbolSize * 0.25) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, g in
                OperatorGlyphView(glyph: g,
                                  color: theme.displayOperator,
                                  strokeFraction: opStrokeRatio)
                    .frame(width: opSymbolSize, height: opSymbolSize)
            }
        }
        .opacity(theme.displayOperatorOpacity)
        .padding(.trailing, trailingShift)
    }

    private func visibleRows() -> [DisplayRow] {
        var rows: [DisplayRow] = state.history
        if let live = state.pendingOpsRow {
            rows.append(.ops(live))
        }
        if let entry = state.entryDisplay {
            rows.append(.number(entry))
        }
        // Trim leading rows until the effective visual row count (including
        // implicit spacers that the render inserts between adjacent non-op
        // rows) fits within `visibleSlots`. Otherwise e.g. `/+/=/+` would
        // overflow the display panel.
        while effectiveRowCount(rows) > visibleSlots {
            rows.removeFirst()
        }
        // The top row must be a number/error row, never an ops row — scroll
        // one more line if trimming leaves an ops row at the top.
        while case .ops = rows.first {
            rows.removeFirst()
        }
        return rows
    }

    private func effectiveRowCount(_ rows: [DisplayRow]) -> Int {
        guard rows.count > 1 else { return rows.count }
        var count = rows.count
        for i in 1..<rows.count {
            if isNonOpRow(rows[i - 1]) && isNonOpRow(rows[i]) {
                count += 1
            }
        }
        return count
    }
}
