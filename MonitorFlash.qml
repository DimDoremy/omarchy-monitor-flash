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

  // How long the card stays fully visible, then how long it fades out.
  property int holdDuration: 900
  readonly property int fadeDuration: 220

  property bool opened: false
  property var targetScreen: null

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
    root.opened = true
    hideTimer.restart()
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
      anchors.centerIn: parent
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
      y: root.opened ? 0 : Math.round(Commons.Style.space(8))

      Behavior on opacity { NumberAnimation { duration: root.opened ? 140 : root.fadeDuration; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: root.opened ? 160 : root.fadeDuration; easing.type: Easing.OutCubic } }
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
        workspace: root.workspaceName
      })
    }
  }
}
