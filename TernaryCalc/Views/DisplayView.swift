import SwiftUI

struct DisplayView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.ternaryTheme) private var theme

    private let visibleSlots = 5
    private let widthSlots   = 6   // 6 tri-trit slots across

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
        // 3 number rows + 2 op rows. Op rows are ~0.35 the height of a number
        // row. Row gap is small. Solve for slotSize that fits both dimensions.
        let horizontalPadding = size.width * 0.02
        let verticalPadding   = size.height * 0.02
        let innerW = size.width  - 2 * horizontalPadding
        let innerH = size.height - 2 * verticalPadding
        let opRatio: CGFloat = 0.35
        let rowGap:  CGFloat = 0.00
        // totalH = 3 * slot + 2 * slot*opRatio + 4*gap*slot = slot*(3 + 2*opRatio + 4*gap)
        let heightPerUnit = 3 + 2 * opRatio + 4 * rowGap
        let slotByW = innerW / CGFloat(widthSlots)
        let slotByH = innerH / heightPerUnit
        let slotSize = min(slotByW, slotByH)
        let opSize   = slotSize * opRatio
        let gap      = slotSize * rowGap

        let rows = visibleRows()

        VStack(spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(row, slotSize: slotSize, opSize: opSize)
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    @ViewBuilder
    private func rowView(_ row: DisplayRow, slotSize: CGFloat, opSize: CGFloat) -> some View {
        switch row {
        case .number(let display):
            FixedNumberRow(display: display, slotSize: slotSize, color: theme.displayDigit)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .ops(let glyphs):
            opsRow(glyphs, opSize: opSize)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .error:
            Text("OVR")
                .font(.system(size: slotSize * 0.4, weight: .bold))
                .foregroundStyle(theme.displayDigit)
                .frame(maxWidth: .infinity, maxHeight: slotSize, alignment: .trailing)
        }
    }

    private func opsRow(_ glyphs: [OperatorGlyph], opSize: CGFloat) -> some View {
        HStack(spacing: opSize * 0.25) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, g in
                OperatorGlyphView(glyph: g,
                                  color: theme.displayOperator,
                                  strokeFraction: TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize)
                    .frame(width: opSize, height: opSize)
            }
        }
        .opacity(theme.displayOperatorOpacity)
    }

    /// History + live pending op + live entry, trimmed to the most recent
    /// `visibleSlots` rows. Numbers are re-fitted into the fixed-slot display.
    private func visibleRows() -> [DisplayRow] {
        var rows: [DisplayRow] = []
        for row in state.history {
            rows.append(row)
        }
        if let live = state.pendingOpsRow {
            rows.append(.ops(live))
        }
        if let entry = state.entryDisplay {
            rows.append(.number(entry))
        }
        if rows.count > visibleSlots {
            rows = Array(rows.suffix(visibleSlots))
        }
        return rows
    }
}
