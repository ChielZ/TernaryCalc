import SwiftUI

struct DisplayView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.ternaryTheme) private var theme

    private let visibleSlots = 5      // 3 number + 2 op rows max
    private let numberWeight: CGFloat = 0.27
    private let opWeight:     CGFloat = 0.10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
                .fill(theme.displayBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
                        .strokeBorder(theme.displayFrameStroke, lineWidth: metrics.panelStroke)
                )
            content
                .padding(.horizontal, metrics.displayHeight * 0.05)
                .padding(.vertical, metrics.displayHeight * 0.04)
        }
        .frame(width: metrics.panelWidth, height: metrics.displayHeight)
    }

    private var content: some View {
        let rows = visibleRows()
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    @ViewBuilder
    private func rowView(_ row: DisplayRow) -> some View {
        switch row {
        case .number(let display):
            NumberGlyph(display: display, color: theme.displayDigit)
                .frame(maxWidth: .infinity, maxHeight: metrics.displayHeight * numberWeight, alignment: .trailing)
        case .op(let glyph):
            OperatorGlyphView(glyph: glyph, color: theme.displayOperator,
                              strokeFraction: 60.0 / 960.0)
                .opacity(theme.displayOperatorOpacity)
                .frame(maxWidth: metrics.displayHeight * opWeight,
                       maxHeight: metrics.displayHeight * opWeight)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .error:
            Text("OVR")
                .font(.system(size: metrics.displayHeight * 0.12, weight: .bold))
                .foregroundStyle(theme.displayDigit)
                .frame(maxWidth: .infinity, maxHeight: metrics.displayHeight * numberWeight, alignment: .trailing)
        }
    }

    /// Compose the visible rows: history followed by the in-progress entry,
    /// trimmed from the front so only the most recent `visibleSlots` show.
    private func visibleRows() -> [DisplayRow] {
        var rows = state.history
        if let entry = state.entryDisplay {
            rows.append(.number(entry))
        }
        if rows.count > visibleSlots {
            rows = Array(rows.suffix(visibleSlots))
        }
        return rows
    }
}
