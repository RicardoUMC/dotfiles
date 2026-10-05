pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "theme"
import "services"

PanelWindow {
    id: root

    property ShellScreen targetScreen: null
    screen: targetScreen
    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    property int selectedIndex: 0
    property real presentationOpacity: 0
    property real presentationScale: 0.96
    property real backdropOpacity: 0
    readonly property var selectedWallpaper: WallpaperService.wallpapers.length > 0
        ? WallpaperService.wallpapers[cyclicIndex(selectedIndex)]
        : null

    signal dismissed()

    function cyclicIndex(index) {
        const count = WallpaperService.wallpapers.length
        if (count <= 0)
            return 0
        return ((index % count) + count) % count
    }

    function carouselOffset(index) {
        const count = WallpaperService.wallpapers.length
        if (count <= 0)
            return 0
        let offset = index - selectedIndex
        if (offset > count / 2)
            offset -= count
        else if (offset < -count / 2)
            offset += count
        return offset
    }

    function resolveTargetScreen() {
        const focused = Hyprland.focusedMonitor
        if (!focused)
            return
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === focused.name) {
                targetScreen = screens[i]
                return
            }
        }
    }

    function syncSelection() {
        const walls = WallpaperService.wallpapers
        if (walls.length === 0) {
            selectedIndex = 0
            return
        }
        for (let i = 0; i < walls.length; i++) {
            if (walls[i].path === WallpaperService.currentPath) {
                selectedIndex = i
                return
            }
        }
        selectedIndex = cyclicIndex(selectedIndex)
    }

    function choose(index) {
        if (WallpaperService.wallpapers.length === 0)
            return
        const nextIndex = cyclicIndex(index)
        selectedIndex = nextIndex
        const nextWallpaper = WallpaperService.wallpapers[nextIndex]
        WallpaperService.previewWallpaper(nextWallpaper.path)
    }

    function chooseRelative(delta) {
        if (WallpaperService.wallpapers.length === 0)
            return
        choose(selectedIndex + delta)
    }

    function chooseRandom() {
        const count = WallpaperService.wallpapers.length
        if (count > 0)
            choose(Math.floor(Math.random() * count))
    }

    function applySelected() {
        if (!selectedWallpaper)
            return
        WallpaperService.commitPreview(selectedWallpaper.path)
        root.visible = false
        root.dismissed()
    }

    function dismissWithoutApply() {
        WallpaperService.cancelPreview()
        root.visible = false
        root.dismissed()
    }

    function toggleOpen() {
        if (visible) {
            dismissWithoutApply()
            return
        }
        resolveTargetScreen()
        WallpaperService.refresh()
        syncSelection()
        WallpaperService.startPreview()
        visible = true
        keyHandler.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            presentationOpacity = 1
            presentationScale = 1
            backdropOpacity = 1
            keyHandler.forceActiveFocus()
        } else {
            presentationOpacity = 0
            presentationScale = 0.96
            backdropOpacity = 0
            WallpaperService.cancelPreview()
        }
    }

    Behavior on presentationOpacity {
        enabled: Theme.animationEnabled("wallpaper.overlay")
        NumberAnimation { duration: Theme.wallpaperOverlayDuration; easing.type: Easing.OutCubic }
    }
    Behavior on presentationScale {
        enabled: Theme.animationEnabled("wallpaper.overlay")
        NumberAnimation { duration: Theme.wallpaperOverlayDuration; easing.type: Easing.OutCubic }
    }
    Behavior on backdropOpacity {
        enabled: Theme.animationEnabled("wallpaper.overlay")
        NumberAnimation { duration: Theme.wallpaperOverlayDuration; easing.type: Easing.OutCubic }
    }

    Connections {
        target: WallpaperService
        function onWallpapersChanged() { root.syncSelection() }
        function onCurrentPathChanged() { root.syncSelection() }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.76 * root.backdropOpacity)
            Behavior on color {
                enabled: Theme.animationEnabled("wallpaper.overlay")
                Motion.EffectsColor { }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, 0.16 * root.backdropOpacity)
            Behavior on color {
                enabled: Theme.animationEnabled("wallpaper.overlay")
                Motion.EffectsColor { }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissWithoutApply()
        }
    }

    ColumnLayout {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        opacity: root.presentationOpacity
        scale: root.presentationScale
        Behavior on opacity {
            enabled: Theme.animationEnabled("wallpaper.overlay")
            NumberAnimation { duration: Theme.wallpaperOverlayDuration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            enabled: Theme.animationEnabled("wallpaper.overlay")
            NumberAnimation { duration: Theme.wallpaperOverlayDuration; easing.type: Easing.OutCubic }
        }
        anchors.leftMargin: Math.max(Theme.spacingXl, parent.width * 0.055)
        anchors.rightMargin: Math.max(Theme.spacingXl, parent.width * 0.055)
        spacing: Theme.spacingLg

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Wallpapers"
                    color: Colors.textBright
                    font { family: Colors.displayFont; pixelSize: 30; bold: true }
                }
            }

            Text {
                text: WallpaperService.wallpapers.length > 0
                    ? (root.selectedIndex + 1) + "  ·  " + WallpaperService.wallpapers.length
                    : "0"
                color: Colors.textDim
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
            }

            Rectangle {
                id: randomButton
                property bool hovered: false
                Layout.preferredWidth: 46
                Layout.preferredHeight: 40
                radius: Theme.radiusPill
                scale: hovered ? 1.06 : 1.0
                color: hovered
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.30)
                    : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
                Behavior on scale {
                    enabled: Theme.animationEnabled("wallpaper.controls")
                    Motion.Effects { }
                }
                Behavior on color {
                    enabled: Theme.animationEnabled("wallpaper.controls")
                    Motion.EffectsColor { }
                }
                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    color: Colors.accent
                    font { family: Colors.uiFont; pixelSize: 20; bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: randomButton.hovered = true
                    onExited: randomButton.hovered = false
                    onClicked: root.chooseRandom()
                }
            }
        }

        Item {
            id: carouselArea
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(660, root.height * 0.62)

            Repeater {
                model: WallpaperService.wallpapers.length

                delegate: Item {
                    id: carouselCard
                    required property int index
                    readonly property int wallIndex: index
                    readonly property int offset: root.carouselOffset(index)
                    readonly property int distance: Math.abs(offset)
                    readonly property int depthTier: Math.min(3, distance)
                    readonly property var wallpaper: WallpaperService.wallpapers.length > 0
                        ? WallpaperService.wallpapers[wallIndex]
                        : null
                    readonly property bool isCurrent: offset === 0
                    readonly property real centerWidth: Math.min(1180, carouselArea.width * 0.60)
                    readonly property real centerHeight: Math.min(620, centerWidth * 9 / 16)
                    readonly property real sideGap: Math.min(460, carouselArea.width * 0.25)
                    readonly property real depthScale: [1.0, 0.76, 0.56, 0.38][depthTier]
                    readonly property real depthOpacity: [1.0, 0.72, 0.48, 0.28][depthTier]
                    readonly property real depthOffset: [0.0, 0.84, 1.55, 2.15][depthTier]
                    readonly property string wallpaperPath: wallpaper ? wallpaper.path : ""
                    property string activeImagePath: ""
                    property string pendingImagePath: ""
                    property bool imageSwapPending: false
                    property bool imageSwapAnimating: false

                    function cancelImageSwap() {
                        imageSwapAnimating = false
                        pendingImagePath = ""
                        imageSwapPending = false
                        currentImage.opacity = 1
                        incomingImage.opacity = 0
                        incomingImage.source = ""
                    }

                    function beginImageSwap(path) {
                        if (!path) {
                            cancelImageSwap()
                            activeImagePath = ""
                            return
                        }
                        if (activeImagePath === path) {
                            if (imageSwapPending)
                                cancelImageSwap()
                            return
                        }
                        if (!Theme.animationEnabled("wallpaper.carousel")) {
                            activeImagePath = path
                            cancelImageSwap()
                            return
                        }
                        pendingImagePath = path
                        imageSwapPending = true
                        incomingImage.source = path
                        if (incomingImage.status === Image.Ready)
                            startImageSwap()
                    }

                    function startImageSwap() {
                        if (!imageSwapPending || incomingImage.status !== Image.Ready)
                            return
                        imageSwapAnimating = true
                        incomingImage.opacity = 1
                        currentImage.opacity = 0
                    }

                    function finishImageSwap() {
                        if (!imageSwapPending || currentImage.opacity > 0.01)
                            return
                        imageSwapAnimating = false
                        activeImagePath = pendingImagePath
                        pendingImagePath = ""
                        imageSwapPending = false
                        currentImage.opacity = 1
                        incomingImage.opacity = 0
                        incomingImage.source = ""
                    }

                    onWallpaperPathChanged: {
                        if (!activeImagePath)
                            activeImagePath = wallpaperPath
                        else
                            beginImageSwap(wallpaperPath)
                    }
                    Component.onCompleted: activeImagePath = wallpaperPath

                    width: centerWidth
                    height: centerHeight
                    x: carouselArea.width / 2 - width / 2
                        + (offset < 0 ? -1 : offset > 0 ? 1 : 0) * depthOffset * sideGap
                    y: carouselArea.height / 2 - height / 2
                    scale: depthScale
                    opacity: depthOpacity
                    z: 10 - distance
                    visible: WallpaperService.wallpapers.length > 0 && distance <= 3

                    Behavior on x {
                        enabled: Theme.animationEnabled("wallpaper.carousel")
                        Motion.Spatial { }
                    }
                    Behavior on scale {
                        enabled: Theme.animationEnabled("wallpaper.carousel")
                        Motion.Spatial { }
                    }
                    Behavior on opacity {
                        enabled: Theme.animationEnabled("wallpaper.carousel")
                        Motion.Effects { }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusLg + 4
                        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, carouselCard.isCurrent ? 0.88 : 0.58)
                        border.width: carouselCard.isCurrent ? 2 : 1
                        border.color: carouselCard.isCurrent
                            ? Colors.accent
                            : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.22)
                        clip: true
                        Behavior on border.color {
                            enabled: Theme.animationEnabled("wallpaper.selection")
                            Motion.EffectsColor { }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: carouselCard.isCurrent ? 6 : 5
                            radius: parent.radius - 4
                            color: Colors.background
                            clip: true

                            Image {
                                id: currentImage
                                anchors.fill: parent
                                source: carouselCard.activeImagePath
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                onOpacityChanged: carouselCard.finishImageSwap()
                                Behavior on opacity {
                                    enabled: Theme.animationEnabled("wallpaper.carousel")
                                    Motion.Effects { }
                                }
                            }

                            Image {
                                id: incomingImage
                                anchors.fill: parent
                                opacity: 0
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                onStatusChanged: {
                                    if (status === Image.Ready)
                                        carouselCard.startImageSwap()
                                }
                                Behavior on opacity {
                                    enabled: Theme.animationEnabled("wallpaper.carousel")
                                    Motion.Effects { }
                                }
                            }
                        }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: carouselCard.isCurrent ? 6 : 5 }
                            height: carouselCard.isCurrent ? 56 : 42
                            radius: Theme.radiusMd
                            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, carouselCard.isCurrent ? 0.78 : 0.64)

                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.choose(carouselCard.wallIndex)
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingSm
                visible: WallpaperService.wallpapers.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No wallpapers yet"
                    color: Colors.textBright
                    font { family: Colors.displayFont; pixelSize: 28; bold: true }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0)
                        root.chooseRelative(-1)
                    else if (wheel.angleDelta.y < 0)
                        root.chooseRelative(1)
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacingMd

            Rectangle {
                id: applyButton
                property bool hovered: false
                Layout.preferredWidth: 132
                Layout.preferredHeight: 46
                radius: Theme.radiusPill
                scale: hovered && root.selectedWallpaper ? 1.04 : 1.0
                color: root.selectedWallpaper
                    ? (hovered ? Colors.textBright : Colors.accent)
                    : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.22)
                opacity: root.selectedWallpaper ? 1.0 : 0.55
                Behavior on scale {
                    enabled: Theme.animationEnabled("wallpaper.controls")
                    Motion.Effects { }
                }
                Behavior on color {
                    enabled: Theme.animationEnabled("wallpaper.controls")
                    Motion.EffectsColor { }
                }
                Text {
                    anchors.centerIn: parent
                    text: "Apply"
                    color: Colors.background
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody; bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !!root.selectedWallpaper
                    hoverEnabled: enabled
                    onEntered: applyButton.hovered = true
                    onExited: applyButton.hovered = false
                    onClicked: root.applySelected()
                }
            }
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.dismissWithoutApply()
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                root.chooseRelative(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                root.chooseRelative(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applySelected()
                event.accepted = true
            }
        }
    }
}
