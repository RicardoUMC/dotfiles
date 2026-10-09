import QtQuick
import Quickshell
import "."
import "../theme"

// Rectangle-only approximation of one BarSection's visual silhouette. This is
// deliberately independent from BarSection's Canvas/MultiEffect and hit item:
// native blur needs a QRegion, while the visible mask remains authoritative.
Region {
    id: root

    required property BarSection targetItem
    property var generatedRegions: []
    readonly property bool nativeBlurEnabled: Theme.islandNativeBlur
    property bool disabledRegionsCleared: false

    readonly property real targetHeight: Math.max(0, Number(targetItem.targetItem.height || 0))
    readonly property real corner: Math.max(0, Math.min(
        Number(targetItem._cornerSize || 0), targetHeight))
    readonly property real bodyHeight: targetHeight
    readonly property bool hasWrap: targetItem.hasWrap
    readonly property bool leftCornerEnabled: targetItem.leftCornerEnabled
    readonly property bool rightCornerEnabled: targetItem.rightCornerEnabled
    readonly property bool bottomLeftRounded: targetItem.bottomLeftRounded
    readonly property bool bottomRightRounded: targetItem.bottomRightRounded
    readonly property real wrapDepth: hasWrap
        ? Math.max(0, Number(targetItem._wrapDepth || 0))
        : 0
    readonly property real leftExtent: leftCornerEnabled ? corner : 0
    readonly property real rightExtent: rightCornerEnabled ? corner : 0
    readonly property real sectionX: Number(targetItem.x || 0)
    readonly property real sectionY: Number(targetItem.y || 0)
    readonly property real sectionWidth: Math.max(0, Number(targetItem.width || 0))

    function bodyLeftInset(y0, y1) {
        let inset = 0
        if (leftCornerEnabled && y0 < corner)
            inset = Math.max(inset, IslandGeometry.topInset(y1, corner))
        if (bottomLeftRounded && y1 > bodyHeight - corner)
            inset = Math.max(inset, leftExtent + IslandGeometry.bottomInset(
                y0 - (bodyHeight - corner), corner))
        return Math.min(sectionWidth, inset)
    }

    function bodyRightInset(y0, y1) {
        let inset = 0
        if (rightCornerEnabled && y0 < corner)
            inset = Math.max(inset, IslandGeometry.topInset(y1, corner))
        if (bottomRightRounded && y1 > bodyHeight - corner)
            inset = Math.max(inset, rightExtent + IslandGeometry.bottomInset(
                y0 - (bodyHeight - corner), corner))
        return Math.min(sectionWidth, inset)
    }

    function wrapWidth(y0, y1) {
        if (wrapDepth <= 0 || corner <= 0)
            return 0
        return Math.min(corner, IslandGeometry.wrapWidth(Math.max(0, y0), corner))
    }

    function addSlice(left, y, right) {
        const start = IslandGeometry.pixelStart(left)
        const end = IslandGeometry.pixelEnd(right)
        if (end <= start)
            return
        const slice = Qt.createQmlObject("import Quickshell; Region {}", root, "IslandBlurSlice")
        slice.x = start
        slice.y = IslandGeometry.pixelStart(y)
        slice.width = end - start
        slice.height = 1
        root.regions.push(slice)
        root.generatedRegions.push(slice)
    }

    function clearGeneratedRegions() {
        if (root.disabledRegionsCleared)
            return
        for (const slice of root.generatedRegions)
            slice.destroy()
        root.generatedRegions = []
        root.disabledRegionsCleared = true
    }

    function rebuild() {
        if (!root.nativeBlurEnabled) {
            clearGeneratedRegions()
            return
        }

        root.disabledRegionsCleared = false
        for (const slice of root.generatedRegions)
            slice.destroy()
        root.generatedRegions = []

        const bodyRows = Math.ceil(bodyHeight)
        for (let row = 0; row < bodyRows; row++) {
            const y0 = row
            const y1 = Math.min(bodyHeight, row + 1)
            const left = bodyLeftInset(y0, y1)
            const right = bodyRightInset(y0, y1)
            addSlice(sectionX + left, sectionY + row, sectionX + sectionWidth - right)
        }

        const wrapRows = Math.ceil(wrapDepth)
        for (let row = 0; row < wrapRows; row++) {
            const y0 = row
            const y1 = Math.min(wrapDepth, row + 1)
            const width = wrapWidth(y0, y1)
            const y = sectionY + bodyHeight + row
            if (hasWrap && !bottomLeftRounded)
                addSlice(sectionX + leftExtent, y, sectionX + leftExtent + width)
            if (hasWrap && !bottomRightRounded)
                addSlice(sectionX + sectionWidth - rightExtent - width, y,
                    sectionX + sectionWidth - rightExtent)
        }
    }

    onTargetHeightChanged: rebuild()
    onCornerChanged: rebuild()
    onHasWrapChanged: rebuild()
    onLeftCornerEnabledChanged: rebuild()
    onRightCornerEnabledChanged: rebuild()
    onBottomLeftRoundedChanged: rebuild()
    onBottomRightRoundedChanged: rebuild()
    onBodyHeightChanged: rebuild()
    onWrapDepthChanged: rebuild()
    onSectionXChanged: rebuild()
    onSectionYChanged: rebuild()
    onSectionWidthChanged: rebuild()
    onLeftExtentChanged: rebuild()
    onRightExtentChanged: rebuild()
    onNativeBlurEnabledChanged: rebuild()
    Component.onCompleted: rebuild()
}
