import SwiftUI

enum CalcLayout {
    /// Base spacing unit, as a ratio of `calcWidth`. Used for:
    /// - padding between the calc outer edge and the display/keypad panels,
    /// - padding inside the keypad panel (between its edge and the keys),
    /// - gap between adjacent keys.
    /// The gap between display and keypad is `2 × baseSpacingRatio`.
    static let baseSpacingRatio: CGFloat = 0.04

    /// Single stroke width applied to every stroked element (calc frame,
    /// display panel, keypad panel, individual keys).
    static let strokeRatio: CGFloat = 0.006

    /// Corner radii (relative to their respective reference sizes).
    static let calculatorCornerRatio: CGFloat = 0.04
    static let panelCornerRatio: CGFloat      = 0.025
    static let keyCornerRatio: CGFloat        = 0.1

    static let extraTopMarginRatio: CGFloat = 0.06
    static let infoButtonRatio: CGFloat     = 0.05

    /// Vertical reserve per side above/below the centered calculator, as a
    /// ratio of the screen's *short* side. Using the short side keeps the
    /// reserve consistent across orientations (landscape no longer wastes a
    /// bunch of height just because it's wide).
    static let verticalReserveRatio: CGFloat = 0.15

    /// Soft cap on calc width as a fraction of the screen's short side.
    /// Only kicks in when the calc is height-constrained — which is the
    /// tablet-portrait case — pulling portrait proportions closer to
    /// landscape so the two orientations feel less lopsided.
    static let maxCalcWidthRatio: CGFloat = 0.85
}

struct CalculatorMetrics {
    let calcWidth: CGFloat
    let calcHeight: CGFloat
    let outerPadding: CGFloat
    let panelGap: CGFloat
    let panelWidth: CGFloat
    let displayHeight: CGFloat
    let keypadHeight: CGFloat
    let keypadInnerPadding: CGFloat
    let keyGap: CGFloat
    let keySize: CGFloat
    let calcCorner: CGFloat
    let panelCorner: CGFloat
    let keyCorner: CGFloat
    let calcStroke: CGFloat
    let panelStroke: CGFloat
    let keyStroke: CGFloat

    static func fit(into available: CGSize,
                    maxCalcWidth: CGFloat = .infinity) -> CalculatorMetrics {
        // The calc's overall aspect is no longer a free constant — display
        // and keypad panels are the same height by design, so calcHeight is
        // determined entirely by calcWidth and the spacing ratios:
        //   keySizeRatio       = (1 − 7s) / 4          (s = baseSpacingRatio)
        //   keypadHeightRatio  = 3·keySizeRatio + 4s
        //   heightOverWidth    = 2·keypadHeightRatio + 4s
        //                      = display + keypad + 2·outer + 1·panelGap
        let s = CalcLayout.baseSpacingRatio
        let keySizeRatio      = (1 - 7 * s) / 4
        let keypadHeightRatio = 3 * keySizeRatio + 4 * s
        let heightOverWidth   = 2 * keypadHeightRatio + 4 * s

        let widthFromHeight = available.height / heightOverWidth

        // If height is the tighter constraint (the calc "wants" to be wider
        // than the screen allows via aspect), apply `maxCalcWidth` so portrait
        // tablets don't end up with calcs glued to the edges. When width is
        // the tighter constraint (phone portrait), still leave a small margin
        // (the 0.928 factor) so the calc doesn't kiss the screen edges.
        let calcWidth: CGFloat
        if widthFromHeight < available.width {
            calcWidth = min(widthFromHeight, maxCalcWidth)
        } else {
            calcWidth = available.width * 0.928
        }
        let calcHeight = calcWidth * heightOverWidth

        let spacing = calcWidth * CalcLayout.baseSpacingRatio
        let stroke  = max(1, calcWidth * CalcLayout.strokeRatio)

        let outerPadding = spacing
        let panelGap     = 2 * spacing
        let panelWidth   = calcWidth - 2 * outerPadding

        let keypadInnerPadding = spacing
        let keyGap             = spacing
        let keyAvail = panelWidth - 2 * keypadInnerPadding - 3 * keyGap
        let keySize  = keyAvail / 4
        let keypadHeight = 3 * keySize + 2 * keyGap + 2 * keypadInnerPadding

        let displayHeight = keypadHeight

        return CalculatorMetrics(
            calcWidth: calcWidth,
            calcHeight: calcHeight,
            outerPadding: outerPadding,
            panelGap: panelGap,
            panelWidth: panelWidth,
            displayHeight: displayHeight,
            keypadHeight: keypadHeight,
            keypadInnerPadding: keypadInnerPadding,
            keyGap: keyGap,
            keySize: keySize,
            calcCorner: calcWidth * CalcLayout.calculatorCornerRatio,
            panelCorner: panelWidth * CalcLayout.panelCornerRatio,
            keyCorner: keySize * CalcLayout.keyCornerRatio,
            calcStroke: stroke,
            panelStroke: stroke,
            keyStroke: stroke
        )
    }
}
