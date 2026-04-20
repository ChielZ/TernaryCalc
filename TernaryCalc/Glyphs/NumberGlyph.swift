import SwiftUI

/// Decimal-point / ring glyph. Line width is `strokeFraction × frame height`
/// — intentionally tied to the frame *height* (not its short side) so the
/// ring's stroke matches the trit stroke at the given size. The inner
/// opening diameter equals the line width (per design spec), which fixes the
/// ring's outer diameter at 3 × line width.
struct PointGlyph: View {
    var color: Color = .black
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize
    var placement: PointPlacement = .centered

    var body: some View {
        GeometryReader { geo in
            let refHeight = geo.size.height
            let lineWidth = refHeight * strokeFraction
            let r = 1.5 * lineWidth                // → inner ∅ = 1 × lineWidth
            let cx = geo.size.width / 2
            let cy: CGFloat = {
                switch placement {
                case .centered:
                    return geo.size.height / 2
                case .baseline(let b):
                    // Outer edge of the ring sits on the baseline.
                    return geo.size.height * b - r
                }
            }()
            Circle()
                .strokeBorder(color, lineWidth: lineWidth)
                .frame(width: 2 * r, height: 2 * r)
                .position(x: cx, y: cy)
        }
    }
}

/// One row of `maxSlots` fixed-size tri-trit slots, right-aligned. Empty
/// leading slots are blank. A decimal-point glyph sits on the boundary
/// between the integer and fractional slots without consuming a slot.
struct FixedNumberRow: View {
    let display: DisplayTrits
    let slotSize: CGFloat
    var color: Color = .black
    var maxSlots: Int = 6
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize

    /// Each tri-trit is rendered as its *value* glyph. Integer tri-trits strip
    /// leading zeros (so `||/` → `/` = 1 at the least-significant end of the
    /// slot), while fractional tri-trits strip TRAILING zeros (so `/||` → `/`
    /// = 1/3 at the most-significant end of the slot — and `|/|` → `|/` =
    /// 1/9). All-zero tri-trits collapse to a single `|`. The glyph centers
    /// itself within the slot via `tritCenters`.
    ///
    /// Exception: when `display.latest` points at a side, that side's last
    /// tri-trit is the typing frontier and renders verbatim — every typed
    /// trit visibly lands, even leading/trailing zeros that would otherwise
    /// be stripped.
    private var integerSlots: [[Trit]] {
        let raw = display.integer.isEmpty ? [Trit.zero] : display.integer
        if display.latest != .none {
            // Entry mode (promote model) — applies whether the typing
            // frontier is on the integer or the fractional side. We must
            // group the typed integer trits the same way the value model
            // does: from the left in typing order, so the first 3 typed
            // sit in the highest-significance slot and the last (possibly
            // partial) group is the LSB tri-trit. Otherwise the displayed
            // value would diverge from the value used for calculation as
            // soon as the user pressed `.`.
            var groups: [[Trit]] = []
            var i = 0
            while i < raw.count {
                let end = min(i + 3, raw.count)
                let group = Array(raw[i..<end])
                let isLast = end == raw.count
                // The integer-side last tri-trit only renders verbatim when
                // the integer side is the typing frontier. Once the user
                // crosses into fractional, all integer tri-trits are locked
                // and get stripped to their value glyph.
                if isLast && display.latest == .integer {
                    groups.append(group)
                } else {
                    groups.append(stripLeadingZeros(group))
                }
                i += 3
            }
            return groups
        }
        // Committed value — pad leading zeros to align to a tri-trit
        // boundary and strip leading zeros from each group.
        let padCount = (3 - raw.count % 3) % 3
        let padded = Array(repeating: Trit.zero, count: padCount) + raw
        var groups: [[Trit]] = []
        for start in stride(from: 0, to: padded.count, by: 3) {
            groups.append(stripLeadingZeros(Array(padded[start..<start + 3])))
        }
        return groups
    }

