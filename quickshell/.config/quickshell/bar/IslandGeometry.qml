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

    // Scalar section contract consumed by the layout frame, visible mask,
    // native blur, and input reservation. Keeping each operation pure avoids
    // a dynamic JS object binding loop while preserving one source of truth.
    function cornerSize(curveRadius, vertical, targetWidth, targetHeight,
                         collapsedHeight, collapsedWidth) {
        const axis = vertical ? targetWidth : targetHeight
        const reference = Math.max(1, Number(collapsedHeight || targetHeight || 0))
        const thickness = Math.max(0, Number(collapsedWidth || targetWidth || 0))
        const scale = vertical ? thickness / reference : 1
        return clampRadius(Number(curveRadius || 0) * scale, axis)
    }

    function extent(enabled, corner) {
        return enabled ? Math.max(0, Number(corner || 0)) : 0
    }

    function resolvedWrapDepth(enabled, configuredWrapDepth) {
        return enabled ? Math.max(0, Number(configuredWrapDepth || 0)) : 0
    }

    function sectionOffsetX(vertical, edge, wrapDepth, leftExtent) {
        return vertical ? (edge === "right" ? -wrapDepth : 0) : -leftExtent
    }

    // Both lateral edges use the same CCW-rotated source; right mirrors only
    // its physical X axis. Therefore both sections consume source-right as
    // their physical top extent.
    function sectionOffsetY(vertical, edge, leftExtent, rightExtent, wrapDepth) {
        return vertical
            ? -rightExtent
            : (edge === "bottom" ? -wrapDepth : 0)
    }

    function sectionWidth(vertical, targetWidth, wrapDepth, leftExtent, rightExtent) {
        return vertical ? targetWidth + wrapDepth : targetWidth + leftExtent + rightExtent
    }

    function sectionHeight(vertical, targetHeight, wrapDepth, leftExtent, rightExtent) {
        return vertical ? targetHeight + leftExtent + rightExtent : targetHeight + wrapDepth
    }

    function targetProxyX(vertical, edge, wrapDepth, leftExtent) {
        return vertical ? (edge === "right" ? wrapDepth : 0) : leftExtent
    }

    function targetProxyY(vertical, edge, leftExtent, rightExtent, wrapDepth) {
        return vertical
            ? rightExtent
            : (edge === "bottom" ? wrapDepth : 0)
    }

    function maskOffsetX(vertical, edge, wrapDepth, leftExtent) {
        return vertical ? (edge === "right" ? -wrapDepth : 0) : -leftExtent
    }

    function maskOffsetY(vertical, edge, leftExtent, rightExtent) {
        return vertical ? -rightExtent : 0
    }

    function maskWidth(vertical, edge, targetWidth, wrapDepth, leftExtent, rightExtent) {
        return vertical
            ? targetWidth + wrapDepth
            : targetWidth + leftExtent + rightExtent
    }

    function maskHeight(vertical, targetHeight, leftExtent, rightExtent) {
        return vertical ? targetHeight + leftExtent + rightExtent : targetHeight
    }

    function reservedHeight(vertical, targetWidth, collapsedHeight) {
        return vertical ? targetWidth : Math.max(0, Number(collapsedHeight || 0))
    }

    function reservedWidth(vertical, targetWidth, collapsedWidth) {
        return vertical ? Math.max(0, Number(collapsedWidth || targetWidth || 0)) : 0
    }

    function horizontalSourceWidth(targetHeight, leftExtent, rightExtent) {
        return targetHeight + leftExtent + rightExtent
    }

    function horizontalSourceHeight(targetWidth, wrapDepth) {
        return targetWidth + wrapDepth
    }

    function wrapEnabled(hasWrap, rounded, corner, wrapDepth) {
        return !!hasWrap && !rounded && corner > 0 && wrapDepth > 0
    }

    // Return one scalar from the shared section contract. Callers bind to the
    // requested value directly, avoiding a mutable object as a dependency.
    function sectionValue(name, vertical, edge, targetWidth, targetHeight,
                          curveRadius, configuredWrapDepth, hasWrap,
                          leftCornerEnabled, rightCornerEnabled,
                          bottomLeftRounded, bottomRightRounded,
                          collapsedHeight, collapsedWidth) {
        const width = Math.max(0, Number(targetWidth || 0))
        const height = Math.max(0, Number(targetHeight || 0))
        const corner = cornerSize(curveRadius, vertical, width, height,
                                   collapsedHeight, collapsedWidth)
        const leftExtent = extent(leftCornerEnabled, corner)
        const rightExtent = extent(rightCornerEnabled, corner)
        const wrapDepth = resolvedWrapDepth(hasWrap, configuredWrapDepth)

        switch (name) {
        case "corner": return corner
        case "leftExtent": return leftExtent
        case "rightExtent": return rightExtent
        case "wrapDepth": return wrapDepth
        case "sectionOffsetX": return sectionOffsetX(vertical, edge, wrapDepth, leftExtent)
        case "sectionOffsetY": return sectionOffsetY(vertical, edge, leftExtent, rightExtent, wrapDepth)
        case "sectionWidth": return sectionWidth(vertical, width, wrapDepth, leftExtent, rightExtent)
        case "sectionHeight": return sectionHeight(vertical, height, wrapDepth, leftExtent, rightExtent)
        case "targetProxyX": return targetProxyX(vertical, edge, wrapDepth, leftExtent)
        case "targetProxyY": return targetProxyY(vertical, edge, leftExtent, rightExtent, wrapDepth)
        case "maskOffsetX": return maskOffsetX(vertical, edge, wrapDepth, leftExtent)
        case "maskOffsetY": return maskOffsetY(vertical, edge, leftExtent, rightExtent)
        case "maskWidth": return maskWidth(vertical, edge, width, wrapDepth, leftExtent, rightExtent)
        case "maskHeight": return maskHeight(vertical, height, leftExtent, rightExtent)
        case "reservedHeight": return reservedHeight(vertical, width, collapsedHeight)
        case "reservedWidth": return reservedWidth(vertical, width, collapsedWidth)
        case "horizontalSourceWidth": return horizontalSourceWidth(height, leftExtent, rightExtent)
        case "horizontalSourceHeight": return horizontalSourceHeight(width, wrapDepth)
        case "targetYFromSection": return !vertical && edge === "bottom" ? wrapDepth : 0
        case "leftWrapEnabled": return wrapEnabled(hasWrap, bottomLeftRounded, corner, wrapDepth)
        case "rightWrapEnabled": return wrapEnabled(hasWrap, bottomRightRounded, corner, wrapDepth)
        default: return 0
        }
    }

    // Inset of a top island corner at the far edge of a pixel row. The Canvas
    // arc has its center on the outer edge of the corner square.
    function topInset(rowEnd, radius) {
        const r = Math.max(0, Number(radius || 0))
        const y = Math.max(0, Math.min(r, Number(rowEnd || 0)))
        return Math.sqrt(Math.max(0, r * r - (r - y) * (r - y)))
    }

    // Inset of a bottom rounded corner at the near edge of a pixel row.
    // The fixed native-blur composition does not currently use this helper,
    // but keep its quarter-circle formula correct for future approximations.
    function bottomInset(rowStart, radius) {
        const r = Math.max(0, Number(radius || 0))
        const y = Math.max(0, Math.min(r, Number(rowStart || 0)))
        return r - Math.sqrt(Math.max(0, r * r - y * y))
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
