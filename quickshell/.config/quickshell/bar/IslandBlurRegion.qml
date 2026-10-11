import QtQuick
import Quickshell
import "."

// Fixed-band approximation of one BarSection's visual silhouette.
// This is deliberately independent from BarSection's Canvas/MultiEffect and hit
// item: native blur needs a QRegion, while the visible mask remains authoritative.
// The fixed bands follow the shared quarter-circle helpers without per-row churn.
Region {
    id: root

    required property BarSection targetItem
    // Injected by Bar.qml so each screen independently opts into the pilot.
    // The default is fail-closed and preserves the visible fallback.
    property bool nativeBlurEnabled: false

    readonly property real targetHeight: Math.max(0, Number(targetItem.targetItem.height || 0))
    readonly property real corner: Math.max(0, Math.min(
        Number(targetItem._cornerSize || 0), targetHeight))
    readonly property bool leftCornerEnabled: targetItem.leftCornerEnabled
    readonly property bool rightCornerEnabled: targetItem.rightCornerEnabled
    readonly property real sectionX: Number(targetItem.x || 0)
    readonly property real sectionY: Number(targetItem.y || 0)
    readonly property real sectionWidth: Math.max(0, Number(targetItem.width || 0))

    // Fourteen fixed slices cover each rounded end, plus one central slice.
    // Use direct Region geometry rather than synthetic Item geometry so the
    // coordinates stay in the same root/window space as the historical slices.
    // Decorative wraps remain excluded: this is still a bounded approximation,
    // not exact parity with the antialiased Canvas mask.
    readonly property real upperBandEnd: Math.min(targetHeight, corner)
    readonly property real lowerBandStart: Math.max(upperBandEnd,
        targetHeight - corner)
    readonly property real topStep: upperBandEnd / 14
    readonly property real bottomStep: Math.max(0, targetHeight - lowerBandStart) / 14

    function bandStart(index) {
        if (index < 14)
            return topStep * index
        if (index === 14)
            return upperBandEnd
        return lowerBandStart + bottomStep * (index - 15)
    }

    function bandEnd(index) {
        if (index < 14)
            return topStep * (index + 1)
        if (index === 14)
            return lowerBandStart
        return lowerBandStart + bottomStep * (index - 14)
    }

    function bandLeft(y0, y1) {
        let inset = 0
        if (leftCornerEnabled && y0 < corner)
            inset = Math.max(inset, IslandGeometry.topInset(y1, corner))
        if (targetItem.bottomLeftRounded && y1 > targetHeight - corner)
            inset = Math.max(inset, (leftCornerEnabled ? corner : 0)
                + IslandGeometry.bottomInset(
                    y0 - (targetHeight - corner), corner))
        return sectionX + inset
    }

    function bandRight(y0, y1) {
        let inset = 0
        if (rightCornerEnabled && y0 < corner)
            inset = Math.max(inset, IslandGeometry.topInset(y1, corner))
        if (targetItem.bottomRightRounded && y1 > targetHeight - corner)
            inset = Math.max(inset, (rightCornerEnabled ? corner : 0)
                + IslandGeometry.bottomInset(
                    y0 - (targetHeight - corner), corner))
        return sectionX + sectionWidth - inset
    }

    // Keep every Region allocated declaratively, but attach the regions only
    // while explicitly enabled. Disabling remains fail-closed.
    Region {
        id: band0
        x: root.bandLeft(root.bandStart(0), root.bandEnd(0))
        y: root.sectionY + root.bandStart(0)
        width: Math.max(0, root.bandRight(root.bandStart(0),
            root.bandEnd(0)) - x)
        height: Math.max(0, root.bandEnd(0) - root.bandStart(0))
    }
    Region {
        id: band1
        x: root.bandLeft(root.bandStart(1), root.bandEnd(1))
        y: root.sectionY + root.bandStart(1)
        width: Math.max(0, root.bandRight(root.bandStart(1),
            root.bandEnd(1)) - x)
        height: Math.max(0, root.bandEnd(1) - root.bandStart(1))
    }
    Region {
        id: band2
        x: root.bandLeft(root.bandStart(2), root.bandEnd(2))
        y: root.sectionY + root.bandStart(2)
        width: Math.max(0, root.bandRight(root.bandStart(2),
            root.bandEnd(2)) - x)
        height: Math.max(0, root.bandEnd(2) - root.bandStart(2))
    }
    Region {
        id: band3
        x: root.bandLeft(root.bandStart(3), root.bandEnd(3))
        y: root.sectionY + root.bandStart(3)
        width: Math.max(0, root.bandRight(root.bandStart(3),
            root.bandEnd(3)) - x)
        height: Math.max(0, root.bandEnd(3) - root.bandStart(3))
    }
    Region {
        id: band4
        x: root.bandLeft(root.bandStart(4), root.bandEnd(4))
        y: root.sectionY + root.bandStart(4)
        width: Math.max(0, root.bandRight(root.bandStart(4),
            root.bandEnd(4)) - x)
        height: Math.max(0, root.bandEnd(4) - root.bandStart(4))
    }
    Region {
        id: band5
        x: root.bandLeft(root.bandStart(5), root.bandEnd(5))
        y: root.sectionY + root.bandStart(5)
        width: Math.max(0, root.bandRight(root.bandStart(5),
            root.bandEnd(5)) - x)
        height: Math.max(0, root.bandEnd(5) - root.bandStart(5))
    }
    Region {
        id: band6
        x: root.bandLeft(root.bandStart(6), root.bandEnd(6))
        y: root.sectionY + root.bandStart(6)
        width: Math.max(0, root.bandRight(root.bandStart(6),
            root.bandEnd(6)) - x)
        height: Math.max(0, root.bandEnd(6) - root.bandStart(6))
    }
    Region {
        id: band7
        x: root.bandLeft(root.bandStart(7), root.bandEnd(7))
        y: root.sectionY + root.bandStart(7)
        width: Math.max(0, root.bandRight(root.bandStart(7),
            root.bandEnd(7)) - x)
        height: Math.max(0, root.bandEnd(7) - root.bandStart(7))
    }
    Region {
        id: band8
        x: root.bandLeft(root.bandStart(8), root.bandEnd(8))
        y: root.sectionY + root.bandStart(8)
        width: Math.max(0, root.bandRight(root.bandStart(8),
            root.bandEnd(8)) - x)
        height: Math.max(0, root.bandEnd(8) - root.bandStart(8))
    }
    Region {
        id: band9
        x: root.bandLeft(root.bandStart(9), root.bandEnd(9))
        y: root.sectionY + root.bandStart(9)
        width: Math.max(0, root.bandRight(root.bandStart(9),
            root.bandEnd(9)) - x)
        height: Math.max(0, root.bandEnd(9) - root.bandStart(9))
    }
    Region {
        id: band10
        x: root.bandLeft(root.bandStart(10), root.bandEnd(10))
        y: root.sectionY + root.bandStart(10)
        width: Math.max(0, root.bandRight(root.bandStart(10),
            root.bandEnd(10)) - x)
        height: Math.max(0, root.bandEnd(10) - root.bandStart(10))
    }
    Region {
        id: band11
        x: root.bandLeft(root.bandStart(11), root.bandEnd(11))
        y: root.sectionY + root.bandStart(11)
        width: Math.max(0, root.bandRight(root.bandStart(11),
            root.bandEnd(11)) - x)
        height: Math.max(0, root.bandEnd(11) - root.bandStart(11))
    }
    Region {
        id: band12
        x: root.bandLeft(root.bandStart(12), root.bandEnd(12))
        y: root.sectionY + root.bandStart(12)
        width: Math.max(0, root.bandRight(root.bandStart(12),
            root.bandEnd(12)) - x)
        height: Math.max(0, root.bandEnd(12) - root.bandStart(12))
    }
    Region {
        id: band13
        x: root.bandLeft(root.bandStart(13), root.bandEnd(13))
        y: root.sectionY + root.bandStart(13)
        width: Math.max(0, root.bandRight(root.bandStart(13),
            root.bandEnd(13)) - x)
        height: Math.max(0, root.bandEnd(13) - root.bandStart(13))
    }
    Region {
        id: band14
        x: root.bandLeft(root.bandStart(14), root.bandEnd(14))
        y: root.sectionY + root.bandStart(14)
        width: Math.max(0, root.bandRight(root.bandStart(14),
            root.bandEnd(14)) - x)
        height: Math.max(0, root.bandEnd(14) - root.bandStart(14))
    }
    Region {
        id: band15
        x: root.bandLeft(root.bandStart(15), root.bandEnd(15))
        y: root.sectionY + root.bandStart(15)
        width: Math.max(0, root.bandRight(root.bandStart(15),
            root.bandEnd(15)) - x)
        height: Math.max(0, root.bandEnd(15) - root.bandStart(15))
    }
    Region {
        id: band16
        x: root.bandLeft(root.bandStart(16), root.bandEnd(16))
        y: root.sectionY + root.bandStart(16)
        width: Math.max(0, root.bandRight(root.bandStart(16),
            root.bandEnd(16)) - x)
        height: Math.max(0, root.bandEnd(16) - root.bandStart(16))
    }
    Region {
        id: band17
        x: root.bandLeft(root.bandStart(17), root.bandEnd(17))
        y: root.sectionY + root.bandStart(17)
        width: Math.max(0, root.bandRight(root.bandStart(17),
            root.bandEnd(17)) - x)
        height: Math.max(0, root.bandEnd(17) - root.bandStart(17))
    }
    Region {
        id: band18
        x: root.bandLeft(root.bandStart(18), root.bandEnd(18))
        y: root.sectionY + root.bandStart(18)
        width: Math.max(0, root.bandRight(root.bandStart(18),
            root.bandEnd(18)) - x)
        height: Math.max(0, root.bandEnd(18) - root.bandStart(18))
    }
    Region {
        id: band19
        x: root.bandLeft(root.bandStart(19), root.bandEnd(19))
        y: root.sectionY + root.bandStart(19)
        width: Math.max(0, root.bandRight(root.bandStart(19),
            root.bandEnd(19)) - x)
        height: Math.max(0, root.bandEnd(19) - root.bandStart(19))
    }
    Region {
        id: band20
        x: root.bandLeft(root.bandStart(20), root.bandEnd(20))
        y: root.sectionY + root.bandStart(20)
        width: Math.max(0, root.bandRight(root.bandStart(20),
            root.bandEnd(20)) - x)
        height: Math.max(0, root.bandEnd(20) - root.bandStart(20))
    }
    Region {
        id: band21
        x: root.bandLeft(root.bandStart(21), root.bandEnd(21))
        y: root.sectionY + root.bandStart(21)
        width: Math.max(0, root.bandRight(root.bandStart(21),
            root.bandEnd(21)) - x)
        height: Math.max(0, root.bandEnd(21) - root.bandStart(21))
    }
    Region {
        id: band22
        x: root.bandLeft(root.bandStart(22), root.bandEnd(22))
        y: root.sectionY + root.bandStart(22)
        width: Math.max(0, root.bandRight(root.bandStart(22),
            root.bandEnd(22)) - x)
        height: Math.max(0, root.bandEnd(22) - root.bandStart(22))
    }
    Region {
        id: band23
        x: root.bandLeft(root.bandStart(23), root.bandEnd(23))
        y: root.sectionY + root.bandStart(23)
        width: Math.max(0, root.bandRight(root.bandStart(23),
            root.bandEnd(23)) - x)
        height: Math.max(0, root.bandEnd(23) - root.bandStart(23))
    }
    Region {
        id: band24
        x: root.bandLeft(root.bandStart(24), root.bandEnd(24))
        y: root.sectionY + root.bandStart(24)
        width: Math.max(0, root.bandRight(root.bandStart(24),
            root.bandEnd(24)) - x)
        height: Math.max(0, root.bandEnd(24) - root.bandStart(24))
    }
    Region {
        id: band25
        x: root.bandLeft(root.bandStart(25), root.bandEnd(25))
        y: root.sectionY + root.bandStart(25)
        width: Math.max(0, root.bandRight(root.bandStart(25),
            root.bandEnd(25)) - x)
        height: Math.max(0, root.bandEnd(25) - root.bandStart(25))
    }
    Region {
        id: band26
        x: root.bandLeft(root.bandStart(26), root.bandEnd(26))
        y: root.sectionY + root.bandStart(26)
        width: Math.max(0, root.bandRight(root.bandStart(26),
            root.bandEnd(26)) - x)
        height: Math.max(0, root.bandEnd(26) - root.bandStart(26))
    }
    Region {
        id: band27
        x: root.bandLeft(root.bandStart(27), root.bandEnd(27))
        y: root.sectionY + root.bandStart(27)
        width: Math.max(0, root.bandRight(root.bandStart(27),
            root.bandEnd(27)) - x)
        height: Math.max(0, root.bandEnd(27) - root.bandStart(27))
    }
    Region {
        id: band28
        x: root.bandLeft(root.bandStart(28), root.bandEnd(28))
        y: root.sectionY + root.bandStart(28)
        width: Math.max(0, root.bandRight(root.bandStart(28),
            root.bandEnd(28)) - x)
        height: Math.max(0, root.bandEnd(28) - root.bandStart(28))
    }

    regions: root.nativeBlurEnabled
        ? [band0, band1, band2, band3, band4, band5, band6,
            band7, band8, band9, band10, band11, band12, band13,
            band14, band15, band16, band17, band18, band19, band20,
            band21, band22, band23, band24, band25, band26, band27,
            band28]
        : []
}
