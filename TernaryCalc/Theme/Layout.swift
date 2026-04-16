import SwiftUI

enum CalcLayout {
    static let calculatorAspectRatio: CGFloat = 11.0 / 16.0

    static let calculatorOuterPaddingRatio: CGFloat = 0.045
    static let panelGapRatio: CGFloat              = 0.030
    static let panelInnerPaddingRatio: CGFloat     = 0.045
    static let keyGapRatio: CGFloat                = 0.040

    static let calculatorCornerRatio: CGFloat = 0.025
    static let panelCornerRatio: CGFloat      = 0.025
    static let keyCornerRatio: CGFloat        = 0.060

    static let calculatorFrameStrokeRatio: CGFloat = 0.004
    static let panelFrameStrokeRatio: CGFloat      = 0.006
    static let keyFrameStrokeRatio: CGFloat        = 0.010

    static let extraTopMarginRatio: CGFloat = 0.06
    static let infoButtonRatio: CGFloat     = 0.05
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

    static func fit(into available: CGSize) -> CalculatorMetrics {
        let aspect = CalcLayout.calculatorAspectRatio
        let widthFromHeight = available.height * aspect
        let calcWidth = min(available.width, widthFromHeight)
        let calcHeight = calcWidth / aspect

        let outerPadding = calcWidth * CalcLayout.calculatorOuterPaddingRatio
        let panelGap     = calcWidth * CalcLayout.panelGapRatio
        let panelWidth   = calcWidth - 2 * outerPadding

        let keypadInnerPadding = panelWidth * CalcLayout.panelInnerPaddingRatio
        let keyGap             = panelWidth * CalcLayout.keyGapRatio
        let keyAvail = panelWidth - 2 * keypadInnerPadding - 3 * keyGap
        let keySize  = keyAvail / 4
        let keypadHeight = 3 * keySize + 2 * keyGap + 2 * keypadInnerPadding

        let displayHeight = calcHeight - keypadHeight - 2 * outerPadding - panelGap

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
            calcStroke: max(1, calcWidth * CalcLayout.calculatorFrameStrokeRatio),
            panelStroke: max(1, panelWidth * CalcLayout.panelFrameStrokeRatio),
            keyStroke: max(1, keySize * CalcLayout.keyFrameStrokeRatio)
        )
    }
}