    private var fractionalSlots: [[Trit]] {
        guard !display.fractional.isEmpty else { return [] }
        var groups: [[Trit]] = []
        var i = 0
        while i < display.fractional.count {
            let end = min(i + 3, display.fractional.count)
            var group = Array(display.fractional[i..<end])
            let isLast = end == display.fractional.count
            if isLast && display.latest == .fractional {
                // Typing frontier — render verbatim, even if the slot has
                // filled to 3 trits (so the user can tell `|/|` apart from
                // a `|/` that still has room to grow).
                groups.append(group)
            } else {
                // Locked tri-trit — pad to 3 with trailing zeros so place
                // values align, then strip trailing zeros to show the tri-
                // trit's value glyph.
                while group.count < 3 { group.append(.zero) }
                groups.append(stripTrailingZeros(group))
            }
            i += 3
        }
        return groups
    }

    private func stripLeadingZeros(_ group: [Trit]) -> [Trit] {
        var out = group
        while out.count > 1, out.first == .zero { out.removeFirst() }
        return out
    }

    private func stripTrailingZeros(_ group: [Trit]) -> [Trit] {
        var out = group
        while out.count > 1, out.last == .zero { out.removeLast() }
        return out
    }

    var body: some View {
        let ints  = integerSlots
        let fracs = fractionalSlots
        // When the decimal is shown but no fractional tri-trits exist yet
        // (user just pressed `.`), reserve one slot's worth of space to the
        // right of the integer so the decimal has somewhere to sit.
        let reservePlaceholder = display.showDecimal && fracs.isEmpty
        let used  = ints.count + fracs.count + (reservePlaceholder ? 1 : 0)
        let empty = max(0, maxSlots - used)
        let pointFrameW = slotSize * 0.4
        let boundaryX = slotSize * CGFloat(empty + ints.count)

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(0..<empty, id: \.self) { _ in
                    Color.clear.frame(width: slotSize, height: slotSize)
                }
                ForEach(ints.indices, id: \.self) { i in
                    TritGroupView(trits: ints[i], color: color, strokeFraction: strokeFraction)
                        .frame(width: slotSize, height: slotSize)
                }
                ForEach(fracs.indices, id: \.self) { i in
                    TritGroupView(trits: fracs[i], color: color, strokeFraction: strokeFraction)
                        .frame(width: slotSize, height: slotSize)
                }
                if reservePlaceholder {
                    Color.clear.frame(width: slotSize, height: slotSize)
                }
            }
            if display.showDecimal {
                PointGlyph(color: color,
                           strokeFraction: strokeFraction,
                           placement: .centered)
                    .frame(width: pointFrameW, height: slotSize)
                    .offset(x: boundaryX - pointFrameW / 2)
            }
        }
        .frame(width: slotSize * CGFloat(maxSlots), height: slotSize, alignment: .leading)
    }
}

/// Simple-ternary number row — a flat sequence of single-trit slots, right-
/// aligned. Each glyph is rendered at tri-trit-mode size (same height and
/// stroke) in a `glyphSize × glyphSize` frame; those frames are positioned
/// along the row at a narrower pitch (`panelWidth / maxSlots`), so adjacent
/// layout slots overlap. Since a trit's drawn extent is only ~29% of its
/// frame width, the strokes stay well separated. Decimal point sits on the
/// boundary between the last integer and first fractional slot.
struct SimpleNumberRow: View {
    let display: DisplayTrits
    let glyphSize: CGFloat
    let panelWidth: CGFloat
    var color: Color = .black
    var maxSlots: Int = 12
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize

    var body: some View {
        let ints  = display.integer.isEmpty ? [Trit.zero] : display.integer
        let fracs = display.fractional
        let reservePlaceholder = display.showDecimal && fracs.isEmpty
        let used  = ints.count + fracs.count + (reservePlaceholder ? 1 : 0)
        let empty = max(0, maxSlots - used)
        let slotPitch = panelWidth / CGFloat(maxSlots)
        let pointFrameW = slotPitch
        let decimalX = slotPitch * CGFloat(empty + ints.count)
        // Glyph frame's left edge so that its center sits on slot i's center.
        let glyphX: (Int) -> CGFloat = { slotIndex in
            slotPitch * (CGFloat(slotIndex) + 0.5) - glyphSize / 2
        }

        ZStack(alignment: .topLeading) {
            ForEach(ints.indices, id: \.self) { j in
                TritGroupView(trits: [ints[j]], color: color, strokeFraction: strokeFraction)
                    .frame(width: glyphSize, height: glyphSize)
                    .offset(x: glyphX(empty + j))
            }
            ForEach(fracs.indices, id: \.self) { k in
                TritGroupView(trits: [fracs[k]], color: color, strokeFraction: strokeFraction)
                    .frame(width: glyphSize, height: glyphSize)
                    .offset(x: glyphX(empty + ints.count + k))
            }
            if display.showDecimal {
                PointGlyph(color: color,
                           strokeFraction: strokeFraction,
                           placement: .centered)
                    .frame(width: pointFrameW, height: glyphSize)
                    .offset(x: decimalX - pointFrameW / 2)
            }
        }
        .frame(width: panelWidth, height: glyphSize, alignment: .leading)
    }
}

