import QtQuick 2.6
import Sailfish.Silica 1.0
import QtSensors 5.0

Page {
    id: page
    objectName: "qiblaPage"
    allowedOrientations: Orientation.Portrait

    readonly property double qiblaBearing: prayerManager.qiblaBearing
    readonly property double qiblaDistance: prayerManager.qiblaDistanceKm
    readonly property string compassDirection: prayerManager.qiblaCompassDirection
    readonly property int calibrationOffset: prayerManager.compassCalibration

    readonly property int qiblaMode: prayerManager.qiblaMode
    readonly property int celestialReference: prayerManager.celestialReference

    readonly property real activeCelestialBearing: {
        if (celestialReference === 1) return prayerManager.sunBearing
        if (celestialReference === 2) return prayerManager.moonBearing
        if (celestialReference === 3) return prayerManager.shadowBearing
        if (celestialReference === 4) return 0.0 // Fixed North
        // Auto: Sun if daytime, Moon if night
        return prayerManager.isDaytime ? prayerManager.sunBearing : prayerManager.moonBearing
    }

    readonly property string activeCelestialName: {
        if (celestialReference === 1) return qsTr("Sun")
        if (celestialReference === 2) return qsTr("Moon")
        if (celestialReference === 3) return qsTr("Shadow")
        if (celestialReference === 4) return qsTr("North")
        return prayerManager.isDaytime ? qsTr("Sun") : qsTr("Moon")
    }

    function formatDigits(str) {
        var _ = prayerManager.useHindiNumerals
        return prayerManager.formatDigits(str)
    }

    function moonPhaseDisplayName(phase) {
        switch (phase) {
        case "New Moon": return qsTr("New Moon")
        case "Waxing Crescent": return qsTr("Waxing Crescent")
        case "First Quarter": return qsTr("First Quarter")
        case "Waxing Gibbous": return qsTr("Waxing Gibbous")
        case "Full Moon": return qsTr("Full Moon")
        case "Waning Gibbous": return qsTr("Waning Gibbous")
        case "Last Quarter": return qsTr("Last Quarter")
        case "Waning Crescent": return qsTr("Waning Crescent")
        default: return phase ? phase : ""
        }
    }

    Connections {
        target: prayerManager
        onUseHindiNumeralsChanged: {}
        onAppLanguageChanged: {}
    }

    readonly property real dialRotationAngle: {
        if (qiblaMode === 0) {
            return hasSensor ? -calibratedHeading : 0.0
        } else {
            return (celestialReference === 4) ? 0.0 : -activeCelestialBearing
        }
    }

    readonly property real celestialToQiblaDiff: {
        var diff = ((qiblaBearing - activeCelestialBearing) % 360 + 360) % 360
        return diff > 180 ? diff - 360 : diff
    }

    property real rawHeading: 0
    property real smoothedHeading: 0
    property bool hasSensor: false
    property real calibrationLevel: 0.0
    property string calibrationLevelText: {
        if (!hasSensor) return qsTr("Unknown")
        if (calibrationLevel >= 0.8) return qsTr("High (%1%)").arg(formatDigits(Math.round(calibrationLevel * 100).toString()))
        if (calibrationLevel >= 0.4) return qsTr("Medium (%1%)").arg(formatDigits(Math.round(calibrationLevel * 100).toString()))
        if (calibrationLevel > 0.0) return qsTr("Low (%1%)").arg(formatDigits(Math.round(calibrationLevel * 100).toString()))
        return qsTr("Calibrating... (%1%)").arg(formatDigits(Math.round(calibrationLevel * 100).toString()))
    }

    readonly property real calibratedHeading: (smoothedHeading + calibrationOffset + 360) % 360

    // Heading difference between phone orientation and Qibla (Magnetic Mode)
    readonly property real angleDiff: {
        var diff = ((qiblaBearing - (hasSensor ? calibratedHeading : 0)) % 360 + 360) % 360
        return diff > 180 ? diff - 360 : diff
    }
    readonly property bool isAligned: hasSensor && Math.abs(angleDiff) <= 4.0

    // Primary sensor: Fused Compass (only active in Magnetic Compass mode)
    Compass {
        id: compassSensor
        active: page.status === PageStatus.Active && qiblaMode === 0
        alwaysOn: false
        onReadingChanged: {
            if (reading && !isNaN(reading.azimuth)) {
                hasSensor = true
                var target = reading.azimuth
                var diff = (target - smoothedHeading) % 360
                if (diff > 180) diff -= 360
                else if (diff < -180) diff += 360
                smoothedHeading = smoothedHeading + diff * 0.35
                rawHeading = target
                if (reading.calibrationLevel !== undefined && !isNaN(reading.calibrationLevel)) {
                    calibrationLevel = reading.calibrationLevel
                }
            }
        }
    }

    // Fallback sensor: Magnetometer (only active in Magnetic Compass mode)
    Magnetometer {
        id: magSensor
        active: !hasSensor && page.status === PageStatus.Active && qiblaMode === 0
        alwaysOn: false
        onReadingChanged: {
            if (reading && !hasSensor && !isNaN(reading.x) && !isNaN(reading.y)) {
                var rad = Math.atan2(-reading.x, reading.y)
                var deg = (rad * 180 / Math.PI + 360) % 360
                var diff = (deg - smoothedHeading) % 360
                if (diff > 180) diff -= 360
                else if (diff < -180) diff += 360
                smoothedHeading = smoothedHeading + diff * 0.35
                rawHeading = deg
                hasSensor = true
                if (reading.calibrationLevel !== undefined && !isNaN(reading.calibrationLevel)) {
                    calibrationLevel = reading.calibrationLevel
                }
            }
        }
    }

    Timer {
        id: celestialTimer
        interval: 20000
        repeat: true
        running: page.status === PageStatus.Active && prayerManager.hasCity
        onTriggered: prayerManager.updateCelestialPositions()
    }

    Connections {
        target: prayerManager
        onQiblaModeChanged: {
            if (prayerManager.qiblaMode === 0) {
                if (page.status === PageStatus.Active) {
                    compassSensor.start()
                    if (!hasSensor) magSensor.start()
                }
            } else {
                compassSensor.stop()
                magSensor.stop()
            }
        }
    }

    Component.onCompleted: {
        prayerManager.updateCelestialPositions()
        if (qiblaMode === 0) {
            compassSensor.start()
            if (!hasSensor) {
                magSensor.start()
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            prayerManager.updateCelestialPositions()
            if (qiblaMode === 0) {
                compassSensor.start()
                if (!hasSensor) magSensor.start()
            }
        } else if (status === PageStatus.Deactivating || status === PageStatus.Inactive) {
            compassSensor.stop()
            magSensor.stop()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Reset calibration offset")
                visible: prayerManager.compassCalibration !== 0
                onClicked: prayerManager.compassCalibration = 0
            }
            MenuItem {
                text: qsTr("Change city")
                onClicked: pageStack.push(Qt.resolvedUrl("CitySearchPage.qml"))
            }
        }

        Column {
            id: contentColumn
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Qibla Direction")
                description: prayerManager.hasCity ? (prayerManager.cityName + (prayerManager.countryName ? (", " + prayerManager.countryName) : "")) : ""
            }

            Label {
                visible: !prayerManager.hasCity
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.secondaryColor
                text: qsTr("Please select a city first to calculate the Qibla direction.")
            }

            ComboBox {
                visible: prayerManager.hasCity
                width: parent.width
                label: qsTr("Determination Method")
                currentIndex: prayerManager.qiblaMode
                menu: ContextMenu {
                    MenuItem { text: formatDigits(qsTr("1. Magnetic Compass (sensor)")) }
                    MenuItem { text: formatDigits(qsTr("2. Sun & Moon (celestial)")) }
                }
                onCurrentIndexChanged: {
                    if (prayerManager.qiblaMode !== currentIndex) {
                        prayerManager.qiblaMode = currentIndex
                    }
                }
            }

            ComboBox {
                visible: prayerManager.hasCity && prayerManager.qiblaMode === 1
                width: parent.width
                label: qsTr("Align Phone Top With")
                currentIndex: prayerManager.celestialReference
                menu: ContextMenu {
                    MenuItem { text: qsTr("Auto (%1)").arg(prayerManager.isDaytime ? qsTr("Sun") : qsTr("Moon")) }
                    MenuItem { text: qsTr("Sun ☀️") }
                    MenuItem { text: qsTr("Moon 🌙") }
                    MenuItem { text: qsTr("Sun's Shadow ♟️") }
                    MenuItem { text: qsTr("Fixed (True North at top)") }
                }
                onCurrentIndexChanged: {
                    if (prayerManager.celestialReference !== currentIndex) {
                        prayerManager.celestialReference = currentIndex
                    }
                }
            }

            Item {
                visible: prayerManager.hasCity
                width: page.width
                height: page.width

                // Outer Compass Ring & Rose
                Item {
                    id: compassDial
                    anchors.fill: parent
                    rotation: dialRotationAngle

                    Behavior on rotation {
                        enabled: (qiblaMode === 1) || !hasSensor
                        NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
                    }

                    Canvas {
                        id: dialCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()

                            var cx = width / 2
                            var cy = height / 2
                            var radius = width / 2 - 3.0

                            // Outer border ring
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                            ctx.lineWidth = 3.0
                            ctx.strokeStyle = Theme.highlightColor
                            ctx.stroke()

                            // Inner subtle ring
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius * 0.78, 0, 2 * Math.PI)
                            ctx.lineWidth = 1.2
                            ctx.strokeStyle = Theme.rgba(Theme.primaryColor, 0.25)
                            ctx.stroke()

                            // Degree tick marks
                            for (var deg = 0; deg < 360; deg += 5) {
                                var rad = (deg - 90) * Math.PI / 180
                                var isMajor = (deg % 30 === 0)
                                var isCardinal = (deg % 90 === 0)
                                var innerR = radius - (isCardinal ? 16 : (isMajor ? 12 : 6))

                                var x1 = cx + radius * Math.cos(rad)
                                var y1 = cy + radius * Math.sin(rad)
                                var x2 = cx + innerR * Math.cos(rad)
                                var y2 = cy + innerR * Math.sin(rad)

                                ctx.beginPath()
                                ctx.moveTo(x1, y1)
                                ctx.lineTo(x2, y2)
                                ctx.lineWidth = isCardinal ? 3.0 : (isMajor ? 2.0 : 1.0)
                                ctx.strokeStyle = isCardinal ? Theme.highlightColor : (isMajor ? Theme.primaryColor : Theme.rgba(Theme.primaryColor, 0.4))
                                ctx.stroke()
                            }

                            // Cardinal Letters: N, E, S, W
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"

                            var cardinals = [
                                { label: "N", deg: 0, color: "#ff4d4d", size: Theme.fontSizeLarge },
                                { label: "E", deg: 90, color: Theme.primaryColor, size: Theme.fontSizeMedium },
                                { label: "S", deg: 180, color: Theme.primaryColor, size: Theme.fontSizeMedium },
                                { label: "W", deg: 270, color: Theme.primaryColor, size: Theme.fontSizeMedium }
                            ]

                            for (var i = 0; i < cardinals.length; i++) {
                                var c = cardinals[i]
                                var cr = (c.deg - 90) * Math.PI / 180
                                var dist = radius * 0.64
                                var tx = cx + dist * Math.cos(cr)
                                var ty = cy + dist * Math.sin(cr)

                                ctx.font = "bold " + c.size + "px sans-serif"
                                ctx.fillStyle = c.color
                                ctx.fillText(c.label, tx, ty)
                            }
                        }
                    }

                    // Sun Pointer Indicator
                    Item {
                        id: sunPointer
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        rotation: prayerManager.sunBearing
                        visible: prayerManager.hasCity
                        opacity: prayerManager.isDaytime ? 1.0 : (prayerManager.sunAltitude > -18 ? 0.4 : 0.2)

                        // Sun Needle
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.verticalCenter
                            width: 12
                            height: parent.height * 0.38
                            radius: 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#ffd700" }
                                GradientStop { position: 1.0; color: Theme.rgba("#ffd700", 0.05) }
                            }
                        }

                        // Sun Disc & Glow at rim
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8
                            width: 64
                            height: 64

                            Rectangle {
                                anchors.centerIn: parent
                                width: 64
                                height: 64
                                radius: 32
                                color: Theme.rgba("#ffd700", prayerManager.isDaytime ? 0.35 : 0.15)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 44
                                radius: 22
                                color: "#ffb300"
                                border.color: "#fff9c4"
                                border.width: 3.0
                            }
                        }
                    }

                    // Moon Pointer Indicator
                    Item {
                        id: moonPointer
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        rotation: prayerManager.moonBearing
                        visible: prayerManager.hasCity
                        opacity: (!prayerManager.isDaytime || prayerManager.isMoonVisible) ? 1.0 : 0.35

                        // Moon Needle
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.verticalCenter
                            width: 12
                            height: parent.height * 0.38
                            radius: 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#80d8ff" }
                                GradientStop { position: 1.0; color: Theme.rgba("#80d8ff", 0.05) }
                            }
                        }

                        // Dynamic Moon Phase Disc & Glow at rim
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8
                            width: 64
                            height: 64

                            Rectangle {
                                anchors.centerIn: parent
                                width: 64
                                height: 64
                                radius: 32
                                color: Theme.rgba("#80d8ff", (!prayerManager.isDaytime || prayerManager.isMoonVisible) ? (0.2 + prayerManager.moonIllumination * 0.25) : 0.1)
                            }

                            Canvas {
                                id: moonPhaseCanvas
                                anchors.centerIn: parent
                                width: 48
                                height: 48
                                renderTarget: Canvas.FramebufferObject

                                readonly property real phase: prayerManager.moonPhase
                                readonly property real illumination: prayerManager.moonIllumination

                                onPhaseChanged: requestPaint()
                                onIlluminationChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()

                                    var cx = width / 2
                                    var cy = height / 2
                                    var r = width / 2 - 2.0
                                    var p = phase

                                    // Base disc (dark part of the moon)
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                    ctx.fillStyle = "#142230"
                                    ctx.fill()
                                    ctx.strokeStyle = Theme.rgba("#80d8ff", 0.6)
                                    ctx.lineWidth = 1.5
                                    ctx.stroke()

                                    // Very close to New Moon: dark disc with glowing rim is enough
                                    if (p < 0.015 || p > 0.985) {
                                        return
                                    }

                                    // Illuminated part of the moon
                                    ctx.beginPath()
                                    if (p <= 0.5) {
                                        // Waxing: Bright limb is on the right
                                        ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, false)
                                        // Terminator returns from bottom to top
                                        var cosTerm = Math.cos(2 * Math.PI * p)
                                        var steps = 18
                                        for (var i = 0; i <= steps; i++) {
                                            var a = (Math.PI / 2) - (i / steps) * Math.PI
                                            var x = cx + r * Math.cos(a) * cosTerm
                                            var y = cy + r * Math.sin(a)
                                            ctx.lineTo(x, y)
                                        }
                                    } else {
                                        // Waning: Bright limb is on the left
                                        ctx.arc(cx, cy, r, Math.PI / 2, 3 * Math.PI / 2, false)
                                        // Terminator returns from top to bottom
                                        var cosTerm = -Math.cos(2 * Math.PI * p)
                                        var steps = 18
                                        for (var i = 0; i <= steps; i++) {
                                            var a = (-Math.PI / 2) + (i / steps) * Math.PI
                                            var x = cx + r * Math.cos(a) * cosTerm
                                            var y = cy + r * Math.sin(a)
                                            ctx.lineTo(x, y)
                                        }
                                    }
                                    ctx.closePath()
                                    ctx.fillStyle = "#e0f7fa"
                                    ctx.fill()
                                }
                            }
                        }
                    }

                    // Sun Shadow (Gnomon) Indicator
                    Item {
                        id: shadowPointer
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        rotation: prayerManager.shadowBearing
                        visible: prayerManager.hasCity && prayerManager.isDaytime

                        // Cast Shadow Ray from center gnomon
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.verticalCenter
                            width: 14
                            height: parent.height * 0.38
                            radius: 7
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.rgba("#000000", 0.65) }
                                GradientStop { position: 0.6; color: Theme.rgba("#1a2533", 0.35) }
                                GradientStop { position: 1.0; color: Theme.rgba("#000000", 0.05) }
                            }
                        }

                        // Shadow Marker at rim
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8
                            width: 64
                            height: 64

                            Rectangle {
                                anchors.centerIn: parent
                                width: 54
                                height: 54
                                radius: 27
                                color: Theme.rgba("#000000", 0.4)
                                border.color: Theme.rgba(Theme.primaryColor, 0.25)
                                border.width: 2.5
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                radius: 10
                                color: Theme.rgba(Theme.primaryColor, 0.8)
                            }
                        }
                    }

                    // Qibla Pointer Indicator (points to Kaaba on the compass dial)
                    Item {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        rotation: qiblaBearing

                        // Kaaba Needle Drop Shadow
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: 4
                            anchors.bottom: parent.verticalCenter
                            anchors.bottomMargin: -3
                            width: 16
                            height: parent.height * 0.40
                            radius: 8
                            color: Theme.rgba("#000000", 0.45)
                        }

                        // Kaaba Needle
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.verticalCenter
                            width: 16
                            height: parent.height * 0.40
                            radius: 8
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: isAligned ? "#00ff88" : Theme.highlightColor }
                                GradientStop { position: 1.0; color: Theme.rgba(Theme.highlightColor, 0.15) }
                            }
                        }

                        // Kaaba Icon Drop Shadow
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: 4
                            y: 11
                            width: 64
                            height: 64
                            radius: 32
                            color: Theme.rgba("#000000", 0.5)
                        }

                        // Kaaba Icon at the rim
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8
                            width: 64
                            height: 64

                            Rectangle {
                                anchors.centerIn: parent
                                width: 64
                                height: 64
                                radius: 32
                                color: isAligned ? Theme.rgba("#00ff88", 0.3) : Theme.rgba("#f1c40f", 0.25)
                                border.color: isAligned ? "#00ff88" : "#f1c40f"
                                border.width: 3.0
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 44
                                height: 44
                                sourceSize.width: 44
                                sourceSize.height: 44
                                fillMode: Image.PreserveAspectFit
                                source: Qt.resolvedUrl("Images/ox16-app-kaaba-icon.png")
                                onStatusChanged: {
                                    if (status === Image.Error && source != Qt.resolvedUrl("../Images/ox16-app-kaaba-icon.png")) {
                                        source = Qt.resolvedUrl("../Images/ox16-app-kaaba-icon.png")
                                    }
                                }
                            }
                        }
                    }

                    // Center Hub
                    Rectangle {
                        anchors.centerIn: parent
                        width: 68
                        height: 68
                        radius: 34
                        color: isAligned ? "#00ff88" : Theme.highlightBackgroundColor
                        border.color: isAligned ? "#00ff88" : Theme.highlightColor
                        border.width: 4.0

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 12
                            color: isAligned ? "#ffffff" : Theme.highlightColor
                        }
                    }
                }

                // Device Top Alignment Pointer (Fixed at top of compass display)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: -8
                    width: 32
                    height: 32
                    rotation: 45
                    color: {
                        if (qiblaMode === 0) {
                            return isAligned ? "#00ff88" : Theme.highlightColor
                        } else {
                            if (celestialReference === 1 || (celestialReference === 0 && prayerManager.isDaytime)) return "#ffc107"
                            if (celestialReference === 2 || (celestialReference === 0 && !prayerManager.isDaytime)) return "#80d8ff"
                            if (celestialReference === 3) return Theme.secondaryColor
                            return Theme.highlightColor
                        }
                    }
                }
            }

            // Alignment Status Banner
            Rectangle {
                visible: prayerManager.hasCity
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: statusRow.height + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: {
                    if (qiblaMode === 0) {
                        return isAligned ? Theme.rgba("#00ff88", 0.2) : (hasSensor ? Theme.rgba(Theme.highlightColor, 0.1) : Theme.rgba(Theme.secondaryColor, 0.08))
                    } else {
                        return Theme.rgba(Theme.highlightColor, 0.15)
                    }
                }
                border.color: {
                    if (qiblaMode === 0) {
                        return isAligned ? "#00ff88" : (hasSensor ? Theme.rgba(Theme.highlightColor, 0.3) : "transparent")
                    } else {
                        return Theme.rgba(Theme.highlightColor, 0.35)
                    }
                }
                border.width: 1

                Row {
                    id: statusRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: Theme.paddingMedium
                        leftMargin: Theme.paddingMedium
                        rightMargin: Theme.paddingMedium
                    }
                    spacing: Theme.paddingSmall

                    Image {
                        id: statusIcon
                        anchors.verticalCenter: parent.verticalCenter
                        source: {
                            if (qiblaMode === 0) {
                                return isAligned ? "image://theme/icon-s-installed" : (hasSensor ? "image://theme/icon-s-sync" : "image://theme/icon-s-device-download")
                            } else {
                                return (celestialReference === 4) ? "image://theme/icon-s-sync" : "image://theme/icon-s-installed"
                            }
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - statusIcon.width - parent.spacing
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Theme.fontSizeSmall
                        color: {
                            if (qiblaMode === 0) {
                                return isAligned ? "#00ff88" : (hasSensor ? Theme.primaryColor : Theme.secondaryColor)
                            } else {
                                return Theme.primaryColor
                            }
                        }
                        text: {
                            if (qiblaMode === 0) {
                                return isAligned ? qsTr("Facing Qibla!") : (hasSensor ? qsTr("Turn device towards green marker") : qsTr("Sensor initializing..."))
                            } else {
                                if (celestialReference === 4) {
                                    return qsTr("Fixed Dial \u2014 True North at top")
                                } else {
                                    return qsTr("Aim top at %1 \u2192 Kaaba needle is Qibla").arg(activeCelestialName)
                                }
                            }
                        }
                    }
                }
            }

            // Legend bar for Qibla, Sun, Shadow, and Moon (2 balanced rows with large rich icons)
            Column {
                visible: prayerManager.hasCity
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                // Row 1: Qibla & Moon
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingLarge

                    // Qibla legend item
                    Row {
                        spacing: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30

                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: 15
                                color: isAligned ? Theme.rgba("#00ff88", 0.25) : Theme.rgba("#f1c40f", 0.2)
                                border.color: isAligned ? "#00ff88" : "#f1c40f"
                                border.width: 1.5
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                sourceSize.width: 22
                                sourceSize.height: 22
                                fillMode: Image.PreserveAspectFit
                                source: Qt.resolvedUrl("Images/ox16-app-kaaba-icon.png")
                                onStatusChanged: {
                                    if (status === Image.Error && source != Qt.resolvedUrl("../Images/ox16-app-kaaba-icon.png")) {
                                        source = Qt.resolvedUrl("../Images/ox16-app-kaaba-icon.png")
                                    }
                                }
                            }
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primaryColor
                            text: qsTr("Qibla %1\u00B0").arg(formatDigits(Math.round(qiblaBearing).toString()))
                        }
                    }

                    // Moon legend item
                    Row {
                        spacing: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            opacity: (!prayerManager.isDaytime || prayerManager.isMoonVisible) ? 1.0 : 0.4

                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: 15
                                color: Theme.rgba("#80d8ff", 0.2)
                                border.color: Theme.rgba("#80d8ff", 0.7)
                                border.width: 1.5
                            }

                            Canvas {
                                id: miniMoonCanvas
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                renderTarget: Canvas.FramebufferObject

                                readonly property real phase: prayerManager.moonPhase

                                onPhaseChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var cx = width / 2
                                    var cy = height / 2
                                    var r = width / 2 - 1.0
                                    var p = phase

                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                    ctx.fillStyle = "#142230"
                                    ctx.fill()

                                    if (p < 0.02 || p > 0.98) return

                                    ctx.beginPath()
                                    if (p <= 0.5) {
                                        ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, false)
                                        var cosTerm = Math.cos(2 * Math.PI * p)
                                        for (var i = 0; i <= 12; i++) {
                                            var a = (Math.PI / 2) - (i / 12) * Math.PI
                                            ctx.lineTo(cx + r * Math.cos(a) * cosTerm, cy + r * Math.sin(a))
                                        }
                                    } else {
                                        ctx.arc(cx, cy, r, Math.PI / 2, 3 * Math.PI / 2, false)
                                        var cosTerm = -Math.cos(2 * Math.PI * p)
                                        for (var i = 0; i <= 12; i++) {
                                            var a = (-Math.PI / 2) + (i / 12) * Math.PI
                                            ctx.lineTo(cx + r * Math.cos(a) * cosTerm, cy + r * Math.sin(a))
                                        }
                                    }
                                    ctx.closePath()
                                    ctx.fillStyle = "#e0f7fa"
                                    ctx.fill()
                                }
                            }
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: (!prayerManager.isDaytime || prayerManager.isMoonVisible) ? Theme.primaryColor : Theme.secondaryColor
                            text: qsTr("Moon %1\u00B0 (%2%)").arg(formatDigits(Math.round(prayerManager.moonBearing).toString())).arg(formatDigits(Math.round(prayerManager.moonIllumination * 100).toString()))
                        }
                    }
                }

                // Row 2: Sun & Shadow
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingLarge

                    // Sun legend item
                    Row {
                        spacing: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            opacity: prayerManager.isDaytime ? 1.0 : 0.4

                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: 15
                                color: Theme.rgba("#ffd700", 0.25)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                radius: 10
                                color: "#ffb300"
                                border.color: "#fff9c4"
                                border.width: 1.5
                            }
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: prayerManager.isDaytime ? Theme.primaryColor : Theme.secondaryColor
                            text: qsTr("Sun %1\u00B0").arg(formatDigits(Math.round(prayerManager.sunBearing).toString()))
                        }
                    }

                    // Shadow legend item (visible during daytime)
                    Row {
                        visible: prayerManager.isDaytime
                        spacing: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: Theme.rgba("#000000", 0.4)
                                border.color: Theme.rgba(Theme.primaryColor, 0.3)
                                border.width: 1.5
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                radius: 5
                                color: Theme.rgba(Theme.primaryColor, 0.85)
                            }
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryColor
                            text: qsTr("Shadow %1\u00B0").arg(formatDigits(Math.round(prayerManager.shadowBearing).toString()))
                        }
                    }
                }
            }

            // Celestial Alignment Guidance Card (Active when in Sun/Moon/Celestial mode)
            Rectangle {
                visible: prayerManager.hasCity && qiblaMode === 1
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: celestialGuideCol.height + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                border.color: Theme.rgba(Theme.highlightColor, 0.3)
                border.width: 1

                Column {
                    id: celestialGuideCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Theme.paddingMedium
                    }
                    spacing: Theme.paddingSmall / 2

                    Row {
                        id: celestialHeaderRow
                        spacing: Theme.paddingSmall
                        width: parent.width

                        Image {
                            id: celestialHeaderIcon
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-s-installed"
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - celestialHeaderIcon.width - parent.spacing
                            text: qsTr("Celestial Navigation (No Magnetic Jitter)")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                        text: {
                            if (celestialReference === 4) {
                                return qsTr("True North is fixed at the top of the phone. Compass sensors are off to eliminate magnetic distortion.")
                            } else {
                                var angle = Math.abs(Math.round(celestialToQiblaDiff))
                                var dir = (celestialToQiblaDiff >= 0) ? qsTr("right") : qsTr("left")
                                return formatDigits(qsTr("1. Point the top of your phone towards the %1.\n2. The green Kaaba needle points to Qibla (%2\u00B0 to the %3).").arg(activeCelestialName).arg(formatDigits(angle.toString())).arg(dir))
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        text: qsTr("Completely immune to indoor iron, steel, and electronic magnetic interference.")
                    }
                }
            }

            // Figure-8 Calibration & Sensor Accuracy Card
            Rectangle {
                visible: prayerManager.hasCity && qiblaMode === 0 && hasSensor
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: figure8Col.height + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                border.color: Theme.rgba(Theme.highlightColor, 0.25)
                border.width: 1

                Column {
                    id: figure8Col
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Theme.paddingMedium
                    }
                    spacing: Theme.paddingSmall / 2

                    Row {
                        id: accuracyRow
                        spacing: Theme.paddingSmall
                        width: parent.width

                        Image {
                            id: syncIcon
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-s-sync"
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - syncIcon.width - parent.spacing
                            text: qsTr("Compass Accuracy: %1").arg(calibrationLevelText)
                            font.pixelSize: Theme.fontSizeSmall
                            color: calibrationLevel >= 0.7 ? "#00ff88" : (calibrationLevel >= 0.3 ? Theme.highlightColor : "#f39c12")
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                    }

                    // Calibration level progress bar
                    Item {
                        width: parent.width
                        height: 4

                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: Theme.rgba(Theme.primaryColor, 0.15)
                        }

                        Rectangle {
                            width: parent.width * Math.max(0.05, Math.min(1.0, calibrationLevel))
                            height: parent.height
                            radius: 2
                            color: calibrationLevel >= 0.7 ? "#00ff88" : (calibrationLevel >= 0.3 ? Theme.highlightColor : "#f39c12")
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        text: qsTr("Rotate and wave your device in a figure-8 motion (\u221E) away from magnetic objects to calibrate the compass sensor.")
                    }
                }
            }

            // Calibration Offset Slider
            SectionHeader {
                visible: prayerManager.hasCity && qiblaMode === 0
                text: qsTr("Sensor Calibration")
            }

            Slider {
                visible: prayerManager.hasCity && qiblaMode === 0
                width: parent.width
                minimumValue: -30
                maximumValue: 30
                stepSize: 1
                value: prayerManager.compassCalibration
                label: qsTr("Calibration Offset")
                valueText: (value > 0 ? "+" : "") + formatDigits(Math.round(value).toString()) + "\u00B0"
                onSliderValueChanged: {
                    prayerManager.compassCalibration = Math.round(value)
                }
            }

            DetailItem {
                visible: prayerManager.hasCity && qiblaMode === 0 && hasSensor
                label: qsTr("Sensor Calibration Level")
                value: calibrationLevelText
            }

            // Qibla Info Details Card
            SectionHeader {
                visible: prayerManager.hasCity
                text: qsTr("Qibla Information")
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("Determination Method")
                value: qiblaMode === 0 ? qsTr("Magnetic Compass") : qsTr("Sun / Moon / Celestial")
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("Qibla Bearing")
                value: formatDigits(qiblaBearing.toFixed(1)) + "\u00B0 (" + compassDirection + ")"
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("Distance to Kaaba")
                value: formatDigits(Math.round(qiblaDistance).toLocaleString()) + " km (" + formatDigits(Math.round(qiblaDistance * 0.621371).toLocaleString()) + " mi)"
            }

            DetailItem {
                visible: prayerManager.hasCity && qiblaMode === 0 && hasSensor
                label: qsTr("Current Device Heading")
                value: formatDigits(Math.round(calibratedHeading).toString()) + "\u00B0" + (calibrationOffset !== 0 ? (" (" + (calibrationOffset > 0 ? "+" : "") + formatDigits(calibrationOffset.toString()) + "\u00B0 offset)") : "")
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("Kaaba Coordinates")
                value: formatDigits("21.4225\u00B0 N, 39.8262\u00B0 E")
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("City Coordinates")
                value: formatDigits(prayerManager.latitude.toFixed(4) + "\u00B0, " + prayerManager.longitude.toFixed(4) + "\u00B0")
            }

            // Celestial Positions Card
            SectionHeader {
                visible: prayerManager.hasCity
                text: qsTr("Celestial Bearings")
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("Sun Direction")
                value: formatDigits(Math.round(prayerManager.sunBearing) + "\u00B0 (" + prayerManager.sunCompassDirection + ") \u2022 ") + (prayerManager.isDaytime ? qsTr("Day, Alt: %1\u00B0").arg((prayerManager.sunAltitude >= 0 ? "+" : "") + formatDigits(prayerManager.sunAltitude.toFixed(1))) : qsTr("Below horizon (%1\u00B0)").arg(formatDigits(prayerManager.sunAltitude.toFixed(1))))
            }

            DetailItem {
                visible: prayerManager.hasCity && prayerManager.isDaytime
                label: qsTr("Sun Shadow Direction")
                value: formatDigits(Math.round(prayerManager.shadowBearing) + "\u00B0 (" + prayerManager.shadowCompassDirection + ") \u2022 ") + qsTr("Gnomon shadow (opposite Sun)")
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("Moon Direction")
                value: formatDigits(Math.round(prayerManager.moonBearing) + "\u00B0 (" + prayerManager.moonCompassDirection + ") \u2022 ") + (prayerManager.isMoonVisible ? qsTr("Visible, Alt: %1\u00B0").arg((prayerManager.moonAltitude >= 0 ? "+" : "") + formatDigits(prayerManager.moonAltitude.toFixed(1))) : qsTr("Below horizon (%1\u00B0)").arg(formatDigits(prayerManager.moonAltitude.toFixed(1))))
            }

            DetailItem {
                visible: prayerManager.hasCity
                label: qsTr("Moon Phase")
                value: moonPhaseDisplayName(prayerManager.moonPhaseName) + " (" + formatDigits(Math.round(prayerManager.moonIllumination * 100).toString()) + "% " + qsTr("lit") + ")"
            }
        }
    }
}