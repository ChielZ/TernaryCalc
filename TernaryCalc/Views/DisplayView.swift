import SwiftUI

struct DisplayView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.ternaryTheme) private var theme

    private let visibleSlots = 5   // 3 number rows + 2 op rows
    private let widthSlots   = 6   // 6 tri-trit slots across

    /// Stroke ratio for display operator glyphs — thicker than the digit
    /// stroke (60/1400) so the operator row doesn't look skinny at small sizes.
    private let opStrokeRatio: CGFloat = 100.0 / 1400.0

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
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(row, slotSize: slotSize, opHeight: opHeight)
            }
        }
        .padding(.vertical, verticalPadding)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    @ViewBuilder
    private func rowView(_ row: DisplayRow, slotSize: CGFloat, opHeight: CGFloat) -> some View {
        switch row {
        case .number(let display):
            FixedNumberRow(display: display, slotSize: slotSize, color: theme.displayDigit)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .ops(let glyphs):
            opsRow(glyphs, opHeight: opHeight, slotSize: slotSize)
                .frame(height: opHeight)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .error:
            OverflowRow(slotSize: slotSize, color: theme.displayDigit)
                .frame(height: slotSize)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func opsRow(_ glyphs: [OperatorGlyph], opHeight: CGFloat, slotSize: CGFloat) -> some View {
        // Each op glyph is its own 1400-unit box with built-in padding of
        // 100/1400 of its side. A trailing shift equal to
        //   (slotSize − opHeight) × 100/1400
        // aligns the op glyph's ink right-edge with the digit ink right-edge
        // so the number row and the operator row share the same visual right
        // margin.
        let padRatio = TritGlyphMetrics.yTop / TritGlyphMetrics.boxSize
        let trailingShift = max(0, (slotSize - opHeight) * padRatio)
        return HStack(spacing: opHeight * 0.25) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, g in
                OperatorGlyphView(glyph: g,
                                  color: theme.displayOperator,
                                  strokeFraction: opStrokeRatio)
                    .frame(width: opHeight, height: opHeight)
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
        if rows.count > visibleSlots {
            rows = Array(rows.suffix(visibleSlots))
        }
        // The top row must be a number/error row, never an ops row — scroll
        // one more line if trimming to `visibleSlots` leaves an ops row at the
        // top.
        while case .ops = rows.first {
            rows.removeFirst()
        }
        return rows
    }
}
