import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "MonitorLabel.js" as Label

// Monitor Flash: when keyboard focus lands on another monitor, show which one
// it landed on. Hyprland already moves the pointer, but a pointer is easy to
// miss; a card with the display number, connector, and workspace is not.
//
// Nothing is bound to a key. The plugin watches Hyprland's focusedMonitor, so
// it works for the stock Ctrl+Alt+Tab binding, for a click, and for any other
// way focus can move.
Item {
  id: root

  // Injected by the shell's overlay loader. Used only to keep the card clear
  // of a bar that shares the bottom or left edge.
  property var shell: null

  // How long the card stays fully visible, then how long it fades out.
  property int holdDuration: 900
  readonly property int fadeDuration: 220

  property bool opened: false
  property var targetScreen: null

  // The card starts in the bottom-left corner. If the pointer is already
  // inside that corner while the card is still up, it slides to the
  // bottom-right instead of sitting under the cursor.
  property bool avoidCursor: false

  property string monitorName: ""
  property string monitorDescription: ""
  property int monitorNumber: 0
  property int monitorCount: 0
  property string workspaceName: ""

  // Focus arrives once at startup. That is the baseline, not a switch.
  property bool baselineSettled: false
  property string lastMonitorName: ""
  property string pendingName: ""

  readonly property var monitors: Hyprland.monitors ? Hyprland.monitors.values : []

  readonly property string barPosition: shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
  readonly property bool barVisible: shell && shell.bar ? shell.bar.barHidden !== true : false
  readonly property int barSize: barVisible ? Math.max(0, Number(shell.bar.barSize || 0)) : 0
  readonly property int edgeGap: Math.round(Commons.Style.space(20))
  readonly property int leftInset: edgeGap + (barPosition === "left" && barVisible ? barSize : 0)
  readonly property int rightInset: edgeGap + (barPosition === "right" && barVisible ? barSize : 0)
  readonly property int bottomInset: edgeGap + (barPosition === "bottom" && barVisible ? barSize : 0)

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // ---------------------------------------------------------------- labels

  function screenFor(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name || "") === name) return screens[i]
    }
    return null
  }

  function workspaceFor(name) {
    var list = root.monitors
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].name || "") !== name) continue
      var workspace = list[i].activeWorkspace
      if (workspace && workspace.name !== undefined && String(workspace.name) !== "")
        return String(workspace.name)
    }
    var focused = Hyprland.focusedWorkspace
    return focused && focused.name !== undefined ? String(focused.name) : ""
  }

  function displayNumber(value) {
    return value > 0 ? Commons.I18n.formatNumber(value) : ""
  }

  // Hyprland reports the pointer in layout coordinates. The card lives in
  // this monitor's local space, so subtract the monitor origin before testing
  // whether the pointer is over the card.
  function monitorOrigin() {
    var list = root.monitors
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].name || "") !== root.monitorName) continue
      return { x: Number(list[i].x) || 0, y: Number(list[i].y) || 0 }
    }
    return {
      x: root.targetScreen ? Number(root.targetScreen.x) || 0 : 0,
      y: root.targetScreen ? Number(root.targetScreen.y) || 0 : 0
    }
  }

  function noteCursor(raw) {
    if (!root.opened || root.avoidCursor) return
    var parts = String(raw || "").split(",")
    var globalX = Number(parts[0])
    var globalY = Number(parts[1])
    if (!Number.isFinite(globalX) || !Number.isFinite(globalY)) return

    var origin = root.monitorOrigin()
    var x = globalX - origin.x
    var y = globalY - origin.y
    var rect = { x: card.x, y: card.y, width: card.width, height: card.height }
    if (Label.contains(rect, x, y, 2)) root.avoidCursor = true
  }

  function pollCursor() {
    if (!root.opened || root.avoidCursor || cursorProcess.running) return
    cursorProcess.running = true
  }

  // ----------------------------------------------------------------- flash

  // A monitor that is not in the cache yet (hotplug, very first event) gets one
  // refresh and one retry before the card falls back to the connector name.
  function showForName(name, retried) {
    var info = Label.info(root.monitors, name)
    var screen = root.screenFor(name)

    if ((!info.found || !screen) && !retried) {
      root.pendingName = name
      Hyprland.refreshMonitors()
      retryTimer.restart()
      return
    }
    root.pendingName = ""
    retryTimer.stop()

    root.monitorName = info.name
    root.monitorDescription = info.description
    root.monitorNumber = info.number
    root.monitorCount = info.count
    root.workspaceName = root.workspaceFor(info.name)
    root.targetScreen = screen
    root.avoidCursor = false
    root.opened = true
    hideTimer.restart()
    // A pointer already resting in the bottom-left corner should move the card
    // on the first frame instead of waiting for the first poll.
    Qt.callLater(root.pollCursor)
  }

  function flash() {
    var monitor = Hyprland.focusedMonitor
    if (!monitor) return
    root.lastMonitorName = String(monitor.name || "")
    root.baselineSettled = true
    root.showForName(root.lastMonitorName)
  }

  function noteFocus() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    if (name === "") return

    if (!root.baselineSettled) {
      root.baselineSettled = true
      root.lastMonitorName = name
      return
    }
    if (name === root.lastMonitorName) return

    root.lastMonitorName = name
    root.showForName(name)
  }

  function close() {
    root.opened = false
    hideTimer.stop()
  }

  // The shell summons an overlay by calling open() with its payload. A payload
  // is optional; without one the card simply reports the focused display.
  function open(payloadJson) {
    var name = ""
    try {
      var payload = JSON.parse(payloadJson || "{}")
      if (payload && payload.monitor !== undefined) name = String(payload.monitor)
    } catch (e) {}

    if (name !== "") {
      root.baselineSettled = true
      root.lastMonitorName = name
      root.showForName(name)
      return
    }
    root.flash()
  }

  Connections {
    target: Hyprland
    function onFocusedMonitorChanged() { root.noteFocus() }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (root.targetScreen && Quickshell.screens.indexOf(root.targetScreen) < 0)
        root.close()
    }
  }

  Component.onCompleted: {
    // Establish the baseline from whatever is already focused. If the
    // Hyprland module is still starting, the first change settles it instead.
    root.noteFocus()
  }

  Timer {
    id: hideTimer
    interval: root.holdDuration
    onTriggered: root.opened = false
  }

  Timer {
    id: retryTimer
    interval: 120
    onTriggered: {
      if (root.pendingName === "") return
      var name = root.pendingName
      root.pendingName = ""
      root.showForName(name, true)
    }
  }

  // The card is a visual-only surface with an empty input mask, so it cannot
  // see pointer enter events itself. While it is up, ask the compositor where
  // the pointer is; this stops as soon as the card moves or closes.
  Process {
    id: cursorProcess
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.noteCursor(text)
    }
  }

  Timer {
    id: cursorTimer
    interval: 100
    repeat: true
    running: root.opened && !root.avoidCursor
    onTriggered: root.pollCursor()
  }

  // ---------------------------------------------------------------- surface

  PanelWindow {
    id: panel

    visible: !!root.targetScreen && (root.opened || card.opacity > 0.01)
    screen: root.targetScreen
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dimdoremy.monitor-flash"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Visual-only surface: clicks belong to whatever is below it.
    mask: Region {}

    MonitorCard {
      id: card
      // Bottom-left by default; bottom-right once the pointer is over it.
      x: root.avoidCursor ? panel.width - card.width - root.rightInset : root.leftInset
      y: panel.height - card.height - root.bottomInset + (root.opened ? 0 : Math.round(Commons.Style.space(8)))
      LayoutMirroring.enabled: Commons.I18n.rightToLeft
      LayoutMirroring.childrenInherit: true
      numberText: root.displayNumber(root.monitorNumber) || "?"
      labelText: strings.t("display.label")
      titleText: root.monitorDescription !== "" ? root.monitorDescription : root.monitorName
      subtitleText: root.monitorDescription !== "" && root.monitorDescription !== root.monitorName
        ? root.monitorName : ""
      workspaceText: root.workspaceName !== ""
        ? strings.t("display.workspace").arg(root.workspaceName)
        : ""
      positionText: root.monitorNumber > 0 && root.monitorCount > 1
        ? strings.t("display.position")
            .arg(Commons.I18n.formatNumber(root.monitorNumber))
            .arg(Commons.I18n.formatNumber(root.monitorCount))
        : ""

      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.96

      Behavior on opacity { NumberAnimation { duration: root.opened ? 140 : root.fadeDuration; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: root.opened ? 160 : root.fadeDuration; easing.type: Easing.OutCubic } }
      Behavior on x { enabled: root.opened; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: root.opened ? 160 : root.fadeDuration; easing.type: Easing.OutCubic } }
    }
  }

  IpcHandler {
    target: "dimdoremy.monitor-flash"

    function flash(): string {
      root.flash()
      return "ok"
    }

    function show(payloadJson: string): string {
      root.open(payloadJson)
      return "ok"
    }

    function close(): string {
      root.close()
      return "ok"
    }

    function state(): string {
      return JSON.stringify({
        opened: root.opened,
        monitor: root.monitorName,
        number: root.monitorNumber,
        count: root.monitorCount,
        workspace: root.workspaceName,
        avoided: root.avoidCursor
      })
    }
  }
}
