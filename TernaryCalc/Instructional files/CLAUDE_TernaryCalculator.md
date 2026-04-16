# Ternary Calculator — Project Context

## Background

This project grows out of an exploration of balanced ternary arithmetic, where the fundamental unit of discreteness has a center (0), symmetry (positive and negative are equally fundamental), and circularity (the extremes meet). The calculator is a tool for exploring this number system and its operations.

The developer (Chiel) also built a balanced ternary clock app (iOS + web) using the same /|\ notation system described below. The clock app is published on the App Store and shares visual design language with this calculator.

## The Balanced Ternary Number System

### Trits
The basic unit is a "trit" (ternary digit) with three values:
- `/` = +1 (highest)
- `|` = 0 (center)
- `\` = -1 (lowest)

Any number and its negation are visual mirror images (swap all `/` and `\`).

### Place values
Like decimal, but powers of 3:
- ... 27s, 9s, 3s, 1s . 1/3s, 1/9s, 1/27s ...

Examples:
- `/|` = 3
- `//\` = 9 + 3 - 1 = 11
- `\\/` = -9 - 3 + 1 = -11 (mirror of `//\`)
- `|./` = 1/3
- `/.\` = 1 - 1/3 = 2/3

### Non-terminating fractions
1/2 cannot be represented finitely in balanced ternary. It has two representations approaching from opposite sides:
- `|./////...` (from below: 1/3 + 1/9 + 1/27 + ... = 1/2)
- `/.\\\\\...` (from above: 1 - 1/3 - 1/9 - 1/27 - ... = 1/2)

These two representations are mirror images of each other.

## Operations


### Addition
Symmetric, unambiguous. Standard balanced ternary addition with carries. The truth table for single-trit addition (ignoring carry):

|   +   |  `\`  |  `|`  |  `/`  |
|-------|-------|--------|-------|
|  `\`  |  `/`  |  `\`  |  `|`  |
|  `|`  |  `\`  |  `|`  |  `/`  |
|  `/`  |  `|`  |  `/`  |  `\`  |


### x_right (standard multiplication)
`/` (+1) is the identity element. Single-trit truth table:

|x_right|  `\`  |   `|`  |  `/`  |
|-------|-------|--------|-------|
|  `\`  |  `/`  |   `|`  |  `\`  |
|  `|`  |  `|`  |   `|`  |  `|`  |
|  `/`  |  `\`  |   `|`  |  `/`  |


### x_left (mirror multiplication)
`\` (-1) is the identity element. The mirror image of x_right. Single-trit truth table:

|x_left |  `\`  |  `|`  |  `/`  |
|-------|-------|-------|-------|
|  `\`  |  `\`  |  `|`  |  `/`  |
|  `|`  |  `|`  |  `|`  |  `|`  |
|  `/`  |  `/`  |  `|`  |  `\`  |


### Flip (replaces subtraction)
Swaps `/` and `\` in every trit. Negates the number. A - B is equivalent to A + mirror(B). Single-trit truth table:

| input | output |
|-------|--------|
|   \   |    /   |
|   |   |    |   |
|   /   |    \   |


### Invert (replaces division)
Multiplicative inverse: transforms A into 1/A. A / B is equivalent to A x_right invert(B) or A x_left invert(B). This is a whole-number operation (not trit-by-trit). Often produces non-terminating results.


### Relationship between operations
- x_left(A, B) = mirror(x_right(A, B)) = x_right(mirror(A), B) = x_right(A, mirror(B))
- x_left and x_right are equally valid ring operations; each is the other's mirror image
- Using only x_right reproduces standard arithmetic; having both preserves the symmetry between `/` and `\`
- The pair does not add computational power but adds representational power



## Input Design

### Trit-by-trit input with tab
- Three number keys: `\`, `|`, `/`
- A tab key that fills remaining positions in the current tri-trit group with `|` (zero) and advances
- Input builds most-significant-trit first
- Tab without prior input acts as `|||` — enables fast entry of "round" numbers (powers of 3)
- Example: entering 9 = `/` then tab (fills to `/||`)
- Example: entering 6 = `/\` then tab (fills to `/\|`)

### Display
- Tri-trit grouping (groups of 3 trits)
- The /|\ glyph notation from the clock app, with condensed/connected line segments where trits share endpoints

## Operation Glyphs
- x_right and x_left represented by mirrored arrow glyphs
- If later extended to complex operations (x_up, x_down), vertical arrows complete the set as a symmetric cross

## Complex Number Extension (future)
- Four multiplication operations: x_right, x_left, x_up, x_down
- Each has a different element as identity: +1, -1, +i, -i
- Standard complex units truth table (5x5, quinary):

|   x   |   0   |   1   |  -1   |   i   |  -i   |
|-------|-------|-------|-------|-------|-------|
|   0   |   0   |   0   |   0   |   0   |   0   |
|   1   |   0   |   1   |  -1   |   i   |  -i   |
|  -1   |   0   |  -1   |   1   |  -i   |   i   |
|   i   |   0   |   i   |  -i   |  -1   |   1   |
|  -i   |   0   |  -i   |   i   |   1   |  -1   |

- x_left reverses direction of rotation compared to x_right in the complex plane
- Mirroring the operation is equivalent to conjugating an operand

## Technical Notes
- iOS app, SwiftUI
- The clock app project is at ~/Documents/TernaryClock/ for reference on shared notation/drawing code
- The developer uses Sketch for graphic design, Comfortaa font for UI text
