import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // === 设置面板配置绑定 ===
    property string petName: pluginData.petName ?? "Clawdy"
    property real petScale: (pluginData.petScale ?? 100) / 100.0
    property int animSpeed: pluginData.animSpeed ?? 100
    property bool useThemeColor: pluginData.useThemeColor ?? true
    property color petColor: pluginData.petColor ?? Theme.primary
    property bool showStateLabel: pluginData.showStateIndicator ?? false
    property bool showNameLabel: pluginData.showPetName ?? false

    readonly property real maxPetSize: Math.min(Math.max(widgetThickness * 0.78, 18), 44)
    readonly property real speedMult: animSpeed / 100.0
    readonly property color activeColor: useThemeColor ? Theme.primary : petColor

    // === Claude 运行状态控制 ===
    property string claudeState: "idle"
    property string claudeEvent: ""
    property string claudeTool: ""
    property int lastStateUpdate: 0

    function refreshState() {
        // 触发 Process 获取最新状态，不再在这里重置状态，防止高频轮询导致的闪烁
        stateProcess.running = true
    }

    Timer {
        id: pollTimer
        interval: 800; running: true; repeat: true; triggeredOnStart: true
        onTriggered: refreshState()
    }

    Process {
        id: stateProcess
        // 修复：全面支持 XDG 兼容路径，防止读取失败
        command: ["sh", "-c", "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/dms-pet/claude-state.json\" 2>/dev/null || echo '{}'"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (!line || line === "{}") {
                    claudeState = "idle"
                    return
                }
                try {
                    var d = JSON.parse(line)
                    if (d && d.state) {
                        var now = Math.floor(Date.now() / 1000)
                        var fileUpdate = d.updatedAt || 0
                        
                        // 30秒过期惰性检测
                        if (fileUpdate === 0 || (now - fileUpdate) > 30) {
                            claudeState = "idle"
                            claudeEvent = ""
                            claudeTool = ""
                        } else {
                            lastStateUpdate = fileUpdate
                            claudeEvent = d.event || ""
                            claudeTool = d.tool || ""
                            claudeState = d.state
                        }
                    }
                } catch (e) {
                    claudeState = "idle"
                }
            }
        }
    }

    // ═══════════════════════════════════════════
    // 内联 PetBlob：迪士尼级物理动画宠物组件
    // ═══════════════════════════════════════════
    component PetBlob: Item {
        id: blob
        property string state: "idle"
        property color pColor: Theme.primary
        property real speedMul: 1.0
        property bool showLabel: false
        signal clicked()

        width: height
        clip: false

        readonly property real eyeH: height * 0.17
        readonly property real pSize: height * 0.07

        // 眼神跟随鼠标偏置量
        property real pupilXOffset: 0
        property real pupilYOffset: 0
        
        Behavior on pupilXOffset { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on pupilYOffset { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        // 三维联动立体地表阴影：随身体跳起高度(bodyMove.y)和缩放比例完美贴合变化
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.03
            width: parent.width * 0.82 * shadowScale
            height: parent.height * 0.12 * shadowScale
            radius: height * 0.5
            color: Qt.rgba(0, 0, 0, 0.16)
            
            readonly property real shadowScale: Math.max(0.3, 1.0 + (bodyMove.y * 0.04))
            opacity: (blob.state === "sleeping" ? 0.03 : 0.16) * Math.max(0.1, 1.0 + (bodyMove.y * 0.07))
            
            Behavior on opacity { NumberAnimation { duration: 300 / blob.speedMul } }
        }

        // 宠物身体本体
        Rectangle {
            id: body
            anchors.fill: parent; anchors.margins: parent.height * 0.04
            radius: height * 0.44
            color: blob.state === "error" ? Qt.lighter(blob.pColor, 1.25) : blob.pColor
            border.width: 1.2; border.color: Qt.darker(blob.pColor, 1.35)
            antialiasing: true
            Behavior on color { ColorAnimation { duration: 250 } }

            // 变形核心：运用 Translate, Rotation 和物理 Scale 保证挤压拉伸效果
            transform: [
                Translate { id: bodyMove; x: 0; y: 0 },
                Rotation { id: bodyRotate; angle: 0; origin.x: body.width / 2; origin.y: body.height / 2 },
                // 重点：缩放原点（Origin.y）设为 body.height（底盘），可以让它像站在地板上一样受力缩放
                Scale { id: bodyScale; origin.x: body.width / 2; origin.y: body.height; xScale: 1.0; yScale: 1.0 }
            ]

            // 身体高光
            Rectangle {
                width: parent.width * 0.42; height: parent.height * 0.16
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: parent.height * 0.13
                radius: height * 0.5
                color: Qt.rgba(1, 1, 1, 0.22)
                antialiasing: true
            }

            // 状态 Emoji 气泡标签（跟随 body transform 移动）
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -height * 0.7
                text: {
                    switch (blob.state) {
                        case "working": return "⚡";
                        case "waking": return "☀️";
                        case "sleeping": return ""; // 睡觉状态已替换为浮动 💤 粒子
                        case "error": return "❌";
                        case "alert": return "🚨";
                        default: return "";
                    }
                }
                font.pixelSize: Math.max(12, blob.height * 0.26)
                visible: blob.showLabel && blob.state !== "idle"
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 / blob.speedMul; easing.type: Easing.InOutQuad } }
            }
        }

        // 眼睛组件
        Rectangle {
            id: leftEye
            width: blob.height * 0.19; height: blob.state === "sleeping" ? blob.height * 0.04 : blob.eyeH
            x: blob.width * 0.28; y: blob.height * 0.30
            radius: height * 0.5; color: "#FFFFFF"; antialiasing: true
            Behavior on height { NumberAnimation { duration: 220 / blob.speedMul; easing.type: Easing.InOutQuad } }
        }
        Rectangle {
            id: rightEye
            width: blob.height * 0.19; height: blob.state === "sleeping" ? blob.height * 0.04 : blob.eyeH
            x: blob.width * 0.53; y: blob.height * 0.30
            radius: height * 0.5; color: "#FFFFFF"; antialiasing: true
            Behavior on height { NumberAnimation { duration: 220 / blob.speedMul; easing.type: Easing.InOutQuad } }
        }

        // 瞳孔组件（支持跟随鼠标偏移）
        Rectangle {
            id: leftPupil
            width: blob.pSize; height: blob.pSize; radius: height * 0.5
            x: leftEye.x + leftEye.width * 0.5 - width * 0.5 + blob.pupilXOffset
            y: leftEye.y + leftEye.height * 0.5 - height * 0.5 + blob.pupilYOffset
            color: blob.state === "error" ? "#FF1744" : "#121212"
            visible: leftEye.height > blob.height * 0.05
            antialiasing: true
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Rectangle {
            id: rightPupil
            width: blob.pSize; height: blob.pSize; radius: height * 0.5
            x: rightEye.x + rightEye.width * 0.5 - width * 0.5 + blob.pupilXOffset
            y: rightEye.y + rightEye.height * 0.5 - height * 0.5 + blob.pupilYOffset
            color: blob.state === "error" ? "#FF1744" : "#121212"
            visible: rightEye.height > blob.height * 0.05
            antialiasing: true
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // 少女红晕腮红
        Rectangle {
            width: blob.height * 0.13; height: blob.height * 0.07
            x: blob.width * 0.15; y: blob.height * 0.50
            radius: height * 0.5; color: Qt.rgba(1, 0.38, 0.38, 0.18)
            visible: blob.state !== "sleeping" && blob.state !== "error"
            antialiasing: true
        }
        Rectangle {
            width: blob.height * 0.13; height: blob.height * 0.07
            x: blob.width * 0.72; y: blob.height * 0.50
            radius: height * 0.5; color: Qt.rgba(1, 0.38, 0.38, 0.18)
            visible: blob.state !== "sleeping" && blob.state !== "error"
            antialiasing: true
        }

        // 嘴部组件：随状态夸张变形
        Rectangle {
            id: mouth
            anchors.horizontalCenter: body.horizontalCenter
            y: body.height * 0.58
            width: blob.state === "alert" ? blob.height * 0.17 : (blob.state === "working" ? blob.height * 0.08 : blob.height * 0.06)
            height: blob.state === "alert" ? blob.height * 0.15 : (blob.state === "working" ? blob.height * 0.07 : blob.height * 0.05)
            radius: height * 0.5
            color: blob.state === "alert" ? "#D32F2F" : (blob.state === "error" ? "#FF1744" : "#121212")
            opacity: blob.state === "sleeping" ? 0 : 0.75
            antialiasing: true
            Behavior on width { NumberAnimation { duration: 150 / blob.speedMul; easing.type: Easing.OutBack } }
            Behavior on height { NumberAnimation { duration: 150 / blob.speedMul; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }


        // ═══════════════════════════════════════════
        // 精致的粒子互动特效
        // ═══════════════════════════════════════════

        // 1. 睡觉时徐徐升起的 Zzz
        Text {
            id: zzzBubble
            text: "💤"
            font.pixelSize: blob.height * 0.24
            opacity: 0
            visible: blob.state === "sleeping"
            x: blob.width * 0.65
            y: blob.height * 0.15

            SequentialAnimation {
                id: zzzAnim
                running: blob.state === "sleeping"
                loops: Animation.Infinite
                PropertyAction { target: zzzBubble; property: "opacity"; value: 0.0 }
                PropertyAction { target: zzzBubble; property: "y"; value: blob.height * 0.22 }
                PropertyAction { target: zzzBubble; property: "scale"; value: 0.6 }
                PauseAnimation { duration: 200 }
                ParallelAnimation {
                    NumberAnimation { target: zzzBubble; property: "opacity"; to: 0.85; duration: 500 / blob.speedMul }
                    NumberAnimation { target: zzzBubble; property: "y"; to: -blob.height * 0.18; duration: 1600 / blob.speedMul; easing.type: Easing.OutQuad }
                    NumberAnimation { target: zzzBubble; property: "scale"; to: 1.15; duration: 1600 / blob.speedMul }
                }
                ParallelAnimation {
                    NumberAnimation { target: zzzBubble; property: "opacity"; to: 0.0; duration: 450 / blob.speedMul }
                }
                PauseAnimation { duration: 800 }
            }
        }

        // 2. 点击时弹出的漂浮心形 ❤️ 粒子
        Text {
            id: clickParticle
            text: "❤️"
            font.pixelSize: blob.height * 0.32
            opacity: 0
            x: parent.width * 0.5 - width * 0.5
            y: parent.height * 0.3

            transform: Rotation { id: particleRot; angle: 0; origin.x: clickParticle.width / 2; origin.y: clickParticle.height / 2 }

            SequentialAnimation {
                id: particleAnim
                running: false
                PropertyAction { target: clickParticle; property: "opacity"; value: 1.0 }
                PropertyAction { target: clickParticle; property: "y"; value: blob.height * 0.25 }
                PropertyAction { target: particleRot; property: "angle"; value: (Math.random() * 40) - 20 }
                ParallelAnimation {
                    NumberAnimation { target: clickParticle; property: "y"; to: -blob.height * 0.45; duration: 650 / blob.speedMul; easing.type: Easing.OutQuad }
                    NumberAnimation { target: clickParticle; property: "opacity"; to: 0.0; duration: 650 / blob.speedMul; easing.type: Easing.OutQuad }
                }
            }
        }

        // ═══════════════════════════════════════════
        // 挤压与拉伸物理动画引擎
        // ═══════════════════════════════════════════

        // 生物呼吸呼吸动效 (完美遵循体积守恒：x 轴展宽时 y 轴收缩)
        SequentialAnimation {
            id: breatheAnim
            running: true; loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; from: 1.0; to: 0.96; duration: (blob.state === "sleeping" ? 2200 : 1100) / blob.speedMul; easing.type: Easing.InOutQuad }
                NumberAnimation { target: bodyScale; property: "xScale"; from: 1.0; to: 1.04; duration: (blob.state === "sleeping" ? 2200 : 1100) / blob.speedMul; easing.type: Easing.InOutQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; from: 0.96; to: 1.0; duration: (blob.state === "sleeping" ? 1500 : 750) / blob.speedMul; easing.type: Easing.InOutQuad }
                NumberAnimation { target: bodyScale; property: "xScale"; from: 1.04; to: 1.0; duration: (blob.state === "sleeping" ? 1500 : 750) / blob.speedMul; easing.type: Easing.InOutQuad }
            }
        }

        // 眨眼动画
        SequentialAnimation {
            id: blinkAnim; running: false
            PropertyAction { target: leftEye; property: "height"; value: blob.height * 0.03 }
            PropertyAction { target: rightEye; property: "height"; value: blob.height * 0.03 }
            PauseAnimation { duration: 65 / blob.speedMul }
            PropertyAction { target: leftEye; property: "height"; value: blob.eyeH }
            PropertyAction { target: rightEye; property: "height"; value: blob.eyeH }
        }

        // 点击产生的超Q弹果冻回弹动画
        SequentialAnimation {
            id: squishAnim; running: false
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; to: 0.72; duration: 60 / blob.speedMul; easing.type: Easing.OutQuad }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 1.28; duration: 60 / blob.speedMul; easing.type: Easing.OutQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; to: 1.08; duration: 160 / blob.speedMul; easing.type: Easing.OutBounce }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 0.92; duration: 160 / blob.speedMul; easing.type: Easing.OutBounce }
            }
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; to: 1.0; duration: 120 / blob.speedMul; easing.type: Easing.OutBack }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 1.0; duration: 120 / blob.speedMul; easing.type: Easing.OutBack }
            }
        }

        // 欢快小跳跳动画：包含起跳前的蓄力弯腿和落地时的撞击缓冲
        SequentialAnimation {
            id: hopAnim; running: false
            // 1. 起跳弯腿蓄力
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; to: 0.85; duration: 90 / blob.speedMul; easing.type: Easing.OutQuad }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 1.15; duration: 90 / blob.speedMul; easing.type: Easing.OutQuad }
            }
            // 2. 弹跳起飞
            ParallelAnimation {
                NumberAnimation { target: bodyMove; property: "y"; from: 0; to: -6; duration: 140 / blob.speedMul; easing.type: Easing.OutQuad }
                NumberAnimation { target: bodyScale; property: "yScale"; to: 1.15; duration: 140 / blob.speedMul; easing.type: Easing.OutQuad }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 0.88; duration: 140 / blob.speedMul; easing.type: Easing.OutQuad }
            }
            // 3. 地心引力下落
            ParallelAnimation {
                NumberAnimation { target: bodyMove; property: "y"; to: 0; duration: 140 / blob.speedMul; easing.type: Easing.InQuad }
                NumberAnimation { target: bodyScale; property: "yScale"; to: 1.0; duration: 140 / blob.speedMul; easing.type: Easing.InQuad }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 1.0; duration: 140 / blob.speedMul; easing.type: Easing.InQuad }
            }
            // 4. 落地冲击缓冲
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; to: 0.88; duration: 70 / blob.speedMul; easing.type: Easing.OutQuad }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 1.12; duration: 70 / blob.speedMul; easing.type: Easing.OutQuad }
            }
            // 5. 还原
            ParallelAnimation {
                NumberAnimation { target: bodyScale; property: "yScale"; to: 1.0; duration: 110 / blob.speedMul; easing.type: Easing.OutElastic }
                NumberAnimation { target: bodyScale; property: "xScale"; to: 1.0; duration: 110 / blob.speedMul; easing.type: Easing.OutElastic }
            }
        }

        // 工作状态下的持续左右果冻晃晃脑动画
        SequentialAnimation {
            id: wobbleAnim; running: false; loops: Animation.Infinite
            NumberAnimation { target: bodyRotate; property: "angle"; from: 0; to: 15; duration: 250 / blob.speedMul; easing.type: Easing.InOutQuad }
            NumberAnimation { target: bodyRotate; property: "angle"; from: 15; to: -15; duration: 450 / blob.speedMul; easing.type: Easing.InOutQuad }
            NumberAnimation { target: bodyRotate; property: "angle"; from: -15; to: 0; duration: 250 / blob.speedMul; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: 400 / blob.speedMul }
        }

        // 错误状态下的疯狂颤抖
        SequentialAnimation {
            id: shakeAnim; running: false
            NumberAnimation { target: bodyMove; property: "x"; to: 6; duration: 40 / blob.speedMul }
            NumberAnimation { target: bodyMove; property: "x"; to: -6; duration: 80 / blob.speedMul }
            NumberAnimation { target: bodyMove; property: "x"; to: 4; duration: 70 / blob.speedMul }
            NumberAnimation { target: bodyMove; property: "x"; to: -2; duration: 50 / blob.speedMul }
            NumberAnimation { target: bodyMove; property: "x"; to: 0; duration: 40 / blob.speedMul }
        }

        // 警告/确认提示状态下的危机跳跃（已升级为无限循环，并在每一次弹跳周期尾部加入优雅停顿）
        SequentialAnimation {
            id: alertJumpAnim; running: false; loops: Animation.Infinite
            // 第一次大跳
            NumberAnimation { target: bodyMove; property: "y"; from: 0; to: -10; duration: 110 / blob.speedMul; easing.type: Easing.OutQuad }
            NumberAnimation { target: bodyMove; property: "y"; to: 0; duration: 140 / blob.speedMul; easing.type: Easing.OutBounce }
            PauseAnimation { duration: 400 / blob.speedMul }
            // 第二次小跳缓冲
            NumberAnimation { target: bodyMove; property: "y"; from: 0; to: -5; duration: 80 / blob.speedMul; easing.type: Easing.OutQuad }
            NumberAnimation { target: bodyMove; property: "y"; to: 0; duration: 100 / blob.speedMul; easing.type: Easing.OutBounce }
            // 每次跳完停顿一段时间（1.2秒），防止高频鬼畜导致处理器负载增加，同时维持警觉感
            PauseAnimation { duration: 1200 / blob.speedMul }
        }

        // 伸懒腰起床动效
        SequentialAnimation {
            id: wakeAnim; running: false
            PropertyAction { target: body; property: "scale"; value: 0.82 }
            PropertyAction { target: body; property: "opacity"; value: 0.6 }
            NumberAnimation { target: body; property: "scale"; to: 1.15; duration: 280 / blob.speedMul; easing.type: Easing.OutBack }
            NumberAnimation { target: body; property: "opacity"; to: 1.0; duration: 180 / blob.speedMul }
            NumberAnimation { target: body; property: "scale"; to: 1.0; duration: 220 / blob.speedMul; easing.type: Easing.OutQuad }
            ScriptAction { script: blinkAnim.restart() }
        }

        // 随机眨眼睛触发器
        Timer {
            id: blinkTimer
            interval: (2400 + Math.floor(Math.random() * 2600)) / blob.speedMul
            running: blob.state !== "sleeping"; repeat: true
            onTriggered: { 
                if (blob.state !== "sleeping") blinkAnim.restart()
                interval = (2400 + Math.floor(Math.random() * 2600)) / blob.speedMul 
            }
        }

        // 闲置状态下偶尔跳动一下的趣味随机事件触发器
        Timer {
            id: idleTimer
            interval: (4000 + Math.floor(Math.random() * 5500)) / blob.speedMul
            running: blob.state === "idle"; repeat: true
            onTriggered: { 
                if (blob.state === "idle") { 
                    var r = Math.random(); 
                    if (r < 0.42) hopAnim.restart() 
                }
                interval = (4000 + Math.floor(Math.random() * 5500)) / blob.speedMul 
            }
        }

        // 监视状态改变，自动切换动效、复位之前的变换
        onStateChanged: {
            wobbleAnim.running = false; shakeAnim.running = false; alertJumpAnim.running = false
            bodyMove.x = 0; bodyMove.y = 0; bodyRotate.angle = 0
            bodyScale.xScale = 1.0; bodyScale.yScale = 1.0
            
            if (state === "waking") wakeAnim.restart()
            else if (state === "working") wobbleAnim.running = true
            else if (state === "error") shakeAnim.restart()
            else if (state === "alert") alertJumpAnim.running = true
        }

        // 精确检测范围的 Hover 与 Click 交互器
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            
            onPositionChanged: {
                if (blob.state !== "sleeping") {
                    // 将鼠标光标偏移坐标化，映射至瞳孔偏移量，形成灵动的注视效果
                    var relX = (mouseX - width / 2) / (width / 2)
                    var relY = (mouseY - height / 2) / (height / 2)
                    blob.pupilXOffset = relX * (leftEye.width * 0.28)
                    blob.pupilYOffset = relY * (leftEye.height * 0.16)
                }
            }
            
            onExited: {
                blob.pupilXOffset = 0
                blob.pupilYOffset = 0
            }
            
            onClicked: {
                squishAnim.restart()
                particleAnim.restart()
                blob.clicked()
            }
        }
    }

    // ═══════════════════════════════════════════
    // 水平栏形态
    // ═══════════════════════════════════════════
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXXS

            PetBlob {
                id: hPet
                height: root.maxPetSize
                state: root.claudeState
                pColor: root.activeColor
                speedMul: root.speedMult
                showLabel: root.showStateLabel
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.showNameLabel ? root.petName : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showNameLabel && text !== ""
            }
        }
    }

    // ═══════════════════════════════════════════
    // 垂直栏形态
    // ═══════════════════════════════════════════
    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            PetBlob {
                id: vPet
                width: Math.min(root.maxPetSize, parent.width * 0.75); height: width
                state: root.claudeState
                pColor: root.activeColor
                speedMul: root.speedMult
                showLabel: root.showStateLabel
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ═══════════════════════════════════════════
    // 点击小宠物的弹出详情窗口
    // ═══════════════════════════════════════════
    popoutContent: Component {
        PopoutComponent {
            headerText: root.petName
            detailsText: {
                switch (root.claudeState) { 
                    case "idle": return "Waiting for you..."; 
                    case "working": return "Claude is working";
                    case "waking": return "Waking up..."; 
                    case "sleeping": return "Zzz...";
                    case "error": return "Something went wrong!"; 
                    case "alert": return "Needs your attention!";
                    default: return "" 
                }
            }
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: popCol.implicitHeight + Theme.spacingM * 2

                Column {
                    id: popCol
                    width: parent.width; spacing: Theme.spacingM
                    anchors.top: parent.top; anchors.topMargin: Theme.spacingM

                    Rectangle {
                        width: parent.width; height: 130
                        radius: Theme.cornerRadius; color: Theme.surfaceContainerHigh
                        PetBlob {
                            anchors.centerIn: parent; height: 96
                            state: root.claudeState; pColor: root.activeColor
                            speedMul: root.speedMult; showLabel: true  // popout 是详情视图，始终显示 emoji
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        StyledText { text: "State:"; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                        StyledText {
                            text: root.claudeState.charAt(0).toUpperCase() + root.claudeState.slice(1)
                            font.pixelSize: Theme.fontSizeMedium; font.bold: true
                            color: { 
                                switch (root.claudeState) { 
                                    case "working": return Theme.success; 
                                    case "error": return Theme.error; 
                                    case "alert": return Theme.warning; 
                                    default: return Theme.surfaceText 
                                } 
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 3; radius: 2
                        color: { 
                            switch (root.claudeState) { 
                                case "working": return Theme.success; 
                                case "error": return Theme.error; 
                                case "alert": return Theme.warning; 
                                default: return Theme.surfaceContainer 
                            } 
                        }
                    }

                    StyledText {
                        visible: root.claudeEvent !== ""
                        text: root.claudeEvent + (root.claudeTool ? ": " + root.claudeTool : "")
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap; width: parent.width
                    }

                    StyledText {
                        text: "Click the pet to interact!\nState updates automatically via Claude Code hooks."
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap; width: parent.width; opacity: 0.65
                    }
                }
            }
        }
    }

    popoutWidth: 300
    popoutHeight: 340
}