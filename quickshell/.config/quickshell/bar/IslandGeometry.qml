pragma Singleton

import QtQml

// Shared analytic geometry for the Canvas island silhouette and its rectangle-only
// native blur approximation. Coordinates describe quarter-circle boundaries in
// the same local pixel space as NotchCornerMask.
QtObject {
    id: root

    function clampRadius(radius, height) {
        return Math.max(0, Math.min(Number(radius || 0), Number(height || 0)))
    }

    // Inset of a top island corner at the far edge of a pixel row. The Canvas
    // arc has its center on the outer edge of the corner square.
    function topInset(rowEnd, radius) {
        const r = Math.max(0, Number(radius || 0))
        const y = Math.max(0, Math.min(r, Number(rowEnd || 0)))
        return Math.sqrt(Math.max(0, r * r - (r - y) * (r - y)))
    }

    // Inset of a bottom rounded corner at the near edge of a pixel row.
    function bottomInset(rowStart, radius) {
        const r = Math.max(0, Number(radius || 0))
        const y = Math.max(0, Math.min(r, Number(rowStart || 0)))
        return r - Math.sqrt(Math.max(0, r * r - (r - y) * (r - y)))
    }

    // Width of a wrap's top-left/top-right quarter-circle at a row. The
    // silhouette is widest at the bar edge and narrows toward its end.
    function wrapWidth(rowStart, radius) {
        const r = Math.max(0, Number(radius || 0))
        const y = Math.max(0, Math.min(r, Number(rowStart || 0)))
        return r - topInset(y, r)
    }

    // QRegion accepts integer rectangles. Use the union of every pixel touched
    // by the continuous boundary rather than flooring width independently.
    function pixelStart(value) {
        return Math.floor(Number(value || 0))
    }

    function pixelEnd(value) {
        return Math.ceil(Number(value || 0))
    }
}