/// Simple-mode overflow row — one `X` per trit slot, at tri-trit glyph size.
struct SimpleOverflowRow: View {
    let glyphSize: CGFloat
    let panelWidth: CGFloat
    var color: Color = .black
    var maxSlots: Int = 12
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize

    var body: some View {
        let slotPitch = panelWidth / CGFloat(maxSlots)
        ZStack(alignment: .topLeading) {
            ForEach(0..<maxSlots, id: \.self) { i in
                ZStack {
                    TritGroupView(trits: [.pos], color: color, strokeFraction: strokeFraction)
                    TritGroupView(trits: [.neg], color: color, strokeFraction: strokeFraction)
                }
                .frame(width: glyphSize, height: glyphSize)
                .offset(x: slotPitch * (CGFloat(i) + 0.5) - glyphSize / 2)
            }
        }
        .frame(width: panelWidth, height: glyphSize, alignment: .leading)
    }
}

/// Overflow row — rendered when an operation produces a value that won't fit.
/// Each of the six tri-trit slots draws `///` overlaid with `\\\` so every
/// trit position reads as an `X`, keeping the row in the same stroke / slot
/// language as the number rows.
struct OverflowRow: View {
    let slotSize: CGFloat
    var color: Color = .black
    var maxSlots: Int = 6
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<maxSlots, id: \.self) { _ in
                ZStack {
                    TritGroupView(trits: [.pos, .pos, .pos],
                                  color: color,
                                  strokeFraction: strokeFraction)
                    TritGroupView(trits: [.neg, .neg, .neg],
                                  color: color,
                                  strokeFraction: strokeFraction)
                }
                .frame(width: slotSize, height: slotSize)
            }
        }
        .frame(width: slotSize * CGFloat(maxSlots), height: slotSize)
    }
}

/// Compute a DisplayTrits that fits `maxSlots` tri-trit slots — truncating
/// the fractional expansion (re-running the from-below conversion at a
/// shorter precision) whenever the integer eats into the space available.
/// Returns nil if even the integer alone doesn't fit.
enum DisplayFit {
    static func fit(_ value: BalancedTernary, maxSlots: Int = 6) -> DisplayTrits? {
        guard let initial = value.toDisplayTrits(maxFractionalTrits: maxSlots * 3) else { return nil }
        let intSlots = triTritCount(initial.integer)
        if intSlots > maxSlots { return nil }
        let availableFracTrits = max(0, (maxSlots - intSlots) * 3)
        if initial.fractional.count <= availableFracTrits {
            return initial
        }
        guard let shorter = value.toDisplayTrits(maxFractionalTrits: availableFracTrits) else { return nil }
        if triTritCount(shorter.integer) > maxSlots { return nil }
        return shorter
    }

    static func triTritCount(_ trits: [Trit]) -> Int {
        trits.isEmpty ? 0 : (trits.count + 2) / 3
    }

    /// Simple-mode fit: budget is `maxTrits` raw single-trit slots. If the
    /// integer part uses N of them, the fractional part gets `maxTrits - N`
    /// (re-running the conversion at that precision so the approach-from-
    /// below truncation remains correct).
    static func fitSimple(_ value: BalancedTernary, maxTrits: Int = 12) -> DisplayTrits? {
        guard let initial = value.toDisplayTrits(maxFractionalTrits: maxTrits) else { return nil }
        let intCount = max(1, initial.integer.count)
        if intCount > maxTrits { return nil }
        let availableFrac = max(0, maxTrits - intCount)
        if initial.fractional.count <= availableFrac {
            return initial
        }
        guard let shorter = value.toDisplayTrits(maxFractionalTrits: availableFrac) else { return nil }
        if max(1, shorter.integer.count) > maxTrits { return nil }
        return shorter
    }
}
